// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import "@nomicfoundation/hardhat-verify";
import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'
import { RPC } from './tasks/const'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import "./tasks/tasks"
// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.20',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    etherscan: {
        apiKey: {
            fuji: "snowtrace",
        },
        customChains: [
            {
                network: "fuji",
                chainId: 43113,
                urls: {
                    apiURL: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
                    browserURL: "https://testnet.snowtrace.io/"
                }
            }
        ],
    },
    sourcify: {
        enabled: true,
    },
    networks: {
        
        sepolia: {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            url: process.env.SEPOLIA_RPC_URL || RPC["sepolia"],
            accounts,
        },
        arbitrumsepolia: {
            eid: EndpointId.ARBSEP_V2_TESTNET,
            url: process.env.ARBITRUMSEPOLIA_RPC_URL || RPC["arbitrumsepolia"],
            accounts,
        },
        opsepolia: {
            eid: EndpointId.OPTSEP_V2_TESTNET,
            url: process.env.OPSEPOLIA_RPC_URL || RPC["opsepolia"],
            accounts,
        },
        amoy: {
            eid: EndpointId.AMOY_V2_TESTNET,
            url: process.env.AMOYSEPOLIA_RPC_URL || RPC["amoy"],
            accounts,
          },
        mantlesepolia: {
            eid: EndpointId.MANTLESEP_V2_TESTNET,
            url: process.env.MANTLESEPOLIA_RPC_URL || RPC["mantlesepolia"],
            accounts,
        },
        basesepolia: {
            eid: EndpointId.BASESEP_V2_TESTNET,
            url: process.env.BASESEPOLIA_RPC_URL || RPC["basesepolia"],
            accounts,
        },
        fuji: {
            eid: EndpointId.AVALANCHE_V2_TESTNET,
            url: process.env.FUJI_RPC_URL || RPC["fuji"],
            accounts,
        },
        orderlysepolia: {
            eid: EndpointId.ORDERLY_V2_TESTNET,
            url: process.env.ORDERLYSEPOLIA_RPC_URL || RPC["orderlysepolia"], //   "https://testnet-rpc.orderly.org/8jbWg77mA6PCwHe13tEiv6rFqT1UJLPEB"
            accounts,
        },
        // mainnets
        ethereum: {
            eid: EndpointId.ETHEREUM_MAINNET,
            url: process.env.ETHEREUM_RPC_URL || RPC["ethereum"],
            accounts,
        },
        arbitrum: {
            eid: EndpointId.ARBITRUM_MAINNET,
            url: process.env.ARBITRUM_RPC_URL || RPC["arbitrum"],
            accounts,
        },
        optimism: {
            eid: EndpointId.OPTIMISM_MAINNET,
            url: process.env.OPTIMISM_RPC_URL || RPC["optimism"],
            accounts,
        },
        polygon: {
            eid: EndpointId.POLYGON_MAINNET,
            url: process.env.POLYGON_RPC_URL || RPC["polygon"],
            accounts,
        },
        base: {
            eid: EndpointId.BASE_MAINNET,
            url: process.env.BASE_RPC_URL || RPC["base"],
            accounts,
        },
        mantle: {
            eid: EndpointId.MANTLE_MAINNET,
            url: process.env.MANTLE_RPC_URL || RPC["mantle"],
            accounts,
        },
        avax: {
            eid: EndpointId.AVALANCHE_MAINNET,
            url: process.env.AVAX_RPC_URL || RPC["avax"],
            accounts,
        },
        orderly: {
            eid: EndpointId.ORDERLY_MAINNET,
            url: process.env.ORDERLY_RPC_URL || RPC["orderly"],
            accounts,
        }
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
}

export default config
