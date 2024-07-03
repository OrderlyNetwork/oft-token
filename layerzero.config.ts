import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'OrderAdapter',
}

const arbitrumsepoliaContract: OmniPointHardhat = {
    eid: EndpointId.ARBSEP_V2_TESTNET,
    contractName: 'OrderOFT',
}

const opsepoliaContract: OmniPointHardhat = {
    eid: EndpointId.OPTSEP_V2_TESTNET,
    contractName: 'OrderOFT',
}

const amoyContract: OmniPointHardhat = {
    eid: EndpointId.AMOY_V2_TESTNET,
    contractName: 'OrderOFT',
}

const basesepoliaContract: OmniPointHardhat = {
    eid: EndpointId.BASESEP_V2_TESTNET,
    contractName: 'OrderOFT',
}

const orderlysepoliaContract: OmniPointHardhat = {
    eid: EndpointId.ORDERLY_V2_TESTNET,
    contractName: 'OrderOFT',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: sepoliaContract,
        },
        {
            contract: arbitrumsepoliaContract,
        },
        {
            contract: opsepoliaContract,
        },
        {
            contract: amoyContract,
        },
        {
            contract: basesepoliaContract,
        },
        {
            contract: orderlysepoliaContract,
        },
    ],
    connections: [
        // from sepolia to others
        // {
        //     from: sepoliaContract,
        //     to: arbitrumsepoliaContract,
        // },
        // {
        //     from: sepoliaContract,
        //     to: opsepoliaContract,
        // },
        // {
        //     from: sepoliaContract,
        //     to: amoyContract,
        // },
        // {
        //     from: sepoliaContract,
        //     to: basesepoliaContract,
        // },
        {
            from: sepoliaContract,
            to: orderlysepoliaContract,
        },
        // from arbitrumsepolia to others
        // {
        //     from: arbitrumsepoliaContract,
        //     to: sepoliaContract,
        // },
        // {
        //     from: arbitrumsepoliaContract,
        //     to: opsepoliaContract,
        // },
        // {
        //     from: arbitrumsepoliaContract,
        //     to: amoyContract,
        // },
        // {
        //     from: arbitrumsepoliaContract,
        //     to: basesepoliaContract,
        // },
        // {
        //     from: arbitrumsepoliaContract,
        //     to: orderlysepoliaContract,
        // },
        // // from opsepolia to others
        // {
        //     from: opsepoliaContract,
        //     to: sepoliaContract,
        // },
        // {
        //     from: opsepoliaContract,
        //     to: arbitrumsepoliaContract,
        // },
        // {
        //     from: opsepoliaContract,
        //     to: amoyContract,
        // },
        // {
        //     from: opsepoliaContract,
        //     to: basesepoliaContract,
        // },
        // {
        //     from: opsepoliaContract,
        //     to: orderlysepoliaContract,
        // },
        // // from amoy to others
        // {
        //     from: amoyContract,
        //     to: sepoliaContract,
        // },
        // {
        //     from: amoyContract,
        //     to: arbitrumsepoliaContract,
        // },
        // {
        //     from: amoyContract,
        //     to: opsepoliaContract,
        // },
        // {
        //     from: amoyContract,
        //     to: basesepoliaContract,
        // },
        // {
        //     from: amoyContract,
        //     to: orderlysepoliaContract,
        // },
        // // from basesepolia to others
        // {
        //     from: basesepoliaContract,
        //     to: sepoliaContract,
        // },
        // {
        //     from: basesepoliaContract,
        //     to: arbitrumsepoliaContract,
        // },
        // {
        //     from: basesepoliaContract,
        //     to: opsepoliaContract,
        // },
        // {
        //     from: basesepoliaContract,
        //     to: amoyContract,
        // },
        // {
        //     from: basesepoliaContract,
        //     to: orderlysepoliaContract,
        // },
        // // from orderlysepolia to others
        {
            from: orderlysepoliaContract,
            to: sepoliaContract,
        },
        // {
        //     from: orderlysepoliaContract,
        //     to: arbitrumsepoliaContract,
        // },
        // {
        //     from: orderlysepoliaContract,
        //     to: opsepoliaContract,
        // },
        // {
        //     from: orderlysepoliaContract,
        //     to: amoyContract,
        // },
        // {
        //     from: orderlysepoliaContract,
        //     to: basesepoliaContract,
        // },
        
    ],
}

export default config
