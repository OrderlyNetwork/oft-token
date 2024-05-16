// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderSafeType } from "../library/OrderSafeType.sol";

contract OrderSafeStorage {
    address public safeRelayer;
    address public oft;
    uint256[50] private _gap;
}
