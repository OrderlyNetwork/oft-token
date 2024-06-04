// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseInvariant } from "../invariants/BaseInvariant.t.sol";

contract VerifyHelper {
    BaseInvariant public baseInvariant;

    constructor(BaseInvariant _baseInvariant) {
        baseInvariant = _baseInvariant;
    }

    event Message(string a);

    function verifyPackets(uint32 dstEid, address _address) public {
        emit Message("In VerifyHelper");
        baseInvariant.verifyPackets(dstEid, _address);
    }
}
