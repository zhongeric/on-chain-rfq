// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {InputToken, OutputToken} from "UniswapX/src/base/ReactorStructs.sol";

struct QuoteRequest {
    InputToken input;
    OutputToken output;
    uint256 auctionStart;
    uint256 auctionEnd;
    uint256 revealDeadline;
    uint256 exclusivityPeriodEnd;
}

library QuoteRequestLib {
    bytes internal constant QUOTE_REQUEST_TYPE = abi.encodePacked(
        "QuoteRequest(",
        "address inputToken,",
        "uint256 inputStartAmount,",
        "uint256 inputEndAmount,",
        "address outputToken,",
        "uint256 outputAmount,",
        "address outputRecipient,",
        "uint256 auctionStart,",
        "uint256 auctionEnd,",
        "uint256 revealDeadline,",
        "uint256 exclusivityPeriodEnd)"
    );

    bytes32 internal constant QUOTE_REQUEST_TYPE_HASH = keccak256(QUOTE_REQUEST_TYPE);

    /// @notice hash the given quote request
    /// @param request the request to hash
    /// @return the eip-712 request hash
    function hash(QuoteRequest memory request) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                QUOTE_REQUEST_TYPE_HASH,
                request.input.token,
                request.input.amount,
                request.input.maxAmount,
                request.output.token,
                request.output.amount,
                request.output.recipient,
                request.auctionStart,
                request.auctionEnd,
                request.revealDeadline,
                request.exclusivityPeriodEnd
            )
        );
    }
}
