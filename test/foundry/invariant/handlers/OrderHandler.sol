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
import { Origin } from "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import { VerifyHelper } from "test/foundry/invariant/helpers/VerifyHelper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev OrderHandler contains functions from the target contracts OrderOFT.sol,
///      OrderToken.sol, and OrderAdapter.sol.
///      These functions contain conditional invariants.
contract OrderHandler is SoladyTest {
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

    mapping(uint32 => MessagingReceipt[]) messageReceipts;
    mapping(uint32 => OFTReceipt[]) oftReceipts;
    mapping(uint32 => PacketVariables[]) packetVariables;

    struct PacketVariables {
        OrderOFTMock srcOft;
        address from;
        address to;
        bytes message;
    }

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
        uint256 adapterBalanceBefore;
        uint256 adapterBalanceAfter;
        uint64 maxReceivedNonceBefore;
        uint64 maxReceivedNonceAfter;
        uint64 outboundNonceBefore;
        uint64 outboundNonceAfter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(OrderOFTMock[] memory _oftInstances, VerifyHelper _verifyHelper) {
        oftInstances = _oftInstances;

        adapterToken = IERC20(OrderAdapterMock(address(oftInstances[0])).token());

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

    // forgefmt: disable-start
    /**************************************************************************************************************************************/
    /*** Invariant Tests for function approve                                                                                           ***/
    /***************************************************************************************************************************************

        * OT-02: Allowance Matches Approved Amount

    /**************************************************************************************************************************************/
    /*** Assertions that must be true when a user calls approve                                                                         ***/
    /**************************************************************************************************************************************/
    // forgefmt: disable-end

    struct ApproveTemps {
        OrderOFTMock srcOft;
        address owner;
        address spender;
    }

    function approve(uint256 srcOftIndexSeed, uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 amount) public {
        ApproveTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftIndexSeed);
        t.owner = randomAddress(ownerIndexSeed);
        t.spender = randomAddress(spenderIndexSeed);

        if (t.owner == t.spender) return;

        // ACTION
        if (t.srcOft == oftInstances[0]) {
            vm.prank(t.owner);
            adapterToken.approve(t.spender, amount);

            // POST-CONDTION
            assertEq(adapterToken.allowance(t.owner, t.spender), amount, "OT-02: Allowance Matches Approved Amount");
        } else {
            vm.prank(t.owner);
            t.srcOft.approve(t.spender, amount);

            // POST-CONDITION
            assertEq(t.srcOft.allowance(t.owner, t.spender), amount, "OT-02: Allowance Matches Approved Amount");
        }
    }

    // forgefmt: disable-start
    /**************************************************************************************************************************************/
    /*** Invariant Tests for functions transfer and transferFrom                                                                        ***/
    /***************************************************************************************************************************************

        * OT-03: ERC20 Balance Changes By Amount For Sender And Receiver Upon Transfer
        * OT-04: ERC20 Balance Remains The Same Upon Self-Transfer
        * OT-05: ERC20 Total Supply Remains The Same Upon Transfer

    /**************************************************************************************************************************************/
    /*** Assertions that must be true when a user calls transfer or transferFrom                                                        ***/
    /**************************************************************************************************************************************/
    // forgefmt: disable-end

    struct TransferTemps {
        OrderOFTMock srcOft;
        address sender;
        address from;
        address to;
        bool success;
    }

    function transfer(uint256 srcOftIndexSeed, uint256 fromIndexSeed, uint256 toIndexSeed, uint256 amount) public {
        TransferTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftIndexSeed);
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
        uint256 srcOftIndexSeed,
        uint256 senderIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint256 amount
    ) public {
        TransferTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftIndexSeed);
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
                "OT-03: balance after + amount != balance before"
            );
            assertEq(
                beforeAfter.toSrcBalanceAfter,
                beforeAfter.toSrcBalanceBefore + amount,
                "OT-03: balance after != balance before + amount"
            );
        } else {
            assertEq(
                beforeAfter.fromSrcBalanceAfter,
                beforeAfter.fromSrcBalanceBefore,
                "OT-04: balance after != balance before"
            );
        }

        // Assert totalSupply stays the same.
        assertEq(
            beforeAfter.srcTotalSupplyBefore,
            beforeAfter.srcTotalSupplyAfter,
            "OT-05: total supply before != total supply after"
        );
    }

    // forgefmt: disable-start
    /**************************************************************************************************************************************/
    /*** Invariant Tests for function send                                                                                              ***/
    /***************************************************************************************************************************************

        * OT-06: Source Token Balance Should Decrease On Send
        * OT-07: Adapter Balance Should Increase On Send
        * OT-08: Native Token Total Supply Should Not Change On Send
        * OT-09: Source OFT Total Supply Should Decrease On Send
        * OT-10: Outbound Nonce Should Increase By 1

    /**************************************************************************************************************************************/
    /*** Assertions that must be true when a user calls send                                                                            ***/
    /**************************************************************************************************************************************/
    // forgefmt: disable-end

    struct SendTemps {
        OrderOFTMock srcOft;
        OrderOFTMock dstOft;
        uint32 dstEid;
        address sender;
        address from;
        address to;
        bool success;
    }

    function send(
        uint256 srcOftIndexSeed,
        uint256 dstOftIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint256 amount
    ) public {
        SendTemps memory t;
        // PRE-CONDITIONS
        t.srcOft = randomOft(srcOftIndexSeed);
        t.dstOft = randomOft(dstOftIndexSeed);
        t.dstEid = t.dstOft.endpoint().eid();
        if (address(t.srcOft) == address(t.dstOft)) return;
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);

        PacketVariables memory packetVars;
        packetVars.srcOft = t.srcOft;
        packetVars.from = t.from;
        packetVars.to = t.to;

        BeforeAfter memory beforeAfter;
        if (t.srcOft == oftInstances[0]) {
            amount = _bound(amount, 0, adapterToken.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = adapterToken.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = adapterToken.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = adapterToken.totalSupply();
            beforeAfter.adapterBalanceBefore = adapterToken.balanceOf(address(t.srcOft));
        } else if (t.dstOft == oftInstances[0]) {
            amount = _bound(amount, 0, t.srcOft.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = t.srcOft.totalSupply();
        } else {
            amount = _bound(amount, 0, t.srcOft.balanceOf(t.from));
            beforeAfter.fromSrcBalanceBefore = t.srcOft.balanceOf(t.from);
            beforeAfter.toSrcBalanceBefore = t.srcOft.balanceOf(t.to);
            beforeAfter.srcTotalSupplyBefore = t.srcOft.totalSupply();
        }
        beforeAfter.outboundNonceBefore = t.srcOft.endpoint().outboundNonce(
            address(t.srcOft),
            t.dstEid,
            addressToBytes32(address(t.dstOft))
        );

        if (amount == 0) return;

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            t.dstEid,
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
        vm.startPrank(t.from);
        (t.success, returnData) = payable(address(t.srcOft)).call{ value: fee.nativeFee }(
            abi.encodeWithSelector(OFTCoreUpgradeable.send.selector, sendParam, fee, address(this))
        );
        vm.stopPrank();

        if (t.success) {
            (MessagingReceipt memory decodedMessagingReceipt, OFTReceipt memory decodedOFTReceipt) = abi.decode(
                returnData,
                (MessagingReceipt, OFTReceipt)
            );

            (bytes memory message, ) = t.srcOft.buildMsgAndOptions(sendParam, decodedOFTReceipt.amountReceivedLD);
            packetVars.message = message;

            // Pushing message receipts to the front
            messageReceipts[t.dstEid].push(); // Increase the array size by 1
            for (uint i = messageReceipts[t.dstEid].length - 1; i > 0; i--) {
                messageReceipts[t.dstEid][i] = messageReceipts[t.dstEid][i - 1]; // Shift elements to the right
            }
            messageReceipts[t.dstEid][0] = decodedMessagingReceipt; // Insert the new element at the front
            // Pushing OFT receipts to the front
            oftReceipts[t.dstEid].push(); // Increase the array size by 1
            for (uint i = oftReceipts[t.dstEid].length - 1; i > 0; i--) {
                oftReceipts[t.dstEid][i] = oftReceipts[t.dstEid][i - 1]; // Shift elements to the right
            }
            oftReceipts[t.dstEid][0] = decodedOFTReceipt;
            // Pushing packet variables to the front
            packetVariables[t.dstEid].push(); // Increase the array size by 1
            for (uint i = packetVariables[t.dstEid].length - 1; i > 0; i--) {
                packetVariables[t.dstEid][i] = packetVariables[t.dstEid][i - 1]; // Shift elements to the right
            }
            packetVariables[t.dstEid][0] = packetVars;

            if (t.srcOft == oftInstances[0]) {
                beforeAfter.fromSrcBalanceAfter = adapterToken.balanceOf(t.from);
                beforeAfter.toSrcBalanceAfter = adapterToken.balanceOf(t.to);
                beforeAfter.srcTotalSupplyAfter = adapterToken.totalSupply();
                beforeAfter.adapterBalanceAfter = adapterToken.balanceOf(address(t.srcOft));
            } else if (t.dstOft == oftInstances[0]) {
                beforeAfter.fromSrcBalanceAfter = t.srcOft.balanceOf(t.from);
                beforeAfter.toSrcBalanceAfter = t.srcOft.balanceOf(t.to);
                beforeAfter.srcTotalSupplyAfter = t.srcOft.totalSupply();
                beforeAfter.fromDstBalanceAfter = adapterToken.balanceOf(t.from);
            } else {
                beforeAfter.fromSrcBalanceAfter = t.srcOft.balanceOf(t.from);
                beforeAfter.toSrcBalanceAfter = t.srcOft.balanceOf(t.to);
                beforeAfter.srcTotalSupplyAfter = t.srcOft.totalSupply();
            }
            beforeAfter.outboundNonceAfter = t.srcOft.endpoint().outboundNonce(
                address(t.srcOft),
                t.dstEid,
                addressToBytes32(address(t.dstOft))
            );

            assertEq(
                beforeAfter.fromSrcBalanceAfter,
                beforeAfter.fromSrcBalanceBefore - decodedOFTReceipt.amountSentLD,
                "OT-06: Source Token Balance Should Decrease On Send"
            );
            if (t.srcOft == oftInstances[0]) {
                assertEq(
                    beforeAfter.adapterBalanceAfter,
                    beforeAfter.adapterBalanceBefore + decodedOFTReceipt.amountSentLD,
                    "OT-07: Adapter Balance Should Increase On Send"
                );
                assertEq(
                    beforeAfter.srcTotalSupplyAfter,
                    beforeAfter.srcTotalSupplyBefore,
                    "OT-08: Native Token Total Supply Should Not Change On Send"
                );
            } else {
                assertEq(
                    beforeAfter.srcTotalSupplyAfter,
                    beforeAfter.srcTotalSupplyBefore - decodedOFTReceipt.amountSentLD,
                    "OT-09: Source OFT Total Supply Should Decrease On Send"
                );
            }
            assertEq(
                beforeAfter.outboundNonceAfter,
                beforeAfter.outboundNonceBefore + 1,
                "OT-10: Outbound Nonce Should Increase By 1"
            );
        }
    }

    // forgefmt: disable-start
    /**************************************************************************************************************************************/
    /*** Invariant Tests for function send                                                                                              ***/
    /***************************************************************************************************************************************

        * OT-11: Max Received Nonce Should Increase By 1 on lzReceive
        * OT-12: Destination Token Balance Should Increase on lzReceive
        * OT-13: Adapter Balance Should Decrease on lzReceive
        * OT-14: Native Token Total Supply Should Not Change on lzReceive
        * OT-15: Destination Total Supply Should Increase on lzReceive

    /**************************************************************************************************************************************/
    /*** Assertions that must be true when a user calls send                                                                            ***/
    /**************************************************************************************************************************************/
    // forgefmt: disable-end

    struct VerifyPacketTemps {
        OrderOFTMock dstOft;
        uint32 dstEid;
    }

    function verifyPackets(uint256 dstOftIndexSeed) public {
        VerifyPacketTemps memory t;
        PacketVariables memory p;
        // PRE-CONDITIONS
        t.dstOft = randomOft(dstOftIndexSeed);
        t.dstEid = t.dstOft.endpoint().eid();
        if (packetVariables[t.dstEid].length == 0) return;
        p = packetVariables[t.dstEid][packetVariables[t.dstEid].length - 1];

        BeforeAfter memory beforeAfter;
        if (t.dstOft == oftInstances[0]) {
            beforeAfter.fromDstBalanceBefore = adapterToken.balanceOf(p.from);
            beforeAfter.toDstBalanceBefore = adapterToken.balanceOf(p.to);
            beforeAfter.dstTotalSupplyBefore = adapterToken.totalSupply();
            beforeAfter.adapterBalanceBefore = adapterToken.balanceOf(address(t.dstOft));
        } else {
            beforeAfter.fromDstBalanceBefore = t.dstOft.balanceOf(p.from);
            beforeAfter.toDstBalanceBefore = t.dstOft.balanceOf(p.to);
            beforeAfter.dstTotalSupplyBefore = t.dstOft.totalSupply();
        }
        beforeAfter.maxReceivedNonceBefore = t.dstOft.getMaxReceivedNonce(
            p.srcOft.endpoint().eid(),
            addressToBytes32(address(p.srcOft))
        );

        // ACTION

        verifyHelper.verifyPackets(t.dstEid, addressToBytes32(address(t.dstOft)), 1);

        uint256 amountSentLD = oftReceipts[t.dstEid][oftReceipts[t.dstEid].length - 1].amountSentLD;
        uint256 amountReceivedLD = oftReceipts[t.dstEid][oftReceipts[t.dstEid].length - 1].amountReceivedLD;

        messageReceipts[t.dstEid].pop();
        oftReceipts[t.dstEid].pop();
        packetVariables[t.dstEid].pop();

        if (t.dstOft == oftInstances[0]) {
            beforeAfter.fromDstBalanceAfter = adapterToken.balanceOf(p.from);
            beforeAfter.toDstBalanceAfter = adapterToken.balanceOf(p.to);
            beforeAfter.dstTotalSupplyAfter = adapterToken.totalSupply();
            beforeAfter.adapterBalanceAfter = adapterToken.balanceOf(address(t.dstOft));
        } else {
            beforeAfter.fromDstBalanceAfter = t.dstOft.balanceOf(p.from);
            beforeAfter.toDstBalanceAfter = t.dstOft.balanceOf(p.to);
            beforeAfter.dstTotalSupplyAfter = t.dstOft.totalSupply();
        }
        beforeAfter.maxReceivedNonceAfter = t.dstOft.getMaxReceivedNonce(
            p.srcOft.endpoint().eid(),
            addressToBytes32(address(p.srcOft))
        );

        if (t.dstOft.orderedNonce()) {
            assertEq(
                beforeAfter.maxReceivedNonceAfter,
                beforeAfter.maxReceivedNonceBefore + 1,
                "OT-11: Max Received Nonce Should Increase By 1 on lzReceive"
            );
        }

        assertEq(
            beforeAfter.toDstBalanceAfter,
            beforeAfter.toDstBalanceBefore + amountReceivedLD,
            "OT-12: Destination Token Balance Should Increase on lzReceive"
        );

        if (t.dstOft == oftInstances[0]) {
            assertEq(
                beforeAfter.adapterBalanceAfter,
                beforeAfter.adapterBalanceBefore - amountSentLD,
                "OT-13: Adapter Balance Should Decrease on lzReceive"
            );
            assertEq(
                beforeAfter.dstTotalSupplyAfter,
                beforeAfter.dstTotalSupplyBefore,
                "OT-14: Native Token Total Supply Should Not Change on lzReceive"
            );
        } else {
            assertEq(
                beforeAfter.dstTotalSupplyAfter,
                beforeAfter.dstTotalSupplyBefore + amountReceivedLD,
                "OT-15: Destination Total Supply Should Increase on lzReceive"
            );
        }
    }

    event MessageNum(string a, uint256 b);

    /*//////////////////////////////////////////////////////////////////////////
                            ONLY OWNER TARGET FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function setOrderedNonce(uint256 oftIndexSeed, bool _orderedNonce) public {
        OrderOFTMock oft = randomOft(oftIndexSeed);
        vm.prank(oft.owner());
        oft.setOrderedNonce(_orderedNonce);
    }

    function skipInboundNonce(uint256 dstOftIndexSeed, uint256 messageReceiptIndexSeed) public {
        // PRE-CONDITIONS
        OrderOFTMock dstOft = randomOft(dstOftIndexSeed);
        uint32 dstEid = dstOft.endpoint().eid();
        if (packetVariables[dstEid].length == 0) return;

        (MessagingReceipt memory receipt, PacketVariables memory packetVars, uint256 index) = randomMessagingReceipt(
            messageReceiptIndexSeed,
            dstEid
        );

        uint64 nonce = receipt.nonce;

        bytes32 sender = addressToBytes32(address(packetVars.srcOft));
        uint32 srcEid = packetVars.srcOft.endpoint().eid();

        if (nonce == 0) return;

        vm.prank(dstOft.owner());
        dstOft.skipInboundNonce(srcEid, sender, uint64(nonce));

        // Removing skipped message from our queue
        for (uint i = index; i < messageReceipts[dstEid].length - 1; i++) {
            messageReceipts[dstEid][i] = messageReceipts[dstEid][i + 1];
        }
        messageReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < oftReceipts[dstEid].length - 1; i++) {
            oftReceipts[dstEid][i] = oftReceipts[dstEid][i + 1];
        }
        oftReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < packetVariables[dstEid].length - 1; i++) {
            packetVariables[dstEid][i] = packetVariables[dstEid][i + 1];
        }
        packetVariables[dstEid].pop();
    }

    function clearInboundNonce(uint256 dstOftIndexSeed, uint256 messageReceiptIndexSeed) public {
        // PRE-CONDITIONS
        OrderOFTMock dstOft = randomOft(dstOftIndexSeed);
        uint32 dstEid = dstOft.endpoint().eid();
        if (packetVariables[dstEid].length == 0) return;

        (MessagingReceipt memory receipt, PacketVariables memory packetVars, uint256 index) = randomMessagingReceipt(
            messageReceiptIndexSeed,
            dstEid
        );

        uint64 nonce = receipt.nonce;
        bytes32 sender = addressToBytes32(address(packetVars.srcOft));
        uint32 srcEid = packetVars.srcOft.endpoint().eid();

        Origin memory origin;
        origin.srcEid = srcEid;
        origin.sender = sender;
        origin.nonce = nonce;

        if (nonce == 0) return;
        bytes32 payloadHash = verifyHelper.validatePacket(receipt.guid);

        vm.prank(dstOft.owner());
        dstOft.clearInboundNonce(origin, receipt.guid, packetVars.message);

        // Removing skipped message from our queue
        for (uint i = index; i < messageReceipts[dstEid].length - 1; i++) {
            messageReceipts[dstEid][i] = messageReceipts[dstEid][i + 1];
        }
        messageReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < oftReceipts[dstEid].length - 1; i++) {
            oftReceipts[dstEid][i] = oftReceipts[dstEid][i + 1];
        }
        oftReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < packetVariables[dstEid].length - 1; i++) {
            packetVariables[dstEid][i] = packetVariables[dstEid][i + 1];
        }
        packetVariables[dstEid].pop();
    }

    function nilifyInboundNonce(uint256 dstOftIndexSeed, uint256 messageReceiptIndexSeed) public {
        // PRE-CONDITIONS
        OrderOFTMock dstOft = randomOft(dstOftIndexSeed);
        uint32 dstEid = dstOft.endpoint().eid();
        if (packetVariables[dstEid].length == 0) return;

        (MessagingReceipt memory receipt, PacketVariables memory packetVars, uint256 index) = randomMessagingReceipt(
            messageReceiptIndexSeed,
            dstEid
        );

        uint64 nonce = receipt.nonce;
        bytes32 sender = addressToBytes32(address(packetVars.srcOft));
        uint32 srcEid = packetVars.srcOft.endpoint().eid();

        Origin memory origin;
        origin.srcEid = srcEid;
        origin.sender = sender;
        origin.nonce = nonce;

        if (nonce == 0) return;

        vm.prank(dstOft.owner());
        dstOft.nilifyInboundNonce(srcEid, sender, nonce, bytes32(0));

        // Removing skipped message from our queue
        for (uint i = index; i < messageReceipts[dstEid].length - 1; i++) {
            messageReceipts[dstEid][i] = messageReceipts[dstEid][i + 1];
        }
        messageReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < oftReceipts[dstEid].length - 1; i++) {
            oftReceipts[dstEid][i] = oftReceipts[dstEid][i + 1];
        }
        oftReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < packetVariables[dstEid].length - 1; i++) {
            packetVariables[dstEid][i] = packetVariables[dstEid][i + 1];
        }
        packetVariables[dstEid].pop();
    }

    function burnInboundNonce(uint256 dstOftIndexSeed, uint256 messageReceiptIndexSeed) public {
        // PRE-CONDITIONS
        OrderOFTMock dstOft = randomOft(dstOftIndexSeed);
        uint32 dstEid = dstOft.endpoint().eid();
        if (packetVariables[dstEid].length == 0) return;

        (MessagingReceipt memory receipt, PacketVariables memory packetVars, uint256 index) = randomMessagingReceipt(
            messageReceiptIndexSeed,
            dstEid
        );

        uint64 nonce = receipt.nonce;
        bytes32 sender = addressToBytes32(address(packetVars.srcOft));
        uint32 srcEid = packetVars.srcOft.endpoint().eid();

        Origin memory origin;
        origin.srcEid = srcEid;
        origin.sender = sender;
        origin.nonce = nonce;

        if (nonce <= 2) return;
        bytes32 payloadHash = verifyHelper.validatePacket(receipt.guid);

        vm.prank(dstOft.owner());
        dstOft.burnInboundNonce(srcEid, sender, nonce, payloadHash);

        // Removing skipped message from our queue
        for (uint i = index; i < messageReceipts[dstEid].length - 1; i++) {
            messageReceipts[dstEid][i] = messageReceipts[dstEid][i + 1];
        }
        messageReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < oftReceipts[dstEid].length - 1; i++) {
            oftReceipts[dstEid][i] = oftReceipts[dstEid][i + 1];
        }
        oftReceipts[dstEid].pop();
        // Removing skipped message from our queue
        for (uint i = index; i < packetVariables[dstEid].length - 1; i++) {
            packetVariables[dstEid][i] = packetVariables[dstEid][i + 1];
        }
        packetVariables[dstEid].pop();
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

    function randomMessagingReceipt(
        uint256 seed,
        uint32 eid
    ) internal view returns (MessagingReceipt memory, PacketVariables memory, uint256) {
        uint256 index = _bound(seed, 0, messageReceipts[eid].length - 1);
        MessagingReceipt memory receipt = messageReceipts[eid][index];
        PacketVariables memory packetVars = packetVariables[eid][index];
        return (receipt, packetVars, index);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
