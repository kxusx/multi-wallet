4 main functions

Submit Transaction - A user can propose a transaction 
Confirm Transaction - Other users can verify this proposed transaction
Execute Transaction - If a certain no of users confirm the transaction, any user can execute it
Revoke Transaction -  Before a transaction is executed, a owner who had previously given confirmation can revoke it

For each function, there is an event specified. There is also an event Deposit when ether is meant to be sent to the wallet(no approvals are required for this, and any wallet can do it).

address[] public owners; - list of owners of the wallet
uint public numConfirmationsRequired; - threshold of owners required to confirm transaction  
