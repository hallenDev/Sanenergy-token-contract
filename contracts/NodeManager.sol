// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/SafeMathUint.sol";
import "./libraries/SafeMathInt.sol";
import "./libraries/IterableMapping.sol";
import "./interfaces/INode.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract NodeManager is Ownable {

    using SafeMath for uint256;

    INode[3] public nodes;

    IUniswapV2Router02 public uniswapV2Router;

    address public uniswapV2Pair;
    address public futurUseWallet = 0x608d522C3b602FB45353f4f227e71124B2Fe3261;
    address public marketingWallet = 0x608d522C3b602FB45353f4f227e71124B2Fe3261;

    uint256 public rewardsFee;
    uint256 public liquidityPoolFee;
    uint256 public futurFee;
    uint256 public totalFees;
    uint256 public maxNodeNumber = 100;

    uint256 public stakedToken = 0;

    uint256 public cashoutFee;

    uint256 private rwSwap;
    bool private swapping = false;
    bool private swapLiquify = true;
    uint256 public swapTokensAmount;

    IERC20 public utilityToken; // SANENERGY SOLUTION TOKEN

    mapping(address => bool) public _isBlacklisted;
    mapping(address => uint256) private _nodeNumber;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor(IERC20 _token, uint256[] memory fees, uint256 swapAmount, address uniV2Router, address uniV2Pair)  {

        require(uniV2Router != address(0), "ROUTER CANNOT BE ZERO");
        require(uniV2Pair != address(0), "PAIR CANNOT BE ZERO");
        require(address(_token) != address(0x0), "TOKEN CANNOT BE ZERO");

        utilityToken = _token;
        uniswapV2Router = IUniswapV2Router02(uniV2Router);
        uniswapV2Pair = uniV2Pair;

        require(fees[0] != 0 && fees[1] != 0 && fees[2] != 0 && fees[3] != 0, "CONSTR: Fees equal 0");
        futurFee = fees[0];
        rewardsFee = fees[1];
        liquidityPoolFee = fees[2];
        cashoutFee = fees[3];
        rwSwap = fees[4];

        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);

        swapTokensAmount = swapAmount;
    }

    receive() external payable {}

    function setNode(address node, uint256 id) external onlyOwner {
        require(id < 3, "SETNODE: invalid node id");
        nodes[id] = INode(node);
    }

    function updateSwapTokensAmount(uint256 newVal) external onlyOwner {
        swapTokensAmount = newVal;
    }

    function updateFuturWallet(address payable wall) external onlyOwner {
        futurUseWallet = wall;
    }

    function updateMarketingWallet(address payable wall) external onlyOwner {
        marketingWallet = wall;
    }

    function updateRewardsFee(uint256 value) external onlyOwner {
        rewardsFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);
    }

    function updateLiquiditFee(uint256 value) external onlyOwner {
        liquidityPoolFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);
    }

    function updateFuturFee(uint256 value) external onlyOwner {
        futurFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);
    }

    function updateCashoutFee(uint256 value) external onlyOwner {
        cashoutFee = value;
    }

    function updateRwSwapFee(uint256 value) external onlyOwner {
        rwSwap = value;
    }

    function blacklistMalicious(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
    }

    function swapAndSendToFee(address destination, uint256 tokens) private {
        uint256 initialETHBalance = address(this).balance;
        swapTokensForEth(tokens);
        uint256 newBalance = (address(this).balance).sub(initialETHBalance);
        if(destination != address(this)) {
            payable(destination).transfer(newBalance);
        }
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(utilityToken);
        path[1] = uniswapV2Router.WETH();

        utilityToken.approve(address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        utilityToken.approve(address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(utilityToken),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function createNodeWithTokens(string memory name, uint256 id) public {

        address sender = _msgSender();
        require(bytes(name).length > 3 && bytes(name).length < 32, "NODE CREATION: NAME SIZE INVALID");
        require(_nodeNumber[sender] < maxNodeNumber, "cannot create node more than maxNodeNumber");
        require(sender != address(0), "NODE CREATION:  creation from the zero address");
        require(!_isBlacklisted[sender], "NODE CREATION: Blacklisted address");
        require(sender != futurUseWallet && sender != marketingWallet, "NODE CREATION: futur and rewardsPool cannot create node");

        uint256 nodePrice = nodes[id].nodePrice();
        require(utilityToken.balanceOf(sender) >= nodePrice, "NODE CREATION: Balance too low for creation.");
        require(utilityToken.allowance(sender, address(this)) >= nodePrice, "NODE CREATION: not approved");
        require(stakedToken <= utilityToken.balanceOf(address(this)), "Insufficient token in reward pool");

        bool swapAmountOk = stakedToken >= swapTokensAmount;
        if (swapAmountOk && swapLiquify && !swapping && sender != owner()) {
            swapping = true;

            uint256 futurTokens = stakedToken.mul(futurFee).div(100);
            swapAndSendToFee(futurUseWallet, futurTokens);

            uint256 rewardsPoolTokens = stakedToken.mul(rewardsFee).div(100);
            uint256 rewardsTokenstoSwap = rewardsPoolTokens.mul(rwSwap).div(100);
            swapAndSendToFee(address(this), rewardsTokenstoSwap);

            uint256 swapTokens = stakedToken.mul(liquidityPoolFee).div(100);
            swapAndLiquify(swapTokens);

            swapAndSendToFee(marketingWallet, stakedToken.sub(futurTokens).sub(rewardsPoolTokens).sub(swapTokens));
            stakedToken = 0;

            swapping = false;
        }

        utilityToken.transferFrom(sender, address(this), nodePrice);
        stakedToken = stakedToken.add(nodePrice);
        nodes[id].createNode(sender, name);
        _nodeNumber[sender] = _nodeNumber[sender].add(1);
    }

    function cashoutAll() public {
        address sender = _msgSender();
        require(sender != address(0), "CASHOUT:  creation from the zero address");
        require(!_isBlacklisted[sender], "CASHOUT: Blacklisted address");
        require(sender != futurUseWallet, "CASHOUT: futur and rewardsPool cannot cashout rewards");

        uint256 rewardAmount = 0;

        for(uint256 id = 0; id < 3; id ++) {
            if(getNodeNumberOf(sender, id) == 0) continue;
            rewardAmount = rewardAmount.add(nodes[id]._getRewardAmountOf(sender));
        }

        require(rewardAmount > 0, "CASHOUT: You don't have enough reward to cash out");
        if (swapLiquify) {
            uint256 feeAmount;
            if (cashoutFee > 0) {
                feeAmount = rewardAmount.mul(cashoutFee).div(100);
                swapAndSendToFee(futurUseWallet, feeAmount);
            }
            rewardAmount -= feeAmount;
        }
        utilityToken.transfer(sender, rewardAmount);
        for(uint256 id = 0; id < 3; id ++) {
            if(getNodeNumberOf(sender, id) == 0) continue;
            nodes[id]._cashoutAllNodesReward(sender);
        }
    }

    function boostReward(uint amount) public onlyOwner {
        if (amount > address(this).balance) amount = address(this).balance;
        payable(owner()).transfer(amount);
    }

    function changeSwapLiquify(bool newVal) public onlyOwner {
        swapLiquify = newVal;
    }

    function getNodeNumberOf(address account, uint256 id) public view returns (uint256) {
        return nodes[id]._getNodeNumberOf(account);
    }

    function getRewardAmountOf(address account, uint256 id) public view returns (uint256) {
        return nodes[id]._getRewardAmountOf(account);
    }

    function getRewardAmount(uint256 id) public view returns (uint256) {
        require(_msgSender() != address(0), "SENDER CAN'T BE ZERO");
        require(nodes[id]._isNodeOwner(_msgSender()),"NO NODE OWNER");
        return nodes[id]._getRewardAmountOf(_msgSender());
    }

    function changeNodePrice(uint256 newNodePrice, uint256 id) public onlyOwner {
        nodes[id]._changeNodePrice(newNodePrice);
    }

    function getNodePrice(uint256 id) public view returns (uint256) {
        return nodes[id].nodePrice();
    }

    function changeRewardPerSec(uint256 newPrice, uint256 id) public onlyOwner {
        nodes[id]._changeRewardPerSecond(newPrice);
    }

    function getRewardPerSec(uint256 id) public view returns (uint256) {
        return nodes[id].rewardPerSec();
    }

    function getTotalCreatedNodes() public view returns (uint256) {
        uint256 res = 0;
        for(uint256 id = 0; id < 3; id ++) {
            res = res.add(nodes[id].totalNodesCreated());
        }
        return res;
    }

    function withdrawOtherToken(IERC20 _token) external onlyOwner {
        require(address(_token) != address(utilityToken), "cannot withdraw utility token");
        _token.transfer(_msgSender(), _token.balanceOf(address(this)));
    }
}