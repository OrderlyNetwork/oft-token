// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IOrderRelayer {
    /* ========== Errors ========== */
    error NotComposeMsgSender(address sender);

    /* ========== Events ========== */
    event ComposeMsgSenderSet(address indexed composeMsgSender, bool allowed);
    event EndpointSet(address indexed endpoint);
    event OftSet(address indexed oft);
    event EidSet(uint256 indexed chainId, uint32 eid);

    /* ========== Functions ========== */
    function setLocalComposeMsgSender(address _composeMsgSender, bool _allowed) external;
    function setRemoteComposeMsgSender(uint32 _eid, address _composeMsgSender, bool _allowed) external;
    function setEndpoint(address _endpoint) external;
    function setOft(address _oft) external;
    function setEid(uint256 _chainId, uint32 _eid) external;
}
