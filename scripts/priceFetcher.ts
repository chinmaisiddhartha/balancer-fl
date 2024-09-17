import { ethers } from 'ethers';
import { abi as IUniswapV3PoolABI } from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json';
import { abi as ERC20ABI } from '@openzeppelin/contracts/build/contracts/ERC20.json';
import dotenv from "dotenv";
import { log } from 'console';
dotenv.config();

const ETHEREUM_NODE_API_KEY = process.env.ETHEREUM_NODE_API_KEY;
const Q96 = 2n ** 96n;
const Q192 = Q96 * Q96;

function formatBigIntAsDecimal(value: BigInt, decimals: number): string {
    const valueString = value.toString();  // Convert BigInt to string
    const length = valueString.length;
  
    // Ensure decimals is handled as a regular number, not BigInt
    const decimalsNumber = Number(decimals);
  
    // If the value is smaller than the decimal places, pad with leading zeros
    if (length <= decimalsNumber) {
      const paddedValue = valueString.padStart(decimalsNumber, '0');
      return `0.${paddedValue}`;
    }
  
    // Insert the decimal point at the correct position
    const integerPart = valueString.slice(0, length - decimalsNumber);
    const decimalPart = valueString.slice(length - decimalsNumber);
    return `${integerPart}.${decimalPart}`;
  }
  
function getAmount0ForLiquidity(sqrtRatioAX96: bigint, sqrtRatioBX96: bigint, liquidity: bigint): bigint {
    if (sqrtRatioAX96 > sqrtRatioBX96) {
        [sqrtRatioAX96, sqrtRatioBX96] = [sqrtRatioBX96, sqrtRatioAX96];
    }
    return (liquidity * Q96 * (sqrtRatioBX96 - sqrtRatioAX96)) / sqrtRatioBX96 / sqrtRatioAX96;
}

function getAmount1ForLiquidity(sqrtRatioAX96: bigint, sqrtRatioBX96: bigint, liquidity: bigint): bigint {
    if (sqrtRatioAX96 > sqrtRatioBX96) {
        [sqrtRatioAX96, sqrtRatioBX96] = [sqrtRatioBX96, sqrtRatioAX96];
    }
    return (liquidity * (sqrtRatioBX96 - sqrtRatioAX96)) / Q96;
}

async function calculateAmounts(provider: ethers.JsonRpcProvider, poolAddress: string) {
    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, provider);
    const [sqrtPriceX96, tickCurrent] = await pool.slot0();
    const liquidity = await pool.liquidity();
    const tickSpacing = await pool.tickSpacing();

    const token0 = await pool.token0();
    console.log("token0 : ", token0);
    
    const token1 = await pool.token1();
    console.log("token1 : ", token1);

    const token0Contract = new ethers.Contract(token0, ERC20ABI, provider);
    const token1Contract = new ethers.Contract(token1, ERC20ABI, provider);

    const decimals0 = await token0Contract.decimals();
    console.log("token0 decimals : ", decimals0);
    
    const decimals1 = await token1Contract.decimals();
    console.log("token1 decimals : ", decimals1);
    

    const tickLower = tickCurrent - tickSpacing;
    const tickUpper = tickCurrent + tickSpacing;

    const sqrtPriceLowerX96 = BigInt(Math.floor(Math.sqrt(1.0001 ** Number(tickLower)) * 2 ** 96));
    const sqrtPriceUpperX96 = BigInt(Math.floor(Math.sqrt(1.0001 ** Number(tickUpper)) * 2 ** 96));

    const amount0 = getAmount0ForLiquidity(BigInt(sqrtPriceX96), sqrtPriceUpperX96, BigInt(liquidity));
    const amount1 = getAmount1ForLiquidity(sqrtPriceLowerX96, BigInt(sqrtPriceX96), BigInt(liquidity));
    
    const priceToken0inToken1 = ((BigInt(sqrtPriceX96) / Q96) ** BigInt(2)) * BigInt(10n ** BigInt(decimals0)) / BigInt(10n ** BigInt(decimals1));
    console.log("priceToken0inToken1 : ", priceToken0inToken1);
    
    const price0 = (BigInt(sqrtPriceX96) * BigInt(sqrtPriceX96) * BigInt(10n ** BigInt(decimals0))) / (Q192 * BigInt(10n ** BigInt(decimals1))); 
    const priceToken0InToken1Wei = (price0 * BigInt(10n ** BigInt(decimals1))).toString();
    const formattedPriceToken0InToken1 = formatBigIntAsDecimal(price0, decimals1);

    console.log("Formatted Price of token0 in value of token1: ", formattedPriceToken0InToken1);

    console.log("priceToken0InToken1Wei : ", priceToken0InToken1Wei);

    const priceToken1InToken0 = BigInt(10n ** BigInt(decimals0)) / price0;
    console.log("priceToken1InToken0 : ", priceToken1InToken0);
    
    const formattedPriceToken1InToken0 = formatBigIntAsDecimal(priceToken1InToken0, decimals0);

    console.log("Formatted Price of token0 in value of token1: ", formattedPriceToken1InToken0);

   


    const priceToken1InToken0Wei = (priceToken1InToken0 * BigInt(10n ** BigInt(decimals0))).toString();
    console.log("priceToken1InToken0Wei : ", priceToken1InToken0Wei);

    
    const price1 = (Q192 * 10n ** BigInt(decimals0)) / (BigInt(sqrtPriceX96) * BigInt(sqrtPriceX96) * BigInt(10n ** BigInt(decimals1)));
    
    return {
        amount0,
        amount1,
        sqrtPriceX96: BigInt(sqrtPriceX96),
        tickCurrent: BigInt(tickCurrent),
        tickLower: BigInt(tickLower),
        tickUpper: BigInt(tickUpper),
        price0,
        price1,
        liquidity: BigInt(liquidity)
    };
}

const provider = new ethers.JsonRpcProvider(`https://site1.moralis-nodes.com/eth/${ETHEREUM_NODE_API_KEY}`)
const poolAddress = '0xc7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b'; // WBTC/USDT pool

calculateAmounts(provider, poolAddress).then(console.log).catch(console.error);
