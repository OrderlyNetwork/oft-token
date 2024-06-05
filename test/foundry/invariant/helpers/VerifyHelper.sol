// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseInvariant } from "../invariants/BaseInvariant.t.sol";

contract VerifyHelper {
    BaseInvariant public baseInvariant;

    constructor(BaseInvariant _baseInvariant) {
        baseInvariant = _baseInvariant;
    }

    function verifyPackets(uint32 dstEid, bytes32 _address, uint256 _packetAmount) public {
        baseInvariant.verifyPackets(dstEid, _address, _packetAmount, address(0x0));
    }
}
