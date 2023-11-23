// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title DSC Engin
 * @author tauseed zaman
 *
 * the system is designed to be minemalistic and simple as possable and main the price to 1 usd begged
 *
 * @notice this contract is the core of this DSC system, and handle all logic for
 */
contract DSCEngin is ReentrancyGuard {
    // errors
    error DSCEngin_MustBeMoreTheZero();
    error DSCEngin_TokenAddressesAndPriceFeedAddresLengthMustBeSame();
    error DSCEngin_TokenNotAllowed();

    // state variables
    mapping(address token => address priceFeed) private s_priceFeeds; //token to priceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // user to token to amount

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    DecentralizedStableCoin private immutable i_dsc;

    // modifiers
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) revert DSCEngin_MustBeMoreTheZero();
    }

    modifier isAllowedToken(address _tokenAddress) {
        if (s_priceFeeds[_tokenAddress] == address(0)) revert DSCEngin_TokenNotAllowed();
        _;
    }

    // functions
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address dscAddress) {
        // USD price feed allways 1
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngin_TokenAddressesAndPriceFeedAddresLengthMustBeSame();
        }

        // set price feeds
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    // external functions

    function depositCollateralAndMintDsc() external {}

    /**
     * @param tokenCollateralAddress address of the collateral token
     * @param amountToCollateral amount of collateral to deposit
     * @notice this function is used to deposit collateral to mint DSC
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountToCollateral)
        external
        moreThanZero(amountToCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // transfer token to this contract
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountToCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountToCollateral);

        IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountToCollateral);
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function lequidate() external {}

    function getHealthFactor() external {}
}
