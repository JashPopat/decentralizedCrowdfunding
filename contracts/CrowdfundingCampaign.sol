// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrowdfundingCampaign 
 * @notice 
 */

import "./interfaces/AggregatorV3Interface.sol";

contract CrowdfundingCampaign {
    // errors

    error CampaignEnded();
    error ContributionMustBePositive();
    error InvalidOraclePrice();
    error OnlyFounder();
    error CampaignNotFunded();
    error TransferFailed();
    error MilestoneReleased();
    error EmptyProof();
    error InvalidMilestone();
    error AlreadySubmitted();
    error CampaignNotEnded();
    error CampaignWasFunded();
    error NothingToRefund();

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
    mapping(address => uint) public contributionsUsd;
    uint public totalContributedUsd;

    // events

    event ContributionReceived(address indexed backer, uint amountWei, uint amountUsd); 
    event FundsReleased(uint indexed milestoneId, uint amountWei);
    event RefundClaimed(address indexed backer, uint amountWei);
    event MilestoneProofSubmitted(uint milestoneId, string proofHash);

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
        if (hasEnded()) revert CampaignEnded();
        if (msg.value == 0) revert ContributionMustBePositive();

        contributionsWei[msg.sender] += msg.value;
        totalContributedWei += msg.value;

        uint contributionUsd = ethToUsd(msg.value);
        contributionsUsd[msg.sender] += contributionUsd;
        totalContributedUsd += contributionUsd;

        emit ContributionReceived(msg.sender, msg.value, contributionUsd);
    }

    function ethToUsd(uint amountWei) internal view returns (uint) {
        (, int answer, , , ) = AggregatorV3Interface(priceFeed).latestRoundData();

        if (answer <= 0 ) revert InvalidOraclePrice();

        uint price = uint(answer);

        return (amountWei * price) / 1e18;
    }

    function isFunded() public view returns (bool) {
        return totalContributedUsd >= goalUsd;
    }

    function hasEnded() public view returns (bool) {
        // manipulation of timestamp is insignificant - silence warning?
        return block.timestamp >= deadline;
    }

    function releaseInitialFunds() external {
        if (msg.sender != founder) revert OnlyFounder();
        if (!isFunded()) revert CampaignNotFunded();
        if (milestones[0].released) revert MilestoneReleased();

        uint amountWei = (totalContributedWei * milestones[0].bps) / 10_000;
        milestones[0].released = true;

        (bool success, ) = payable(founder).call{value: amountWei}("");
        if (!success) revert TransferFailed();

        emit FundsReleased(0, amountWei);
    }

    function claimRefund() external {
        if (!hasEnded()) revert CampaignNotEnded();
        if (isFunded()) revert CampaignWasFunded();

        uint amountWei = contributionsWei[msg.sender];
        if (amountWei == 0) revert NothingToRefund();
        contributionsWei[msg.sender] = 0;
        uint amountUsd = contributionsUsd[msg.sender];
        contributionsUsd[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amountWei}("");
        if (!success) revert TransferFailed();

        totalContributedWei -= amountWei;
        totalContributedUsd -= amountUsd;

        emit RefundClaimed(msg.sender, amountWei);
    }

    function submitProof(uint milestoneId, string calldata proofHash) external {
        if (!isFunded()) revert CampaignNotFunded();
        if (milestoneId >= milestones.length) revert InvalidMilestone();
        if (bytes(proofHash).length == 0) revert EmptyProof();
        if (msg.sender != founder) revert OnlyFounder();
        if (milestones[milestoneId].submitted) revert AlreadySubmitted();

        milestones[milestoneId].submitted = true;
        milestones[milestoneId].proofHash = proofHash;

        emit MilestoneProofSubmitted(milestoneId, proofHash);
    }
}
