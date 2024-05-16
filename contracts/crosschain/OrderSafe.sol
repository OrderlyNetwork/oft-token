// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OrderBase } from "../base/OrderBase.sol";
import { OrderSafeStorage } from "../storage/OrderSafeStorage.sol";
import { IOrderSafe } from "../interfaces/IOrderSafe.sol";

import { IOrderSafeRelayer } from "../interfaces/IOrderSafeRelayer.sol";

contract OrderSafe is OrderBase, IOrderSafe, OrderSafeStorage {
    // using OFTComposeMsgCodec for bytes;
    using SafeERC20 for IERC20;

    function stakeOrder(address staker, uint256 amount) public payable whenNotPaused {
        require(msg.sender == staker, "OrderSafe: sender must be staker");
        // Get the token address from the of contract, it could be the oft contract itself or a native erc20 contract
        IERC20 token = IERC20(IOFT(oft).token());

        // Transfer the amount from the staker to the relayer contract
        // Staker should approve the relayer contract to spend the amount first
        token.safeTransferFrom(staker, safeRelayer, amount);
        // Call the relayer contract to send the stake message
        IOrderSafeRelayer(safeRelayer).sendStakeMsg{ value: msg.value }(staker, amount);
        emit OrderStaked(staker, amount);
    }

    /* ========================= Only Owner ========================= */

    function setOrderRelayer(address _orderRelayer) public onlyOwner {
        require(_orderRelayer != address(0), "OrderSafe: invalid order relayer address");
        safeRelayer = _orderRelayer;
        emit OrderRelayerSet(_orderRelayer);
    }
}
