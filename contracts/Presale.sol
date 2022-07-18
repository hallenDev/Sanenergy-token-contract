// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Presale is Ownable {

    using SafeMath for uint256;

    uint256 public tokenPerbnb = 3300 * 10**9;

    IERC20 public SanToken;

    bool public enabled = false;

    constructor(IERC20 _sanToken) {
        SanToken = _sanToken;
    }

    receive() external payable {}

    function withdrawBNB() external onlyOwner {
        uint256 bnbBalance = address(this).balance;
        payable(owner()).transfer(bnbBalance);
    }

    function buyToken() external payable {

        require(enabled == true, "presale not started");
        uint256 bnbBalance = msg.value;
        require(bnbBalance <= 4 * 10**18, "exceed max buy amount");
        
        uint256 tokenAmount = tokenPerbnb.mul(bnbBalance).div(10**18);
        require(tokenAmount <= SanToken.balanceOf(address(this)), "insufficient token balance. need to deposit more SAN tokens");
        SanToken.transfer(_msgSender(), tokenAmount);
    }

    function startPresale() external onlyOwner {
        require(enabled == false, "already started");
        enabled = true;
    }

    function endPresale() external onlyOwner {
        require(enabled == true, "already ended");
        enabled = false;
    }

    function withdrawToken() external onlyOwner {
        require(enabled == false, "on presale");
        SanToken.transfer(owner(), SanToken.balanceOf(address(this)));
    }

}