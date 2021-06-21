// SPDX-License-Identifier: GPL 3.0 
pragma solidity ^0.5.0;

/**
 * @author Aydin Abadi
 * @title ValuED contract
 */
contract ValuED {
    /* _________
     * Constants
     */
    int public constant NO_FEEDBACK = -10;                /// Constant outside range to signify no feedback provided
    int public constant MAX_SCORE = 5;                    /// Maximum score (feedback) allowed
    int public constant MIN_SCORE = -5;                   /// Minimum score (feedback) allowed
    uint public constant LECTURE_TOKENS = 5;              /// Amount of tokens that can be claimed is fixed
    uint public constant REGISTRATION_TOKENS = 10;        /// Amount of (welcome) tokens given (to students) at registration
    
    /* _______________
     * Management/Info
     */
    address public manager;                               /// The owner, deployer and manager of the contract
    mapping (address => bool) public validStudent;        /// Valid students (registered)
    mapping (address => bool) public validAdmin;          /// Valid administrators
    uint public currentLectureNumber;                     /// Current lecture number
    mapping (uint => StudentStatus) public studentStatus; /// Index: student numbers
    mapping (address => uint) public studentBalance;      /// Student's balance
    mapping (uint => bytes2) public hashLectureID;        /// lecture number => hash(lecture ID).
    mapping (address => uint) public claimed;             /// Binds a student's address to a lecture number to signify they claimed the related tokens
    mapping (uint => uint) public lectureParticipants;    /// Index: lecture number
    
    /* ___________________
     * Peer-to-peer trades
     */
    uint public proposalsCount;                           /// Last proposal ID
    mapping (uint => Proposal) public proposals;          /// Proposals
    
    uint public transactionsCount;                        /// Last transaction ID
    mapping (uint => Transaction) public transactions;    /// Transactions
    
    mapping (address => int) public reputations;          /// Users' current scores
    mapping (address => uint) public tradedTokens;        /// Total tokens traded by user
    
    
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
        uint tokens;     /// Tokens required for this proposal (sent or received)
        address creator; /// Who offers the proposal
        string email;    /// Used to exchange extra information
        string reason;   /// Description of the proposal
        uint id;         /// The ID of the proposal
        bool active;     /// An active proposal is one where tokens have not been transferred yet
    }

    /**
     * A transaction is created when tokens are transferred from an users
     * to another.
     */
    struct Transaction{
        address sender;       /// Who sends the tokens
        address receiver;     /// Who receives the tokens
        string reason;        /// Description of the transaction
        int senderFeedback;   /// Feedback provided by the sender
        int receiverFeedback; /// Feedback provided by the receiver
        uint id;              /// The ID of the transaction
        uint tokens;          /// Tokens transferred in this transaction
        string creationTime;  /// Time of creation
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
        studentBalance[student] += tokens;
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
        require(studentStatus[studentNumber].enrolled == true);
        require(studentStatus[studentNumber].registered == false);
        studentStatus[studentNumber].registered = true;
        
        validStudent[student] = true;
        studentBalance[student] = REGISTRATION_TOKENS;
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
        require(
            hashLectureID[currentLectureNumber]
            == bytes2(keccak256(bytes(lecture)))
        );
        
        /* 
         * Ensures the student has not already claimed any tokens for this
         * lecture yet.
         * TODO future?: not enough if current lecture number is set to a
         * previous one.
         * - admins are currently assumed to behave honestly)
         * - currentLectureNumber is expected to change in weeks (>= 1 week)
         */
        require(claimed[msg.sender] != currentLectureNumber);
        
        claimed[msg.sender] = currentLectureNumber;
        studentBalance[msg.sender] += LECTURE_TOKENS;
        lectureParticipants[currentLectureNumber]++;
    }
    
    /**
     * In the UI, each student should be able to see a list of active offers
     * he/she has made. This allows the student to fetch specific offer ID
     * used in sendTokens.
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
        require(studentBalance[msg.sender] >= tokens, "Not enough token");
        
        Proposal memory proposal;
        proposalsCount++;
        proposal.tokens = tokens;
        proposal.creator = msg.sender;
        proposal.email = email;
        proposal.reason = reason;
        proposal.id = proposalsCount;
        proposal.active = true;
        proposals[proposalsCount] = proposal;
    }
    
    /**
     * Send a token related to a proposal.
     * 
     * @param tokens the amount of tokens to send
     * @param receiver the address to send tokens to
     * @param reason the description for the transaction
     * @param time the time for the transaction
     * @param proposalID the proposal ID that contains the (active) offer
     */
    function sendTokens(
        uint tokens,
        address receiver,
        string calldata reason,
        string calldata time,
        uint proposalID
    )
        external
    {
        require(msg.sender != receiver);
        require(validStudent[msg.sender] == true, "Not a valid sender");
        require(validStudent[receiver] == true, "Not a valid recipient");
        require(
            studentBalance[msg.sender] >= tokens,
            "Not enough tokens"
        );
        require(proposals[proposalID].active == true, "Not an active offer");
        require(tokens > 0);
        
        /*
         * Either the token recipient or the token sender should be in the
         * creator of the offer_ID
         */
        require(
            msg.sender == proposals[proposalID].creator
            || receiver == proposals[proposalID].creator
        );
        
        // Only active offers should be desplayed on the UI.
        proposals[proposalID].active = false;
        
        // Adjust balance and keep track of traded tokens
        studentBalance[msg.sender] -= tokens;
        studentBalance[receiver] += tokens;
        tradedTokens[msg.sender] += tokens; 
        tradedTokens[receiver] += tokens;
        
        // Create the transaction for sending tokens
        Transaction memory transaction;
        transactionsCount++;
        transaction.sender = msg.sender;
        transaction.receiver = receiver;
        transaction.reason = reason;
        transaction.tokens = tokens; 
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
        require(can /* && (res == 1 || res == 2) TODO future? */);
//         
        if (res == 1) {
            transactions[transactionID].senderFeedback = score; 
            reputations[transactions[transactionID].receiver] += score;
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
            transactions[transactionID].receiver == sender
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
