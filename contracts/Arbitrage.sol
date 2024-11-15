// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

// import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
// import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
// // import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
// import "hardhat/console.sol";

// library TransferHelper {
//     /// @notice Transfers tokens from the targeted address to the given destination
//     /// @notice Errors with 'STF' if transfer fails
//     /// @param token The contract address of the token to be transferred
//     /// @param from The originating address from which the tokens will be transferred
//     /// @param to The destination address of the transfer
//     /// @param value The amount to be transferred
//     function safeTransferFrom(
//         address token,
//         address from,
//         address to,
//         uint256 value
//     ) internal {
//         (bool success, bytes memory data) =
//             token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
//         require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
//     }

//     /// @notice Transfers tokens from msg.sender to a recipient
//     /// @dev Errors with ST if transfer fails
//     /// @param token The contract address of the token which will be transferred
//     /// @param to The recipient of the transfer
//     /// @param value The value of the transfer
//     function safeTransfer(
//         address token,
//         address to,
//         uint256 value
//     ) internal {
//         (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
//         require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
//     }

//     /// @notice Approves the stipulated contract to spend the given allowance in the given token
//     /// @dev Errors with 'SA' if transfer fails
//     /// @param token The contract address of the token to be approved
//     /// @param to The target of the approval
//     /// @param value The amount of the given token the target will be allowed to spend
//     function safeApprove(
//         address token,
//         address to,
//         uint256 value
//     ) internal {
//         (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
//         require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
//     }

//     /// @notice Transfers ETH to the recipient address
//     /// @dev Fails with `STE`
//     /// @param to The destination of the transfer
//     /// @param value The value to be transferred
//     function safeTransferETH(address to, uint256 value) internal {
//         (bool success, ) = to.call{value: value}(new bytes(0));
//         require(success, 'STE');
//     }
// }


// contract Arbitrage is IFlashLoanRecipient {
//     IVault public constant vault =
//         IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

//     // uint160 internal constant MIN_SQRT_RATIO = 4295128739;
//     // uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

//     address immutable owner;
    
//     enum Exchange {
//         V2,
//         V3
//     }

//     struct FlashLoanData {
//         address flashToken;
//         uint256 flashAmount;
//         address caller;
//         address[] path;
//         uint8[] exchRoute;
//         address[] pools;
//         uint256 balanceBefore;
//     }

//     event FlashLoan(address token, uint256 amount);
//     event SwapExecuted(uint8 exchange, uint256 amountIn, uint256 amountOut);
//     event SwapStarted(
//         uint8 exchange,
//         uint256 amountIn,
//         address tokenIn,
//         address tokenOut,
//         address pool
//     );
//     event FlashLoanReceived(
//         uint256 amount,
//         uint256 fee,
//         uint256 balanceAfter
//     );
//     event ArbitrageAttempt(
//         uint256 startAmount,
//         uint256 finalAmount,
//         bool profitable,
//         uint256 profit
//     );

//     constructor() payable {
//         owner = msg.sender;
//     }
    
//     receive() external payable {}

//     function getFlashloan(
//         address flashToken,
//         uint256 flashAmount,
//         address[] calldata path,
//         uint8[] calldata exchRoute,
//         address[] calldata pools
//     ) external {
//         uint256 balanceBefore = IERC20(flashToken).balanceOf(address(this));
//         console.log("Balance before flashloan: ", balanceBefore);

//         FlashLoanData memory flashLoanData = FlashLoanData({
//             flashToken: flashToken,
//             flashAmount: flashAmount,
//             caller: msg.sender,
//             path: path,
//             exchRoute: exchRoute,
//             pools: pools,
//             balanceBefore: balanceBefore
//         });

//         bytes memory data = abi.encode(flashLoanData);

//         IERC20[] memory tokens = new IERC20[](1);
//         tokens[0] = IERC20(flashToken);

//         uint256[] memory amounts = new uint256[](1);
//         amounts[0] = flashAmount;

//         vault.flashLoan(this, tokens, amounts, data);
//     }

//     function receiveFlashLoan(
//         IERC20[] memory tokens,
//         uint256[] memory amounts,
//         uint256[] memory feeAmounts,
//         bytes memory userData
//     ) external override {
//         require(msg.sender == address(vault), "FlashLoanTemplate: Caller not Balancer Vault");

//         FlashLoanData memory decoded = abi.decode(userData, (FlashLoanData));
//         uint256 balanceAfter = IERC20(decoded.flashToken).balanceOf(address(this));
//         console.log("FlashLoan received: ", balanceAfter);

//         emit FlashLoanReceived(amounts[0], feeAmounts[0], balanceAfter);

//         require(
//             balanceAfter - decoded.balanceBefore >= amounts[0],
//             "Arbitrage: Contract did not get loan"
//         );

//         uint256 profit = executeArbitrage(decoded, amounts[0]);

//         bool success = IERC20(decoded.flashToken).transfer(address(vault), amounts[0] + feeAmounts[0]);
//         require(success, "Arbitrage: Transfer to Vault failed");

//         emit ArbitrageAttempt( amounts[0], balanceAfter , profit > 0, profit );
        
//         if (profit > 0) {
//             success = IERC20(decoded.flashToken).transfer(decoded.caller, profit);
//             require(success, "Arbitrage: Profit Transfer to caller failed");
//         }

//         emit FlashLoan(decoded.flashToken, amounts[0]);
//     }

//     function executeArbitrage(FlashLoanData memory userData, uint256 flashAmount) private returns (uint256) {
//         // console.log("Executing arbitrage...");
//         uint256 currentAmount = flashAmount;
//         address currentToken = userData.flashToken;
        
//         uint256 routeLength = userData.exchRoute.length;
//         for (uint i = 0; i < routeLength; i++) {
//             // console.log("Executing arbitrage on exchange: ", userData.exchRoute[i]);
//             (uint256 amountOut, address tokenOut) = placeSwap(userData.path, currentAmount, userData.exchRoute[i], i, userData.pools[i]);
//             console.log("Swap completed. Amount in: ", currentAmount, " Amount out: ", amountOut);
//             currentAmount = amountOut;
//             currentToken = tokenOut;
//         }
    
//         console.log("Final amount: ", currentAmount, " Flash loan amount: ", flashAmount);
//         if (currentAmount > flashAmount) {
//            unchecked {
//                uint256 profit = currentAmount - flashAmount;
//                console.log("Profit: ", profit);
//                return profit;
//            }
//         } else {
//             console.log("No profit. Final amount: ", currentAmount, " Flash loan amount: ", flashAmount);
//             return 0;
//         }
//     }
    
    
//     function placeSwap(address[] memory _tokenPath, uint256 _amountIn, uint8 _route, uint256 swapIndex, address pool) private returns(uint256, address) {
//         console.log("Placing swap on exchange: ", _route);
//         emit SwapStarted(_route, _amountIn, _tokenPath[swapIndex], _tokenPath[swapIndex + 1], pool);
       
//         uint256 amountOut;
//         address tokenOut;
    
//         address[] memory path = new address[](2);
//         path[0] = _tokenPath[swapIndex];
//         path[1] = _tokenPath[swapIndex + 1];

//         bool isInput0 = path[0] < path[1];

//         console.log("tokenIn balance of smart contract before swap:",IERC20(path[0]).balanceOf(address(this)));
//         console.log("tokenOut balance of smart contract before swap:", IERC20(path[1]).balanceOf(address(this)));
//         console.log("");
      

//         if (_route == uint8(Exchange.V2)) {
//             uint256 minAmountOut = v2MinAmountOut(pool, _amountIn, isInput0);
//             uint256[] memory amounts = swapExactTokensForTokens(pool, _amountIn, minAmountOut, path, address(this));
//             amountOut = amounts[1];
//             tokenOut = path[1];
//         } else {
//             amountOut = swapExactInputSingle(pool, _amountIn, 0, path[0], address(this));
//             tokenOut = path[1];
//         }
//         console.log("swap executed on exchange:", _route);
//         console.log("tokenIn balance of smart contract after swap:",IERC20(path[0]).balanceOf(address(this)));
//         console.log("tokenOut balance of smart contract after swap:", IERC20(tokenOut).balanceOf(address(this)));
        
//         emit SwapExecuted(_route, _amountIn, amountOut);
//         return (amountOut, tokenOut);
//     }
    
    

//     function swapExactTokensForTokens(
//         address pair,
//         uint256 amountIn,
//         uint256 amountOutMin,
//         address[] memory path,
//         address to
//     ) private returns (uint256[] memory amounts) {
//         require(path.length == 2, "Invalid path");
//         console.log("V2 Swap - Path:", path[0], path[1]);
    
//         IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pair);
//         (uint112 reserve0, uint112 reserve1,) = uniswapV2Pair.getReserves();        
//         bool isInput0 = path[0] < path[1];
//         uint256 amountOut = getAmountOut(amountIn, isInput0 ? reserve0 : reserve1, isInput0 ? reserve1 : reserve0);
//         require(amountOut >= amountOutMin, "Insufficient output amount");
        
//         // console.log("path0 contract balance is : ", IERC20(path[0]).balanceOf(address(this)));
//         // console.log(
//         //     "path1 contract balance is : ",
//         //     IERC20(path[1]).balanceOf(address(this))
//         // );
//         // console.log("V2 Swap - Token balance before approval:", IERC20(path[0]).balanceOf(address(this)));
//         // console.log("V2 Swap - Approving tokens for transfer...");
//         TransferHelper.safeApprove(path[0], pair, amountIn);
//         uint256 allowance = IERC20(path[0]).allowance(address(this), pair);
//         // console.log("V2 Swap - Approval allowance:", allowance);
//         require(allowance >= amountIn, "Insufficient allowance");
//         TransferHelper.safeTransfer(path[0], pair, amountIn);
    
//         amounts = new uint256[](2);
//         amounts[0] = amountIn;
//         amounts[1] = amountOut;
        
//         uniswapV2Pair.swap(
//             isInput0 ? 0 : amountOut,
//             isInput0 ? amountOut : 0,
//             to,
//             new bytes(0)
//         );
//         // console.log("V2 Swap - Actual Amount In:", amounts[0]);
//         // console.log("V2 Swap - Actual Amount Out:", amounts[1]);
        
//         return amounts;
//     }
    
    

//     function swapExactInputSingle(
//         address poolAddress,
//         uint256 amountIn,
//         uint256 amountOutMinimum,
//         address tokenIn,
//         address recipient
//     ) private returns (uint256 amountOut) {
//         IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
//         bool zeroForOne = tokenIn == pool.token0();
//         // console.log("zero for one :", zeroForOne);
//         address tokenOut = zeroForOne ? pool.token1() : pool.token0();
//         // console.log("V3 Swap - Token In:", tokenIn);
//         // console.log("");
//         // console.log("V3 Swap - token0: ", pool.token0());
//         // console.log("V3 Swap - token1: ", pool.token1());
//         (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
//         uint160 sqrtPriceLimitX96 = zeroForOne 
//             ? sqrtPriceX96 * 9975 / 10000  // Price can go down by 0.25%
//             : sqrtPriceX96 * 10025 / 10000; // Price can go up by 0.25%

//         bytes memory callbackData = abi.encode(tokenIn, tokenOut, amountIn);

//         (int256 amount0, int256 amount1) = pool.swap(
//             recipient,
//             zeroForOne,
//             int256(amountIn),
//             sqrtPriceLimitX96,
//             callbackData
//         );

//         amountOut = uint256(-(zeroForOne ? amount1 : amount0));
//         require(amountOut >= amountOutMinimum, "Insufficient output amount");
//     }


//     function uniswapV3SwapCallback(
//         int256 amount0Delta,
//         int256 amount1Delta,
//         bytes calldata data 
//     ) external {
//         require(msg.sender == address(IUniswapV3Pool(msg.sender)), "Unauthorized callback");
//         // console.log("Authorized callback msg.sender : ", address(IUniswapV3Pool(msg.sender)));
//         // console.log("noramal msg.sender v3 call back top line is : ", msg.sender);
//         (address tokenIn, address tokenOut, uint256 amountIn) = abi.decode(data, (address, address, uint256));
    
//         uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
//         require(amountToPay <= amountIn, "Insufficient input amount");
    
//         bool success = IERC20(tokenIn).transfer(msg.sender, amountToPay);
//         require(success, "Callback Transfer failed");
//         // console.log("last msg.sender in callback: ", msg.sender);
//     }
    

//     function getAmountOut(uint256 amountIn, uint112 reserveIn, uint112 reserveOut) internal pure returns (uint256 amountOut) {
//         require(amountIn > 0, "Insufficient input amount");
//         require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
//         uint256 amountInWithFee = amountIn * 997;
//         uint256 numerator = amountInWithFee * uint256(reserveOut);
//         uint256 denominator = (uint256(reserveIn) * 1000) + amountInWithFee;
//         amountOut = numerator / denominator;
//     }

//     function withdrawTokens(address token) public  {
//         require(msg.sender == owner, "Only the owner can withdraw");
//         uint256 balance = IERC20(token).balanceOf(address(this));
//         require(balance > 0, "No tokens to withdraw");
//         bool success = IERC20(token).transfer(msg.sender, balance);
//         require(success, "Token withdrawal failed");
//     }

//     function withdrawEth() public {
//         require(msg.sender == owner, "Only the owner can withdraw");
//         uint256 balance = address(this).balance;
//         require(balance > 0, "No ETH to withdraw");
//         (bool success, ) = msg.sender.call{value: balance}("");
//         require(success, "ETH withdrawal failed");
//     }

//     function v2MinAmountOut(address pool, uint256 amountIn, bool isInput0) internal view returns (uint256 amountOut) {
//         require(amountIn > 0, "Insufficient input amount");
//         (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pool).getReserves();
//             uint256 _amountOut = getAmountOut(amountIn, isInput0 ? reserve0 : reserve1, isInput0 ? reserve1 : reserve0);
//             console.log("expected amountOut:", _amountOut);
//             uint256 amountOutMin = (_amountOut * 9975) / 10000;
//             console.log("amountOutMin:", amountOutMin);
//             return amountOutMin;
//     }
    
// }

    
    
    
    
