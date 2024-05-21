// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import { Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";

contract OrderOFT is OFT {
    mapping(uint32 => mapping(bytes32 => uint64)) public receivedNonce;
    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("Orderly Network", "ORDER", _lzEndpoint, _delegate) Ownable(_delegate) {}

    // omit zero token transfer to allow raw composeMsg relay
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

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_amountLD > 0) {
            amountReceivedLD = super._credit(_to, _amountLD, _srcEid);
        }
    }

    function _acceptNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) internal {
        receivedNonce[_srcEid][_sender] += 1;
        require(_nonce == receivedNonce[_srcEid][_sender], "OApp: invalid nonce");
    }

    function nextNonce(uint32 _srcEid, bytes32 _sender) public view override returns (uint64) {
        return receivedNonce[_srcEid][_sender] + 1;
    }

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
}
