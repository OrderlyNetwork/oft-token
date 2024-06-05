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

    mapping(uint32 => MessagingReceipt[]) messageReceipts;
    mapping(uint32 => OFTReceipt[]) oftReceipts;
    mapping(uint32 => PacketVariables[]) packetVariables;

    struct PacketVariables {
        address from;
        address to;
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
        uint64 nonceBefore;
        uint64 nonceAfter;
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
        if (address(t.srcOft) == address(t.dstOft)) return;
        t.from = randomAddress(fromIndexSeed);
        t.to = randomAddress(toIndexSeed);

        PacketVariables memory packetVars;
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
            (MessagingReceipt memory decodedMessagingReceipt, OFTReceipt memory decodedOFTReceipt) = abi.decode(
                returnData,
                (MessagingReceipt, OFTReceipt)
            );
            messageReceipts[t.dstOft.endpoint().eid()].push(decodedMessagingReceipt);
            oftReceipts[t.dstOft.endpoint().eid()].push(decodedOFTReceipt);
            packetVariables[t.dstOft.endpoint().eid()].push(packetVars);

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

            assertEq(
                beforeAfter.fromSrcBalanceAfter,
                beforeAfter.fromSrcBalanceBefore - decodedOFTReceipt.amountSentLD,
                "Source Token Balance Should Decrease"
            );
            if (t.srcOft == oftInstances[0]) {
                assertEq(
                    beforeAfter.adapterBalanceAfter,
                    beforeAfter.adapterBalanceBefore + decodedOFTReceipt.amountSentLD,
                    "Adapter Balance Should Increase"
                );
                assertEq(
                    beforeAfter.srcTotalSupplyAfter,
                    beforeAfter.srcTotalSupplyBefore,
                    "Native Token Total Supply Should Not Change"
                );
            } else {
                assertEq(
                    beforeAfter.srcTotalSupplyAfter,
                    beforeAfter.srcTotalSupplyBefore - decodedOFTReceipt.amountSentLD,
                    "Source Total Supply Should Decrease"
                );
            }
        }
    }

    struct VerifyPacketTemps {
        OrderOFTMock dstOft;
    }

    function verifyPackets(uint256 dstOftIndexSeed) public {
        VerifyPacketTemps memory t;
        PacketVariables memory p;
        // PRE-CONDITIONS
        t.dstOft = randomOft(dstOftIndexSeed);
        if (packetVariables[t.dstOft.endpoint().eid()].length == 0) return;
        p = packetVariables[t.dstOft.endpoint().eid()][packetVariables[t.dstOft.endpoint().eid()].length - 1];

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

        // ACTION

        verifyHelper.verifyPackets(t.dstOft.endpoint().eid(), addressToBytes32(address(t.dstOft)), 1);

        uint256 amountSentLD = oftReceipts[t.dstOft.endpoint().eid()][oftReceipts[t.dstOft.endpoint().eid()].length - 1]
            .amountSentLD;
        uint256 amountReceivedLD = oftReceipts[t.dstOft.endpoint().eid()][
            oftReceipts[t.dstOft.endpoint().eid()].length - 1
        ].amountReceivedLD;

        messageReceipts[t.dstOft.endpoint().eid()].pop();
        oftReceipts[t.dstOft.endpoint().eid()].pop();
        packetVariables[t.dstOft.endpoint().eid()].pop();

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

        assertEq(
            beforeAfter.toDstBalanceAfter,
            beforeAfter.toDstBalanceBefore + amountReceivedLD,
            "Destination Token Balance Should Increase"
        );

        if (t.dstOft == oftInstances[0]) {
            assertEq(
                beforeAfter.adapterBalanceAfter,
                beforeAfter.adapterBalanceBefore - amountSentLD,
                "Adapter Balance Should Decrease"
            );
            assertEq(
                beforeAfter.dstTotalSupplyAfter,
                beforeAfter.dstTotalSupplyBefore,
                "Native Token Total Supply Should Not Change"
            );
        } else {
            assertEq(
                beforeAfter.dstTotalSupplyAfter,
                beforeAfter.dstTotalSupplyBefore + amountReceivedLD,
                "Destination Total Supply Should Increase"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            ONLY OWNER TARGET FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function setOrderedNonce(uint256 oftIndexSeed, bool _orderedNonce) public {
        OrderOFTMock oft = randomOft(oftIndexSeed);
        vm.prank(oft.owner());
        oft.setOrderedNonce(_orderedNonce);
    }

    function skipInboundNonce(uint256 srcOftIndexSeed, uint256 senderIndexSeed, uint256 nonce) public {
        OrderOFTMock srcOft = randomOft(srcOftIndexSeed);
        bytes32 sender = addressToBytes32(randomAddress(senderIndexSeed));
        uint32 eid = srcOft.endpoint().eid();

        nonce = _bound(nonce, 0, srcOft.getMaxReceivedNonce(eid, sender));
        if (nonce == 0) return;

        vm.prank(srcOft.owner());
        srcOft.skipInboundNonce(eid, sender, uint64(nonce));
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

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
