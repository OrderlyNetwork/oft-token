// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OrderAdapter } from "contracts/OrderAdapter.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract OrderAdapterMock is OrderAdapter {
    function getInnerToken() public view returns (IERC20) {
        return innerToken;
    }

    function removeDust(uint256 _amountLD) public view returns (uint256 amountLD) {
        return _removeDust(_amountLD);
    }
}
