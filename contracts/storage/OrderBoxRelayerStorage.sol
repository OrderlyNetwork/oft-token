// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract OrderBoxRelayerStorage {
    // eid => orderSafe address
    mapping(uint32 => address) public orderSafe;
    address public orderBox;

    /* ========== Storage Slots + Gap == 50 ========== */
    uint256[50] private _gap;
}
