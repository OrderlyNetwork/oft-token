// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OrderInvariant} from "../invariants/OrderInvariant.t.sol";

contract VerifyHelper {
    OrderInvariant public orderInvariant;

    constructor(OrderInvariant _orderInvariant) {
        orderInvariant = _orderInvariant;
    }

    function verifyPackets(uint32 dstEid, bytes32 _address, uint256 _packetAmount) public {
        orderInvariant.verifyPackets(dstEid, _address, _packetAmount, address(0x0));
    }

    function validatePacket(bytes32 guid) public returns (bytes32) {
        return orderInvariant.validatePacket(orderInvariant.packets(guid));
    }
}
