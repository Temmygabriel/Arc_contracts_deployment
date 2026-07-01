// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GoodsEscrow
/// @notice Buyer funds escrow in native USDC for a physical/digital good. Seller marks
///         the order shipped. Buyer confirms receipt to release funds, or can raise a
///         dispute, which freezes funds for a designated arbiter to resolve.
contract GoodsEscrow {
    enum Status { AwaitingPayment, Paid, Shipped, Disputed, Released, Refunded }

    struct Order {
        address buyer;
        address seller;
        address arbiter;
        string itemDescription;
        uint256 amount;
        uint256 createdAt;
        Status status;
    }

    Order[] public orders;
    mapping(address => uint256[]) public ordersByBuyer;
    mapping(address => uint256[]) public ordersBySeller;

    event OrderCreated(uint256 indexed id, address indexed buyer, address indexed seller, address arbiter, uint256 amount, string itemDescription);
    event OrderPaid(uint256 indexed id, uint256 amount);
    event OrderShipped(uint256 indexed id);
    event OrderDisputed(uint256 indexed id, address indexed by);
    event OrderResolved(uint256 indexed id, address indexed winner, uint256 amount);

    function createOrder(
        address seller,
        address arbiter,
        string calldata itemDescription,
        uint256 amount
    ) external returns (uint256) {
        require(seller != address(0), "GoodsEscrow: zero seller");
        require(seller != msg.sender, "GoodsEscrow: buyer cannot be seller");
        require(arbiter != address(0), "GoodsEscrow: zero arbiter");
        require(arbiter != msg.sender && arbiter != seller, "GoodsEscrow: arbiter must be neutral");
        require(amount > 0, "GoodsEscrow: zero amount");
        require(bytes(itemDescription).length > 0, "GoodsEscrow: empty description");

        uint256 id = orders.length;
        orders.push(Order({
            buyer: msg.sender,
            seller: seller,
            arbiter: arbiter,
            itemDescription: itemDescription,
            amount: amount,
            createdAt: block.timestamp,
            status: Status.AwaitingPayment
        }));

        ordersByBuyer[msg.sender].push(id);
        ordersBySeller[seller].push(id);

        emit OrderCreated(id, msg.sender, seller, arbiter, amount, itemDescription);
        return id;
    }

    function payOrder(uint256 id) external payable {
        require(id < orders.length, "GoodsEscrow: invalid id");
        Order storage o = orders[id];
        require(msg.sender == o.buyer, "GoodsEscrow: not the buyer");
        require(o.status == Status.AwaitingPayment, "GoodsEscrow: not awaiting payment");
        require(msg.value == o.amount, "GoodsEscrow: incorrect amount");

        o.status = Status.Paid;
        emit OrderPaid(id, msg.value);
    }

    function markShipped(uint256 id) external {
        require(id < orders.length, "GoodsEscrow: invalid id");
        Order storage o = orders[id];
        require(msg.sender == o.seller, "GoodsEscrow: not the seller");
        require(o.status == Status.Paid, "GoodsEscrow: not paid");

        o.status = Status.Shipped;
        emit OrderShipped(id);
    }

    function confirmReceipt(uint256 id) external {
        require(id < orders.length, "GoodsEscrow: invalid id");
        Order storage o = orders[id];
        require(msg.sender == o.buyer, "GoodsEscrow: not the buyer");
        require(o.status == Status.Shipped, "GoodsEscrow: not shipped");

        o.status = Status.Released;
        (bool ok, ) = o.seller.call{value: o.amount}("");
        require(ok, "GoodsEscrow: transfer failed");

        emit OrderResolved(id, o.seller, o.amount);
    }

    function dispute(uint256 id) external {
        require(id < orders.length, "GoodsEscrow: invalid id");
        Order storage o = orders[id];
        require(msg.sender == o.buyer || msg.sender == o.seller, "GoodsEscrow: not a participant");
        require(o.status == Status.Paid || o.status == Status.Shipped, "GoodsEscrow: cannot dispute now");

        o.status = Status.Disputed;
        emit OrderDisputed(id, msg.sender);
    }

    /// @notice Arbiter resolves a dispute, sending the full escrowed amount to the winner.
    function resolveDispute(uint256 id, address winner) external {
        require(id < orders.length, "GoodsEscrow: invalid id");
        Order storage o = orders[id];
        require(msg.sender == o.arbiter, "GoodsEscrow: not the arbiter");
        require(o.status == Status.Disputed, "GoodsEscrow: not disputed");
        require(winner == o.buyer || winner == o.seller, "GoodsEscrow: winner must be a participant");

        o.status = winner == o.buyer ? Status.Refunded : Status.Released;

        (bool ok, ) = winner.call{value: o.amount}("");
        require(ok, "GoodsEscrow: transfer failed");

        emit OrderResolved(id, winner, o.amount);
    }

    function getOrder(uint256 id) external view returns (
        address buyer,
        address seller,
        address arbiter,
        string memory itemDescription,
        uint256 amount,
        uint256 createdAt,
        Status status
    ) {
        require(id < orders.length, "GoodsEscrow: invalid id");
        Order memory o = orders[id];
        return (o.buyer, o.seller, o.arbiter, o.itemDescription, o.amount, o.createdAt, o.status);
    }

    function getOrdersByBuyer(address account) external view returns (uint256[] memory) {
        return ordersByBuyer[account];
    }

    function getOrdersBySeller(address account) external view returns (uint256[] memory) {
        return ordersBySeller[account];
    }

    function totalOrders() external view returns (uint256) {
        return orders.length;
    }
}
