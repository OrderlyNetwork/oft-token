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
    // /**
    //  * @dev Constructor to initialize the OApp with the provided endpoint and owner.
    //  * @param _endpoint The address of the LOCAL LayerZero endpoint.
    //  * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
    //  */
    // constructor(address _endpoint, address _delegate) OAppCore(_endpoint, _delegate) {}

    /**
     * @dev Initializer for the upgradeable OApp with the provided endpoint and owner.
     * @param _endpoint The address of the LOCAL LayerZero endpoint.
     * @param _delegate The address of the owner of the OApp.
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
