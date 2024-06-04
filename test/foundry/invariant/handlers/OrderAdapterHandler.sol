// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../utils/SoladyTest.sol";
import "../../../mocks/OrderAdapterMock.sol";

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract OrderAdapterHandler is SoladyTest {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    OrderAdapterMock orderAdapter;

    /*//////////////////////////////////////////////////////////////////////////
                                   HANDLER VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address user0 = vm.addr(uint256(keccak256("User0")));
    address user1 = vm.addr(uint256(keccak256("User1")));
    address user2 = vm.addr(uint256(keccak256("User2")));
    address user3 = vm.addr(uint256(keccak256("User3")));
    address user4 = vm.addr(uint256(keccak256("User4")));
    address user5 = vm.addr(uint256(keccak256("User5")));

    address[6] users;

    struct BeforeAfter {
        uint256 fromBalanceBefore;
        uint256 toBalanceBefore;
        uint256 totalSupplyBefore;
        uint256 fromBalanceAfter;
        uint256 toBalanceAfter;
        uint256 totalSupplyAfter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(address _orderAdapter) {
        orderAdapter = OrderAdapterMock(_orderAdapter);

        users[0] = user0;
        users[1] = user1;
        users[2] = user2;
        users[3] = user3;
        users[4] = user4;
        users[5] = user5;
    }

    function setOrderedNonce(bool _orderedNonce) public {
        vm.prank(orderAdapter.owner());
        orderAdapter.setOrderedNonce(_orderedNonce);

        assertEq(orderAdapter.orderedNonce(), _orderedNonce, "OrderedNonce was not set");
    }
}
