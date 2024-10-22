import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-ethers";
import * as dotenv from "dotenv";

dotenv.config();

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;
const ETHEREUM_NODE_API_KEY = process.env.ETHEREUM_NODE_API_KEY;
const BSC_NODE_API_KEY = process.env.BSC_NODE_API_KEY;
const POLYGON_NODE_API_KEY = process.env.POLYGON_NODE_API_KEY;
const BASE_NODE_API_KEY = process.env.BASE_NODE_API_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true
        }
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true
        }
      }
    ]
  },
  networks: {
    mainnet: {
      url: `https://site1.moralis-nodes.com/eth/${ETHEREUM_NODE_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    polygon: {
      url: `https://site1.moralis-nodes.com/polygon/${POLYGON_NODE_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    bsc: {
      url: `https://site1.moralis-nodes.com/bsc/${BSC_NODE_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    base: {
      url: `https://site1.moralis-nodes.com/base/${BASE_NODE_API_KEY}`,
      accounts: [PRIVATE_KEY]
    },
    hardhat: {
      forking: {
        url: `https://site1.moralis-nodes.com/eth/${ETHEREUM_NODE_API_KEY}`,
        // url: `https://site1.moralis-nodes.com/base/${BASE_NODE_API_KEY}`,
        // blockNumber: 19155559 // Optional: Specify a block number to fork from
      }
    }
  },
  ignition: {
    // Ignition configuration (if needed)
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};
export default config;





/**
 * 

   

 */