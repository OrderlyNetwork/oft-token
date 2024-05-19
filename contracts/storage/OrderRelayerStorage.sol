// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract OrderRelayerStorage {
    address public endpoint;
    address public oft;
    // mapping of chainId to endpoint
    mapping(uint256 => uint32) public eidMap;
    // mapping of chainId to chainId
    mapping(uint32 => uint256) public chainIdMap;
    // record of trusted local composeMsgSender
    mapping(address => bool) public localComposeMsgSender;
    // record of trusted remote composeMsgSender: eid => address => bool
    mapping(uint32 => mapping(address => bool)) public remoteComposeMsgSender;
    // mapping of optionId to gasLimit
    mapping(uint8 => uint256) public optionsGasLimit;

    /* ========== Storage Slots + Gap == 50 ========== */
    uint256[50] private _gap;
}
