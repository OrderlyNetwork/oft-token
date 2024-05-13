
import { task, types } from "hardhat/config"
import { EnvType, OFTContractType, TEST_NETWORKS, MAIN_NETWORKS, tokenContractName, oftContractName, getLzConfig, checkNetwork } from "./const"
import { loadOFTAddress, saveOFTAddress,  setPeer, isPeered } from "./utils"
import { Options } from '@layerzerolabs/lz-v2-utilities'

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
        console.log(`Printing contract address on ${taskArgs.env} ${hre.network.name}`, await loadOFTAddress(env, hre.network.name, contractName))
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
    
            // set the salt for deterministic deployment
            let contractAddress: string = ""
            if (contractName === 'OrderToken') {
                const salt = hre.ethers.utils.id(process.env.TOKEN_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };

                // should set a correct distributor address for mainnet deployment
                const initDistributor = signer.address
    
                // deterministically deploy the contract
                const OrderTokenContract = await deploy(contractName,  {
                    ...baseDeployArgs,
                    args: [initDistributor]
                })
                console.log(`Order Token contract deployed to ${OrderTokenContract.address} with tx hash ${OrderTokenContract.transactionHash}`);
                contractAddress = OrderTokenContract.address
            } else if (contractName === 'OrderAdapter') {
                const salt = hre.ethers.utils.id(process.env.ADAPTER_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };
            
                const orderTokenAddress = await loadOFTAddress(env, hre.network.name, 'OrderToken')
                const lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                const owner = signer.address
            
                // deterministically deploy the contract
                const OrderAdapterContract = await deploy("OrderAdapter", {
                    ...baseDeployArgs,
                    args: [orderTokenAddress, lzEndpointAddress, owner]
                })
                
                console.log(`Order Adapter contract deployed to ${OrderAdapterContract.address} with tx hash ${OrderAdapterContract.transactionHash}`);
                contractAddress = OrderAdapterContract.address
            } else if (contractName === 'OrderOFT') {
                const salt = hre.ethers.utils.id(process.env.OFT_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };
                const lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                const owner = signer.address
                const args = [lzEndpointAddress, owner]
                
                // deterministically deploy the contract
                const OrderOFTContract = await deploy("OrderOFT", {
                    ...baseDeployArgs,
                    args: [lzEndpointAddress, owner]
                })
                
                console.log(`Order OFT contract deployed to ${OrderOFTContract.address} with tx hash ${OrderOFTContract.transactionHash}`);
                contractAddress = OrderOFTContract.address
            } else if (contractName === 'OrderSafe') {
                const salt = hre.ethers.utils.id(process.env.SAFE_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };
                const lzEndpointAddress = getLzConfig(hre.network.name).endpointAddress
                const owner = signer.address
                const initArgs = [owner]
                
                // deterministically deploy the contract
                const OrderSafeContract = await deploy("OrderSafe", {
                    ...baseDeployArgs,
                    proxy: {
                        owner: owner,
                        proxyContract: "UUPS",
                        execute: {
                            methodName: "initialize",
                            args: initArgs
                        }
                    }
                })
                console.log(`Order Safe contract deployed to ${OrderSafeContract.address} with tx hash ${OrderSafeContract.transactionHash}`);
                contractAddress = OrderSafeContract.address
            } else {
                throw new Error(`Contract ${contractName} not found`)
            }
            
            await saveOFTAddress(env, hre.network.name, contractName, contractAddress)
            
            
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
            } else {
                throw new Error(`Contract ${contractName} not found`)
            }
            const contractAddress = await loadOFTAddress(env, network, contractName) as string
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

                    localContractAddress = await loadOFTAddress(taskArgs.env, fromNetwork, localContractName) as string
                    remoteContractAddress = await loadOFTAddress(taskArgs.env, toNetwork, remoteContractName) as string

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

            localContractAddress = await loadOFTAddress(taskArgs.env, fromNetwork, localContractName) as string
            remoteContractAddress = await loadOFTAddress(taskArgs.env, toNetwork, remoteContractName) as string

            const erc20ContractName = tokenContractName(fromNetwork)
            const erc20ContractAddress = await loadOFTAddress(taskArgs.env, fromNetwork, erc20ContractName) as string

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
            const gasLimit = 60000
            const msgValue = 0
            const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue)
            const param = {
                dstEid: getLzConfig(toNetwork)["endpointId"],
                to: hre.ethers.utils.hexZeroPad(receiver, 32),
                amountLD: tokenAmount,
                minAmountLD: tokenAmount,
                extraOptions: option.toHex(),
                composeMsg: "0x",
                oftCmd: "0x"
            }
            const payLzToken = false
            const fee = await localContract.quoteSend(param, payLzToken);
            const sendTx = await localContract.send(param, fee, signer.address, 
            {   value: fee.nativeFee,
                gasLimit: 1000000,
                nonce: nonce
            })
            console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

