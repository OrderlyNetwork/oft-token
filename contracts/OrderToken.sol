// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OrderToken is ERC20 {
    constructor(address initDistributor) ERC20("Orderly Network", "ORDER") {
        _mint(initDistributor, 1_000_000_000 ether);
    }
}
