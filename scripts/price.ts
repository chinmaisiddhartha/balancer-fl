import { ethers } from 'ethers';
import { abi as IUniswapV3PoolABI } from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json';
import { FullMath } from '@uniswap/v3-sdk';
import JSBI from 'jsbi';
import dotenv from "dotenv";

dotenv.config();

const ETHEREUM_NODE_API_KEY = process.env.ETHEREUM_NODE_API_KEY;

async function getPoolPrice(poolAddress: string) {
    const provider = new ethers.JsonRpcProvider(`https://site1.moralis-nodes.com/eth/${ETHEREUM_NODE_API_KEY}`);
    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, provider);

    const [token0, token1, fee, tickSpacing, liquidity, slot0] = await Promise.all([
        pool.token0(),
        pool.token1(),
        pool.fee(),
        pool.tickSpacing(),
        pool.liquidity(),
        pool.slot0()
    ]);

    const sqrtPriceX96 = JSBI.BigInt(slot0.sqrtPriceX96.toString());
    const tick = slot0.tick;

    const token0Contract = new ethers.Contract(token0, ['function decimals() view returns (uint8)'], provider);
    const token1Contract = new ethers.Contract(token1, ['function decimals() view returns (uint8)'], provider);
    const [decimals0, decimals1] = await Promise.all([token0Contract.decimals(), token1Contract.decimals()]);

    const price0 = JSBI.divide(JSBI.multiply(sqrtPriceX96, sqrtPriceX96), JSBI.exponentiate(JSBI.BigInt(2), JSBI.BigInt(192)));
    const price1 = JSBI.divide(JSBI.exponentiate(JSBI.BigInt(2), JSBI.BigInt(192)), JSBI.multiply(sqrtPriceX96, sqrtPriceX96));

    const adjustedPrice0 = Number(price0.toString()) / Number(Math.abs(Number(decimals1) - Number(decimals0)));
    const adjustedPrice1 = Number(price1.toString()) / Number(Math.abs(Number(decimals0) - Number(decimals1)));
    
    console.log(`Pool Address: ${poolAddress}`);
    console.log(`Token0: ${token0}`);
    console.log(`Token1: ${token1}`);
    console.log(`Price of Token1 in Token0: ${adjustedPrice0}`);
    console.log(`Price of Token0 in Token1: ${adjustedPrice1}`);
    console.log(`Current Tick: ${tick}`);
    console.log(`Liquidity: ${liquidity.toString()}`);
}

// Usage
const poolAddress = '0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640'; // USDC-ETH 0.05% pool
getPoolPrice(poolAddress).catch(console.error);
