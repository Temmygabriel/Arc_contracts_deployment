// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SavingsCircle
/// @notice A rotating savings group (ROSCA). A fixed set of members each contribute
///         the same amount per round. One member receives the full pot per round.
///         The admin assigns the recipient order upfront. Everyone must pay before
///         the pot is released. Runs until every member has received once.
contract SavingsCircle {
    enum CircleStatus { Forming, Active, Completed }

    struct Circle {
        address admin;
        string name;
        uint256 contributionAmount;
        uint256 memberCount;
        uint256 currentRound;
        uint256 roundDeadline;
        uint256 roundDuration;
        CircleStatus status;
        uint256 paidInRound;
    }

    Circle[] public circles;
    mapping(uint256 => address[]) public memberOrder;
    mapping(uint256 => mapping(address => bool)) public isMember;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasPaidRound;
    mapping(uint256 => mapping(uint256 => bool)) public roundPaid;
    mapping(address => uint256[]) public circlesByMember;

    event CircleCreated(uint256 indexed id, address indexed admin, string name, uint256 contributionAmount, uint256 memberCount);
    event CircleActivated(uint256 indexed id);
    event ContributionMade(uint256 indexed id, uint256 indexed round, address indexed contributor, uint256 paidCount);
    event PotReleased(uint256 indexed id, uint256 indexed round, address indexed recipient, uint256 amount);
    event CircleCompleted(uint256 indexed id);

    function createCircle(
        string calldata name,
        uint256 contributionAmount,
        uint256 roundDuration,
        address[] calldata members
    ) external returns (uint256) {
        require(bytes(name).length > 0, "SavingsCircle: empty name");
        require(contributionAmount > 0, "SavingsCircle: zero contribution");
        require(roundDuration >= 1 days, "SavingsCircle: round too short");
        require(members.length >= 2, "SavingsCircle: need at least 2 members");
        require(members.length <= 20, "SavingsCircle: too many members");

        uint256 id = circles.length;
        circles.push(Circle({
            admin: msg.sender,
            name: name,
            contributionAmount: contributionAmount,
            memberCount: members.length,
            currentRound: 0,
            roundDeadline: 0,
            roundDuration: roundDuration,
            status: CircleStatus.Forming,
            paidInRound: 0
        }));

        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "SavingsCircle: zero member");
            require(!isMember[id][members[i]], "SavingsCircle: duplicate member");
            isMember[id][members[i]] = true;
            memberOrder[id].push(members[i]);
            circlesByMember[members[i]].push(id);
        }

        emit CircleCreated(id, msg.sender, name, contributionAmount, members.length);
        return id;
    }

    function activate(uint256 id) external {
        require(id < circles.length, "SavingsCircle: invalid id");
        Circle storage c = circles[id];
        require(msg.sender == c.admin, "SavingsCircle: not admin");
        require(c.status == CircleStatus.Forming, "SavingsCircle: already active");

        c.status = CircleStatus.Active;
        c.currentRound = 1;
        c.roundDeadline = block.timestamp + c.roundDuration;
        c.paidInRound = 0;

        emit CircleActivated(id);
    }

    function contribute(uint256 id) external payable {
        require(id < circles.length, "SavingsCircle: invalid id");
        Circle storage c = circles[id];
        require(c.status == CircleStatus.Active, "SavingsCircle: not active");
        require(isMember[id][msg.sender], "SavingsCircle: not a member");
        require(block.timestamp <= c.roundDeadline, "SavingsCircle: round deadline passed");
        require(!hasPaidRound[id][c.currentRound][msg.sender], "SavingsCircle: already paid this round");
        require(msg.value == c.contributionAmount, "SavingsCircle: wrong contribution amount");

        hasPaidRound[id][c.currentRound][msg.sender] = true;
        c.paidInRound++;

        emit ContributionMade(id, c.currentRound, msg.sender, c.paidInRound);

        if (c.paidInRound == c.memberCount) {
            _releasePot(id);
        }
    }

    function _releasePot(uint256 id) internal {
        Circle storage c = circles[id];
        uint256 round = c.currentRound;
        address recipient = memberOrder[id][round - 1];
        uint256 pot = c.contributionAmount * c.memberCount;

        roundPaid[id][round] = true;

        (bool ok, ) = recipient.call{value: pot}("");
        require(ok, "SavingsCircle: pot transfer failed");

        emit PotReleased(id, round, recipient, pot);

        if (round == c.memberCount) {
            c.status = CircleStatus.Completed;
            emit CircleCompleted(id);
        } else {
            c.currentRound++;
            c.paidInRound = 0;
            c.roundDeadline = block.timestamp + c.roundDuration;
        }
    }

    function getCircle(uint256 id) external view returns (
        address admin,
        string memory name,
        uint256 contributionAmount,
        uint256 memberCount,
        uint256 currentRound,
        uint256 roundDeadline,
        CircleStatus status
    ) {
        require(id < circles.length, "SavingsCircle: invalid id");
        Circle memory c = circles[id];
        return (c.admin, c.name, c.contributionAmount, c.memberCount, c.currentRound, c.roundDeadline, c.status);
    }

    function getMemberOrder(uint256 id) external view returns (address[] memory) {
        require(id < circles.length, "SavingsCircle: invalid id");
        return memberOrder[id];
    }

    function getCirclesByMember(address account) external view returns (uint256[] memory) {
        return circlesByMember[account];
    }

    function totalCircles() external view returns (uint256) {
        return circles.length;
    }
}
