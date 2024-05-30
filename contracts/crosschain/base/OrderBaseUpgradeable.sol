// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title OrderBaseUpgradeable
 * @author Zion
 * @dev The base contract for inheritance with upgradeable setting
 */
abstract contract OrderBaseUpgradeable is UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    function initialize(address _owner) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_owner);
        __Pausable_init();
    }

    /**
     * @param newImplementation The address of deployed implementation
     * @dev Override with onlyOwner modifier to authrize the upgrade prcess
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
