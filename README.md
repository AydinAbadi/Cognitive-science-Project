# Cognitive-science-Project
The Value Creation-and Trading Project: VCaT Project ---Cognitive science


Owner: that owns the contract and adds/removes valid admins to/from the system

Admin:

1- Given a list of students’ numbers it registers them in the system. The list contains the list of students who enrolled in the course

2- Given a list of students’ addresses (in the blockchain network) it registers them to the system as well. The system ensures only those whose student number are registered can register their address.

3- When the admin registers the students addresses, it also allocates a fixed number of tokens (e.g. 10) to each.

4- Amin can also send additional tokens to students when needed.

Student:

1- Those students who enrolled in the course and have enough tokens can send tokens to each other. This creates a transaction.

2- Both sender and receiver of tokens can leave feedback, or give score, to each other. The score ranges in [-5,5].

3- Students can see the list of transactions they been involved in (this will be done via UI).

Smart contract stores:

1- Valid students’ numbers

2- Valid students’ addresses

3- Valid admin address

4- Token balance of each student

5- Total number of transactions made by each student. It includes the total number of tokens sent and received by the student.

6- Each token transaction in detail, i.e. who send how many tokens to whom for what reason.

7- Valid student’s reputation.

## Run with docker

docker run -v "`pwd`":/mnt ethereum/solc:0.5.0 mnt/ValuED.sol

