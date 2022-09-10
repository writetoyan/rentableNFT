
const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

module.exports = {

  

  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },

    mainnet_fork: {
      host: "127.0.0.1",     
      port: 8545,           
      network_id: "1",      
    },

    kovan:{
      provider : function() { return new HDWalletProvider({mnemonic:{phrase:`${process.env.MNEMONIC}`},providerOrUrl:`wss://kovan.infura.io/ws/v3/${process.env.INFURA_ID}`})},
      network_id:42,
    },

//    ropsten:{
//      provider : function() { return new HDWalletProvider({mnemonic:{phrase:`${process.env.MNEMONIC}`}, providerOrUrl:`https://ropsten.infura.io/v3/${process.env.INFURA_ID}`})},
//      network_id:3,
//    }

  },

  plugins: ["solidity-coverage"],

  // Set default mocha options here, use special reporters, etc.
  mocha: {
    // timeout: 100000
    //  reporter: 'eth-gas-reporter',
    //  reporterOptions : { 
    //    gasPrice:1,
    //    token:'ETH',
    //    showTimeSpent: true,
    //    coinmarketcap: 'be6197c7-1c94-4f24-b4c5-ec1fb6351898',
    // }
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.17",      // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
       settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: false,
          runs: 200
        },
      //  evmVersion: "byzantium"
       }
    }
  },

};
