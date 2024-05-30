// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
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
    networks: {
        
        sepolia: {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            url: process.env.RPC_URL_SEPOLIA || RPC["sepolia"],
            accounts,
        },
        arbitrumsepolia: {
            eid: EndpointId.ARBSEP_V2_TESTNET,
            url: process.env.RPC_URL_ARBITRUMSEPOLIA || RPC["arbitrumsepolia"],
            accounts,
            gasMultiplier: 3,
        },
        opsepolia: {
            eid: EndpointId.OPTSEP_V2_TESTNET,
            url: process.env.RPC_URL_OPSEPOLIA || RPC["opsepolia"],
            accounts,
        },
        amoy: {
            eid: EndpointId.AMOY_V2_TESTNET,
            url: process.env.RPC_URL_AMOYSEPOLIA || RPC["amoy"],
            accounts,
          },
        mantlesepolia: {
            eid: EndpointId.MANTLESEP_V2_TESTNET,
            url: process.env.RPC_URL_MANTLESEPOLIA || RPC["mantlesepolia"],
            accounts,
            // gas: 2000000000000000,
        },
        basesepolia: {
            eid: EndpointId.BASESEP_V2_TESTNET,
            url: process.env.RPC_URL_BASESEPOLIA || RPC["basesepolia"],
            accounts,
        },
        orderlysepolia: {
            eid: EndpointId.ORDERLY_V2_TESTNET,
            url: process.env.RPC_URL_ORDERLYSEPOLIA || RPC["orderlysepolia"],
            accounts,
        },
        // mainnets
        ethereum: {
            url: process.env.RPC_URL_ETHEREUM || RPC["ethereum"],
            accounts,
        },
        arbitrum: {
            url: process.env.RPC_URL_ARBITRUM || RPC["arbitrum"],
            accounts,
        },
        optimism: {
            url: process.env.RPC_URL_OPTIMISM || RPC["optimism"],
            accounts,
        },
        polygon: {
            url: process.env.RPC_URL_POLYGON || RPC["polygon"],
            accounts,
        },
        base: {
            url: process.env.RPC_URL_BASE || RPC["base"],
            accounts,
        },
        mantle: {
            url: process.env.RPC_URL_MANTLE || RPC["mantle"],
            accounts,
        },
        orderly: {
            url: process.env.RPC_URL_ORDERLY || RPC["orderly"],
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
