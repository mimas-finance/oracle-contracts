// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import '@uniswap/v2-periphery/contracts/libraries/SafeMath.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IERC20.sol';

import "./UniswapPairTwapOracle.sol";

/**
 * @title Updates all supported pair oracles with rewards
 * @author Mimas Finance
 * @notice This contract gives an economic incentive to keep the Uniswap TWAP
 * oracles up to date. Anyone is able to update the oracles, and in turn collect
 * the accumulated rewards up to that point. 
 */
contract OracleUpdater is Ownable {
    using SafeMath for uint256;

    struct OracleInfo {
      UniswapPairTwapOracle oracle;
      bool enabled;
    }

    UniswapPairTwapOracle[] public oracles;
    IERC20 public rewardToken;
    uint256 public rewardsPerBlock;
    uint256 public lastBlockNumber;
    uint256 public lastBlockTimestamp;

    constructor() public {}

    /**
     * @notice Adds a supported pair oracle
     * @param _oracle The oracle to add
     */
    function addOracle(UniswapPairTwapOracle _oracle) external onlyOwner {
      oracles.push(_oracle);
    }

    /**
     * @notice Sets the reward for updating the oracles
     * @param _rewardToken The reward token to distribute
     * @param _rewardsPerBlock The amount of reward tokens per block
     */
    function setReward(IERC20 _rewardToken, uint256 _rewardsPerBlock) public onlyOwner {
      rewardToken = _rewardToken;
      rewardsPerBlock = _rewardsPerBlock;
      lastBlockNumber = block.number;
      lastBlockTimestamp = block.timestamp;
    }

    /**
     * @notice Updates all the supported oracles and receive the accumulated rewards.
     */
    function updateOracles() external {
      for (uint256 i = 0; i < oracles.length; ++i) {
        UniswapPairTwapOracle oracle = oracles[i];
        oracle.update();
      }

      distributeReward();
    }

    /**
     * @return The number of supported oracles.
     */
    function oracleCount() external view returns (uint256) {
      return oracles.length;
    }

    /**
     * @return The currently accumulated and unclaimed rewards.
     */
    function accumulatedRewards() public view returns (uint256) {
      uint256 blocksElapsed = block.number - lastBlockNumber;
      return SafeMath.mul(blocksElapsed, rewardsPerBlock);
    }
    
    function distributeReward() internal {
      uint256 rewards = accumulatedRewards();
      lastBlockNumber = block.number;
      lastBlockTimestamp = block.timestamp;

      if (rewards > rewardToken.balanceOf(address(this))) {
        return;
      }

      rewardToken.transferFrom(address(this), msg.sender, rewards);
    }
}