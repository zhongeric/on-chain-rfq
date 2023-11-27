// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {QuoteRequest, QuoteRequestLib} from "./lib/QuoteRequestLib.sol";

/// A simple on-chain RFQ system using a commit-reveal scheme and staking to prevent spam
/// extensions to this can include slashing for not revealing or fading
/// @dev best used on L2s where gas is cheap
/// the client must eventually build the order with the results from calling `getWinningQuote`
contract OnChainRFQSystem {
    using QuoteRequestLib for QuoteRequest;
    // Mapping of request hash to mapping of quoter to commitment

    mapping(bytes32 => mapping(address => bytes32)) public commitments;
    mapping(bytes32 => uint256) public winningQuote;
    mapping(bytes32 => address) public winningQuoter;
    // Mapping of address to staked amount
    mapping(address => uint256) public stake;

    error NotEnoughStake();
    error InvalidCommitment();
    error ExclusivityPeriodNotOver();

    event CommitmentReceived(bytes32 indexed commitment, uint256 timestamp);
    event CommitmentRevealed(bytes32 indexed commitment, uint256 value, uint256 timestamp);
    event AuctionStarted(bytes32 indexed requestHash, QuoteRequest request);

    uint256 public constant MIN_STAKE = 1 ether;

    /// @notice Start an RFQ auction
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

    /// @notice Generate a commitment for the given order and quote
    /// can be called offchain
    function generateCommitment(QuoteRequest memory order, uint256 quote) public view returns (bytes32) {
        return keccak256(abi.encode(msg.sender, order, quote));
    }

    /// @notice Commit a quote for the auction
    /// the sender must have at least MIN_STAKE
    function commitQuote(QuoteRequest memory request, bytes32 _commitment) public {
        require(block.timestamp < request.auctionEnd);
        if (stake[msg.sender] < MIN_STAKE) revert NotEnoughStake();

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
        if (commitment != commitments[hash][msg.sender]) {
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

    /// @notice Receive stake
    receive() external payable {
        stake[msg.sender] += msg.value;
    }

    /// @notice Withdraw stake
    function withdrawStake(uint256 amount) external {
        require(stake[msg.sender] >= amount);
        stake[msg.sender] -= amount;
        (msg.sender).call{value: amount};
    }
}
