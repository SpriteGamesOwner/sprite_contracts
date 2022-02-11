// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;


import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../lifecycle/HasNoEther.sol";
import "../control/Utils.sol";

contract FairyAuction is Base, HasNoEther {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter public _orderIdCounter;
    
    struct Auction {
        uint256 orderId;        
        address payable seller; 
        uint128 startingPrice;  
        uint128 endingPrice;    
        uint64 duration;        
        uint64 startedAt;       
    }

    uint256 public ownerCut;
    
    address public payTokenAddress = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    
    uint64 public saleCount;
    
    uint256 public salePrice;

    mapping (address => mapping (uint256 => Auction)) public auctions;
    
    function pause() public onlyOwner {
        _pause();
    }
    
    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    event AuctionCreated(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        address _seller,
        uint256 _orderId
    );
    
    event AuctionSuccessful(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 _totalPrice,
        address _winner,
        uint256 _orderId
    );
    
    event AuctionCancelled(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 _orderId
    );

    modifier canBeStoredWith64Bits(uint256 _value) {
        require(_value <= 18446744073709551615, 'value is error');
        _;
    }

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455, 'value is error');
        _;
    }

    constructor(uint256 _ownerCut) {
        require(_ownerCut <= 10000, '_OwnerCut was error');

        ownerCut = _ownerCut;
    }

    function moveOwner(address to) external onlyOwner isExternal(to) {
        transferOwnership(to);
    }
    
    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
    external
    whenNotPaused
    canBeStoredWith128Bits(_startingPrice)
    canBeStoredWith128Bits(_endingPrice)
    canBeStoredWith64Bits(_duration)
    {
        address _seller = msg.sender;
        require(_nftAddress != address(0), 'NftAddress is a Zero address');
        require(_startingPrice > 0 && _endingPrice > 0, 'Price error');
        require(!_checkPrice(_startingPrice, _endingPrice), 'Span is too large');
        require(_owns(_nftAddress, _seller, _tokenId),  'Caller is not owner');
        require(_duration >= 1 minutes, 'Duration must be more than one minute');
        
        _escrow(_nftAddress, _seller, _tokenId);

        _orderIdCounter.increment();
        uint256 orderId = _orderIdCounter.current();

        Auction memory _auction = Auction(
            orderId,
            payable(_seller),
            uint128(_startingPrice),
            uint128(_endingPrice),
            uint64(_duration),
            uint64(block.timestamp)
        );

        _addAuction(
            _nftAddress,
            _tokenId,
            _auction,
            _seller,
            orderId
        );
    }

    function _checkPrice(uint256 _startingPrice, uint256 _endingPrice) internal pure returns (bool) {
        uint256 cut = 0 ;
        if (_endingPrice > _startingPrice) {
            cut = _endingPrice/_startingPrice;
        }
        return (cut > 2);
    }
    
    function bid(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _orderId
    )
    payable
    external
    whenNotPaused
    {
        require(_nftAddress != address(0), 'NftAddress can not a Zero Address');
        require(address(msg.sender).balance >= msg.value, "Bid failed, reason: not enough balance");

        _bid(_nftAddress, _tokenId, _orderId, msg.value);
        _transfer(_nftAddress, msg.sender, _tokenId);
    }
    
    function cancelAuction(address _nftAddress, uint256 _tokenId, uint256 _orderId) external {
        require(_nftAddress != address(0), 'NftAddress is a Zero address');
        Auction memory _auction = auctions[_nftAddress][_tokenId];
        require(msg.sender == _auction.seller, 'caller is not owner');
        require(_validAuction(_orderId, _auction), 'This auction has been bided');

        _cancelAuction(_nftAddress, _tokenId, _auction.seller, _orderId);
    }
    
    function _validAuction(uint256 _orderId, Auction memory _auction) internal pure returns (bool) {
        return (_auction.startedAt > 0 && _auction.orderId == _orderId);
    }
    
    function _getCurrentPrice(
        Auction memory _auction
    )
    internal
    view
    returns (uint256)
    {
        uint256 _secondsPassed = 0;
    
        if (block.timestamp > _auction.startedAt) {
            _secondsPassed = block.timestamp - _auction.startedAt;
        }
        
        return _computeCurrentPrice(
            _auction.startingPrice,
            _auction.endingPrice,
            _auction.duration,
            _secondsPassed
        );
    }
    
    function _computeCurrentPrice(
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        uint256 _secondsPassed
    )
    internal
    pure
    returns (uint256)
    {
        if (_secondsPassed >= _duration) {
            return _endingPrice;
        } else {
            int256 _totalPriceChange = int256(_endingPrice) - int256(_startingPrice);
            int256 _currentPriceChange = _totalPriceChange * int256(_secondsPassed) / int256(_duration);
            int256 _currentPrice = int256(_startingPrice) + _currentPriceChange;
            
            return uint256(_currentPrice);
        }
    }
    
    function _owns(address _nftAddress, address _claimant, uint256 _tokenId) internal view returns (bool) {
        return (IERC721(_nftAddress).ownerOf(_tokenId) == _claimant);
    }
    
    function _addAuction(
        address _nftAddress,
        uint256 _tokenId,
        Auction memory _auction,
        address _seller,
        uint256 orderId
    )
    internal
    {
        auctions[_nftAddress][_tokenId] = _auction;
        emit AuctionCreated(
            _nftAddress,
            _tokenId,
            uint256(_auction.startingPrice),
            uint256(_auction.endingPrice),
            uint256(_auction.duration),
            _seller,
            orderId
        );
    }
    
    function _removeAuction(address _nftAddress, uint256 _tokenId) internal {
        delete auctions[_nftAddress][_tokenId];
    }
    
    function _cancelAuction(address _nftAddress, uint256 _tokenId, address _seller, uint256 _orderId) internal {
        _removeAuction(_nftAddress, _tokenId);
        _transfer(_nftAddress, _seller, _tokenId);
        emit AuctionCancelled(_nftAddress, _tokenId,_orderId);
    }
    
    function _escrow(address _nftAddress, address _owner, uint256 _tokenId) internal {
        IERC721(_nftAddress).transferFrom(_owner, address(this), _tokenId);
    }
    
    function _transfer(address _nftAddress, address _receiver, uint256 _tokenId) internal {
        IERC721(_nftAddress).transferFrom(address(this), _receiver, _tokenId);
    }
    
    function _computeCut(uint256 _price) internal view returns (uint256) {
        return _price * ownerCut / 10000;
    }

    function _bid(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _orderId,
        uint256 _amount
    )
    internal
    returns (uint256)
    {
        Auction memory _auction = auctions[_nftAddress][_tokenId];
        require(_validAuction(_orderId, _auction), 'Invalid auction');
        uint256 _price = _getCurrentPrice(_auction);
        require(_amount >= _price, 'Current price not match bid');

        address payable _seller = _auction.seller;
        _removeAuction(_nftAddress, _tokenId);
        if (_price > 0) {
            uint256 _auctioneerCut = _computeCut(_price);
            uint256 _sellerProceeds = _price - _auctioneerCut;
            payable(address(owner())).transfer(_auctioneerCut);
            payable(address(_seller)).transfer(_sellerProceeds);
        }
        _auction.startedAt = 0;
        emit AuctionSuccessful(
            _nftAddress,
            _tokenId,
            _price,
            msg.sender,
            _orderId
        );

        return _price;
    }
 
}