// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IERC20 {
    // 小数点
    function decimals() external view returns (uint8);
    // 符号
    function symbol() external view returns (string memory);
    // 名称
    function name() external view returns (string memory);
    // 总供给量
    function totalSupply() external view returns (uint256);
    // 收支平衡
    function balanceOf(address account) external view returns (uint256);
    // 转账
    function transfer(address recipient, uint256 amount) external returns (bool);
    // 津贴
    function allowance(address owner, address spender) external view returns (uint256);
    // 同意
    function approve(address spender, uint256 amount) external returns (bool);
    // 转账
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    // 转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 许可事件
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// 交换路由器
interface ISwapRouter {
    // 工厂
    function factory() external pure returns (address);
    // 交换准确的代币，以支持转移代币的费用
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    // 活动性
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
}

// 交换工厂
interface ISwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
// 安全的数学
library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }


    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }


    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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


    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TokenDistributor {
    address public _owner;
    constructor (address token) {
        _owner = msg.sender;
        IERC20(token).approve(msg.sender, ~uint256(0));
    }

    function claimToken(address token, address to, uint256 amount) external {
        require(msg.sender == _owner, "!owner");
        IERC20(token).transfer(to, amount);
    }
}

interface ISwapPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

abstract contract AbsToken is IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private fundAddress;
    address private receiveAddress;
    address public  deadAddress = address(0x000000000000000000000000000000000000dEaD);
    address private marketAddress = address(0x02132304A890b5e918da6565AA1e747940A7510c);
    address private teamAddress = address(0xbD01795576533F618Dc86B6f3Da311053fE3dc7f);
    IERC20 public rewardToken = IERC20(0xe51A771214d38aA1C5ee082D0139955709a578e8);



    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping(address => bool) public _isExcludedFromFees;
    mapping (address => bool) public rewardList;

    uint256 private _tTotal;

    ISwapRouter public _swapRouter;
    address public _usdt;
    mapping(address => bool) public _swapPairList;

    bool private inSwap;

    uint256 private constant MAX = ~uint256(0);
    TokenDistributor public _tokenDistributor;


    uint256 public _buyLPDividendFee = 99;
    uint256 public _buyFundFee = 400;
    uint256 public _buyLPFee = 0;
    uint256 public _buyAirdropFee = 1;

    uint256 public _sellLPDividendFee = 99;
    uint256 public _sellFundFee = 400;
    uint256 public _sellLPFee = 0;
    uint256 public _sellAirdropFee = 1;

    uint256 public transferFee = 0;
    uint public removeFee = 0;

    uint256 public startTradeBlock;
    uint256 public startLPBlock;
    address public _mainPair;
    uint256 public startTime;

    uint256 public rewardtime = 0 ;
    uint256 public waitblock = 20 ;
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (
        address RouterAddress, address USDTAddress,
        string memory Name, string memory Symbol, uint8 Decimals, uint256 Supply,
        address ReceiveAddress, address FundAddress
    ){
        _name = Name;
        _symbol = Symbol;
        _decimals = Decimals;

        ISwapRouter swapRouter = ISwapRouter(RouterAddress);

        _usdt = USDTAddress;
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = MAX;
        IERC20(USDTAddress).approve(RouterAddress, MAX);

        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address mainPair = swapFactory.createPair(address(this), USDTAddress);
        _swapPairList[mainPair] = true;

        _mainPair = mainPair;

        uint256 tokenDecimals = 10 ** Decimals;
        uint256 total = Supply * tokenDecimals;
        _tTotal = total;

        _balances[ReceiveAddress] = total;
        emit Transfer(address(0), ReceiveAddress, total);
        fundAddress = FundAddress;
        receiveAddress = ReceiveAddress;

        _isExcludedFromFees[ReceiveAddress] = true;
        _isExcludedFromFees[FundAddress] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[address(swapRouter)] = true;
        _isExcludedFromFees[msg.sender] = true;
        _isExcludedFromFees[marketAddress] = true;
        _isExcludedFromFees[teamAddress] = true;

        _tokenDistributor = new TokenDistributor(USDTAddress);

        excludeHolder[address(0)] = true;
        excludeHolder[address(deadAddress)] = true;
        holderRewardCondition = 1 * 10 ** 15;

    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 balance = _balances[account];
        return balance;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {

        require(!rewardList[from], "rewardList");
        uint256 balance = balanceOf(from);
        require(balance >= amount, "balanceNotEnough");

        bool takeFee;
        bool isTransfer;
        bool isRemove;
        bool isAdd;

        if (!_swapPairList[from] && !_swapPairList[to]) {
            isTransfer = true;
        }

        if (_swapPairList[from] && block.timestamp < startTime + rewardtime) {
            rewardList[to] = true;
        }

        if (_swapPairList[from] || _swapPairList[to]) {

            if (0 == startLPBlock) {
                if (_isExcludedFromFees[from] && to == _mainPair && IERC20(to).totalSupply() == 0) {
                    startLPBlock = block.number;
                }
            }

            if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {

                takeFee = true;

                if (_swapPairList[to]) {
                    isAdd = _isAddLiquidity();
                    if (isAdd) {
                        takeFee = false;
                    }
                }else {
                    isRemove = _isRemoveLiquidity();
                    if (isRemove) {
                        takeFee = true;
                    }
                }

                if (0 == startTradeBlock) {
                    require(0 < startLPBlock && isAdd, "!Trade");
                }

            }
        }

        _tokenTransfer(from, to, amount, takeFee, isTransfer, isRemove);

        if (from != address(this)) {
            if (_swapPairList[to]) {
                addHolder(from);
            }
            processReward(1000000);
        }
    }

    function _isAddLiquidity() internal view returns (bool isAdd){
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0,uint256 r1,) = mainPair.getReserves();

        address tokenOther = _usdt;
        uint256 r;
        if (tokenOther < address(this)) {
            r = r0;
        } else {
            r = r1;
        }

        uint bal = IERC20(tokenOther).balanceOf(address(mainPair));
        isAdd = bal > r;
    }

    function _isRemoveLiquidity() internal view returns (bool isRemove){
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0,uint256 r1,) = mainPair.getReserves();

        address tokenOther = _usdt;
        uint256 r;
        if (tokenOther < address(this)) {
            r = r0;
        } else {
            r = r1;
        }
        uint bal = IERC20(tokenOther).balanceOf(address(mainPair));
        isRemove = r >= bal;
    }

    address public lastAirdropAddress;

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isTransfer,
        bool isRemove
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;
        uint256 airdropFeeAmount;
        if (takeFee) {
            address current;
            if (isRemove){
                uint removeFeeAmount = tAmount * removeFee / 100;
                if (removeFeeAmount > 0) {
                    feeAmount += removeFeeAmount;
                    _takeTransfer(sender, address(this), removeFeeAmount);
                }
            }else { //buy
                if (_swapPairList[sender]){
                    uint256 swapFee = _buyFundFee + _buyLPDividendFee + _buyLPFee;
                    uint256 swapAmount = (tAmount * swapFee) / 10000;
                    airdropFeeAmount = _buyAirdropFee * tAmount / 10000;
                    current = recipient;
                    if (swapAmount > 0) {
                        feeAmount += swapAmount;
                        _takeTransfer(sender, address(this), swapAmount);
                    }
                }else{//sell
                    uint256 swapFee = _sellFundFee + _sellLPDividendFee + _sellLPFee;
                    uint256 swapAmount = (tAmount * swapFee) / 10000;
                    airdropFeeAmount = _sellAirdropFee * tAmount / 10000;
                    current = sender;

                    if (swapAmount > 0) {
                        feeAmount += swapAmount;
                        _takeTransfer(sender, address(this), swapAmount);
                    }
                    if (!inSwap) {
                        uint256 contractTokenBalance = balanceOf(address(this));
                        if (contractTokenBalance > 0) {
                            swapFee = _buyFundFee + _buyLPDividendFee + _buyLPFee + _sellFundFee + _sellLPDividendFee + _sellLPFee;
                            uint256 numTokensSell = tAmount * swapFee / 5000;
                            if (numTokensSell > contractTokenBalance) {
                                numTokensSell = contractTokenBalance;
                            }
                            uint256 numTokensSellToFund = contractTokenBalance * 4 / 5;
                            uint256 numTokensSellToReward = contractTokenBalance * 1 / 5;
                            swapTokenForFund(numTokensSellToFund, swapFee);
                            swapTokenForReward(numTokensSellToReward);
                        }
                    }
                }
                if (airdropFeeAmount > 0) {
                    uint256 seed = (uint160(lastAirdropAddress) | block.number) ^ uint160(current);
                    feeAmount += airdropFeeAmount;
                    uint256 airdropAmount = airdropFeeAmount / 2;
                    address airdropAddress;
                    for (uint256 i; i < 2;) {
                        airdropAddress = address(uint160(seed | tAmount));
                        _takeTransfer(sender, airdropAddress, airdropAmount);
                        unchecked{
                            ++i;
                            seed = seed >> 1;
                        }
                    }
                    lastAirdropAddress = airdropAddress;
                }
            }
        }
        if (isTransfer && !_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient]){
            uint256 transferFeeAmount;
            transferFeeAmount = (tAmount * transferFee) / 10000;

            if (transferFeeAmount > 0) {
                feeAmount += transferFeeAmount;
                _takeTransfer(sender, deadAddress, transferFeeAmount);
            }
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    function swapTokenForFund(uint256 tokenAmount, uint256 swapFee) private lockTheSwap {
        swapFee += swapFee;
        uint256 lpFee = _sellLPFee;
        uint256 lpAmount = tokenAmount * lpFee / swapFee;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _usdt;
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount - lpAmount,
            0,
            path,
            address(_tokenDistributor),
            block.timestamp
        );

        swapFee -= lpFee;

        IERC20 USDT = IERC20(_usdt);
        uint256 UsdtBalance = USDT.balanceOf(address(_tokenDistributor));
        uint256 fundAmount = UsdtBalance * (_buyFundFee + _sellFundFee) * 2 / swapFee;
        USDT.transferFrom(address(_tokenDistributor), marketAddress, fundAmount.div(2));
        USDT.transferFrom(address(_tokenDistributor), teamAddress, fundAmount.div(2));
        USDT.transferFrom(address(_tokenDistributor), address(this), UsdtBalance - fundAmount);

        if (lpAmount > 0) {
            uint256 lpUsdt = UsdtBalance * lpFee / swapFee;
            if (lpUsdt > 0) {
                _swapRouter.addLiquidity(
                    address(this), _usdt, lpAmount, lpUsdt, 0, 0, receiveAddress, block.timestamp
                );
            }
        }
    }
    function swapTokenForReward(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = _usdt;
        path[2] = address(rewardToken);
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }

    function setFundAddress(address addr) external onlyOwner {
        fundAddress = addr;
        _isExcludedFromFees[addr] = true;
    }

    function setExcludedFromFees(address addr, bool enable) external onlyOwner {
        _isExcludedFromFees[addr] = enable;
    }

    function batchSetExcludedFromFees(address[] calldata addr, bool enable) external onlyOwner {
        for (uint i = 0; i < addr.length; i++) {
            _isExcludedFromFees[addr[i]] = enable;
        }
    }

    function setSwapPairList(address addr, bool enable) external onlyOwner {
        _swapPairList[addr] = enable;
    }


    receive() external payable {}

    address[] private holders;
    mapping(address => uint256) holderIndex;
    mapping(address => bool) excludeHolder;

    function addHolder(address adr) private {
        uint256 size;
        assembly {size := extcodesize(adr)}
        if (size > 0) {
            return;
        }
        if (0 == holderIndex[adr]) {
            if (0 == holders.length || holders[0] != adr) {
                holderIndex[adr] = holders.length;
                holders.push(adr);
            }
        }
    }

    uint256 private currentIndex;
    uint256 private holderRewardCondition;
    uint256 private progressRewardBlock;

    function processReward(uint256 gas) private {
        if (progressRewardBlock + waitblock > block.number) {
            return;
        }

        IERC20 USDT = IERC20(rewardToken);

        uint256 balance = USDT.balanceOf(address(this));
        if (balance < holderRewardCondition) {
            return;
        }

        IERC20 holdToken = IERC20(_mainPair);
        uint holdTokenTotal = holdToken.totalSupply();

        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;

        uint256 shareholderCount = holders.length;

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            shareHolder = holders[currentIndex];
            tokenBalance = holdToken.balanceOf(shareHolder);
            if (tokenBalance > 0 && !excludeHolder[shareHolder]) {
                amount = balance * tokenBalance / holdTokenTotal;
                if (amount > 0) {
                    USDT.transfer(shareHolder, amount);
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }

        progressRewardBlock = block.number;
    }

    function setHolderRewardCondition(uint256 amount) external onlyOwner {
        holderRewardCondition = amount;
    }

    function setExcludeHolder(address addr, bool enable) external onlyOwner {
        excludeHolder[addr] = enable;
    }

    function setBuyLPDividendFee(uint256 newvalue) external onlyOwner {
        _buyLPDividendFee = newvalue;
    }

    function setBuyLPFee(uint256 newvalue) external onlyOwner {
        _buyLPFee = newvalue;
    }

    function setBuyAirdropFee(uint256 newvalue) external onlyOwner {
        _buyAirdropFee = newvalue;
    }

    function setBuyFundFee(uint256 newvalue) external onlyOwner {
        _buyFundFee = newvalue;
    }

    function setSellLPDividendFee(uint256 newvalue) external onlyOwner {
        _sellLPDividendFee = newvalue;
    }

    function setSellFundFee(uint256 newvalue) external onlyOwner {
        _sellFundFee = newvalue;
    }

    function setSellLPFee(uint256 newvalue) external onlyOwner {
        _sellLPFee = newvalue;
    }

    function setSellAirdropFee(uint256 newvalue) external onlyOwner {
        _sellAirdropFee = newvalue;
    }

    function setTime(uint256 value) public onlyOwner {
        rewardtime = value;
    }

    function setTransferFee(uint256 newValue) public onlyOwner{
        transferFee = newValue;
    }

    function setRemoveFee(uint256 newValue) public onlyOwner{
        removeFee = newValue;
    }

    function setWaitBlock(uint256 newValue) public onlyOwner{
        waitblock = newValue;
    }

    function multikList(address[] calldata adrs, bool value) public onlyOwner{
        for(uint256 i; i< adrs.length; i++){
            rewardList[adrs[i]] = value;
        }
    }

    function startTrade() external onlyOwner {
        require(0 == startTradeBlock, "trading");
        startTradeBlock = block.number;
        startTime = block.timestamp;
    }


    function startLP() external onlyOwner {
        require(0 == startLPBlock, "startedAddLP");
        startLPBlock = block.number;
    }

    function stopLP() external onlyOwner {
        startLPBlock = 0;
    }

    function claimBalance() external onlyFunder  {
        payable(fundAddress).transfer(address(this).balance);
    }

    function claimToken(address token, uint256 amount, address to) external onlyFunder  {
        IERC20(token).transfer(to, amount);
    }

    modifier onlyFunder() {
        require(_owner == msg.sender || fundAddress == msg.sender, "!Funder");
        _;
    }

}

contract TIY is AbsToken {
    constructor() AbsToken(
    //SwapRouter
    address(0x42a0F91973536f85B06B310fa9C70215784F35a1),
    //USDT
    address(0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f),
    "TIY",
    "TIY",
    18,
    500000,
    //Receive
    address(0x06E223cCbbDb3c96D0cfC83bf9fCF837BdDd85d2),
    //Fund
    address(0xbD01795576533F618Dc86B6f3Da311053fE3dc7f)
    ){
    }
}
