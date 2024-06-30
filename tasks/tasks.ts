
import { task, types } from "hardhat/config"
import { EnvType, OFTContractType, TEST_NETWORKS, MAIN_NETWORKS, tokenContractName, oftContractName, getLzConfig, checkNetwork, OPTIONS, TGE_CONTRACTS } from "./const"
import { loadContractAddress, saveContractAddress,  setPeer, isPeered } from "./utils"
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { DeployResult } from "hardhat-deploy/dist/types"

let fromNetwork: string = ""
let toNetwork: string = ""

let localContractAddress: string = ""
let localContractName: string = ""

let remoteContractAddress: string = ""
let remoteContractName: string = ""

const EXECUTOR_CONFIG_TYPE = ["tuple(uint32,address)"]
// const EXECUTOR_CONFIG_TYPE = ["uint32","address"]
const ULN_CONFIG_TYPE = ["tuple(uint64,uint8,uint8,uint8,address[],address[])"]
// const ULN_CONFIG_TYPE = ["uint64","uint8","uint8","uint8","address[]","address[]"]


const CONFIG_TYPE_EXECUTOR = 1
const CONFIG_TYPE_ULN = 2

task("order:test", "Used to test code snippets")
    .addParam("dstNetwork", "The network to receive the tokens", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        console.log(`Destination network: ${taskArgs.dstNetwork}`)

    })

task("order:print", "Prints the address of the OFT contract")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .addParam("contract", "The contract to deploy", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const contractName: OFTContractType = taskArgs.contract as OFTContractType
        const env: EnvType = taskArgs.env as EnvType
        checkNetwork(hre.network.name)
        console.log(`Printing contract address on ${taskArgs.env} ${hre.network.name}`, await loadContractAddress(env, hre.network.name, contractName))
    })

task("order:deploy", "Deploys the contract to a specific network: OrderToken, OrderAdapter, OrderOFT, OrderSafeRelayer, OrderBoxRelayer, OrderSafe, OrderBox")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .addParam("contract", "The contract to deploy", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        try {
            const contractName: OFTContractType = taskArgs.contract as OFTContractType
            const env: EnvType = taskArgs.env as EnvType
            console.log(`Running on ${hre.network.name}`)
            const { deploy } = hre.deployments;
            const [ signer ] = await hre.ethers.getSigners();
    
            // let variables for deployment and initialization
            let contractAddress: string = ""
            let proxy: boolean = false
            let methodName: string = ""
            let orderTokenAddress: string | undefined = ""
            let lzEndpointAddress: string | undefined= ""
            let distributorAddress: string | undefined = ""
            let owner: string = ""
            let initArgs: any[] = []
            
            // set deployment initArgs based on contract name
            if (contractName === 'OrderToken') {

                // should set proper distributor address for mainnet
                distributorAddress = signer.address // multisig address
                initArgs = [distributorAddress]

            } else if (contractName === 'OrderAdapter') {
                proxy = true
                orderTokenAddress = await loadContractAddress(env, hre.network.name, 'OrderToken')
                lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                owner = signer.address // multisig address
                initArgs = [orderTokenAddress, lzEndpointAddress, owner]

            } else if (contractName === 'OrderOFT') {
                proxy = true
                lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                owner = signer.address // multisig address
                initArgs = [lzEndpointAddress, owner]
                
            } else if (contractName === 'OrderSafeRelayer' || contractName === 'OrderBoxRelayer' || contractName === 'OrderSafe' || contractName === 'OrderBox') {
                
                proxy = true
                owner = signer.address
                initArgs = [owner]
                
            } 
            else {
                throw new Error(`Contract ${contractName} not found`)
            }

            const salt = hre.ethers.utils.id(process.env.ORDER_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
            const baseDeployArgs = {
                from: signer.address,
                log: true,
                deterministicDeployment: salt
            };
            
            // deterministic deployment
            let deployedContract: DeployResult
            if (proxy) {
                deployedContract = await deploy(contractName, {
                    ...baseDeployArgs,
                    proxy: {
                        owner: owner,
                        proxyContract: "UUPS",
                        execute: {
                            methodName: "initialize",
                            args: initArgs
                        }
                    },
                    // gasLimit: 800000
                })
            } else {
                deployedContract = await deploy(contractName, {
                    ...baseDeployArgs,
                    args: initArgs
                })
            }
            console.log(`${contractName} contract deployed to ${deployedContract.address} with tx hash ${deployedContract.transactionHash}`);
            contractAddress = deployedContract.address
            await saveContractAddress(env, hre.network.name, contractName, contractAddress)       
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:init", "Initializes the contract on a specific network: OrderSafe, OrderSafeRelayer, OrderBox, OrderBoxRelayer")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .addParam("contract", "The contract to deploy", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const contractName: OFTContractType = taskArgs.contract as OFTContractType
        const env: EnvType = taskArgs.env as EnvType
        console.log(`Running on ${hre.network.name}`)
        const { deploy } = hre.deployments;
        const [ signer ] = await hre.ethers.getSigners();
        try {
            const contractAddress = await loadContractAddress(env, hre.network.name, contractName) as string
            const contract = await hre.ethers.getContractAt(contractName, contractAddress, signer)
            
            const lzConfig = getLzConfig(hre.network.name)
            const orderLzConfig = getLzConfig("orderlysepolia")
            const oftName = oftContractName(hre.network.name)
            const oftAddress = await loadContractAddress(env, hre.network.name, oftName) as string
            if (contractName === 'OrderSafeRelayer' || contractName === 'OrderBoxRelayer') {

                const endPointAddressOnContract = await contract.endpoint()
                if (endPointAddressOnContract !== lzConfig.endpointAddress) {
                    const txSetEndpointAddress = await contract.setEndpoint(lzConfig.endpointAddress)
                    await txSetEndpointAddress.wait()
                    console.log(`Endpoint set to ${lzConfig.endpointAddress} on ${contractName}`)
                } else {
                    console.log(`Endpoint already set to ${lzConfig.endpointAddress}`)
                }
                const oftAddressOnContract = await contract.oft()
                if (oftAddressOnContract !== oftAddress) {
                    const txSetOft = await contract.setOft(oftAddress)
                    await txSetOft.wait()
                    const txSetLocalSender = await contract.setLocalComposeMsgSender(oftAddress, true)
                    await txSetLocalSender.wait()
                    console.log(`OFT set to ${oftAddress} on ${contractName} and set as local composeMsgSender`)
                } else {
                    console.log(`OFT already set to ${oftAddress}`)
                }
    
                const eidMapped = await contract.eidMap(lzConfig.chainId)
                const chainIdMapped = await contract.chainIdMap(lzConfig.endpointId)
        
                if (Number(eidMapped) !== lzConfig.endpointId || Number(chainIdMapped) !== lzConfig.chainId) {
                    const txSetEid = await contract.setEid(lzConfig.chainId, lzConfig.endpointId)
                    await txSetEid.wait()
                    console.log(`Set eid ${lzConfig.endpointId} and chainId ${lzConfig.chainId} on ${contractName}`)
                }
                else {
                    console.log(`Eid ${lzConfig.endpointId} and chainId ${lzConfig.chainId} already set on ${contractName}`)
                }
                
                // set options
                const lzReceive = 0
                const lzReceiveGas = 200000
                const lzReceiveValue = 0

                const stake = 1
                const stakeGas = 500000
                const stakeValue = 0

                const txSetOptionsAirdropReceive = await contract.setOptionsAirdrop(lzReceive, lzReceiveGas, lzReceiveValue)
                await txSetOptionsAirdropReceive.wait()
                console.log(`Set options for airdrop receive on ${contractName}`)
                const txSetOptionsAridropStake = await contract.setOptionsAirdrop(stake, stakeGas, stakeValue)
                await txSetOptionsAridropStake.wait()
                console.log(`Set options for airdrop stake on ${contractName}`)

                
                if (contractName === 'OrderSafeRelayer') {

                    const orderChainIdOnContract = await contract.chainIdMap(orderLzConfig.endpointId)
                    const orderEndpointIdOnContract = await contract.eidMap(orderLzConfig.chainId)
                    if (Number(orderChainIdOnContract) !== orderLzConfig.chainId || Number(orderEndpointIdOnContract) !== orderLzConfig.endpointId) {
                        const txSetOrderChainId = await contract.setOrderChainId(orderLzConfig.chainId, orderLzConfig.endpointId)
                        await txSetOrderChainId.wait()
                        console.log(`Set order chainId ${orderLzConfig.chainId} and endpointId ${orderLzConfig.endpointId} on ${contractName}`)
                    } else {
                        console.log(`Order chainId ${orderLzConfig.chainId} and endpointId ${orderLzConfig.endpointId} already set on ${contractName}`)
                    }
                    
                    const safeAddressOnContract = await contract.orderSafe()
                    const safeAddress = await loadContractAddress(env, hre.network.name, 'OrderSafe')
                   
                    // be careful here
                    if (safeAddress && (safeAddressOnContract !== safeAddress)) {
                        const txSetSafeAddress = await contract.setOrderSafe(safeAddress)
                        await txSetSafeAddress.wait()
                        console.log(`Set OrderSafe address ${safeAddress} on ${contractName}`)
                    } else {
                        console.log(`OrderSafe contract not found on ${env} ${hre.network.name}, or already set on ${contractName}`)
                    }
                    
                    const boxRelayerAddressOnContract = await contract.orderBoxRelayer()
                    const boxRelayerAddress = await loadContractAddress(env, "orderlysepolia", 'OrderBoxRelayer')
                    if (boxRelayerAddress && (boxRelayerAddressOnContract !== boxRelayerAddress)) {
                        const txSetBoxRelayer = await contract.setOrderBoxRelayer(boxRelayerAddress)
                        await txSetBoxRelayer.wait()
                        const txSetRemoteSender = await contract.setRemoteComposeMsgSender(orderLzConfig.endpointId, boxRelayerAddress, true)
                        await txSetRemoteSender.wait()
                        console.log(`Set OrderBoxRelayer address ${boxRelayerAddress} on ${contractName} and set as remote composeMsgSender`)
                    } else {
                        console.log(`OrderBoxRelayer contract not found on ${env} orderlysepolia, or already set on ${contractName}`)
                    }
                } else {
                    const boxAddressOnContract = await contract.orderBox()
                    const boxAddress = await loadContractAddress(env, hre.network.name, 'OrderBox')
                    if (boxAddress && (boxAddressOnContract !== boxAddress)) {
                        const setBoxAddressTx = await contract.setOrderBox(boxAddress)
                        await setBoxAddressTx.wait()
                        console.log(`Set OrderBox address ${boxAddress} on ${contractName}`)
                    } else {
                        console.log(`OrderBox contract not found on ${env} ${hre.network.name}, or already set on ${contractName}`)
                    }

                    const safeNetwork = "arbitrumsepolia"
                    const safeLzConfig = getLzConfig(safeNetwork)
                    const safeRelayerAddress = await loadContractAddress(env, safeNetwork, 'OrderSafeRelayer')
                    const isRemoteSender = await contract.remoteComposeMsgSender(safeLzConfig.endpointId, safeRelayerAddress)
                    if (!isRemoteSender) {
                        const txSetRemoteComposeMsgSender = await contract.setRemoteComposeMsgSender(safeLzConfig.endpointId, safeRelayerAddress, true)
                        await txSetRemoteComposeMsgSender.wait()
                        const txSetEid = await contract.setEid(safeLzConfig.chainId, safeLzConfig.endpointId)
                        await txSetEid.wait()
                        console.log(`Set remote composeMsgSender ${safeRelayerAddress} of ${safeNetwork} on ${contractName} and corresponding eid and chainId`)
                    } else {
                        console.log(`Remote composeMsgSender ${safeRelayerAddress} of ${safeNetwork} already set on ${contractName}`)
                    }

                    // TODO set Eids, ChainIds and Addresses for each SafeRelayer
                } 
                
            } else if (contractName === 'OrderSafe' || contractName === 'OrderBox') {

                const oftAddressOnContract = await contract.oft()
                const oftAddress = await loadContractAddress(env, hre.network.name, oftName)
                if (oftAddressOnContract !== oftAddress) {
                    const txSetOft = await contract.setOft(oftAddress)
                    await txSetOft.wait()
                    console.log(`Set OFT address ${oftAddress} on ${contractName}`)
                } else {
                    console.log(`OFT already set on ${contractName}`)
                }
                if (contractName === 'OrderSafe') {
                    const orderRelayerAddressOnContract = await contract.safeRelayer()
                    const orderRelayerAddress = await loadContractAddress(env, hre.network.name, 'OrderSafeRelayer')
                    if (orderRelayerAddress !== orderRelayerAddressOnContract) {
                        const setSafeRelayerTx = await contract.setOrderRelayer(orderRelayerAddress)
                        await setSafeRelayerTx.wait()
                        console.log(`Set OrderSafeRelayer address ${orderRelayerAddress} on ${contractName}`)
                    } else {
                        console.log(`OrderSafeRelayer already set on ${contractName}`)
                    }
                } else {
                    const orderRelayerAddressOnContract = await contract.boxRelayer()
                    const orderRelayerAddress = await loadContractAddress(env, hre.network.name, 'OrderBoxRelayer')
                    if (orderRelayerAddress !== orderRelayerAddressOnContract) {
                        const setBoxRelayerTx = await contract.setOrderRelayer(orderRelayerAddress)
                        await setBoxRelayerTx.wait()
                        console.log(`Set OrderBoxRelayer address ${orderRelayerAddress} on ${contractName}`)
                    } else {
                        console.log(`OrderBoxRelayer already set on ${contractName}`)
                    }
                } 
            } 
            else {
                throw new Error(`Contract ${contractName} not found`)
            }

            console.log(`Initialized ${contractName} on ${hre.network.name} for ${env}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:upgrade", "Upgrades the contract to a specific network: OrderSafe, OrderSafeRelayer, OrderBox, OrderBoxRelayer")
    .addParam("env", "The environment to upgrade the OFT contract", undefined, types.string)
    .addParam("contract", "The contract to upgrade", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const network = hre.network.name
        checkNetwork(network)
        try {
            const contractName: OFTContractType = taskArgs.contract as OFTContractType
            const env: EnvType = taskArgs.env as EnvType
            console.log(`Running on ${hre.network.name}`)
            const { deploy } = hre.deployments;
            const [ signer ] = await hre.ethers.getSigners();
            let implAddress = ""
            const salt = hre.ethers.utils.id(process.env.ORDER_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
            if (contractName === 'OrderAdapter' || contractName === 'OrderOFT' || contractName === 'OrderSafe' || contractName === 'OrderBox' || contractName === 'OrderSafeRelayer' || contractName === 'OrderBoxRelayer') {
                const baseDeployArgs = {
                    from: signer.address,
                    log:true,
                    deterministicDeployment: salt
                }
                const contract = await deploy(contractName, {
                    ...baseDeployArgs
                })
                implAddress = contract.address
                console.log(`${contractName} implementation deployed to ${implAddress} with tx hash ${contract.transactionHash}`);
            }
            else {
                throw new Error(`Contract ${contractName} not found`)
            }
            const contractAddress = await loadContractAddress(env, network, contractName) as string
            const contract = await hre.ethers.getContractAt(contractName, contractAddress, signer)
            
            // encoded data for function call during upgrade
            const data = "0x"
            const upgradeTx = await contract.upgradeToAndCall(implAddress, data)
            console.log(`Upgrading contract ${contractName} to ${implAddress} with tx hash ${upgradeTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:oft:set", "Connect OFT contracs on different networks: OrderOFT, OrderAdapter")
    .addParam("env", "The environment to connect the OFT contracts", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        try {
            const fromNetwork = hre.network.name
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            console.log(`Running on ${fromNetwork}`)
            const [ signer ] = await hre.ethers.getSigners()
            let nonce = await signer.getTransactionCount()
            let enforcedOptions = []
            let eids1 = []
            let peers = []
            const localContractName = oftContractName(fromNetwork)
            const localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string
            const localContract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)

            for (const toNetwork of NETWORKS) {
                if (fromNetwork !== toNetwork) {
                    
                    
                    remoteContractName = oftContractName(toNetwork)
                    remoteContractAddress = await loadContractAddress(taskArgs.env, toNetwork, remoteContractName) as string
                    
                    
                    const lzConfig = getLzConfig(toNetwork)
                    const paddedPeerAddress = hre.ethers.utils.hexZeroPad(remoteContractAddress, 32)
                    // lzConfig! to avoid undefined error
                    const isPeer = await localContract.isPeer(lzConfig["endpointId"], paddedPeerAddress)
                    
                    if (!isPeer) {
                        // const txSetPeer = await localContract.setPeer(lzConfig["endpointId"], paddedPeerAddress, {
                        //     nonce: nonce++
                        // })
                        // await txSetPeer.wait()
                        // console.log(`Setting peer from ${fromNetwork} to ${toNetwork} with tx hash ${txSetPeer.hash}`)
                        eids1.push(lzConfig["endpointId"])
                        peers.push(paddedPeerAddress)
                        await setPeer(taskArgs.env, fromNetwork, toNetwork, true)
                    } else {
                        console.log(`Already peered from ${fromNetwork} to ${toNetwork}`)
                    }
                    const types = [1,2]
                    for (const type of types) {
                        const typeOptionOnContract = await localContract.enforcedOptions(lzConfig["endpointId"], type)
                        let enforcedOrderedOption = ""
                        if ( type === 1) {
                            enforcedOrderedOption = Options.newOptions().addExecutorLzReceiveOption(OPTIONS[1].gas, OPTIONS[1].value).toHex() // .addExecutorOrderedExecutionOption()
                        } else if (type === 2) {
                            enforcedOrderedOption = Options.newOptions().addExecutorLzReceiveOption(OPTIONS[1].gas, OPTIONS[1].value).addExecutorComposeOption(0, OPTIONS[2].gas, OPTIONS[2].value).toHex() // .addExecutorOrderedExecutionOption()
                        }
                        if (typeOptionOnContract !== enforcedOrderedOption) {
                            const optionsToAdd = {
                                eid: lzConfig["endpointId"],
                                msgType: type,
                                options: enforcedOrderedOption
                            }
                            enforcedOptions.push(optionsToAdd)
                        }
                    }   
                }
            }
            if (eids1.length > 0) {
                const txSetPeers = await localContract.setPeers(eids1, peers, {nonce: nonce++})
                await txSetPeers.wait()
                console.log(`Setting peers for ${fromNetwork} with tx hash ${txSetPeers.hash}`)
            } else {
                console.log(`All peers already set for ${fromNetwork}`)
            }


            if (enforcedOptions.length > 0) {
                const txSetEnforcedOptions = await localContract.setEnforcedOptions(enforcedOptions, {nonce: nonce++})
                await txSetEnforcedOptions.wait()
                console.log(`Enforced options set with tx hash ${txSetEnforcedOptions.hash}`)
            } else {
                console.log(`Enforced options already set`)
            
            }

            const occManagerAddress = TGE_CONTRACTS[taskArgs.env][fromNetwork].occManager
            // const occManagerAddress = "0xDd3287043493E0a08d2B348397554096728B459c"
            if (occManagerAddress) {
                const trustedStatus = await localContract.trustOderlyAddress(occManagerAddress)
                if (!trustedStatus) {
                    const txTrustOrderly = await localContract.setTrustAddress(occManagerAddress, true, {
                        nonce: nonce++
                    })
                    await txTrustOrderly.wait()
                    console.log(`Trusted Orderly OCC address ${occManagerAddress} on ${localContractName}`)
                } else {
                    console.log(`Orderly OCC address already trusted on ${localContractName}`)
                }
            } else {
                console.log(`No Orderly OCC address found on ${fromNetwork}`)
            }

            if (fromNetwork === 'orderly' || fromNetwork === 'orderlysepolia') {
                const onlyOrderlyEnabled = await localContract.onlyOrderly()

                if (!onlyOrderlyEnabled) {
                    const txSetOnlyOrderly = await localContract.setOnlyOrderly(true, {
                        nonce: nonce++
                    })
                    await txSetOnlyOrderly.wait()
                    console.log(`Set only orderly enabled on ${localContractName}`)
                } else {
                    console.log(`Only orderly already enabled on ${localContractName}`)
                }
            } else {
                console.log(`Only orderly shouldn't be enabled on ${localContractName}`)
            }
            

        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:oft:getconfig", "Print the configuration of OFT contracts on different networks")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .addFlag("setConfig", "Set the configuration of OFT contracts for different networks", )
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        try {
            const fromNetwork = hre.network.name
            checkNetwork(fromNetwork)
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            console.log(`Running on ${fromNetwork}`)
            const [ signer ] = await hre.ethers.getSigners()
            const endpointV2Deployment = await hre.deployments.get('EndpointV2')
            const endpointV2 = await hre.ethers.getContractAt(endpointV2Deployment.abi, endpointV2Deployment.address, signer)
            
            const localContractName = oftContractName(fromNetwork)
            const localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string
            
            let remoteLzConfig, remoteEid, defaultSendLib, defaultReceiveLib, sendLibConfigExecutorData, sendLibConfigULNData, receiveLibConfigULNData, sendLibConfigExecutor, sendLibConfigULN, receiveLibConfigULN
            let receiveLibConfigULNArray = []
            let sendLibConfigExecutorULNArray = []
            for (const toNetwork of NETWORKS) {
                if (fromNetwork !== toNetwork) {
                    
                    remoteLzConfig = getLzConfig(toNetwork)
                    
                    remoteEid = remoteLzConfig["endpointId"]
                    defaultSendLib = await endpointV2.defaultSendLibrary(remoteEid)
                    defaultReceiveLib = await endpointV2.defaultReceiveLibrary(remoteEid)
                    sendLibConfigExecutorData = await endpointV2.getConfig(localContractAddress, defaultSendLib, remoteEid, CONFIG_TYPE_EXECUTOR)
                    sendLibConfigULNData = await endpointV2.getConfig(localContractAddress, defaultSendLib, remoteEid, CONFIG_TYPE_ULN)
                    receiveLibConfigULNData = await endpointV2.getConfig(localContractAddress, defaultReceiveLib, remoteEid, CONFIG_TYPE_ULN)
                    const [decodedSendLibConfigExecutor] = hre.ethers.utils.defaultAbiCoder.decode(EXECUTOR_CONFIG_TYPE, sendLibConfigExecutorData)
                    const [decodedSendLibConfigULN] = hre.ethers.utils.defaultAbiCoder.decode(ULN_CONFIG_TYPE, sendLibConfigULNData)
                    const [decodedReceiveLibConfigULN] = hre.ethers.utils.defaultAbiCoder.decode(ULN_CONFIG_TYPE, receiveLibConfigULNData)
                    
                    console.log(`=================Print Config for ${toNetwork}===================`)
                    console.log(`Default SendLib: ${defaultSendLib}`)
                    console.log(`Default ReceiveLib: ${defaultReceiveLib}`)
                    console.log(`SendLibConfigExecutor: \n maxMessageSize: ${decodedSendLibConfigExecutor[0]},\n executor: ${decodedSendLibConfigExecutor[1]}`)
                    console.log(`SendLibConfigULN: \n confirmations: ${decodedSendLibConfigULN[0]}, \n requiredDVNCount: ${decodedSendLibConfigULN[1]}, \n optionalDVNCount: ${decodedSendLibConfigULN[2]}, \n optionalDVNThreshold: ${decodedSendLibConfigULN[3]}, \n requiredDVNs: ${decodedSendLibConfigULN[4]}, \n optionalDVNs: ${decodedSendLibConfigULN[5]} \n`)
                    console.log(`ReceiveLibConfigULN: \n confirmations: ${decodedReceiveLibConfigULN[0]}, \n requiredDVNCount: ${decodedReceiveLibConfigULN[1]}, \n optionalDVNCount: ${decodedReceiveLibConfigULN[2]}, \n optionalDVNThreshold: ${decodedReceiveLibConfigULN[3]}, \n requiredDVNs: ${decodedReceiveLibConfigULN[4]}, \n optionalDVNs: ${decodedReceiveLibConfigULN[5]} \n`)

                    if (taskArgs.setConfig) {
                        console.log("Start setting config")
                        // console.log(localContractAddress, remoteEid, defaultSendLib)
                        const isDefaultSendLib = await endpointV2.isDefaultSendLibrary(localContractAddress, remoteEid)
                        if (isDefaultSendLib) {
                            const txSetSendLib = await endpointV2.setSendLibrary(localContractAddress, remoteEid, defaultSendLib)
                            await txSetSendLib.wait()
                            console.log(`✅ Set SendLib for ${toNetwork}`)
                        } else {
                            console.log(`👌 SendLib already set for ${toNetwork}`)
                        }

                        const receiveLibOnContract = await endpointV2.getReceiveLibrary(localContractAddress, remoteEid)
                        const expiry = 0
                        if (receiveLibOnContract.isDefault == true) {
                            const txSetReceiveLib = await endpointV2.setReceiveLibrary(localContractAddress, remoteEid, defaultReceiveLib, expiry)
                            await txSetReceiveLib.wait()
                            console.log(`✅ Set ReceiveLib for ${toNetwork}`)
                        } else {
                            console.log(`👌 ReceiveLib already set for ${toNetwork}`)
                        }
                         
                    }
                   
                    const setRceiveLibConfigData = hre.ethers.utils.defaultAbiCoder.encode(ULN_CONFIG_TYPE, [decodedReceiveLibConfigULN])
                    const setSendLibConfigExecutorData = hre.ethers.utils.defaultAbiCoder.encode(EXECUTOR_CONFIG_TYPE, [decodedSendLibConfigExecutor])
                    const setSendLibConfigULNData = hre.ethers.utils.defaultAbiCoder.encode(ULN_CONFIG_TYPE, [decodedSendLibConfigULN])
                    receiveLibConfigULNArray.push([remoteEid, CONFIG_TYPE_ULN, setRceiveLibConfigData])
                    sendLibConfigExecutorULNArray.push([remoteEid, CONFIG_TYPE_EXECUTOR, setSendLibConfigExecutorData])
                    sendLibConfigExecutorULNArray.push([remoteEid, CONFIG_TYPE_ULN, setSendLibConfigULNData])
                }


            }
            if (taskArgs.setConfig) {
                const txSetSendConfig = await endpointV2.setConfig(localContractAddress, defaultSendLib, sendLibConfigExecutorULNArray)
                await txSetSendConfig.wait()
                console.log(`✅ Set SendLib config for ${fromNetwork}`)
                const txSetULNConfig = await endpointV2.setConfig(localContractAddress, defaultReceiveLib, receiveLibConfigULNArray)
                await txSetULNConfig.wait()
                console.log(`✅ Set  config for ${fromNetwork}`)
                
            }
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })



task("order:oft:distribute", "Distribute tokens to all OFT contracts on different networks")
    .addParam("env", "The environment to send the tokens", undefined, types.string)
    .addParam("receiver", "The address to receive the tokens", undefined, types.string)
    .addParam("amount", "The amount of tokens to send", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        try {
            fromNetwork = hre.network.name
            const receiver = taskArgs.receiver
            const [ signer ] = await hre.ethers.getSigners()
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            console.log(`Running on ${fromNetwork}`)
            let nonce = await signer.getTransactionCount()
            for (const toNetwork of NETWORKS) {
                if (fromNetwork !== toNetwork) {
                    
                    localContractName = oftContractName(fromNetwork)
                    remoteContractName = oftContractName(toNetwork)                    
                    localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string
                    remoteContractAddress = await loadContractAddress(taskArgs.env, toNetwork, remoteContractName) as string

                    const erc20ContractName = tokenContractName(fromNetwork)
                    const erc20ContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, erc20ContractName) as string

                    const localContract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)
                    const erc20Contract = await hre.ethers.getContractAt(erc20ContractName, erc20ContractAddress, signer)
                    
                    const deciamls = await erc20Contract.decimals() 
                    const tokenAmount = hre.ethers.utils.parseUnits(taskArgs.amount, deciamls)
                    if (await localContract.approvalRequired() && (tokenAmount > await erc20Contract.allowance(signer.address, localContractAddress))) {
                        const estimateGas = await erc20Contract.estimateGas.approve(localContractAddress, tokenAmount, {nonce: nonce})
                        // console.log(`Estimated gas: ${estimateGas}`)
                        const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount, 
                            {   
                              
                                gasLimit: 10 * Number(estimateGas),
                                nonce: nonce++
                            })
                        await approveTx.wait()
                        console.log(`Approving ${localContractName} to spend ${taskArgs.amount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
                    }
                    
                    const param = {
                        dstEid: getLzConfig(toNetwork)["endpointId"],
                        to: hre.ethers.utils.hexZeroPad(receiver, 32),
                        amountLD: tokenAmount,
                        minAmountLD: tokenAmount,
                        extraOptions: "0x",
                        composeMsg: "0x",
                        oftCmd: "0x"
                    }
                    const payLzToken = false
                    let fee = await localContract.quoteSend(param, payLzToken);

                    const estimateGas = await localContract.estimateGas.send(param, fee, signer.address, 
                        {  
                            // gasPrice: 1000000000,
                            value: fee.nativeFee,
                            nonce: nonce
                        })
                    const sendTx = await localContract.send(param, fee, signer.address, 
                    {   
                        gasLimit: 10 * Number(estimateGas),
                        value: fee.nativeFee,
                        nonce: nonce++
                    })
                    await sendTx.wait()
                    console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
                        }}
            
            }
        catch(e) {
            console.log(`Error: ${e}`)
        
        }
    })

task("order:oft:bridge", "Bridge tokens to a specific address on a specific network through OFT contracts")
    .addParam("env", "The environment to send the tokens", undefined, types.string)
    .addParam("dstNetwork", "The network to receive the tokens", undefined, types.string)
    .addParam("receiver", "The address to receive the tokens", undefined, types.string)
    .addParam("amount", "The amount of tokens to send", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        checkNetwork(taskArgs.dstNetwork)
        try {
            fromNetwork = hre.network.name
            console.log(`Running on ${fromNetwork}`)

            const receiver = taskArgs.receiver
            toNetwork = taskArgs.dstNetwork
            
            if (fromNetwork === toNetwork) {
                throw new Error(`Cannot bridge tokens to the same network`)
            } else {
                localContractName = oftContractName(fromNetwork)
                remoteContractName = oftContractName(toNetwork)
            }

            localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string
            remoteContractAddress = await loadContractAddress(taskArgs.env, toNetwork, remoteContractName) as string

            const erc20ContractName = tokenContractName(fromNetwork)
            const erc20ContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, erc20ContractName) as string

            const [ signer ] = await hre.ethers.getSigners()
            const localContract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)
            const erc20Contract = await hre.ethers.getContractAt(erc20ContractName, erc20ContractAddress, signer)
            
            const deciamls = await erc20Contract.decimals() 
            const tokenAmount = hre.ethers.utils.parseUnits(taskArgs.amount, deciamls)
         
            let nonce = await signer.getTransactionCount()

            if (await localContract.approvalRequired() && (tokenAmount > await erc20Contract.allowance(signer.address, localContractAddress))) {
                const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount, {nonce: nonce++})
                await approveTx.wait()
                console.log(`Approving ${localContractName} to spend ${taskArgs.amount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
            }
            
            const param = {
                dstEid: getLzConfig(toNetwork)["endpointId"],
                to: hre.ethers.utils.hexZeroPad(receiver, 32),
                amountLD: tokenAmount,
                minAmountLD: tokenAmount,
                extraOptions: "0x",
                composeMsg: "0x",
                oftCmd: "0x"
            }
            const payLzToken = false
            let fee = await localContract.quoteSend(param, payLzToken);
            // console.log(`Fee in native: ${fee.nativeFee}`)
            const sendTx = await localContract.send(param, fee, signer.address, 
            {   value: fee.nativeFee,
                nonce: nonce++
            })
            await sendTx.wait()
            console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:oft:quote", "Quote the fee for sending tokens to a specific address on a specific network through OFT contracts")
.addParam("env", "The environment to send the tokens", undefined, types.string)
.addParam("dstNetwork", "The network to receive the tokens", undefined, types.string)
.addParam("receiver", "The address to receive the tokens", undefined, types.string)
.addParam("amount", "The amount of tokens to send", undefined, types.string)
.setAction(async (taskArgs, hre) => {
    checkNetwork(hre.network.name)
    checkNetwork(taskArgs.dstNetwork)
    try {
        fromNetwork = hre.network.name
        console.log(`Running on ${fromNetwork}`)

        const receiver = taskArgs.receiver
        toNetwork = taskArgs.dstNetwork
        
        if (fromNetwork === toNetwork) {
            throw new Error(`Cannot bridge tokens to the same network`)
        } else {
            localContractName = oftContractName(fromNetwork)
            remoteContractName = oftContractName(toNetwork)
        }

        localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string
        remoteContractAddress = await loadContractAddress(taskArgs.env, toNetwork, remoteContractName) as string

        const erc20ContractName = tokenContractName(fromNetwork)
        const erc20ContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, erc20ContractName) as string

        const [ signer ] = await hre.ethers.getSigners()
        const localContract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)
        const erc20Contract = await hre.ethers.getContractAt(erc20ContractName, erc20ContractAddress, signer)
        
        const deciamls = await erc20Contract.decimals() 
        const tokenAmount = hre.ethers.utils.parseUnits(taskArgs.amount, deciamls)
        
        const param = {
            dstEid: getLzConfig(toNetwork)["endpointId"],
            to: hre.ethers.utils.hexZeroPad(receiver, 32),
            amountLD: tokenAmount,
            minAmountLD: tokenAmount,
            extraOptions: "0x",
            composeMsg: "0x",
            oftCmd: "0x"
        }
        const payLzToken = false
        let fee = await localContract.quoteSend(param, payLzToken);
        console.log(`Fee in Wei: ${fee.nativeFee}`) 
        console.log(`Fee in ETH: ${hre.ethers.utils.formatEther(fee.nativeFee)}`)
    }
    catch (e) {
        console.log(`Error: ${e}`)
    }
})


task("order:oft:transfer", "Transfer tokens to a specific address on a specific network")
.addParam("env", "The environment to send the tokens", undefined, types.string)
.addParam("receiver", "The address to receive the tokens", undefined, types.string)
.addParam("amount", "The amount of tokens to send", undefined, types.string)
.setAction(async (taskArgs, hre) => {
    checkNetwork(hre.network.name)
    try {
        fromNetwork = hre.network.name
        console.log(`Running on ${fromNetwork}`)

        const receiver = taskArgs.receiver

        const erc20ContractName = tokenContractName(fromNetwork)
        const erc20ContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, erc20ContractName) as string

        const [ signer ] = await hre.ethers.getSigners()
        const erc20Contract = await hre.ethers.getContractAt(erc20ContractName, erc20ContractAddress, signer)
        
        
        const deciamls = await erc20Contract.decimals() 
        const tokenAmount = hre.ethers.utils.parseUnits(taskArgs.amount, deciamls)
        const transferTx = await erc20Contract.transfer(receiver, tokenAmount)
        await transferTx.wait()
        console.log(`Transferring tokens to ${receiver} with tx hash ${transferTx.hash}`)
        
    }
    catch (e) {
        console.log(`Error: ${e}`)
    }
})

task("order:stake", "Send stakes to a specific address on a specific network")
    .addParam("env", "The environment to send the stakes", undefined, types.string)
    .addParam("amount", "The amount of stakes to send", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        try {
            fromNetwork = hre.network.name
            console.log(`Running on ${fromNetwork}`)

            toNetwork = "orderlysepolia"
            
            if (fromNetwork === toNetwork) {
                throw new Error(`Cannot bridge tokens to the same network`)
            } else {
                localContractName = "OrderSafe"
                remoteContractName = oftContractName(toNetwork)
            }

            localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string

            const erc20ContractName = tokenContractName(fromNetwork)
            const erc20ContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, erc20ContractName) as string

            const [ signer ] = await hre.ethers.getSigners()
            const safeContract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)
            const erc20Contract = await hre.ethers.getContractAt(erc20ContractName, erc20ContractAddress, signer)
            
            const deciamls = await erc20Contract.decimals() 
            const tokenAmount = hre.ethers.utils.parseUnits(taskArgs.amount, deciamls)
            let nonce = await signer.getTransactionCount()

            
            const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount, {
                nonce: nonce++
            
            })
            await approveTx.wait()
            console.log(`Approving ${localContractName} to spend ${taskArgs.amount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
            
            const lzFee = await safeContract.getStakeFee(signer.address, tokenAmount)

            const stakeTx = await safeContract.stakeOrder(signer.address, tokenAmount, {
                value: lzFee,
                nonce: nonce++
            })
            console.log(`Staking tokens from ${fromNetwork} to ${toNetwork} with tx hash ${stakeTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("lz:retry:compose", "Compose a message to a specific address on a specific network")
    .addParam("hash", "The hash of the compose alert txn", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        const composeAlertTopic = hre.ethers.utils.id("LzComposeAlert(address,address,address,bytes32,uint16,uint256,uint256,bytes,bytes,bytes)")
        const endpointV2Deployment = await hre.deployments.get('EndpointV2')
        const [ signer ] = await hre.ethers.getSigners()
        const endpointV2 = await hre.ethers.getContractAt(endpointV2Deployment.abi, endpointV2Deployment.address, signer)
        console.log(await endpointV2.eid())
        const composeAlertTxn = await hre.ethers.provider.getTransactionReceipt(taskArgs.hash)
        if (!composeAlertTxn) {
            throw new Error(`Transaction with hash ${taskArgs.hash} not found`)
        }
        const logs = composeAlertTxn.logs
        const composeAlertLog = logs.find(log => log.topics[0] === composeAlertTopic)

        if (!composeAlertLog) {
            throw new Error(`Compose alert log not found`)
        }
        const log = endpointV2.interface.parseLog(composeAlertLog)
        
        const retryLzComposeTx = await endpointV2.lzCompose(log.args["from"], log.args["to"], log.args["guid"], log.args["index"], log.args["message"], log.args["extraData"], {
            gasLimit: log.args["gas"],
            value: log.args["value"]
        })

        console.log(`Composing message with tx hash ${retryLzComposeTx.hash}`)
        
    })


task("lz:exec:compose", "Compose a message to a specific address on a specific network")
    .addParam("hash", "The hash of the compose alert txn", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const composeSentTopic = hre.ethers.utils.id("ComposeSent(address,address,bytes32,uint16,bytes)")
        const endpointV2Deployment = await hre.deployments.get('EndpointV2')
        const [ signer ] = await hre.ethers.getSigners()
        const endpointV2 = await hre.ethers.getContractAt(endpointV2Deployment.abi, endpointV2Deployment.address, signer)
        const composeSentTxn = await hre.ethers.provider.getTransactionReceipt(taskArgs.hash)
        if (!composeSentTxn) {
            throw new Error(`Transaction with hash ${taskArgs.hash} not found`)
        }
        const logs = composeSentTxn.logs
        const composeSentLog = logs.find(log => log.topics[0] === composeSentTopic)

        if (!composeSentLog) {
            throw new Error(`Compose alert log not found`)
        }
        const log = endpointV2.interface.parseLog(composeSentLog)
        
        const callLzComposeTx = await endpointV2.lzCompose(log.args["from"], log.args["to"], log.args["guid"], log.args["index"], log.args["message"], "0x")

        console.log(`Composing message with tx hash ${callLzComposeTx.hash}`)

    })


task("lz:receive", "Receive a message on a specific network")
    .addParam("hash", "The hash of the receive alert txn", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        const receiveAlertTopic = hre.ethers.utils.id("LzReceiveAlert(address,address,(uint32,bytes32,uint64),bytes32,uint256,uint256,bytes,bytes,bytes)")
        const endpointV2Deployment = await hre.deployments.get('EndpointV2')
        const [ signer ] = await hre.ethers.getSigners()
        const endpointV2 = await hre.ethers.getContractAt(endpointV2Deployment.abi, endpointV2Deployment.address, signer)

        
        const receiveAlertTxn = await hre.ethers.provider.getTransactionReceipt(taskArgs.hash)
        if (!receiveAlertTxn) {
            throw new Error(`Transaction with hash ${taskArgs.hash} not found`)
        }
        const logs = receiveAlertTxn.logs
        const receiveAlertLog = logs.find(log => log.topics[0] === receiveAlertTopic)

        if (!receiveAlertLog) {
            throw new Error(`Receive alert log not found`)
        }
        const log = endpointV2.interface.parseLog(receiveAlertLog)
        
        const retryLzReceiveTx = await endpointV2.lzReceive(log.args["origin"], log.args["receiver"], log.args["guid"], log.args["message"], log.args["extraData"], {
            gasLimit: log.args["gas"],
            value: log.args["value"]
        })

        console.log(`lz receive sent with tx hash ${retryLzReceiveTx.hash}`)
        
    })

task("lz:config:decode", "Decode the config for Executor or ULN")
    .addParam("data", "The data to decode", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const CONIG_TYPE = ["address", "address", "(uint32,uint32,bytes)[]"]
        const data = "0x"+taskArgs.data.slice(10)
        const config = hre.ethers.utils.defaultAbiCoder.decode(CONIG_TYPE, data)
        const configLength = config[2].length
        const configDataArray = config[2]
        console.log(`Print ${configLength} config data`)

        for (let i = 0; i < configLength; i++) {
            const remoteEid = configDataArray[i][0]
            const configType = configDataArray[i][1]
            let configData
            if (configType === 1) {
                [configData] = hre.ethers.utils.defaultAbiCoder.decode(EXECUTOR_CONFIG_TYPE, configDataArray[i][2])
                console.log(`Remote Eid: ${remoteEid}, Config Type: ${configType}, Config Data: {\n maxMessageSize: ${configData[0]}, \nexecutor: ${configData[1]} \n
                }`)
            } else if (configType === 2) {
                [configData] = hre.ethers.utils.defaultAbiCoder.decode(ULN_CONFIG_TYPE, configDataArray[i][2])
                console.log(`Remote Eid: ${remoteEid}, Config Type: ${configType}, Config Data: {\n
                    confirmations: ${configData[0]}, \n
                    requiredDVNCount: ${configData[1]}, \n
                    optionalDVNCount: ${configData[2]}, \n
                    optionalDVNThreshold: ${configData[3]}, \n
                    requiredDVNs: ${configData[4]}, \n
                    optionalDVNs: ${configData[5]}, \n
                }`)
            } else {
                throw new Error(`Config type ${configType} not found`)
            }
            
        }
    })
    
