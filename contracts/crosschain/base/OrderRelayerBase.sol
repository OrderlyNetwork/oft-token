// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { OrderRelayerStorage } from "../storage/OrderRelayerStorage.sol";
import { OrderBase } from "./OrderBase.sol";
import { IOrderRelayer, Options, OptionsAirdrop } from "../interfaces/IOrderRelayer.sol";

abstract contract OrderRelayerBase is IOrderRelayer, OrderBase, OrderRelayerStorage {
    using OptionsBuilder for bytes;
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

    function setOptionsAirdrop(uint8 _option, uint128 _gas, uint128 _value) public onlyOwner {
        optionsAirdrop[_option] = OptionsAirdrop(_gas, _value);
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

    function _getOptionsAirdrop(uint8 _option) internal view returns (uint128 gas, uint128 value) {
        gas = optionsAirdrop[_option].gas;
        value = optionsAirdrop[_option].value;
    }

    function _getOption(uint8 _option) internal view returns (bytes memory options) {
        (uint128 lzReceiveGas, uint128 lzReceiveValue) = _getOptionsAirdrop(uint8(Options.LZ_RECEIVE));
        (uint128 optionGas, uint128 optionValue) = _getOptionsAirdrop(_option);
        uint16 index = 0; // only one message can be composed in a transaction
        if (_option == uint8(Options.STAKE_ORDER)) {
            options = OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(lzReceiveGas, lzReceiveValue)
                .addExecutorLzComposeOption(index, optionGas, optionValue);
        }
    }

    function _authorizeComposeMsgSender(
        address _endpoint,
        address _localSender,
        uint32 _eid,
        address _remoteSender
    ) internal view returns (bool) {
        return
            endpoint == _endpoint &&
            _isLocalComposeMsgSender(_localSender) &&
            _isRemoteComposeMsgSender(_eid, _remoteSender);
    }

    fallback() external payable {}
    receive() external payable {}
}
