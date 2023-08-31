pragma solidity ^0.6.0;

import "../../common/openzeppelin/math/SafeMath.sol";

abstract contract EthPriceOracle
{
    function latestRoundData()
        public 
        virtual
        view 
        returns(
            uint80 roundID,
            int answer,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound);
}

struct StoredMessageData 
{
    address firstAuthor;
    uint nativeBurned;
    uint dollarsBurned;
    uint nativeTipped;
    uint dollarsTipped;
}

contract SmokeSignal 
{
    using SafeMath for uint256;

    address payable constant burnAddress = address(0x0);
    address payable donationAddress;
    EthPriceOracle public oracle;

    constructor(address payable _donationAddress, EthPriceOracle _oracle) 
        public 
    {
        donationAddress = _donationAddress;
        oracle = _oracle;
    }

    mapping (bytes32 => StoredMessageData) public storedMessageData;

    function EthPrice() 
        public
        view
        returns (uint _price)
    {
       

        if (address(oracle) == address(0))
            return 10**18;
        else
        {
            (/* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/) = oracle.latestRoundData();
            return uint(answer)*10**10;
        }
    }

    function ethToUsd(uint ethAmount)
        public
        view
        returns (uint usdAmount)
    {
        usdAmount = EthPrice() * ethAmount / 10**18;
    }

    event MessageBurn(
        bytes32 indexed _hash,
        address indexed _from,
        uint _burnAmount,
        uint _burnUsdValue,
        string _message
    );

    function burnMessage(string calldata _message, uint donateAmount)
        external
        payable
        returns(bytes32)
    {
        internalDonateIfNonzero(donateAmount);

        bytes32 hash = keccak256(abi.encode(_message));

        uint burnAmount = msg.value.sub(donateAmount);

        uint burnUsdValue = ethToUsd(burnAmount);

        internalBurnForMessageHash(hash, burnAmount, burnUsdValue);

        if (storedMessageData[hash].firstAuthor == address(0))
        {
            storedMessageData[hash].firstAuthor = msg.sender;
        }

        emit MessageBurn(
            hash,
            msg.sender,
            burnAmount,
            burnUsdValue,
            _message);

        return hash;
    }

    event HashBurn(
        bytes32 indexed _hash,
        address indexed _from,
        uint _burnAmount,
        uint _burnUsdValue
    );

    function burnHash(bytes32 _hash, uint donateAmount)
        external
        payable
    {
        internalDonateIfNonzero(donateAmount);

        uint burnAmount = msg.value.sub(donateAmount);

        uint burnUsdValue = ethToUsd(burnAmount);

        internalBurnForMessageHash(_hash, burnAmount, burnUsdValue);

        emit HashBurn(
            _hash,
            msg.sender,
            burnAmount,
            burnUsdValue
        );
    }

    event HashTip(
        bytes32 indexed _hash,
        address indexed _from,
        uint _tipAmount,
        uint _tipUsdValue
    );

    function tipHashOrBurnIfNoAuthor(bytes32 _hash, uint donateAmount)
        external
        payable
    {
        internalDonateIfNonzero(donateAmount);

        uint tipAmount = msg.value.sub(donateAmount);
        
        uint tipUsdValue = ethToUsd(tipAmount);
        
        address author = storedMessageData[_hash].firstAuthor;
        if (author == address(0))
        {
            internalBurnForMessageHash(_hash, tipAmount, tipUsdValue);

            emit HashBurn(
                _hash,
                msg.sender,
                tipAmount,
                tipUsdValue
            );
        }
        else 
        {
            internalTipForMessageHash(_hash, author, tipAmount, tipUsdValue);

            emit HashTip(
                _hash,
                msg.sender,
                tipAmount,
                tipUsdValue
            );
        }
    }

    function internalBurnForMessageHash(bytes32 _hash, uint _burnAmount, uint _burnUsdValue)
        internal
    {
        internalBurn(_burnAmount);
        storedMessageData[_hash].nativeBurned += _burnAmount;
        storedMessageData[_hash].dollarsBurned += _burnUsdValue;
    }

    function internalTipForMessageHash(bytes32 _hash, address author, uint _tipAmount, uint _tipUsdValue)
        internal
    {
        internalSend(author, _tipAmount);
        storedMessageData[_hash].nativeTipped += _tipAmount;
        storedMessageData[_hash].dollarsTipped += _tipUsdValue;
    }

    function internalDonateIfNonzero(uint _wei)
        internal
    {
        if (_wei > 0)
        {
            internalSend(donationAddress, _wei);
        }
    }

    function internalSend(address _to, uint _wei)
        internal
    {
        _to.call.value(_wei)("");
    }

    function internalBurn(uint _wei)
        internal
    {
        burnAddress.call.value(_wei)("");
    }
}

contract SmokeSignal_Base is SmokeSignal
{
    // TODO : Add the chainlink Eth / usd oracle address for Base here @Elmer
    constructor(address payable _donationAddress) SmokeSignal(_donationAddress, EthPriceOracle(address(0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2))) // Mainnet 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
        public 
    { }
}
