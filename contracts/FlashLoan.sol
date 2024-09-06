// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "hardhat/console.sol";

contract FlashLoanTemplate is IFlashLoanRecipient {
    IVault public constant vault =
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniswapV2Router02 private constant uniswapV2Router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ISwapRouter private constant uniswapV3Router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV2Router02 private constant sushiSwapV2Router =
        IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    enum Exchange {
        UNISWAP_V2,//0
        UNISWAP_V3,//1
        SUSHISWAP_V2//2
    }

    struct FlashLoanData {
        address flashToken;
        uint256 flashAmount;
        address caller;
        address[] path;
        uint24 v3Fee;
        uint8[] exchRoute;
        uint256 balanceBefore;
    }

    event FlashLoan(address token, uint256 amount);
    event SwapExecuted(uint8 exchange, uint256 amountIn, uint256 amountOut);

    constructor() payable {}

    function getFlashloan(
        address flashToken,
        uint256 flashAmount,
        address[] memory path,
        uint24 v3Fee,
        uint8[] memory exchRoute
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
            amountOut = PlaceSwap(userData.path, amountIn, userData.exchRoute[i], userData.v3Fee, i);
            if (amountOut == 0) {
                console.log("Swap failed, aborting arbitrage");
                return 0;
            }
            amountIn = amountOut;
            console.log("Completed swap on Exchange: ", userData.exchRoute[i], " amountOut: ", amountOut);
        }
    
        return amountOut > flashAmount ? amountOut - flashAmount : 0;
    }
    
    function PlaceSwap(address[] memory _tokenPath, uint256 _amountIn, uint8 _route, uint24 _v3Fee, uint256 swapIndex) private returns(uint256) {
        console.log("Placing swap on exchange: ", _route);
        address router = getRouterAddress(_route);
        IERC20(_tokenPath[swapIndex]).approve(router, _amountIn);
        uint256 deadline = block.timestamp + 300; // 5 minutes
        uint256 amountOutMin = 0;
        uint256 amountOut;
    
        if (_route == uint8(Exchange.UNISWAP_V2) || _route == uint8(Exchange.SUSHISWAP_V2)) {
            address[] memory path = new address[](2);
            path[0] = _tokenPath[swapIndex];
            path[1] = _tokenPath[swapIndex + 1];
            try IUniswapV2Router02(router).swapExactTokensForTokens(
                _amountIn,
                amountOutMin,
                path,
                address(this),
                deadline
            ) returns (uint256[] memory amounts) {
                amountOut = amounts[amounts.length - 1];
                emit SwapExecuted(_route, _amountIn, amountOut);
                return amountOut;
            } catch Error(string memory reason) {
                console.log("Swap failed. Reason: ", reason);
                return 0;
            } catch (bytes memory lowLevelData) {
                console.log("Swap failed. Low-level error: ");
                console.logBytes(lowLevelData);
                return 0;
            }
        } else {
            try ISwapRouter(router).exactInputSingle(ISwapRouter.ExactInputSingleParams({
                tokenIn: _tokenPath[swapIndex],
                tokenOut: _tokenPath[swapIndex + 1],
                fee: _v3Fee,
                recipient: address(this),
                deadline: deadline,
                amountIn: _amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })) returns (uint256 result) {
                amountOut = result;
                emit SwapExecuted(_route, _amountIn, amountOut);
                return amountOut;
            } catch Error(string memory reason) {
                console.log("Swap failed. Reason: ", reason);
                return 0;
            } catch (bytes memory lowLevelData) {
                console.log("Swap failed. Low-level error: ");
                console.logBytes(lowLevelData);
                return 0;
            }
        }
    }
    

    function getRouterAddress(uint8 _route) private view returns(address) {
        if (_route == uint8(Exchange.UNISWAP_V2)) return address(uniswapV2Router);
        if (_route == uint8(Exchange.UNISWAP_V3)) return address(uniswapV3Router);
        if (_route == uint8(Exchange.SUSHISWAP_V2)) return address(sushiSwapV2Router);
        revert("Invalid route");
    }
}
