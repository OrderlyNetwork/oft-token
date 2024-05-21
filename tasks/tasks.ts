
import { task, types } from "hardhat/config"
import { EnvType, OFTContractType, TEST_NETWORKS, MAIN_NETWORKS, tokenContractName, oftContractName, getLzConfig, checkNetwork } from "./const"
import { loadContractAddress, saveContractAddress,  setPeer, isPeered } from "./utils"
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { AbiCoder } from "ethers/lib/utils"
import { DeployResult } from "hardhat-deploy/dist/types"
import { urlToHttpOptions } from "url"

let fromNetwork: string = ""
let toNetwork: string = ""

let localContractAddress: string = ""
let localContractName: string = ""

let remoteContractAddress: string = ""
let remoteContractName: string = ""

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
            let orderTokenAddress: string | undefined = ""
            let lzEndpointAddress: string | undefined= ""
            let distributorAddress: string | undefined = ""
            let owner: string = ""
            let initArgs: any[] = []
            
            // set deployment initArgs based on contract name
            if (contractName === 'OrderToken') {

                // should set proper distributor address for mainnet
                distributorAddress = signer.address
                initArgs = [distributorAddress]

            } else if (contractName === 'OrderAdapter') {

                orderTokenAddress = await loadContractAddress(env, hre.network.name, 'OrderToken')
                lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                owner = signer.address
                initArgs = [orderTokenAddress, lzEndpointAddress, owner]

            } else if (contractName === 'OrderOFT') {

                lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                owner = signer.address
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
                    gasLimit: 800000
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
            if (contractName === 'OrderSafe') {
                const salt = hre.ethers.utils.id(process.env.ORDER_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log:true,
                    deterministicDeployment: salt
                }

                const OrderSafeContract = await deploy("OrderSafe", {
                    ...baseDeployArgs
                })
                implAddress = OrderSafeContract.address
                console.log(`Order Safe implementation deployed to ${OrderSafeContract.address} with tx hash ${OrderSafeContract.transactionHash}`);
            }  else if (contractName === 'OrderSafeRelayer') {
                const salt = hre.ethers.utils.id(process.env.ORDER_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log:true,
                    deterministicDeployment: salt
                }

                const OrderSafeContract = await deploy(contractName, {
                    ...baseDeployArgs
                })
                implAddress = OrderSafeContract.address
                console.log(`${contractName} implementation deployed to ${OrderSafeContract.address} with tx hash ${OrderSafeContract.transactionHash}`);
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
                        const tx = await localContract.setPeer(lzConfig["endpointId"], paddedPeerAddress, {
                            nonce: nonce++
                        })
                        tx.wait()
                        console.log(`Setting peer from ${fromNetwork} to ${toNetwork} with tx hash ${tx.hash}`)
                        await setPeer(taskArgs.env, fromNetwork, toNetwork, true)
                    } else {
                        console.log(`Already peered from ${fromNetwork} to ${toNetwork}`)
                    }
                    const types = [1,2]
                    for (const type of types) {
                        const typeOptionOnContract = await localContract.enforcedOptions(lzConfig["endpointId"], type)

                        const enforcedOrderedOption = Options.newOptions().addExecutorOrderedExecutionOption().toHex()
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
            if (enforcedOptions.length > 0) {
                const txSetEnforcedOptions = await localContract.setEnforcedOptions(enforcedOptions)
                txSetEnforcedOptions.wait()
                console.log(`Enforced options set with tx hash ${txSetEnforcedOptions.hash}`)
            } else {
                console.log(`Enforced options already set`)
            
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
                        const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount, {nonce: nonce++})
                        approveTx.wait()
                        console.log(`Approving ${localContractName} to spend ${taskArgs.amount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
                    }
                    
                    // TODO: test with different gasLimit 
                    const gasLimit = 50000
                    const msgValue = 0
                    const index = 0
                    // const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue)
                    const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue).toHex()
                    // const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue).addExecutorComposeOption(index, gasLimit, msgValue)
                    // const composedMsg = await hre.ethers.utils.defaultAbiCoder.encode(["uint256"], ["5"])
                    // const stakeComposeMsg = await hre.ethers.utils.defaultAbiCoder.encode(["(address,uint256)"], [[signer.address, tokenAmount]])
                    const composeMsg = "0x"
                    const param = {
                        dstEid: getLzConfig(toNetwork)["endpointId"],
                        to: hre.ethers.utils.hexZeroPad(receiver, 32),
                        amountLD: tokenAmount,
                        minAmountLD: tokenAmount,
                        extraOptions: option,
                        composeMsg: composeMsg,
                        oftCmd: "0x"
                    }
                    const payLzToken = false
                    let fee = await localContract.quoteSend(param, payLzToken);
                    const sendTx = await localContract.send(param, fee, signer.address, 
                    {   value: fee.nativeFee,
                        gasLimit:500000,
                        nonce: nonce++
                    })
                    sendTx.wait()
                    console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
                        }}
            
            }
        catch(e) {
            console.log(`Error: ${e}`)
        
        }
    })

task("order:oft:send", "Send tokens to a specific address on a specific network")
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
                approveTx.wait()
                console.log(`Approving ${localContractName} to spend ${taskArgs.amount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
            }
            
            // TODO: test with different gasLimit 
            const gasLimit = 50000
            const msgValue = 0
            const index = 0
            const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue).toHex()
            const composeMsg = "0x"
            const param = {
                dstEid: getLzConfig(toNetwork)["endpointId"],
                to: hre.ethers.utils.hexZeroPad(receiver, 32),
                amountLD: tokenAmount,
                minAmountLD: tokenAmount,
                extraOptions: option,
                composeMsg: composeMsg,
                oftCmd: "0x"
            }
            const payLzToken = false
            let fee = await localContract.quoteSend(param, payLzToken);
            const sendTx = await localContract.send(param, fee, signer.address, 
            {   value: fee.nativeFee,
                gasLimit:500000,
                nonce: nonce
            })
            sendTx.wait()
            console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
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

            
            const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount)
            approveTx.wait()
            console.log(`Approving ${localContractName} to spend ${tokenAmount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
            
            const index = 0;
            const lzReceiveGas = 200000;
            const lzComposeGas = 500000;
            const airdropValue = 0;
            const option = Options.newOptions().addExecutorLzReceiveOption(lzReceiveGas, airdropValue).addExecutorComposeOption(index, lzComposeGas, airdropValue)
            const lzFee = await safeContract.getStakeFee(signer.address, tokenAmount)
            
            const stakeTx = await safeContract.stakeOrder(signer.address, tokenAmount, {
                gasLimit: 500000,
                value: lzFee,
            })
            console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${stakeTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })
