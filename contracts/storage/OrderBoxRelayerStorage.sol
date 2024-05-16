// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderRelayerType } from "../library/OrderRelayerType.sol";

contract OrderBoxRelayerStorage {
    address orderBox;
    uint256[50] private _gap;
}
