pragma solidity ^0.5.0;

contract CogScience_project {
    
    int public max_score;
    int public min_score;
    uint public totalNum_transactions; // it's used as transaction's ID too.
    uint public totalNum_proposals;
    uint public lecture_tokens; // it keeps a fixed number of tokens.
    uint public current_lecture_number;
    address public owner;
    mapping (uint => Pair) public valid_student_num; 
    mapping (uint => Proposal) public proposals;
    mapping (address => bool) public valid_student_addr;
    mapping (address => bool) public valid_admins;
    mapping (address => uint) public student_token_balance;
    mapping (address => uint) public totalNumOf_tokens_traded; // keeps track of total tokens sent/recived by each student.
    mapping (address  => int) public reputations; // mapping (address reciver  => int score) 
    mapping (uint => Transaction) public transactions; // mapping (uint transaction id/counter => Transaction)
    mapping (uint => bytes2) public hash_lectureID; // lecture number => hash(lecture ID).
    mapping (address => uint) public attended; 
    mapping (uint => uint) public total_participants;// (uint lecture_number => uint number_of_students_claimed_tokens) total_participants--  It stores  total number of students participated in a session/lecture
    
    struct Pair{
       
        bool validStudent_num;
        bool token_assigned;
    }
    
    struct Proposal{
        
        uint numOf_tokens;
        address creator_address;
        string creator_emailAdress;// this is needed because the student that makes an offer may want to send token. 
        // in this case, the student who is interested can email and send to it, its public key. Then, the student who 
        // has made the offer can call send_token() and uses the other student's address as the recipient. 
        string reason;
        uint proposal_ID;
        bool active;
    }

    struct Transaction{
        
        address sender;
        address reciever;
        string reason; 
        int TokenSender_feedback; // feedback provided by the sender to tokens.
        int TokenReciever_feedback; // feedback provided by  the reciever of tokens.
        uint transaction_ID;
        uint numOf_tokens; // number of tokens sent in this transaction.
        string creation_time;
    }
    
    constructor(address admin) public{
        
        owner = msg.sender;
        valid_admins[admin] = true;
        valid_admins[msg.sender] = true; // so the deployer can be admin too.
        max_score = 5;
        min_score = -5;
        lecture_tokens = 5;
    }
    
    modifier only_admin(){
        
        require(valid_admins[msg.sender] == true);
        _;
    }
    
    modifier only_owner(){
        
        require(msg.sender == owner);
        _;
    }
    
    function add_admin(address new_admin) external only_owner{
        
        valid_admins[new_admin] = true;
    }
    
    function remove_admin(address admin) external only_owner{
        
        valid_admins[admin] = false;
    }
    
    // Allows a valid admin to send some tokens to students.
    function distribute_token(address std_addr, uint numOf_tokens) external only_admin{
        
        require(valid_student_addr[std_addr] == true);
        student_token_balance[std_addr] += numOf_tokens;
    }
    
    function register_std_num(uint std_num) external only_admin{ // this is done when a list of students enroled for the course is finalised. 
        
        valid_student_num[std_num].validStudent_num = true;
    }

    function register_std_addr(address std_addr, uint std_num) external only_admin{
        
         require(valid_student_num[std_num].validStudent_num == true); // check if the student has enroled the course
         require(valid_student_num[std_num].token_assigned == false); // ensures a student cannot registers itself with multiple public keys
         valid_student_num[std_num].token_assigned = true;
         valid_student_addr[std_addr] = true;
         student_token_balance[std_addr] = 10; // it allocates 10 tokens to the regitered student.
    }
    
    function register_lectureID(uint lecture_number, string calldata lec_ID) external only_admin{
        
        hash_lectureID[lecture_number] = bytes2(keccak256(bytes(lec_ID)));// a hash value of the lecture is stored in the contract. 
    }
    
   function set_currentlecture_number(uint num) external only_admin{
       
       current_lecture_number = num;
   } 
     // This function allows a student to claim a fixed number of tokens (lecture_tokens), if it could prove its attentance in a lecture  (e.g. by uploading a QR code in the UI). If approved 
    // (in the UI) then UI calls this function. 
    function claim_token(string calldata input_) external{
        
        require(valid_student_addr[msg.sender] == true);// checks if it's a valid student
        require(hash_lectureID[current_lecture_number] == bytes2(keccak256(bytes(input_))));//checks if the student has sent a valid id 
        require(attended[msg.sender] != current_lecture_number);// ensures the student has not already claimed any tokens for this lecture yet.
        attended[msg.sender] = current_lecture_number;
        student_token_balance[msg.sender] += lecture_tokens;
        total_participants[current_lecture_number]++;
    }
    
    // in the UI, each student should be able to see a list of active offers he/she has made. This allows the student
    // to fetch specific offer ID used in send_token. //  
    // This function allows a student to post an offer on the UI. It can offer to engage in an actitivy and specify how many tokens it is willing to send or recieve.
    function makeProposal(uint numOf_tokens_, string calldata reason_, string calldata email_address_) external{
        
        require(valid_student_addr[msg.sender] == true, "Not a valid sender");
        require(student_token_balance[msg.sender] >= numOf_tokens_,"Not enough token");
        Proposal memory proposal_;
        proposal_.numOf_tokens = numOf_tokens_;
        proposal_.creator_address = msg.sender;
        proposal_.creator_emailAdress = email_address_;
        proposal_.reason = reason_;
        totalNum_proposals++;
        proposal_.proposal_ID = totalNum_proposals;
        proposal_.active = true;
        proposals[totalNum_proposals] = proposal_;
    }
    
    function send_token(uint amount, address recipient_address, string calldata _reason,string calldata time_, uint offer_ID_) external{
        
        require(msg.sender!=recipient_address); // the sender should not be able to send token to itself and make a transaction. 
        require(valid_student_addr[msg.sender] == true, "Not a valid sender"); // checks if the sender is a valid student
        require(valid_student_addr[recipient_address] == true, "Not a valid recipient"); // checks if the recipient is a valid student
        require(student_token_balance[msg.sender] >= amount,"Not enough token");  // check if the sender has enough token.
        require(proposals[offer_ID_].active == true, "Not an active offer");//check of the offer is active yet.
        require(amount > 0);
        //either the token recipient or the token sender should be in the creator of the offer_ID.
        require(msg.sender == proposals[offer_ID_].creator_address || recipient_address == proposals[offer_ID_].creator_address);
        proposals[offer_ID_].active = false;// recall only active offers should be desplayed on the UI.
        student_token_balance[msg.sender] -= amount;
        student_token_balance[recipient_address] += amount;
        totalNumOf_tokens_traded[msg.sender] += amount; 
        totalNumOf_tokens_traded[recipient_address] += amount;
        Transaction memory trans;
        // stores each transaction's details in "transactions".
        totalNum_transactions += 1;
        trans.sender = msg.sender;
        trans.reciever = recipient_address;
        trans.reason = _reason;
        trans.numOf_tokens = amount; 
        trans.creation_time = time_;
        trans.transaction_ID = totalNum_transactions;
        trans.TokenSender_feedback = -10; // we allocate -10 to show no feedback has been provided. Note that 0 is among valid scores and it's also a default value for uint types. 
        trans.TokenReciever_feedback = -10; // see above
        transactions[totalNum_transactions] = trans;
    }
    
    function canLeave_feedback(address feedback_sender, uint transaction_id) internal returns (bool can, uint res){ 
        
        // checks if the person who wants to leave the feedback is sender of tokens AND has not left any feedback for the transaction.
        if(transactions[transaction_id].sender == feedback_sender && transactions[transaction_id].TokenSender_feedback == -10){
            res = 1;
            can = true;
        }
        // checks if the person who wants to leave the feedback is reciever of tokens AND has not left any feedback for the transaction.
        else if(transactions[transaction_id].reciever == feedback_sender && transactions[transaction_id].TokenReciever_feedback == -10){
            res = 2;
            can = true;
        }
    }
    // the sender of the feedback needs to first check the list of the transactions and see which transaction it wants to leave feedback 
    // then it needs to read the transaction ID. 
    function leave_feedback(uint transaction_id, int score) external{
       
        require (min_score <= score && score <= max_score);  // check if the score is valid: min_score <= score <= max_score
        (bool can, uint res) = canLeave_feedback(msg.sender, transaction_id); // check if the the sender of the feedback is one of the parties involded in the transaction and has not already left any feedback yet. 
        require(can);
        if (res == 1){ 
            transactions[transaction_id].TokenSender_feedback = score; 
            reputations[transactions[transaction_id].reciever] += score;
        }
        else if (res == 2){ 
            transactions[transaction_id].TokenReciever_feedback = score; 
            reputations[transactions[transaction_id].sender] += score;
        }
    }
}
