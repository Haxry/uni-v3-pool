// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library Tick {
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        return uint128(1000000000000) / uint128(tickSpacing);
    }
}