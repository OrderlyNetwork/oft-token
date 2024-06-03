// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OFTMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import { IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt } from "../layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { OrderRelayerBase } from "./base/OrderRelayerBase.sol";
import { IOrderSafeRelayer } from "./interfaces/IOrderSafeRelayer.sol";
import { Options } from "./interfaces/IOrderRelayer.sol";
import { OrderRelayerStorage } from "./storage/OrderRelayerStorage.sol";
import { OrderSafeRelayerStorage } from "./storage/OrderSafeRelayerStorage.sol";

contract OrderSafeRelayer is IOrderSafeRelayer, OrderRelayerBase, OrderSafeRelayerStorage {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    function sendStakeMsg(
        address _staker,
        uint256 _amount
    ) public payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        require(msg.sender == orderSafe, "OrderSafeRelayer: Only OrderSafe can call");
        if (IOFT(oft).approvalRequired()) {
            IERC20 token = IERC20(IOFT(oft).token());
            token.approve(oft, _amount);
        }
        uint32 orderEid = _getOrderEid();
        bytes memory options = _getOption(uint8(Options.STAKE_ORDER));
        bytes memory stakeMsg = abi.encode(_staker, _amount);
        SendParam memory sendParam = SendParam({
            dstEid: orderEid,
            to: OFTMsgCodec.addressToBytes32(orderBoxRelayer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: options,
            composeMsg: stakeMsg,
            oftCmd: ""
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        require(msg.value >= fee.nativeFee, "OrderSafeRelayer: insufficient lz fee");
        (msgReceipt, oftReceipt) = IOFT(oft).send{ value: fee.nativeFee }(sendParam, fee, payable(_staker));
        emit SendStakeMsg(orderEid, OFTMsgCodec.addressToBytes32(orderBoxRelayer), stakeMsg);
    }

    function sendUnstakeMsg(address _staker, uint256 _amount) public {}

    /* ========================= Only Owner ========================= */

    // Set the order safe address on vault side
    function setOrderSafe(address _orderSafe) public onlyOwner {
        require(_orderSafe != address(0), "OrderSafeRelayer: zero order safe address");
        orderSafe = _orderSafe;
    }

    function setOrderBoxRelayer(address _orderBoxRelayer) public onlyOwner {
        require(_orderBoxRelayer != address(0), "OrderSafeRelayer: zero order box relayer address");
        orderBoxRelayer = _orderBoxRelayer;
    }

    function setOrderChainId(uint256 _orderChainId, uint32 _orderEid) public onlyOwner {
        require(_orderChainId > 0, "OrderSafeRelayer: zero order chain id");
        require(_orderEid > 0, "OrderSafeRelayer: zero order eid");
        orderChainId = _orderChainId;
        eidMap[_orderChainId] = _orderEid;
        chainIdMap[_orderEid] = _orderChainId;
    }

    /* ========================= View ========================= */

    function getStakeFee(address _staker, uint256 _amount) public view override returns (uint256) {
        uint16 index = 0;
        uint128 lzReceiveGas = 200000;
        uint128 lzComposeGas = 500000;
        uint128 airdropValue = 0;
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(lzReceiveGas, airdropValue)
            .addExecutorLzComposeOption(index, lzComposeGas, airdropValue);
        bytes memory composeMsg = abi.encode(_staker, _amount);
        SendParam memory sendParam = SendParam({
            dstEid: _getOrderEid(),
            to: OFTMsgCodec.addressToBytes32(orderBoxRelayer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        return fee.nativeFee;
    }

    /* ========================= Internal ========================= */

    function _getOrderEid() internal view returns (uint32) {
        return eidMap[orderChainId];
    }
}
