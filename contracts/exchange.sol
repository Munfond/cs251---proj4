// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "";

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // Liquidity pool shares
    mapping(address => uint) private lps;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    // For use with exchange rates
    uint private multiplier = 10 ** 5;

    uint private ten_to_eighteen = 10 ** 18;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");
        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10 ** 5;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    function calcDeltaToken(uint delta_eth) private view returns (uint) {
        uint delta = (token.balanceOf(address(this)) * delta_eth) /
            (address(this).balance);
        return delta;
    }

    /* ========================= Liquidity Provider Functions =========================  */
    //y is token and x is eth
    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        require(msg.value > 0, "Must provide positive value");
        uint delta_token = calcDeltaToken(msg.value);

        uint token_balance = token.balanceOf(msg.sender);
        require(
            token_balance >= delta_token,
            "LP does does not have enough of token to add the inputted amount of liquidity."
        );
 
        uint exchange_rate = (token_reserves * multiplier * ten_to_eighteen) /
            eth_reserves;
        require(
            min_exchange_rate < exchange_rate &&
                min_exchange_rate < max_exchange_rate,
            "Failed due to slippage"
        );

        uint lp_shares = (msg.value * total_shares) / (eth_reserves);
        total_shares += lp_shares;

        lps[msg.sender] += lp_shares;

        eth_reserves += msg.value;
        token_reserves += delta_token;
        k = eth_reserves * token_reserves;


        token.transferFrom(msg.sender, address(this), delta_token);
    }


    function removeLiquidity(
        uint amountETH,
        uint max_exchange_rate,
        uint min_exchange_rate
    ) public payable {
        require(
            amountETH <= eth_reserves - 1,
            "Cannot remove more liquidity than is in the pool"
        );
        uint delta_token = calcDeltaToken(amountETH);
        uint lp_shares = (amountETH * total_shares) / eth_reserves;
        total_shares -= lp_shares;
        require(
            lps[msg.sender] >= lp_shares,
            "LP does not have enough shares to remove the inputted amount of liquidity."
        );

        uint exchange_rate = (token_reserves * multiplier * ten_to_eighteen) /
            eth_reserves;
        require(
            min_exchange_rate < exchange_rate &&
                min_exchange_rate < max_exchange_rate,
            "Failed due to slippage"
        );

        uint diff_eth = address(this).balance - eth_reserves;
        uint diff_token = token.balanceOf(address(this)) - token_reserves;
        uint entitled_eth = (diff_eth * lp_shares) / total_shares;
        uint entitled_token = (diff_token * lp_shares) / total_shares;

        lps[msg.sender] -= lp_shares;

        eth_reserves -= amountETH;
        token_reserves -= delta_token;
        k = eth_reserves * token_reserves;

        token.transfer(msg.sender, delta_token + entitled_token);
        payable(msg.sender).transfer(amountETH + entitled_eth);
    }

    function removeAllLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        uint caller_shares = lps[msg.sender];
        uint caller_eth = (caller_shares * eth_reserves) / total_shares;
        removeLiquidity(caller_eth, max_exchange_rate, min_exchange_rate);
    }

    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(
        uint amountTokens,
        uint max_exchange_rate
    ) external payable {

        uint callerSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= callerSupply,
            "Caller does not have enough tokens to make swap"
        );
        
        uint fee_adjusted_amountTokens = amountTokens -
            (amountTokens * swap_fee_numerator) /
            swap_fee_denominator;
        uint new_token_reserves = token_reserves + fee_adjusted_amountTokens;
        uint new_eth_reserves = k / new_token_reserves;

        uint amountEth = eth_reserves - new_eth_reserves;


        require(
            (token_reserves * multiplier * ten_to_eighteen) / eth_reserves <
                max_exchange_rate,
            "Failed due to slippage"
        );

        require(
            amountEth <= (eth_reserves - 1),
            "Swap failed due to prevention of Eth supply dipping below 1"
        );

        eth_reserves = new_eth_reserves;
        token_reserves = new_token_reserves;


        payable(msg.sender).transfer(amountEth);

        token.transferFrom(msg.sender, address(this), amountTokens);
    }


    function swapETHForTokens(uint max_exchange_rate) external payable {
        uint fee_adjusted_amountEth = msg.value -
            (msg.value * swap_fee_numerator) /
            swap_fee_denominator;

        uint new_eth_reserves = eth_reserves + fee_adjusted_amountEth;
        uint new_token_reserves = k / new_eth_reserves;
        uint amountToken = token_reserves - new_token_reserves;


        require(
            (eth_reserves * multiplier) / (token_reserves * ten_to_eighteen) <
                max_exchange_rate,
            "Failed due to slippage"
        );

        require(
            amountToken <= (token_reserves - 1),
            "Swap failed due to prevention of Token supply dipping below 1"
        );

        eth_reserves = new_eth_reserves;
        token_reserves = new_token_reserves;

        bool worked = token.transfer(msg.sender, amountToken);
        require(worked, "Token transfer failed");
    }
}
