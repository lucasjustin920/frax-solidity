// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../Math/SafeMath.sol";



library FraxPoolLibrary {
    using SafeMath for uint256;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // ================ Structs ================
    // Needed to lower stack size
    struct MintFF_Params {
        uint256 mint_fee; 
        uint256 fxs_price_usd; 
        uint256 frax_price_usd; 
        uint256 col_price_usd;
        uint256 fxs_amount;
        uint256 collateral_amount;
        uint256 collateral_token_balance;
        uint256 pool_ceiling;
        uint256 col_ratio;
    }

    struct BuybackFXS_Params {
        uint256 buyback_fee;
        uint256 excess_collateral_dollar_value_d18;
        uint256 fxs_price_usd;
        uint256 col_price_usd;
        uint256 FXS_amount;
    }

    // ================ Functions ================

    function calcMint1t1FRAX(uint256 col_price, uint256 frax_price, uint256 mint_fee, uint256 collateral_amount_d18) public pure returns (uint256) {
        uint256 col_price_usd = col_price;
        uint256 c_dollar_value_d18 = (collateral_amount_d18.mul(col_price_usd)).div(1e6);
        return c_dollar_value_d18.sub((c_dollar_value_d18.mul(mint_fee)).div(1e6));
        //return collateral_amount_d18.mul(1000000-mint_fee).mul(col_price_usd).div(1e12);
    }

    function calcMintAlgorithmicFRAX(uint256 mint_fee, uint256 fxs_price_usd, uint256 fxs_amount_d18) public pure returns (uint256) {
        uint256 fxs_dollar_value_d18 = fxs_amount_d18.mul(fxs_price_usd).div(1e6);
        return fxs_dollar_value_d18.sub((fxs_dollar_value_d18.mul(mint_fee)).div(1e6));
    }

    // Must be internal because of the struct
    function calcMintFractionalFRAX(MintFF_Params memory params) internal pure returns (uint256, uint256) {
        // Since solidity truncates division, every division operation must be the last operation in the equation to ensure minimum error
        // The contract must check the proper ratio was sent to mint FRAX. We do this by seeing the minimum mintable FRAX based on each amount 
        uint256 fxs_needed;
        //uint256 collateral_needed;
        uint256 fxs_dollar_value_d18;
        uint256 c_dollar_value_d18;
        
        // Scoping for stack concerns
        {    
            // USD amounts of the collateral and the FXS
            fxs_dollar_value_d18 = params.fxs_amount.mul(params.fxs_price_usd).div(1e6);
            c_dollar_value_d18 = params.collateral_amount.mul(params.col_price_usd).div(1e6);

            // Recalculate and round down
            // collateral_needed = c_dollar_value_d18.mul(1e6).div(params.col_price_usd); //not needed
        }
        //require(params.collateral_token_balance + params.collateral_amount < params.pool_ceiling, "Pool ceiling reached, no more FRAX can be minted with this collateral");
        
        uint calculated_fxs_dollar_value_d18 = 
                    (c_dollar_value_d18.mul(1e6).div(params.col_ratio))
                    .sub(c_dollar_value_d18);

        uint calculated_fxs_needed = calculated_fxs_dollar_value_d18.mul(1e6).div(params.fxs_price_usd);

        return (
            (c_dollar_value_d18 + calculated_fxs_dollar_value_d18).sub(((c_dollar_value_d18 + calculated_fxs_dollar_value_d18).mul(params.mint_fee)).div(1e6)),
            calculated_fxs_needed
        );
    }

    function calcRedeem1t1FRAX(uint256 col_price_usd, uint256 FRAX_amount, uint256 redemption_fee) public pure returns (uint256) {
        //uint256 frax_dollar_value_d18 = FRAX_amount.mul(1e6).div(frax_price_usd);
        uint256 collateral_needed_d18 = FRAX_amount.mul(1e6).div(col_price_usd);
        return collateral_needed_d18.sub((collateral_needed_d18.mul(redemption_fee)).div(1e6));
        //return (FRAX_amount.mul(1000000-redemption_fee).div(1e6)); // returns FRAX_amount worth of collateral in USD, minus redemption fee
    }

    // Must be internal because of the struct
    function calcBuyBackFXS(BuybackFXS_Params memory params) internal pure returns (uint256) {
        // If the total collateral value is higher than the amount required at the current collateral ratio then buy back up to the possible FXS with the desired collateral
        require(params.excess_collateral_dollar_value_d18 > 0, "No excess collateral to buy back!");

        // Make sure not to take more than is available
        uint256 fxs_dollar_value_d18 = params.FXS_amount.mul(params.fxs_price_usd).div(1e6);
        require(fxs_dollar_value_d18 <= params.excess_collateral_dollar_value_d18, "You are trying to buy back more than the excess!");

        // Get the equivalent amount of collateral based on the market value of FXS provided 
        uint256 collateral_equivalent_d18 = fxs_dollar_value_d18.mul(1e6).div(params.col_price_usd);
        //collateral_equivalent_d18 = collateral_equivalent_d18.sub((collateral_equivalent_d18.mul(params.buyback_fee)).div(1e6));

        return (
            collateral_equivalent_d18
        );

    }


    // Returns value of collateral that must increase to reach recollateralization target (if 0 means no recollateralization)
    function recollateralizeAmount(uint256 total_supply, uint256 global_collateral_ratio, uint256 global_collat_value) public pure returns (uint256 recollateralization_left) {
        uint256 target_collat_value = total_supply.mul(global_collateral_ratio).div(1e18); // We want 6 degrees of precision so divide by 1e18; total_supply is 1e18 and global_collateral_ratio is 1e6
        // Subtract the current value of collateral from the target value needed, if higher than 0 then system needs to recollateralize
        uint256 recollateralization_left = target_collat_value.sub(global_collat_value); // If recollateralization is not needed, throws a subtraction underflow
        return(recollateralization_left);
    }

}
