// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.12;

contract Utils {

    // -----------------------------------
    // ------------- Utils ---------------
    // -----------------------------------

    function toAsciiString(address x) external view returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = this.char(hi);
            s[2*i+1] = this.char(lo);            
        }
        return string(s);
    }

    function char(bytes1 b) external pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            return bytes1(uint8(b) + 0x30);
        }
        else {
            return bytes1(uint8(b) + 0x57);
        }
    }

    function generateGUID() external view returns (bytes32) {
        uint nonce = 0;
        uint rand = uint(keccak256(abi.encodePacked(nonce, block.timestamp, block.difficulty, block.coinbase)));
        nonce++;
        return bytes32(rand);
    }

    function divideAndRoundUp(uint numerator, uint denominator) external pure returns (uint256) {
        uint256 quotient = numerator / denominator;
        if (numerator % denominator != 0) {
            quotient = quotient + 1;
        }
        return quotient;
    }
}