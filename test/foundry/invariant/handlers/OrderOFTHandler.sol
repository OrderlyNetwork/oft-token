// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../utils/SoladyTest.sol";
import "../../../mocks/OrderOFTMock.sol";
import "../../../mocks/OrderAdapterMock.sol";
import "contracts/OrderOFT.sol";

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { IOFT, SendParam, OFTReceipt, MessagingReceipt } from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingFee } from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSenderUpgradeable.sol";
import { OFTCoreUpgradeable } from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";

import { VerifyHelper } from "test/foundry/invariant/helpers/VerifyHelper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract OrderOFTHandler is SoladyTest {
    using OptionsBuilder for bytes;
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    OrderOFTMock[] public oftInstances;
    IERC20 public adapterToken;
    VerifyHelper verifyHelper;

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
        uint256 fromSrcBalanceBefore;
        uint256 toSrcBalanceBefore;
        uint256 srcTotalSupplyBefore;
        uint256 fromDstBalanceBefore;
        uint256 toDstBalanceBefore;
        uint256 dstTotalSupplyBefore;
        uint256 fromSrcBalanceAfter;
        uint256 toSrcBalanceAfter;
        uint256 srcTotalSupplyAfter;
        uint256 fromDstBalanceAfter;
        uint256 toDstBalanceAfter;
        uint256 dstTotalSupplyAfter;
    }

    event MessageAddress(string a, address b);

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(OrderOFTMock[] memory _oftInstances, VerifyHelper _verifyHelper) {
        oftInstances = _oftInstances;

        adapterToken = OrderAdapterMock(address(oftInstances[0])).getInnerToken();

        verifyHelper = _verifyHelper;

        users[0] = user0;
        users[1] = user1;
        users[2] = user2;
        users[3] = user3;
        users[4] = user4;
        users[5] = user5;

        for (uint i = 0; i < oftInstances.length; i++) {
            if (i == 0) {
                vm.prank(user0);
                adapterToken.approve(user0, type(uint256).max);

                vm.prank(user1);
                adapterToken.approve(user1, type(uint256).max);

                vm.prank(user2);
                adapterToken.approve(user2, type(uint256).max);

                vm.prank(user3);
                adapterToken.approve(user3, type(uint256).max);

                vm.prank(user4);
                adapterToken.approve(user4, type(uint256).max);

                vm.prank(user5);
                adapterToken.approve(user5, type(uint256).max);
            } else {
                vm.prank(user0);
                oftInstances[i].approve(user0, type(uint256).max);

                vm.prank(user1);
                oftInstances[i].approve(user1, type(uint256).max);

                vm.prank(user2);
                oftInstances[i].approve(user2, type(uint256).max);

                vm.prank(user3);
                oftInstances[i].approve(user3, type(uint256).max);

                vm.prank(user4);
                oftInstances[i].approve(user4, type(uint256).max);

                vm.prank(user5);
                oftInstances[i].approve(user5, type(uint256).max);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                               TARGET FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    struct ApproveTemps {
        OrderOFTMock srcOft;
        address owner;
        address spender;
    }

    function approve(uint256 srcOftSeed, uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 amount) public {
        ApproveTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftSeed);
        t.owner = randomAddress(ownerIndexSeed);
        t.spender = randomAddress(spenderIndexSeed);

        if (t.owner == t.spender) return;

        // ACTION
        if (t.srcOft == oftInstances[0]) {
            vm.prank(t.owner);
            adapterToken.approve(t.spender, amount);

            // POST-CONDTION
            assertEq(adapterToken.allowance(t.owner, t.spender), amount, "PD-04: Allowance != Amount");
        } else {
            vm.prank(t.owner);
            t.srcOft.approve(t.spender, amount);

            // POST-CONDITION
            assertEq(t.srcOft.allowance(t.owner, t.spender), amount, "PD-04: Allowance != Amount");
        }
    }

    struct TransferTemps {
        OrderOFTMock srcOft;
        address sender;
        address from;
        address to;
        bool success;
    }

    function transfer(uint256 srcOftSeed, uint256 fromIndexSeed, uint256 toIndexSeed, uint256 amount) public {
        TransferTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftSeed);
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);

        BeforeAfter memory beforeAfter;
        if (t.srcOft == oftInstances[0]) {
            amount = _bound(amount, 0, adapterToken.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = adapterToken.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = adapterToken.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = adapterToken.totalSupply();
        } else {
            amount = _bound(amount, 0, t.srcOft.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = t.srcOft.totalSupply();
        }

        // ACTION
        if (t.srcOft == oftInstances[0]) {
            vm.prank(t.from);
            (t.success, ) = address(adapterToken).call(abi.encodeWithSelector(IERC20.transfer.selector, t.to, amount));
        } else {
            vm.prank(t.from);
            (t.success, ) = address(t.srcOft).call(
                abi.encodeWithSelector(ERC20Upgradeable.transfer.selector, t.to, amount)
            );
        }

        // POST-CONDITIONS
        if (t.success) {
            _checkPostTransferInvariants(beforeAfter, t, amount);
        }
    }

    function transferFrom(
        uint256 srcOftSeed,
        uint256 senderIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint256 amount
    ) public {
        TransferTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftSeed);
        t.sender = randomAddress(senderIndexSeed);
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);

        BeforeAfter memory beforeAfter;
        if (t.srcOft == oftInstances[0]) {
            amount = _bound(amount, 0, adapterToken.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = adapterToken.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = adapterToken.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = adapterToken.totalSupply();

            if (adapterToken.allowance(t.from, t.sender) < amount) {
                t.sender = t.from;
            }
        } else {
            amount = _bound(amount, 0, t.srcOft.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = t.srcOft.totalSupply();

            if (t.srcOft.allowance(t.from, t.sender) < amount) {
                t.sender = t.from;
            }
        }

        // ACTION
        if (t.srcOft == oftInstances[0]) {
            vm.prank(t.sender);
            (t.success, ) = address(adapterToken).call(
                abi.encodeWithSelector(IERC20.transferFrom.selector, t.from, t.to, amount)
            );
        } else {
            vm.prank(t.sender);
            (t.success, ) = address(t.srcOft).call(
                abi.encodeWithSelector(ERC20Upgradeable.transferFrom.selector, t.from, t.to, amount)
            );
        }

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
        if (t.srcOft == oftInstances[0]) {
            beforeAfter.fromSrcBalanceAfter = adapterToken.balanceOf(t.from);
            beforeAfter.toSrcBalanceAfter = adapterToken.balanceOf(t.to);
            beforeAfter.srcTotalSupplyAfter = adapterToken.totalSupply();
        } else {
            beforeAfter.fromSrcBalanceAfter = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceAfter = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyAfter = t.srcOft.totalSupply();
        }

        // Assert balance updates between addresses are valid.
        if (t.from != t.to) {
            assertEq(
                beforeAfter.fromSrcBalanceAfter + amount,
                beforeAfter.fromSrcBalanceBefore,
                "PD-07 & PD-11: balance after + amount != balance before"
            );
            assertEq(
                beforeAfter.toSrcBalanceAfter,
                beforeAfter.toSrcBalanceBefore + amount,
                "PD-07 & PD-11: balance after != balance before + amount"
            );
        } else {
            assertEq(
                beforeAfter.fromSrcBalanceAfter,
                beforeAfter.fromSrcBalanceBefore,
                "PD-08 & PD-12: balance after != balance before"
            );
        }

        // Assert totalSupply stays the same.
        assertEq(
            beforeAfter.srcTotalSupplyBefore,
            beforeAfter.srcTotalSupplyAfter,
            "PD-09 & PD-13: total supply before != total supply after"
        );
    }

    struct SendTemps {
        OrderOFTMock srcOft;
        OrderOFTMock dstOft;
        address sender;
        address from;
        address to;
        bool success;
    }

    function send(
        uint256 srcOftSeed,
        uint256 dstOftSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint256 amount
    ) public {
        SendTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftSeed);
        t.dstOft = randomOft(dstOftSeed);
        if (address(t.srcOft) == address(t.dstOft)) return;
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);

        emit MessageAddress("Initial Send Source Endpoint:", address(t.srcOft.endpoint()));
        emit MessageAddress("Initial Send Destination Endpoint:", address(t.dstOft.endpoint()));

        BeforeAfter memory beforeAfter;
        if (t.srcOft == oftInstances[0]) {
            amount = _bound(amount, 0, adapterToken.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = adapterToken.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = adapterToken.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = adapterToken.totalSupply();
            beforeAfter.fromDstBalanceBefore = t.dstOft.balanceOf(t.from);
            beforeAfter.toDstBalanceBefore = t.dstOft.balanceOf(t.to);
            beforeAfter.dstTotalSupplyBefore = t.dstOft.totalSupply();
        } else if (t.dstOft == oftInstances[0]) {
            amount = _bound(amount, 0, t.srcOft.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = t.srcOft.totalSupply();
            beforeAfter.fromDstBalanceBefore = adapterToken.balanceOf(t.from);
            beforeAfter.toDstBalanceBefore = adapterToken.balanceOf(t.to);
            beforeAfter.dstTotalSupplyBefore = adapterToken.totalSupply();
        } else {
            amount = _bound(amount, 0, t.srcOft.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = t.srcOft.totalSupply();
            beforeAfter.fromDstBalanceBefore = t.dstOft.balanceOf(t.from);
            beforeAfter.toDstBalanceBefore = t.dstOft.balanceOf(t.to);
            beforeAfter.dstTotalSupplyBefore = t.dstOft.totalSupply();
        }

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            t.dstOft.endpoint().eid(),
            addressToBytes32(t.to),
            amount,
            t.srcOft.removeDust(amount),
            options,
            "",
            ""
        );
        MessagingFee memory fee = t.srcOft.quoteSend(sendParam, false);

        // ACTION
        bytes memory returnData;
        vm.prank(t.from);
        (t.success, returnData) = payable(address(t.srcOft)).call{ value: fee.nativeFee }(
            abi.encodeWithSelector(OFTCoreUpgradeable.send.selector, sendParam, fee, address(this))
        );

        if (t.success) {
            emit MessageAddress("Pre verification endpoint", address(t.srcOft.endpoint()));
            emit MessageAddress("Destination OFT", address(t.dstOft));
            verifyHelper.verifyPackets(t.dstOft.endpoint().eid(), address(t.dstOft));

            (, OFTReceipt memory decodedOFTReceipt) = abi.decode(returnData, (MessagingReceipt, OFTReceipt));

            if (t.srcOft == oftInstances[0]) {
                beforeAfter.fromSrcBalanceAfter = adapterToken.balanceOf(t.from);
                beforeAfter.toSrcBalanceAfter = adapterToken.balanceOf(t.to);
                beforeAfter.srcTotalSupplyAfter = adapterToken.totalSupply();
                beforeAfter.fromDstBalanceAfter = t.dstOft.balanceOf(t.from);
                beforeAfter.toDstBalanceAfter = t.dstOft.balanceOf(t.to);
                beforeAfter.dstTotalSupplyAfter = t.dstOft.totalSupply();
            } else if (t.dstOft == oftInstances[0]) {
                beforeAfter.fromSrcBalanceAfter = t.srcOft.balanceOf(t.from);
                beforeAfter.toSrcBalanceAfter = t.srcOft.balanceOf(t.to);
                beforeAfter.srcTotalSupplyAfter = t.srcOft.totalSupply();
                beforeAfter.fromDstBalanceAfter = adapterToken.balanceOf(t.from);
                beforeAfter.toDstBalanceAfter = adapterToken.balanceOf(t.to);
                beforeAfter.dstTotalSupplyAfter = adapterToken.totalSupply();
            } else {
                beforeAfter.fromSrcBalanceAfter = t.srcOft.balanceOf(t.from);
                beforeAfter.toSrcBalanceAfter = t.srcOft.balanceOf(t.to);
                beforeAfter.srcTotalSupplyAfter = t.srcOft.totalSupply();
                beforeAfter.fromDstBalanceAfter = t.dstOft.balanceOf(t.from);
                beforeAfter.toDstBalanceAfter = t.dstOft.balanceOf(t.to);
                beforeAfter.dstTotalSupplyAfter = t.dstOft.totalSupply();
            }

            assertEq(
                beforeAfter.fromSrcBalanceAfter,
                beforeAfter.fromSrcBalanceBefore - decodedOFTReceipt.amountSentLD,
                "OrderTokenA balance should decrease"
            );
            assertEq(
                beforeAfter.toDstBalanceAfter,
                beforeAfter.toDstBalanceBefore + decodedOFTReceipt.amountReceivedLD,
                "OrderTokenB balance should increase"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function randomAddress(uint256 seed) internal view returns (address) {
        return users[_bound(seed, 0, users.length - 1)];
    }

    function randomOft(uint256 seed) internal view returns (OrderOFTMock) {
        return oftInstances[_bound(seed, 0, oftInstances.length - 1)];
    }

    event MessageBytes(string a, bytes32 b);

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
