// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CampaignFactory.sol";
import "../contracts/CrowdfundingCampaign.sol";
import "../contracts/mocks/MockEthUsdPriceFeed.sol";

contract CrowdfundingCampaignTest is Test {
    int256 public constant ETH_USD = 3000e8;
    uint256 public constant GOAL_USD = 3000;
    uint256 public constant DURATION_DAYS = 30;

    // 0.65 + 0.45 ether clears the goal at $3000/ETH after the 2% exchange markup
    // (raw $3300, credited $3234 vs a $3000 goal), keeping alice:bob at the same 3:2 ratio.
    uint256 public constant ALICE_WEI = 0.65 ether;
    uint256 public constant BOB_WEI = 0.45 ether;

    MockEthUsdPriceFeed public priceFeed;
    CampaignFactory public factory;
    CrowdfundingCampaign public campaign;

    address public founder;
    address public alice;
    address public bob;
    address public carol;

    function setUp() public {
        founder = makeAddr("founder");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        priceFeed = new MockEthUsdPriceFeed(ETH_USD);
        factory = new CampaignFactory(address(priceFeed));

        string[] memory descriptions = new string[](2);
        descriptions[0] = "prototype";
        descriptions[1] = "launch";

        uint16[] memory percentages = new uint16[](2);
        percentages[0] = 40;
        percentages[1] = 60;

        vm.prank(founder);
        campaign = CrowdfundingCampaign(
            factory.createCampaign(GOAL_USD, DURATION_DAYS, descriptions, percentages)
        );
    }

    function fundToGoal() internal {
        vm.prank(alice);
        campaign.contribute{value: ALICE_WEI}();

        vm.prank(bob);
        campaign.contribute{value: BOB_WEI}();
    }

    function submitProofFor(uint milestoneId) internal {
        vm.prank(founder);
        campaign.submitProof(milestoneId, "ipfs://proof");
    }

    // contributions

    function test_contributeRecordsWeiAndUsd() public {
        vm.prank(alice);
        campaign.contribute{value: ALICE_WEI}();

        assertEq(campaign.contributionsWei(alice), ALICE_WEI, "wei should be tracked");
        assertEq(campaign.contributionsUsd(alice), 1911e8, "usd should be tracked at feed rate after markup");
        assertEq(campaign.totalContributedWei(), ALICE_WEI, "total wei should be tracked");
        assertEq(campaign.totalContributedUsd(), 1911e8, "total usd should be tracked after markup");
    }

    function test_contributeRevertsOnZeroValue() public {
        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.ContributionMustBePositive.selector);
        campaign.contribute{value: 0}();
    }

    function test_contributeRevertsAfterDeadline() public {
        vm.warp(block.timestamp + DURATION_DAYS * 1 days);

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.CampaignEnded.selector);
        campaign.contribute{value: ALICE_WEI}();
    }

    function test_contributeRevertsOnNonPositivePrice() public {
        priceFeed.setAnswer(0);

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.InvalidOraclePrice.selector);
        campaign.contribute{value: ALICE_WEI}();
    }

    function test_priceRiseReachesGoalWithLessEth() public {
        priceFeed.setAnswer(6000e8);

        vm.prank(alice);
        campaign.contribute{value: 0.52 ether}();

        assertTrue(campaign.isFunded(), "half the eth should reach the goal at double the price");
    }

    function test_isFundedOnceGoalIsMet() public {
        assertFalse(campaign.isFunded(), "should not be funded before contributions");

        fundToGoal();

        assertTrue(campaign.isFunded(), "should be funded once the goal is met");
    }

    // refunds

    function test_claimRefundReturnsEthWhenGoalMissed() public {
        vm.prank(alice);
        campaign.contribute{value: ALICE_WEI}();

        vm.warp(block.timestamp + DURATION_DAYS * 1 days);

        uint balanceBefore = alice.balance;
        vm.prank(alice);
        campaign.claimRefund();

        assertEq(alice.balance, balanceBefore + ALICE_WEI, "backer should get their eth back");
        assertEq(campaign.contributionsWei(alice), 0, "contribution should be cleared");
        assertEq(campaign.totalContributedWei(), 0, "total should be reduced");
    }

    function test_claimRefundRevertsBeforeDeadline() public {
        vm.prank(alice);
        campaign.contribute{value: ALICE_WEI}();

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.CampaignNotEnded.selector);
        campaign.claimRefund();
    }

    function test_claimRefundRevertsWhenGoalWasMet() public {
        fundToGoal();
        vm.warp(block.timestamp + DURATION_DAYS * 1 days);

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.CampaignWasFunded.selector);
        campaign.claimRefund();
    }

    function test_claimRefundRevertsWithNothingToRefund() public {
        vm.prank(alice);
        campaign.contribute{value: ALICE_WEI}();

        vm.warp(block.timestamp + DURATION_DAYS * 1 days);

        vm.prank(carol);
        vm.expectRevert(CrowdfundingCampaign.NothingToRefund.selector);
        campaign.claimRefund();
    }

    // proofs

    function test_submitProofStoresHash() public {
        fundToGoal();
        submitProofFor(1);

        (, , string memory proofHash, bool submitted, , , , ) = campaign.milestones(1);
        assertEq(proofHash, "ipfs://proof", "proof hash should be stored");
        assertTrue(submitted, "milestone should be marked submitted");
    }

    function test_submitProofRevertsForNonFounder() public {
        fundToGoal();

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.OnlyFounder.selector);
        campaign.submitProof(1, "ipfs://proof");
    }

    // voting

    function test_voteApprovesMilestoneOnWeightedMajority() public {
        fundToGoal();
        submitProofFor(1);

        // alice holds 1911 of 3234 usd (credited, after markup), past half on her own
        vm.prank(alice);
        campaign.voteOnMilestone(1);

        (, , , , bool approved, , , ) = campaign.milestones(1);
        assertTrue(approved, "milestone should be approved");
        assertEq(campaign.votesForUsd(1), 1911e8, "support weight should be the usd contribution");
    }

    function test_voteBelowMajorityDoesNotApprove() public {
        fundToGoal();
        submitProofFor(1);

        // bob holds 1323 of 3234 usd (credited, after markup), short of half
        vm.prank(bob);
        campaign.voteOnMilestone(1);

        (, , , , bool approved, , , ) = campaign.milestones(1);
        assertFalse(approved, "milestone should not be approved on a minority stake");
    }

    function test_voteRevertsForNonBacker() public {
        fundToGoal();
        submitProofFor(1);

        vm.prank(carol);
        vm.expectRevert(CrowdfundingCampaign.NotABacker.selector);
        campaign.voteOnMilestone(1);
    }

    function test_voteRevertsOnSecondVote() public {
        fundToGoal();
        submitProofFor(1);

        vm.prank(bob);
        campaign.voteOnMilestone(1);

        vm.prank(bob);
        vm.expectRevert(CrowdfundingCampaign.AlreadyVoted.selector);
        campaign.voteOnMilestone(1);
    }

    function test_voteRevertsBeforeProofSubmitted() public {
        fundToGoal();

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.ProofNotSubmitted.selector);
        campaign.voteOnMilestone(1);
    }

    function test_voteRevertsForUnknownMilestone() public {
        fundToGoal();

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.InvalidMilestone.selector);
        campaign.voteOnMilestone(2);
    }

    // releases

    function test_releaseInitialFundsPaysFirstMilestone() public {
        fundToGoal();

        uint balanceBefore = founder.balance;
        vm.prank(founder);
        campaign.releaseInitialFunds();

        // milestone 0 is 40% of 1 ether
        assertEq(founder.balance, balanceBefore + 0.44 ether, "founder should receive the first share");
    }

    function test_releaseMilestonePaysFounderAfterApproval() public {
        fundToGoal();
        submitProofFor(1);

        vm.prank(alice);
        campaign.voteOnMilestone(1);

        uint balanceBefore = founder.balance;
        vm.prank(founder);
        campaign.releaseMilestone(1);

        // milestone 1 is 60% of 1 ether
        assertEq(founder.balance, balanceBefore + 0.66 ether, "founder should receive the approved share");

        (, , , , , bool released, , ) = campaign.milestones(1);
        assertTrue(released, "milestone should be marked released");
    }

    function test_releaseMilestoneRevertsWithoutApproval() public {
        fundToGoal();
        submitProofFor(1);

        vm.prank(founder);
        vm.expectRevert(CrowdfundingCampaign.MilestoneNotApproved.selector);
        campaign.releaseMilestone(1);
    }

    function test_releaseMilestoneRevertsForNonFounder() public {
        fundToGoal();
        submitProofFor(1);

        vm.prank(alice);
        campaign.voteOnMilestone(1);

        vm.prank(alice);
        vm.expectRevert(CrowdfundingCampaign.OnlyFounder.selector);
        campaign.releaseMilestone(1);
    }

    function test_releaseMilestoneRevertsOnSecondRelease() public {
        fundToGoal();
        submitProofFor(1);

        vm.prank(alice);
        campaign.voteOnMilestone(1);

        vm.prank(founder);
        campaign.releaseMilestone(1);

        vm.prank(founder);
        vm.expectRevert(CrowdfundingCampaign.MilestoneReleased.selector);
        campaign.releaseMilestone(1);
    }
}
