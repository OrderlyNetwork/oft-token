// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OFTUpgradeable } from "./layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTUpgradeable.sol";
import { Origin } from "./layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";

/**
 * @title OrderOFT
 * @author Orderly Network
 * @dev OrderOFT is the OFT version of the native ERC20 token for the Orderly Network.
 */
contract OrderOFT is OFTUpgradeable {
    /**
     * @dev Initialize the OrderOFT contract and set the ordered nonce flag
     * @param _lzEndpoint The LayerZero endpoint address
     * @param _delegate The delegate address of this OApp on the endpoint
     */
    function initialize(address _lzEndpoint, address _delegate) external initializer {
        __initializeOFT("Orderly Network", "ORDER", _lzEndpoint, _delegate);
        _setOrderedNonce(true);
    }
}
