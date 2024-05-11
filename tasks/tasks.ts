
import { task, types } from "hardhat/config"
import { OFTData, EnvType, LZConfig, OFTContractType, TEST_NETWORKS, MAIN_NETWORKS, isERC20Network, tokenContractName, oftContractName } from "./const"
import { loadOFTAddress, saveOFTAddress, loadLzConfig,  setPeer, isPeered } from "./utils"
import { Options } from '@layerzerolabs/lz-v2-utilities'

import { RPC } from "./const"
// const { deployments } = require('hardhat');
// const { ethers } = require('ethers');

// import { deployments } from "hardhat"

let fromNetwork: string = ""
let toNetwork: string = ""

let localContractAddress: string = ""
let localContractName: string = ""

let remoteContractAddress: string = ""
let remoteContractName: string = ""

task("print-oft-address", "Prints the address of the OFT contract")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        console.log(`Printing contract address on ${taskArgs.env} ${hre.network.name}`, await loadOFTAddress(taskArgs.env, hre.network.name, "OrderOFT"))
        // await saveOFTAddress(taskArgs.env, hre.network.name, "OrderOFT", "0x1234567890")
        // console.log(`Printing contract address on ${taskArgs.env} ${hre.network.name}`, await loadOFTAddress(taskArgs.env, hre.network.name, "OrderOFT"))

    })

task("deploy-oft", "Deploys the OFT contract")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        const env: EnvType = taskArgs.env as EnvType
        console.log(`Deploying OFT contract on ${env} environment`)

    })

task("deploy:to", "Deploys the contract to a specific network")
    .addParam("env", "The environment to deploy the OFT contract", undefined, types.string)
    .addParam("contract", "The contract to deploy", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        try {
            const contract: OFTContractType = taskArgs.contract as OFTContractType
            const env: EnvType = taskArgs.env as EnvType
            console.log(`Running on ${hre.network.name}`)

            const { deploy } = hre.deployments;
            // const { deployer } = await hre.getNamedAccounts();
            const [ signer ] = await hre.ethers.getSigners();
            const endpointV2Deployment = await hre.deployments.get('EndpointV2')
    
            // set the salt for deterministic deployment
            let contractAddress: string = ""
            if (contract === 'OrderToken') {
                const salt = hre.ethers.utils.id(process.env.TOKEN_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };

                const initDistributor = signer.address
    
                // deterministically deploy the contract
                const OrderTokenContract = await deploy(contract,  {
                    ...baseDeployArgs,
                    args: [initDistributor]
                })
                console.log(`Order Token contract deployed to ${OrderTokenContract.address} with tx hash ${OrderTokenContract.transactionHash}`);
                contractAddress = OrderTokenContract.address
            } else if (contract === 'OrderAdapter') {
                const salt = hre.ethers.utils.id(process.env.ADAPTER_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };
            
                const orderTokenAddress = await loadOFTAddress(env, hre.network.name, 'OrderToken')
                const lzEndpointAddress = endpointV2Deployment.address
                const owner = signer.address
            
                // deterministically deploy the contract
                const OrderAdapterContract = await deploy("OrderAdapter", {
                    ...baseDeployArgs,
                    args: [orderTokenAddress, lzEndpointAddress, owner]
                })
                
                console.log(`Order Adapter contract deployed to ${OrderAdapterContract.address} with tx hash ${OrderAdapterContract.transactionHash}`);
                contractAddress = OrderAdapterContract.address
            } else if (contract === 'OrderOFT') {
                const salt = hre.ethers.utils.id(process.env.OFT_DEPLOYMENT_SALT + `${env}` || "deterministicDeployment")
                const baseDeployArgs = {
                    from: signer.address,
                    log: true,
                    deterministicDeployment: salt
                };
                const lzEndpointAddress = endpointV2Deployment.address
                const owner = signer.address
            
                // deterministically deploy the contract
                const OrderOFTContract = await deploy("OrderOFT", {
                    ...baseDeployArgs,
                    args: [lzEndpointAddress, owner]
                })
                
                console.log(`Order OFT contract deployed to ${OrderOFTContract.address} with tx hash ${OrderOFTContract.transactionHash}`);
                contractAddress = OrderOFTContract.address
            }
            
            await saveOFTAddress(env, hre.network.name, contract, contractAddress)
            
            
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("peer:set", "Connect OFT contracs on different networks")
    .addParam("env", "The environment to connect the OFT contracts", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        try {
            const fromNetwork = hre.network.name
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            console.log(`Running on ${fromNetwork}`)
            for (const toNetwork of NETWORKS) {
                if (fromNetwork !== toNetwork) {
                    
                    // if (fromNetwork === NETWORKS[0]) {
                    //     console.log(fromNetwork)
                    //     localContractName = "OrderAdapter"
                    // } else {
                    //     localContractName = "OrderOFT"
                    // }
                    localContractName = oftContractName(fromNetwork)
                    remoteContractName = oftContractName(toNetwork)

                    localContractAddress = await loadOFTAddress(taskArgs.env, fromNetwork, localContractName) as string
                    remoteContractAddress = await loadOFTAddress(taskArgs.env, toNetwork, remoteContractName) as string

                    const [ signer ] = await hre.ethers.getSigners()
                    const contract = await hre.ethers.getContractAt(localContractName, localContractAddress, signer)
                    
                    const lzConfig = await loadLzConfig(toNetwork)
                    
                    const paddedPeerAddress = hre.ethers.utils.hexZeroPad(remoteContractAddress, 32)
                    // lzConfig! to avoid undefined error
                    const isPeer = await contract.isPeer(lzConfig!["eid"], paddedPeerAddress)
                    if (!isPeer) {
                        const tx = await contract.setPeer(lzConfig!["eid"], paddedPeerAddress)
                        console.log(`Setting peer on ${fromNetwork} to ${toNetwork} with tx hash ${tx.hash}`)
                        await setPeer(taskArgs.env, fromNetwork, toNetwork, true)
                    } else {
                        console.log(`Already peered on ${fromNetwork} to ${toNetwork}`)
                    }
                    
                }
            }

        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })

task("peer:init", "Initialize the network connections in oftPeers.json file")
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


task("bridge:token", "Send tokens to a specific address on a specific network")
    .addParam("env", "The environment to send the tokens", undefined, types.string)
    .addParam("dstNetwork", "The network to receive the tokens", undefined, types.string)
    .addParam("receiver", "The address to receive the tokens", undefined, types.string)
    .addParam("amount", "The amount of tokens to send", undefined, types.string)
    .setAction(async (taskArgs, hre) => {
        try {
            fromNetwork = hre.network.name
            const NETWORKS = taskArgs.env === 'mainnet' ? MAIN_NETWORKS : TEST_NETWORKS
            console.log(`Running on ${fromNetwork}`)
            const receiver = taskArgs.receiver
            toNetwork = taskArgs.dstNetwork
            if (!NETWORKS.includes(toNetwork)) {
                throw new Error(`Network ${toNetwork} not found`)
            }

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

            if (await localContract.approvalRequired()) {
                const approveTx = await erc20Contract.approve(localContractAddress, tokenAmount)
                console.log(`Approving ${localContractName} to spend ${tokenAmount} on ${erc20ContractName} with tx hash ${approveTx.hash}`)
            }
            
            
            const gasLimit = 60000
            const msgValue = 0
            const option = Options.newOptions().addExecutorLzReceiveOption(gasLimit, msgValue)
            const param = {
                dstEid: loadLzConfig(toNetwork)!["eid"],
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
                gasLimit: 1000000
            })
            console.log(`Sending tokens from ${fromNetwork} to ${toNetwork} with tx hash ${sendTx.hash}`)
        }
        catch (e) {
            console.log(`Error: ${e}`)
        }
    })