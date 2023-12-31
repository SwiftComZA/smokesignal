pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

// Maker based oracle
abstract contract EthPriceOracle
{
    function read()
        public 
        virtual
        view 
        returns(bytes32);
}


// Pyth based oracle
struct Price {
    // Price
    int64 price;
    // Confidence interval around the price
    uint64 conf;
    // Price exponent
    int32 expo;
    // Unix timestamp describing when the price was published
    uint publishTime;
}

abstract contract PythOracle
{
    function getPriceUnsafe(bytes32 id ) 
        external 
        view 
        virtual
        returns 
    (Price memory price);
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
    PythOracle public oracle;

    constructor(address payable _donationAddress, PythOracle _oracle) 
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
            return  10**18;
        else
        {
            // bytes32 id = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // This is ETH/USD Mainnet ID
            bytes32 id = 0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6; // This is ETH/USD Testnet ID
            Price memory price = oracle.getPriceUnsafe(id);
            return convertToUint(price);
        }
    }
    // 242632774885376000000
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
    
    function convertToUint(Price memory price) 
        private 
        pure 
        returns (uint256)
    {
        if (price.price < 0 || price.expo > 0 || price.expo < -255) {
            revert();
        }

        return uint256(price.price)*10**10;
    }
}

contract SmokeSignal_Scroll is SmokeSignal
{
    // TODO : add Scroll oracle @Elmer do this first
    constructor(address payable _donationAddress) SmokeSignal(_donationAddress, PythOracle( address(0xA2aa501b19aff244D90cc15a4Cf739D2725B5729) ))
        public 
    { }
}

contract SmokeSignal_zkSync is SmokeSignal
{
    // TODO : add zkSync oracle @Elmer do this second
    constructor(address payable _donationAddress) SmokeSignal(_donationAddress, PythOracle( address(0xC38B1dd611889Abc95d4E0a472A667c3671c08DE) ))
        public 
    { }
}