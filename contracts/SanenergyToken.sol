// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract SanenergyToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 10**10 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Sanenergy Solution";
    string private _symbol = "SAN";
    uint8 private _decimals = 9;
    
    uint256 public _reflectionFee = 2;
    uint256 private _previousReflectionFee = _reflectionFee;
    
    uint256 public _liquidityFee = 4;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _charityFee = 2;
    uint256 private _previousCharityFee = _charityFee;

    uint256 public _devFee = 2;
    uint256 private _previousDevFee = _devFee;

    uint256 public _totalFee = 10;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 private numTokensSellToAddToLiquidity = 500 * 10**9;

    address private charityAddress;
    address private devAddress;

    struct FeeValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tCharity;
        uint256 tDev;
    }

    struct tFeeValues {
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tCharity;
        uint256 tDev;
    }
    
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor (address _charity, address _dev) {
        _rOwned[_msgSender()] = _rTotal;
        
        // for mainnet
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // for testnet
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);

         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        charityAddress = _charity;
        devAddress = _dev;
        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            FeeValues memory _values = _getValues(tAmount);
            return _values.rAmount;
        } else {
            FeeValues memory _values = _getValues(tAmount);
            return _values.rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        FeeValues memory _values = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(_values.tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);        
        _takeLiquidity(_values.tLiquidity);
        _reflectFee(_values.rFee, _values.tFee);
        _takeCharity(_values.tCharity);
        _takeDev(_values.tDev);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    
    function setReflectionFeePercent(uint256 reflectionFee) external onlyOwner {
        require(_totalFee.sub(_reflectionFee).add(reflectionFee) <= 10, "exceed tax 10% in total");
        _reflectionFee = reflectionFee;
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        require(_totalFee.sub(_liquidityFee).add(liquidityFee) <= 10, "exceed tax 10% in total");
        _liquidityFee = liquidityFee;
    }

    function setCharityFeePercent(uint256 charityFee) external onlyOwner {
        require(_totalFee.sub(_charityFee).add(charityFee) <= 10, "exceed tax 10% in total");
        _charityFee = charityFee;
    }

    function setDevFeePercent(uint256 devFee) external onlyOwner {
        require(_totalFee.sub(_devFee).add(devFee) <= 10, "exceed tax 10% in total");
        _devFee = devFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setCharityAddress(address _charityAddress) external onlyOwner {
        charityAddress = _charityAddress;
    }

    function setDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (FeeValues memory) {
        tFeeValues memory tValues = _getTValues(tAmount);
        uint256 tOther = tValues.tLiquidity.add(tValues.tCharity).add(tValues.tDev);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tValues.tFee, tOther, _getRate());
        return FeeValues(rAmount, rTransferAmount, rFee, tValues.tTransferAmount, tValues.tFee, tValues.tLiquidity, tValues.tCharity, tValues.tDev);
    }

    function _getTValues(uint256 tAmount) private view returns (tFeeValues memory) {

        tFeeValues memory tValues = tFeeValues(
            0,
            calculateReflectionFee(tAmount),
            calculateLiquidityFee(tAmount),
            calculateCharityFee(tAmount),
            calculateDevFee(tAmount)
        );
        tValues.tTransferAmount = tAmount.sub(tValues.tFee).sub(tValues.tLiquidity).sub(tValues.tCharity).sub(tValues.tDev);
        return tValues;
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tOther, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rOther = tOther.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rOther);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _takeCharity(uint256 tCharity) private {
        uint256 currentRate =  _getRate();
        uint256 rCharity = tCharity.mul(currentRate);
        _rOwned[charityAddress] = _rOwned[charityAddress].add(rCharity);
        if(_isExcluded[charityAddress]) {
            _tOwned[charityAddress] = _tOwned[charityAddress].add(tCharity);
        }
    }

    function _takeDev(uint256 tDev) private {
        uint256 currentRate =  _getRate();
        uint256 rDev = tDev.mul(currentRate);
        _rOwned[devAddress] = _rOwned[devAddress].add(rDev);
        if(_isExcluded[devAddress]) {
            _tOwned[devAddress] = _tOwned[devAddress].add(tDev);
        }
    }
    
    function calculateReflectionFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_reflectionFee).div(
            10**2
        );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }

    function calculateCharityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_charityFee).div(
            10**2
        );
    }

    function calculateDevFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_devFee).div(
            10**2
        );
    }
    
    function removeAllFee() private {
        if(_reflectionFee == 0 && _liquidityFee == 0 && _charityFee == 0 && _devFee == 0) return;
        
        _previousReflectionFee = _reflectionFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCharityFee = _charityFee;
        _previousDevFee = _devFee;
        
        _reflectionFee = 0;
        _liquidityFee = 0;
        _charityFee = 0;
        _devFee = 0;
    }
    
    function restoreAllFee() private {
        _reflectionFee = _previousReflectionFee;
        _liquidityFee = _previousLiquidityFee;
        _charityFee = _previousCharityFee;
        _devFee = _previousDevFee;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        // if not buy/sell action, remove the fee
        if(from != uniswapV2Pair && to != uniswapV2Pair) {
            takeFee = false;
        }
        
        //transfer amount, it will take reflectionFee, liquidity fee, charity fee, dev fee
        _tokenTransfer(from,to,amount,takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
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
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee) {
            removeAllFee();
        }
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        
        if(!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        FeeValues memory _values = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);
        _takeLiquidity(_values.tLiquidity);
        _reflectFee(_values.rFee, _values.tFee);
        _takeCharity(_values.tCharity);
        _takeDev(_values.tDev);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        FeeValues memory _values = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(_values.tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);           
        _takeLiquidity(_values.tLiquidity);
        _reflectFee(_values.rFee, _values.tFee);
        _takeCharity(_values.tCharity);
        _takeDev(_values.tDev);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        FeeValues memory _values = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(_values.rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(_values.rTransferAmount);
        _takeLiquidity(_values.tLiquidity);
        _reflectFee(_values.rFee, _values.tFee);
        _takeCharity(_values.tCharity);
        _takeDev(_values.tDev);
        emit Transfer(sender, recipient, _values.tTransferAmount);
    }
}