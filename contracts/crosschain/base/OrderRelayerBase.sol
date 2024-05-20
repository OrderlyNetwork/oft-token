// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderRelayerStorage } from "../storage/OrderRelayerStorage.sol";
import { OrderBase } from "./OrderBase.sol";
import { IOrderRelayer } from "../interfaces/IOrderRelayer.sol";

abstract contract OrderRelayerBase is IOrderRelayer, OrderBase, OrderRelayerStorage {
    /* ========== Only Owner ========== */
    function setLocalComposeMsgSender(address _addr, bool _allowed) public onlyOwner {
        localComposeMsgSender[_addr] = _allowed;
    }

    function setRemoteComposeMsgSender(uint32 _eid, address _addr, bool _allowed) public onlyOwner {
        remoteComposeMsgSender[_eid][_addr] = _allowed;
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

    function setOptionGaslimit(uint8 _option, uint256 _limit) public onlyOwner {
        optionsGaslimit[_option] = _limit;
    }

    /* ========== Internal ========== */
    function _isLocalComposeMsgSender(address _addr) internal view returns (bool) {
        return localComposeMsgSender[_addr];
    }

    function _isRemoteComposeMsgSender(uint32 _eid, address _addr) internal view returns (bool) {
        return remoteComposeMsgSender[_eid][_addr];
    }

    function _getEid(uint256 _chainId) internal view returns (uint32) {
        return eidMap[_chainId];
    }

    function _getChainId(uint32 _eid) internal view returns (uint256) {
        return chainIdMap[_eid];
    }

    fallback() external payable {}
    receive() external payable {}
}
