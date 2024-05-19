// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract OrderSafeStorage {
    address public safeRelayer;
    address public oft;

    /* ========== Storage Slots + Gap == 50 ========== */
    uint256[50] private _gap;
}
