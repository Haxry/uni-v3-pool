// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./lib/SafeCast.sol";
import "./interfaces/IERC20.sol";
import "./lib/TickMath.sol";
import "./lib/SqrtPriceMath.sol";

contract Pool{
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    uint128 public immutable maxLiquidityPerTick;

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
       
        bool unlocked;
    }

    Slot0 public slot0;
    uint128 public liquidity;
    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    modifier lock(){
        require(slot0.unlocked, "Pool: LOCKED");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    constructor(address _token0, address _token1, uint24 _fee, int24 _tickSpacing){
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;

        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= TickMath.MIN_TICK, 'TLM');
        require(tickUpper <= TickMath.MAX_TICK, 'TUM');
    }

    function initialize(uint160 sqrtPriceX96) external {
        //check that it is called only once 
        require(slot0.sqrtPriceX96 == 0, "Pool: already initialized");
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        slot0 = Slot0(sqrtPriceX96, tick, true);
    }

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthInside0X128 = 0;
        uint256 _feeGrowthInside1X128 = 0;

        bool flippedLower;
        bool flippedUpper;
        if(liquidityDelta != 0){
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthInside0X128,
                _feeGrowthInside1X128,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthInside0X128,
                _feeGrowthInside1X128,
                true,
                maxLiquidityPerTick
            );
        }

        position.update(liquidityDelta, _feeGrowthInside0X128, _feeGrowthInside1X128);
        if (flippedLower) {
            ticks.clear(tickLower);
        }
        if (flippedUpper) {
            ticks.clear(tickUpper);
        }
    
    }

    function _modifyPosition(ModifyPositionParams memory params) private returns (Position.Info storage position,int256 amount0,int256 amount1) 
    {
        checkTicks(params.tickLower, params.tickUpper);
        Slot0 memory _slot0 = slot0;
        position = _updatePosition(
            params.owner,
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            _slot0.tick
        );

        if(params.liquidityDelta !=0){
            if(_slot0.tick < params.tickLower){

                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                
        } else if (_slot0.tick < params.tickUpper) {
  
            amount0 = SqrtPriceMath.getAmount0Delta(
                _slot0.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(params.tickUpper),
                params.liquidityDelta
            );
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.tickLower),
                _slot0.sqrtPriceX96,
                params.liquidityDelta
            );
            
            liquidity = params.liquidityDelta<0 ? liquidity - uint128(-params.liquidityDelta) : liquidity + uint128(params.liquidityDelta);
            
        } else {
            amount1 = SqrtPriceMath.getAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.tickLower),
                TickMath.getSqrtRatioAtTick(params.tickUpper),
                params.liquidityDelta
            );
        }
        }

        
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external lock returns (uint256 amount0,uint256 amount1){
        require(amount > 0, "Pool: amount is zero");
        (,int256 amount0Int,int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender,address(this), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender,address(this), amount1);
        }
    }


}