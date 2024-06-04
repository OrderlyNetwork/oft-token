// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../utils/SoladyTest.sol";
import "../../../mocks/OrderTokenMock.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OrderTokenHandler is SoladyTest {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    OrderTokenMock orderToken;

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

    constructor(OrderTokenMock _orderToken) {
        orderToken = _orderToken;

        users[0] = user0;
        users[1] = user1;
        users[2] = user2;
        users[3] = user3;
        users[4] = user4;
        users[5] = user5;
    }

    /*//////////////////////////////////////////////////////////////////////////
                               TARGET FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    struct ApproveTemps {
        address owner;
        address spender;
    }

    function approve(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 amount) public {
        ApproveTemps memory t;
        // PRE-CONDITIONS
        t.owner = randomAddress(ownerIndexSeed);
        t.spender = randomAddress(spenderIndexSeed);

        if (t.owner == t.spender) return;

        // ACTION
        vm.prank(t.owner);
        orderToken.approve(t.spender, amount);

        // POST-CONDITIONS
        assertEq(orderToken.allowance(t.owner, t.spender), amount, "PD-04: Allowance != Amount");
    }

    function transfer(uint256 fromIndexSeed, uint256 toIndexSeed, uint256 amount) public {
        TransferTemps memory t;
        // PRE-CONDITIONS
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, orderToken.balanceOf(t.from));

        BeforeAfter memory beforeAfter;
        beforeAfter.fromBalanceBefore = orderToken.balanceOf(t.from);
        beforeAfter.toBalanceBefore = orderToken.balanceOf(t.to);
        beforeAfter.totalSupplyBefore = orderToken.totalSupply();

        // ACTION
        vm.prank(t.from);
        (t.success, ) = address(orderToken).call(abi.encodeWithSelector(ERC20.transfer.selector, t.to, amount));

        // POST-CONDITIONS
        if (t.success) {
            _checkPostTransferInvariants(beforeAfter, t, amount);
        }
    }

    struct TransferTemps {
        address sender;
        address from;
        address to;
        bool success;
    }

    function transferFrom(uint256 senderIndexSeed, uint256 fromIndexSeed, uint256 toIndexSeed, uint256 amount) public {
        TransferTemps memory t;
        // PRE-CONDITIONS
        t.sender = randomAddress(senderIndexSeed);
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, orderToken.balanceOf(t.from));

        BeforeAfter memory beforeAfter;
        beforeAfter.fromBalanceBefore = orderToken.balanceOf(t.from);
        beforeAfter.toBalanceBefore = orderToken.balanceOf(t.to);
        beforeAfter.totalSupplyBefore = orderToken.totalSupply();

        if (orderToken.allowance(t.from, t.sender) < amount) {
            t.sender = t.from;
        }

        // ACTION
        vm.prank(t.sender);
        (t.success, ) = address(orderToken).call(
            abi.encodeWithSelector(ERC20.transferFrom.selector, t.from, t.to, amount)
        );

        // POST-CONDITIONS
        if (t.success) {
            _checkPostTransferInvariants(beforeAfter, t, amount);
        }
    }

    function _checkPostTransferInvariants(
        BeforeAfter memory beforeAfter,
        TransferTemps memory t,
        uint256 amount
    ) internal {
        beforeAfter.fromBalanceAfter = orderToken.balanceOf(t.from);
        beforeAfter.toBalanceAfter = orderToken.balanceOf(t.to);
        beforeAfter.totalSupplyAfter = orderToken.totalSupply();

        // Assert balance updates between addresses are valid.
        if (t.from != t.to) {
            assertEq(
                beforeAfter.fromBalanceAfter + amount,
                beforeAfter.fromBalanceBefore,
                "PD-07 & PD-11: balance after + amount != balance before"
            );
            assertEq(
                beforeAfter.toBalanceAfter,
                beforeAfter.toBalanceBefore + amount,
                "PD-07 & PD-11: balance after != balance before + amount"
            );
        } else {
            assertEq(
                beforeAfter.fromBalanceAfter,
                beforeAfter.fromBalanceBefore,
                "PD-08 & PD-12: balance after != balance before"
            );
        }

        // Assert totalSupply stays the same.
        assertEq(
            beforeAfter.totalSupplyBefore,
            beforeAfter.totalSupplyAfter,
            "PD-09 & PD-13: total supply before != total supply after"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function randomAddress(uint256 seed) internal view returns (address) {
        return users[_bound(seed, 0, users.length - 1)];
    }
}
