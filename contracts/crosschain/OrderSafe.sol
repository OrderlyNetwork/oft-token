// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OrderBaseUpgradeable } from "./base/OrderBaseUpgradeable.sol";
import { OrderSafeStorage } from "./storage/OrderSafeStorage.sol";
import { IOrderSafe, MessagingReceipt, OFTReceipt } from "./interfaces/IOrderSafe.sol";
import { IOrderSafeRelayer, StakeMsg } from "./interfaces/IOrderSafeRelayer.sol";

contract OrderSafe is IOrderSafe, OrderBaseUpgradeable, OrderSafeStorage {
    // using OFTComposeMsgCodec for bytes;
    using SafeERC20 for IERC20;

    function stakeOrder(
        address _staker,
        uint256 _amount
    ) public payable whenNotPaused returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        require(msg.sender == _staker, "OrderSafe: sender must be staker");
        // Get the token address from the of contract, it could be the oft contract itself or a native erc20 contract
        IERC20 token = IERC20(IOFT(oft).token());

        // Transfer the amount from the staker to the relayer contract
        // Staker should approve the safe contract to spend the amount first
        token.safeTransferFrom(_staker, safeRelayer, _amount);
        // Call the relayer contract to send the stake message
        (msgReceipt, oftReceipt) = IOrderSafeRelayer(safeRelayer).sendStakeMsg{ value: msg.value }(_staker, _amount);
        emit OrderStaked(_staker, _amount);
    }

    function unstakeOrder(address _staker, uint256 _amount) public whenNotPaused {
        require(msg.sender == _staker, "OrderSafe: sender must be staker");
        // Call the relayer contract to send the unstake message
        IOrderSafeRelayer(safeRelayer).sendUnstakeMsg(_staker, _amount);
    }

    /* ========================= Only Owner ========================= */

    function setOrderRelayer(address _orderRelayer) public onlyOwner {
        require(_orderRelayer != address(0), "OrderSafe: invalid order relayer address");
        safeRelayer = _orderRelayer;
        emit OrderRelayerSet(_orderRelayer);
    }

    function setOft(address _oft) public onlyOwner {
        require(_oft != address(0), "OrderSafe: invalid oft address");
        oft = _oft;
    }

    /* ========================= View ========================= */

    function getStakeFee(address _staker, uint256 _amount) public view returns (uint256) {
        return IOrderSafeRelayer(safeRelayer).getStakeFee(_staker, _amount);
    }
}
