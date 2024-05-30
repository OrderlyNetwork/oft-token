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
    // @dev Reord nonce for inbound messages: srcEid => sender => nonce
    mapping(uint32 => mapping(bytes32 => uint64)) public maxReceivedNonce;
    // @dev Flag to enforce ordered nonce, if true, the nonce must be strictly increasing by 1
    bool public orderedNonce;

    /**
     * @dev Initialize the OrderOFT contract and set the ordered nonce flag
     * @param _lzEndpoint The LayerZero endpoint address
     * @param _delegate The delegate address of this OApp on the endpoint
     */
    function initialize(address _lzEndpoint, address _delegate) external initializer {
        __initializeOFT("Orderly Network", "ORDER", _lzEndpoint, _delegate);
        _setOrderedNonce(true);
    }

    /**
     * @dev Set the flag to enforce ordered nonce or not
     * @param _orderedNonce the flag to enforce ordered nonce or not
     */
    function setOrderedNonce(bool _orderedNonce) public onlyOwner {
        _setOrderedNonce(_orderedNonce);
    }

    /**
     * @dev Get the next nonce for the sender
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     */
    function nextNonce(uint32 _srcEid, bytes32 _sender) public view override returns (uint64) {
        if (orderedNonce) {
            return maxReceivedNonce[_srcEid][_sender] + 1;
        } else {
            return 0;
        }
    }

    /**
     * @dev Skip a nonce which is not verified by lz yet (that is: inboundPayloadHash[_receiver][_srcEid][_sender][_nonce] == EMPTY_PAYLOAD_HASH)
     * @param _srcEid the eid of the source chain
     * @param _sender the address of the remote sender (oft or adapter)
     * @param _nonce the nonce of the message to skip
     */
    function skipInboundNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) public onlyOwner {
        _acceptNonce(_srcEid, _sender, _nonce);
        endpoint.skip(address(this), _srcEid, _sender, _nonce);
    }

    /**
     * @dev Clear the inbound nonce to ignore a message
     * @dev this is a PULL mode versus the PUSH mode of lzReceive
     * @param _origin the origin of the message
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid the guid of the message
     * @param _message the message data
     */
    function clearInboundNonce(Origin calldata _origin, bytes32 _guid, bytes calldata _message) public onlyOwner {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);
        endpoint.clear(address(this), _origin, _guid, _message);
    }

    /**
     * @dev Nilify the inbound nonce to mark a message as verified, but disallows execution until it is re-verified.
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     * @param _nonce The nonce of the message to burn
     * @param _payloadHash The hash of the message to burn
     */
    function nilifyInboundNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) public onlyOwner {
        _acceptNonce(_srcEid, _sender, _nonce);
        endpoint.nilify(address(this), _srcEid, _sender, _nonce, _payloadHash);
    }

    /**
     * @dev Burn the inbound nonce to mark a message as unexecutable and un-verifiable. The nonce can never be re-verified or executed.
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     * @param _nonce The nonce of the message to burn
     * @param _payloadHash The hash of the message to burn
     */
    function burnInboundNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) public onlyOwner {
        _acceptNonce(_srcEid, _sender, _nonce);
        endpoint.burn(address(this), _srcEid, _sender, _nonce, _payloadHash);
    }

    /**
     * @dev Check and accept the nonce of the inbound message
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     * @param _nonce The nonce of the message
     */
    function _acceptNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) internal {
        uint64 curNonce = maxReceivedNonce[_srcEid][_sender];
        if (orderedNonce) {
            require(_nonce == curNonce + 1, "OApp: invalid nonce");
        }

        if (_nonce > curNonce) {
            maxReceivedNonce[_srcEid][_sender] = _nonce;
        }
    }

    function _setOrderedNonce(bool _orderedNonce) internal {
        orderedNonce = _orderedNonce;
    }

    /**
     * @dev Overide the _lzReceive function to check and accept the nonce of the message
     * @param _origin the origin of the message
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid the guid of the message
     * @param _message the message data
     * @param _executor the executor address
     * @param _extraData the extra data
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) internal override {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);
        super._lzReceive(_origin, _guid, _message, _executor, _extraData);
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
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
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
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_amountLD > 0) {
            amountReceivedLD = super._credit(_to, _amountLD, _srcEid);
        }
    }
}
