// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title OrderToken
 * @author Orderly Network
 * @dev OrderToken is the native ERC20 token for the Orderly Network and only deployed on Ethereum.
 *      It is used to incentivize the traders and market markers on Orderly Network.
 */
contract OrderToken is ERC20 {
    /**
     * @dev Constructor for the OrderToken contract.
     * @param _initDistributor The address to which the total supply of ORDER tokens will be minted.
     */
    constructor(address _initDistributor) ERC20("Orderly Network", "ORDER") {
        _mint(_initDistributor, 1_000_000_000 ether);
    }
}
