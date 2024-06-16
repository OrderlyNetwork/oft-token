// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OFTAdapterUpgradeable } from "./layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapterUpgradeable.sol";
import { Origin } from "./layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";

/**
 * @title OrderAdapter
 * @author Orderly Network
 * @dev OrderAdapter is an adapter contract to connect the OrderToken contract with the LayerZero endpoint
 * throught OFT protocol. It is only deployed on the network where the OrderToken contract is deployed.
 */
contract OrderAdapter is OFTAdapterUpgradeable {
    /**
     * @dev Initialize the OrderAdapter contract and set the ordered nonce flag
     * @param _lzEndpoint The LayerZero endpoint address
     * @param _delegate The delegate address of this OApp on the endpoint
     */
    function initialize(address _orderToken, address _lzEndpoint, address _delegate) external initializer {
        __initializeOFTAdapter(_orderToken, _lzEndpoint, _delegate);
        _setOrderedNonce(true);
    }
}
