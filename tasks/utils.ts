import { OFTData, OFTPeers, LZConfig, env, name, TEST_NETWORKS, MAIN_NETWORKS} from "./const";
import fs from 'fs';

const ADDRESS_PATH = "./config/oftAddress.json"
const PEERS_PATH = "./config/oftPeers.json"



export async function saveOFTAddress(env: env, network: string, name: name, address: string) {
    if (fs.existsSync(ADDRESS_PATH)) {
        const data = fs.readFileSync(ADDRESS_PATH, 'utf-8');
        const oftAddress: OFTData = JSON.parse(data);
        if (!oftAddress[env]) {
            oftAddress[env] = {}
        }
        if (!oftAddress[env][network]) {
            oftAddress[env][network] = {}
        }
        oftAddress[env][network][name] = address;
        fs.writeFileSync(ADDRESS_PATH, JSON.stringify(oftAddress, null, 2));
        console.log(`Address of ${name} saved for ${name} on ${env} ${network}`)
    } else {
        throw new Error("Address file not found")
    }
 }

export async function loadOFTAddress(env: env, network: string, name: name) {
 
    if (fs.existsSync(ADDRESS_PATH)) {
        const data = fs.readFileSync(ADDRESS_PATH, 'utf-8');
        const oftAddress: OFTData = JSON.parse(data);
        
        if (oftAddress[env][network][name]) {
            return oftAddress[env][network][name]
        } else {
            throw new Error(`Address for ${name} not found on ${env} ${network}`)
        }
        
    }
}

export async function setPeer(env: env, from: string, to: string, connected: boolean) {
    if (fs.existsSync(PEERS_PATH)) {
        const data = fs.readFileSync(PEERS_PATH, 'utf-8');
        let oftPeers: OFTPeers = JSON.parse(data);
        if (!oftPeers[env]) {
            oftPeers[env] = {}
        }
        if (!oftPeers[env][from]) {
            oftPeers[env][from] = {}
        }
        oftPeers[env][from][to] = connected;
        fs.writeFileSync(PEERS_PATH, JSON.stringify(oftPeers, null, 2));
    } else {
        throw new Error("Peers file not found")
    }
}

export async function isPeered(env: env, from: string, to: string) {
    if (fs.existsSync(PEERS_PATH)) {
        const data = fs.readFileSync(PEERS_PATH, 'utf-8');
        const oftPeers: OFTPeers = JSON.parse(data);
        if (oftPeers[env][from]) {
            return oftPeers[env][from][to]
        } else {
            throw new Error(`Peer for ${from} to ${to} not found on ${env}`)
        }
    } else {
        throw new Error("Peers file not found")
    }
}
