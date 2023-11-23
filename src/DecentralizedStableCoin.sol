// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author tauseed zaman
 * Collateralized: Exogenestic (Eth BTC)
 * Minting: Algorethmic
 * Relative Stable: Pegged to USD
 *
 * This is a Stable coin based by DSC Engin, this contract is just ERC20 implementation of a stable coin
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    // errors
    error DecentralizedStableCoin_MustBeMoreTheZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();
    error DecentralizedStableCoin_NotToZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) revert DecentralizedStableCoin_MustBeMoreTheZero();

        if (balance < _amount) {
            revert DecentralizedStableCoin_BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin_NotToZeroAddress();
        }

        if (_amount <= 0) revert DecentralizedStableCoin_MustBeMoreTheZero();

        _mint(_to, _amount);
        return true;
    }
}
