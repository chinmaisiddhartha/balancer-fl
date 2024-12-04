// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import "./TransferHelper.sol";

contract P3Swap {

    function swapP3(
        address poolAddress,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address tokenIn,
        address recipient
    ) internal returns (uint256 amountOut) {
       
        IPancakeV3Pool pool = IPancakeV3Pool(poolAddress);
        bool zeroForOne = tokenIn == pool.token0();

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        // Safe version using checked math
        uint160 sqrtPriceLimitX96 = zeroForOne 
        ? uint160((uint256(sqrtPriceX96) * 99) / 100)   // Price can go up by 0.5%
        : uint160((uint256(sqrtPriceX96) * 101) / 100); // Price can go down by 0.5%

        // uint160 sqrtPriceLimitX96 = zeroForOne ? type(uint160).min : type(uint160).max;
        
        bytes memory callbackData = abi.encode(tokenIn, zeroForOne ? pool.token1() : pool.token0(), amountIn);

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

    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data 
    ) external {
        require(msg.sender == address(IPancakeV3Pool(msg.sender)), "Unauthorized callback");
        // console.log("Authorized callback msg.sender : ", address(IUniswapV3Pool(msg.sender)));
        // console.log("noramal msg.sender v3 call back top line is : ", msg.sender);
        (address tokenIn, address tokenOut, uint256 amountIn) = abi.decode(data, (address, address, uint256));
        require(tokenOut != address(0), "Invalid token out");
        uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        require(amountToPay <= amountIn, "Insufficient input amount");
    
        TransferHelper.safeTransfer(tokenIn, msg.sender, amountToPay);
        // console.log("last msg.sender in callback: ", msg.sender);
    }

}