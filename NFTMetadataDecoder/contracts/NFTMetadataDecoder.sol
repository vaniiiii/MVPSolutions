//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title NFTMetadataDecoder
/// @dev A contract for decoding color from packed NFT metadata.
contract NFTMetadataDecoder {
    bytes32 public metadata;

    /// @dev Creates new NFTMetadataDecoder contract.
    /// @param metadata_ The packed NFT metadata.
    constructor(bytes32 metadata_) {
        metadata = metadata_;
    }

    /// @dev Extracts the color value from the stored packed NFT metadata.
    /// @return The extracted color decimal value.
    function getColorFromMetadata() external view returns (uint256) {
        assembly {
            // Get's metadata storage slot
            let wholeSlot := sload(metadata.slot)
            // Getting next free memory slot
            let ptr := mload(0x40)
            // Shift metadata right by 160 bits to remove owner
            // Mask the slot to get the value of the variable
            mstore(ptr, and(shr(160, wholeSlot), 0x000000000000000000ffffff))
            return(ptr, 0x20)
        }
    }
}
