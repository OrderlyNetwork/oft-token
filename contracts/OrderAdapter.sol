// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFTAdapter } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapter.sol";

contract OrderAdapter is OFTAdapter {
    constructor(
        address _orderToken,
        address _lzEndpoint,
        address _delegate
    ) OFTAdapter(_orderToken, _lzEndpoint, _delegate) Ownable(_delegate) {}
}