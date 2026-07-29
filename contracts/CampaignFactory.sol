// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CampaignFactory
 * @notice Deploys and tracks CrowdfundingCampaign instances. Each campaign's
 *         funding goal and milestone allocations are denominated in USD
 *         (with 8 decimals, matching Chainlink's ETH/USD feed format), and
 *         converted to ETH at contribution time inside the campaign contract.
 *
 */

import "./CrowdfundingCampaign.sol";

contract CampaignFactory {

    error InvalidPriceFeed();
    error GoalMustBePositive();
    error DurationTooShort(uint256 daysProvided);
    error NoMilestonesProvided();
    error MilestoneLengthMismatch(uint256 descriptions, uint256 percentages);
    error MilestonePercentZero(uint256 milestoneIndex);
    error MilestonePercentNot100(uint256 totalPercent);

    //10_000 = 100% 3000bps = 30% 100bps = 1% express % in points
    /// @notice Basis points denominator. Milestone allocations must sum to this.
    uint16 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Chainlink ETH/USD price feed address used by all campaigns deployed by this factory
    address public immutable priceFeed;

    /// @notice All campaigns ever deployed by this factory, in creation order.
    address[] public campaigns;

    /// @notice Campaigns grouped by the founder who created them.
    mapping(address => address[]) public campaignsByFounder;

    event CampaignCreated(
        address indexed campaignAddress,
        address indexed founder,
        uint256 goalUsd,         // raw input  (e.g. 10000)
        uint256 deadline,        // computed   (block.timestamp + N days)
        uint256 milestoneCount,
        uint256 indexed campaignIndex
    );

    /// @param _priceFeed Address of the Chainlink ETH/USD aggregator this factory's campaigns should use.
    constructor(address _priceFeed) {
        if (_priceFeed == address(0)) revert InvalidPriceFeed();
        priceFeed = _priceFeed;
    }

    /**
     * @notice Create a new crowdfunding campaign.
     * @param goalUsd Total funding goal in whole USD (10000 for $10,000). The contract scales this to 8 decimals internally tomatch Chainlink's ETH/USD feed format.

     * @param durationDays Number of days from now for the fundraising window(e.g. 30 for a 30-day campaign). Must be at least 1. The contract computes the actual Unix deadline internally.

     * @param milestoneDescriptions Ordered, human-readable description for each milestone (e.g. "Prototype complete").

     * @param milestonePercent Ordered whole-number percentage of the goal for each milestone ([30, 50, 20] for 30%/50%/20%). Must be the same length as milestoneDescriptions and sum to exactly 100.

     * @return campaignAddress The address of the newly deployed campaign.
     */
    function createCampaign(
        uint256 goalUsd,
        uint256 durationDays,
        string[] calldata milestoneDescriptions,
        uint16[] calldata milestonePercent)

    external returns (address campaignAddress) {
        if (goalUsd == 0) revert GoalMustBePositive();
        uint256 goalUsd8 = goalUsd * 1e8;

        if (durationDays == 0) revert DurationTooShort(durationDays);
        uint256 deadline = block.timestamp + (durationDays * 1 days);

        if (milestoneDescriptions.length == 0) revert NoMilestonesProvided();
        if (milestoneDescriptions.length != milestonePercent.length)
            revert MilestoneLengthMismatch(milestoneDescriptions.length, milestonePercent.length);

        // Validate percentages and convert to basis points
        uint16[] memory milestoneBps;
        {
            uint256 totalPercent;
            milestoneBps = new uint16[](milestoneDescriptions.length);
            for (uint256 i = 0; i < milestoneDescriptions.length; i++) {
                if (milestonePercent[i] == 0) revert MilestonePercentZero(i);
                totalPercent += milestonePercent[i];
                milestoneBps[i] = milestonePercent[i] * 100;
            }
            if (totalPercent != 100) revert MilestonePercentNot100(totalPercent);
        }

        // Deploy — assign directly to return variable (no extra local)
        campaignAddress = address(new CrowdfundingCampaign(
            msg.sender,
            goalUsd8,
            deadline,
            milestoneDescriptions,
            milestoneBps,
            priceFeed
        ));

        campaigns.push(campaignAddress);
        campaignsByFounder[msg.sender].push(campaignAddress);

        emit CampaignCreated(
            campaignAddress,
            msg.sender,
            goalUsd,
            deadline,
            milestoneDescriptions.length,
            campaigns.length - 1
        );
    }

    /// @notice Total number of campaigns deployed by this factory.
    function getCampaignCount() external view returns (uint256) {
        return campaigns.length;
    }

    /// @notice Returns all campaign addresses deployed by this factory.
    /// @dev For demo and frontend calls only.
    function getAllCampaigns() external view returns (address[] memory) {
        return campaigns;
    }

    /// @notice Returns all campaigns created by a given founder.
    function getCampaignsByFounder(address founder) external view returns (address[] memory) {
        return campaignsByFounder[founder];
    }
}
