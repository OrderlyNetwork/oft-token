// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library OCCMsgCodec {
    // Offset constants for encoding and decoding OCC or OFT messages
    // Layout: 2 + 32 + 8 + composeMsg/occMsg
    // +---+-----------+-------+---------------+
    // |   |           |       |               |
    // | 2 |    32     |   8   |      msg      |
    // |   |           |       |               |
    // +---+-----------+-------+---------------+
    uint8 private constant MSG_TYPE_OFFSET = 2;
    uint8 private constant SEND_TO_OFFSET = 34;
    uint8 private constant SEND_AMOUNT_SD_OFFSET = 42;

    enum MSG_TYPE {
        OFT_MSG,
        OCC_MSG
    }

    /**
     * @dev Encodes an OFT LayerZero message.
     * @param _sendTo The recipient address.
     * @param _amountShared The amount in shared decimals.
     * @param _composeMsg The composed message.
     * @return _msg The encoded message.
     * @return hasCompose A boolean indicating whether the message has a composed payload.
     */
    function encodeOFTMsg(
        bytes32 _sendTo,
        uint64 _amountShared,
        bytes memory _composeMsg
    ) internal view returns (bytes memory _msg, bool hasCompose) {
        hasCompose = _composeMsg.length > 0;
        // @dev Remote chains will want to know the composed function caller ie. msg.sender on the src.
        _msg = hasCompose
            ? abi.encodePacked(
                uint16(MSG_TYPE.OFT_MSG),
                _sendTo,
                _amountShared,
                addressToBytes32(msg.sender),
                _composeMsg
            )
            : abi.encodePacked(uint16(MSG_TYPE.OFT_MSG), _sendTo, _amountShared);
    }

    /**
     * @dev Encodes an OCC message.
     * @param _sendTo The recipient address.
     * @param _amountShared The amount in shared decimals.
     * @param _occMsg The OCC message.
     * @return _msg The encoded OCC message.
     */
    function encodeOCCMsg(
        bytes32 _sendTo,
        uint64 _amountShared,
        bytes memory _occMsg
    ) internal view returns (bytes memory _msg) {
        // @dev Remote chains will want to know the caller ie. msg.sender on the src.
        _msg = abi.encodePacked(
            uint16(MSG_TYPE.OCC_MSG),
            _sendTo,
            _amountShared,
            addressToBytes32(msg.sender),
            _occMsg
        );
    }

    /**
     * @dev Get the message type
     * @param _msg The OFT/OCC message.
     * @return A uint16 indicating the message type.
     * @dev 0: OFT_MSG, 1: OCC_MSG
     */
    function getType(bytes calldata _msg) internal pure returns (uint16) {
        return uint16(bytes2(_msg[:MSG_TYPE_OFFSET]));
    }

    /**
     * @dev Checks if the OFT/OCC message is attached.
     * @param _msg The OFT/OCC message.
     * @return A boolean indicating whether the message is attached.
     */
    function hasMsg(bytes calldata _msg) internal pure returns (bool) {
        return _msg.length > SEND_AMOUNT_SD_OFFSET;
    }

    /**
     * @dev Retrieves the recipient address from the message.
     * @param _msg The message.
     * @return The recipient address.
     */
    function sendTo(bytes calldata _msg) internal pure returns (bytes32) {
        return bytes32(_msg[MSG_TYPE_OFFSET:SEND_TO_OFFSET]);
    }

    /**
     * @dev Retrieves the amount in shared decimals from the message.
     * @param _msg The message.
     * @return The amount in shared decimals.
     */
    function amountSD(bytes calldata _msg) internal pure returns (uint64) {
        return uint64(bytes8(_msg[SEND_TO_OFFSET:SEND_AMOUNT_SD_OFFSET]));
    }

    /**
     * @dev Retrieves the message from the OFT/OCC message.
     * @param _msg The OFT/OCC message.
     * @return The message payload.
     */
    function getMsg(bytes calldata _msg) internal pure returns (bytes memory) {
        return _msg[SEND_AMOUNT_SD_OFFSET:];
    }

    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /**
     * @dev Converts bytes32 to an address.
     * @param _b The bytes32 value to convert.
     * @return The address representation of bytes32.
     */
    function bytes32ToAddress(bytes32 _b) internal pure returns (address) {
        return address(uint160(uint256(_b)));
    }
}
