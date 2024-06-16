// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

enum Options {
    LZ_RECEIVE,
    STAKE_ORDER,
    UNSTAKE_ORDER,
    STAKE_ESORDER,
    UNSTAKE_ESORDER,
    CLAIM_ORDER,
    CLAIM_ESORDER,
    VEST_ESORDER
}

struct OptionsAirdrop {
    uint128 gas;
    uint128 value;
}

interface IOrderRelayer {
    /* ========== Errors ========== */
    error NotLocalMsgSender(address sender);
    error NotRemoteMsgSender(uint32 eid, address sender);
    error InvalidEnpoint(address expectedEndpoint, address realEndpoint);
    error InvalidOft(address expectedOft, address realOft);

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
