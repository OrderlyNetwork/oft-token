
import { task, types } from "hardhat/config"
import { EnvType, OFTContractType, TEST_NETWORKS, MAIN_NETWORKS, tokenContractName, oftContractName, getLzConfig, checkNetwork } from "./const"
import { loadContractAddress, saveContractAddress,  setPeer, isPeered } from "./utils"
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { AbiCoder } from "ethers/lib/utils"
import { DeployResult } from "hardhat-deploy/dist/types"

let fromNetwork: string = ""
let toNetwork: string = ""

let localContractAddress: string = ""
let localContractName: string = ""

let remoteContractAddress: string = ""
let remoteContractName: string = ""

task("test:task", "Used to test code snippets")
    .setAction(async (taskArgs, hre) => {
        console.log("Running on", hre.network.name)
        checkNetwork(hre.network.name)

    })

task("order:print", "Prints the address of the OFT contract")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const contractName: OFTContractType = taskArgs.contract as OFTContractType
        const env: EnvType = taskArgs.env as EnvType
        checkNetwork(hre.network.name)
        console.log(`Printing contract address on ${taskArgs.env} ${hre.network.name}`, await loadContractAddress(env, hre.network.name, contractName))
    })

task("order:deploy", "Deploys the contract to a specific network")
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
            await hre.run("order:init", {env: env, contract: contractName})          
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:init", "Initializes the contract on a specific network")
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
            const oftName = oftContractName(hre.network.name)
            const oftAddress = await loadContractAddress(env, hre.network.name, oftName) as string
            if (contractName === 'OrderSafeRelayer' || contractName === 'OrderBoxRelayer') {
                const tx1 = await contract.setEndpoint(lzConfig.endpointAddress)
                await tx1.wait()
                const tx2 = await contract.setOft(oftAddress)
                await tx2.wait()
                const tx3 = await contract.setComposeMsgSender(oftAddress, true)
                await tx3.wait()
                const tx4 = await contract.setEid(lzConfig.chainId, lzConfig.endpointId)
                await tx4.wait()
                
                if (contractName === 'OrderSafeRelayer') {
                    const safeRelayerTx1 = await contract.setOrderChainId(4460)
                    await safeRelayerTx1.wait()
                    const safeAddress = await loadContractAddress(env, hre.network.name, 'OrderSafe')
                    if (safeAddress) {
                        const safeRelayerTx2 = await contract.setOrderSafe(safeAddress)
                        await safeRelayerTx2.wait()
                    } else {
                        console.log(`OrderSafe contract not found on ${env} ${hre.network.name}, please set it later`)
                    }
                    const boxRelayerAddress = await loadContractAddress(env, "orderlysepolia", 'OrderBoxRelayer')
                    if (boxRelayerAddress) {
                        const safeRelayerTx3 = await contract.setOrderBoxRelayer(boxRelayerAddress)
                        await safeRelayerTx3.wait()
                    }
                } else {
                    const boxAddress = await loadContractAddress(env, hre.network.name, 'OrderBox')
                    if (boxAddress) {
                        const boxRelayerTx1 = await contract.setOrderBox(boxAddress)
                        await boxRelayerTx1.wait()
                    } else {
                        console.log(`OrderBox contract not found on ${env} ${hre.network.name}, please set it later`)
                    }
                }
                
            } else if (contractName === 'OrderSafe' || contractName === 'OrderBox') {
                const tx1 = await contract.setOft(oftAddress)
                await tx1.wait()
                if (contractName === 'OrderSafe') {
                    const orderRelayerAddress = await loadContractAddress(env, hre.network.name, 'OrderSafeRelayer')
                    if (orderRelayerAddress) {
                        const orderSafeTx1 = await contract.setOrderRelayer(orderRelayerAddress)
                        await orderSafeTx1.wait()
                    } else {
                        console.log(`OrderSafeRelayer contract not found on ${env} ${hre.network.name}, please set it later`)
                    }
                } else {
                    const orderRelayerAddress = await loadContractAddress(env, hre.network.name, 'OrderBoxRelayer')
                    if (orderRelayerAddress) {
                        const orderBoxTx1 = await contract.setOrderRelayer(orderRelayerAddress)
                        await orderBoxTx1.wait()
                    } else {
                        console.log(`OrderBoxRelayer contract not found on ${env} ${hre.network.name}, please set it later`)
                    }
                }
            } 

            console.log(`Initialized ${contractName} on ${hre.network.name} for ${env}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:upgrade", "Upgrades the contract to a specific network")
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
                const salt = hre.ethers.utils.id(process.env.SAFE_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
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
            } else if (contractName === 'OrderBox') {
                const salt = hre.ethers.utils.id(process.env.BOX_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log:true,
                    deterministicDeployment: salt
                }

                const OrderSafeContract = await deploy("OrderBox", {
                    ...baseDeployArgs
                })
                implAddress = OrderSafeContract.address
                console.log(`Order Box implementation deployed to ${OrderSafeContract.address} with tx hash ${OrderSafeContract.transactionHash}`);
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

task("order:peer:set", "Connect OFT contracs on different networks")
    .addParam("env", "The environment to connect the OFT contracts", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        checkNetwork(hre.network.name)
        try {
            const fromNetwork = hre.network.name
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            console.log(`Running on ${fromNetwork}`)
            for (const toNetwork of NETWORKS) {
                if (fromNetwork !== toNetwork) {
                    
                    localContractName = oftContractName(fromNetwork)
                    remoteContractName = oftContractName(toNetwork)

                    localContractAddress = await loadContractAddress(taskArgs.env, fromNetwork, localContractName) as string
                    remoteContractAddress = await loadContractAddress(taskArgs.env, toNetwork, remoteContractName) as string

                    const [ signer ] = await hre.ethers.getSigners()
                    const contract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)
                    
                    const lzConfig = getLzConfig(toNetwork)
                    
                    const paddedPeerAddress = hre.ethers.utils.hexZeroPad(remoteContractAddress, 32)
                    // lzConfig! to avoid undefined error
                    const isPeer = await contract.isPeer(lzConfig["endpointId"], paddedPeerAddress)
                    if (!isPeer) {
                        const tx = await contract.setPeer(lzConfig["endpointId"], paddedPeerAddress)
                        tx.wait()
                        console.log(`Setting peer from ${fromNetwork} to ${toNetwork} with tx hash ${tx.hash}`)
                        await setPeer(taskArgs.env, fromNetwork, toNetwork, true)
                    } else {
                        console.log(`Already peered from ${fromNetwork} to ${toNetwork}`)
                    }
                    
                }
            }

        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("order:peer:init", "Initialize the network connections in oftPeers.json file")
    .addParam("env", "The environment to connect the OFT contracts", undefined, types.string)
    .addFlag("writeFile", "Write the connections to the file")
    .setAction(async (taskArgs, hre) => {
        try {
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            for (const fromNetwork of NETWORKS) {
                for (const toNetwork of NETWORKS) {
                    if (fromNetwork !== toNetwork) {
                        await setPeer(taskArgs.env, fromNetwork, toNetwork, false)
                    }
                }
            }
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })


task("order:bridge:token", "Send tokens to a specific address on a specific network")
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

            if (await localContract.approvalRequired()) {
                const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount, {nonce: nonce++})
                approveTx.wait()
                console.log(`Approving ${localContractName} to spend ${tokenAmount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
            }
            
            // TODO: test with different gasLimit 
            const gasLimit = 50000
            const msgValue = 0
            const index = 0
            const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue)
            // const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue).addExecutorComposeOption(index, gasLimit, msgValue)
            // const composedMsg = await hre.ethers.utils.defaultAbiCoder.encode(["uint256"], ["5"])
            // const stakeComposeMsg = await hre.ethers.utils.defaultAbiCoder.encode(["(address,uint256)"], [[signer.address, tokenAmount]])
            const composeMsg = "0x"
            console.log(`Composed message: ${composeMsg}`)
            const param = {
                dstEid: getLzConfig(toNetwork)["endpointId"],
                to: hre.ethers.utils.hexZeroPad(receiver, 32),
                amountLD: tokenAmount,
                minAmountLD: tokenAmount,
                extraOptions: option.toHex(),
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
            console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })


