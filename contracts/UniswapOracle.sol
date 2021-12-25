// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6;

import "./UniswapPairTwapOracle.sol";

import "openzeppelin-solidity/contracts/access/Ownable.sol";

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IERC20.sol';


/**
 * @title Price oracle based on Uniswap pairs
 * @author Mimas Finance
 * @notice This price oracle requires a child UniswapPairTwapOracle for each supported
 * asset, which must be paired against WCRO. UniswapOracle also uses a child UniswapPairTwapOracle
 * for the canonical CRO/USD price, to obtain the dollar price of each supported asset.
 */
 contract UniswapOracle is Ownable {
    using SafeMath for uint256;

    mapping(address => UniswapPairTwapOracle) public pairOracles;
    UniswapPairTwapOracle public wcroUsdOracle;

    address public wcroAddress;
    uint8 public usdTokenDecimals;

    uint256 constant public PRICE_FRESHNESS_SECONDS = 30 * 60;     // 30 minutes
    uint256 constant public MIN_WCRO_RESERVES_IN_PAIR = 1_000_000; // 1 million WCROs

    event PairOracleSet(address token, UniswapPairTwapOracle pairOracle);
    event OneUsdOracleSet(UniswapPairTwapOracle wcroUsdOracle, uint8 usdTokenDecimals);

    constructor(address _wcroAddress) public {
      wcroAddress = _wcroAddress;
    }
    
    /**
     * @notice Sets the cononical Uniswap pair oracle for the ONE/USD price
     * @param _wcroUsdOracle The TWAP oracle for the Uniswap pair
     */
    function setWcroUsdOracle(UniswapPairTwapOracle _wcroUsdOracle) external onlyOwner {
      address token0 = _wcroUsdOracle.token0();
      address token1 = _wcroUsdOracle.token1();

      require(token0 == wcroAddress || token1 == wcroAddress, "UniswapOracle::Pair must containe WCRO");

      usdTokenDecimals = token0 == wcroAddress ?
          IERC20(token1).decimals() : IERC20(token0).decimals();

      wcroUsdOracle = _wcroUsdOracle;
      emit OneUsdOracleSet(wcroUsdOracle, usdTokenDecimals);
    }

    /**
     * @notice Adds a new supported asset and its corresponding UniswapPairOracle
     * @param _token The new token to add
     * @param _pairOracle The TWAP oracle for a Uniswap pair, which must be of the form {_token}/WCRO
     */
    function addPairOracle(address _token, UniswapPairTwapOracle _pairOracle) external onlyOwner {
      (address token0, address token1) = UniswapV2Library.sortTokens(_token, wcroAddress);
      require(token0 == _pairOracle.token0() && token1 == _pairOracle.token1(), 
              "UniswapOracle::Token must be paired with WCRO");

      pairOracles[_token] = _pairOracle;
      emit PairOracleSet(_token, _pairOracle);
    }


    /**
     * @notice Checks if the current price is considered "reliable", taking into account the
     * freshness and liquidity of each underlying pair oracle.
     * @param _token The token whose price to query
     * @return True if the price is considered reliable 
     */
    function hasReliablePrice(address _token) external view returns (bool) {
      require(address(wcroUsdOracle) != address(0), "UniswapOracle::WCRO oracle not set");
      
      UniswapPairTwapOracle pairOracle = _token == wcroAddress ? wcroUsdOracle : pairOracles[_token];
      require(address(pairOracle) != address(0), "UniswapOracle::PairOracle not set");

      bool isFresh = now - pairOracle.blockTimestampLast() <= PRICE_FRESHNESS_SECONDS;
      if (!isFresh) {
        return false;
      }

      if (!hasSufficientLiquidity(wcroUsdOracle.pair())) {
        return false;
      }

      if (!hasSufficientLiquidity(pairOracle.pair())) {
        return false;
      }

      return true;
    }

    function hasSufficientLiquidity(IUniswapV2Pair pair) internal view returns (bool) {
        (uint256 reserves0, uint256 reserves1, ) = pair.getReserves();

        uint256 pairWCROReserves = pair.token0() == wcroAddress ? reserves0 : reserves1;
        return pairWCROReserves >= MIN_WCRO_RESERVES_IN_PAIR;
    }

    /**
     * @notice Gets the price of a supported asset in USD
     * @param _token The token whose price to query
     * @return The price of the token in USD. The price is scaled to decimals expected by the Comptroller.
     */
    function getPrice(address _token) external view returns (uint) {
      require(address(wcroUsdOracle) != address(0), "UniswapOracle::WCRO oracle not set");

      UniswapPairTwapOracle pairOracle = _token == wcroAddress ? wcroUsdOracle : pairOracles[_token];
      require(address(pairOracle) != address(0), "UniswapOracle::PairOracle not set");

      uint256 tokenDecimals = IERC20(_token).decimals();
      uint256 onePrice = pairOracle.consult(_token, 10 ** tokenDecimals);
      uint256 usdPrice = _token == wcroAddress ? onePrice : wcroUsdOracle.consult(wcroAddress, onePrice);

      // Comptroller needs prices in the format: ${raw price} * 1e(36 - usdTokenDecimals - tokenDecimals)
      uint256 decimalDelta = 36 - usdTokenDecimals - tokenDecimals;
      uint256 usdPriceMantissa = usdPrice * (10 ** decimalDelta);
      return usdPriceMantissa;
    }
}