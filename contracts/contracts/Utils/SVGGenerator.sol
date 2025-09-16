// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title SVGGenerator
 * @dev External library for generating SVG artwork for TuuKeep Cabinet NFTs
 *
 * This library extracts SVG generation logic to reduce main contract size
 * while maintaining dynamic artwork capabilities.
 */
library SVGGenerator {
    using Strings for uint256;

    /**
     * @dev Generate dynamic SVG for cabinet NFT
     * @param tokenId Cabinet token ID
     * @param name Cabinet name
     * @param isActive Cabinet status
     * @param totalPlays Total number of plays
     * @return SVG string
     */
    function generateCabinetSVG(
        uint256 tokenId,
        string memory name,
        bool isActive,
        uint256 totalPlays
    ) external pure returns (string memory) {
        // Color scheme based on cabinet status
        string memory primaryColor = isActive ? "#4CAF50" : "#9E9E9E";
        string memory accentColor = isActive ? "#81C784" : "#BDBDBD";
        string memory statusText = isActive ? "ACTIVE" : "INACTIVE";

        return string(abi.encodePacked(
            '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
            '<defs>',
            '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:', primaryColor, ';stop-opacity:1" />',
            '<stop offset="100%" style="stop-color:', accentColor, ';stop-opacity:1" />',
            '</linearGradient>',
            '</defs>',
            '<rect width="400" height="400" fill="url(#bg)"/>',
            '<rect x="50" y="80" width="300" height="240" fill="#2C2C2C" rx="20"/>',
            '<rect x="70" y="100" width="260" height="120" fill="#1A1A1A" rx="10"/>',
            '<circle cx="200" cy="160" r="30" fill="', primaryColor, '"/>',
            '<text x="200" y="280" text-anchor="middle" fill="white" font-family="Arial" font-size="16" font-weight="bold">',
            _truncateString(name, 20),
            '</text>',
            '<text x="200" y="300" text-anchor="middle" fill="#CCCCCC" font-family="Arial" font-size="12">',
            'Cabinet #', tokenId.toString(),
            '</text>',
            '<text x="200" y="320" text-anchor="middle" fill="#CCCCCC" font-family="Arial" font-size="10">',
            statusText,
            '</text>',
            '<text x="200" y="350" text-anchor="middle" fill="#CCCCCC" font-family="Arial" font-size="10">',
            'Plays: ', totalPlays.toString(),
            '</text>',
            '</svg>'
        ));
    }

    /**
     * @dev Truncate string to maximum length
     * @param str Input string
     * @param maxLength Maximum length
     * @return Truncated string
     */
    function _truncateString(string memory str, uint256 maxLength)
        internal
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);
        if (strBytes.length <= maxLength) {
            return str;
        }

        bytes memory truncated = new bytes(maxLength);
        for (uint256 i = 0; i < maxLength; i++) {
            truncated[i] = strBytes[i];
        }

        return string(truncated);
    }
}