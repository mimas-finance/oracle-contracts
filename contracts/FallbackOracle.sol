// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import '@uniswap/v2-periphery/contracts/libraries/SafeMath.sol';

/**
 * @title A fallback price oracle based on externally posted prices
 * @author Mimas Finance
 * @notice This price oracle is used as a last resort to get the price of
 * an asset, which are simply posted periodically by a trusted party.
 */
contract FallbackOracle is Ownable {
    using SafeMath for uint256;

    struct PostedPrice {
      uint256 timestamp;
      uint256 price;
    }

    mapping(address => PostedPrice) public postedPrices;

    event PricePosted(address token, uint previousPriceMantissa, uint newPriceMantissa);

    constructor() public {
    }
    
    /**
     * @notice Posts the new price of an asset
     * @param _token The token whose price to post
     * @param _newPrice The new price to post, scaled to decimals expected by the Comptroller.
     */
    function postPrice(address _token, uint256 _newPrice) external onlyOwner {
      emit PricePosted(_token, postedPrices[_token].price, _newPrice);

      PostedPrice memory postedPrice = postedPrices[_token];
      postedPrice.timestamp = now;
      postedPrice.price = _newPrice;
      
      postedPrices[_token] = postedPrice;
    }

    /**
     * @notice Gets the price of a supported asset in USD
     * @param _token The token whose price to query
     * @return The price of the token in USD. The price is scaled to decimals expected by the Comptroller.
     */
    function getPrice(address _token) external view returns (uint256) {
      PostedPrice memory postedPrice = postedPrices[_token];
      return postedPrice.price;
    }
}