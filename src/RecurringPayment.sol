// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RecurringPayment
/// @notice A payer pre-funds a subscription with native USDC. The payee can "pull" one
///         payment per interval until either the funded balance or the maximum number
///         of payments is exhausted. The payer can cancel anytime and reclaim whatever
///         remains unpulled.
contract RecurringPayment {
    struct Subscription {
        address payer;
        address payee;
        uint256 amountPerPeriod;
        uint256 interval;
        uint256 balance;
        uint256 paymentsMade;
        uint256 maxPayments;
        uint256 lastPaidAt;
        uint256 createdAt;
        bool active;
    }

    Subscription[] public subscriptions;
    mapping(address => uint256[]) public subscriptionsByPayer;
    mapping(address => uint256[]) public subscriptionsByPayee;

    event SubscriptionCreated(uint256 indexed id, address indexed payer, address indexed payee, uint256 amountPerPeriod, uint256 interval, uint256 maxPayments);
    event PaymentPulled(uint256 indexed id, uint256 amount, uint256 paymentsMade);
    event SubscriptionCancelled(uint256 indexed id, uint256 refundedAmount);
    event SubscriptionToppedUp(uint256 indexed id, uint256 amount);

    uint256 public constant MIN_INTERVAL = 1 hours;

    function createSubscription(
        address payee,
        uint256 amountPerPeriod,
        uint256 interval,
        uint256 maxPayments
    ) external payable returns (uint256) {
        require(payee != address(0), "RecurringPayment: zero payee");
        require(payee != msg.sender, "RecurringPayment: payee cannot be payer");
        require(amountPerPeriod > 0, "RecurringPayment: zero amount");
        require(interval >= MIN_INTERVAL, "RecurringPayment: interval too short");
        require(maxPayments > 0, "RecurringPayment: zero max payments");
        require(msg.value > 0, "RecurringPayment: must fund something");

        uint256 id = subscriptions.length;
        subscriptions.push(Subscription({
            payer: msg.sender,
            payee: payee,
            amountPerPeriod: amountPerPeriod,
            interval: interval,
            balance: msg.value,
            paymentsMade: 0,
            maxPayments: maxPayments,
            lastPaidAt: 0,
            createdAt: block.timestamp,
            active: true
        }));

        subscriptionsByPayer[msg.sender].push(id);
        subscriptionsByPayee[payee].push(id);

        emit SubscriptionCreated(id, msg.sender, payee, amountPerPeriod, interval, maxPayments);
        return id;
    }

    function topUp(uint256 id) external payable {
        require(id < subscriptions.length, "RecurringPayment: invalid id");
        Subscription storage s = subscriptions[id];
        require(msg.sender == s.payer, "RecurringPayment: not the payer");
        require(s.active, "RecurringPayment: not active");
        require(msg.value > 0, "RecurringPayment: zero top up");

        s.balance += msg.value;
        emit SubscriptionToppedUp(id, msg.value);
    }

    function pullPayment(uint256 id) external {
        require(id < subscriptions.length, "RecurringPayment: invalid id");
        Subscription storage s = subscriptions[id];
        require(msg.sender == s.payee, "RecurringPayment: not the payee");
        require(s.active, "RecurringPayment: not active");
        require(s.paymentsMade < s.maxPayments, "RecurringPayment: max payments reached");
        require(s.balance >= s.amountPerPeriod, "RecurringPayment: insufficient balance");
        require(
            s.lastPaidAt == 0 || block.timestamp >= s.lastPaidAt + s.interval,
            "RecurringPayment: too early"
        );

        s.balance -= s.amountPerPeriod;
        s.paymentsMade++;
        s.lastPaidAt = block.timestamp;

        (bool ok, ) = s.payee.call{value: s.amountPerPeriod}("");
        require(ok, "RecurringPayment: transfer failed");

        emit PaymentPulled(id, s.amountPerPeriod, s.paymentsMade);

        if (s.paymentsMade == s.maxPayments) {
            s.active = false;
        }
    }

    function cancel(uint256 id) external {
        require(id < subscriptions.length, "RecurringPayment: invalid id");
        Subscription storage s = subscriptions[id];
        require(msg.sender == s.payer, "RecurringPayment: not the payer");
        require(s.active, "RecurringPayment: not active");

        s.active = false;
        uint256 refund = s.balance;
        s.balance = 0;

        if (refund > 0) {
            (bool ok, ) = s.payer.call{value: refund}("");
            require(ok, "RecurringPayment: refund failed");
        }

        emit SubscriptionCancelled(id, refund);
    }

    function nextPaymentAt(uint256 id) external view returns (uint256) {
        require(id < subscriptions.length, "RecurringPayment: invalid id");
        Subscription memory s = subscriptions[id];
        if (s.lastPaidAt == 0) return block.timestamp;
        return s.lastPaidAt + s.interval;
    }

    function getSubscription(uint256 id) external view returns (
        address payer,
        address payee,
        uint256 amountPerPeriod,
        uint256 interval,
        uint256 balance,
        uint256 paymentsMade,
        uint256 maxPayments,
        uint256 lastPaidAt,
        bool active
    ) {
        require(id < subscriptions.length, "RecurringPayment: invalid id");
        Subscription memory s = subscriptions[id];
        return (s.payer, s.payee, s.amountPerPeriod, s.interval, s.balance, s.paymentsMade, s.maxPayments, s.lastPaidAt, s.active);
    }

    function getSubscriptionsByPayer(address account) external view returns (uint256[] memory) {
        return subscriptionsByPayer[account];
    }

    function getSubscriptionsByPayee(address account) external view returns (uint256[] memory) {
        return subscriptionsByPayee[account];
    }

    function totalSubscriptions() external view returns (uint256) {
        return subscriptions.length;
    }
}
