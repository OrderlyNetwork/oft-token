// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Forge imports
import "forge-std/console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {OrderTokenMock} from "test/mocks/OrderTokenMock.sol";
import {OrderOFTMock} from "test/mocks/OrderOFTMock.sol";
import {OrderAdapterMock} from "test/mocks/OrderAdapterMock.sol";
import {OFTInspectorMock} from "test/mocks/OFTInspectorMock.sol";

import {OrderHandler} from "test/foundry/invariant/handlers/OrderHandler.sol";

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {
    IOAppOptionsType3,
    EnforcedOptionParam
} from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";

import {VerifyHelper} from "test/foundry/invariant/helpers/VerifyHelper.sol";

// Order imports
import {OrderToken} from "contracts/OrderToken.sol";
import {OrderAdapter} from "contracts/OrderAdapter.sol";
import {OrderOFT} from "contracts/OrderOFT.sol";
import {OrderBox} from "contracts/crosschain/OrderBox.sol";
import {OrderBoxRelayer} from "contracts/crosschain/OrderBoxRelayer.sol";
import {OrderSafe} from "contracts/crosschain/OrderSafe.sol";
import {OrderSafeRelayer} from "contracts/crosschain/OrderSafeRelayer.sol";

// OFT imports
import {
    IOFT,
    SendParam,
    OFTReceipt,
    MessagingReceipt
} from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCoreUpgradeable.sol";
import {OFTMsgCodec} from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {OFTComposeMsgCodec} from "contracts/layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

// OZ imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// forgefmt: disable-start
/**************************************************************************************************************************************/
/*** Invariant Tests                                                                                                                ***/
/***************************************************************************************************************************************

    * OT-01: Total Supply of ORDER should always be 1,000,000,000

/**************************************************************************************************************************************/
/*** OrderInvariant configures an OFT system that contains 10 endpoints.                                                             ***/
/*** The system contains the OrderToken, as well as, its OFT adapter.                                                               ***/
/*** The rest of the endpoints are connected to OrderOFT Instances.                                                                 ***/
/*** It also contains global invariants.                                                                                            ***/
/**************************************************************************************************************************************/
// forgefmt: disable-end

contract OrderInvariant is StdInvariant, TestHelperOz5 {
    /*//////////////////////////////////////////////////////////////////////////
                            BASE INVARIANT VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address user0 = vm.addr(uint256(keccak256("User0")));
    address user1 = vm.addr(uint256(keccak256("User1")));
    address user2 = vm.addr(uint256(keccak256("User2")));
    address user3 = vm.addr(uint256(keccak256("User3")));
    address user4 = vm.addr(uint256(keccak256("User4")));
    address user5 = vm.addr(uint256(keccak256("User5")));
    address[] users = [user0, user1, user2, user3, user4, user5];

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

    OrderTokenMock token;

    uint8 public constant MAX_OFTS = 10;
    // eid = 1: endpoint id on l1 side: ethereum, the first one always the ethereum chain
    // eid = 2: endpoint id on vault side: arb
    // eid = 3: endpoint id on vault side: op
    // eid = 4: endpoint id on ledge side: orderly, the last one always the orderly chain
    uint32[] public eids;
    address[] public ofts;
    OrderOFTMock[] public oftInstances;

    OrderBox public orderBox;
    OrderBoxRelayer public orderBoxRelayer;
    OrderSafe[] public orderSafeInstances;
    OrderSafeRelayer[] public orderSafeRelayerInstances;

    uint256[] public chainIds;

    OrderHandler orderHandler;

    VerifyHelper verifyHelper;

    uint256 initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(address(this), 1000000 ether);
        vm.deal(user0, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(user4, 1000 ether);
        vm.deal(user5, 1000 ether);

        // Set the OFT contracts
        _setOft();

        // Set the contracts to test cross-chain flow
        _setCC();

        // Initiate token transfer from the ERC20 contract to other OFT contracts
        _setDistribution();

        verifyHelper = new VerifyHelper(this);

        orderHandler = new OrderHandler(oftInstances, verifyHelper);

        targetContract(address(orderHandler));

        bytes4[] memory orderSelectors = new bytes4[](5);
        orderSelectors[0] = orderHandler.approve.selector;
        orderSelectors[1] = orderHandler.transfer.selector;
        orderSelectors[2] = orderHandler.transferFrom.selector;
        orderSelectors[3] = orderHandler.send.selector;
        orderSelectors[4] = orderHandler.verifyPackets.selector;

        targetSelector(FuzzSelector({addr: address(orderHandler), selectors: orderSelectors}));
    }

    function invariantOrderTokenBalanceSum() external {
        assertEq(
            token.totalSupply(), 1_000_000_000 ether, "OT-01: Total Supply of ORDER should always be 1,000,000,000"
        );
    }

    function _setOft() internal {
        setUpEndpoints(MAX_OFTS, LibraryType.UltraLightNode);
        console.log("Set up %d endpoints", MAX_OFTS);

        token = new OrderTokenMock(address(this));
        OrderAdapterMock orderAdapterImpl = new OrderAdapterMock();
        OrderOFTMock orderOFTImpl = new OrderOFTMock();

        eids = new uint32[](MAX_OFTS);

        ofts = new address[](MAX_OFTS);
        oftInstances = new OrderOFTMock[](MAX_OFTS);
        bytes memory oftInitDate;

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            eids[i] = i + 1;
            oftInitDate = i == 0
                ? abi.encodeWithSignature(
                    "initialize(address,address,address)", address(token), address(endpoints[eids[i]]), address(this)
                )
                : abi.encodeWithSignature("initialize(address,address)", address(endpoints[eids[i]]), address(this));

            ERC1967Proxy oftProxy =
                new ERC1967Proxy(i == 0 ? address(orderAdapterImpl) : address(orderOFTImpl), oftInitDate);
            ofts[i] = address(oftProxy);
            oftInstances[i] = OrderOFTMock(address(oftProxy));
        }

        console.log("Set up %d OFTs", MAX_OFTS);

        this.wireOApps(ofts);

        console.log("Wired %d OFTs", MAX_OFTS);

        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint256 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                EnforcedOptionParam memory enforcedOptionSend = EnforcedOptionParam(
                    eids[j],
                    uint16(OptionTypes.SEND),
                    OptionsBuilder.newOptions().addExecutorLzReceiveOption(RECEIVE_GAS, VALUE)
                        .addExecutorOrderedExecutionOption()
                );
                EnforcedOptionParam memory enforcedOptionSendAndCall = EnforcedOptionParam(
                    eids[j],
                    uint16(OptionTypes.SEND_AND_CALL),
                    OptionsBuilder.newOptions().addExecutorLzReceiveOption(RECEIVE_GAS, VALUE)
                        .addExecutorLzComposeOption(0, COMPOSE_GAS, VALUE).addExecutorOrderedExecutionOption()
                );
                enforcedOptions.push(enforcedOptionSend);
                enforcedOptions.push(enforcedOptionSendAndCall);
            }
            oftInstances[i].setEnforcedOptions(enforcedOptions);
        }

        console.log("Set enforced options for %d OFTs", MAX_OFTS);
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

        console.log("Set chainIds for %d OFTs", MAX_OFTS);

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

        console.log("Deployed and set OrderBox and OrderBoxRelayer on eid: %d", eids[MAX_OFTS - 1]);

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
        console.log("Deployed and set OrderSafe and OrderSafeRelayer on eids: %d - %d", eids[0], eids[MAX_OFTS - 2]);
    }

    /**
     * @dev Initiate token transfer from the ERC20 contract to other OFT contracts
     * @dev Test token transfer between any two OFT contracts
     */
    function _setDistribution() internal {
        _init();
        for (uint8 i = 1; i < MAX_OFTS; i++) {
            oftInstances[i].mint(user0, initialBalance);
            oftInstances[i].mint(user1, initialBalance);
            oftInstances[i].mint(user2, initialBalance);
            oftInstances[i].mint(user3, initialBalance);
            oftInstances[i].mint(user4, initialBalance);
            oftInstances[i].mint(user5, initialBalance);
        }
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

                SendParam memory sendParam =
                    SendParam(eids[j], addressToBytes32(address(this)), tokenToSend, tokenToSend, options, "", "");
                MessagingFee memory fee = oftInstances[i].quoteSend(sendParam, false);

                oftInstances[i].send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
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

        console.log("Distributed tokens to %d - %d OFTs", eids[1], eids[MAX_OFTS - 1]);
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
            // assertEq(oftInstances[i].orderedNonce(), true);
        }

        // check if ofts are fully connected
        for (uint8 i = 0; i < MAX_OFTS; i++) {
            for (uint256 j = 0; j < MAX_OFTS; j++) {
                if (i == j) continue;
                assertEq(oftInstances[i].isPeer(eids[j], addressToBytes32(ofts[j])), true);
            }
        }

        console.log("Check the initial state for %d ofts", MAX_OFTS);
    }
}
