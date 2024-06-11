// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// @dev Import the 'MessagingFee' and 'MessagingReceipt' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppSenderUpgradeable, MessagingFee, MessagingReceipt } from "./OAppSenderUpgradeable.sol";
// @dev Import the 'Origin' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppReceiverUpgradeable, Origin } from "./OAppReceiverUpgradeable.sol";
import { OAppCoreUpgradeable } from "./OAppCoreUpgradeable.sol";

/**
 * @title OApp
 * @dev Abstract contract serving as the base for OApp implementation, combining OAppSender and OAppReceiver functionality.
 */
abstract contract OAppUpgradeable is
    UUPSUpgradeable,
    PausableUpgradeable,
    OAppSenderUpgradeable,
    OAppReceiverUpgradeable
{
    /* ============================ Storage Slots + __gap == 50 ============================ */
    // @dev The gap to prevent storage collisions
    // @dev https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    // @dev New storage should be added below this line, and no exceeding 50 slots
    uint256[50] private __gap;

    /**
     * @dev Initializer for the upgradeable OApp with the provided endpoint and delegate(owner).
     * @param _endpoint The address of the LayerZero endpoint on LOCAL network.
     * @param _delegate The delegate address for the OApp on the endpoint.
     */
    function __initializeOApp(address _endpoint, address _delegate) internal virtual onlyInitializing {
        __initializeOAppCore(_endpoint, _delegate);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __Ownable_init(_delegate);
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

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol implementation.
     * @return receiverVersion The version of the OAppReceiver.sol implementation.
     */
    function oAppVersion()
        public
        pure
        virtual
        override(OAppSenderUpgradeable, OAppReceiverUpgradeable)
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }
}
