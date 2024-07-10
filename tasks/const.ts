import { MainnetV2EndpointId, TestnetV2EndpointId, Chain, ENVIRONMENT} from '@layerzerolabs/lz-definitions'

export type address = string
export type name = string
export type network = string
export type env = string
export type dvns = address[]

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
export type TestNetworkType = 'sepolia' | 'arbitrumsepolia' | 'opsepolia' | 'amoy' | 'basesepolia' | 'mantlesepolia' | 'fuji' |  'orderlysepolia'
export type MainNetworkType = 'ethereum' | 'arbitrum' | 'optimism' | 'polygon' | 'base' | 'mantle' | 'avax' | 'orderly'
export type AllNetworkType = TestNetworkType | MainNetworkType
export type OFTContractType = 'OrderToken' | 'OrderAdapter' | 'OrderOFT' | 'OrderSafe' | 'OrderBox' | 'OrderSafeRelayer' | 'OrderBoxRelayer'

export const TEST_NETWORKS = ['sepolia', 'arbitrumsepolia', 'opsepolia', 'amoy', 'basesepolia', 'orderlysepolia']  //   'fuji',  
export const MAIN_NETWORKS = ['ethereum', 'arbitrum', 'optimism', 'polygon', 'base',   'orderly'] //'mantle', 'avax',
export const OPTIONS = {
    "1": {
        "gas": 50000,
        "value": 0
    },
    "2": {
        "gas": 100000,
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
    "fuji": "https://avalanche-fuji-c-chain-rpc.publicnode.com",
    "orderlysepolia": "https://testnet-rpc.orderly.org/8jbWg77mA6PCwHe13tEiv6rFqT1UJLPEB",
    // mainnets
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "optimism": "https://optimism.publicnode.com",
    "polygon": "https://polygon-bor.publicnode.com",
    "base": "https://base-rpc.publicnode.com",
    "mantle": "https://mantle-rpc.publicnode.com",
    "avax": "https://avalanche-c-chain-rpc.publicnode.com",
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
    sendLibConfig?: {
        sendLibAddress: address,
        executorConfig: {
            executorAddress: address,
            maxMessageSize?: number,
        },
        ulnConfig: {
            confirmations?: number, 
            requiredDVNCount?: number, 
            optionalDVNCount?: number, 
            optionalDVNThreshold?: number, 
            requiredDVNs: address[],
            optionalDVNs?: address[],
        }
    },
    receiveLibConfig?: {
        receiveLibAddress: address,
        gracePeriod?: number,
        ulnConfig: {
            confirmations?: number, 
            requiredDVNCount?: number, 
            optionalDVNCount?: number, 
            optionalDVNThreshold?: number, 
            requiredDVNs: address[],
            optionalDVNs?: address[],
        }
    }
}

type TgeContract = {
    occManager: address
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
        sendLibConfig: {
            sendLibAddress: "0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE",
            executorConfig: {
                executorAddress: "0x718B92b5CB0a5552039B593faF724D182A881eDA",
            },
            ulnConfig: {
                requiredDVNs: ["0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193"], //, 
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0xdAf00F5eE2158dD58E0d3857851c432E34A3A851",
            ulnConfig: {
                requiredDVNs: ["0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193"], // 
            }
        }
    },
    "arbitrumsepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.ARBSEP_V2_TESTNET,
        chainId: 421614,
        sendLibConfig: {
            sendLibAddress: "0x4f7cd4DA19ABB31b0eC98b9066B9e857B1bf9C0E",
            executorConfig: {
                executorAddress: "0x5Df3a1cEbBD9c8BA7F8dF51Fd632A9aef8308897",
            },
            ulnConfig: {
                requiredDVNs: ["0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x75Db67CDab2824970131D5aa9CECfC9F69c69636",
            ulnConfig: {
                requiredDVNs: ["0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8"],
            }
        }
    },
    "opsepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.OPTSEP_V2_TESTNET,
        chainId: 11155420,
        sendLibConfig: {
            sendLibAddress: "0xB31D2cb502E25B30C651842C7C3293c51Fe6d16f",
            executorConfig: {
                executorAddress: "0xDc0D68899405673b932F0DB7f8A49191491A5bcB",
            },
            ulnConfig: {
                requiredDVNs: ["0xd680ec569f269aa7015F7979b4f1239b5aa4582C"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x9284fd59B95b9143AF0b9795CAC16eb3C723C9Ca",
            ulnConfig: {
                requiredDVNs: ["0xd680ec569f269aa7015F7979b4f1239b5aa4582C"],
            }
        }
    },
    "amoy": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.AMOY_V2_TESTNET,
        chainId: 80002,
        sendLibConfig: {
            sendLibAddress: "0x1d186C560281B8F1AF831957ED5047fD3AB902F9",
            executorConfig: {
                executorAddress: "0x4Cf1B3Fa61465c2c907f82fC488B43223BA0CF93",
            },
            ulnConfig: {
                requiredDVNs: ["0x55c175DD5b039331dB251424538169D8495C18d1"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x53fd4C4fBBd53F6bC58CaE6704b92dB1f360A648",
            ulnConfig: {
                requiredDVNs: ["0x55c175DD5b039331dB251424538169D8495C18d1"],
            }
        }
    },
    "basesepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.BASESEP_V2_TESTNET,
        chainId: 84532,
        sendLibConfig: {
            sendLibAddress: "0xC1868e054425D378095A003EcbA3823a5D0135C9",
            executorConfig: {
                executorAddress: "0x8A3D588D9f6AC041476b094f97FF94ec30169d3D",
            },
            ulnConfig: {
                requiredDVNs: ["0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x12523de19dc41c91F7d2093E0CFbB76b17012C8d",
            ulnConfig: {
                requiredDVNs: ["0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6"],
            }
        }
    },
    "mantlesepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.MANTLESEP_V2_TESTNET,
        chainId: 5003,
    },
    "fuji": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.AVALANCHE_V2_TESTNET,
        chainId: 43113,
    },
    "orderlysepolia": {
        endpointAddress: TEST_LZ_ENDPOINT,
        endpointId: TestnetV2EndpointId.ORDERLY_V2_TESTNET,
        chainId: 4460,
        sendLibConfig: {
            sendLibAddress: "0x8e3Dc55b7A1f7Fe4ce328A1c90dC1B935a30Cc42",
            executorConfig: {
                executorAddress: "0x1e567E344B2d990D2ECDFa4e14A1c9a1Beb83e96",
            },
            ulnConfig: {
                requiredDVNs: ["0x175d2B829604b82270D384393D25C666a822ab60"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x3013C32e5F45E69ceA9baD4d96786704C2aE148c",
            ulnConfig: {
                requiredDVNs: ["0x175d2B829604b82270D384393D25C666a822ab60"],
            }
        }
    },
    // lz config for mainnets
    "ethereum": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.ETHEREUM_V2_MAINNET,
        chainId: 1,
        sendLibConfig: {
            sendLibAddress: "0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1",
            executorConfig: {
                executorAddress: "0x173272739Bd7Aa6e4e214714048a9fE699453059",
            },
            ulnConfig: {
                requiredDVNs: ["0x589dEDbD617e0CBcB916A9223F4d1300c294236b"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0xc02Ab410f0734EFa3F14628780e6e695156024C2",
            ulnConfig: {
                requiredDVNs: ["0x589dEDbD617e0CBcB916A9223F4d1300c294236b"],
            }
        }
    },
    "arbitrum": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.ARBITRUM_V2_MAINNET,
        chainId: 42161,
        sendLibConfig: {
            sendLibAddress: "0x975bcD720be66659e3EB3C0e4F1866a3020E493A",
            executorConfig: {
                executorAddress: "0x31CAe3B7fB82d847621859fb1585353c5720660D",
            },
            ulnConfig: {
                requiredDVNs: ["0x2f55C492897526677C5B68fb199ea31E2c126416"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x7B9E184e07a6EE1aC23eAe0fe8D6Be2f663f05e6",
            ulnConfig: {
                requiredDVNs: ["0x2f55C492897526677C5B68fb199ea31E2c126416"],
            }
        }
    },
    "optimism": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.OPTIMISM_V2_MAINNET,
        chainId: 10,
        sendLibConfig: {
            sendLibAddress: "0x1322871e4ab09Bc7f5717189434f97bBD9546e95",
            executorConfig: {
                executorAddress: "0x2D2ea0697bdbede3F01553D2Ae4B8d0c486B666e",
            },
            ulnConfig: {
                requiredDVNs: ["0x6A02D83e8d433304bba74EF1c427913958187142"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x3c4962Ff6258dcfCafD23a814237B7d6Eb712063",
            ulnConfig: {
                requiredDVNs: ["0x6A02D83e8d433304bba74EF1c427913958187142"],
            }
        }
    },
    "polygon": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.POLYGON_V2_MAINNET,
        chainId: 137,
        sendLibConfig: {
            sendLibAddress: "0x6c26c61a97006888ea9E4FA36584c7df57Cd9dA3",
            executorConfig: {
                executorAddress: "0xCd3F213AD101472e1713C72B1697E727C803885b",
            },
            ulnConfig: {
                requiredDVNs: ["0x23DE2FE932d9043291f870324B74F820e11dc81A"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0x1322871e4ab09Bc7f5717189434f97bBD9546e95",
            ulnConfig: {
                requiredDVNs: ["0x23DE2FE932d9043291f870324B74F820e11dc81A"],
            }
        }
    },
    "base": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.BASE_V2_MAINNET,
        chainId: 8453,
        sendLibConfig: {
            sendLibAddress: "0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2",
            executorConfig: {
                executorAddress: "0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4",
            },
            ulnConfig: {
                requiredDVNs: ["0x9e059a54699a285714207b43B055483E78FAac25"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf",
            ulnConfig: {
                requiredDVNs: ["0x9e059a54699a285714207b43B055483E78FAac25"],
            }
        }
    },
    "mantle": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.MANTLE_V2_MAINNET,
        chainId: 5000,
    },
    "avax": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.AVALANCHE_V2_MAINNET,
        chainId: 43114
    },
    "orderly": {
        endpointAddress: MAIN_LZ_ENDPOINT,
        endpointId: MainnetV2EndpointId.ORDERLY_V2_MAINNET,
        chainId: 291,
        sendLibConfig: {
            sendLibAddress: "0x5B23E2bAe5C5f00e804EA2C4C9abe601604378fa",
            executorConfig: {
                executorAddress: "0x1aCe9DD1BC743aD036eF2D92Af42Ca70A1159df5",
            },
            ulnConfig: {
                requiredDVNs: ["0xF53857dbc0D2c59D5666006EC200cbA2936B8c35"],
            }
        },
        receiveLibConfig: {
            receiveLibAddress: "0xCFf08a35A5f27F306e2DA99ff198dB90f13DEF77",
            ulnConfig: {
                requiredDVNs: ["0xF53857dbc0D2c59D5666006EC200cbA2936B8c35"],
            }
        }
    },
}

export const TGE_CONTRACTS: { [key: env]: { [key: network]: TgeContract} } = {
    'dev': {
        "sepolia": {
            occManager: "0x0180107E72FB14a22a776913063b8a4081E9dc94",
        },
        "arbitrumsepolia": {
            occManager: "0x0180107E72FB14a22a776913063b8a4081E9dc94",
        },
        "opsepolia": {
            occManager: "0x0180107E72FB14a22a776913063b8a4081E9dc94",
        },
        "amoy": {
            occManager: "0x0180107E72FB14a22a776913063b8a4081E9dc94",
        },
        "basesepolia": {
            occManager: "0x0180107E72FB14a22a776913063b8a4081E9dc94",
        },
        "orderlysepolia": {
            occManager: "0xb846DF606b592B9646db03aE2568951651D9D5BC",
        }
    },
    'qa': {
        "sepolia": {
            occManager: "0xB20A18d8A53Ea23A5E8da32465De374f942693D7",
        },
        "arbitrumsepolia": {
            occManager: "0xB20A18d8A53Ea23A5E8da32465De374f942693D7",
        },
        "opsepolia": {
            occManager: "0xB20A18d8A53Ea23A5E8da32465De374f942693D7",
        },
        "amoy": {
            occManager: "0xB20A18d8A53Ea23A5E8da32465De374f942693D7",
        },
        "basesepolia": {
            occManager: "0xB20A18d8A53Ea23A5E8da32465De374f942693D7",
        },
        "orderlysepolia": {
            occManager: "0xD14bEE159B4a8E918f0A43EBf2F801eea93BeD53",
        }
    },
    'staging': {
        "sepolia": {
            occManager: "0x912196EB2583A2f0a18FaD632ee5dB65B8C93EEf",
        },
        "arbitrumsepolia": {
            occManager: "0x912196EB2583A2f0a18FaD632ee5dB65B8C93EEf",
        },
        "opsepolia": {
            occManager: "0x912196EB2583A2f0a18FaD632ee5dB65B8C93EEf",
        },
        "amoy": {
            occManager: "0x912196EB2583A2f0a18FaD632ee5dB65B8C93EEf",
        },
        "basesepolia": {
            occManager: "0x912196EB2583A2f0a18FaD632ee5dB65B8C93EEf",
        },
        "orderlysepolia": {
            occManager: "0x45f3039A9A0eefcC8997e030d9F3cCBb1A7AC6C1",
        }
    },
    'mainnet': {
        "ethereum": {
            occManager: "",
        },
        "arbitrum": {
            occManager: "",
        },
        "optimism": {
            occManager: "",
        },
        "polygon": {
            occManager: "",
        },
        "base": {
            occManager: "",
        },
        "orderly": {
            occManager: "",
        }
    }
}

export const MULTI_SIG: { [key: env]: address } = { 
    "dev": "0xFae9CAF31EeD9f6480262808920dA03eb7f76E7E",
    "qa": "0xc1465019B3e04602a50d34A558c6630Ac50f8fbb",
    "staging": "0x7D1e7BeAd9fBb72e35Dc8E6d1966c2e57DbDA3F0",
    "mainnet": "0x4e834Ca9310d7710a409638A7aa70CB22F141Df3",
}

export function getLzConfig(network: network): LzConfig {
    checkNetwork(network)
    return LZ_CONFIG[network]
}

export function getLzLibConfig(newtwork: network): LzConfig {
    checkNetwork(newtwork)
    if (!LZ_CONFIG[newtwork].sendLibConfig || !LZ_CONFIG[newtwork].receiveLibConfig ) {
       throw new Error(`LZ config for ${newtwork} does not have sendLibConfig or receiveLibConfig`)
    }
    return LZ_CONFIG[newtwork]
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


