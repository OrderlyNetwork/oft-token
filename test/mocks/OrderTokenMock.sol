// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OrderToken } from "contracts/OrderToken.sol";

contract OrderTokenMock is OrderToken {
    constructor(address _initDistributor) OrderToken(_initDistributor) {}
}
