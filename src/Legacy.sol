// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Legacy
/// @notice A dead man's switch. Write a message to someone. Check in regularly to keep it sealed.
///         If you stop checking in for longer than your chosen silence window, the message unlocks
///         and your recipient can read it. Your last words, on-chain, forever.
contract Legacy {
    struct LegacyRecord {
        address author;
        address recipient;
        string message;
        string title;
        uint256 createdAt;
        uint256 lastCheckIn;
        uint256 silenceWindow;
        bool triggered;
        bool claimed;
    }

    LegacyRecord[] public legacies;

    mapping(address => uint256[]) public legaciesByAuthor;
    mapping(address => uint256[]) public legaciesByRecipient;

    event LegacyCreated(uint256 indexed id, address indexed author, address indexed recipient, string title, uint256 silenceWindow);
    event CheckedIn(uint256 indexed id, address indexed author, uint256 nextDeadline);
    event LegacyTriggered(uint256 indexed id, uint256 triggeredAt);
    event LegacyClaimed(uint256 indexed id, address indexed recipient);

    uint256 public constant MIN_SILENCE = 7 days;
    uint256 public constant MAX_SILENCE = 365 days;

    function create(
        address recipient,
        string calldata title,
        string calldata message,
        uint256 silenceWindow
    ) external returns (uint256) {
        require(recipient != address(0), "Legacy: zero address");
        require(recipient != msg.sender, "Legacy: cannot leave legacy to yourself");
        require(bytes(title).length > 0, "Legacy: empty title");
        require(bytes(message).length > 0, "Legacy: empty message");
        require(bytes(message).length <= 2000, "Legacy: message too long");
        require(silenceWindow >= MIN_SILENCE, "Legacy: silence window too short (min 7 days)");
        require(silenceWindow <= MAX_SILENCE, "Legacy: silence window too long (max 365 days)");

        uint256 id = legacies.length;

        legacies.push(LegacyRecord({
            author: msg.sender,
            recipient: recipient,
            message: message,
            title: title,
            createdAt: block.timestamp,
            lastCheckIn: block.timestamp,
            silenceWindow: silenceWindow,
            triggered: false,
            claimed: false
        }));

        legaciesByAuthor[msg.sender].push(id);
        legaciesByRecipient[recipient].push(id);

        emit LegacyCreated(id, msg.sender, recipient, title, silenceWindow);
        return id;
    }

    function checkIn(uint256 id) external {
        require(id < legacies.length, "Legacy: invalid id");
        LegacyRecord storage l = legacies[id];
        require(msg.sender == l.author, "Legacy: not your legacy");
        require(!l.triggered, "Legacy: already triggered");

        l.lastCheckIn = block.timestamp;

        emit CheckedIn(id, msg.sender, block.timestamp + l.silenceWindow);
    }

    /// @notice Anyone can trigger a legacy once the silence window has passed.
    ///         This separates triggering from claiming — the recipient doesn't
    ///         have to be the one watching the clock.
    function trigger(uint256 id) external {
        require(id < legacies.length, "Legacy: invalid id");
        LegacyRecord storage l = legacies[id];
        require(!l.triggered, "Legacy: already triggered");
        require(block.timestamp > l.lastCheckIn + l.silenceWindow, "Legacy: author still active");

        l.triggered = true;

        emit LegacyTriggered(id, block.timestamp);
    }

    function claim(uint256 id) external returns (string memory) {
        require(id < legacies.length, "Legacy: invalid id");
        LegacyRecord storage l = legacies[id];
        require(msg.sender == l.recipient, "Legacy: not the recipient");
        require(l.triggered, "Legacy: not yet triggered");

        if (!l.claimed) {
            l.claimed = true;
            emit LegacyClaimed(id, msg.sender);
        }

        return l.message;
    }

    function isTriggered(uint256 id) external view returns (bool) {
        require(id < legacies.length, "Legacy: invalid id");
        LegacyRecord memory l = legacies[id];
        return l.triggered || block.timestamp > l.lastCheckIn + l.silenceWindow;
    }

    function timeUntilTrigger(uint256 id) external view returns (uint256) {
        require(id < legacies.length, "Legacy: invalid id");
        LegacyRecord memory l = legacies[id];
        if (l.triggered) return 0;
        uint256 deadline = l.lastCheckIn + l.silenceWindow;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    function getMeta(uint256 id) external view returns (
        address author,
        address recipient,
        string memory title,
        uint256 createdAt,
        uint256 lastCheckIn,
        uint256 silenceWindow,
        bool triggered,
        bool claimed
    ) {
        require(id < legacies.length, "Legacy: invalid id");
        LegacyRecord memory l = legacies[id];
        return (l.author, l.recipient, l.title, l.createdAt, l.lastCheckIn, l.silenceWindow, l.triggered, l.claimed);
    }

    function getLegaciesByAuthor(address account) external view returns (uint256[] memory) {
        return legaciesByAuthor[account];
    }

    function getLegaciesByRecipient(address account) external view returns (uint256[] memory) {
        return legaciesByRecipient[account];
    }

    function totalLegacies() external view returns (uint256) {
        return legacies.length;
    }
}
