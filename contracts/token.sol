// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
 
// Your token contract
contract Token is Ownable, ERC20 {
    string private constant _symbol = 'LOOM';
    string private constant _name = 'Heirloom';
    bool private can_mint = true;
    
    constructor() ERC20(_name, _symbol) {}

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    // Function mint: Create more of your tokens.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the onlyOwner modifier!
    function mint(uint amount) 
        public 
        onlyOwner
    {
        require(can_mint, "Minting has been disabled.");
        _mint(msg.sender, amount);
    }

    function disable_mint()
        public
        onlyOwner
    {
        can_mint = false;
    }
}