// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6;

import "./UniswapOracle.sol";
import "./FallbackOracle.sol";

import "openzeppelin-solidity/contracts/access/Ownable.sol";


/**
 * @dev Simple interface for a MmToken.
 */
interface MmToken {
    function underlying() external view returns (address);
    function symbol() external view returns (string memory);
}

/**
 * @dev Simple interface for a PriceOracle expected by the Comptroller.
 */
abstract contract PriceOracle {
    bool public constant isPriceOracle = true;

    function getUnderlyingPrice(MmToken mmToken) external view virtual returns (uint);
}

/**
 * @title Top-level price oracle for Mimas Finance
 * @author Mimas Finance
 * @notice This oracle uses two sub-oracles, UniswapOracle and FallbackOracle, to
 * get the price of supported assets. The main price is queried from the UniswapOracle, but 
 * when the price is not reliable, we use the FallbackOracle.
 */
contract MimasPriceOracle is PriceOracle, Ownable {
    UniswapOracle public uniswapOracle;
    FallbackOracle public fallbackOracle;
    address public wcroAddress;

    constructor(UniswapOracle _uniswapOracle, 
                FallbackOracle _fallbackOracle, 
                address _woneAddress) public {
      uniswapOracle = _uniswapOracle;
      fallbackOracle = _fallbackOracle;
      wcroAddress = _woneAddress;
    }

    function setUniswapOracle(UniswapOracle _uniswapOracle) external onlyOwner {
      uniswapOracle = _uniswapOracle;
    }

    function setFallbackOracle(FallbackOracle _fallbackOracle) external onlyOwner {
      fallbackOracle = _fallbackOracle;
    }

    /**
      * @notice Get the underlying price of a mmToken asset
      * @param mmToken The mmToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      */
    function getUnderlyingPrice(MmToken mmToken) external view override returns (uint) {
      // Use WCRO as the underlying token if the market is for CRO.
      address erc20TokenAddress;
      if (compareStrings(mmToken.symbol(), "mmCRO")) {
        erc20TokenAddress = wcroAddress;
      } else {
        erc20TokenAddress = mmToken.underlying();
      }

      if (uniswapOracle.hasReliablePrice(erc20TokenAddress)) {
        return uniswapOracle.getPrice(erc20TokenAddress);
      } else {
        return fallbackOracle.getPrice(erc20TokenAddress);
      }
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}