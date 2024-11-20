import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-gas-reporter";
import * as dotenv from "dotenv";

dotenv.config();

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;
const ETHEREUM_NODE_API_KEY = process.env.ETHEREUM_NODE_API_KEY;
const BSC_NODE_API_KEY = process.env.BSC_NODE_API_KEY;
const POLYGON_NODE_API_KEY = process.env.POLYGON_NODE_API_KEY;
const BASE_NODE_API_KEY = process.env.BASE_NODE_API_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const COIN_MARKETCAP_API_KEY = process.env.COIN_MARKETCAP_API_KEY;
const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY;
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
        // url: `https://site1.moralis-nodes.com/eth/${ETHEREUM_NODE_API_KEY}`,
        url: `https://site1.moralis-nodes.com/base/${BASE_NODE_API_KEY}`,
        // blockNumber: 22578295 // Optional: Specify a block number to fork from
      }
    }
  },
  ignition: {
    blockPollingInterval: 1_000,
    timeBeforeBumpingFees: 3 * 60 * 1_000,
    maxFeeBumps: 4,
    requiredConfirmations: 5
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 100
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY && BASESCAN_API_KEY
  },
  mocha: {
    timeout: 100000
  },
};export default config;




/**
 * 
  gasReporter: {
    enabled: true,
    currency: 'USD',
    token: "ETH",
    coinmarketcap: ETHERSCAN_API_KEY,
    gasPriceApi: {
      // Custom endpoints for each network's gas prices
      default: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
      polygon: "https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice",
      bsc: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice", 
      base: "https://api.basescan.org/api?module=proxy&action=eth_gasPrice"
    },
    showMethodSig: true,
    showTimeSpent: true,
    excludeContracts: [],
    src: "./contracts",
    outputFile: "gas-reports/full-gas-report.txt",
    noColors: true,
    // Network specific settings
    token: {
      ethereum: "ETH",
      polygon: "MATIC",
      bsc: "BNB",
      base: "ETH"
    },
    // Token prices in USD
    tokenPrice: {
      ETH: 2940,
      MATIC: 0.89,
      BNB: 308
    },
    // Gas limits per network
    gasLimit: {
      ethereum: 30000000,
      polygon: 30000000,
      bsc: 140000000,
      base: 30000000
    }
  }
   

 */