// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

contract OrderSafe is UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ILayerZeroComposer {

    address public endpoint;

    function initialize(address _owner) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_owner);
        __Pausable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function upgradeFunction() public pure returns (string memory) {
        return "upgradeFunction";
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable override {
        require(msg.sender == endpoint, "OrderSafe: only endpoint can call this function");
        
    }
}
