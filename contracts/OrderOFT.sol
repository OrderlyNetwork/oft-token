// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract OrderOFT is OFT {
    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("Orderly Network", "ORDER", _lzEndpoint, _delegate) Ownable(_delegate) {}    
}