// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CampaignFactory.sol";

contract CampaignFactoryTest is Test {
    CampaignFactory public factory;

    address public founder;
    address public priceFeed;

    function setUp() public {
        founder = makeAddr("founder");
        priceFeed = makeAddr("priceFeed");

        factory = new CampaignFactory(priceFeed);
    }

    function test_constructorStoresPriceFeed() public view {
        address actualPriceFeed = factory.priceFeed();

        assertEq(actualPriceFeed, priceFeed, "price feed should be stored");
    }

    function test_constructorRevertsForZeroPriceFeed() public {
        address invalidPriceFeed = address(0);

        vm.expectRevert(CampaignFactory.InvalidPriceFeed.selector);
        new CampaignFactory(invalidPriceFeed);
    }

    function test_createCampaignDeploysAndTracksCampaign() public {
        string[] memory descriptions = new string[](2);
        descriptions[0] = "prototype";
        descriptions[1] = "launch";

        uint16[] memory percentages = new uint16[](2);
        percentages[0] = 40;
        percentages[1] = 60;

        vm.prank(founder);

        address campaignAddress = factory.createCampaign(
            10_000,
            30,
            descriptions,
            percentages
        );

        assertGt(campaignAddress.code.length, 0, "campaign should be deployed");
        assertEq(factory.getCampaignCount(), 1, "campaign count should increase");
        assertEq(factory.campaigns(0), campaignAddress, "campaign should be indexed");
        assertEq(
            factory.campaignsByFounder(founder, 0),
            campaignAddress,
            "campaign should be indexed by founder"
        );
    }
}
