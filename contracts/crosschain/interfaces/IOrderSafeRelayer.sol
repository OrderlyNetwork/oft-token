// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { MessagingReceipt, OFTReceipt } from "../../layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
struct StakeMsg {
    address staker;
    uint256 amount;
}

interface IOrderSafeRelayer {
    event SendStakeMsg(uint32 orderEid, bytes32 to, bytes stakeMsg);
    function sendStakeMsg(
        address staker,
        uint256 amount
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);
    function relayStakeMsg(
        address staker,
        uint256 amount
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);
    function sendUnstakeMsg(address staker, uint256 amount) external;
    function setOrderSafe(address orderSafe) external;
    function setOrderBoxRelayer(address orderBoxRelayer) external;
    function getStakeFee(address staker, uint256 amount) external view returns (uint256);
    function getRelayStakeFee(address staker, uint256 amount) external view returns (uint256);
    // function getOptions() external view returns (bytes memory);
}
