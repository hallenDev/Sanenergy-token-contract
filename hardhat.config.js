require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('hardhat-deploy');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.13',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    avalanche: {
      chainId: 43114,
      url: process.env.AVALANCHE_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    fuji: {
      chainId: 43113,
      url: process.env.FUJI_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    BSC: {
      chainId: 56,
      url: process.env.BSC_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    BST_TEST: {
      chainId: 97,
      url: process.env.BSC_TEST_RPC_URL,
      accounts:[process.env.PRIVATE_KEY]
    }
  },
  namedAccounts: {
    account0: 0
  },
  etherscan: {
    apiKey: 'FRVGB2M4Q1DANURKWUVVWDFBEIG87NF1H2'
  }
};
