// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "../interfaces/AggregatorV3Interface.sol";

// local price feed mock for anvil and forge tests, answer carries 8 decimals
contract MockEthUsdPriceFeed is AggregatorV3Interface {
    int256 public answer;
    uint256 public updatedAt;
    uint80 public roundId;

    constructor(int256 _answer) {
        setAnswer(_answer);
    }

    function setAnswer(int256 _answer) public {
        answer = _answer;
        updatedAt = block.timestamp;
        roundId += 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}
