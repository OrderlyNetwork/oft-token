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

    /**
     * @dev Overide the _debit function to skip zero token transfer request
     * @param _from the address of the token sender
     * @param _amountLD the amount of tokens to send in local decimals
     * @param _minAmountLD the minimum aceeptable amount required by sender in local decimals
     * @param _dstEid the eid of the destination chain
     * @return amountSentLD the amount sent in local decimals
     * @return amountReceivedLD the amount received in local decimals on the remote
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        if (_amountLD > 0) {
            (amountSentLD, amountReceivedLD) = super._debit(_from, _amountLD, _minAmountLD, _dstEid);
        }
    }

    /**
     * @dev Overide the _credit function to skip zero token transfer request
     * @param _to the address of the token receiver
     * @param _amountLD the amount of tokens to receive in local decimals
     * @param _srcEid the eid of the source chain
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal override returns (uint256 amountReceivedLD) {
        if (_amountLD > 0) {
            amountReceivedLD = super._credit(_to, _amountLD, _srcEid);
        }
    }
}
