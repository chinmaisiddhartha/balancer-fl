// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "hardhat/console.sol";

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}


contract Arbitrage is IFlashLoanRecipient {
    IVault public constant vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    enum Exchange {
        V2,
        V3
    }

    struct FlashLoanData {
        address flashToken;
        uint256 flashAmount;
        address caller;
        address[] path;
        uint24 v3Fee;
        uint8[] exchRoute;
        address[] pools;
        uint256 balanceBefore;
    }

    event FlashLoan(address token, uint256 amount);
    event SwapExecuted(uint8 exchange, uint256 amountIn, uint256 amountOut);

    constructor() payable {}
    
    receive() external payable {}

    function getFlashloan(
        address flashToken,
        uint256 flashAmount,
        address[] memory path,
        uint24 v3Fee,
        uint8[] memory exchRoute,
        address[] memory pools
    ) external {
        uint256 balanceBefore = IERC20(flashToken).balanceOf(address(this));
        console.log("Balance before flashloan: ", balanceBefore);

        FlashLoanData memory flashLoanData = FlashLoanData({
            flashToken: flashToken,
            flashAmount: flashAmount,
            caller: msg.sender,
            path: path,
            v3Fee: v3Fee,
            exchRoute: exchRoute,
            pools: pools,
            balanceBefore: balanceBefore
        });

        bytes memory data = abi.encode(flashLoanData);

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(flashToken);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;

        vault.flashLoan(this, tokens, amounts, data);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault), "FlashLoanTemplate: Caller not Balancer Vault");

        FlashLoanData memory decoded = abi.decode(userData, (FlashLoanData));
        uint256 balanceAfter = IERC20(decoded.flashToken).balanceOf(address(this));
        console.log("FlashLoan received: ", balanceAfter);

        require(
            balanceAfter - decoded.balanceBefore == amounts[0],
            "FlashLoanTemplate: Contract did not get loan"
        );

        uint256 profit = executeArbitrage(decoded, amounts[0]);

        IERC20(decoded.flashToken).transfer(address(vault), amounts[0] + feeAmounts[0]);
        if (profit > 0) {
            IERC20(decoded.flashToken).transfer(decoded.caller, profit);
        }

        emit FlashLoan(decoded.flashToken, amounts[0]);
    }

    function executeArbitrage(FlashLoanData memory userData, uint256 flashAmount) private returns (uint256) {
        console.log("Executing arbitrage...");
        uint256 currentAmount = flashAmount;
        address currentToken = userData.flashToken;
    
        for (uint i = 0; i < userData.exchRoute.length; i++) {
            console.log("Executing arbitrage on exchange: ", userData.exchRoute[i]);
            (uint256 amountOut, address tokenOut) = PlaceSwap(userData.path, currentAmount, userData.exchRoute[i], userData.v3Fee, i, userData.pools[i]);
            console.log("Swap completed. Amount in: ", currentAmount, " Amount out: ", amountOut);
            currentAmount = amountOut;
            currentToken = tokenOut;
        }
    
        console.log("Final amount: ", currentAmount, " Flash loan amount: ", flashAmount);
        if (currentAmount > flashAmount) {
            uint256 profit = currentAmount - flashAmount;
            console.log("Profit: ", profit);
            return profit;
        } else {
            console.log("No profit. Final amount: ", currentAmount, " Flash loan amount: ", flashAmount);
            return 0;
        }
    }
    
    
    function PlaceSwap(address[] memory _tokenPath, uint256 _amountIn, uint8 _route, uint24 _v3Fee, uint256 swapIndex, address pool) private returns(uint256, address) {
        console.log("Placing swap on exchange: ", _route);
        uint256 amountOut;
        address tokenOut;
    
        address[] memory path = new address[](2);
        path[0] = _tokenPath[swapIndex];
        path[1] = _tokenPath[swapIndex + 1];

        console.log("pool address for swap: ", pool, "swapIndex: ", swapIndex);
        console.log("path0: ", path[0]);
        console.log("path1: ", path[1]);
        // console.log("approving pool to spend tokens");
        // IERC20(path[0]).approve(pool, _amountIn);
        // console.log(" approval done ..!!");
        console.log("tokenIn balance of smart contract before swap:",IERC20(path[0]).balanceOf(address(this)));
        console.log("tokenOut balance of smart contract before swap:", IERC20(path[1]).balanceOf(address(this)));
        console.log("");
      

        if (_route == uint8(Exchange.V2)) {
            uint256[] memory amounts = swapExactTokensForTokens(pool, _amountIn, 0, path, address(this));
            amountOut = amounts[1];
            tokenOut = path[1];
        } else {
            amountOut = swapExactInputSingle(pool, _amountIn, 0, path[0], address(this));
            tokenOut = path[1];
        }
        console.log("swap executed on exchange:", _route);
        console.log("tokenIn balance of smart contract after swap:",IERC20(path[0]).balanceOf(address(this)));
        console.log("tokenOut balance of smart contract after swap:", IERC20(tokenOut).balanceOf(address(this)));
        
        emit SwapExecuted(_route, _amountIn, amountOut);
        return (amountOut, tokenOut);
    }
    
    

    function swapExactTokensForTokens(
        address pair,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to
    ) private returns (uint256[] memory amounts) {
        require(path.length == 2, "Invalid path");
        console.log("V2 Swap - Pair address:", pair);
        console.log("V2 Swap - Amount In:", amountIn);
        console.log("V2 Swap - Path:", path[0], path[1]);
    
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();
        console.log("V2 Swap - Reserves:", reserve0, reserve1);
        
        bool isInput0 = path[0] < path[1];
        uint256 amountOut = getAmountOut(amountIn, isInput0 ? reserve0 : reserve1, isInput0 ? reserve1 : reserve0);
        console.log("V2 Swap - Calculated Amount Out:", amountOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        console.log("path0 contract balance is : ", IERC20(path[0]).balanceOf(address(this)));
        console.log(
            "path1 contract balance is : ",
            IERC20(path[1]).balanceOf(address(this))
        );
        console.log("V2 Swap - Token balance before approval:", IERC20(path[0]).balanceOf(address(this)));
        console.log("V2 Swap - Approving tokens for transfer...");
        TransferHelper.safeApprove(path[0], pair, amountIn);
        uint256 allowance = IERC20(path[0]).allowance(address(this), pair);
        console.log("V2 Swap - Approval allowance:", allowance);
        require(allowance >= amountIn, "Insufficient allowance");

        console.log("checking both token balances in smart contract");

        console.log("");
        console.log("V2 Swap - Transferring tokens to pair address...");
        TransferHelper.safeTransfer(path[0], pair, amountIn);
        console.log("Transfer successful");
        console.log(
            "V2 Swap - Token balance after transfer:",
            IERC20(path[0]).balanceOf(address(this))
        );
        // try IERC20(path[0]).transfer(pair, amountIn) {
        //     console.log("V2 Swap - Token transfer successful");
        // } catch Error(string memory reason) {
        //     console.log("V2 Swap - Token transfer failed. Reason:", reason);
        //     revert(reason);
        // } catch (bytes memory lowLevelData) {
        //     console.log("V2 Swap - Token transfer failed. Low-level error");
        //     revert("Low-level transfer error");
        // }
    
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        
        uniswapV2Pair.swap(
            isInput0 ? 0 : amountOut,
            isInput0 ? amountOut : 0,
            to,
            new bytes(0)
        );
        
        
        console.log("V2 Swap - Actual Amount In:", amounts[0]);
        console.log("V2 Swap - Actual Amount Out:", amounts[1]);
        
        return amounts;
    }
    
    

    function swapExactInputSingle(
        address poolAddress,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address tokenIn,
        address recipient
    ) private returns (uint256 amountOut) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        console.log("SwapExactInputSingle - Pool Address:", poolAddress);
        bool zeroForOne = tokenIn == pool.token0();
        console.log("zero for one :", zeroForOne);
        address tokenOut = zeroForOne ? pool.token1() : pool.token0();
        console.log("V3 Swap - Token In:", tokenIn);
        console.log("");
        console.log("V3 Swap - token0: ", pool.token0());
        console.log("V3 Swap - token1: ", pool.token1());
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint160 sqrtPriceLimitX96 = zeroForOne 
            ? sqrtPriceX96 * 99 / 100  // Price can go down by 1%
            : sqrtPriceX96 * 101 / 100; // Price can go up by 1%

        bytes memory callbackData = abi.encode(tokenIn, tokenOut, amountIn);

        (int256 amount0, int256 amount1) = pool.swap(
            recipient,
            zeroForOne,
            int256(amountIn),
            sqrtPriceLimitX96,
            callbackData
        );

        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        require(amountOut >= amountOutMinimum, "Insufficient output amount");
    }


    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        require(msg.sender == address(IUniswapV3Pool(msg.sender)), "Unauthorized callback");
        console.log("Authorized callback msg.sender : ", address(IUniswapV3Pool(msg.sender)));
        console.log("noramal msg.sender v3 call back top line is : ", msg.sender);
        (address tokenIn, address tokenOut, uint256 amountIn) = abi.decode(data, (address, address, uint256));
    
        uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        require(amountToPay <= amountIn, "Insufficient input amount");
    
        IERC20(tokenIn).transfer(msg.sender, amountToPay);
        console.log("last msg.sender in callback: ", msg.sender);
    }
    

    function getAmountOut(uint256 amountIn, uint112 reserveIn, uint112 reserveOut) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * uint256(reserveOut);
        uint256 denominator = (uint256(reserveIn) * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}