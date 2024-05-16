// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderRelayerType } from "../library/OrderRelayerType.sol";

contract OrderSafeRelayerStorage {
    address public orderSafe;
    uint256 public orderChainId;
    address public orderBoxRelayer;
    uint256[50] private _gap;
}
