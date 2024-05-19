// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

contract OrderRelayMessage {
    struct Order {
        address maker;
        address taker;
        address oft;
        address token;
        uint256 amount;
        uint256 price;
        uint256 chainId;
        uint256 expiry;
        uint256 salt;
        bytes signature;
    }

    struct OrderRelay {
        Order order;
        address relayer;
        uint256 expiry;
        bytes signature;
    }

    struct OrderRelayMessage {
        OrderRelay orderRelay;
        address orderBox;
        uint256 expiry;
        bytes signature;
    }
}
