// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Bounty
/// @notice Post a task with a described reward. Anyone can submit a claim with proof.
///         The poster reviews claims and approves one. The full history — every attempt,
///         every rejection — stays on-chain permanently.
contract Bounty {
    enum BountyStatus { Open, Claimed, Cancelled }

    struct BountyRecord {
        address poster;
        string title;
        string description;
        string reward;
        uint256 postedAt;
        uint256 expiresAt;
        BountyStatus status;
        address claimedBy;
        uint256 claimCount;
    }

    struct Claim {
        address claimant;
        string proof;
        uint256 submittedAt;
        bool approved;
        bool rejected;
        string rejectionReason;
    }

    BountyRecord[] public bounties;

    mapping(uint256 => Claim[]) public claims;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    mapping(address => uint256[]) public bountiesByPoster;
    mapping(address => uint256[]) public claimsByAddress;

    event BountyPosted(uint256 indexed id, address indexed poster, string title, uint256 expiresAt);
    event BountyCancelled(uint256 indexed id, address indexed poster);
    event ClaimSubmitted(uint256 indexed bountyId, uint256 indexed claimIndex, address indexed claimant);
    event ClaimApproved(uint256 indexed bountyId, uint256 indexed claimIndex, address indexed claimant);
    event ClaimRejected(uint256 indexed bountyId, uint256 indexed claimIndex, string reason);

    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 90 days;

    function post(
        string calldata title,
        string calldata description,
        string calldata reward,
        uint256 durationSeconds
    ) external returns (uint256) {
        require(bytes(title).length > 0, "Bounty: empty title");
        require(bytes(description).length > 0, "Bounty: empty description");
        require(bytes(description).length <= 1000, "Bounty: description too long");
        require(bytes(reward).length > 0, "Bounty: empty reward");
        require(durationSeconds >= MIN_DURATION, "Bounty: duration too short");
        require(durationSeconds <= MAX_DURATION, "Bounty: duration too long");

        uint256 id = bounties.length;

        bounties.push(BountyRecord({
            poster: msg.sender,
            title: title,
            description: description,
            reward: reward,
            postedAt: block.timestamp,
            expiresAt: block.timestamp + durationSeconds,
            status: BountyStatus.Open,
            claimedBy: address(0),
            claimCount: 0
        }));

        bountiesByPoster[msg.sender].push(id);

        emit BountyPosted(id, msg.sender, title, block.timestamp + durationSeconds);
        return id;
    }

    function submitClaim(uint256 bountyId, string calldata proof) external returns (uint256) {
        require(bountyId < bounties.length, "Bounty: invalid id");
        BountyRecord storage b = bounties[bountyId];
        require(b.status == BountyStatus.Open, "Bounty: not open");
        require(block.timestamp < b.expiresAt, "Bounty: expired");
        require(msg.sender != b.poster, "Bounty: poster cannot claim own bounty");
        require(!hasClaimed[bountyId][msg.sender], "Bounty: already submitted a claim");
        require(bytes(proof).length > 0, "Bounty: empty proof");
        require(bytes(proof).length <= 500, "Bounty: proof too long");

        uint256 claimIndex = claims[bountyId].length;

        claims[bountyId].push(Claim({
            claimant: msg.sender,
            proof: proof,
            submittedAt: block.timestamp,
            approved: false,
            rejected: false,
            rejectionReason: ""
        }));

        hasClaimed[bountyId][msg.sender] = true;
        b.claimCount++;
        claimsByAddress[msg.sender].push(bountyId);

        emit ClaimSubmitted(bountyId, claimIndex, msg.sender);
        return claimIndex;
    }

    function approveClaim(uint256 bountyId, uint256 claimIndex) external {
        require(bountyId < bounties.length, "Bounty: invalid bounty id");
        BountyRecord storage b = bounties[bountyId];
        require(msg.sender == b.poster, "Bounty: not the poster");
        require(b.status == BountyStatus.Open, "Bounty: not open");
        require(claimIndex < claims[bountyId].length, "Bounty: invalid claim index");

        Claim storage c = claims[bountyId][claimIndex];
        require(!c.approved, "Bounty: already approved");
        require(!c.rejected, "Bounty: claim was rejected");

        c.approved = true;
        b.status = BountyStatus.Claimed;
        b.claimedBy = c.claimant;

        emit ClaimApproved(bountyId, claimIndex, c.claimant);
    }

    function rejectClaim(uint256 bountyId, uint256 claimIndex, string calldata reason) external {
        require(bountyId < bounties.length, "Bounty: invalid bounty id");
        BountyRecord storage b = bounties[bountyId];
        require(msg.sender == b.poster, "Bounty: not the poster");
        require(b.status == BountyStatus.Open, "Bounty: not open");
        require(claimIndex < claims[bountyId].length, "Bounty: invalid claim index");

        Claim storage c = claims[bountyId][claimIndex];
        require(!c.approved, "Bounty: already approved");
        require(!c.rejected, "Bounty: already rejected");

        c.rejected = true;
        c.rejectionReason = reason;

        emit ClaimRejected(bountyId, claimIndex, reason);
    }

    function cancel(uint256 bountyId) external {
        require(bountyId < bounties.length, "Bounty: invalid id");
        BountyRecord storage b = bounties[bountyId];
        require(msg.sender == b.poster, "Bounty: not the poster");
        require(b.status == BountyStatus.Open, "Bounty: not open");

        b.status = BountyStatus.Cancelled;

        emit BountyCancelled(bountyId, msg.sender);
    }

    function getBounty(uint256 id) external view returns (
        address poster,
        string memory title,
        string memory description,
        string memory reward,
        uint256 postedAt,
        uint256 expiresAt,
        BountyStatus status,
        address claimedBy,
        uint256 claimCount
    ) {
        require(id < bounties.length, "Bounty: invalid id");
        BountyRecord memory b = bounties[id];
        return (b.poster, b.title, b.description, b.reward, b.postedAt, b.expiresAt, b.status, b.claimedBy, b.claimCount);
    }

    function getClaim(uint256 bountyId, uint256 claimIndex) external view returns (
        address claimant,
        string memory proof,
        uint256 submittedAt,
        bool approved,
        bool rejected,
        string memory rejectionReason
    ) {
        require(bountyId < bounties.length, "Bounty: invalid bounty id");
        require(claimIndex < claims[bountyId].length, "Bounty: invalid claim index");
        Claim memory c = claims[bountyId][claimIndex];
        return (c.claimant, c.proof, c.submittedAt, c.approved, c.rejected, c.rejectionReason);
    }

    function getBountiesByPoster(address account) external view returns (uint256[] memory) {
        return bountiesByPoster[account];
    }

    function totalBounties() external view returns (uint256) {
        return bounties.length;
    }
}
