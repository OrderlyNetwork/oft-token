// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IOrderBox {
    event OrderStaked(uint256 indexed chainId, address indexed staker, uint256 amount);
    event OrderRelayerSet(address indexed orderRelayer);
    function stakeOrder(uint256 chainId, address staker, uint256 amount) external;
    function setOft(address _oft) external;
    // function unstakeOrder(int256 chainId, address staker, uint256 amount) external;
}
