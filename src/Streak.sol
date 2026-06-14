// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Streak
/// @notice Track daily check-in streaks. Miss a day and your streak resets — publicly.
/// @dev One check-in per calendar day (UTC). The contract enforces the 24h window.
contract Streak {
    struct StreakRecord {
        string goal;
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 totalCheckIns;
        uint256 lastCheckIn;
        uint256 startedAt;
        bool active;
    }

    mapping(address => StreakRecord) public streaks;
    mapping(address => uint256[]) public checkInLog;

    uint256 public constant WINDOW = 1 days;
    uint256 public constant GRACE = 2 days;

    event StreakStarted(address indexed user, string goal);
    event CheckedIn(address indexed user, uint256 newStreak, uint256 timestamp);
    event StreakBroken(address indexed user, uint256 brokenAt, uint256 finalStreak);
    event StreakRestarted(address indexed user, string newGoal);

    function start(string calldata goal) external {
        require(bytes(goal).length > 0, "Streak: empty goal");
        require(bytes(goal).length <= 120, "Streak: goal too long");
        require(!streaks[msg.sender].active, "Streak: already have an active streak");

        streaks[msg.sender] = StreakRecord({
            goal: goal,
            currentStreak: 0,
            longestStreak: 0,
            totalCheckIns: 0,
            lastCheckIn: 0,
            startedAt: block.timestamp,
            active: true
        });

        emit StreakStarted(msg.sender, goal);
    }

    function checkIn() external {
        StreakRecord storage s = streaks[msg.sender];
        require(s.active, "Streak: no active streak — call start() first");
        require(block.timestamp >= s.lastCheckIn + WINDOW, "Streak: already checked in today");

        bool streakBroken = s.lastCheckIn > 0 && block.timestamp > s.lastCheckIn + GRACE;

        if (streakBroken) {
            emit StreakBroken(msg.sender, block.timestamp, s.currentStreak);
            s.currentStreak = 0;
        }

        s.currentStreak++;
        s.totalCheckIns++;
        s.lastCheckIn = block.timestamp;

        if (s.currentStreak > s.longestStreak) {
            s.longestStreak = s.currentStreak;
        }

        checkInLog[msg.sender].push(block.timestamp);

        emit CheckedIn(msg.sender, s.currentStreak, block.timestamp);
    }

    function abandon() external {
        StreakRecord storage s = streaks[msg.sender];
        require(s.active, "Streak: no active streak");

        emit StreakBroken(msg.sender, block.timestamp, s.currentStreak);
        s.active = false;
        s.currentStreak = 0;
    }

    function restart(string calldata newGoal) external {
        require(bytes(newGoal).length > 0, "Streak: empty goal");
        StreakRecord storage s = streaks[msg.sender];
        require(!s.active, "Streak: abandon current streak first");

        s.goal = newGoal;
        s.currentStreak = 0;
        s.totalCheckIns = 0;
        s.lastCheckIn = 0;
        s.startedAt = block.timestamp;
        s.active = true;

        emit StreakRestarted(msg.sender, newGoal);
    }

    function isBroken(address user) external view returns (bool) {
        StreakRecord memory s = streaks[user];
        if (!s.active || s.lastCheckIn == 0) return false;
        return block.timestamp > s.lastCheckIn + GRACE;
    }

    function getStreak(address user) external view returns (
        string memory goal,
        uint256 currentStreak,
        uint256 longestStreak,
        uint256 totalCheckIns,
        uint256 lastCheckIn,
        bool active
    ) {
        StreakRecord memory s = streaks[user];
        return (s.goal, s.currentStreak, s.longestStreak, s.totalCheckIns, s.lastCheckIn, s.active);
    }

    function getCheckInLog(address user) external view returns (uint256[] memory) {
        return checkInLog[user];
    }
}
