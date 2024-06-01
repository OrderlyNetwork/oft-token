// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Order imports
import { OrderToken } from "../../contracts/OrderToken.sol";
import { OrderAdapter } from "../../contracts/OrderAdapter.sol";
import { OrderOFT } from "../../contracts/OrderOFT.sol";

// Mock imports
import { OFTMock } from "../mocks/OFTMock.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { OFTComposerMock } from "../mocks/OFTComposerMock.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import { OptionsBuilder } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

// OFT imports
import { IOFT, SendParam, OFTReceipt } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";
import { OFTMsgCodec } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract OrderOFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    enum OptionTypes {
        SEND,
        SEND_AND_CALL
    }

    uint256 public constant INIT_MINT = 1_000_000_000 ether;
    uint128 public constant RECEIVE_GAS = 200000;
    uint128 public constant COMPOSE_GAS = 500000;
    uint128 public constant VALUE = 0;

    EnforcedOptionParam[] public enforcedOptions;

    OrderToken token;
    OrderAdapter oftA;
    OrderOFT oftB;
    OrderOFT oftC;

    uint8 public constant MAX_OFTS = 4;
    uint32[] public eids;
    address[] public ofts;
    OrderOFT[] public oftInstances;

    function setUp() public override {
        vm.deal(address(this), 1000 ether);

        super.setUp();
        setUpEndpoints(MAX_OFTS, LibraryType.UltraLightNode);

        token = new OrderToken(address(this));
        OrderAdapter orderAdapterImpl = new OrderAdapter();
        OrderOFT orderOFTImpl = new OrderOFT();

        // eid = 1: endpoint id on ethereum side
        // eid = 2: endpoint id on vault side: arb
        // eid = 3: endpoint id on vault side: op
        // eid = 4: endpoint id on ledge side: orderly
        eids = new uint32[](MAX_OFTS);

        ofts = new address[](MAX_OFTS);
        oftInstances = new OrderOFT[](MAX_OFTS);
        bytes memory oftInitDate;
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            eids[i] = i + 1;
            if (i == 0) {
                oftInitDate = abi.encodeWithSignature(
                    "initialize(address,address,address)",
                    address(token),
                    address(endpoints[eids[i]]),
                    address(this)
                );
            } else {
                oftInitDate = abi.encodeWithSignature(
                    "initialize(address,address)",
                    address(endpoints[eids[i]]),
                    address(this)
                );
            }

            ERC1967Proxy oftProxy = new ERC1967Proxy(
                i == 0 ? address(orderAdapterImpl) : address(orderOFTImpl),
                oftInitDate
            );
            ofts[i] = address(oftProxy);
            oftInstances[i] = OrderOFT(address(oftProxy));
        }

        this.wireOApps(ofts);

        for (uint256 i = 0; i < MAX_OFTS; i++) {
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
            }
            oftInstances[i].setEnforcedOptions(enforcedOptions);
        }
    }

    function test_init() public {
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
            assertEq(oftInstances[i].orderedNonce(), true);
        }

        // fully connected ofts
        for (uint256 i = 0; i < ofts.length; i++) {
            for (uint256 j = 0; j < ofts.length; j++) {
                if (i == j) continue;
                assertEq(oftInstances[i].isPeer(eids[j], addressToBytes32(ofts[j])), true);
            }
        }
    }

    function test_distribute() public {
        uint256 tokenToSend = 1_000_000 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        for (uint256 i = 0; i < 1; i++) {
            for (uint256 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                if (oftInstances[i].approvalRequired()) {
                    IERC20(oftInstances[i].token()).approve(ofts[i], tokenToSend);
                }

                SendParam memory sendParam = SendParam(
                    eids[j],
                    addressToBytes32(address(this)),
                    tokenToSend,
                    tokenToSend,
                    options,
                    "",
                    ""
                );
                MessagingFee memory fee = oftInstances[i].quoteSend(sendParam, false);

                oftInstances[i].send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
                verifyPackets(eids[j], addressToBytes32(ofts[j]));
                assertEq(IERC20(oftInstances[j].token()).balanceOf(address(this)), tokenToSend);
            }
            assertEq(
                IERC20(oftInstances[i].token()).balanceOf(address(this)),
                INIT_MINT - tokenToSend * (MAX_OFTS - 1)
            );
        }
    }
    // TODO import the rest of oft tests?
}
