// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// owners - ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
// recpt - 0x617F2E2fD72FD9D5503197092aC168c91465E7f2


contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance); // no approval reqd
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;
    uint public balance;
    uint public minBalance; // min balance required in wallet

    struct Transaction {
        address to; // receptient
        uint value; 
        bytes data; // additional data may be shared
        bool executed; // indicates if transaction has been executed
        uint numConfirmations; 
        // who submitted transaction
        address proposerAddress;
    }

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed; 
    // !!! will add this in the struct of transaction later, faced issues constructing transaction struct in submitTransaction !!!
    
    // keep track of all owners deposits in the wallet
    mapping(address => uint) public ownerDeposits;

    Transaction[] public transactions;

    // confirms if msg sender is an owner of the wallet
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    modifier proposer(uint _txIndex){
        require(transactions[_txIndex].proposerAddress == msg.sender, "not proposer");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired, uint _minBalance) {
        require(_owners.length > 0, "owners required"); // array of owners is not empty 
        require( _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique"); // to check if owner doesn't already exist  

            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;
        minBalance = _minBalance;
        balance = 0;
    }

    function deposit() external payable {
        balance += msg.value;
        // check if its owner depositing then increase ownerDeposits 
        if(isOwner[msg.sender]){
            ownerDeposits[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // SUBMIT TRANSACTION
    function submitTransaction(address _to, uint _value, bytes memory _data) 
        public 
        onlyOwner 
    {
        uint txIndex = transactions.length;

        // check for min balance in wallet
        require(address(this).balance >= minBalance*1000000000000000000, "insufficient funds");

        // check if this owner has deposited enough funds
        require(ownerDeposits[msg.sender] >= _value*1000000000000000000, "owner should contribute more");

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0,
                proposerAddress: msg.sender
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex) // owner should not have already confirmed the transaction yet
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        proposer(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        ownerDeposits[transaction.proposerAddress] -= transaction.value*1000000000000000000;

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
