// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INode {

    function totalNodesCreated() external view returns (uint256);
    function nodePrice() external view returns (uint256);
    function _isNodeOwner(address account) external view returns (bool);
    function _getRewardAmountOf(address account) external view returns (uint256);
    function _getNodeNumberOf(address account) external view returns (uint256);
    function rewardPerSec() external view returns (uint256);

    function _cashoutAllNodesReward(address account) external returns (uint256);
    function _changeNodePrice(uint256 newNodePrice) external ;
    function createNode(address account, string memory nodeName) external;
    function _changeRewardPerSecond(uint256 newPrice) external;

}