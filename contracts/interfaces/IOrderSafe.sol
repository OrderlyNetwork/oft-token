// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

interface IOrderSafe {
    function claimOrder() external;
    function claimEsOrder() external;

    function stakeOrder() external;
    function unStakeOrder() external;

    function stakeEsOrder() external;
    function vestEsOrder() external;
    
}