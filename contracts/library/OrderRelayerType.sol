// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

library OrderRelayerType {
    struct StakeMsg {
        address staker;
        uint256 amount;
    }

    struct UnstakeMsg {
        address staker;
        uint256 amount;
    }

    struct Msg {
        uint16 msgType;
        bytes32 msgData;
    }

    enum MsgType {
        STAKE,
        UNSTAKE
    }
}
