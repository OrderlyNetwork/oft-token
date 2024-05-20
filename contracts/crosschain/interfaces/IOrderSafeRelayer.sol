// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

struct StakeMsg {
    address staker;
    uint256 amount;
}

interface IOrderSafeRelayer {
    function sendStakeMsg(address staker, uint256 amount) external payable;
    function sendUnstakeMsg(address staker, uint256 amount) external;
    function setOrderSafe(address orderSafe) external;
    function setOrderBoxRelayer(address orderBoxRelayer) external;
    function getStakeFee(address staker, uint256 amount) external view returns (uint256);
}
