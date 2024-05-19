// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Staker } from "../interfaces/IOrderBox.sol";

contract OrderBoxStorage {
    mapping(address => Staker) public staker;
    address public boxRelayer;
    address public oft;

    /* ========== Storage Slots + Gap == 50 ========== */
    uint256[50] private _gap;
}
