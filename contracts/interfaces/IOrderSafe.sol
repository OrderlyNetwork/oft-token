// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IOrderSafe {
    event OrderRelayerSet(address indexed orderRelayer);
    event OrderStaked(address indexed staker, uint256 amount);
    event OrderUnstakeRequired(address indexed staker, uint256 amount);
    event OrderUnstakeCompleted(address indexed staker, uint256 amount);

    function setOrderRelayer(address _orderRelayer) external;
    function setOft(address _oft) external;
}
