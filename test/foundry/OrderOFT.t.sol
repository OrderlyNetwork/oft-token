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

// OFT imports
import { IOFT, SendParam, OFTReceipt, MessagingReceipt } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingFee } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";
import { OFTMsgCodec } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "../../contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/Vm.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract OrderOFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    enum OptionTypes {
        SEND,
        SEND_AND_CALL
    }

    uint256 public constant INIT_BALANCE = 1000 ether;
    uint256 public constant INIT_MINT = 1_000_000_000 ether;
    uint128 public constant RECEIVE_GAS = 200_000;
    uint128 public constant COMPOSE_GAS = 500_000;
    uint128 public constant VALUE = 0;

    EnforcedOptionParam[] public enforcedOptions;

    OrderToken token;

    uint8 public constant MAX_OFTS = 4;
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
        // Top up this contract with 1000 ether
        vm.deal(address(this), INIT_BALANCE);
        // Set the OFT contracts
        _setOfts();
        // Set the contracts to test cross-chain flow
        _setCC();
    }

    /**
     * @dev Check the initialization of the OFT contracts
     */
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

        // check if ofts are fully connected
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint256 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                assertEq(oftInstances[i].isPeer(eids[j], addressToBytes32(ofts[j])), true);
            }
        }
    }

    function test_stake_msg() public {
        _distribute();

        uint256 tokenToStake = 1 ether;
        uint256 stakeFee;
        MessagingReceipt memory msgReceipt;
        OFTReceipt memory oftReceipt;
        for (uint8 i = 0; i < 1; i++) {
            IERC20(oftInstances[i].token()).approve(address(orderSafeInstances[i]), tokenToStake);
            stakeFee = orderSafeInstances[i].getStakeFee(address(this), tokenToStake);

            // vm.recordLogs();
            (msgReceipt, oftReceipt) = orderSafeInstances[i].stakeOrder{ value: stakeFee }(address(this), tokenToStake);
            // Vm.Log[] memory logEntries = vm.getRecordedLogs();

            // bytes memory options;

            // for (uint8 i = 0; i < logEntries.length; i++) {
            //     if (logEntries[i].topics[0] == keccak256("PacketSent(bytes,bytes,address)")) {
            //         (, options, ) = abi.decode(logEntries[5].data, (bytes, bytes, address));
            //         break;
            //     }
            // }

            verifyPackets(eids[MAX_OFTS - 1], addressToBytes32(ofts[MAX_OFTS - 1]));
            // this.lzCompose(eids[MAX_OFTS - 1], ofts[i], options, msgReceipt.guid, address, composerMsg_);
        }
    }
    // TODO import the rest of oft tests?
    // composeMsg
    // ABA pattern
    // ABA composeMsg pattern
    // nonce control

    /**
     * @dev Set up the OFT contracts and connect them to each other
     */
    function _setOfts() internal {
        super.setUp();
        // Set up the endpoints: eid => endpoint
        setUpEndpoints(MAX_OFTS, LibraryType.UltraLightNode);

        token = new OrderToken(address(this));
        OrderAdapter orderAdapterImpl = new OrderAdapter();
        OrderOFT orderOFTImpl = new OrderOFT();

        eids = new uint32[](MAX_OFTS);
        ofts = new address[](MAX_OFTS);
        oftInstances = new OrderOFT[](MAX_OFTS);

        bytes memory oftInitDate;
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            eids[i] = i + 1;

            // Initialize the OFT contracts
            // The first one is the Adapter contracts and the rest are OFT contracts
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
            // Save the OFT addresses and instances
            ofts[i] = address(oftProxy);
            oftInstances[i] = OrderOFT(address(oftProxy));
        }

        // Wire the OFT contracts to each other
        this.wireOApps(ofts);

        // Set the enforced options for the OFT contracts
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
            }
            oftInstances[i].setEnforcedOptions(enforcedOptions);
        }
    }

    /**
     * @dev Initiate token transfer from the ERC20 contract to other OFT contracts
     * @dev Test token transfer between any two OFT contracts
     */
    function _distribute() internal {
        uint256 initialSend = INIT_MINT / MAX_OFTS;
        uint256 initialRelay = initialSend / MAX_OFTS;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            uint256 tokenToSend = i == 0 ? initialSend : initialRelay;
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
            }
        }

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            assertEq(
                IERC20(oftInstances[i].token()).balanceOf(address(this)),
                i == 0
                    ? INIT_MINT - (MAX_OFTS - 1) * initialSend + (MAX_OFTS - 1) * initialRelay
                    : initialSend - initialRelay
            );
        }
        console.log(address(this));
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
        uint128 receiveGas = 20_000;
        uint128 composeGas = 50_000;
        uint128 value = 0;
        // chain id mock
        chainIds = new uint256[](MAX_OFTS);
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            chainIds[i] = block.chainid + eids[i];
        }

        bytes memory initData = abi.encodeWithSignature("initialize(address)", address(this));

        // deploy OrderBox and OrderBoxRelayer
        OrderBox orderBoxImpl = new OrderBox();
        OrderBoxRelayer orderBoxRelayerImpl = new OrderBoxRelayer();
        ERC1967Proxy orderBoxProxy = new ERC1967Proxy(address(orderBoxImpl), initData);
        ERC1967Proxy orderBoxRelayerProxy = new ERC1967Proxy(address(orderBoxRelayerImpl), initData);
        orderBox = OrderBox(address(orderBoxProxy));
        orderBoxRelayer = OrderBoxRelayer(payable(address(orderBoxRelayerProxy)));

        // set OrderBoxRelayer
        orderBoxRelayer.setEid(chainIds[MAX_OFTS - 1], eids[MAX_OFTS - 1]);
        orderBoxRelayer.setEndpoint(endpoints[MAX_OFTS - 1]);
        orderBoxRelayer.setOft(ofts[MAX_OFTS - 1]);
        orderBoxRelayer.setLocalComposeMsgSender(ofts[MAX_OFTS - 1], true);
        orderBoxRelayer.setOptionsAirdrop(0, receiveGas, value); // lz receive
        orderBoxRelayer.setOptionsAirdrop(1, composeGas, value); // lz compose
        orderBoxRelayer.setOrderBox(address(orderBox));

        // set OrderBox
        orderBox.setOft(ofts[MAX_OFTS - 1]);
        orderBox.setOrderRelayer(address(orderBoxRelayer));

        // deploy OrderSafe and OrderSafeRelayer
        orderSafeInstances = new OrderSafe[](MAX_OFTS - 1);
        orderSafeRelayerInstances = new OrderSafeRelayer[](MAX_OFTS - 1);
        OrderSafe orderSafeImpl = new OrderSafe();
        OrderSafeRelayer orderSafeRelayerImpl = new OrderSafeRelayer();

        for (uint8 i = 0; i < MAX_OFTS - 1; i++) {
            ERC1967Proxy orderSafeProxy = new ERC1967Proxy(address(orderSafeImpl), initData);
            ERC1967Proxy orderSafeRelayerProxy = new ERC1967Proxy(address(orderSafeRelayerImpl), initData);
            orderSafeInstances[i] = OrderSafe(address(orderSafeProxy));
            orderSafeRelayerInstances[i] = OrderSafeRelayer(payable(address(orderSafeRelayerProxy)));

            // set OrderSafeRelayer
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

            // set OrderSafe
            orderSafeInstances[i].setOft(ofts[i]);
            orderSafeInstances[i].setOrderRelayer(address(orderSafeRelayerInstances[i]));

            // set OrderBoxRelayer
            orderBoxRelayer.setRemoteComposeMsgSender(eids[i], address(orderSafeRelayerInstances[i]), true);
            orderBoxRelayer.setEid(chainIds[i], eids[i]);
        }
    }
}
