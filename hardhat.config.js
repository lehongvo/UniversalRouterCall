require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');
require('solidity-coverage');
require('dotenv').config();

const ETHERSCAN_API_KEY = "56FPTRJDCD3GA5491XPZRPIJRHR8VGK5NJ";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true
        }
      }
    ],
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    JOC: {
      url: `https://rpc-1.japanopenchain.org:8545`,
      chainId: 81,
      accounts: [process.env.PRIVATE_KEY]
    },
    JOCT: {
      url: `https://rpc-1.testnet.japanopenchain.org:8545`,
      chainId: 10081,
      accounts: [process.env.PRIVATE_KEY],
    },
    polygonAmoy: {
      url: `https://rpc-amoy.polygon.technology`,
      chainId: 80002,
      accounts: [process.env.PRIVATE_KEY],
    }
  },
  gasReporter: {
    enabled: true,
    currency: 'USD'
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: []
  },
  etherscan: {
    apiKey: {
      JOCT: process.env.JOCT_API_KEY,
      polygonAmoy: "YQ8MYAQT7MYZ1P1714K3AGTAHJUCPY8E62",
    },
    customChains: [
      {
        network: "JOCT",
        chainId: 10081,
        urls: {
          apiURL: process.env.API_URL,
          browserURL: process.env.BROWSER_URL
        },
      },
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        },
      }
    ]
  },
  coverage: {
    excludeContracts: ['Migrations'],
    skipFiles: ['test/']
  },
};