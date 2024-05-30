# Orderly Token Contract

> This project is to deploy ORDER token on Ethereum and its OFT version on other networks to enable the multi-chain token transfer within LayerZero V2 protocol.
> Only OFT and Adapter contracts are under mainly development, the OrderSafe(Relayer) and OrderBox(Relayer) contracts are used to test the Cross-Chain token transfer and message relay.

This project is built using Layerzero [dev-tool](https://github.com/LayerZero-Labs/devtools), which has integrated Hardhat and Foundry for development, testing and deployment.

This repo contains the Orderly Token contract in native ERC20 standard and its cooresponding [OFT version](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)to enable multi-chain token transfer within [LayerZero V2 protocol](https://github.com/LayerZero-Labs/LayerZero-v2).

To deploy and test this project, please excute follow the instructions first.

```
git clone repo_url
npm install
```

The contracts structure is as follows:

```
                    +-----------+   +-----------+                 +-----------+   +-----------+
                    |           |   |           |    LayerZero    |           |   |           |
                    |   ERC20   |   |    OFT    |-----------------|    OFT    |   |   ERC20   |
                    |           |   |           |                 |           |   |           |
                    +-----------+   +-----------+                 +-----------+   +-----------+
                          |               |                             |               |
                          |               |                             |               |
                          |               |                             |               |
                          |               |                             |               |
+----------+        +---------------------------+                 +---------------------------+        +----------+
|          |        |                           |                 |                           |        |          |
|OrderSafe |------- |     OrderSafeRelayer      |                 |      OrderBoxRelayer      | -------| OrderBox |
|          |        |                           |                 |                           |        |          |
+----------+        +---------------------------+                 +---------------------------+        +----------+
```

## Architecture

The project is structured as follows:

- contracts: Contains the OrderToken and OrderOFT contracts
- deployments: Contains the deployed results for the contracts, used for verification
- config: Contains the configuration for the deployed contracts addresses and peer relationship between OFT contracts
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
  order:bridge:send                     Send tokens to a specific address on a specific network
  order:deploy                          Deploys the contract to a specific network: OrderToken, OrderAdapter, OrderOFT, OrderSafeRelayer, OrderBoxRelayer, OrderSafe, OrderBox
  order:init                            Initializes the contract on a specific network: OrderSafe, OrderSafeRelayer, OrderBox, OrderBoxRelayer
  order:oft:distribute                  Distribute tokens to all OFT contracts on different networks
  order:oft:set                         Connect OFT contracs on different networks: OrderOFT, OrderAdapter
  order:print                           Prints the address of the OFT contract
  order:stake                           Send stakes to a specific address on a specific network
  order:test                            Used to test code snippets
  order:upgrade                         Upgrades the contract to a specific network: OrderSafe, OrderSafeRelayer, OrderBox, OrderBoxRelayer
  run                                   Runs a user-defined script after compiling the project
  size-contracts                        Output the size of compiled contracts
  sourcify                              submit contract source code to sourcify (https://sourcify.dev)
  test                                  Runs mocha tests
```

These tasks with the prefix `order:` are defined in the tasks folder, are used for Orderly network.

### Deploy Contracts

Before you can run the task to deplyment, you need to set up the `.env` file to specify the network and the private key for the deployment. Check the `.env.example` file for the reference.

All contracts are deployed with `create2` method, which means the contract address is determined by the contract bytecode and the `salt` value defined in the `.env` file. The `salt` value is used to generate the contract address deterministically.

> ~~[!WARNING]: OderToken, OrderOFT/OrderAdapter are non-upgradable contracts, so the deployment should be carefully considered.~~
> The OrderToken and OrderOFT contracts are deployed with UUPS pattern, which means the contract logic can be upgraded by the owner.

To deploy native ERC20 token contract on Ethereum:

```
// Compile the contracts
npx hardhat compile

// On Sepolia testnet
npx hardhat order:deploy --env dev --network sepolia --contract OrderToken
// On Ethereum mainnet
npx hardhat order:deploy --env mainnet --network ethereum --contract OrderToken
```

To deploy OFT Adapter contract on Ethereum:

```
// Compile the contracts
npx hardhat compile

// On Sepolia testnet
npx hardhat order:deploy --env dev --network sepolia --contract OrderAdapter
// On Ethereum mainnet
npx hardhat order:deploy --env mainnet --network ethereum --contract OrderAdapter
```

To deploy OFT contract on different chains

```
// Compile the contracts
npx hardhat compile

// On testnet
npx hardhat order:deploy --env dev --network arbitrumsepolia --contract OrderOFT
npx hardhat order:deploy --env dev --network opsepolia --contract OrderOFT
npx hardhat order:deploy --env dev --network amoy --contract OrderOFT
npx hardhat order:deploy --env dev --network basesepolia --contract OrderOFT
npx hardhat order:deploy --env dev --network orderlysepolia  --contract OrderOFT

// On mainnet
npx hardhat order:deploy --env mainnet --network arbitrum --contract OrderOFT
npx hardhat order:deploy --env mainnet --network optimism --contract OrderOFT
npx hardhat order:deploy --env mainnet --network polygon --contract OrderOFT
npx hardhat order:deploy --env mainnet --network base --contract OrderOFT
npx hardhat order:deploy --env mainnet --network orderly --contract OrderOFT
```

### Upgrade Contracts

To upgradee the contract, we can use the `order:upgrade` task to upgrade the contract on the specified network.

```
// npx hardhat order:upgrade --env envName --network networkName --contract contractName
// On testnet
npx hardhat order:upgrade --env dev --network sepolia --contract OrderAdapter
npx hardhat order:upgrade --env dev --network arbitrumsepolia --contract OrderOFT
npx hardhat order:upgrade --env dev --network opsepolia --contract OrderOFT
npx hardhat order:upgrade --env dev --network amoy --contract OrderOFT
npx hardhat order:upgrade --env dev --network basesepolia --contract OrderOFT
npx hardhat order:upgrade --env dev --network orderlysepolia --contract OrderOFT

// On mainnet
npx hardhat order:upgrade --env mainnet --network ethereum --contract OrderAdapter
npx hardhat order:upgrade --env mainnet --network arbitrum --contract OrderOFT
npx hardhat order:upgrade --env mainnet --network optimism --contract OrderOFT
npx hardhat order:upgrade --env mainnet --network polygon --contract OrderOFT
npx hardhat order:upgrade --env mainnet --network base --contract OrderOFT
npx hardhat order:upgrade --env mainnet --network orderly --contract OrderOFT
```

### Verify Contracts

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

### Peer Connection

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
// npx hardhat order:oft:set --env dev --network fromNetwork
npx hardhat order:oft:set --env dev --network sepolia
npx hardhat order:oft:set --env dev --network arbitrumsepolia
npx hardhat order:oft:set --env dev --network opsepolia
npx hardhat order:oft:set --env dev --network amoy
npx hardhat order:oft:set --env dev --network basesepolia
npx hardhat order:oft:set --env dev --network orderlysepolia
```

The task `order:oft:set` will try to connect the OFT(or Adapter) contract on the network specified in the `--network` parameter to the OFT contracts on other networks (Supported networks are defined by the `TEST_NETWORKS` or `MAIN_NETWORKS` in `tasks/const.ts`). The connection status will be recorded in the `config/oftPeers.json` file.

```
npx hardhat order:oft:set --env dev --network arbitrumsepolia

Running on arbitrumsepolia
Setting peer from arbitrumsepolia to sepolia with tx hash 0x18e8c44af4ae59b7be6669338d2faf653abc12a634e1c732cf7345a255819dd6
Setting peer from arbitrumsepolia to opsepolia with tx hash 0xcfced93bc51c9a2f0e4f09cd99b1a5752c84dd52870c7ccabbf4b8b8e3e7e7c5
Setting peer from arbitrumsepolia to orderlysepolia with tx hash 0x1d3fd4dd47c8b8f2fb9c06ffd78fc11bdbd48ac8515eb14643de1bb835791f27
```

After we have executed the `order:oft:set` task on each supported network, it is supposed that the OFT contracts on different networks are connected together. The transfer between any two of them is enabled.

### Token Transfer

> Notice: The very first token transfer should be executed on the network where the native ERC20 token is deployed (Sepolia or Ethereum). And to transfer from the ERC20 token to the OFT token, the task will try to approve the OrderAdapter contract to spend the token on behalf of the sender.

After OFT contracts deployed on other networks are connected together, there is no ORDER token on these networks. We can only initiate the token transfer from Sepolia/Ethereum to other networks through OFT Adapter contract.

```
npx hardhat order:oft:distribute --env dev --network sepolia --receiver 0xdd3287043493e0a08d2b348397554096728b459c --amount 1000000

Approving OrderAdapter to spend 1000000 on OrderToken with tx hash 0x76af63c37b1b8b76ec9bebc2cc577cc5455aceb0c29481e5f81aa9175eb7f274
Sending tokens from sepolia to arbitrumsepolia with tx hash 0x592da906d5724167d8f726a1f0dc3558c12cf334edc211e59a85c4073c31efa0
Approving OrderAdapter to spend 1000000 on OrderToken with tx hash 0x684943a0c9b200f4ca067db5a3bb07cd98ef0f7bfd9598db5bfd8f6f25d96dd8
Sending tokens from sepolia to opsepolia with tx hash 0xbcf41528934ad5b03d6d7016ebede1904c29f0226dac9a50f709d9d91791b163
Approving OrderAdapter to spend 1000000 on OrderToken with tx hash 0x61ea4d21053f4ea6587bb4a932566df192bfcf8f3a3e3b71513ecbaa7a327e30
Sending tokens from sepolia to orderlysepolia with tx hash 0xc25c6bfaef2feff535e0efe50c8d469d9a483df86d731dc8177e208d536551e1
```

To test the token transfer across chains, we can use `order:oft:send` task to send the token from one network to another network. The task is defined as follows:

```
// npx hardhat order:oft:send --env dev --network fromNetwork --dst-network toNetwork --receiver toAddress --amount amount

npx hardhat order:oft:send --env dev --network sepolia --dst-network orderlysepolia --receiver 0xdd3287043493e0a08d2b348397554096728b459c --amount 100

Running on sepolia
Approving OrderAdapter to spend 100 on OrderToken with tx hash 0xbf2b81d73a4007256e84ca2f8407fec4bcabda73aaeb6a63343382626264dbc1
Sending tokens from sepolia to orderlysepolia with tx hash 0x701678c3976f0c53c2169c771feea91d037abf82863d49a7a110dde2afcb2c8c
```

Using [LayerZero](https://testnet.layerzeroscan.com/tx/0x774db31149ba43cd85342bf654ff2fc884c8fe21863911f055a3e281dd9766aa) scan to monitor the token transfer status

## Cross-Chain Msg with Token Transfer

OFT protocal also supports the cross-chain message relay with token transfer. The message relay is enabled by adding composed message to the token transfer action (`send()` function of OFT contract).

```
struct SendParam {
uint32 dstEid; // Destination endpoint ID.
bytes32 to; // Recipient address.
uint256 amountLD; // Amount to send in local decimals.
uint256 minAmountLD; // Minimum amount to send in local decimals.
bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message.
bytes composeMsg; // The composed message for the send() operation.
bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations.
}
function send(
SendParam calldata \_sendParam,
MessagingFee calldata \_fee,
address \_refundAddress
)
```

The relayed message should be encoded as bytes before calling `send()` function, and will be sent to the `_sendParam.to` address on the destination network. The `_sendParam.to` contract must inherit the `ILayerZeroComposer` and implement its `lzCompose()` function to receive and decode the composed message.

```
function lzCompose(
address \_from,
bytes32 \_guid,
bytes calldata \_message,
address \_executor,
bytes calldata \_extraData
) public payable override {
bytes memory composeMsg = \_message.composeMsg();
uint32 srcEid = \_message.srcEid();
address remoteSender = OFTComposeMsgCodec.bytes32ToAddress(\_message.composeFrom());
require(
\_composeMsgSenderCheck(msg.sender, \_from, srcEid, remoteSender),
"OrderlyBox: composeMsg sender check failed"
);
(address staker, uint256 amount) = abi.decode(composeMsg, (address, uint256));
IERC20 token = IERC20(IOFT(oft).token());
token.safeTransfer(orderBox, amount);
IOrderBox(orderBox).stakeOrder(\_getChainId(srcEid), staker, amount);
}
```

### Contracts

All contracts related to the cross-chain message relay are defined in the `contracts/crosschain` folder.

- `OrderSafe.sol`: The contract to receive users' requests (stake or unstake) on vault side (Arb/OP networks), and trigger the token transfer to ledger side.
- `OrderSafeRelayer.sol`: The contract to work as the Cross-Chain Message Relayer for the OrderSafe contract. It should encode the composed message and send it to the OrderBox contract through OFT contract.

- `OrderBox.sol`: The contract to handle stake logic and controle the staked token on the ledger side (Orderly network).
- `OrderBoxRelayer.sol`: The contract to work as the Cross-Chain Message Relayer for the OrderBox contract. It should decode the composed message and trigger the stake action on the OrderBox contract.

Both `OrderSafeRelayer` and `OrderBoxRelayer` contracts should implement the `ILayerZeroComposer` interface and implement the `lzCompose()` function to receive and decode the composed message.

### Deployment

The contracts for Cross-Chain Message Relay are deployed using UUPS pattern with deterministic address.
To deploy the cross-chain message relay contracts, we can use the following commands:

```
npx hardhat compile

// On Vault side
npx hardhat order:deploy --env dev --network arbitrumsepolia --contract OrderSafeRelayer
npx hardhat order:deploy --env dev --network arbitrumsepolia --contract OrderSafe

// On Ledger side
npx hardhat order:deploy --env dev --network orderlysepolia --contract OrderBoxRelayer
npx hardhat order:deploy --env dev --network orderlysepolia --contract OrderBox
```

### Upgrade

To upgrade the cross-chain message relay contracts, we can use the `order:upgrade` task to upgrade the contract on the specified network.

```
npx hardhat order:upgrade --env dev --network arbitrumsepolia --contract OrderSafeRelayer
npx hardhat order:upgrade --env dev --network arbitrumsepolia --contract OrderSafe

npx hardhat order:upgrade --env dev --network orderlysepolia --contract OrderBoxRelayer
npx hardhat order:upgrade --env dev --network orderlysepolia --contract OrderBox
```

### Verification

```
// Verify SafeRelayer contract
npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderSafeRelayer" -n "arbitrumsepolia" -u $API_URL_ARBITRUMSEPOLIA -k $API_KEY_ARBITRUMSEPOLIA

// Verify Safe contract
npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderSafe" -n "arbitrumsepolia" -u $API_URL_ARBITRUMSEPOLIA -k $API_KEY_ARBITRUMSEPOLIA

// Verify BoxRelayer contract
npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderBoxRelayer" -n "orderlysepolia" -u $API_URL_ORDERLYSEPOLIA

// Verify Box contract
npx @layerzerolabs/verify-contract -d "./deployments" --contracts "OrderBox" -n "orderlysepolia" -u $API_URL_ORDERLYSEPOLIA
```

### Initializatino

Before running the task to initialize the contracts, you **must have deploy** all the four contracts (`OrderSafe, OrderSafeRelayer` on Vault side, `OrderBox, OrderBoxRelayer` on Ledger side) on the corresponding networks to generate the corresponding addresses.

```
npx hardhat order:init --env dev --network arbitrumsepolia --contract OrderSafeRelayer
npx hardhat order:init --env dev --network arbitrumsepolia --contract OrderSafe

npx hardhat order:init --env dev --network orderlysepolia --contract OrderBoxRelayer
npx hardhat order:init --env dev --network orderlysepolia --contract OrderBox

```

This `init` task will set correponding addresses on the contracts to enable the **TRUSTED** cross-chain message relay.

### Stake Token

To stake token on the ledger side, we can use the `stakeOrder` function on the `OrderSafe` contract. The `OrderSafe` contract will relay the token to `OrderSafeRelayer`, the later will call `send()` function on the OFT contract to send the token to the `OrderBoxRelayer` contract on the Ledger side and composed with a message to trigger stake action on Ledger side.

```

npx hardhat order:stake --env dev --amount 100 --network arbitrumsepolia
Running on arbitrumsepolia
Approving OrderSafe to spend 100 on OrderOFT with tx hash 0xa969eceae9be923231713d167cc1ef8dc0ab686866802237896b9e402315fb38
Sending tokens from arbitrumsepolia to orderlysepolia with tx hash 0x31f74192d1bd685e4b1bac36a433bd5d208fc43a660e57bf8f826579a43560d1

```

Through the [LayerZero](https://testnet.layerzeroscan.com/tx/0x31f74192d1bd685e4b1bac36a433bd5d208fc43a660e57bf8f826579a43560d1) scan to monitor the token transfer status.

- The [received tx](https://explorerl2new-orderly-l2-4460-sepolia-8tc3sd7dvy.t.conduit.xyz/tx/0xd06a8e7dd8373927c52b11a2e8d6a574c7ac90cb9aa508ca389a4539ea5789e1) on Orderly network
- The [composed tx](https://explorerl2new-orderly-l2-4460-sepolia-8tc3sd7dvy.t.conduit.xyz/tx/0x384d03949bf6cc7b3b01cbd232d40cc8c2c3fdeb8691a9e971cb1ec52771de6a) on Orderly network

```

```
