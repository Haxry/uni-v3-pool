import "./FullMath.sol";
import "./SqrtPriceMath.sol";


library SwapMath {
    using FullMath for uint256;
    using SqrtPriceMath for uint160;

    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        uint24 feePips
    ) internal pure returns (uint160 sqrtRatioNextX96, uint256 amountIn,uint256 amountOut,uint256 feeAmount) {

        bool zeroForOne = sqrtRatioCurrentX96 >=sqrtRatioTargetX96;
        bool exactIn = amountRemaining >=0;

        //calculate max amount in or out and next sqrt ratio
        if(exactIn){
            uint amountInRemainingLessFee = FullMath.mulDiv(amountRemaining,1e6-feePips,1e6);
            //calculate max amount in, round up amount in 
            amountIn = zeroForOne? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96,sqrtRatioCurrentX96,liquidity,true):SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96,sqrtRatioTargetX96,liquidity,true);

            //calculate nxt sqrt ratio

            if(amountInRemainingLessFee >= amountIn){
                sqrtRatioNextX96 = sqrtRatioTargetX96;

        } else {
            sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtRatioCurrentX96,liquidity,amountInRemainingLessFee,zeroForOne);
        }

        
    } else {
        //calculate max amount out, round down amount out
        amountOut = zeroForOne? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96,sqrtRatioCurrentX96,liquidity,false):SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96,sqrtRatioTargetX96,liquidity,false);
        //calculate next sqrt ratio
        sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtRatioCurrentX96,liquidity,amountRemaining,zeroForOne);
    }
}
}