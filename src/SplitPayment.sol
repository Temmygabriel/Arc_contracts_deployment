// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SplitPayment
/// @notice Register a payee group with fixed basis-point shares (sum to 10000). Anyone
///         can send native USDC to that group via pay() and it is divided instantly
///         among the recipients. Useful for revenue share, royalties, affiliate payouts.
contract SplitPayment {
    struct Group {
        address creator;
        address[] payees;
        uint256[] sharesBps;
        uint256 totalReceived;
        uint256 createdAt;
    }

    Group[] public groups;
    mapping(uint256 => mapping(address => uint256)) public totalPaidTo;
    mapping(address => uint256[]) public groupsByCreator;

    event GroupCreated(uint256 indexed id, address indexed creator, address[] payees, uint256[] sharesBps);
    event PaymentSplit(uint256 indexed id, address indexed sender, uint256 totalAmount);

    uint256 public constant TOTAL_BPS = 10000;

    function createGroup(address[] calldata payees, uint256[] calldata sharesBps) external returns (uint256) {
        require(payees.length > 0, "SplitPayment: need at least one payee");
        require(payees.length == sharesBps.length, "SplitPayment: length mismatch");
        require(payees.length <= 25, "SplitPayment: too many payees");

        uint256 sum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            require(payees[i] != address(0), "SplitPayment: zero payee");
            require(sharesBps[i] > 0, "SplitPayment: zero share");
            sum += sharesBps[i];
        }
        require(sum == TOTAL_BPS, "SplitPayment: shares must sum to 10000");

        uint256 id = groups.length;
        groups.push(Group({
            creator: msg.sender,
            payees: payees,
            sharesBps: sharesBps,
            totalReceived: 0,
            createdAt: block.timestamp
        }));

        groupsByCreator[msg.sender].push(id);

        emit GroupCreated(id, msg.sender, payees, sharesBps);
        return id;
    }

    function pay(uint256 id) external payable {
        require(id < groups.length, "SplitPayment: invalid id");
        require(msg.value > 0, "SplitPayment: zero payment");

        Group storage g = groups[id];
        g.totalReceived += msg.value;

        uint256 distributed = 0;
        uint256 n = g.payees.length;

        for (uint256 i = 0; i < n; i++) {
            uint256 share;
            if (i == n - 1) {
                // last payee gets remainder to avoid rounding dust loss
                share = msg.value - distributed;
            } else {
                share = (msg.value * g.sharesBps[i]) / TOTAL_BPS;
                distributed += share;
            }

            totalPaidTo[id][g.payees[i]] += share;

            (bool ok, ) = g.payees[i].call{value: share}("");
            require(ok, "SplitPayment: transfer failed");
        }

        emit PaymentSplit(id, msg.sender, msg.value);
    }

    function getGroup(uint256 id) external view returns (
        address creator,
        address[] memory payees,
        uint256[] memory sharesBps,
        uint256 totalReceived,
        uint256 createdAt
    ) {
        require(id < groups.length, "SplitPayment: invalid id");
        Group memory g = groups[id];
        return (g.creator, g.payees, g.sharesBps, g.totalReceived, g.createdAt);
    }

    function getGroupsByCreator(address account) external view returns (uint256[] memory) {
        return groupsByCreator[account];
    }

    function totalGroups() external view returns (uint256) {
        return groups.length;
    }
}
