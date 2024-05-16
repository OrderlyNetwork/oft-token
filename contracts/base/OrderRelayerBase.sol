// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderRelayerStorage } from "../storage/OrderRelayerStorage.sol";
import { OrderBase } from "./OrderBase.sol";
import { IOrderRelayer } from "../interfaces/IOrderRelayer.sol";

abstract contract OrderRelayerBase is OrderRelayerStorage, OrderBase, IOrderRelayer {
    /* ========== Public ========== */
    function setComposeMsgSender(address _composeMsgSender, bool _allowed) public onlyOwner {
        composeMsgSender[_composeMsgSender] = _allowed;
    }

    function setEndpoint(address _endpoint) public onlyOwner {
        endpoint = _endpoint;
    }

    function setOft(address _oft) public onlyOwner {
        oft = _oft;
    }

    function setEid(uint256 _chainId, uint32 _eid) public onlyOwner {
        eidMap[_chainId] = _eid;
        chainIdMap[_eid] = _chainId;
    }

    /* ========== Internal ========== */
    function _isComposeMsgSender(address _composeMsgSender) internal view returns (bool) {
        return composeMsgSender[_composeMsgSender];
    }

    function _getEid(uint256 _chainId) internal view returns (uint32) {
        return eidMap[_chainId];
    }

    function _getChainId(uint32 _eid) internal view returns (uint256) {
        return chainIdMap[_eid];
    }
}
