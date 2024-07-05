//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract MultiSigWallet {
	event Deposit(address indexed sender, uint amount);
	event Submit(uint indexed txId);
	event Approve(address indexed sender, uint indexed txId);
	event Execute(uint indexed txId);
	event Revoke(address indexed sender, uint indexed txId);

	address[] public owners;
	mapping(address => bool) public isOwner;
	uint public required;

	struct Transaction {
		address to;
		uint value;
		bytes data;
		bool executed;
	}

	Transaction[] public transactions;

	mapping(uint => mapping(address => bool)) public approved;

	modifier onlyOwner() {
		require(isOwner[msg.sender], "not owner.");
		_;
	}

	modifier txExists(uint _txId) {
		require(_txId < transactions.length, "Transaction does not exist.");
		_;
	}

	modifier notApproved(uint _txId) {
		require(!approved[_txId][msg.sender], "Already approved.");
		_;
	}

	modifier notExecuted(uint _txId) {
		require(!transactions[_txId].executed, "Transaction already executed.");
		_;
	}

	constructor(address[] memory _owners, uint _required) {
		require(_owners.length > 0, "Owner must be more than 1.");
		require(
			_required > 0 && _required <= _owners.length,
			"Invalid required length."
		);

		for (uint i; i < _owners.length; i++) {
			address owner = _owners[i];
			require(owner != address(0), "Invalid owner");
			require(!isOwner[owner], "The owner exists!");

			isOwner[owner] = true;
			owners.push(owner);
		}
		required = _required;
	}

	receive() external payable {
		emit Deposit(msg.sender, msg.value);
	}

	function submit(
		address _to,
		uint _value,
		bytes calldata _data
	) external onlyOwner {
		transactions.push(
			Transaction({
				to: _to,
				value: _value,
				data: _data,
				executed: false
			})
		);

		emit Submit(transactions.length - 1);
	}

	function approve(
		uint _txId
	) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
		approved[_txId][msg.sender] = true;
		emit Approve(msg.sender, _txId);
	}

	function _getApprovalCount(uint _txId) private view returns (uint count) {
		for (uint i; i < owners.length; i++) {
			if (approved[_txId][owners[i]]) {
				count++;
			}
		}
	}

	function execute(
		uint _txId
	) external onlyOwner txExists(_txId) notExecuted(_txId) {
		require(_getApprovalCount(_txId) >= required, "Not enough approvals.");

		Transaction storage transaction = transactions[_txId];
		(bool success, ) = transaction.to.call{ value: transaction.value }(
			transaction.data
		);

		require(success, "Tx failed!");
		transaction.executed = true;

		emit Execute(_txId);
	}

	function revoke(
		uint _txId
	) external onlyOwner txExists(_txId) notExecuted(_txId) {
		require(
			approved[_txId][msg.sender],
			"You didn't approved this transaction."
		);
		approved[_txId][msg.sender] = false;

		emit Revoke(msg.sender, _txId);
	}
}
