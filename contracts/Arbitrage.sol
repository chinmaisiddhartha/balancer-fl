// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "hardhat/console.sol";

contract Arbitrage is IFlashLoanRecipient {
    IVault public constant vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    enum Exchange {
        UNISWAP_V2,
        UNISWAP_V3,
        SUSHISWAP_V2
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
        uint256 amountIn = flashAmount;
        uint256 amountOut;

        for (uint i = 0; i < userData.exchRoute.length; i++) {
            console.log("Executing arbitrage on exchange: ", userData.exchRoute[i]);
            amountOut = PlaceSwap(userData.path, amountIn, userData.exchRoute[i], userData.v3Fee, i, userData.pools[i]);
            if (amountOut == 0) {
                console.log("Swap failed, aborting arbitrage");
                return 0;
            }
            amountIn = amountOut;
            console.log("Completed swap on Exchange: ", userData.exchRoute[i], " amountOut: ", amountOut);
        }

        return amountOut > flashAmount ? amountOut - flashAmount : 0;
    }

    function PlaceSwap(address[] memory _tokenPath, uint256 _amountIn, uint8 _route, uint24 _v3Fee, uint256 swapIndex, address pool) private returns(uint256) {
        console.log("Placing swap on exchange: ", _route);
        uint256 amountOut;
    
        address[] memory path = new address[](2);
        path[0] = _tokenPath[swapIndex];
        path[1] = _tokenPath[swapIndex + 1];
    
        if (_route == uint8(Exchange.UNISWAP_V2) || _route == uint8(Exchange.SUSHISWAP_V2)) {
            amountOut = swapExactTokensForTokens(pool, _amountIn, 0, path, address(this));
        } else {
            amountOut = swapExactInputSingle(pool, _amountIn, 0, path[0], address(this));
        }
    
        emit SwapExecuted(_route, _amountIn, amountOut);
        return amountOut;
    }
    

    function swapExactTokensForTokens(
        address pair,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to
    ) private returns (uint256 amountOut) {
        require(path.length == 2, "Invalid path");
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();
        
        bool isInput0 = path[0] < path[1];
        amountOut = getAmountOut(amountIn, isInput0 ? reserve0 : reserve1, isInput0 ? reserve1 : reserve0);
        require(amountOut >= amountOutMin, "Insufficient output amount");
    
        IERC20(path[0]).approve(pair, amountIn);
        IERC20(path[0]).transferFrom(address(this), pair, amountIn);
    
        uniswapV2Pair.swap(
            isInput0 ? 0 : amountOut,
            isInput0 ? amountOut : 0,
            to,
            new bytes(0)
        );
        return amountOut;
    }
    

    function swapExactInputSingle(
        address poolAddress,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address tokenIn,
        address recipient
    ) private returns (uint256 amountOut) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        bool zeroForOne = tokenIn == pool.token0();
        address tokenOut = zeroForOne ? pool.token1() : pool.token0();

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
    
        (address tokenIn, address tokenOut, uint256 amountIn) = abi.decode(data, (address, address, uint256));
    
        uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        require(amountToPay <= amountIn, "Insufficient input amount");
    
        IERC20(tokenIn).transfer(msg.sender, amountToPay);
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
