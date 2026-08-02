// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

// https://docs.chain.link/chainlink-local/api-reference/v022/aggregator-v3-interface#latestrounddata

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}