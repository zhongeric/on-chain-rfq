// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

struct SignedOrder {
    bytes order;
    bytes sig;
}

struct AuctionOrder {
    bytes32 orderHash;
    SignedOrder signedOrder;
    uint256 auctionEnd;
    uint256 auctionStart;
    uint256 revealDeadline;
    uint256 exclusivityPeriodEnd;
}

contract OnChainRFQ {
    // Mapping from orderHash to mapping from quoter to commitment
    mapping(bytes32 => mapping (address => bytes32)) public commitments;
    mapping(bytes32 => uint256) public winningQuote;
    mapping(bytes32 => address) public winningQuoter;

    error ExclusivityPeriodNotOver;

    function createCommitment(AuctionOrder memory order, uint256 quote) public view returns (bytes32) {
        return keccak256(abi.encode(msg.sender, order, quote));
    }

    function commit(AuctionOrder memory order, bytes32 _commitment) public {
        require(block.timestamp < order.auctionEnd);
        commitments[order.orderHash][msg.sender] = _commitment;
    }

    /// @notice Reveal your quote for the auction
    /// this will leak information to other participants, who can choose to not reveal if they lose.
    function reveal(AuctionOrder memory order, uint256 quote) public {
        require(block.timestamp > order.auctionEnd);
        require(block.timestamp <= order.revealDeadline);
        require(createCommitment(order, quote) == commitments[order.orderHash][msg.sender]);
        if(quote > winningQuote[order.orderHash]) {
            winningQuote[order.orderHash] = quote;
            winningQuoter[order.orderHash] = msg.sender;
        }
    }

    function settle(AuctionOrder memory order) public {
        require(block.timestamp > order.revealDeadline, "Auction not over yet");
        if(block.timestamp <= order.exclusivityPeriodEnd && winningQuoter[order.orderHash] != msg.sender) {
            revert ExclusivityPeriodNotOver();
        }


    }
}
