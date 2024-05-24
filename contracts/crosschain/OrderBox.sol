// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { IERC20Metadata, IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OrderBoxStorage } from "./storage/OrderBoxStorage.sol";
import { OrderBaseUpgradeable } from "./base/OrderBaseUpgradeable.sol";
import { IOrderBox } from "./interfaces/IOrderBox.sol";

contract OrderBox is IOrderBox, OrderBaseUpgradeable, OrderBoxStorage {
    function stakeOrder(uint256 _chainId, address _addr, uint256 _amount) public {
        require(msg.sender == boxRelayer, "OrderBox: Only OrderBoxRelayer can call");
        staker[_addr].orderAmount += _amount;
        staker[_addr].blockNumber = block.number;
        emit OrderStaked(_chainId, _addr, _amount);
    }

    /* ========================= Only Owner ========================= */
    function setOrderRelayer(address _orderRelayer) public onlyOwner {
        require(_orderRelayer != address(0), "OrderSafe: invalid order relayer address");
        boxRelayer = _orderRelayer;
        emit OrderRelayerSet(_orderRelayer);
    }

    function setOft(address _oft) public onlyOwner {
        require(_oft != address(0), "OrderBox: zero oft address");
        oft = _oft;
    }
}
