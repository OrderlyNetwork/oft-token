// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/DoubleEndedQueue.sol)
pragma solidity ^0.8.20;

import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

/**
 * @dev A sequence of items with the ability to efficiently push and pop items (i.e. insert and remove) on both ends of
 * the sequence (called front and back). Among other access patterns, it can be used to implement efficient LIFO and
 * FIFO queues. Storage use is optimized, and all operations are O(1) constant time. This includes {clear}, given that
 * the existing queue contents are left in storage.
 *
 * The struct is called `Bytes32Deque`. Other types can be cast to and from `bytes32`. This data structure can only be
 * used in storage, and not in memory.
 * ```solidity
 * DoubleEndedQueue.Bytes32Deque queue;
 * ```
 */
library PacketQueue {
    function insert(DoubleEndedQueue.Bytes32Deque storage deque, bytes32 value, uint256 index) internal {
        unchecked {
            if (index >= DoubleEndedQueue.length(deque)) revert DoubleEndedQueue.QueueOutOfBounds();
            uint128 frontIndex = deque._begin - 1;
            if (frontIndex == deque._end) revert DoubleEndedQueue.QueueFull();
            deque._begin = frontIndex;
            if (index == 0) {
                deque._data[frontIndex] = value;
            } else {
                for (uint128 i = 0; i < uint128(index); i++) {
                    deque._data[frontIndex + i] = deque._data[frontIndex + i + 1];
                }
                deque._data[frontIndex + uint128(index)] = value;
            }
        }
    }

    function remove(DoubleEndedQueue.Bytes32Deque storage deque, uint256 index) internal returns (bytes32 value) {
        unchecked {
            if (index >= DoubleEndedQueue.length(deque)) revert DoubleEndedQueue.QueueOutOfBounds();
            uint128 backIndex = deque._end;
            if (backIndex == deque._begin) revert DoubleEndedQueue.QueueEmpty();
            value = deque._data[deque._begin + uint128(index)];
            for (uint128 i = 0; i < DoubleEndedQueue.length(deque) - index - 1; i++) {
                deque._data[deque._begin + uint128(index) + i] = deque._data[deque._begin + uint128(index) + i + 1];
            }
            deque._end--;
        }
    }
}
