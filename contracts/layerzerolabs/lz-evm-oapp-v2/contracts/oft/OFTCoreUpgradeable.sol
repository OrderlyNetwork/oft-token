// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { OAppUpgradeable, Origin } from "../oapp/OAppUpgradeable.sol";
import { OAppOptionsType3Upgradeable } from "../oapp/libs/OAppOptionsType3Upgradeable.sol";
import { IOAppMsgInspector } from "../oapp/interfaces/IOAppMsgInspector.sol";

import { OAppPreCrimeSimulatorUpgradeable } from "../precrime/OAppPreCrimeSimulatorUpgradeable.sol";

import { IOFT, SendParam, OFTLimit, OFTReceipt, OFTFeeDetail, MessagingReceipt, MessagingFee } from "./interfaces/IOFT.sol";
import { IOCCManager } from "./interfaces/IOCCManager.sol";
import { OFTMsgCodec } from "./libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "./libs/OFTComposeMsgCodec.sol";
import { OCCMsgCodec } from "./libs/OCCMsgCodec.sol";

/**
 * @title OFTCore
 * @dev Abstract contract for the OftChain (OFT) token.
 */
abstract contract OFTCoreUpgradeable is
    IOFT,
    OAppUpgradeable,
    OAppPreCrimeSimulatorUpgradeable,
    OAppOptionsType3Upgradeable
{
    using OCCMsgCodec for bytes;
    using OCCMsgCodec for bytes32;

    // @notice Provides a conversion rate when swapping between denominations of SD and LD
    //      - shareDecimals == SD == shared Decimals
    //      - localDecimals == LD == local decimals
    // @dev Considers that tokens have different decimal amounts on various chains.
    // @dev eg.
    //  For a token
    //      - locally with 4 decimals --> 1.2345 => uint(12345)
    //      - remotely with 2 decimals --> 1.23 => uint(123)
    //      - The conversion rate would be 10 ** (4 - 2) = 100
    //  @dev If you want to send 1.2345 -> (uint 12345), you CANNOT represent that value on the remote,
    //  you can only display 1.23 -> uint(123).
    //  @dev To preserve the dust that would otherwise be lost on that conversion,
    //  we need to unify a denomination that can be represented on ALL chains inside of the OFT mesh
    uint256 public decimalConversionRate;

    // @notice Msg types that are used to identify the various OFT operations.
    // @dev This can be extended in child contracts for non-default oft operations
    // @dev These values are used in things like combineOptions() in OAppOptionsType3.sol.
    uint16 public constant SEND = 1;
    uint16 public constant SEND_AND_CALL = 2;

    // Address of an optional contract to inspect both 'message' and 'options'
    address public msgInspector;

    /* ============================ Storage Slots + __gap == 50 ============================ */
    // @dev The gap to prevent storage collisions
    // @dev https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    // @dev New storage should be added below this line, and no exceeding 50 slots

    // @dev Reord nonce for inbound messages: srcEid => sender => nonce
    mapping(uint32 => mapping(bytes32 => uint64)) public maxReceivedNonce;
    address public occManager;
    // @dev Flag to enforce ordered nonce, if true, the nonce must be strictly increasing by 1
    bool public orderedNonce;

    uint256[47] private __gap;

    event MsgInspectorSet(address inspector);

    modifier onlyOCCManager(address _addr) {
        require(_addr == occManager, "OFT: Only OCCManager");
        _;
    }

    modifier zeroAddressCheck(address _addr) {
        require(_addr != address(0), "OFT: ZeroAddress");
        _;
    }

    /**
     * @dev Initializer.
     * @param _localDecimals The decimals of the token on the local chain (this chain).
     * @param _endpoint The address of the LayerZero endpoint.
     * @param _delegate The address of delegate for the OFT owner on the endpoint.
     */
    function __initializeOFTCore(
        uint8 _localDecimals,
        address _endpoint,
        address _delegate
    ) internal virtual onlyInitializing {
        __initializeOApp(_endpoint, _delegate);
        if (_localDecimals < sharedDecimals()) revert InvalidLocalDecimals();
        decimalConversionRate = 10 ** (_localDecimals - sharedDecimals());
    }

    /**
     * @notice Retrieves interfaceID and the version of the OFT.
     * @return interfaceId The interface ID.
     * @return version The version.
     *
     * @dev interfaceId: This specific interface ID is '0x02e49c2c'.
     * @dev version: Indicates a cross-chain compatible msg encoding with other OFTs.
     * @dev If a new feature is added to the OFT cross-chain msg encoding, the version will be incremented.
     * ie. localOFT version(x,1) CAN send messages to remoteOFT version(x,1)
     */
    function oftVersion() external pure virtual returns (bytes4 interfaceId, uint64 version) {
        return (type(IOFT).interfaceId, 1);
    }

    /**
     * @dev Retrieves the shared decimals of the OFT.
     * @return The shared decimals of the OFT.
     *
     * @dev Sets an implicit cap on the amount of tokens, over uint64.max() will need some sort of outbound cap / totalSupply cap
     * Lowest common decimal denominator between chains.
     * Defaults to 6 decimal places to provide up to 18,446,744,073,709.551615 units (max uint64).
     * For tokens exceeding this totalSupply(), they will need to override the sharedDecimals function with something smaller.
     * ie. 4 sharedDecimals would be 1,844,674,407,370,955.1615
     * @notice For ORDER tokens, the sharedDecimals should be set to 18 (decimalConversionRate = 1), no precision lost during cross-chain transfer.
     */
    function sharedDecimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev Sets the message inspector address for the OFT.
     * @param _msgInspector The address of the message inspector.
     *
     * @dev This is an optional contract that can be used to inspect both 'message' and 'options'.
     * @dev Set it to address(0) to disable it, or set it to a contract address to enable it.
     */
    function setMsgInspector(address _msgInspector) public virtual onlyOwner {
        msgInspector = _msgInspector;
        emit MsgInspectorSet(_msgInspector);
    }

    /**
     * @notice Provides a quote for OFT-related operations.
     * @param _sendParam The parameters for the send operation.
     * @return oftLimit The OFT limit information.
     * @return oftFeeDetails The details of OFT fees.
     * @return oftReceipt The OFT receipt information.
     */
    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        view
        virtual
        returns (OFTLimit memory oftLimit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory oftReceipt)
    {
        uint256 minAmountLD = 0; // Unused in the default implementation.
        uint256 maxAmountLD = type(uint256).max; // Unused in the default implementation.
        oftLimit = OFTLimit(minAmountLD, maxAmountLD);

        // Unused in the default implementation; reserved for future complex fee details.
        oftFeeDetails = new OFTFeeDetail[](0);

        // @dev This is the same as the send() operation, but without the actual send.
        // - amountSentLD is the amount in local decimals that would be sent from the sender.
        // - amountReceivedLD is the amount in local decimals that will be credited to the recipient on the remote OFT instance.
        // @dev The amountSentLD MIGHT not equal the amount the user actually receives. HOWEVER, the default does.
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debitView(
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);
    }

    /**
     * @notice Provides a quote for the send() operation.
     * @param _sendParam The parameters for the send() operation.
     * @param _payInLzToken Flag indicating whether the caller is paying in the LZ token.
     * @return msgFee The calculated LayerZero messaging fee from the send() operation.
     *
     * @dev MessagingFee: LayerZero msg fee
     *  - nativeFee: The native fee.
     *  - lzTokenFee: The lzToken fee.
     */
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view virtual returns (MessagingFee memory msgFee) {
        // @dev mock the amount to receive, this is the same operation used in the send().
        // The quote is as similar as possible to the actual send() operation.
        (, uint256 amountReceivedLD) = _debitView(_sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildTypeMsgAndOptions(
            uint16(OCCMsgCodec.MSG_TYPE.OFT_MSG),
            _sendParam,
            amountReceivedLD
        );

        // @dev Calculates the LayerZero fee for the send() operation.
        return _quote(_sendParam.dstEid, message, options, _payInLzToken);
    }

    /**
     * @dev Executes the send operation.
     * @param _sendParam The parameters for the send operation.
     * @param _fee The calculated fee for the send() operation.
     *      - nativeFee: The native fee.
     *      - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess funds.
     * @return msgReceipt The receipt for the send operation.
     * @return oftReceipt The OFT receipt information.
     *
     * @dev MessagingReceipt: LayerZero msg receipt
     *  - guid: The unique identifier for the sent message.
     *  - nonce: The nonce of the sent message.
     *  - fee: The LayerZero fee incurred for the message.
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        virtual
        override
        whenNotPaused
        zeroAddressCheck(_sendParam.to.bytes32ToAddress())
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        // require(_sendParam.to.bytes32ToAddress() != address(0), "OFT: Transfer to ZeroAddress");
        // @dev Applies the token transfers regarding this send() operation.
        // - amountSentLD is the amount in local decimals that was ACTUALLY sent/debited from the sender.
        // - amountReceivedLD is the amount in local decimals that will be received/credited to the recipient on the remote OFT instance.
        (uint256 amountSentLD, uint256 amountReceivedLD) = _sentToken(
            msg.sender,
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildTypeMsgAndOptions(
            uint16(OCCMsgCodec.MSG_TYPE.OFT_MSG),
            _sendParam,
            amountReceivedLD
        );

        // @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt = _lzSend(_sendParam.dstEid, message, options, _fee, _refundAddress);
        // @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, _sendParam.dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }

    /**
     * @notice Provides a quote for the relay() operation.
     * @param _sendParam The parameters for the relay() operation.
     * @param _payInLzToken Flag indicating whether the caller is paying in the LZ token.
     * @return msgFee The calculated LayerZero messaging fee from the relay() operation.
     *
     * @dev MessagingFee: LayerZero msg fee
     *  - nativeFee: The native fee.
     *  - lzTokenFee: The lzToken fee.
     */
    function quoteRelay(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view virtual returns (MessagingFee memory msgFee) {
        // @dev mock the amount to receive, this is the same operation used in the send().
        // The quote is as similar as possible to the actual send() operation.
        (, uint256 amountReceivedLD) = _debitView(_sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildTypeMsgAndOptions(
            uint16(OCCMsgCodec.MSG_TYPE.OCC_MSG),
            _sendParam,
            amountReceivedLD
        );

        // @dev Calculates the LayerZero fee for the send() operation.
        return _quote(_sendParam.dstEid, message, options, _payInLzToken);
    }

    /**
     * @dev Executes the relay operation.
     * @param _sendParam The parameters for the relay operation. USE THE SAME PARAMS AS send() but encoded with a different msgType.
     * @param _fee The calculated fee for the relay() operation.
     *      - nativeFee: The native fee.
     *      - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess funds.
     * @return msgReceipt The receipt for the send operation.
     * @return oftReceipt The OFT receipt information.
     *
     * @dev MessagingReceipt: LayerZero msg receipt
     *  - guid: The unique identifier for the sent message.
     *  - nonce: The nonce of the sent message.
     *  - fee: The LayerZero fee incurred for the message.
     */
    function relay(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        virtual
        whenNotPaused
        onlyOCCManager(msg.sender)
        zeroAddressCheck(_sendParam.to.bytes32ToAddress())
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        // @dev Applies the token transfers regarding this relay() operation.
        // - amountSentLD is the amount in local decimals that was ACTUALLY sent/debited from the sender.
        // - amountReceivedLD is the amount in local decimals that will be received/credited to the recipient on the remote OFT instance.
        (uint256 amountSentLD, uint256 amountReceivedLD) = _sentToken(
            msg.sender,
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        // @dev Builds the options and OFT message to quote in the endpoint.
        // TODO: Prevent an incorrect extraOptions with .addExecutorLzComposeOption()
        //       Should _check(extraOptions) in the relay() function.
        (bytes memory message, bytes memory options) = _buildTypeMsgAndOptions(
            uint16(OCCMsgCodec.MSG_TYPE.OCC_MSG),
            _sendParam,
            amountReceivedLD
        );

        // @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt = _lzSend(_sendParam.dstEid, message, options, _fee, _refundAddress);
        // @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OCCSent(msgReceipt.guid, _sendParam.dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }

    /**
     * @dev Internal function to build the message and options.
     * @param _sendParam The parameters for the send() operation.
     * @param _amountLD The amount in local decimals.
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function _buildTypeMsgAndOptions(
        uint16 _msgType,
        SendParam calldata _sendParam,
        uint256 _amountLD
    ) internal view virtual returns (bytes memory message, bytes memory options) {
        uint16 lzMsgType;
        if (_msgType == uint16(OCCMsgCodec.MSG_TYPE.OFT_MSG)) {
            bool hasCompose;
            (message, hasCompose) = OCCMsgCodec.encodeOFTMsg(
                _sendParam.to,
                _toSD(_amountLD),
                // @dev Must be include a non empty bytes if you want to compose, EVEN if you dont need it on the remote.
                // EVEN if you dont require an arbitrary payload to be sent... eg. '0x01'
                _sendParam.composeMsg
            );
            // @dev Change the msg type depending if its composed or not.
            lzMsgType = hasCompose ? SEND_AND_CALL : SEND;
        } else if (_msgType == uint16(OCCMsgCodec.MSG_TYPE.OCC_MSG)) {
            message = OCCMsgCodec.encodeOCCMsg(
                _sendParam.to,
                _toSD(_amountLD),
                // @dev Must be include a non empty bytes if you want to compose, EVEN if you dont need it on the remote.
                // EVEN if you dont require an arbitrary payload to be sent... eg. '0x01'
                _sendParam.composeMsg
            );
            // @dev The OCC_MSG is always a SEND operation.
            lzMsgType = SEND;
        }
        // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.
        options = combineOptions(_sendParam.dstEid, lzMsgType, _sendParam.extraOptions);
        // @dev Optionally inspect the message and options depending if the OApp owner has set a msg inspector.
        // @dev If it fails inspection, needs to revert in the implementation. ie. does not rely on return boolean
        if (msgInspector != address(0)) IOAppMsgInspector(msgInspector).inspect(message, options);
    }

    /**
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * @dev _executor The address of the executor.
     * @dev _extraData Additional data.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/, // @dev unused in the default implementation.
        bytes calldata /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override whenNotPaused {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);
        // @dev Decode the OFT message and route to the appropriate receive function.
        //      The message is encoded with the OFT/OCC message type.
        //      If the message is an OFT_MSG, it will be routed to the OFT receive function.
        //      If the message is an OCC_MSG, it will be routed to the OCC receive function.
        if (_message.getType() == uint16(OCCMsgCodec.MSG_TYPE.OFT_MSG)) _oftReceive(_origin, _guid, _message);
        else if (_message.getType() == uint16(OCCMsgCodec.MSG_TYPE.OCC_MSG)) _occReceive(_origin, _guid, _message);
    }

    /**
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded OFT message.
     */
    function _oftReceive(Origin calldata _origin, bytes32 _guid, bytes calldata _message) internal {
        address toAddress = _message.sendTo().bytes32ToAddress();
        uint256 amountReceivedLD = _receiveToken(toAddress, _toLD(_message.amountSD()), _origin.srcEid);
        if (_message.hasMsg()) {
            // @dev Proprietary composeMsg format for the OFT.
            bytes memory composeMsg = OFTComposeMsgCodec.encode(
                _origin.nonce,
                _origin.srcEid,
                amountReceivedLD,
                _message.getMsg()
            );

            // @dev Stores the lzCompose payload that will be executed in a separate tx.
            // Standardizes functionality for executing arbitrary contract invocation on some non-evm chains.
            // @dev The off-chain executor will listen and process the msg based on the src-chain-callers compose options passed.
            // @dev The index is used when a OApp needs to compose multiple msgs on lzReceive.
            // For default OFT implementation there is only 1 compose msg per lzReceive, thus its always 0.
            endpoint.sendCompose(toAddress, _guid, 0 /* the index of the composed message*/, composeMsg);
        }

        emit OFTReceived(_guid, _origin.srcEid, toAddress, amountReceivedLD);
    }

    /**
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded OCC message.
     */
    function _occReceive(Origin calldata _origin, bytes32 _guid, bytes calldata _message) internal {
        // @dev The src sending chain doesnt know the address length on this chain (potentially non-evm)
        // Thus everything is bytes32() encoded in flight.
        address toAddress = _message.sendTo().bytes32ToAddress();
        // @dev Credit the amountLD to the recipient and return the ACTUAL amount the recipient received in local decimals
        uint256 amountReceivedLD = _receiveToken(toAddress, _toLD(_message.amountSD()), _origin.srcEid);

        if (_message.hasMsg()) {
            // @dev Proprietary attachMsg format for the OCC.
            //      For best capability, the attachMsg is encoded/decoded as the same format as the OFT composeMsg
            bytes memory attachMsg = OFTComposeMsgCodec.encode(
                _origin.nonce,
                _origin.srcEid,
                amountReceivedLD,
                _message.getMsg()
            );
            // TODO: What if this call reverted? => lzReceiverAlert() on the endpoint, and orderedNonce pattern will result in
            //       all future messages from the same sender being alerted.
            IOCCManager(occManager).occReceive(attachMsg);
        }

        emit OCCReceived(_guid, _origin.srcEid, toAddress, amountReceivedLD);
    }

    /**
     * @dev Internal function to handle the OAppPreCrimeSimulator simulated receive.
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The LayerZero message.
     * @param _executor The address of the off-chain executor.
     * @param _extraData Arbitrary data passed by the msg executor.
     *
     * @dev Enables the preCrime simulator to mock sending lzReceive() messages,
     * routes the msg down from the OAppPreCrimeSimulator, and back up to the OAppReceiver.
     */
    function _lzReceiveSimulate(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @dev Check if the peer is considered 'trusted' by the OApp.
     * @param _eid The endpoint ID to check.
     * @param _peer The peer to check.
     * @return Whether the peer passed is considered 'trusted' by the OApp.
     *
     * @dev Enables OAppPreCrimeSimulator to check whether a potential Inbound Packet is from a trusted source.
     */
    function isPeer(uint32 _eid, bytes32 _peer) public view virtual override returns (bool) {
        return peers[_eid] == _peer;
    }

    /**
     * @dev Internal function to remove dust from the given local decimal amount.
     * @param _amountLD The amount in local decimals.
     * @return amountLD The amount after removing dust.
     *
     * @dev Prevents the loss of dust when moving amounts between chains with different decimals.
     * @dev eg. uint(123) with a conversion rate of 100 becomes uint(100).
     */
    function _removeDust(uint256 _amountLD) internal view virtual returns (uint256 amountLD) {
        return (_amountLD / decimalConversionRate) * decimalConversionRate;
    }

    /**
     * @dev Internal function to convert an amount from shared decimals into local decimals.
     * @param _amountSD The amount in shared decimals.
     * @return amountLD The amount in local decimals.
     */
    function _toLD(uint256 _amountSD) internal view virtual returns (uint256 amountLD) {
        return _amountSD * decimalConversionRate;
    }

    /**
     * @dev Internal function to convert an amount from local decimals into shared decimals.
     * @param _amountLD The amount in local decimals.
     * @return amountSD The amount in shared decimals.
     */
    function _toSD(uint256 _amountLD) internal view virtual returns (uint256 amountSD) {
        return _amountLD / decimalConversionRate;
    }

    /**
     * @dev Internal function to mock the amount mutation from a OFT debit() operation.
     * @param _amountLD The amount to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @dev _dstEid The destination endpoint ID.
     * @return amountSentLD The amount sent, in local decimals.
     * @return amountReceivedLD The amount to be received on the remote chain, in local decimals.
     *
     * @dev This is where things like fees would be calculated and deducted from the amount to be received on the remote.
     */
    function _debitView(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 /*_dstEid*/
    ) internal view virtual returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        // @dev Remove the dust so nothing is lost on the conversion between chains with different decimals for the token.
        amountSentLD = _removeDust(_amountLD);
        // @dev The amount to send is the same as amount received in the default implementation.
        amountReceivedLD = amountSentLD;

        // @dev Check for slippage.
        if (amountReceivedLD < _minAmountLD) {
            revert SlippageExceeded(amountReceivedLD, _minAmountLD);
        }
    }

    /**
     * @dev Internal function to perform a debit operation.
     * @param _from The address to debit.
     * @param _amountLD The amount to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination endpoint ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     *
     * @dev Defined here but are intended to be overriden depending on the OFT implementation.
     * @dev Depending on OFT implementation the _amountLD could differ from the amountReceivedLD.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual returns (uint256 amountSentLD, uint256 amountReceivedLD);

    /**
     * @dev Internal function to perform a credit operation.
     * @param _to The address to credit.
     * @param _amountLD The amount to credit in local decimals.
     * @param _srcEid The source endpoint ID.
     * @return amountReceivedLD The amount ACTUALLY received in local decimals.
     *
     * @dev Defined here but are intended to be overriden depending on the OFT implementation.
     * @dev Depending on OFT implementation the _amountLD could differ from the amountReceivedLD.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal virtual returns (uint256 amountReceivedLD);

    /**
     * @dev Internal function to check if the receive is valid.
     * @param _reciver The address to receive the tokens.
     * @param _amountLD The amount to receive in local decimals.
     * @return Whether the receive is valid.
     */
    function _checkReceive(address _reciver, uint256 _amountLD) internal pure returns (bool) {
        if (_reciver == address(0) || _amountLD == 0) {
            return false;
        }
        return true;
    }

    function _receiveToken(address _to, uint256 _amountLD, uint32 _srcEid) internal returns (uint256 amountReceivedLD) {
        // @dev Only mint/unlock token if its amount > 0
        if (_checkReceive(_to, _amountLD)) {
            amountReceivedLD = _credit(_to, _amountLD, _srcEid);
        }
    }

    function _sentToken(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        // @dev Only burn/lock token if its amount > 0
        if (_amountLD > 0) {
            (amountSentLD, amountReceivedLD) = _debit(_from, _amountLD, _minAmountLD, _dstEid);
        }
    }

    function setOCCManager(address _addr) public onlyOwner zeroAddressCheck(_addr) {
        occManager = _addr;
    }
    /**
     * @dev Set the flag to enforce ordered nonce or not
     * @param _orderedNonce the flag to enforce ordered nonce or not
     */
    function setOrderedNonce(bool _orderedNonce) public onlyOwner {
        _setOrderedNonce(_orderedNonce);
    }

    /**
     * @dev Get the next nonce for the sender
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     */
    function nextNonce(uint32 _srcEid, bytes32 _sender) public view override returns (uint64) {
        if (orderedNonce) {
            return maxReceivedNonce[_srcEid][_sender] + 1;
        } else {
            return 0;
        }
    }

    /**
     * @dev Clear the inbound nonce to ignore a message
     * @dev this is a PULL mode versus the PUSH mode of lzReceive
     * @param _origin the origin of the message
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid the guid of the message
     * @param _message the message data
     */
    function clearInboundNonce(Origin calldata _origin, bytes32 _guid, bytes calldata _message) public onlyOwner {
        endpoint.clear(address(this), _origin, _guid, _message);
    }

    /**
     * @dev Skip a nonce which is not verified by lz yet, that is:
     *      inboundPayloadHash[_receiver][_srcEid][_sender][_nonce] == EMPTY_PAYLOAD_HASH &&
     *      inboundPayload[_receiver][_srcEid][_sender][_nonce-1] != EMPTY_PAYLOAD
     *      ==> lazyInboundNonce[_receiver][_srcEid][_sender] == _nonce
     * @param _srcEid the eid of the source chain
     * @param _sender the address of the remote sender (oft or adapter)
     * @param _nonce the nonce of the message to skip
     */
    function skipInboundNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) public onlyOwner {
        endpoint.skip(address(this), _srcEid, _sender, _nonce);
    }

    /**
     * @dev Nilify the inbound nonce to mark a message as verified, but disallows execution until it is re-verified.
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     * @param _nonce The nonce of the message to burn
     * @param _payloadHash The hash of the message to burn
     */
    function nilifyInboundNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) public onlyOwner {
        endpoint.nilify(address(this), _srcEid, _sender, _nonce, _payloadHash);
    }

    /**
     * @dev Burn the inbound nonce to mark a message as unexecutable and un-verifiable. The nonce can never be re-verified or executed.
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     * @param _nonce The nonce of the message to burn
     * @param _payloadHash The hash of the message to burn
     */
    function burnInboundNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) public onlyOwner {
        endpoint.burn(address(this), _srcEid, _sender, _nonce, _payloadHash);
    }

    /**
     * @dev Pull the max received nonce from the endpoint
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     */
    function pullMaxReceivedNonce(uint32 _srcEid, bytes32 _sender) public onlyOwner {
        maxReceivedNonce[_srcEid][_sender] = endpoint.lazyInboundNonce(address(this), _srcEid, _sender);
    }

    /**
     * @dev Check and accept the nonce of the inbound message
     * @param _srcEid The eid of the source chain
     * @param _sender The address of the remote sender (oft or adapter)
     * @param _nonce The nonce of the message
     */
    function _acceptNonce(uint32 _srcEid, bytes32 _sender, uint64 _nonce) internal {
        uint64 curNonce = maxReceivedNonce[_srcEid][_sender];
        if (orderedNonce) {
            require(_nonce == curNonce + 1, "OApp: invalid nonce");
        }

        if (_nonce > curNonce) {
            maxReceivedNonce[_srcEid][_sender] = _nonce;
        }
    }

    function _setOrderedNonce(bool _orderedNonce) internal {
        orderedNonce = _orderedNonce;
    }
}
