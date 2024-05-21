// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { OrderBoxRelayerStorage } from "./storage/OrderBoxRelayerStorage.sol";
import { IOrderBoxRelayer } from "./interfaces/IOrderBoxRelayer.sol";
import { OrderRelayerBase } from "./base/OrderRelayerBase.sol";
import { OrderBase } from "./base/OrderBase.sol";
import { IOrderBox } from "./interfaces/IOrderBox.sol";

contract OrderBoxRelayer is IOrderBoxRelayer, ILayerZeroComposer, OrderRelayerBase, OrderBoxRelayerStorage {
    using OFTComposeMsgCodec for bytes;
    using SafeERC20 for IERC20;

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable override {
        bytes memory composeMsg = _message.composeMsg();
        uint32 srcEid = _message.srcEid();
        address remoteSender = OFTComposeMsgCodec.bytes32ToAddress(_message.composeFrom());
        require(
            _authorizeComposeMsgSender(msg.sender, _from, srcEid, remoteSender),
            "OrderlyBox: composeMsg sender check failed"
        );
        (address staker, uint256 amount) = abi.decode(composeMsg, (address, uint256));
        IERC20 token = IERC20(IOFT(oft).token());
        token.safeTransfer(orderBox, amount);
        IOrderBox(orderBox).stakeOrder(_getChainId(srcEid), staker, amount);
    }

    /* ========================= Only Owner ========================= */
    function setEids(uint256[] calldata _chainIds, uint32[] calldata _eids) public onlyOwner {
        require(_chainIds.length == _eids.length, "OrderBoxRelayer: invalid input length");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            eidMap[_chainIds[i]] = _eids[i];
            chainIdMap[_eids[i]] = _chainIds[i];
        }
    }

    function setOrderBox(address _orderBox) public onlyOwner {
        require(_orderBox != address(0), "OrderBoxRelayer: zero order box address");
        orderBox = _orderBox;
    }
}
