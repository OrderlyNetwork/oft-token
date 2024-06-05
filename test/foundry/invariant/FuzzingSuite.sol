// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseInvariant } from "./invariants/BaseInvariant.t.sol";

contract FuzzingSuite is BaseInvariant {
    function setUp() public virtual override {
        BaseInvariant.setUp();
    }
}
