pragma solidity ^0.4.2;

contract token { mapping(address=>uint256) public balanceOf; }

contract admined {
 address public admin;

 function admined(){
    admin = msg.sender;
 }

 modifier onlyAdmin(){
    if(msg.sender != admin) throw;
    _;
 }

 function transferAdminship(address newAdmin) onlyAdmin{
    admin = newAdmin;
 }

}

contract Association is admined {

    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    
    Proposal[] public proposals;
    uint public numProposals;

    
    token public sharesTokenAddress;

    modifier onlyShareholders {
        if(sharesTokenAddress.balanceOf(msg.sender) == 0) throw;
        _;
    }

    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint votingDeadline;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        int currentResult;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }

    struct Vote {
        bool inSupport;
        address voter;
    }

    /* First time setup */
    function Association(
        address sharesAddress,
        uint minimumSharesToPassAVote,
        uint minutesForDebate,
        address leader) payable {
        changeVotingRules(sharesAddress, minimumSharesToPassAVote, minutesForDebate);
        if(leader == 0) admin = msg.sender;
        else admin = leader;

    }

    /*change rules*/
    function changeVotingRules(
        address sharesAddress,
        uint minimumSharesToPassAVote,
        uint minutesForDebate) onlyAdmin {
        sharesTokenAddress = token(sharesAddress);
        if(minimumSharesToPassAVote == 0) minimumSharesToPassAVote = 1;
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;

    }

    /* Function to create a new proposal */
    function newProposal(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode) onlyShareholders returns (uint proposalID){

        proposalID = proposals.length;
        proposals.length = proposals.length + 1;
        Proposal p = proposals[proposalID];
        p.recipient = beneficiary;
        p.amount = etherAmount;
        p.description = jobDescription;
        p.proposalHash = sha3(beneficiary, etherAmount, transactionBytecode);
        p.votingDeadline = now + debatingPeriodInMinutes * 1 minutes;
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        numProposals = proposalID+1;
        return proposalID;
    }

    /* function to check if a proposal code matches */
    function checkProposalCode(
        uint proposalNumber, 
        address beneficiary, 
        uint etherAmount, 
        bytes transactionBytecode) constant returns (bool codeChecksOut){
        Proposal p = proposals[proposalNumber];
        return p.proposalHash == sha3(beneficiary, etherAmount, transactionBytecode);
    }

    function vote(
        uint proposalNumber,
        bool supportsProposal) onlyShareholders returns (uint voteID){
        Proposal p = proposals[proposalNumber];
        if(p.voted[msg.sender]) throw;
        p.voted[msg.sender] = true;
        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProposal, voter: msg.sender});
        p.numberOfVotes++;
        return voteID;
    }

    function executeProposal(uint proposalNumber, bytes transactionBytecode) {
        
     Proposal p = proposals[proposalNumber];
      
      if(now < p.votingDeadline || 
        p.executed ||
        p.proposalHash != sha3(p.recipient, p.amount, transactionBytecode)
        )
      throw;

      uint quorum = 0;
      uint yea = 0;
      uint nay = 0;

      for(uint i=0; i< p.votes.length; i++){
        Vote v = p.votes[i];
        uint voteWeight = sharesTokenAddress.balanceOf(v.voter);
        quorum +=voteWeight;
        if(v.inSupport){
            yea += voteWeight;
        }
        else{
            nay += voteWeight;
        }
      }

      if(quorum <= minimumQuorum){
        throw;
      }
      else if(yea > nay){
        p.executed = true;
        if(!p.recipient.call.value(p.amount * 1 ether)(transactionBytecode)){
            throw;
        }
        p.proposalPassed = true;
      }
      else{
        p.proposalPassed = false;
      }
    }

    function () payable {
    }


}