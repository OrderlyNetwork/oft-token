// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { OrderBoxType } from "../library/OrderBoxType.sol";

contract OrderBoxStorage {
    // chainId => orderSafe address
    mapping(uint256 => address) public orderSafe;
    mapping(address => OrderBoxType.Staker) public stakers;
    address public boxRelayer;
    address public oft;
    uint256[50] private _gap;
}
