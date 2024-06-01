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

    uint128 public constant RECEIVE_GAS = 200000;
    uint128 public constant COMPOSE_GAS = 500000;
    uint128 public constant VALUE = 0;

    EnforcedOptionParam[] public enforcedOptions;

    uint8 public constant MAX_OFTS = 3;
    uint32[] public eids;
    address[] public ofts;

    address public userA = address(0x1);
    address public userB = address(0x2);
    uint256 public initialBalance = 100 ether;

    OrderToken token;
    OrderAdapter oftA;
    OrderOFT oftB;
    OrderOFT oftC;

    function setUp() public override {
        vm.deal(address(this), 1000 ether);

        super.setUp();
        setUpEndpoints(MAX_OFTS, LibraryType.UltraLightNode);
        uint32 aEid = 1; // endpoint id on ethereum side
        uint32 bEid = 2; // endpoint id on vault side
        uint32 cEid = 3; // endpoint id on ledge side

        eids = new uint32[](MAX_OFTS);
        eids[0] = aEid;
        eids[1] = bEid;
        eids[2] = cEid;

        token = new OrderToken(address(this));

        OrderAdapter orderAdapterImpl = new OrderAdapter();
        OrderOFT orderOFTImpl = new OrderOFT();

        bytes memory orderOFTInitDataA = abi.encodeWithSignature(
            "initialize(address,address,address)",
            address(token),
            address(endpoints[eids[0]]),
            address(this)
        );
        ERC1967Proxy oftProxyA = new ERC1967Proxy(address(orderAdapterImpl), orderOFTInitDataA);
        oftA = OrderAdapter(address(oftProxyA));

        bytes memory orderOFTInitDataB = abi.encodeWithSignature(
            "initialize(address,address)",
            address(endpoints[eids[1]]),
            address(this)
        );

        ERC1967Proxy orderOFTProxyB = new ERC1967Proxy(address(orderOFTImpl), orderOFTInitDataB);
        oftB = OrderOFT(address(orderOFTProxyB));

        bytes memory orderOFTInitDataC = abi.encodeWithSignature(
            "initialize(address,address)",
            address(endpoints[eids[2]]),
            address(this)
        );

        ERC1967Proxy orderOFTProxy = new ERC1967Proxy(address(orderOFTImpl), orderOFTInitDataC);
        oftC = OrderOFT(address(orderOFTProxy));

        ofts = new address[](MAX_OFTS);
        ofts[0] = address(oftA);
        ofts[1] = address(oftB);
        ofts[2] = address(oftC);

        this.wireOApps(ofts);
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

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
            OrderOFT(ofts[i]).setEnforcedOptions(enforcedOptions);
        }
    }

    function test_init() public {
        assertEq(token.balanceOf(address(this)), 1_000_000_000 ether);

        assertEq(ofts.length, 3);
        assertEq(oftA.owner(), address(this));
        assertEq(oftA.token(), address(token));
        assertEq(oftA.approvalRequired(), true);
        assertEq(oftA.orderedNonce(), true);

        assertEq(oftB.owner(), address(this));
        assertEq(oftB.token(), address(oftB));
        assertEq(oftB.approvalRequired(), false);
        assertEq(oftB.orderedNonce(), true);

        assertEq(oftC.owner(), address(this));
        assertEq(oftC.token(), address(oftC));
        assertEq(oftC.approvalRequired(), false);
        assertEq(oftC.orderedNonce(), true);

        // fully connected ofts
        for (uint256 i = 0; i < ofts.length; i++) {
            for (uint256 j = 0; j < ofts.length; j++) {
                if (i == j) continue;
                assertEq(OrderOFT(ofts[i]).isPeer(eids[j], addressToBytes32(ofts[j])), true);
            }
        }
    }

    function test_distribute() public {
        uint256 tokenToSend = 1_000_000 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        for (uint256 i = 0; i < ofts.length; i++) {
            for (uint256 j = 0; j < ofts.length; j++) {
                if (i == j) continue;

                uint32 dstEid = eids[j];
                bytes32 to = addressToBytes32(address(this));
                uint256 amountLD = tokenToSend;
                uint256 minAmountLD = tokenToSend;
                bytes memory extraOptions = options;
                bytes memory composeMsg = "";
                bytes memory oftCmd = "";
                SendParam memory sendParam = SendParam(
                    dstEid,
                    to,
                    amountLD,
                    minAmountLD,
                    extraOptions,
                    composeMsg,
                    oftCmd
                );
                MessagingFee memory fee = oftA.quoteSend(sendParam, false);
            }
        }
    }
    // TODO import the rest of oft tests?
}
