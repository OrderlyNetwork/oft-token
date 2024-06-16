// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { OrderRelayerStorage } from "../storage/OrderRelayerStorage.sol";
import { OrderBaseUpgradeable } from "./OrderBaseUpgradeable.sol";
import { IOrderRelayer, Options, OptionsAirdrop } from "../interfaces/IOrderRelayer.sol";

/**
 * @title OrderRelayerBase contract
 * @author Zion
 * @notice The base contract to define the relayer to interact with OFT contract
 */
abstract contract OrderRelayerBase is IOrderRelayer, OrderBaseUpgradeable, OrderRelayerStorage {
    using OptionsBuilder for bytes;
    /* ========== Only Owner ========== */
    /**
     *
     * @param _addr The address of a composeMsg sender on the local network
     * @param _allowed The status for a given address if it is allowed to send composeMsg to this relayer contract
     */
    function setLocalComposeMsgSender(address _addr, bool _allowed) public onlyOwner {
        localMsgSender[_addr] = _allowed;
    }

    /**
     *
     * @param _eid The eid of a remote network from where a composeMsg is sent
     * @param _addr The address of a composeMsg sender on a remote network
     * @param _allowed The status for a given address if it is allowed to send composeMsg to this relayer contract from the remote network
     */
    function setRemoteComposeMsgSender(uint32 _eid, address _addr, bool _allowed) public onlyOwner {
        remoteMsgSender[_eid][_addr] = _allowed;
    }

    /**
     *
     * @param _endpoint The address of the Layerzero endpoint on the local network
     */
    function setEndpoint(address _endpoint) public onlyOwner {
        endpoint = _endpoint;
    }

    /**
     *
     * @param _oft The OFT cotract address deployed on the local network
     */
    function setOft(address _oft) public onlyOwner {
        oft = _oft;
    }

    /**
     *
     * @param _chainId The chainId for a given eid
     * @param _eid The eid for a given chainId
     * @dev This mapping should be set based on Layerzero doc
     */
    function setEid(uint256 _chainId, uint32 _eid) public onlyOwner {
        eidMap[_chainId] = _eid;
        chainIdMap[_eid] = _chainId;
    }

    /**
     *
     * @param _option The enum value given an option
     * @param _gas The airdropped gas limit on destination network given an option
     * @param _value The airdropped value in native gas token on destination network given an option
     */
    function setOptionsAirdrop(uint8 _option, uint128 _gas, uint128 _value) public onlyOwner {
        optionsAirdrop[_option] = OptionsAirdrop(_gas, _value);
    }

    /* ========== Internal ========== */
    function _isLocalComposeMsgSender(address _addr) internal view returns (bool) {
        return localMsgSender[_addr];
    }

    function _isRemoteMsgSender(uint32 _eid, address _addr) internal view returns (bool) {
        return remoteMsgSender[_eid][_addr];
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

    /**
     *
     * @param _endpoint The the caller of function lzCompose() on the relayer contract, it should be the endpoint
     * @param _oft The composeMsg sender on local network, it should be the oft/adapter contract
     * @param _eid The eid to identify the network from where the composeMsg sent
     * @param _remoteSender The address to identiy the sender on the remote network
     */
    function _authorizeComposeMsgSender(
        address _endpoint,
        address _oft,
        uint32 _eid,
        address _remoteSender
    ) internal view returns (bool) {
        if (endpoint != _endpoint) revert InvalidEnpoint(endpoint, _endpoint);
        if (oft != _oft) revert InvalidOft(oft, _oft);
        if (!_isRemoteMsgSender(_eid, _remoteSender)) revert NotRemoteMsgSender(_eid, _remoteSender);
        return true;
    }

    function _authorizeOCCMsgSender(address _oft, uint32 _eid, address _remoteSender) internal view returns (bool) {
        if (oft != _oft) revert InvalidOft(oft, _oft);
        if (!_isRemoteMsgSender(_eid, _remoteSender)) revert NotRemoteMsgSender(_eid, _remoteSender);
        return true;
    }

    fallback() external payable {}
    receive() external payable {}
}
