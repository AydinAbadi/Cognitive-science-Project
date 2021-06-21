// SPDX-License-Identifier: 
pragma solidity ^0.5.0;

/**
 * @author A B
 * @title ValuED contract - for cognitive science project
 */
contract ValuED {
    int public constant NO_FEEDBACK = -10;                /// Constant outside range to signify no feedback provided
    int public constant MAX_SCORE = 5;                    /// Maximum score (feedback) allowed
    int public constant MIN_SCORE = -5;                   /// Minimum score (feedback) allowed
    uint public constant LECTURE_TOKENS = 5;              /// Amount of tokens that can be claimed is fixed
    uint public constant REGISTRATION_TOKENS = 10;        /// Amount of (welcome) tokens given (to students) at registration
    
    address public manager;                               /// The owner, deployer and manager of the contract
    mapping (address => bool) public validStudent;        ///
    mapping (address => bool) public validAdmin;          ///
    uint public currentLectureNumber;                     /// Current lecture number
    
    uint public proposalsCount;                           /// Last proposal ID
    mapping (uint => Proposal) public proposals;          /// Proposals
    
    uint public transactionsCount;                        /// Last transaction ID
    mapping (uint => Transaction) public transactions;    /// mapping (uint transaction id/counter => Transaction)
    
    mapping (uint => StudentStatus) public studentStatus; /// Index: student numbers
    mapping (address => uint) public studentTokenBalance; ///
    mapping (address => uint) public tradedTokens;        /// keeps track of total tokens sent/recived by each student.
    mapping (address  => int) public reputations;         /// mapping (address reciver  => int score) 
    mapping (uint => bytes2) public hashLectureID;        /// lecture number => hash(lecture ID).
    mapping (address => (uint => bool)) public claimed;     /// 
    mapping (uint => uint) public lectureParticipants;    /// (uint lecture_number => uint number_of_students_claimed_tokens) lectureParticipants--  It stores  total number of students participated in a session/lecture
    
    /**
     * The status of students determines their registered status in the
     * current lecture.
     */
    struct StudentStatus {
        bool enrolled;   /// If the student is enrolled
        bool registered; /// It the student has been assigned tokens already
    }
    
    /**
     * The status of what student claimed relating to what lecture.
     */
    struct ClaimedStatus {
        address student;    /// Student that claimed tokens for a lecture
        uint lectureNumber; /// Lecture number of reference
    }
    
    /**
     * Valid users can propose any trades they wish and submit their proposal
     * that has the following structure. 
     */
    struct Proposal {
        uint tokens;     /// Tokens
        address creator; ///
        string email;    /// this is needed because the student that makes an offer may want to send token. 
                         /// in this case, the student who is interested can email and send to it, its public key. Then, the student who 
                         /// has made the offer can call sendToken() and uses the other student's address as the recipient. 
        string reason;   ///
        uint id;         ///
        bool active;     ///
    }

    /**
     * 
     */
    struct Transaction{
        address sender;       ///
        address reciever;     ///
        string reason;        ///
        int senderFeedback;   /// feedback provided by the sender to tokens.
        int receiverFeedback; /// feedback provided by  the reciever of tokens.
        uint id;              ///
        uint tokens;          /// number of tokens sent in this transaction.
        string creationTime;  ///
    }
    
    /**
     * Contract constructor.
     * The deployer (manager) will be administrator too.
     * 
     * @param admin administrator to add (apart from the manager)
     */
    constructor(address admin) public {
        manager = msg.sender;
        validAdmin[admin] = true;
        validAdmin[msg.sender] = true;
    }
    
    /**
     * Only an admin will be allowed.
     */
    modifier onlyAdmin() {
        require(validAdmin[msg.sender] == true);
        _;
    }
    
    /**
     * Only the manager will be allowed.
     */
    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }
    
    /**
     * Add an administrator.
     * 
     * @param admin administrator to add
     */
    function addAdmin(address admin) external onlyManager {
        validAdmin[admin] = true;
    }
    
    /**
     * Delete an administrator.
     * 
     * @param admin administrator to delete
     */
    function delAdmin(address admin) external onlyManager {
        validAdmin[admin] = false;
    }
    
    /**
     * Allows a valid admin to send some tokens to students.
     * 
     * @param student student whose balance will be increased
     * @param tokens tokens given to the student
     */
    function distributeToken(address student, uint tokens) external onlyAdmin {
        require(validStudent[student] == true);
        studentTokenBalance[student] += tokens;
    }
    
    /**
     * This function is called when a list of students enrolled for the course
     * is finalised.
     * 
     * @param studentNumber student number
     */
    function enrollStudent(uint studentNumber) external onlyAdmin {
        studentStatus[studentNumber].enrolled = true;
    }

    /**
     * Binds a (invalid) student to a student number that has been previously
     * enrolled and was not registered before.
     * 
     * @param student student to register
     * @param studentNumber student number assigned for current registration
     */
    function registerStudent(
        address student,
        uint studentNumber
    )
        external onlyAdmin
    {
        require(studentStatus[studentNumber].enrolled == true); // check if the student has enrolled the course
        require(studentStatus[studentNumber].registered == false); // ensures a student cannot registers itself with multiple public keys
        studentStatus[studentNumber].registered = true;
        validStudent[student] = true;
        studentTokenBalance[student] = REGISTRATION_TOKENS;
    }
    
    /**
     * Register a lecture identified by a string to the given lecture number.
     * 
     * @param lectureNumber the lecture number
     * @param lecture the string identifying the lecture
     */
    function registerLecture(
        uint lectureNumber,
        string calldata lecture
    )
        external onlyAdmin
    {
        hashLectureID[lectureNumber] = bytes2(keccak256(bytes(lecture)));
    }
    
    /**
     * Set the current lecture/course number.
     * 
     * @param lectureNumber the lecture number
     */
    function setCurrentLectureNumber(uint lectureNumber) external onlyAdmin {
        currentLectureNumber = lectureNumber;
    } 
   
    /**
     * This function allows a student to claim a fixed number of tokens
     * (LECTURE_TOKENS), if it could prove its attentance in a lecture
     * (e.g. by uploading a QR code in the UI). If approved (in the UI), then
     * the UI calls this function.
     * 
     * @param lecture the lecture (ID string) related with the token claim
     */
    function claimToken(string calldata lecture) external {
        require(validStudent[msg.sender] == true);
        require(hashLectureID[currentLectureNumber] == bytes2(keccak256(bytes(lecture))));
        
        /* 
         * Ensures the student has not already claimed any tokens for this
         * lecture yet. -- TODO future?: not enough if current lecture number
         * is set to a previous one - (admins are currently assumed to behave
         * honestly).
         */
        require(claimed[msg.sender][currentLectureNumber]);
        claimed[msg.sender][currentLectureNumber] = true;
        studentTokenBalance[msg.sender] += LECTURE_TOKENS;
        lectureParticipants[currentLectureNumber]++;
    }
    
    /**
     * In the UI, each student should be able to see a list of active offers
     * he/she has made. This allows the student to fetch specific offer ID
     * used in sendToken.
     * This function allows a student to post an offer on the UI. It can offer
     * to engage in an actitivy and specify how many tokens it is willing to
     * send or recieve.
     * 
     * @param tokens the price of the proposal
     * @param reason the reason describing the proposal
     * @param email email to send tokens later if public keys are sent too
     * known
     */
    function makeProposal(
        uint tokens,
        string calldata reason,
        string calldata email
    )
        external
    {
        require(validStudent[msg.sender] == true, "Not a valid sender");
        require(studentTokenBalance[msg.sender] >= tokens,"Not enough token");
        Proposal memory proposal;
        proposal.tokens = tokens;
        proposal.creator = msg.sender;
        proposal.email = email;
        proposal.reason = reason;
        proposalsCount++;
        proposal.id = proposalsCount;
        proposal.active = true;
        proposals[proposalsCount] = proposal;
    }
    
    /**
     * Send a token related to a proposal.
     * 
     * @param amount the amount of tokens to send
     * @param receiver the address to send tokens to
     * @param reason the description for the transaction
     * @param time the time for the transaction
     * @param proposalID the proposal ID that contains the (active) offer
     */
    function sendToken(
        uint amount,
        address receiver,
        string calldata reason,
        string calldata time,
        uint proposalID
    )
        external
    {
        require(msg.sender != receiver); // the sender should not be able to send token to itself and make a transaction. 
        require(validStudent[msg.sender] == true, "Not a valid sender");
        require(validStudent[receiver] == true, "Not a valid recipient"); // checks if the recipient is a valid student
        require(studentTokenBalance[msg.sender] >= amount,"Not enough token");  // check if the sender has enough token.
        require(proposals[proposalID].active == true, "Not an active offer");//check of the offer is active yet.
        require(amount > 0);
        //either the token recipient or the token sender should be in the creator of the offer_ID.
        require(msg.sender == proposals[proposalID].creator || receiver == proposals[proposalID].creator);
        proposals[proposalID].active = false;// recall only active offers should be desplayed on the UI.
        studentTokenBalance[msg.sender] -= amount;
        studentTokenBalance[receiver] += amount;
        tradedTokens[msg.sender] += amount; 
        tradedTokens[receiver] += amount;
        Transaction memory transaction;
        // stores each transaction's details in "transactions".
        transactionsCount += 1;
        transaction.sender = msg.sender;
        transaction.reciever = receiver;
        transaction.reason = reason;
        transaction.tokens = amount; 
        transaction.creationTime = time;
        transaction.id = transactionsCount;
        transaction.senderFeedback = NO_FEEDBACK;
        transaction.receiverFeedback = NO_FEEDBACK;
        transactions[transactionsCount] = transaction;
    }
    
    /**
     * The sender of the feedback needs to first check the list of the
     * transactions and see which transaction it wants to leave feedback, then
     * it needs to read the transaction ID.
     * 
     * @param transactionID the transaction ID of reference
     * @param score the feedback to leave
     */
    function leaveFeedback(uint transactionID, int score) external {
        require (MIN_SCORE <= score && score <= MAX_SCORE);
        (bool can, uint res) = canLeaveFeedback(msg.sender, transactionID);
        require(can);
//         require(res == 1 || res == 2); // TODO future?
        if (res == 1) {
            transactions[transactionID].senderFeedback = score; 
            reputations[transactions[transactionID].reciever] += score;
        } else if (res == 2) {
            transactions[transactionID].receiverFeedback = score; 
            reputations[transactions[transactionID].sender] += score;
        }
    }
    
    /**
     * This function tells whether a participant of a transaction can leave
     * a feedback (to the other participant).
     * 
     * @param sender the sender of the feedback
     * @param transactionID the transaction ID of reference
     * 
     * @return (can, res)
     */
    function canLeaveFeedback(
        address sender,
        uint transactionID
    )
        view
        internal
        returns (bool can, uint res)
    {
        if (
            transactions[transactionID].sender == sender
            && transactions[transactionID].senderFeedback == NO_FEEDBACK
        ) {
            res = 1;
            can = true;
        } else if (
            transactions[transactionID].reciever == sender
            && transactions[transactionID].receiverFeedback == NO_FEEDBACK
        ) {
            res = 2;
            can = true;
//         } else { // Not required?
//             res = 0;
//             can = false;
        }
    }
}
