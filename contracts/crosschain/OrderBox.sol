// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { OrderBase } from "../base/OrderBase.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OrderBoxStorage } from "../storage/OrderBoxStorage.sol";
import { IOrderBox } from "../interfaces/IOrderBox.sol";

contract OrderBox is IOrderBox, OrderBase, OrderBoxStorage {
    function stakeOrder(uint256 _chainId, address _staker, uint256 _amount) public {
        require(msg.sender == boxRelayer, "OrderBox: Only OrderBoxRelayer can call");
        stakers[_staker].orderAmount += _amount;
        stakers[_staker].blockNumber = block.number;
        emit OrderStaked(_chainId, _staker, _amount);
    }
}
