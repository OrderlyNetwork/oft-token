# Orderly Token Contract

This project is built using Layerzero [dev-tool](https://github.com/LayerZero-Labs/devtools), which has integrated Hardhat and Foundry for development, testing and deployment.

This repo contains the Orderly Token contract in native ERC20 standard and its cooresponding [OFT version](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)to enable multi-chain token transfer within [LayerZero V2 protocol](https://github.com/LayerZero-Labs/LayerZero-v2).

To deploy and test this project, please follow the instructions below.

```
git clone repo_url
npm install
```

## Architecture
The project is structured as follows:
- contracts: Contains the OrderToken and OrderOFT contracts
- deployments: Contains the deployed results for the contracts, used for verification
- config: Contains the configuration for Layerzero V2 and the deployed contracts addresses and peer relationship between OFT contracts
- tasks: Contains the tasks for deployment and the interactions with the contracts
- test: Contains the tests for the contracts
- `hardhat.config.js`: Contains the hardhat configuration

### Contracts

- `OrderToken.sol`: The native ERC20 token contract deployed on Ethereum mainnet and testnet.
- `OrderAdapter.sol`: The adapter contract to enable the multichain token transfer for ORDER token.
- `OrderOFT.sol`: The OFT version of the OrderToken contract, deployed on many other chains such as Orderly, Abitrum, Optimism, Polygon, Base, Mantle etc.

### Tasks
The very useful tasks are defined in the tasks folder, which can be used to deploy the contracts, interact with the contracts.

You can run `npx hardhat` to list all the available tasks:
```
AVAILABLE TASKS:

  check                                 Check whatever you need
  clean                                 Clears the cache and deletes all artifacts
  compile                               Compiles the entire project, building all artifacts
  console                               Opens a hardhat console
  deploy                                Deploy contracts
  etherscan-verify                      submit contract source code to etherscan
  export                                export contract deployment of the specified network into one file
  export-artifacts                
  flatten                               Flattens and prints contracts and their dependencies. If no file is passed, all the contracts in the project will be flattened.
  help                                  Prints this message
  order:bridge:token                    Send tokens to a specific address on a specific network
  order:deploy                          Deploys the contract to a specific network
  order:peer:init                       Initialize the network connections in oftPeers.json file
  order:peer:set                        Connect OFT contracs on different networks
  order:print                           Prints the address of the OFT contract
  run                                   Runs a user-defined script after compiling the project
  size-contracts                        Output the size of compiled contracts
  sourcify                              submit contract source code to sourcify (https://sourcify.dev)
  test                                  Runs mocha tests
```

These tasks with the prefix `order:` are defined in the tasks folder, are used for Orderly network.
#### Deploy Contracts

To deploy native ERC20 token contract on Ethereum

```
// On Sepolia testnet
npx hardhat order:deploy --network sepolia --env dev --contract OrderToken
// On Ethereum mainnet
npx hardhat order:deploy --network ethereum --env mainnet --contract OrderToken
```

To deploy OFT Adapter contract on Ethereum
```
// On Sepolia testnet
npx hardhat order:deploy --network sepolia --env dev --contract OrderAdapter
// On Ethereum mainnet
npx hardhat order:deploy --network ethereum --env mainnet --contract OrderAdapter
```

To deploy OFT contract on different chains
```
// On testnet
npx hardhat order:deploy --network arbitrumsepolia --env dev --contract OrderOFT
npx hardhat order:deploy --network opsepolia --env dev --contract OrderOFT
npx hardhat order:deploy --network amoy --env dev --contract OrderOFT
npx hardhat order:deploy --network basesepolia --env dev --contract OrderOFT
npx hardhat order:deploy --network mantlesepolia --env dev --contract OrderOFT
npx hardhat order:deploy --network orderlysepolia --env dev --contract OrderOFT

// On mainnet
npx hardhat order:deploy --network arbitrum --env mainnet --contract OrderOFT
npx hardhat order:deploy --network optimism --env mainnet --contract OrderOFT
npx hardhat order:deploy --network polygon --env mainnet --contract OrderOFT
npx hardhat order:deploy --network base --env mainnet --contract OrderOFT
npx hardhat order:deploy --network mantle --env mainnet --contract OrderOFT
npx hardhat order:deploy --network orderly --env mainnet --contract OrderOFT
```

#### Verify Contracts
```
npx @layerzerolabs/verify-contract --help


# cheatsheet
source .env
npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderToken" -n "sepolia" -u $API_URL_SEPOLIA -k $API_KEY_SEPOLIA 

npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderAdapter" -n "sepolia" -u $API_URL_SEPOLIA -k $API_KEY_SEPOLIA

npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderOFT" -n "arbitrumsepolia" -u $API_URL_ARBITRUMSEPOLIA -k $API_KEY_ARBITRUMSEPOLIA

npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderOFT" -n "opsepolia" -u $API_URL_OPSEPOLIA -k $API_KEY_OPSEPOLIA

npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderOFT" -n "amoy" -u $API_URL_AMOYSEPOLIA -k $API_KEY_AMOYSEPOLIA

npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderOFT" -n "basesepolia" -u $API_URL_BASESEPOLIA -k $API_KEY_BASESEPOLIA

npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderOFT" -n "mantlesepolia" -u $API_URL_MANTLESEPOLIA -k $API_KEY_MANTLESEPOLIA

npx @layerzerolabs/verify-contract -d "./deployments/" --contracts "OrderOFT" -n "orderlysepolia" -u $API_URL_ORDERLYSEPOLIA

```

#### Peer Connection

After we've deployed ERC20 contract + Adapter and OFT contracts, we need to connect them together to enable the multi-chain token transfer.

To give the maximum token tranfer flexibility, we can connect the OFT contracts on different networks together. That is to say, we can transfer the token from one supported network to another supported network. There are O(N^2) pathways for the token transfer between the OFT contracts on different networks.

`config/oftPeers.json` file is used to record the peer stutus between the OFT contracts on different networks. The file is structured as follows:
```
{
  "env: {
    "fromNetwork1": {
      "toNetwork1": true,
      "toNetwork2": false,
    }
  }
}
```

To connect an OFT contract on one network to other OFT contracts on other networks, we can run the following command:
```
// npx hardhat order:peer:set --env dev --network fromNetwork 
npx hardhat order:peer:set --env dev --network sepolia
```

The task `order:peer:set` will try to connect the OFT(or Adapter) contract on the network specified in the `--network` parameter to the OFT contracts on other networks (Supported networks are defined by the `TEST_NETWORKS` or `MAIN_NETWORKS` in `tasks/const.ts`). The connection status will be recorded in the `config/oftPeers.json` file.

After we have executed the `order:peer:set` task on each supported network, it is supposed that the OFT contracts on different networks are connected together. The transfer between any two of them is enabled.

#### Token Transfer

To test the token transfer between the OFT contracts on different networks, we can run the following command:
```
npx hardhat order:bridge:token --env dev --network fromNetwork --dst-network toNetwork --receiver toAddress --amount amount
```