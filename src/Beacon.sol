// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Beacon
/// @notice Signal that you're open to something — collaboration, help, connection.
///         Beacons expire automatically. Respond to someone's beacon and they're notified on-chain.
contract Beacon {
    struct BeaconRecord {
        address emitter;
        string signal;
        string context;
        uint256 emittedAt;
        uint256 expiresAt;
        bool extinguished;
        uint256 responseCount;
    }

    struct Response {
        address responder;
        string message;
        uint256 respondedAt;
    }

    BeaconRecord[] public beacons;
    mapping(uint256 => Response[]) public responses;
    mapping(address => uint256[]) public beaconsByAddress;
    mapping(uint256 => mapping(address => bool)) public hasResponded;

    event BeaconLit(uint256 indexed id, address indexed emitter, string signal, uint256 expiresAt);
    event BeaconExtinguished(uint256 indexed id, address indexed emitter);
    event BeaconResponse(uint256 indexed beaconId, address indexed responder, string message);

    function light(
        string calldata signal,
        string calldata context,
        uint256 durationSeconds
    ) external returns (uint256) {
        require(bytes(signal).length > 0, "Beacon: empty signal");
        require(bytes(signal).length <= 80, "Beacon: signal too long");
        require(bytes(context).length <= 300, "Beacon: context too long");
        require(durationSeconds >= 1 hours, "Beacon: minimum 1 hour duration");
        require(durationSeconds <= 30 days, "Beacon: maximum 30 day duration");

        uint256 id = beacons.length;
        uint256 expiresAt = block.timestamp + durationSeconds;

        beacons.push(BeaconRecord({
            emitter: msg.sender,
            signal: signal,
            context: context,
            emittedAt: block.timestamp,
            expiresAt: expiresAt,
            extinguished: false,
            responseCount: 0
        }));

        beaconsByAddress[msg.sender].push(id);

        emit BeaconLit(id, msg.sender, signal, expiresAt);
        return id;
    }

    function extinguish(uint256 id) external {
        require(id < beacons.length, "Beacon: invalid id");
        BeaconRecord storage b = beacons[id];
        require(msg.sender == b.emitter, "Beacon: not your beacon");
        require(!b.extinguished, "Beacon: already extinguished");
        require(block.timestamp < b.expiresAt, "Beacon: already expired");

        b.extinguished = true;
        emit BeaconExtinguished(id, msg.sender);
    }

    function respond(uint256 id, string calldata message) external {
        require(id < beacons.length, "Beacon: invalid id");
        BeaconRecord storage b = beacons[id];
        require(!b.extinguished, "Beacon: extinguished");
        require(block.timestamp < b.expiresAt, "Beacon: expired");
        require(msg.sender != b.emitter, "Beacon: cannot respond to your own beacon");
        require(!hasResponded[id][msg.sender], "Beacon: already responded");
        require(bytes(message).length > 0, "Beacon: empty message");
        require(bytes(message).length <= 300, "Beacon: message too long");

        hasResponded[id][msg.sender] = true;
        b.responseCount++;

        responses[id].push(Response({
            responder: msg.sender,
            message: message,
            respondedAt: block.timestamp
        }));

        emit BeaconResponse(id, msg.sender, message);
    }

    function isActive(uint256 id) external view returns (bool) {
        require(id < beacons.length, "Beacon: invalid id");
        BeaconRecord memory b = beacons[id];
        return !b.extinguished && block.timestamp < b.expiresAt;
    }

    function getBeacon(uint256 id) external view returns (
        address emitter,
        string memory signal,
        string memory context,
        uint256 emittedAt,
        uint256 expiresAt,
        bool extinguished,
        uint256 responseCount,
        bool active
    ) {
        require(id < beacons.length, "Beacon: invalid id");
        BeaconRecord memory b = beacons[id];
        return (
            b.emitter,
            b.signal,
            b.context,
            b.emittedAt,
            b.expiresAt,
            b.extinguished,
            b.responseCount,
            !b.extinguished && block.timestamp < b.expiresAt
        );
    }

    function getResponse(uint256 beaconId, uint256 responseIndex) external view returns (
        address responder,
        string memory message,
        uint256 respondedAt
    ) {
        require(beaconId < beacons.length, "Beacon: invalid beacon id");
        require(responseIndex < responses[beaconId].length, "Beacon: invalid response index");
        Response memory r = responses[beaconId][responseIndex];
        return (r.responder, r.message, r.respondedAt);
    }

    function getBeaconsByAddress(address account) external view returns (uint256[] memory) {
        return beaconsByAddress[account];
    }

    function totalBeacons() external view returns (uint256) {
        return beacons.length;
    }
}
