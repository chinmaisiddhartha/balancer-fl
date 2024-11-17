// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import "./TransferHelper.sol";
contract V2Swap {

    function swapV2(
        address pair,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to
    ) internal returns (uint256[] memory amounts) {
        require(path.length == 2, "Invalid path length");

        IUniswapV2Pair Pair = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1,) = Pair.getReserves();        
        bool isInput0 = path[0] < path[1];
        uint256 amountOut = getAmountOut(amountIn, isInput0 ? reserve0 : reserve1, isInput0 ? reserve1 : reserve0);
        require(amountOut >= amountOutMin, "Slipppage Limit exceeded");
        
        TransferHelper.safeApprove(path[0], pair, amountIn);
        uint256 allowance = IERC20(path[0]).allowance(address(this), pair);
        
        require(allowance >= amountIn, "Insufficient allowance");
        TransferHelper.safeTransfer(path[0], pair, amountIn);
    
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        
        Pair.swap(
            isInput0 ? 0 : amountOut,
            isInput0 ? amountOut : 0,
            to,
            new bytes(0)
        );

        return amounts;

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

