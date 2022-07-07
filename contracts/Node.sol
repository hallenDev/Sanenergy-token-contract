// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/IterableMapping.sol";

contract Node is Ownable {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    struct NodeEntity {
        string name;
        uint256 creationTime;
        uint256 lastClaimTime;
    }

    IterableMapping.Map private nodeOwners;
    mapping(address => NodeEntity[]) private _nodesOfUser;

    uint256 public nodePrice;
    uint256 public rewardPerSec;

    address public nodeManager;

    uint256 public totalNodesCreated = 0;

    constructor(uint256 _nodePrice, uint256 _rewardPerSec) {
        nodePrice = _nodePrice;
        rewardPerSec = _rewardPerSec;
    }

    modifier onlySentry() {
        require(_msgSender() == nodeManager || _msgSender() == owner(), "Fuck off");
        _;
    }

    function setNodeManager(address nodeManager_) external onlySentry {
        nodeManager = nodeManager_;
    }

    function createNode(address account, string memory nodeName) external onlySentry {
        require(isNameAvailable(account, nodeName), "CREATE NODE: Name not available");
        _nodesOfUser[account].push(
            NodeEntity({
                name: nodeName,
                creationTime: block.timestamp,
                lastClaimTime: block.timestamp
            })
        );
        nodeOwners.set(account, _nodesOfUser[account].length);
        totalNodesCreated++;
    }

    function isNameAvailable(address account, string memory nodeName) public view returns (bool) {
        NodeEntity[] memory nodes = _nodesOfUser[account];
        for (uint256 i = 0; i < nodes.length; i++) {
            if (keccak256(bytes(nodes[i].name)) == keccak256(bytes(nodeName))) {
                return false;
            }
        }
        return true;
    }

    function _burn(uint256 index) internal {
        require(index < nodeOwners.size());
        nodeOwners.remove(nodeOwners.getKeyAtIndex(index));
    }

    function _getNodeWithCreatime(NodeEntity[] memory nodes, uint256 _creationTime) public view returns (NodeEntity memory) {
        uint256 numberOfNodes = nodes.length;
        require(numberOfNodes > 0, "CASHOUT ERROR: You don't have nodes to cash-out");
        bool found = false;
        int256 index = binary_search(nodes, 0, numberOfNodes, _creationTime);
        uint256 validIndex;
        if (index >= 0) {
            found = true;
            validIndex = uint256(index);
        }
        require(found, "NODE SEARCH: No NODE Found with this blocktime");
        return nodes[validIndex];
    }

    function binary_search(
        NodeEntity[] memory arr,
        uint256 low,
        uint256 high,
        uint256 x
    ) private view returns (int256) {
        if (high >= low) {
            uint256 mid = (high + low).div(2);
            if (arr[mid].creationTime == x) {
                return int256(mid);
            } else if (arr[mid].creationTime > x) {
                return binary_search(arr, low, mid - 1, x);
            } else {
                return binary_search(arr, mid + 1, high, x);
            }
        } else {
            return -1;
        }
    }

    function _cashoutAllNodesReward(address account) external onlySentry view returns (uint256) {
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        require(nodesCount > 0, "NODE: CREATIME must be higher than zero");
        NodeEntity memory _node;
        uint256 rewardsTotal = 0;
        for (uint256 i = 0; i < nodesCount; i++) {
            _node = nodes[i];
            rewardsTotal = rewardsTotal.add(
                (block.timestamp.sub(_node.lastClaimTime)).mul(rewardPerSec)
            );
            nodes[i].lastClaimTime = block.timestamp;
        }
        return rewardsTotal;
    }

    function _cashoutNodeReward(address account, uint256 _creationTime) view public returns (uint256) {
        require(_creationTime > 0, "NODE: CREATIME must be higher than zero");
        NodeEntity[] storage nodes = _nodesOfUser[account];
        uint256 numberOfNodes = nodes.length;
        require(
            numberOfNodes > 0,
            "CASHOUT ERROR: You don't have nodes to cash-out"
        );
        NodeEntity memory node = _getNodeWithCreatime(nodes, _creationTime);
        uint256 rewardNode = (block.timestamp.sub(node.lastClaimTime)).mul(rewardPerSec);
        node.lastClaimTime = block.timestamp;
        return rewardNode;
    }

    function _getRewardAmountOf(address account) public view returns (uint256) {
        require(isNodeOwner(account), "GET REWARD OF: NO NODE OWNER");
        uint256 nodesCount;
        uint256 rewardCount = 0;

        NodeEntity[] storage nodes = _nodesOfUser[account];
        nodesCount = nodes.length;

        for (uint256 i = 0; i < nodesCount; i++) {
            rewardCount = rewardCount.add(
                (block.timestamp.sub(nodes[i].lastClaimTime)).mul(rewardPerSec)
            );
        }

        return rewardCount;
    }

    function _getRewardAmountOf(address account, uint256 _creationTime) public view returns (uint256) {
        require(isNodeOwner(account), "GET REWARD OF: NO NODE OWNER");

        require(_creationTime > 0, "NODE: CREATIME must be higher than zero");
        NodeEntity[] storage nodes = _nodesOfUser[account];
        uint256 numberOfNodes = nodes.length;
        require(numberOfNodes > 0, "CASHOUT ERROR: You don't have nodes to cash-out");
        NodeEntity memory node = _getNodeWithCreatime(nodes, _creationTime);
        uint256 rewardNode = (block.timestamp.sub(node.lastClaimTime)).mul(rewardPerSec);
        return rewardNode;
    }

    function _getNodesNames(address account) public view returns (string memory) {
        require(isNodeOwner(account), "GET NAMES: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;
        string memory names = nodes[0].name;
        string memory separator = "#";
        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];
            names = string(abi.encodePacked(names, separator, _node.name));
        }
        return names;
    }

    function _getNodesCreationTime(address account) public view returns (string memory) {
        require(isNodeOwner(account), "GET CREATIME: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;
        string memory _creationTimes = uint2str(nodes[0].creationTime);
        string memory separator = "#";

        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];

            _creationTimes = string(
                abi.encodePacked(
                    _creationTimes,
                    separator,
                    uint2str(_node.creationTime)
                )
            );
        }
        return _creationTimes;
    }

    function _getNodesRewardAvailable(address account) public view returns (string memory) {
        require(isNodeOwner(account), "GET REWARD: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;
        uint256 reward = (block.timestamp - nodes[0].lastClaimTime) * rewardPerSec;
        string memory _rewardsAvailable = uint2str(reward);
        string memory separator = "#";

        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];
            reward = (block.timestamp.sub(_node.lastClaimTime)).mul(
                rewardPerSec
            );
            _rewardsAvailable = string(
                abi.encodePacked(_rewardsAvailable, separator, uint2str(reward))
            );
        }
        return _rewardsAvailable;
    }

    function _getNodesLastClaimTime(address account) public view returns (string memory) {
        require(isNodeOwner(account), "LAST CLAIME TIME: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;
        string memory _lastClaimTimes = uint2str(nodes[0].lastClaimTime);
        string memory separator = "#";

        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];

            _lastClaimTimes = string(
                abi.encodePacked(
                    _lastClaimTimes,
                    separator,
                    uint2str(_node.lastClaimTime)
                )
            );
        }
        return _lastClaimTimes;
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function _changeNodePrice(uint256 newNodePrice) external onlySentry {
        nodePrice = newNodePrice;
    }

    function _changeRewardPerSec(uint256 newPrice) external onlySentry {
        rewardPerSec = newPrice;
    }

    function _getNodeNumberOf(address account) public view returns (uint256) {
        return nodeOwners.get(account);
    }

    function isNodeOwner(address account) private view returns (bool) {
        return nodeOwners.get(account) > 0;
    }

    function _isNodeOwner(address account) public view returns (bool) {
        return isNodeOwner(account);
    }
}
