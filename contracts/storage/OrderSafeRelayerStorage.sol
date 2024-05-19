// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract OrderSafeRelayerStorage {
    address public orderSafe;
    uint256 public orderChainId;
    address public orderBoxRelayer;

    /* ========== Storage Slots + Gap == 50 ========== */
    uint256[50] private _gap;
}
