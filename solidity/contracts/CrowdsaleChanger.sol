pragma solidity ^0.4.11;
import './SafeMath.sol';
import './ITokenChanger.sol';
import './ISmartToken.sol';
import './IEtherToken.sol';

/*
    Open issues:
    - Verify ERC20 token addresses, transferFrom (must return a boolean flag) and update them with the correct ETH values
    - Possibly move all the ERC20 token initialization from the initERC20Tokens function to a different contract to lower the gas cost and make the crowdsale changer more generic
    - Possibly add getters for ERC20 token fields so that the client won't need to rely on the order in the struct
*/

/*
    Crowdsale Changer v0.1

    The crowdsale version of the token changer, allows buying the smart token with ether/other ERC20 tokens
    The price remains fixed for the entire duration of the crowdsale
    Note that 20% of the contributions are the Bancor token's reserve

    The changer is upgradable - the token owner can replace it with a new version by calling setTokenChanger (it's also a safety mechanism in case of bugs/exploits)
*/
contract CrowdsaleChanger is SafeMath, ITokenChanger {
    struct ERC20TokenData {
        uint256 valueN; // 1 smallest unit in wei (numerator)
        uint256 valueD; // 1 smallest unit in wei (denominator)
        bool isEnabled; // is purchase of the smart token enabled with the ERC20 token, can be set by the token owner
        bool isSet;     // used to tell if the mapping element is defined
    }

    uint256 public constant DURATION = 7 days;              // crowdsale duration
    uint256 public constant TOKEN_PRICE_N = 1;              // initial price in wei (numerator)
    uint256 public constant TOKEN_PRICE_D = 100;            // initial price in wei (denominator)
    uint256 public constant BTCS_ETHER_CAP = 50000 ether;   // maximum bitcoin suisse ether contribution

    string public version = '0.1';
    string public changerType = 'crowdsale';

    uint256 public startTime = 0;                           // crowdsale start time (in seconds)
    uint256 public endTime = 0;                             // crowdsale end time (in seconds)
    uint256 public totalEtherCap = 1000000 ether;           // current temp ether contribution cap, limited as a safety mechanism until the real cap is revealed
    uint256 public totalEtherContributed = 0;               // ether contributed so far
    bytes32 public realEtherCapHash;                        // ensures that the real cap is predefined on deployment and cannot be changed later
    address public beneficiary = 0x0;                       // address to receive all contributed ether
    address public btcs = 0x0;                              // bitcoin suisse address
    ISmartToken public token;                               // smart token governed by the changer
    IEtherToken public etherToken;                          // ether token contract
    address[] public acceptedTokens;                        // ERC20 standard token addresses
    mapping (address => ERC20TokenData) public tokenData;   // ERC20 token addresses -> ERC20 token data
    mapping (address => uint256) public contributions;      // contribution per token

    // triggered when a change between two tokens occurs
    event Change(address indexed _fromToken, address indexed _toToken, address indexed _trader, uint256 _amount, uint256 _return);

    /**
        @dev constructor

        @param _token          smart token governed by the changer
        @param _etherToken     ether token contract address
        @param _startTime      crowdsale start time
        @param _beneficiary    address to receive all contributed ether
        @param _btcs           bitcoin suisse address
    */
    function CrowdsaleChanger(ISmartToken _token, IEtherToken _etherToken, uint256 _startTime, address _beneficiary, address _btcs, bytes32 _realEtherCapHash)
        validAddress(_token)
        validAddress(_etherToken)
        validAddress(_beneficiary)
        validAddress(_btcs)
        earlierThan(_startTime)
        validAmount(uint256(_realEtherCapHash))
    {
        token = _token;
        etherToken = _etherToken;
        startTime = _startTime;
        endTime = startTime + DURATION;
        beneficiary = _beneficiary;
        btcs = _btcs;
        realEtherCapHash = _realEtherCapHash;

        addERC20Token(_etherToken, 1, 1); // Ether
    }

    // validates an address - currently only checks that it isn't null
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    // validates an ERC20 token address - verifies that the address belongs to one of the ERC20 tokens
    modifier validERC20Token(address _address) {
        require(tokenData[_address].isSet);
        _;
    }

    // validates a token address - verifies that the address belongs to one of the changeable tokens
    modifier validToken(address _address) {
        require(_address == address(token) || tokenData[_address].isSet);
        _;
    }

    // verifies that an amount is greater than zero
    modifier validAmount(uint256 _amount) {
        require(_amount > 0);
        _;
    }

    // verifies that the ether cap is valid based on the key provided
    modifier validEtherCap(uint256 _cap, uint256 _key) {
        require(computeRealCap(_cap, _key) == realEtherCapHash);
        _;
    }

    // allows execution by the token owner only
    modifier tokenOwnerOnly {
        assert(msg.sender == token.owner());
        _;
    }

    // ensures that token changing is connected to the smart token
    modifier active() {
        assert(token.changer() == this);
        _;
    }

    // ensures that token changing is not conneccted to the smart token
    modifier inactive() {
        assert(token.changer() != this);
        _;
    }

    // ensures that it's earlier than the given time
    modifier earlierThan(uint256 _time) {
        assert(now < _time);
        _;
    }

    // ensures that the current time is between _startTime (inclusive) and _endTime (exclusive)
    modifier between(uint256 _startTime, uint256 _endTime) {
        assert(now >= _startTime && now < _endTime);
        _;
    }

    // ensures that we didn't reach the ether cap
    modifier etherCapNotReached() {
        assert(totalEtherContributed < totalEtherCap);
        _;
    }

    // ensures that the sender is bitcoin suisse
    modifier btcsOnly() {
        assert(msg.sender == btcs);
        _;
    }

    // ensures that we didn't reach the bitcoin suisse ether cap
    modifier btcsEtherCapNotReached(uint256 _ethContribution) {
        assert(safeAdd(totalEtherContributed, _ethContribution) <= BTCS_ETHER_CAP);
        _;
    }

    /**
        @dev returns the number of accepted ERC20 tokens defined

        @return number of accepted tokens
    */
    function acceptedTokenCount() public constant returns (uint16 count) {
        return uint16(acceptedTokens.length);
    }

    /**
        @dev returns the number of changeable tokens supported by the contract
        note that the number of changeable tokens is the number of ERC20 tokens plus the smart token

        @return number of changeable tokens
    */
    function changeableTokenCount() public constant returns (uint16 count) {
        return uint16(acceptedTokens.length + 1);
    }

    /**
        @dev given a changeable token index, returns the changeable token contract address

        @param _tokenIndex  changeable token index

        @return number of changeable tokens
    */
    function changeableToken(uint16 _tokenIndex) public constant returns (address tokenAddress) {
        if (_tokenIndex == 0)
            return token;
        return acceptedTokens[_tokenIndex - 1];
    }

    /**
        @dev initializes the predefined ERC20 tokens
        can only be called by the token owner
    */
    function initERC20Tokens()
        public
        tokenOwnerOnly
        inactive
    {
        addERC20Token(IERC20Token(0xa74476443119A942dE498590Fe1f2454d7D4aC0d), 1, 1); // Golem
        addERC20Token(IERC20Token(0x48c80F1f4D53D5951e5D5438B54Cba84f29F32a5), 1, 1); // Augur

        addERC20Token(IERC20Token(0x6810e776880C02933D47DB1b9fc05908e5386b96), 1, 1); // Gnosis
        addERC20Token(IERC20Token(0xaeC2E87E0A235266D9C5ADc9DEb4b2E29b54D009), 1, 1); // SingularDTV
        addERC20Token(IERC20Token(0xE0B7927c4aF23765Cb51314A0E0521A9645F0E2A), 1, 1); // DigixDAO

        addERC20Token(IERC20Token(0x4993CB95c7443bdC06155c5f5688Be9D8f6999a5), 1, 1); // ROUND
        addERC20Token(IERC20Token(0x607F4C5BB672230e8672085532f7e901544a7375), 1, 1); // iEx.ec
        addERC20Token(IERC20Token(0x888666CA69E0f178DED6D75b5726Cee99A87D698), 1, 1); // ICONOMI
        addERC20Token(IERC20Token(0xAf30D2a7E90d7DC361c8C4585e9BB7D2F6f15bc7), 1, 1); // FirstBlood
        addERC20Token(IERC20Token(0xBEB9eF514a379B997e0798FDcC901Ee474B6D9A1), 1, 1); // Melon
        addERC20Token(IERC20Token(0x667088b212ce3d06a1b553a7221E1fD19000d9aF), 1, 1); // Wings
    }

    /**
        @dev defines a new ERC20 token
        can only be called by the token owner while the changer is inactive

        @param _token      address of the ERC20 token
        @param _valueN     1 smallest unit in wei (numerator)
        @param _valueD     1 smallest unit in wei (denominator)
    */
    function addERC20Token(IERC20Token _token, uint256 _valueN, uint256 _valueD)
        public
        tokenOwnerOnly
        inactive
        validAddress(_token)
        validAmount(_valueN)
        validAmount(_valueD)
    {
        require(_token != address(this) && _token != token && !tokenData[_token].isSet); // validate input

        tokenData[_token].valueN = _valueN;
        tokenData[_token].valueD = _valueD;
        tokenData[_token].isEnabled = true;
        tokenData[_token].isSet = true;
        acceptedTokens.push(_token);
    }

    /**
        @dev updates one of the ERC20 tokens
        can only be called by the token owner
        note that the function can be called during the crowdsale as well, mainly to update the ERC20 token ETH value

        @param _erc20Token     address of the ERC20 token
        @param _valueN         1 smallest unit in wei (numerator)
        @param _valueD         1 smallest unit in wei (denominator)
    */
    function updateERC20Token(IERC20Token _erc20Token, uint256 _valueN, uint256 _valueD)
        public
        tokenOwnerOnly
        validERC20Token(_erc20Token)
        validAmount(_valueN)
        validAmount(_valueD)
    {
        ERC20TokenData data = tokenData[_erc20Token];
        data.valueN = _valueN;
        data.valueD = _valueD;
    }

    /**
        @dev disables purchasing with the given ERC20 token in case the token got compromised
        can only be called by the token owner

        @param _erc20Token     ERC20 token contract address
        @param _disable        true to disable the token, false to re-enable it
    */
    function disableERC20Token(IERC20Token _erc20Token, bool _disable)
        public
        tokenOwnerOnly
        validERC20Token(_erc20Token)
    {
        tokenData[_erc20Token].isEnabled = !_disable;
    }

    /**
        @dev withdraws tokens from one of the ERC20 tokens and sends them to an account
        can only be called by the token owner
        this is a safety mechanism that allows the token owner to return tokens that were sent directly to this contract by mistake

        @param _erc20Token     ERC20 token contract address
        @param _to             account to receive the new amount
        @param _amount         amount to withdraw (in the ERC20 token)
    */
    function withdraw(IERC20Token _erc20Token, address _to, uint256 _amount)
        public
        tokenOwnerOnly
        validERC20Token(_erc20Token)
        validAddress(_to)
        validAmount(_amount)
    {
        require(_to != address(this) && _to != address(token)); // validate input
        assert(_erc20Token.transfer(_to, _amount));
    }

    /**
        @dev enables the real cap defined on deployment

        @param _cap    predefined cap
        @param _key    key used to compute the cap hash
    */
    function enableRealCap(uint256 _cap, uint256 _key)
        public
        tokenOwnerOnly
        active
        between(startTime, endTime)
        validAmount(_cap)
        validEtherCap(_cap, _key)
    {
        totalEtherCap = _cap;
    }

    /**
        @dev sets the smart token's changer address to a different one instead of the current contract address
        can only be called by the token owner
        the changer can be set to null to transfer ownership from the changer to the original smart token's owner

        @param _changer    new changer contract address (can also be set to 0x0 to remove the current changer)
    */
    function setTokenChanger(ITokenChanger _changer) public tokenOwnerOnly {
        require(_changer != this && _changer != address(token)); // validate input
        token.setChanger(_changer);
    }

    /**
        @dev returns the expected return for changing a specific amount of _fromToken to _toToken

        @param _fromToken  token to change from
        @param _toToken    token to change to
        @param _amount     amount to change, in fromToken

        @return expected change return amount
    */
    function getReturn(address _fromToken, address _toToken, uint256 _amount) public constant returns (uint256 amount) {
        require(_toToken == address(token)); // validate input
        return getPurchaseReturn(IERC20Token(_fromToken), _amount);
    }

    /**
        @dev returns the expected return for buying the token for an ERC20 token

        @param _erc20Token     ERC20 token contract address
        @param _depositAmount  amount to deposit (in the ERC20 token)

        @return expected purchase return amount
    */
    function getPurchaseReturn(IERC20Token _erc20Token, uint256 _depositAmount)
        public
        constant
        active
        etherCapNotReached
        validERC20Token(_erc20Token)
        validAmount(_depositAmount)
        returns (uint256 amount)
    {
        ERC20TokenData data = tokenData[_erc20Token];
        require(data.isEnabled); // validate input

        uint256 depositEthValue = safeMul(_depositAmount, data.valueN) / data.valueD;
        if (depositEthValue == 0)
            return 0;

        // check ether cap
        require(safeAdd(totalEtherContributed, depositEthValue) <= totalEtherCap);
        return depositEthValue * TOKEN_PRICE_D / TOKEN_PRICE_N;
    }

    /**
        @dev changes a specific amount of _fromToken to _toToken

        @param _fromToken  token to change from
        @param _toToken    token to change to
        @param _amount     amount to change, in fromToken
        @param _minReturn  if the change results in an amount smaller than the minimum return, it is cancelled

        @return change return amount
    */
    function change(address _fromToken, address _toToken, uint256 _amount, uint256 _minReturn) public returns (uint256 amount) {
        require(_toToken == address(token)); // validate input
        return buyERC20(IERC20Token(_fromToken), _amount, _minReturn);
    }

    /**
        @dev buys the token with one of the ERC20 tokens
        requires the called to approve and allowance for the crowdsale contract

        @param _erc20Token     ERC20 token contract address
        @param _depositAmount  amount to deposit (in the ERC20 token)
        @param _minReturn      if the change results in an amount smaller than the minimum return, it is cancelled

        @return contribution return amount
    */
    function buyERC20(IERC20Token _erc20Token, uint256 _depositAmount, uint256 _minReturn)
        public
        between(startTime, endTime)
        returns (uint256 amount)
    {
        amount = getPurchaseReturn(_erc20Token, _depositAmount);
        assert(amount != 0 && amount >= _minReturn); // ensure the trade gives something in return and meets the minimum requested amount

        assert(_erc20Token.transferFrom(msg.sender, beneficiary, _depositAmount)); // transfer _depositAmount funds from the caller in the ERC20 token
        contributions[_erc20Token] = safeAdd(contributions[_erc20Token], _depositAmount); // increase ERC20 contribution amount

        ERC20TokenData data = tokenData[_erc20Token];
        uint256 depositEthValue = safeMul(_depositAmount, data.valueN) / data.valueD;
        handleContribution(msg.sender, depositEthValue, amount);
        Change(_erc20Token, token, msg.sender, _depositAmount, amount);
        return amount;
    }

    /**
        @dev buys the token with ETH

        @return contribution return amount
    */
    function buyETH()
        public
        payable
        between(startTime, endTime)
        returns (uint256 amount)
    {
        return handleETHDeposit(msg.sender, msg.value);
    }

    /**
        @dev buys the token with BTCs (Bitcoin Suisse only)
        can only be called before the crowdsale started

        @param _contributor    account that should receive the new tokens

        @return contribution return amount
    */
    function buyBTCs(address _contributor)
        public
        payable
        btcsOnly
        btcsEtherCapNotReached(msg.value)
        earlierThan(startTime)
        returns (uint256 amount)
    {
        return handleETHDeposit(_contributor, msg.value);
    }

    /**
        @dev handles direct ETH deposits (as opposed to ERC20 contributions)
        note that the Change event is still triggered using the sender as the trader, as opposed to the contributor

        @param _contributor    account that should receive the new tokens
        @param _depositAmount  amount contributed by the account, in wei

        @return contribution return amount
    */
    function handleETHDeposit(address _contributor, uint256 _depositAmount) private returns (uint256 amount) {
        amount = getPurchaseReturn(etherToken, _depositAmount);
        assert(amount != 0); // ensure the trade gives something in return

        etherToken.deposit.value(_depositAmount)(); // transfer the ether to the ether contract
        assert(etherToken.transfer(beneficiary, _depositAmount)); // transfer the ether to the beneficiary account
        contributions[etherToken] = safeAdd(contributions[etherToken], _depositAmount); // increase ETH contribution amount
        handleContribution(_contributor, _depositAmount, amount);

        Change(etherToken, token, msg.sender, msg.value, amount);
        return amount;
    }

    /**
        @dev handles the generic part of the contribution - regardless of the type of contribution
        assumes that the contribution was already added to the beneficiary account in the different tokens
        updates the total contributed amount and issues new tokens to the contributor and to the beneficiary

        @param _contributor        account that should the new tokens
        @param _depositEthValue    amount contributed by the account, in wei
        @param _return             amount to be issued to the contributor, in the smart token
    */
    function handleContribution(address _contributor, uint256 _depositEthValue, uint256 _return) private {
        // update the total contribution amount
        totalEtherContributed = safeAdd(totalEtherContributed, _depositEthValue);
        // issue new funds to the contributor in the smart token
        token.issue(_contributor, _return);
        // issue tokens to the beneficiary
        token.issue(beneficiary, _return);
    }

    /**
        @dev computes the real cap based on the given cap & key

        @param _cap    cap
        @param _key    key used to compute the cap hash

        @return computed real cap hash
    */
    function computeRealCap(uint256 _cap, uint256 _key) private returns (bytes32) {
        return sha3(_cap, _key);
    }

    // fallback
    function() payable {
        buyETH();
    }
}
