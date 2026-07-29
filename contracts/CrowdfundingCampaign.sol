// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrowdfundingCampaign 
 * @notice 
 */
contract CrowdfundingCampaign {
    // errors

    // constants

    // structs

    struct Milestone {
        string description;
        uint16 bps;
        string proofHash;
        bool submitted;
        bool approved;
        bool released;

    }

    // state vars

    Milestone[] public milestones;
    address public founder;
    uint256 public goalUsd;
    uint256 public deadline;
    address public priceFeed;

    // events


    constructor(
        address _founder,
        uint256 _goalUsd,
        uint256 _deadline,
        string[] memory _milestoneDescriptions,
        uint16[] memory _milestoneBps,
        address _priceFeed
    ) {
        founder = _founder;
        goalUsd = _goalUsd;
        deadline = _deadline;
        priceFeed = _priceFeed;

        for (uint i = 0; i < _milestoneDescriptions.length; i++) {
            milestones.push(Milestone({
                description: _milestoneDescriptions[i],
                proofHash: "",
                bps: _milestoneBps[i],
                submitted: false,
                approved: false,
                released: false
            }));
        }
    }

    function getMilestoneCount() external view returns (uint) {
        return milestones.length;
    }
}
