// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITuuKeepCabinetGame
 * @dev Interface for TuuKeepCabinetGame contract
 */
interface ITuuKeepCabinetGame {
    // Events
    event GachaPlayed(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 amount,
        uint256 tuuCoinUsed,
        uint256 prizeIndex,
        bool won
    );

    event PrizeWon(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 indexed itemIndex,
        address contractAddress,
        uint256 tokenIdOrAmount
    );

    event TuuCoinMinted(
        uint256 indexed cabinetId,
        address indexed player,
        uint256 amount
    );

    event RevenueDistributed(
        uint256 indexed cabinetId,
        uint256 ownerAmount,
        uint256 platformAmount,
        uint256 totalAmount
    );

    // Game Functions
    function play(uint256 cabinetId, uint256 tuuCoinAmount) external payable;

    // Revenue Functions
    function withdrawCabinetRevenue(uint256 cabinetId) external;
    function withdrawPlatformRevenue(uint256 amount) external;
    function batchWithdrawRevenue(uint256[] calldata cabinetIds) external;

    // Analytics
    function getCabinetRevenue(uint256 cabinetId) external view returns (uint256);
    function getPlatformRevenue() external view returns (uint256);
    function getCabinetAnalytics(uint256 cabinetId) external view returns (
        uint256 totalPlays,
        uint256 totalRevenue,
        uint256 averagePlayValue,
        uint256 lastPlayTime,
        uint256 itemCount,
        uint256 activeItemCount
    );
    function getRevenueForecast(uint256 cabinetId, uint256 daysToForecast) external view returns (uint256 projectedRevenue);
}