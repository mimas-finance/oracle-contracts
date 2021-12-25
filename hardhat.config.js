require("dotenv").config();
require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.6.6",
    settings: {
      optimizer: {
        enabled: true
      }
    }
  },
  networks: {
    testnet: {
      url: "https://cronos-testnet-3.crypto.org:8545",
      accounts: [`0x${process.env.DEPLOY_TESTNET_PRIVATE_KEY}`],
      timeout: 200000,
    },
    mainnet: {
      url: "https://evm-cronos.crypto.org",
      accounts: [`0x${process.env.DEPLOY_MAINNET_PRIVATE_KEY}`],
      timeout: 200000,
    }
  }
};
