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
export const TEST_LZ_ENDPOINT = "0x6EDCE65403992e310A62460808c4b910D972f10f"
export const MAIN_LZ_ENDPOINT = "0x1a44076050125825900e736c501f859c50fE728c"

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

export const ERC1967PROXY_BYTECODE = "0x608060405260405161084e38038061084e83398101604081905261002291610349565b61004d60017f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbd610417565b600080516020610807833981519152146100695761006961043c565b6100758282600061007c565b50506104a1565b610085836100b2565b6000825111806100925750805b156100ad576100ab83836100f260201b6100291760201c565b505b505050565b6100bb8161011e565b6040516001600160a01b038216907fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b90600090a250565b60606101178383604051806060016040528060278152602001610827602791396101de565b9392505050565b610131816102bc60201b6100551760201c565b6101985760405162461bcd60e51b815260206004820152602d60248201527f455243313936373a206e657720696d706c656d656e746174696f6e206973206e60448201526c1bdd08184818dbdb9d1c9858dd609a1b60648201526084015b60405180910390fd5b806101bd60008051602061080783398151915260001b6102cb60201b6100711760201c565b80546001600160a01b0319166001600160a01b039290921691909117905550565b60606001600160a01b0384163b6102465760405162461bcd60e51b815260206004820152602660248201527f416464726573733a2064656c65676174652063616c6c20746f206e6f6e2d636f6044820152651b9d1c9858dd60d21b606482015260840161018f565b600080856001600160a01b0316856040516102619190610452565b600060405180830381855af49150503d806000811461029c576040519150601f19603f3d011682016040523d82523d6000602084013e6102a1565b606091505b5090925090506102b28282866102ce565b9695505050505050565b6001600160a01b03163b151590565b90565b606083156102dd575081610117565b8251156102ed5782518084602001fd5b8160405162461bcd60e51b815260040161018f919061046e565b634e487b7160e01b600052604160045260246000fd5b60005b83811015610338578181015183820152602001610320565b838111156100ab5750506000910152565b6000806040838503121561035c57600080fd5b82516001600160a01b038116811461037357600080fd5b60208401519092506001600160401b038082111561039057600080fd5b818501915085601f8301126103a457600080fd5b8151818111156103b6576103b6610307565b604051601f8201601f19908116603f011681019083821181831017156103de576103de610307565b816040528281528860208487010111156103f757600080fd5b61040883602083016020880161031d565b80955050505050509250929050565b60008282101561043757634e487b7160e01b600052601160045260246000fd5b500390565b634e487b7160e01b600052600160045260246000fd5b6000825161046481846020870161031d565b9190910192915050565b602081526000825180602084015261048d81604085016020870161031d565b601f01601f19169190910160400192915050565b610357806104b06000396000f3fe60806040523661001357610011610017565b005b6100115b610027610022610074565b6100b9565b565b606061004e83836040518060600160405280602781526020016102fb602791396100dd565b9392505050565b73ffffffffffffffffffffffffffffffffffffffff163b151590565b90565b60006100b47f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc5473ffffffffffffffffffffffffffffffffffffffff1690565b905090565b3660008037600080366000845af43d6000803e8080156100d8573d6000f35b3d6000fd5b606073ffffffffffffffffffffffffffffffffffffffff84163b610188576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f416464726573733a2064656c65676174652063616c6c20746f206e6f6e2d636f60448201527f6e7472616374000000000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b6000808573ffffffffffffffffffffffffffffffffffffffff16856040516101b0919061028d565b600060405180830381855af49150503d80600081146101eb576040519150601f19603f3d011682016040523d82523d6000602084013e6101f0565b606091505b509150915061020082828661020a565b9695505050505050565b6060831561021957508161004e565b8251156102295782518084602001fd5b816040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161017f91906102a9565b60005b83811015610278578181015183820152602001610260565b83811115610287576000848401525b50505050565b6000825161029f81846020870161025d565b9190910192915050565b60208152600082518060208401526102c881604085016020870161025d565b601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016919091016040019291505056fe416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a26469706673582212201e3c9348ed6dd2f363e89451207bd8df182bc878dc80d47166301a510c8801e964736f6c634300080a0033360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564"
export const DETERMIN_CONTRSCT_FACTORY =  "0x4e59b44847b379578588920cA78FbF26c0B4956C"
export const INIT_TOKEN_HOLDER = "0xDd3287043493E0a08d2B348397554096728B459c"
export const SIGNER = "0xDd3287043493E0a08d2B348397554096728B459c"

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


