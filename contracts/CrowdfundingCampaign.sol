// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrowdfundingCampaign 
 * @notice 
 */
contract CrowdfundingCampaign {
    // errors

    error CampaignEnded();
    error ContributionMustBePositive();

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

    mapping(address => uint) public contributionsWei;
    uint public totalContributedWei;

    // events

    event ContributionReceived(address backer, uint amountWei); 

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

    function contribute() external payable {
        // manipulation of timestamp is insignificant
        if (block.timestamp >= deadline) revert CampaignEnded();
        if (msg.value == 0) revert ContributionMustBePositive();

        contributionsWei[msg.sender] += msg.value;
        totalContributedWei += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }
}
