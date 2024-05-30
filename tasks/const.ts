import { MainnetV2EndpointId, TestnetV2EndpointId, Chain, ENVIRONMENT} from '@layerzerolabs/lz-definitions'

export type address = string
export type name = string
export type network = string
export type env = string


interface OFTContractAddress {
    [key: name]: address;
}interface OFTNetwork {
    [key: network]: OFTContractAddress;
}export interface OFTData {
    [key: env]: OFTNetwork;
}

interface OFTTo {
    [key: network]: boolean;
}
interface OFTFrom {
    [key: network]: OFTTo;
}
export interface OFTPeers {
    [key: env]: OFTFrom;
}

interface LZData {
    [key: string]: string;

}
export interface LZConfig {
    [key: network]: LZData
}

export type EnvType = 'dev' | 'qa' | 'staging' | 'mainnet'
export type VaultNetworkType = 'arbitrum' | 'optimism' | 'polygon' | 'base' | 'mantle'
export type TestNetworkType = 'sepolia' | 'arbitrumsepolia' | 'opsepolia' | 'amoy' | 'basesepolia' | 'mantlesepolia' |  'orderlysepolia'
export type MainNetworkType = 'ethereum' | 'arbitrum' | 'optimism' | 'polygon' | 'base' | 'mantle' | 'orderly'
export type AllNetworkType = TestNetworkType | MainNetworkType
export type OFTContractType = 'OrderToken' | 'OrderAdapter' | 'OrderOFT' | 'OrderSafe' | 'OrderBox' | 'OrderSafeRelayer' | 'OrderBoxRelayer'

export const TEST_NETWORKS = ['sepolia', 'arbitrumsepolia', 'opsepolia', 'amoy', 'basesepolia', 'orderlysepolia']  //   ,  
export const MAIN_NETWORKS = ['ethereum', 'arbitrum', 'optimism', 'polygon', 'base', 'mantle', 'orderly']
export const OPTIONS = {
    "1": {
        "gas": 55000,
        "value": 0
    },
    "2": {
        "gas": 150000,
        "value": 0
    }
}

export const RPC: { [key: network]: string } = {
    // testnets
    "sepolia": "https://rpc.sepolia.org",
    "arbitrumsepolia": "https://public.stackup.sh/api/v1/node/arbitrum-sepolia",
    "opsepolia": "https://endpoints.omniatech.io/v1/op/sepolia/public",
    "amoy": "https://polygon-amoy-bor-rpc.publicnode.com",
    "basesepolia": "https://base-sepolia-rpc.publicnode.com",
    "mantlesepolia": "https://rpc.testnet.mantle.xyz",
    "orderlysepolia": "https://testnet-rpc.orderly.org/8jbWg77mA6PCwHe13tEiv6rFqT1UJLPEB",
    // mainnets
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "optimism": "https://optimism.publicnode.com",
    "polygon": "https://polygon-bor.publicnode.com",
    "base": "https://base-rpc.publicnode.com",
    "mantle": "https://mantle-rpc.publicnode.com",
    "orderly": "https://rpc.orderly.network",
}

export function getRPC(network: network) {
    if (!supportedNetwork(network)) {
        throw new Error(`Network ${network} is not supported`)
    }
    return RPC[network]
}

type LzConfig = {
    endpointAddress: address,
    endpointId: number,
    chainId: number,
}

// For most testnets/mainnets, the endpoint is the follow one, but need to check the actual endpoint under this doc https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
const TEST_LZ_ENDPOINT = "0x6EDCE65403992e310A62460808c4b910D972f10f"
const MAIN_LZ_ENDPOINT = "0x1a44076050125825900e736c501f859c50fE728c"

export const LZ_CONFIG: { [key: network]: LzConfig} = {
    // lz config for testnets
    "sepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.SEPOLIA_V2_TESTNET,
        chainId: 11155111,
    },
    "arbitrumsepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.ARBSEP_V2_TESTNET,
        chainId: 421614,
    },
    "opsepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.OPTSEP_V2_TESTNET,
        chainId: 11155420,
    },
    "amoy": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.AMOY_V2_TESTNET,
        chainId: 80002,
    },
    "basesepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.BASESEP_V2_TESTNET,
        chainId: 84532,
    },
    "mantlesepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.MANTLESEP_V2_TESTNET,
        chainId: 5003,
    },
    "orderlysepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.ORDERLY_V2_TESTNET,
        chainId: 4460,
    },
    // lz config for mainnets
    "ethereum": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.ETHEREUM_V2_MAINNET,
        chainId: 1,
    },
    "arbitrum": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.ARBITRUM_V2_MAINNET,
        chainId: 42161,
    },
    "optimism": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.OPTIMISM_V2_MAINNET,
        chainId: 10,
    },
    "polygon": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.POLYGON_V2_MAINNET,
        chainId: 137,
    },
    "base": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.BASE_V2_MAINNET,
        chainId: 8453,
    },
    "mantle": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.MANTLE_V2_MAINNET,
        chainId: 5000,
    },
    "orderly": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.ORDERLY_V2_MAINNET,
        chainId: 291,
    },
}

export function getLzConfig(network: network): LzConfig {
    checkNetwork(network)
    return LZ_CONFIG[network]
}

export function tokenContractName(network: network) {
    if (isERC20Network(network)) {
        return 'OrderToken'
    } else {
        return 'OrderOFT'
    }
}

export function oftContractName(network: network) {
    if (isERC20Network(network)) {
        return 'OrderAdapter'
    } else {
        return 'OrderOFT'
    }
}

// Check if the network is where the ERC20 token is deployed to
// The ERC20 token is deployed to the sepolia and ethereum network
export function isERC20Network(network: network) {
    return network === TEST_NETWORKS[0] || network === MAIN_NETWORKS[0]
}

// Check if the network is where the OFT token is deployed to
export function supportedNetwork(network: network) {
    return TEST_NETWORKS.includes(network) || MAIN_NETWORKS.includes(network)
}

export function checkNetwork(network: string) {
    if (TEST_NETWORKS.includes(network) || MAIN_NETWORKS.includes(network)) {
        return true
    } else {
        throw new Error(`Network ${network} is not supported`)
    }
}


