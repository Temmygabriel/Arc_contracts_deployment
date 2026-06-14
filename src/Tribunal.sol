// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Tribunal
/// @notice Two parties file a dispute. A panel of jurors (any third party) votes within
///         a time window. Majority rules. The verdict and all votes are permanent on-chain.
///         Neither party may vote on their own case.
contract Tribunal {
    enum Verdict { Pending, FavorPlaintiff, FavorDefendant, Tied }

    struct Case {
        address plaintiff;
        address defendant;
        string claim;
        string defense;
        uint256 filedAt;
        uint256 hearingEndsAt;
        uint256 plaintiffVotes;
        uint256 defendantVotes;
        Verdict verdict;
        bool defenseSubmitted;
    }

    Case[] public cases;

    /// @dev caseId => juror => whether voted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @dev caseId => juror => who they voted for (true = plaintiff)
    mapping(uint256 => mapping(address => bool)) public votedForPlaintiff;

    mapping(address => uint256[]) public casesByAddress;

    event CaseFiled(uint256 indexed id, address indexed plaintiff, address indexed defendant, string claim);
    event DefenseSubmitted(uint256 indexed id, address indexed defendant, string defense);
    event VoteCast(uint256 indexed id, address indexed juror, bool forPlaintiff);
    event VerdictReached(uint256 indexed id, Verdict verdict, uint256 plaintiffVotes, uint256 defendantVotes);

    uint256 public constant HEARING_DURATION = 3 days;
    uint256 public constant DEFENSE_WINDOW = 1 days;

    function fileClaim(address defendant, string calldata claim) external returns (uint256) {
        require(defendant != address(0), "Tribunal: zero address");
        require(defendant != msg.sender, "Tribunal: cannot sue yourself");
        require(bytes(claim).length > 0, "Tribunal: empty claim");
        require(bytes(claim).length <= 500, "Tribunal: claim too long");

        uint256 id = cases.length;

        cases.push(Case({
            plaintiff: msg.sender,
            defendant: defendant,
            claim: claim,
            defense: "",
            filedAt: block.timestamp,
            hearingEndsAt: block.timestamp + HEARING_DURATION,
            plaintiffVotes: 0,
            defendantVotes: 0,
            verdict: Verdict.Pending,
            defenseSubmitted: false
        }));

        casesByAddress[msg.sender].push(id);
        casesByAddress[defendant].push(id);

        emit CaseFiled(id, msg.sender, defendant, claim);
        return id;
    }

    function submitDefense(uint256 id, string calldata defense) external {
        require(id < cases.length, "Tribunal: invalid id");
        Case storage c = cases[id];
        require(msg.sender == c.defendant, "Tribunal: not the defendant");
        require(!c.defenseSubmitted, "Tribunal: defense already submitted");
        require(block.timestamp < c.filedAt + DEFENSE_WINDOW, "Tribunal: defense window closed");
        require(bytes(defense).length > 0, "Tribunal: empty defense");
        require(bytes(defense).length <= 500, "Tribunal: defense too long");

        c.defense = defense;
        c.defenseSubmitted = true;

        emit DefenseSubmitted(id, msg.sender, defense);
    }

    function vote(uint256 id, bool forPlaintiff) external {
        require(id < cases.length, "Tribunal: invalid id");
        Case storage c = cases[id];
        require(block.timestamp < c.hearingEndsAt, "Tribunal: hearing closed");
        require(c.verdict == Verdict.Pending, "Tribunal: verdict already reached");
        require(msg.sender != c.plaintiff, "Tribunal: plaintiff cannot vote");
        require(msg.sender != c.defendant, "Tribunal: defendant cannot vote");
        require(!hasVoted[id][msg.sender], "Tribunal: already voted");

        hasVoted[id][msg.sender] = true;
        votedForPlaintiff[id][msg.sender] = forPlaintiff;

        if (forPlaintiff) {
            c.plaintiffVotes++;
        } else {
            c.defendantVotes++;
        }

        emit VoteCast(id, msg.sender, forPlaintiff);
    }

    function closeCase(uint256 id) external {
        require(id < cases.length, "Tribunal: invalid id");
        Case storage c = cases[id];
        require(block.timestamp >= c.hearingEndsAt, "Tribunal: hearing still open");
        require(c.verdict == Verdict.Pending, "Tribunal: already closed");

        if (c.plaintiffVotes > c.defendantVotes) {
            c.verdict = Verdict.FavorPlaintiff;
        } else if (c.defendantVotes > c.plaintiffVotes) {
            c.verdict = Verdict.FavorDefendant;
        } else {
            c.verdict = Verdict.Tied;
        }

        emit VerdictReached(id, c.verdict, c.plaintiffVotes, c.defendantVotes);
    }

    function getCase(uint256 id) external view returns (
        address plaintiff,
        address defendant,
        string memory claim,
        string memory defense,
        uint256 filedAt,
        uint256 hearingEndsAt,
        uint256 plaintiffVotes,
        uint256 defendantVotes,
        Verdict verdict
    ) {
        require(id < cases.length, "Tribunal: invalid id");
        Case memory c = cases[id];
        return (
            c.plaintiff,
            c.defendant,
            c.claim,
            c.defense,
            c.filedAt,
            c.hearingEndsAt,
            c.plaintiffVotes,
            c.defendantVotes,
            c.verdict
        );
    }

    function getCasesByAddress(address account) external view returns (uint256[] memory) {
        return casesByAddress[account];
    }

    function totalCases() external view returns (uint256) {
        return cases.length;
    }
}
