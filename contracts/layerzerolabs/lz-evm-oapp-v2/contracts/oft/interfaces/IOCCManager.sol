// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/**
 * @title ILayerZeroComposer
 */
interface IOCCManager {
    /**
     * @notice Send a message to the OCCManager.
     * @param _message The message payload in bytes, should be encoded/decoded using OFTComposeMsgCodec.
     */
    function occReceive(bytes calldata _message) external payable;
}
