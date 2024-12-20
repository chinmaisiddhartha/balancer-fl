// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./utils/V2Swap.sol";
import "./utils/V3Swap.sol";
import "./utils/P3Swap.sol";
import "./utils/CLSwap.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "hardhat/console.sol";
contract Arbitrage is IFlashLoanRecipient, V2Swap, V3Swap, P3Swap, CLSwap {
    IVault public constant vault =
    IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address immutable owner;

    bytes32 public immutable DOMAIN_SEPARATOR;
        
    uint256 public constant REVEAL_DELAY = 1;
    uint256 public constant MIN_PRIORITY_FEE = 3 gwei;
    uint256 public constant TIME_LOCK = 1 minutes;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => uint256) public pendingTrades;

    enum Exchange {
            V2, // uniswap v2 and all it's forks
            V3, // uniswap v3
            P3, // pancake v3
            CL // Aerodrome :: only base blockchain
    }

    struct FlashLoanData {
        address flashToken;
        uint256 flashAmount;
        address caller;
        address[] path;
        uint8[] exchRoute;
        address[] pools;
        uint256 balanceBefore;
    }

    event FlashLoan(address token, uint256 amount);
    event SwapExecuted(uint8 exchange, uint256 amountIn, uint256 amountOut);
    event SwapStarted(
        uint8 exchange,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address pool
    );
    event FlashLoanReceived(
        uint256 amount,
        uint256 fee,
        uint256 balanceAfter
    );
    event ArbitrageAttempt(
        uint256 startAmount,
        uint256 finalAmount,
        bool profitable,
        uint256 profit
    );

    event CommitmentSubmitted(bytes32 indexed commitment);
    event TradeQueued(bytes32 indexed tradeHash);


    constructor() payable {
        owner = msg.sender;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            "Arbitrage",
            "1",
            block.chainid,
            address(this)
        ));
    }

    receive() external payable {}

    modifier withPrivateMempool() {
        require(tx.gasprice >= block.basefee + MIN_PRIORITY_FEE, "Low priority fee");
        require(tx.origin == msg.sender, "No flashbots");
        _;
    }

    function commit(bytes32 commitment) external {
        commitments[commitment] = true;
        emit CommitmentSubmitted(commitment);
    }

    function queueTrade(bytes32 tradeHash) external {
        pendingTrades[tradeHash] = block.timestamp + TIME_LOCK;
        emit TradeQueued(tradeHash);
    }

    function getFlashloanWithSubmarine(
        address flashToken,
        uint256 flashAmount,
        address[] calldata path,
        uint8[] calldata exchRoute,
        address[] calldata pools,
        bytes32 salt
    ) external withPrivateMempool {
        bytes32 commitment = keccak256(abi.encode(
            flashToken,
            flashAmount,
            path,
            exchRoute,
            pools,
            salt,
            msg.sender
        ));
        
        require(commitments[commitment], "Invalid commitment");
        require(block.number >= REVEAL_DELAY, "Too early");
        delete commitments[commitment];
        
        getFlashloan(flashToken, flashAmount, path, exchRoute, pools);
    }

    function getFlashloan(
        address flashToken,
        uint256 flashAmount,
        address[] calldata path,
        uint8[] calldata exchRoute,
        address[] calldata pools
    ) internal withPrivateMempool {
        uint256 balanceBefore = IERC20(flashToken).balanceOf(address(this));
        // console.log("Balance before flashloan: ", balanceBefore);

        FlashLoanData memory flashLoanData = FlashLoanData({
            flashToken: flashToken,
            flashAmount: flashAmount,
            caller: msg.sender,
            path: path,
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
        require(tokens.length == 1, "Only single token flashloans supported");

        FlashLoanData memory decoded = abi.decode(userData, (FlashLoanData));
        uint256 balanceAfter = tokens[0].balanceOf(address(this));
        console.log("FlashLoan received: ", amounts[0], "Balance after FL: ", balanceAfter);

        emit FlashLoanReceived(amounts[0], feeAmounts[0], balanceAfter);

        require(
            balanceAfter - decoded.balanceBefore >= amounts[0],
            "Arbitrage: Contract did not get loan"
        );

        uint256 profit = executeArbitrage(decoded, amounts[0]);

        bool success = IERC20(decoded.flashToken).transfer(address(vault), amounts[0] + feeAmounts[0]);
        require(success, "Arbitrage: Transfer to Vault failed");

        emit ArbitrageAttempt( amounts[0], balanceAfter , profit > 0, profit );
        
        if (profit > 0) {
            success = IERC20(decoded.flashToken).transfer(decoded.caller, profit);
            require(success, "Arbitrage: Profit Transfer to caller failed");
        }

        emit FlashLoan(decoded.flashToken, amounts[0]);
    }

    function executeArbitrage(FlashLoanData memory userData, uint256 flashAmount) private returns (uint256) {
        // console.log("Executing arbitrage...");
        uint256 currentAmount = flashAmount;
        address currentToken = userData.flashToken;
        
        uint256 routeLength = userData.exchRoute.length;
        for (uint i = 0; i < routeLength;) {
            console.log("Executing arbitrage on exchange: ", userData.exchRoute[i]);
            (uint256 amountOut, address tokenOut) = placeSwap(userData.path, currentAmount, userData.exchRoute[i], i, userData.pools[i]);
            console.log("Swap completed. Amount in: ", currentAmount, " Amount out: ", amountOut);
            currentAmount = amountOut;
            currentToken = tokenOut;
            unchecked { ++i;}
        }

        console.log("Final amount: ", currentAmount, " Flash loan amount: ", flashAmount);
        if (currentAmount > flashAmount) {
        unchecked {
            uint256 profit = currentAmount - flashAmount;
               console.log("Profit: ", profit);
            return profit;
        }
        } else {
            console.log("No profit. Final amount: ", currentAmount, " Flash loan amount: ", flashAmount);
            return 0;
        }
    }


    function placeSwap(address[] memory _tokenPath, uint256 _amountIn, uint8 _route, uint256 swapIndex, address pool) private returns(uint256 amountOut, address) {
        console.log("Placing swap on exchange: ", _route);
        emit SwapStarted(_route, _amountIn, _tokenPath[swapIndex], _tokenPath[swapIndex + 1], pool);
    
        uint256 minAmountOut;
        address tokenOut = _tokenPath[swapIndex + 1];

        address[] memory path = new address[](2);
        path[0] = _tokenPath[swapIndex];
        path[1] = _tokenPath[swapIndex + 1];

        // console.log("token Path is : ", path[0], " ", path[1]);

        bool isInput0 = path[0] < path[1];

        // console.log("tokenIn balance of smart contract before swap:",IERC20(path[0]).balanceOf(address(this)));
        // console.log("tokenOut balance of smart contract before swap:", IERC20(path[1]).balanceOf(address(this)));
        // console.log("");
    

        if (_route == uint8(Exchange.V2)) {
            minAmountOut = v2MinAmountOut(pool, _amountIn, isInput0);
            uint256[] memory amounts = swapV2(pool, _amountIn, minAmountOut, path, address(this));
            amountOut = amounts[1];
        } else if (_route == uint8(Exchange.V3))  {
            minAmountOut = calculateV3MinAmountOut(pool, _amountIn, path[0]);
            amountOut = swapV3(pool, _amountIn, minAmountOut, path[0], address(this));
        } else if (_route == uint8(Exchange.P3)) { 
            minAmountOut = calculateP3MinAmountOut(pool, _amountIn, path[0]);
            amountOut = swapP3(pool, _amountIn, minAmountOut, path[0], address(this));
        } else if (_route == uint8(Exchange.CL)) {
            minAmountOut = calculateCLMinAmountOut(pool, _amountIn, path[0]);
            amountOut = swapCL(pool, _amountIn, minAmountOut, path[0], address(this));
        }
        console.log("swap executed on exchange:", _route);
        // console.log("tokenIn balance of smart contract after swap:",IERC20(path[0]).balanceOf(address(this)));
        // console.log("tokenOut balance of smart contract after swap:", IERC20(tokenOut).balanceOf(address(this)));
        
        emit SwapExecuted(_route, _amountIn, amountOut);
        return (amountOut, tokenOut);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data 
    ) external override(V3Swap, CLSwap){
        require(msg.sender == address(IUniswapV3Pool(msg.sender)), "Unauthorized callback");
        // console.log("Authorized callback msg.sender : ", address(IUniswapV3Pool(msg.sender)));
        // console.log("noramal msg.sender v3 call back top line is : ", msg.sender);
        (address tokenIn, address tokenOut, uint256 amountIn) = abi.decode(data, (address, address, uint256));
        require(tokenOut != address(0), "Invalid token out");
        uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        require(amountToPay <= amountIn, "Insufficient input amount");

        TransferHelper.safeTransfer(tokenIn, msg.sender, amountToPay);
        // console.log("last msg.sender in callback: ", msg.sender);
    }

    function withdrawTokens(address token) public  {
        require(msg.sender == owner, "Only the owner can withdraw");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        bool success = IERC20(token).transfer(msg.sender, balance);
        require(success, "Token withdrawal failed");
    }

    function withdrawEth() public {
        require(msg.sender == owner, "Only the owner can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "ETH withdrawal failed");
    }

    function v2MinAmountOut(address pool, uint256 amountIn, bool isInput0) internal view returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pool).getReserves();
            uint256 _amountOut = getAmountOut(amountIn, isInput0 ? reserve0 : reserve1, isInput0 ? reserve1 : reserve0);
            console.log("V2 expected amountOut:", _amountOut);
            uint256 amountOutMin = (_amountOut * 999) / 1000; // 0.1% slippage tolerance
            console.log("V2 amountOutMin:", amountOutMin);
            return amountOutMin;
    }

    function calculateV3MinAmountOut(
        address pool,
        uint256 amountIn,
        address tokenIn
    ) internal view returns (uint256) {
        IUniswapV3Pool v3Pool = IUniswapV3Pool(pool);
        (uint160 sqrtPriceX96, , , , , , ) = v3Pool.slot0();
        bool zeroForOne = tokenIn == v3Pool.token0();
        uint256 expectedOut = estimateV3Output(sqrtPriceX96, amountIn, zeroForOne);

        // Apply slippage
        uint256 amountOutMin = (expectedOut * 95) / 100; // 0.44% slippage tolerance
        console.log("Uni V3 expected amount Out:", expectedOut);
        console.log("Uni V3 amount out min:", amountOutMin);
        return amountOutMin;
    }

    function calculateP3MinAmountOut(
        address pool,
        uint256 amountIn,
        address tokenIn
    ) internal view returns (uint256) {
        IPancakeV3Pool p3Pool = IPancakeV3Pool(pool);
        (uint160 sqrtPriceX96, , , , , , ) = p3Pool.slot0();
        bool zeroForOne = tokenIn == p3Pool.token0();

        uint256 expectedOut = estimateV3Output(sqrtPriceX96, amountIn, zeroForOne);

        // Apply slippage
        uint256 amountOutMin = (expectedOut * 95) / 100; // 0.33% slippage tolerance
        console.log("Pancake V3 expected amount Out:", expectedOut);
        console.log("Pancake V3 amount out min:", amountOutMin);
        return amountOutMin;
    }

    function calculateCLMinAmountOut(
        address pool,
        uint256 amountIn,
        address tokenIn
    ) internal view returns (uint256) {
        ICLPool clPool = ICLPool(pool);
        (uint160 sqrtPriceX96, , , , , ) = clPool.slot0();
        bool zeroForOne = tokenIn == clPool.token0();
        uint256 expectedOut = estimateV3Output(sqrtPriceX96, amountIn, zeroForOne);

        // Apply slippage
        uint256 amountOutMin = (expectedOut * 95) / 100; // 0.33% slippage tolerance
        console.log("CL Swap expected amount Out:", expectedOut);
        console.log("CL Swap amount out Minimum:", amountOutMin);
        return amountOutMin;
    }

    // Function to estimate V3 output based on pool state (simplified)
    function estimateV3Output(
        uint160 sqrtPriceX96,
        uint256 amountIn,
        bool isInput0
    ) internal pure returns (uint256) {
        require(sqrtPriceX96 > 0, "Invalid sqrt price");
        
        // Calculate price with better precision
        uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        require(price > 0, "Invalid price calculation");
        
        if (isInput0) {
            // token0 to token1
            return (amountIn * uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        } else {
            // token1 to token0
            return (amountIn << 192) / (uint256(sqrtPriceX96) * uint256(sqrtPriceX96));
        }
    }
    
    



}





