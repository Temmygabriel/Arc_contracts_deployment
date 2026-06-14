// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Alliance
/// @notice A group Pact. Up to 10 addresses commit to a shared cause.
///         The alliance activates once every invited member signs.
///         Any member can break it — but the breaker is permanently recorded.
///         Think guilds, coalitions, founding teams, friend groups.
contract Alliance {
    enum Status { Forming, Active, Broken, Dissolved }

    struct AllianceRecord {
        address founder;
        string name;
        string charter;
        uint256 formedAt;
        uint256 activatedAt;
        Status status;
        address brokenBy;
        string breakReason;
        uint256 memberCount;
        uint256 signedCount;
    }

    AllianceRecord[] public alliances;

    /// @dev allianceId => member address => invited
    mapping(uint256 => mapping(address => bool)) public isMember;

    /// @dev allianceId => member address => signed
    mapping(uint256 => mapping(address => bool)) public hasSigned;

    /// @dev allianceId => ordered member list
    mapping(uint256 => address[]) public members;

    mapping(address => uint256[]) public alliancesByAddress;

    event AllianceFormed(uint256 indexed id, address indexed founder, string name, uint256 memberCount);
    event AllianceSigned(uint256 indexed id, address indexed member, uint256 signaturesRemaining);
    event AllianceActivated(uint256 indexed id);
    event AllianceBroken(uint256 indexed id, address indexed breakerAddress, string reason);
    event AllianceDissolved(uint256 indexed id);

    uint256 public constant MAX_MEMBERS = 10;

    function form(
        string calldata name,
        string calldata charter,
        address[] calldata invitees
    ) external returns (uint256) {
        require(bytes(name).length > 0, "Alliance: empty name");
        require(bytes(charter).length > 0, "Alliance: empty charter");
        require(bytes(charter).length <= 1000, "Alliance: charter too long");
        require(invitees.length > 0, "Alliance: need at least one other member");
        require(invitees.length < MAX_MEMBERS, "Alliance: too many members (max 10 total)");

        uint256 id = alliances.length;

        alliances.push(AllianceRecord({
            founder: msg.sender,
            name: name,
            charter: charter,
            formedAt: block.timestamp,
            activatedAt: 0,
            status: Status.Forming,
            brokenBy: address(0),
            breakReason: "",
            memberCount: invitees.length + 1,
            signedCount: 1
        }));

        isMember[id][msg.sender] = true;
        hasSigned[id][msg.sender] = true;
        members[id].push(msg.sender);
        alliancesByAddress[msg.sender].push(id);

        for (uint256 i = 0; i < invitees.length; i++) {
            address invitee = invitees[i];
            require(invitee != address(0), "Alliance: zero address in invitees");
            require(invitee != msg.sender, "Alliance: founder already a member");
            require(!isMember[id][invitee], "Alliance: duplicate invitee");

            isMember[id][invitee] = true;
            members[id].push(invitee);
            alliancesByAddress[invitee].push(id);
        }

        emit AllianceFormed(id, msg.sender, name, invitees.length + 1);
        return id;
    }

    function sign(uint256 id) external {
        require(id < alliances.length, "Alliance: invalid id");
        AllianceRecord storage a = alliances[id];
        require(a.status == Status.Forming, "Alliance: not in forming state");
        require(isMember[id][msg.sender], "Alliance: not a member");
        require(!hasSigned[id][msg.sender], "Alliance: already signed");

        hasSigned[id][msg.sender] = true;
        a.signedCount++;

        uint256 remaining = a.memberCount - a.signedCount;
        emit AllianceSigned(id, msg.sender, remaining);

        if (a.signedCount == a.memberCount) {
            a.status = Status.Active;
            a.activatedAt = block.timestamp;
            emit AllianceActivated(id);
        }
    }

    function breakAlliance(uint256 id, string calldata reason) external {
        require(id < alliances.length, "Alliance: invalid id");
        AllianceRecord storage a = alliances[id];
        require(a.status == Status.Active, "Alliance: not active");
        require(isMember[id][msg.sender], "Alliance: not a member");

        a.status = Status.Broken;
        a.brokenBy = msg.sender;
        a.breakReason = reason;

        emit AllianceBroken(id, msg.sender, reason);
    }

    function dissolve(uint256 id) external {
        require(id < alliances.length, "Alliance: invalid id");
        AllianceRecord storage a = alliances[id];
        require(msg.sender == a.founder, "Alliance: only founder can dissolve");
        require(a.status == Status.Active, "Alliance: not active");

        a.status = Status.Dissolved;

        emit AllianceDissolved(id);
    }

    function getAlliance(uint256 id) external view returns (
        address founder,
        string memory name,
        string memory charter,
        uint256 formedAt,
        uint256 activatedAt,
        Status status,
        address brokenBy,
        string memory breakReason,
        uint256 memberCount,
        uint256 signedCount
    ) {
        require(id < alliances.length, "Alliance: invalid id");
        AllianceRecord memory a = alliances[id];
        return (
            a.founder,
            a.name,
            a.charter,
            a.formedAt,
            a.activatedAt,
            a.status,
            a.brokenBy,
            a.breakReason,
            a.memberCount,
            a.signedCount
        );
    }

    function getMembers(uint256 id) external view returns (address[] memory) {
        require(id < alliances.length, "Alliance: invalid id");
        return members[id];
    }

    function getAlliancesByAddress(address account) external view returns (uint256[] memory) {
        return alliancesByAddress[account];
    }

    function totalAlliances() external view returns (uint256) {
        return alliances.length;
    }
}
