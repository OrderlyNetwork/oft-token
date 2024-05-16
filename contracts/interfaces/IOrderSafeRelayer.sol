// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IOrderSafeRelayer {
    function sendStakeMsg(address staker, uint256 amount) external payable;
    // function sendUnstakeMsg(address staker, uint256 amount) external;
    function setOrderSafe(address _orderSafe) external;

    function setOrderBoxRelayer(address _orderBoxRelayer) external;
}
