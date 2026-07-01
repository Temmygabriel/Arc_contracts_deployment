// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GroupExpenseSplit
/// @notice A shared expense group (trip, household, team). Members log expenses they paid.
///         The contract tracks net balances. When someone is owed, they can request
///         settlement; the debtor pays directly through the contract which forwards
///         immediately to the creditor.
contract GroupExpenseSplit {
    struct Group {
        address admin;
        string name;
        uint256 createdAt;
        uint256 memberCount;
        uint256 expenseCount;
    }

    struct Expense {
        address paidBy;
        string description;
        uint256 amount;
        address[] splitAmong;
        uint256[] shares;
        uint256 loggedAt;
    }

    Group[] public groups;
    mapping(uint256 => Expense[]) public expenses;
    mapping(uint256 => mapping(address => bool)) public isMember;
    mapping(uint256 => address[]) public groupMembers;
    // groupId => creditor => debtor => amount owed
    mapping(uint256 => mapping(address => mapping(address => uint256))) public owes;
    mapping(address => uint256[]) public groupsByMember;

    event GroupCreated(uint256 indexed id, address indexed admin, string name, address[] members);
    event ExpenseLogged(uint256 indexed groupId, uint256 indexed expenseIndex, address indexed paidBy, string description, uint256 amount);
    event DebtSettled(uint256 indexed groupId, address indexed debtor, address indexed creditor, uint256 amount);

    function createGroup(string calldata name, address[] calldata members) external returns (uint256) {
        require(bytes(name).length > 0, "GroupExpenseSplit: empty name");
        require(members.length > 0, "GroupExpenseSplit: need members");
        require(members.length <= 20, "GroupExpenseSplit: too many members");

        uint256 id = groups.length;
        groups.push(Group({
            admin: msg.sender,
            name: name,
            createdAt: block.timestamp,
            memberCount: members.length + 1,
            expenseCount: 0
        }));

        isMember[id][msg.sender] = true;
        groupMembers[id].push(msg.sender);
        groupsByMember[msg.sender].push(id);

        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "GroupExpenseSplit: zero member");
            require(!isMember[id][members[i]], "GroupExpenseSplit: duplicate member");
            isMember[id][members[i]] = true;
            groupMembers[id].push(members[i]);
            groupsByMember[members[i]].push(id);
        }

        emit GroupCreated(id, msg.sender, name, members);
        return id;
    }

    /// @notice Log an expense paid by msg.sender, split among `splitAmong` by `shares` (must sum to amount).
    function logExpense(
        uint256 groupId,
        string calldata description,
        uint256 amount,
        address[] calldata splitAmong,
        uint256[] calldata shares
    ) external {
        require(groupId < groups.length, "GroupExpenseSplit: invalid group");
        require(isMember[groupId][msg.sender], "GroupExpenseSplit: not a member");
        require(bytes(description).length > 0, "GroupExpenseSplit: empty description");
        require(amount > 0, "GroupExpenseSplit: zero amount");
        require(splitAmong.length > 0 && splitAmong.length == shares.length, "GroupExpenseSplit: bad split");
        require(splitAmong.length <= 20, "GroupExpenseSplit: too many splits");

        uint256 shareSum = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            require(isMember[groupId][splitAmong[i]], "GroupExpenseSplit: non-member in split");
            require(shares[i] > 0, "GroupExpenseSplit: zero share");
            shareSum += shares[i];
        }
        require(shareSum == amount, "GroupExpenseSplit: shares must sum to amount");

        uint256 expenseIndex = expenses[groupId].length;
        expenses[groupId].push(Expense({
            paidBy: msg.sender,
            description: description,
            amount: amount,
            splitAmong: splitAmong,
            shares: shares,
            loggedAt: block.timestamp
        }));

        groups[groupId].expenseCount++;

        // Record debts: each split member who isn't the payer owes paidBy their share
        for (uint256 i = 0; i < splitAmong.length; i++) {
            if (splitAmong[i] != msg.sender) {
                owes[groupId][msg.sender][splitAmong[i]] += shares[i];
            }
        }

        emit ExpenseLogged(groupId, expenseIndex, msg.sender, description, amount);
    }

    /// @notice Debtor settles their debt to a creditor in the group.
    function settle(uint256 groupId, address creditor) external payable {
        require(groupId < groups.length, "GroupExpenseSplit: invalid group");
        require(isMember[groupId][msg.sender], "GroupExpenseSplit: not a member");
        require(msg.value > 0, "GroupExpenseSplit: zero payment");

        uint256 debt = owes[groupId][creditor][msg.sender];
        require(debt > 0, "GroupExpenseSplit: no debt owed");
        require(msg.value <= debt, "GroupExpenseSplit: overpayment");

        owes[groupId][creditor][msg.sender] -= msg.value;

        (bool ok, ) = creditor.call{value: msg.value}("");
        require(ok, "GroupExpenseSplit: transfer failed");

        emit DebtSettled(groupId, msg.sender, creditor, msg.value);
    }

    function getDebt(uint256 groupId, address creditor, address debtor) external view returns (uint256) {
        return owes[groupId][creditor][debtor];
    }

    function getGroup(uint256 id) external view returns (address, string memory, uint256, uint256, uint256) {
        require(id < groups.length, "GroupExpenseSplit: invalid id");
        Group memory g = groups[id];
        return (g.admin, g.name, g.createdAt, g.memberCount, g.expenseCount);
    }

    function getGroupMembers(uint256 id) external view returns (address[] memory) {
        require(id < groups.length, "GroupExpenseSplit: invalid id");
        return groupMembers[id];
    }

    function getGroupsByMember(address account) external view returns (uint256[] memory) {
        return groupsByMember[account];
    }

    function totalGroups() external view returns (uint256) {
        return groups.length;
    }
}
