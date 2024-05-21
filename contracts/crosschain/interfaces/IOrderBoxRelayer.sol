// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IOrderBoxRelayer {
    // function boxSendUnstakeMsg(address staker, uint256 amount) external;
    function setEids(uint256[] calldata _chainIds, uint32[] calldata _eids) external;
    function setOrderBox(address _orderBox) external;
}
