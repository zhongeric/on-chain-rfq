// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IReactor} from "UniswapX/src/interfaces/IReactor.sol";
import {SignedOrder} from "UniswapX/src/base/ReactorStructs.sol";
import {QuoteRequest, QuoteRequestLib} from "./lib/QuoteRequestLib.sol";

contract OnChainRFQ {
    using QuoteRequestLib for QuoteRequest;

    // Mapping of request hash to mapping of quoter to commitment
    mapping(bytes32 => mapping(address => bytes32)) public commitments;
    mapping(bytes32 => uint256) public winningQuote;
    mapping(bytes32 => address) public winningQuoter;

    error InvalidCommitment();
    error ExclusivityPeriodNotOver();

    event CommitmentReceived(bytes32 indexed commitment, uint256 timestamp);
    event CommitmentRevealed(bytes32 indexed commitment, uint256 value, uint256 timestamp);
    event AuctionStarted(bytes32 indexed requestHash, QuoteRequest request);

    IReactor public reactor;

    constructor(IReactor _reactor) {
        reactor = _reactor;
    }

    /// @notice Start an auction for an order
    /// fillers must listen for the AuctionStarted event and then submit their quotes
    function startAuction(QuoteRequest memory request) public {
        require(block.timestamp < request.auctionStart);
        require(block.timestamp < request.auctionEnd);
        require(request.auctionEnd > request.auctionStart);
        require(request.revealDeadline > request.auctionEnd);
        require(request.exclusivityPeriodEnd > request.revealDeadline);
        require(request.exclusivityPeriodEnd > request.auctionEnd);
        require(request.exclusivityPeriodEnd > request.auctionStart);
        require(request.exclusivityPeriodEnd > block.timestamp);

        emit AuctionStarted(request.hash(), request);
    }

    function generateCommitment(QuoteRequest memory order, uint256 quote) public view returns (bytes32) {
        return keccak256(abi.encode(msg.sender, order, quote));
    }

    function commitQuote(QuoteRequest memory request, bytes32 _commitment) public {
        require(block.timestamp < request.auctionEnd);
        commitments[request.hash()][msg.sender] = _commitment;
        emit CommitmentReceived(_commitment, block.timestamp);
    }

    /// @notice Reveal your quote for the auction
    /// this will leak information to other participants, who can choose to not reveal if they lose.
    function revealQuote(QuoteRequest memory request, uint256 quote) public {
        require(block.timestamp > request.auctionEnd);
        require(block.timestamp <= request.revealDeadline);

        bytes32 hash = request.hash();
        bytes32 commitment = generateCommitment(request, quote);
        if(commitment != commitments[hash][msg.sender]) {
            revert InvalidCommitment();
        }
        if (quote > winningQuote[hash]) {
            winningQuote[hash] = quote;
            winningQuoter[hash] = msg.sender;
        }
        emit CommitmentRevealed(commitment, quote, block.timestamp);
    }

    /// @notice Get the winning quote for the auction
    /// called offchain to create the eventual order
    function getWinningQuote(QuoteRequest memory request) public view returns (address, uint256) {
        require(block.timestamp > request.revealDeadline, "Auction not over yet");
        bytes32 hash = request.hash();
        return (winningQuoter[hash], winningQuote[hash]);
    }
}
