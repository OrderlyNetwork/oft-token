// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OptionsAirdrop } from "../interfaces/IOrderRelayer.sol";

contract OrderRelayerStorage {
    address public endpoint;
    address public oft;
    // mapping of chainId to endpoint
    mapping(uint256 => uint32) public eidMap;
    // mapping of chainId to chainId
    mapping(uint32 => uint256) public chainIdMap;
    // record of trusted local composeMsgSender
    mapping(address => bool) public localMsgSender;
    // record of trusted remote MsgSender: eid => address => bool
    mapping(uint32 => mapping(address => bool)) public remoteMsgSender;
    // mapping option => eid => airdropped gas/value limit
    mapping(uint8 => OptionsAirdrop) public optionsAirdrop;

    /* ========== Storage Slots + Gap == 50 ========== */
    uint256[50] private _gap;
}
