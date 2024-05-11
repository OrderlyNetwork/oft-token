export type address = string
export type name = string
export type network = string
export type env = string


interface OFTContractAddress {
    [key: name]: address;
}
interface OFTNetwork {
    [key: network]: OFTContractAddress;
}
export interface OFTData {
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
export type TestNetworkName = 'sepolia' | 'arbitrumsepolia' | 'opsepolia' | 'amoy' | 'basesepolia' | 'mantlesepolia' |  'orderlysepolia'
export type MainNetworkName = 'ethereum' | 'arbitrum' | 'optimism' | 'polygon' | 'base' | 'mantle' | 'orderly'
export type OFTContractType = 'OrderToken' | 'OrderAdapter' | 'OrderOFT'

export const TEST_NETWORKS = ['sepolia', 'arbitrumsepolia', 'opsepolia', 'orderlysepolia']  //  'amoy', 'basesepolia', 'mantlesepolia', 
export const MAIN_NETWORKS = ['ethereum', 'arbitrum', 'optimism', 'polygon', 'base', 'mantle', 'orderly']

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

export function isERC20Network(network: network) {
    return network === TEST_NETWORKS[0] || network === MAIN_NETWORKS[0]
}

export const RPC: { [key: string]: string } = {
    // testnets
    "sepolia": "https://rpc.sepolia.org",
    "arbitrumsepolia": "https://arbitrum-sepolia.blockpi.network/v1/rpc/public",
    "opsepolia": "https://sepolia.optimism.io",
    "amoy": "https://polygon-amoy-bor-rpc.publicnode.com",
    "basesepolia": "https://base-sepolia-rpc.publicnode.com",
    "mantlesepolia": "https://rpc.sepolia.mantle.xyz",
    "orderlysepolia": "https://testnet-rpc.orderly.org/8jbWg77mA6PCwHe13tEiv6rFqT1UJLPEB",
    // mainnets
    "ethereum": "",
    "arbitrum": "",
    "optimism": "",
    "polygon": "",
    "base": "",
    "mantle": "",
    "orderly": "",
}