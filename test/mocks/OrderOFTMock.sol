// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OrderOFT } from "contracts/OrderOFT.sol";

import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract OrderOFTMock is OrderOFT {
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function debitView(
        uint256 _amountToSendLD,
        uint256 _minAmountToCreditLD,
        uint32 _dstEid
    ) public view returns (uint256 amountDebitedLD, uint256 amountToCreditLD) {
        return _debitView(_amountToSendLD, _minAmountToCreditLD, _dstEid);
    }

    function removeDust(uint256 _amountLD) public view returns (uint256 amountLD) {
        return _removeDust(_amountLD);
    }

    function toLD(uint64 _amountSD) public view returns (uint256 amountLD) {
        return _toLD(_amountSD);
    }

    function toSD(uint256 _amountLD) public view returns (uint64 amountSD) {
        return _toSD(_amountLD);
    }

    function getMaxReceivedNonce(uint32 _srcEid, bytes32 _sender) public returns (uint64) {
        return maxReceivedNonce[_srcEid][_sender];
    }
}
