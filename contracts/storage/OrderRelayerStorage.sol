// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderRelayerType } from "../library/OrderRelayerType.sol";

contract OrderRelayerStorage {
    mapping(uint256 => uint32) eidMap;
    mapping(uint32 => uint256) chainIdMap;
    mapping(address => bool) public composeMsgSender;
    mapping(uint16 => uint256) public optionsGasLimit;

    address public endpoint;
    address public oft;
    uint256[50] private _gap;
}
