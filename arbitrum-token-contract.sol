// SPDX-License-Identifier: MIT
// Arbitrum example contract with marketing address. Ready to launch your own tokens, simply change lines 117, 122, 123, 141.
pragma solidity ^0.8.5;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Ownable {
    address internal owner;
    constructor(address _owner) {
        owner = _owner;
    }
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }
    function renounceOwnership() public onlyOwner {
        owner = address(0);
        emit OwnershipTransferred(address(0));
    }  
    event OwnershipTransferred(address owner);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract EtherStellar is ERC20, Ownable {
    using SafeMath for uint256;
    address routerAdress = 0x252fd9C54323240Cc1129beD11a1fE891fEb9be6;
    address DEAD = 0x000000000000000000000000000000000000dEaD;

    string constant _name = "EtherStellar";
    string constant _symbol = "ETHST";
    uint8 constant _decimals = 9;

    uint256 public _totalSupply = 70000000000 * (10 ** _decimals);
    uint256 public _maxWalletAmount = (_totalSupply * 80) / 100;
    uint256 public _maxTxAmount = _totalSupply.mul(90).div(100); //90%

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isTxLimitExempt;

    uint256 liquidityFee = 3; 
    uint256 marketingFee = 5;
    uint256 totalFee = liquidityFee + marketingFee;
    uint256 feeDenominator = 1000;

    address public marketingFeeReceiver = 0x3ff6c3BbDD88336837b36517B264679CC5a133a1;

    IDEXRouter public router;
    address public pair;

    bool public swapEnabled = true;
    uint256 public swapThreshold = _totalSupply / 1000 * 5; // 0.5%
    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor () Ownable(msg.sender) {
        router = IDEXRouter(routerAdress);
        pair = IDEXFactory(router.factory()).createPair(router.WETH(), address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;

        address _owner = owner;
        isFeeExempt[0x252fd9C54323240Cc1129beD11a1fE891fEb9be6] = true;
        isTxLimitExempt[_owner] = true;
        isTxLimitExempt[0x252fd9C54323240Cc1129beD11a1fE891fEb9be6] = true;
        isTxLimitExempt[DEAD] = true;

        _balances[_owner] = _totalSupply;
        emit Transfer(address(0), _owner, _totalSupply);
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if(inSwap){ return _basicTransfer(sender, recipient, amount); }
        
        if (recipient != pair && recipient != DEAD) {
            require(isTxLimitExempt[recipient] || _balances[recipient] + amount <= _maxWalletAmount, "Transfer amount exceeds the bag size.");
        }
        
        if(shouldSwapBack()){ swapBack(); } 

        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        uint256 amountReceived = shouldTakeFee(sender) ? takeFee(sender, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }
    
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldTakeFee(address sender) internal view returns (bool) {
        return !isFeeExempt[sender];
    }

    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount.mul(totalFee).div(feeDenominator);
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);
        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    /**
 * @dev Swaps tokens held by the contract for ETH, distributes marketing fees,
 *      and adds liquidity to the DEX pool.
 */
function swapBack() internal swapping {
    uint256 contractTokenBalance = swapThreshold;
    uint256 amountToLiquify;
    uint256 amountToSwap;
    unchecked {
        (amountToLiquify, amountToSwap) = calculateSwapAmounts(contractTokenBalance);
    }

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = router.WETH();

    uint256 amountETH = swapTokensForETH(amountToSwap, path);

    uint256 totalETHFee = totalFee - (liquidityFee / 2);
    uint256 amountETHLiquidity;
    uint256 amountETHMarketing;
    unchecked {
        (amountETHLiquidity, amountETHMarketing) = calculateETHAmounts(amountETH, totalETHFee);
    }

    transferMarketingFees(amountETHMarketing);

    if (amountToLiquify > 0) {
        addLiquidity(amountETHLiquidity, amountToLiquify);
    }
}

/**
 * @dev Calculates the amounts of tokens to be swapped and liquified.
 * @param contractTokenBalance The total token balance of the contract.
 * @return amountToLiquify The amount of tokens to be used for liquidity.
 * @return amountToSwap The amount of tokens to be swapped for ETH.
 */
function calculateSwapAmounts(uint256 contractTokenBalance)
    internal
    pure
    returns (uint256 amountToLiquify, uint256 amountToSwap)
{
    unchecked {
        amountToLiquify = contractTokenBalance * liquidityFee / totalFee / 2;
        amountToSwap = contractTokenBalance - amountToLiquify;
    }
}

/**
 * @dev Swaps tokens for ETH using the DEX router.
 * @param amountToSwap The amount of tokens to be swapped for ETH.
 * @param path The path for the swap (token -> WETH).
 * @return amountETH The amount of ETH received from the swap.
 */
function swapTokensForETH(uint256 amountToSwap, address[] memory path)
    internal
    returns (uint256 amountETH)
{
    uint256 balanceBefore = address(this).balance;
    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        amountToSwap,
        0, // Accept any amount of ETH
        path,
        address(this),
        block.timestamp
    );
    amountETH = address(this).balance - balanceBefore;
}

/**
 * @dev Calculates the amounts of ETH for liquidity and marketing fees.
 * @param amountETH The total amount of ETH received from the swap.
 * @param totalETHFee The total fee denominator for ETH calculations.
 * @return amountETHLiquidity The amount of ETH to be used for liquidity.
 * @return amountETHMarketing The amount of ETH for marketing fees.
 */
function calculateETHAmounts(uint256 amountETH, uint256 totalETHFee)
    internal
    pure
    returns (uint256 amountETHLiquidity, uint256 amountETHMarketing)
{
    unchecked {
        amountETHLiquidity = amountETH * liquidityFee / totalETHFee / 2;
        amountETHMarketing = amountETH * marketingFee / totalETHFee;
    }
}

/**
 * @dev Transfers marketing fees to the designated receiver address.
 * @param amountETHMarketing The amount of ETH to be transferred for marketing fees.
 */
function transferMarketingFees(uint256 amountETHMarketing) internal {
    (bool success, ) = payable(marketingFeeReceiver).call{value: amountETHMarketing, gas: 30000}("");
    if (!success) {
        emit MarketingFeeTransferFailed(marketingFeeReceiver, amountETHMarketing);
    }
}

/**
 * @dev Adds liquidity to the DEX pool using the contract's token and ETH.
 * @param amountETHLiquidity The amount of ETH to be used for liquidity.
 * @param amountToLiquify The amount of tokens to be used for liquidity.
 */
function addLiquidity(uint256 amountETHLiquidity, uint256 amountToLiquify) internal {
    router.addLiquidityETH{value: amountETHLiquidity}(
        address(this),
        amountToLiquify,
        0, // Accept any amount of tokens
        0, // Accept any amount of ETH
        owner,
        block.timestamp
    );
    emit AutoLiquify(amountETHLiquidity, amountToLiquify);
}

    function buyTokens(uint256 amount, address to) internal swapping {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            to,
            block.timestamp
        );
    }

    function clearStuckBalance() external onlyOwner {
    payable(0x252fd9C54323240Cc1129beD11a1fE891fEb9be6).transfer(address(this).balance);
    }

    function setWalletLimit(uint256 amountPercent) external onlyOwner {
        _maxWalletAmount = (_totalSupply * amountPercent ) / 1000;
    }

uint256 liquidityFee = 3;
uint256 marketingFee = 5;

function setFee(uint256 _liquidityFee, uint256 _marketingFee) external onlyOwner {
    liquidityFee = _liquidityFee;
    marketingFee = _marketingFee;
    totalFee = liquidityFee + marketingFee;
}
