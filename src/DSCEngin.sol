// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
\src\\AggregatorV3Interface.sol
 * 
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
    error DSCEngin_TransferFailed();
    error DSCEngin_BreaksHealthFactor(uint256 userHealthFactor);
    error DSCEngin_MintFailed();

    // state variables

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LEQUIDATION_THRESHOLD = 50; // mean 200% collerateralized
    uint256 private constant LEQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1; // mean 100% collerateralized

    mapping(address token => address priceFeed) private s_priceFeeds; //token to priceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // user to token to amount
    mapping(address user => uint256 amountDscMinted) private s_DSCMineted;
    address[] private s_collateralTokens;

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    DecentralizedStableCoin private immutable i_dsc;

    // modifiers
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) revert DSCEngin_MustBeMoreTheZero();
        _;
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
            s_collateralTokens.push(_tokenAddresses[i]);
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

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountToCollateral);
        if (!success) revert DSCEngin_TransferFailed();
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /**
     *
     * @notice follow CEI standard
     * @param amountOfDscToMint amount of DSC to mint
     * @notice this function is used to mint DSC
     */
    function mintDsc(uint256 amountOfDscToMint) external moreThanZero(amountOfDscToMint) nonReentrant {
        s_DSCMineted[msg.sender] += amountOfDscToMint;

        // if minted too much then revert

        _revertIfHeathFactorIsBroken(msg.sender);

        // mint the DSC
        bool mint = i_dsc.mint(msg.sender, amountOfDscToMint);
        if(!mint) revert DSCEngin_MintFailed();
    }

    function burnDsc() external {}

    function lequidate() external {}

    function getHealthFactor() external {}

    // private and internal view functions

    /**
     * @param user address of the user
     * @return totalDscMinted total DSC minted by the user
     * @return totalCollateralValueInUsd total collateral value in USD
     * @notice this function is used to get account information
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        totalDscMinted = s_DSCMineted[user];
        totalCollateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @param user address of the user
     * @return health factor of the user
     * @notice this function is used to show how close a user is to lequidation,
     * if less then 1 you are about to lequidate
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral deposited
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);
        uint256 CollateralAdjustedValueForTheshold =
            (totalCollateralValueInUsd * LEQUIDATION_THRESHOLD) / LEQUIDATION_PRECISION;
        return (CollateralAdjustedValueForTheshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHeathFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) revert DSCEngin_BreaksHealthFactor(userHealthFactor);
    }

    // private external functions

    function getAccountCollateralValue(address user) private view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += amount * getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION)* amount) / PRECISION;
    }
}
