// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Order imports
import { OrderToken } from "../../contracts/OrderToken.sol";
import { OrderAdapter } from "../../contracts/OrderAdapter.sol";
import { OrderOFT } from "../../contracts/OrderOFT.sol";
import { OrderBox } from "../../contracts/crosschain/OrderBox.sol";
import { OrderBoxRelayer } from "../../contracts/crosschain/OrderBoxRelayer.sol";
import { OrderSafe } from "../../contracts/crosschain/OrderSafe.sol";
import { OrderSafeRelayer } from "../../contracts/crosschain/OrderSafeRelayer.sol";

// Mock imports
import { OFTMock } from "../mocks/OFTMock.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { OFTComposerMock } from "../mocks/OFTComposerMock.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import { OptionsBuilder } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { ExecutorOptions } from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";

// OFT imports
import { IOFT, SendParam, OFTReceipt, MessagingReceipt } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingFee } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";
import { OFTMsgCodec } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import { EndpointV2Mock as EndpointV2 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/Vm.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract OrderOFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    enum OptionTypes {
        SEND,
        SEND_AND_CALL
    }

    uint256 public constant INIT_MINT = 1_000_000_000 ether;
    uint128 public constant RECEIVE_GAS = 200000;
    uint128 public constant COMPOSE_GAS = 500000;
    uint128 public constant VALUE = 0;

    EnforcedOptionParam[] public enforcedOptions;
    EnforcedOptionParam[] public receiveOptions;

    OrderToken token;

    uint8 public constant MSG_COUNT = 21;
    uint8 public constant MAX_OFTS = 10;
    // eid = 1: endpoint id on l1 side: ethereum, the first one always the ethereum chain
    // eid = 2: endpoint id on vault side: arb
    // eid = 3: endpoint id on vault side: op
    // eid = 4: endpoint id on ledge side: orderly, the last one always the orderly chain
    uint32[] public eids;
    address[] public ofts;
    OrderOFT[] public oftInstances;

    OrderBox public orderBox;
    OrderBoxRelayer public orderBoxRelayer;
    OrderSafe[] public orderSafeInstances;
    OrderSafeRelayer[] public orderSafeRelayerInstances;

    uint256[] public chainIds;

    function setUp() public override {
        vm.deal(address(this), 1000000 ether);

        // Set the OFT contracts
        _setOft();

        // Initiate token transfer from the ERC20 contract to other OFT contracts
        _setDistribution();
    }

    function test_pause_send() public {
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            uint256 tokenToSend = IERC20(oftInstances[i].token()).balanceOf(address(this)) / MAX_OFTS;
            if (!oftInstances[i].paused()) oftInstances[i].pause();
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                _checkApproval(i);
                SendParam memory sendParam = SendParam(
                    eids[j],
                    addressToBytes32(address(this)),
                    tokenToSend,
                    tokenToSend,
                    "",
                    "",
                    ""
                );
                MessagingFee memory fee = oftInstances[i].quoteSend(sendParam, false);
                vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
                oftInstances[i].send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
            }
        }
    }

    function test_pause_receive() public {
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            uint256 tokenToSend = IERC20(oftInstances[i].token()).balanceOf(address(this)) / MAX_OFTS;
            if (oftInstances[i].paused()) oftInstances[i].unpause();

            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                if (!oftInstances[j].paused()) oftInstances[j].pause();
                _checkApproval(i);
                _send(i, j, tokenToSend);
                oftInstances[j].setOrderedNonce(eids[i], false);
                vm.prank(endpoints[eids[j]]);
                vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
                oftInstances[j].lzReceive(
                    Origin(eids[i], addressToBytes32(ofts[i]), 1),
                    bytes32(uint256(1)),
                    "",
                    msg.sender,
                    ""
                );
            }
        }
    }

    function test_pause_transfer() public {
        address receiver = address(1);
        address spender = address(2);
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            if (i == 0) continue;
            uint256 tokenToSend = IERC20(ofts[i]).balanceOf(address(this)) / MAX_OFTS;
            if (!oftInstances[i].paused()) {
                IERC20(ofts[i]).approve(spender, tokenToSend);
                oftInstances[i].pause();
            }

            vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
            IERC20(ofts[i]).transfer(receiver, tokenToSend);
            vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
            IERC20(ofts[i]).approve(spender, tokenToSend);

            vm.prank(spender);
            vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
            IERC20(ofts[i]).transferFrom(address(this), spender, tokenToSend);
        }
    }

    function test_zero_receiver() public {
        address zero_receiver = address(0);
        uint256 tokenToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(RECEIVE_GAS, VALUE);
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                _checkApproval(i);
                SendParam memory sendParam = SendParam(
                    eids[j],
                    addressToBytes32(address(zero_receiver)),
                    tokenToSend,
                    tokenToSend,
                    options,
                    "",
                    ""
                );
                MessagingFee memory fee = oftInstances[i].quoteSend(sendParam, false);
                vm.expectRevert("OFT: Transfer to ZeroAddress");
                oftInstances[i].send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
            }
        }
    }

    function test_dust_send() public {
        uint256 dust = 1;
        uint256 oldBalance;
        uint256 newBalance;
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;

                _checkApproval(i);
                _send(i, j, dust);
                oldBalance = IERC20(oftInstances[j].token()).balanceOf(address(this));
                verifyPackets(eids[j], addressToBytes32(ofts[j]));
                newBalance = IERC20(oftInstances[j].token()).balanceOf(address(this));
                assertEq(newBalance, oldBalance + dust);
            }
        }
    }

    function test_unorder_nonce() public {
        uint256 tokenToSend = 1 ether;
        EndpointV2 localEndpoint;
        uint64 localOutboundNonce;
        EndpointV2 remoteEndpoint;
        uint64 remoteInboundNonce;
        MessagingReceipt memory msgReceipt;
        bytes32[] memory guids = new bytes32[](MSG_COUNT);
        uint64[] memory nonces = new uint64[](MSG_COUNT);
        uint256 oldBalance;

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            localEndpoint = EndpointV2(endpoints[eids[i]]);
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                remoteEndpoint = EndpointV2(endpoints[eids[j]]);

                // send packets: 0 - (MSG_COUNT - 1)
                for (uint8 seq = 0; seq < MSG_COUNT; seq++) {
                    localOutboundNonce = localEndpoint.outboundNonce(ofts[i], eids[j], addressToBytes32(ofts[j]));
                    _checkApproval(i);
                    (msgReceipt, ) = _send(i, j, tokenToSend * (localOutboundNonce + 1));
                    assertEq(msgReceipt.nonce, localOutboundNonce + 1);
                    guids[seq] = msgReceipt.guid;
                    nonces[seq] = msgReceipt.nonce;
                }

                // commit packets: 0 - (MSG_COUNT / 2 - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT / 2);

                // execute packets: 0 - (MSG_COUNT / 2 - 1)
                for (uint8 seq = 0; seq < MSG_COUNT / 2; seq++) {
                    oldBalance = IERC20(oftInstances[j].token()).balanceOf(address(this));
                    executePacket(address(0), guids[seq]);
                    remoteInboundNonce = remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i]));
                    assertEq(remoteInboundNonce, nonces[seq]);
                    assertEq(
                        IERC20(oftInstances[j].token()).balanceOf(address(this)),
                        oldBalance + tokenToSend * nonces[seq]
                    );
                }

                // commit packets: (MSG_COUNT / 2) - (MSG_COUNT - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT - MSG_COUNT / 2);
                remoteInboundNonce = remoteEndpoint.inboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i]));

                // try to execute packets with unordered nonce: (MSG_COUNT - 1) - (MSG_COUNT / 2 + 1)
                for (uint8 seq = MSG_COUNT - 1; seq > MSG_COUNT / 2; seq--) {
                    executePacketRevert(address(0), guids[seq], bytes("OApp: invalid nonce"));
                }

                // set unordered nonce to enable unordered delivery
                oftInstances[j].setOrderedNonce(eids[i], false);
                // execute packets: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
                for (uint8 seq = MSG_COUNT - 1; seq >= MSG_COUNT / 2; seq--) {
                    oldBalance = IERC20(oftInstances[j].token()).balanceOf(address(this));
                    executePacket(address(0), guids[seq]);
                    assertEq(remoteInboundNonce, nonces[MSG_COUNT - 1]);
                    assertEq(
                        IERC20(oftInstances[j].token()).balanceOf(address(this)),
                        oldBalance + tokenToSend * nonces[seq]
                    );
                }
                // reset ordered nonce
                oftInstances[j].setOrderedNonce(eids[i], true);
            }
        }
    }

    // function test_clear_nonce() public {
    //     uint256 tokenToSend = 1 ether;
    //     EndpointV2 localEndpoint;
    //     uint64 localOutboundNonce;
    //     EndpointV2 remoteEndpoint;
    //     MessagingReceipt memory msgReceipt;
    //     bytes32[] memory guids = new bytes32[](MSG_COUNT);
    //     uint64[] memory nonces = new uint64[](MSG_COUNT);
    //     bytes memory message;

    //     for (uint8 i = 0; i < MAX_OFTS; i++) {
    //         localEndpoint = EndpointV2(endpoints[eids[i]]);
    //         for (uint8 j = 0; j < MAX_OFTS; j++) {
    //             if (i == j) continue;
    //             remoteEndpoint = EndpointV2(endpoints[eids[j]]);
    //             // send packets: 0 - (MSG_COUNT - 1)
    //             for (uint8 seq = 0; seq < MSG_COUNT; seq++) {
    //                 localOutboundNonce = localEndpoint.outboundNonce(ofts[i], eids[j], addressToBytes32(ofts[j]));
    //                 _checkApproval(i);
    //                 (msgReceipt, ) = _send(i, j, tokenToSend * (localOutboundNonce + 1));
    //                 assertEq(msgReceipt.nonce, localOutboundNonce + 1);
    //                 guids[seq] = msgReceipt.guid;
    //                 nonces[seq] = msgReceipt.nonce;
    //             }

    //             // commit packets: 0 - (MSG_COUNT - 1)
    //             commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT);
    //             assertEq(
    //                 remoteEndpoint.inboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
    //                 nonces[MSG_COUNT - 1]
    //             );

    //             oftInstances[j].setOrderedNonce(false);

    //             (message, ) = OFTMsgCodec.encode(addressToBytes32(ofts[j]), uint64(tokenToSend), "0x");

    //             oftInstances[j].clearInboundNonce(
    //                 Origin(eids[i], addressToBytes32(ofts[i]), nonces[MSG_COUNT / 2]),
    //                 guids[MSG_COUNT / 2],
    //                 message
    //             );

    //             // // skip packet: MSG_COUNT / 2
    //             // oftInstances[j].skipInboundNonce(eids[i], addressToBytes32(ofts[i]), nonces[MSG_COUNT / 2]);
    //             // assertEq(
    //             //     remoteEndpoint.inboundPayloadHash(
    //             //         ofts[j],
    //             //         eids[i],
    //             //         addressToBytes32(ofts[i]),
    //             //         nonces[MSG_COUNT / 2]
    //             //     ),
    //             //     remoteEndpoint.EMPTY_PAYLOAD_HASH()
    //             // );
    //             // // try to commit packet: MSG_COUNT / 2
    //             // commitPackets(eids[j], addressToBytes32(ofts[j]), 1);
    //             // assertEq(
    //             //     remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
    //             //     nonces[MSG_COUNT / 2]
    //             // );
    //             // // execute packets: 0 - (MSG_COUNT / 2 - 1)
    //             // for (uint8 seq = 0; seq < MSG_COUNT / 2; seq++) {
    //             //     executePacket(address(0), guids[seq]);
    //             //     assertGt(remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])), nonces[seq]);
    //             // }
    //             // // commit packets: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
    //             // commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT - MSG_COUNT / 2 - 1);
    //             // // try to execute packet: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
    //             // for (uint8 seq = MSG_COUNT / 2 + 1; seq < MSG_COUNT; seq++) {
    //             //     executePacketRevert(address(0), guids[seq], bytes("OApp: invalid nonce"));
    //             // }

    //             // // update the max received nonce to the skipped nonce
    //             // oftInstances[j].pullMaxReceivedNonce(eids[i], addressToBytes32(ofts[i]));
    //             // assertEq(oftInstances[j].maxReceivedNonce(eids[i], addressToBytes32(ofts[i])), nonces[MSG_COUNT / 2]);
    //             // // execute packets: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
    //             // for (uint8 seq = MSG_COUNT / 2 + 1; seq < MSG_COUNT; seq++) {
    //             //     executePacket(address(0), guids[seq]);
    //             //     assertEq(remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])), nonces[seq]);
    //             //     assertEq(oftInstances[j].maxReceivedNonce(eids[i], addressToBytes32(ofts[i])), nonces[seq]);
    //             // }

    //             oftInstances[j].setOrderedNonce(true);
    //         }
    //     }
    // }

    function test_skip_nonce() public {
        uint256 tokenToSend = 1 ether;
        EndpointV2 localEndpoint;
        uint64 localOutboundNonce;
        EndpointV2 remoteEndpoint;
        MessagingReceipt memory msgReceipt;
        bytes32[] memory guids = new bytes32[](MSG_COUNT);
        uint64[] memory nonces = new uint64[](MSG_COUNT);

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            localEndpoint = EndpointV2(endpoints[eids[i]]);
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                remoteEndpoint = EndpointV2(endpoints[eids[j]]);
                // send packets: 0 - (MSG_COUNT - 1)
                for (uint8 seq = 0; seq < MSG_COUNT; seq++) {
                    localOutboundNonce = localEndpoint.outboundNonce(ofts[i], eids[j], addressToBytes32(ofts[j]));
                    _checkApproval(i);
                    (msgReceipt, ) = _send(i, j, tokenToSend * (localOutboundNonce + 1));
                    assertEq(msgReceipt.nonce, localOutboundNonce + 1);
                    guids[seq] = msgReceipt.guid;
                    nonces[seq] = msgReceipt.nonce;
                }

                // commit packets: 0 - (MSG_COUNT / 2 - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT / 2);
                assertEq(
                    remoteEndpoint.inboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                    nonces[MSG_COUNT / 2 - 1]
                );
                // skip packet: MSG_COUNT / 2
                oftInstances[j].skipInboundNonce(eids[i], addressToBytes32(ofts[i]), nonces[MSG_COUNT / 2]);
                assertEq(
                    remoteEndpoint.inboundPayloadHash(
                        ofts[j],
                        eids[i],
                        addressToBytes32(ofts[i]),
                        nonces[MSG_COUNT / 2]
                    ),
                    remoteEndpoint.EMPTY_PAYLOAD_HASH()
                );
                // try to commit packet: MSG_COUNT / 2
                commitPackets(eids[j], addressToBytes32(ofts[j]), 1);
                assertEq(
                    remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                    nonces[MSG_COUNT / 2]
                );
                // execute packets: 0 - (MSG_COUNT / 2 - 1)
                for (uint8 seq = 0; seq < MSG_COUNT / 2; seq++) {
                    executePacket(address(0), guids[seq]);
                    assertGt(remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])), nonces[seq]);
                }
                // commit packets: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT - MSG_COUNT / 2 - 1);
                // try to execute packet: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
                for (uint8 seq = MSG_COUNT / 2 + 1; seq < MSG_COUNT; seq++) {
                    executePacketRevert(address(0), guids[seq], bytes("OApp: invalid nonce"));
                }

                // update the max received nonce to the skipped nonce
                oftInstances[j].pullMaxReceivedNonce(eids[i], addressToBytes32(ofts[i]));
                assertEq(oftInstances[j].maxReceivedNonce(eids[i], addressToBytes32(ofts[i])), nonces[MSG_COUNT / 2]);
                // execute packets: (MSG_COUNT / 2 + 1) - (MSG_COUNT - 1)
                for (uint8 seq = MSG_COUNT / 2 + 1; seq < MSG_COUNT; seq++) {
                    executePacket(address(0), guids[seq]);
                    assertEq(remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])), nonces[seq]);
                    assertEq(oftInstances[j].maxReceivedNonce(eids[i], addressToBytes32(ofts[i])), nonces[seq]);
                }
            }
        }
    }

    function test_nilify_nonce() public {
        uint256 tokenToSend = 1 ether;
        EndpointV2 localEndpoint;
        uint64 localOutboundNonce;
        EndpointV2 remoteEndpoint;
        MessagingReceipt memory msgReceipt;
        bytes32[] memory guids = new bytes32[](MSG_COUNT);
        uint64[] memory nonces = new uint64[](MSG_COUNT);

        bytes32 payloadHash;

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            localEndpoint = EndpointV2(endpoints[eids[i]]);
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                remoteEndpoint = EndpointV2(endpoints[eids[j]]);
                // send packets: 0 - (MSG_COUNT - 1)
                for (uint8 seq = 0; seq < MSG_COUNT; seq++) {
                    localOutboundNonce = localEndpoint.outboundNonce(ofts[i], eids[j], addressToBytes32(ofts[j]));
                    _checkApproval(i);
                    (msgReceipt, ) = _send(i, j, tokenToSend * (localOutboundNonce + 1));
                    assertEq(msgReceipt.nonce, localOutboundNonce + 1);
                    guids[seq] = msgReceipt.guid;
                    nonces[seq] = msgReceipt.nonce;
                }

                // commit packets: 0 - (MSG_COUNT / 2 - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT / 2);

                oftInstances[j].setOrderedNonce(eids[i], false);
                // execute packet: MSG_COUNT / 2 - 1
                executePacket(address(0), guids[MSG_COUNT / 2 - 1]);
                assertEq(
                    remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                    nonces[MSG_COUNT / 2 - 1]
                );

                payloadHash = remoteEndpoint.inboundPayloadHash(
                    ofts[j],
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT / 4]
                );
                // nilify packet: MSG_COUNT / 4
                oftInstances[j].nilifyInboundNonce(
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT / 4],
                    payloadHash
                );
                assertEq(
                    remoteEndpoint.inboundPayloadHash(
                        ofts[j],
                        eids[i],
                        addressToBytes32(ofts[i]),
                        nonces[MSG_COUNT / 4]
                    ),
                    remoteEndpoint.NIL_PAYLOAD_HASH()
                );

                // try to execute packet: 0 - (MSG_COUNT/2 - 2)
                for (uint8 seq = 0; seq < MSG_COUNT / 2 - 1; seq++) {
                    if (seq == MSG_COUNT / 4) {
                        executePacketRevert(
                            address(0),
                            guids[seq],
                            abi.encodeWithSignature(
                                "LZ_PayloadHashNotFound(bytes32,bytes32)",
                                remoteEndpoint.NIL_PAYLOAD_HASH(),
                                payloadHash
                            )
                        );
                    } else {
                        executePacket(address(0), guids[seq]);
                    }
                }

                // recommit packet: MSG_COUNT / 2
                // have to be fake receiver to avoid the HashAlreadyUsed event on DVNMock
                // recommitPacket(guids[MSG_COUNT / 2]);
                (address expectedReceiveLib, ) = remoteEndpoint.getReceiveLibrary(ofts[j], eids[i]);
                vm.prank(expectedReceiveLib);
                remoteEndpoint.verify(
                    Origin(eids[i], addressToBytes32(ofts[i]), nonces[MSG_COUNT / 4]),
                    ofts[j],
                    payloadHash
                );
                executePacket(address(0), guids[MSG_COUNT / 4]);
                assertEq(
                    remoteEndpoint.inboundPayloadHash(
                        ofts[j],
                        eids[i],
                        addressToBytes32(ofts[i]),
                        nonces[MSG_COUNT / 4]
                    ),
                    remoteEndpoint.EMPTY_PAYLOAD_HASH()
                );

                // execute packets: (MSG_COUNT / 2) - (MSG_COUNT - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT - MSG_COUNT / 2);
                payloadHash = remoteEndpoint.inboundPayloadHash(
                    ofts[j],
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT - MSG_COUNT / 4]
                );

                oftInstances[j].nilifyInboundNonce(
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT - MSG_COUNT / 4],
                    payloadHash
                );

                assertEq(
                    remoteEndpoint.inboundPayloadHash(
                        ofts[j],
                        eids[i],
                        addressToBytes32(ofts[i]),
                        nonces[MSG_COUNT - MSG_COUNT / 4]
                    ),
                    remoteEndpoint.NIL_PAYLOAD_HASH()
                );

                // try to execute packet: (MSG_COUNT / 2) - (MSG_COUNT - 1)
                for (uint8 seq = MSG_COUNT / 2; seq < MSG_COUNT; seq++) {
                    if (seq == MSG_COUNT - MSG_COUNT / 4) {
                        executePacketRevert(
                            address(0),
                            guids[seq],
                            abi.encodeWithSignature(
                                "LZ_PayloadHashNotFound(bytes32,bytes32)",
                                remoteEndpoint.NIL_PAYLOAD_HASH(),
                                payloadHash
                            )
                        );
                    } else {
                        executePacket(address(0), guids[seq]);
                        assertEq(
                            remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                            nonces[seq]
                        );
                    }
                }

                vm.prank(expectedReceiveLib);
                remoteEndpoint.verify(
                    Origin(eids[i], addressToBytes32(ofts[i]), nonces[MSG_COUNT - MSG_COUNT / 4]),
                    ofts[j],
                    payloadHash
                );

                executePacket(address(0), guids[MSG_COUNT - MSG_COUNT / 4]);
                assertEq(
                    remoteEndpoint.inboundPayloadHash(
                        ofts[j],
                        eids[i],
                        addressToBytes32(ofts[i]),
                        nonces[MSG_COUNT - MSG_COUNT / 4]
                    ),
                    remoteEndpoint.EMPTY_PAYLOAD_HASH()
                );

                oftInstances[j].setOrderedNonce(eids[i], true);
            }
        }
    }

    function test_burn_nonce() public {
        uint256 tokenToSend = 1 ether;
        EndpointV2 localEndpoint;
        uint64 localOutboundNonce;
        EndpointV2 remoteEndpoint;
        MessagingReceipt memory msgReceipt;
        bytes32[] memory guids = new bytes32[](MSG_COUNT);
        uint64[] memory nonces = new uint64[](MSG_COUNT);

        bytes32 payloadHash;

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            localEndpoint = EndpointV2(endpoints[eids[i]]);
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                remoteEndpoint = EndpointV2(endpoints[eids[j]]);

                for (uint8 seq = 0; seq < MSG_COUNT; seq++) {
                    localOutboundNonce = localEndpoint.outboundNonce(ofts[i], eids[j], addressToBytes32(ofts[j]));
                    _checkApproval(i);
                    (msgReceipt, ) = _send(i, j, tokenToSend * (localOutboundNonce + 1));
                    assertEq(msgReceipt.nonce, localOutboundNonce + 1);
                    guids[seq] = msgReceipt.guid;
                    nonces[seq] = msgReceipt.nonce;
                }

                // commit packets: 0 - (MSG_COUNT - 1)
                commitPackets(eids[j], addressToBytes32(ofts[j]), MSG_COUNT);
                assertEq(
                    remoteEndpoint.inboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                    nonces[MSG_COUNT - 1]
                );

                // no packet executed
                assertEq(remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])), nonces[0] - 1);

                payloadHash = remoteEndpoint.inboundPayloadHash(
                    ofts[j],
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT / 2]
                );

                // try to burn a nonce later then the current lazyInboundNonce
                vm.expectRevert(abi.encodeWithSignature("LZ_InvalidNonce(uint64)", nonces[MSG_COUNT / 2]));
                oftInstances[j].burnInboundNonce(
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT / 2],
                    payloadHash
                );

                // execute packet: (MSG_COUNT - 1)
                oftInstances[j].setOrderedNonce(eids[i], false);
                executePacket(address(0), guids[MSG_COUNT - 1]);
                assertEq(
                    remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                    nonces[MSG_COUNT - 1]
                );

                // burn packet: MSG_COUNT / 2
                oftInstances[j].burnInboundNonce(
                    eids[i],
                    addressToBytes32(ofts[i]),
                    nonces[MSG_COUNT / 2],
                    payloadHash
                );
                assertEq(
                    remoteEndpoint.inboundPayloadHash(
                        ofts[j],
                        eids[i],
                        addressToBytes32(ofts[i]),
                        nonces[MSG_COUNT / 2]
                    ),
                    remoteEndpoint.EMPTY_PAYLOAD_HASH()
                );

                // execute packets: 0 - (MSG_COUNT -2)
                for (uint8 seq = 0; seq < MSG_COUNT - 1; seq++) {
                    if (seq != MSG_COUNT / 2) {
                        executePacket(address(0), guids[seq]);
                        assertGe(
                            remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                            nonces[seq]
                        );
                        assertEq(
                            remoteEndpoint.lazyInboundNonce(ofts[j], eids[i], addressToBytes32(ofts[i])),
                            nonces[MSG_COUNT - 1]
                        );
                    } else {
                        executePacketRevert(
                            address(0),
                            guids[seq],
                            abi.encodeWithSignature(
                                "LZ_PayloadHashNotFound(bytes32,bytes32)",
                                remoteEndpoint.EMPTY_PAYLOAD_HASH(),
                                payloadHash
                            )
                        );
                    }
                }

                oftInstances[j].setOrderedNonce(eids[i], true);
            }
        }
    }

    function test_stake_msg() public {
        // Set the contracts to test cross-chain flow
        _setCC();

        uint256 tokenToStake = 1000 ether;
        uint256 stakeFee;
        MessagingReceipt memory msgReceipt;
        OFTReceipt memory oftReceipt;
        bytes memory options;
        bytes memory stakeMsg;
        for (uint8 i = 0; i < MAX_OFTS - 1; i++) {
            IERC20(oftInstances[i].token()).approve(address(orderSafeInstances[i]), tokenToStake);
            stakeFee = orderSafeInstances[i].getStakeFee(address(this), tokenToStake);
            vm.recordLogs();
            (msgReceipt, oftReceipt) = orderSafeInstances[i].stakeOrder{ value: stakeFee }(address(this), tokenToStake); // (msgReceipt, oftReceipt) =
            Vm.Log[] memory logs = vm.getRecordedLogs();
            for (uint8 j = 0; j < logs.length; j++) {
                if (logs[j].topics[0] == keccak256("PacketSent(bytes,bytes,address)")) {
                    (, options, ) = abi.decode(logs[j].data, (bytes, bytes, address));
                    continue;
                }
                if (logs[j].topics[0] == keccak256("SendStakeMsg(uint32,bytes32,bytes)")) {
                    (, , bytes memory composeMsg) = abi.decode(logs[j].data, (uint32, bytes32, bytes));
                    stakeMsg = OFTComposeMsgCodec.encode(
                        msgReceipt.nonce,
                        eids[i],
                        oftReceipt.amountReceivedLD,
                        abi.encodePacked(addressToBytes32(address(orderSafeRelayerInstances[i])), composeMsg)
                    );
                    continue;
                }
            }
            verifyPackets(eids[MAX_OFTS - 1], addressToBytes32(ofts[MAX_OFTS - 1]));
            this.lzCompose(
                eids[MAX_OFTS - 1],
                ofts[MAX_OFTS - 1],
                options,
                msgReceipt.guid,
                address(orderBoxRelayer),
                stakeMsg
            );
        }
        assertEq(
            IERC20(oftInstances[MAX_OFTS - 1].token()).balanceOf(address(orderBox)),
            tokenToStake * (MAX_OFTS - 1)
        );
    }
    // TODO import the rest of oft tests?
    // composeMsg
    // ABA pattern
    // ABA composeMsg pattern
    // nonce control

    /**
     * @dev Set up the OFT contracts and its endpoints
     */
    function _setOft() internal {
        super.setUp();
        setUpEndpoints(MAX_OFTS, LibraryType.UltraLightNode);
        // // console.log("Set up %d endpoints", MAX_OFTS);

        token = new OrderToken(address(this));
        OrderAdapter orderAdapterImpl = new OrderAdapter();
        OrderOFT orderOFTImpl = new OrderOFT();

        eids = new uint32[](MAX_OFTS);

        ofts = new address[](MAX_OFTS);
        oftInstances = new OrderOFT[](MAX_OFTS);
        bytes memory oftInitDate;

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            eids[i] = i + 1;
            oftInitDate = i == 0
                ? abi.encodeWithSignature(
                    "initialize(address,address,address)",
                    address(token),
                    address(endpoints[eids[i]]),
                    address(this)
                )
                : abi.encodeWithSignature("initialize(address,address)", address(endpoints[eids[i]]), address(this));

            ERC1967Proxy oftProxy = new ERC1967Proxy(
                i == 0 ? address(orderAdapterImpl) : address(orderOFTImpl),
                oftInitDate
            );
            ofts[i] = address(oftProxy);
            oftInstances[i] = OrderOFT(address(oftProxy));
        }

        // // console.log("Set up %d OFTs", MAX_OFTS);

        this.wireOApps(ofts);

        // console.log("Wired %d OFTs", MAX_OFTS);

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint256 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                EnforcedOptionParam memory enforcedOptionSend = EnforcedOptionParam(
                    eids[j],
                    uint16(OptionTypes.SEND),
                    OptionsBuilder
                        .newOptions()
                        .addExecutorLzReceiveOption(RECEIVE_GAS, VALUE)
                        .addExecutorOrderedExecutionOption()
                );
                EnforcedOptionParam memory enforcedOptionSendAndCall = EnforcedOptionParam(
                    eids[j],
                    uint16(OptionTypes.SEND_AND_CALL),
                    OptionsBuilder
                        .newOptions()
                        .addExecutorLzReceiveOption(RECEIVE_GAS, VALUE)
                        .addExecutorLzComposeOption(0, COMPOSE_GAS, VALUE)
                        .addExecutorOrderedExecutionOption()
                );
                enforcedOptions.push(enforcedOptionSend);
                enforcedOptions.push(enforcedOptionSendAndCall);

                oftInstances[i].setOrderedNonce(eids[j], true);
            }
            oftInstances[i].setEnforcedOptions(enforcedOptions);
        }

        // console.log("Set enforced options for %d OFTs", MAX_OFTS);
    }

    /**
     * @dev Set up the cross-chain contracts to enable the cross-chain flow
     *                     +-----------+   +-----------+                 +-----------+   +-----------+
     *                     |           |   |           |    LayerZero    |           |   |           |
     *                     |   ERC20   |   |    OFT    |-----------------|    OFT    |   |   ERC20   |
     *                     |           |   |           |                 |           |   |           |
     *                     +-----------+   +-----------+                 +-----------+   +-----------+
     *                         |               |                             |               |
     *                         |               |                             |               |
     *                         |               |                             |               |
     *                         |               |                             |               |
     * +----------+        +---------------------------+                 +---------------------------+        +----------+
     * |          |        |                           |                 |                           |        |          |
     * |OrderSafe |------- |     OrderSafeRelayer      |                 |      OrderBoxRelayer      | -------| OrderBox |
     * |          |        |                           |                 |                           |        |          |
     * +----------+        +---------------------------+                 +---------------------------+        +----------+
     */
    function _setCC() internal {
        uint128 receiveGas = 200000;
        uint128 composeGas = 500000;
        uint128 value = 0;
        // chain id mock
        chainIds = new uint256[](MAX_OFTS);
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            chainIds[i] = block.chainid + eids[i];
        }

        // console.log("Set chainIds for %d OFTs", MAX_OFTS);

        bytes memory initData = abi.encodeWithSignature("initialize(address)", address(this));

        // deploy OrderBox and OrderBoxRelayer
        OrderBox orderBoxImpl = new OrderBox();
        OrderBoxRelayer orderBoxRelayerImpl = new OrderBoxRelayer();
        ERC1967Proxy orderBoxProxy = new ERC1967Proxy(address(orderBoxImpl), initData);
        ERC1967Proxy orderBoxRelayerProxy = new ERC1967Proxy(address(orderBoxRelayerImpl), initData);
        orderBox = OrderBox(address(orderBoxProxy));
        orderBoxRelayer = OrderBoxRelayer(payable(address(orderBoxRelayerProxy)));

        orderBoxRelayer.setEid(chainIds[MAX_OFTS - 1], eids[MAX_OFTS - 1]);
        orderBoxRelayer.setEndpoint(endpoints[MAX_OFTS]);
        orderBoxRelayer.setOft(ofts[MAX_OFTS - 1]);
        orderBoxRelayer.setLocalComposeMsgSender(ofts[MAX_OFTS - 1], true);
        orderBoxRelayer.setOptionsAirdrop(0, receiveGas, value); // lz receive
        orderBoxRelayer.setOptionsAirdrop(1, composeGas, value); // lz compose
        orderBoxRelayer.setOrderBox(address(orderBox));

        orderBox.setOft(ofts[MAX_OFTS - 1]);
        orderBox.setOrderRelayer(address(orderBoxRelayer));

        // console.log("Deployed and set OrderBox and OrderBoxRelayer on eid: %d", eids[MAX_OFTS - 1]);

        orderSafeInstances = new OrderSafe[](MAX_OFTS - 1);
        orderSafeRelayerInstances = new OrderSafeRelayer[](MAX_OFTS - 1);
        OrderSafe orderSafeImpl = new OrderSafe();
        OrderSafeRelayer orderSafeRelayerImpl = new OrderSafeRelayer();

        for (uint8 i = 0; i < MAX_OFTS - 1; i++) {
            ERC1967Proxy orderSafeProxy = new ERC1967Proxy(address(orderSafeImpl), initData);
            ERC1967Proxy orderSafeRelayerProxy = new ERC1967Proxy(address(orderSafeRelayerImpl), initData);
            orderSafeInstances[i] = OrderSafe(address(orderSafeProxy));
            orderSafeRelayerInstances[i] = OrderSafeRelayer(payable(address(orderSafeRelayerProxy)));

            orderSafeRelayerInstances[i].setEid(chainIds[i], eids[i]);
            orderSafeRelayerInstances[i].setEndpoint(endpoints[i]);
            orderSafeRelayerInstances[i].setOft(ofts[i]);
            orderSafeRelayerInstances[i].setLocalComposeMsgSender(ofts[i], true);
            orderSafeRelayerInstances[i].setOptionsAirdrop(0, receiveGas, value);
            orderSafeRelayerInstances[i].setOptionsAirdrop(1, composeGas, value);
            orderSafeRelayerInstances[i].setOrderChainId(chainIds[MAX_OFTS - 1], eids[MAX_OFTS - 1]);
            orderSafeRelayerInstances[i].setOrderSafe(address(orderSafeInstances[i]));
            orderSafeRelayerInstances[i].setOrderBoxRelayer(address(orderBoxRelayer));
            orderSafeRelayerInstances[i].setRemoteComposeMsgSender(eids[MAX_OFTS - 1], address(orderBoxRelayer), true);

            orderSafeInstances[i].setOft(ofts[i]);
            orderSafeInstances[i].setOrderRelayer(address(orderSafeRelayerInstances[i]));

            orderBoxRelayer.setRemoteComposeMsgSender(eids[i], address(orderSafeRelayerInstances[i]), true);
            orderBoxRelayer.setEid(chainIds[i], eids[i]);
        }
        // console.log("Deployed and set OrderSafe and OrderSafeRelayer on eids: %d - %d", eids[0], eids[MAX_OFTS - 2]);
    }

    /**
     * @dev Initiate token transfer from the ERC20 contract to other OFT contracts
     * @dev Test token transfer between any two OFT contracts
     */
    function _setDistribution() internal {
        _init();
        uint256 initialSend = INIT_MINT / MAX_OFTS;
        uint256 initialRelay = initialSend / MAX_OFTS;
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            uint256 tokenToSend = i == 0 ? initialSend : initialRelay;
            for (uint8 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                _checkApproval(i);

                _send(i, j, tokenToSend);
                verifyPackets(eids[j], addressToBytes32(ofts[j]));
            }
        }

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            assertEq(
                IERC20(oftInstances[i].token()).balanceOf(address(this)),
                i == 0 ? INIT_MINT - (MAX_OFTS - 1) * (initialSend - initialRelay) : initialSend - initialRelay
            );
        }

        // console.log("Distributed tokens to %d - %d OFTs", eids[1], eids[MAX_OFTS - 1]);
    }

    function _init() internal {
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            assertEq(oftInstances[i].owner(), address(this));
            assertEq(oftInstances[i].endpoint().eid(), eids[i]);
            assertEq(address(oftInstances[i].endpoint()), endpoints[eids[i]]);
            if (i == 0) {
                assertEq(oftInstances[i].token(), address(token));
                assertEq(oftInstances[i].approvalRequired(), true);
                assertEq(IERC20(oftInstances[i].token()).balanceOf(address(this)), INIT_MINT);
            } else {
                assertEq(oftInstances[i].token(), ofts[i]);
                assertEq(oftInstances[i].approvalRequired(), false);
                assertEq(oftInstances[i].balanceOf(address(this)), 0);
            }
        }

        // check if ofts are fully connected
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint256 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                assertEq(oftInstances[i].isPeer(eids[j], addressToBytes32(ofts[j])), true);
                assertEq(oftInstances[i].orderedNonce(eids[j]), true);
            }
        }

        // console.log("Check the initial state for %d ofts", MAX_OFTS);
    }

    function _checkApproval(uint8 from) internal {
        if (oftInstances[from].approvalRequired()) {
            IERC20(oftInstances[from].token()).approve(ofts[from], INIT_MINT);
        }
    }

    function _send(
        uint8 from,
        uint8 to,
        uint256 amount
    ) internal returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(RECEIVE_GAS, VALUE);
        SendParam memory sendParam = SendParam(
            eids[to],
            addressToBytes32(address(this)),
            amount,
            amount,
            options,
            "",
            ""
        );
        MessagingFee memory fee = oftInstances[from].quoteSend(sendParam, false);
        (msgReceipt, oftReceipt) = oftInstances[from].send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );
    }

    function commitPackets(uint32 _dstEid, bytes32 _dstAddress, uint256 _packetAmount) public {
        require(endpoints[_dstEid] != address(0), "endpoint not yet registered");

        DoubleEndedQueue.Bytes32Deque storage queue = packetsQueue[_dstEid][_dstAddress];
        uint256 pendingPacketsSize = queue.length();
        uint256 numberOfPackets;
        if (_packetAmount == 0) {
            numberOfPackets = queue.length();
        } else {
            numberOfPackets = pendingPacketsSize > _packetAmount ? _packetAmount : pendingPacketsSize;
        }
        while (numberOfPackets > 0) {
            // front in, back out
            bytes32 guid = queue.popBack();
            bytes memory packetBytes = packets[guid];
            this.assertGuid(packetBytes, guid);
            this.validatePacket(packetBytes);
            numberOfPackets--;
        }
    }

    function recommitPacket(bytes32 guid) public {
        bytes memory packetBytes = packets[guid];
        this.assertGuid(packetBytes, guid);
        this.validatePacket(packetBytes);
    }

    function executePacket(address composer, bytes32 guid) public {
        bytes memory packetBytes = packets[guid];
        bytes memory options = optionsLookup[guid];
        if (_executorOptionExists(options, ExecutorOptions.OPTION_TYPE_NATIVE_DROP)) {
            (uint256 amount, bytes32 receiver) = _parseExecutorNativeDropOption(options);
            address to = address(uint160(uint256(receiver)));
            (bool sent, ) = to.call{ value: amount }("");
            require(sent, "Failed to send Ether");
        }
        if (_executorOptionExists(options, ExecutorOptions.OPTION_TYPE_LZRECEIVE)) {
            this.lzReceive(packetBytes, options);
        }
        if (composer != address(0) && _executorOptionExists(options, ExecutorOptions.OPTION_TYPE_LZCOMPOSE)) {
            this.lzCompose(packetBytes, options, guid, composer);
        }
    }

    function executePacketRevert(address composer, bytes32 guid, bytes memory revertInfo) public {
        bytes memory packetBytes = packets[guid];
        bytes memory options = optionsLookup[guid];
        if (_executorOptionExists(options, ExecutorOptions.OPTION_TYPE_NATIVE_DROP)) {
            (uint256 amount, bytes32 receiver) = _parseExecutorNativeDropOption(options);
            address to = address(uint160(uint256(receiver)));
            (bool sent, ) = to.call{ value: amount }("");
            require(sent, "Failed to send Ether");
        }
        if (_executorOptionExists(options, ExecutorOptions.OPTION_TYPE_LZRECEIVE)) {
            vm.expectRevert(revertInfo);
            this.lzReceive(packetBytes, options);
        }
        if (composer != address(0) && _executorOptionExists(options, ExecutorOptions.OPTION_TYPE_LZCOMPOSE)) {
            vm.expectRevert(revertInfo);
            this.lzCompose(packetBytes, options, guid, composer);
        }
    }
}
