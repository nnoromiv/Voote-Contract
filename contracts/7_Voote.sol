// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract Voote {

    // STRUCTURES

    struct Election {
        string electionTitle;
        address creator;
        uint32 startTime;
        uint32 endTime;
        uint8 candidateCount;
        bool isActive;
        bool resultsVisible;
    }

    struct Candidate {
        string candidateName;
        address candidateAddress;
        uint16 voteCount;
    }

    // STATE VARIABLES
    uint16 public totalPossibleElection = 256;
    uint8 public constant maxAdminPerElection = 10;
    uint16 public electionCounter;

    mapping(uint16 => Election) public elections;
    mapping(uint16 => mapping(uint8 => Candidate)) public electionCandidates;
    mapping(uint16 => mapping(address => bool)) public hasVoted;
    mapping(uint16 => mapping(address => bool)) public isCandidateRegistered;
    mapping(uint16 => mapping(address => bool)) public isBannedFromElection;
    mapping(uint16 => mapping(address => bool)) public isElectionAdmin;
    mapping(uint16 => address[]) private electionAdmins;

    uint16[] public allElectionIds;

    // EVENTS

    event ElectionCreated(uint16 indexed electionId, string title);
    event CandidateRegistered(uint16 indexed electionId, uint8 indexed candidateId, string name, address addr);
    event VoteCast(uint16 indexed electionId, uint8 indexed candidateId, address voter);
    event ElectionDeactivated(uint16 indexed electionId);
    event ResultsVisibilityUpdated(uint16 indexed electionId, bool visible);
    event UserBanned(uint16 indexed electionId, address indexed user);
    event UserUnbanned(uint16 indexed electionId, address indexed user);
    event AdminAdded(uint16 indexed electionId, address indexed admin);
    event AdminRemoved(uint16 indexed electionId, address indexed admin);

    // MODIFIERS

    modifier electionExists(uint16 electionId) {
        require(elections[electionId].creator != address(0), "Election doesn't exist");
        _;
    }

    modifier electionActive(uint16 electionId)  {
        Election memory _election = elections[electionId];
        require(_election.isActive && block.timestamp >= _election.startTime && block.timestamp <= _election.endTime, "Inactive or invalid time");
        require(_election.candidateCount >=  2,"Minimum 2 candidates required");
        _;
    }

    modifier onlyCreatorOrAdmin(uint16 electionId) {
        require(
            msg.sender == elections[electionId].creator || isElectionAdmin[electionId][msg.sender],
            "Not authorized"
        );
        _;
    }

    // ELECTION FUNCTION

    function setTotalPossibleElections(uint16 value) external {
        require(value > 0 && value >= electionCounter, "Invalid value");
        totalPossibleElection = value;
    }

    function createElection(string memory title, uint32 startTime, uint32 endTime) external {
        require(startTime > block.timestamp && endTime > startTime, "Invalid times");
        require(electionCounter < totalPossibleElection, "Elections Limit reached");

        electionCounter++;

        elections[electionCounter] = Election(
            title, 
            msg.sender,
            startTime,
            endTime,
            0,
            true,
            true
        );

        allElectionIds.push(electionCounter);        
        emit ElectionCreated(electionCounter, title);
    }

    function toggleElectionActive(uint16 electionId)  external onlyCreatorOrAdmin(electionId) {
        require(msg.sender == elections[electionId].creator, "Only creator");
        elections[electionId].isActive = !elections[electionId].isActive;
         
        emit ElectionDeactivated(electionId);   /* send event to bus */
    }

    function setResultsVisibility(uint16 electionId, bool visible) external onlyCreatorOrAdmin(electionId) {
        require(msg.sender == elections[electionId].creator, "Only creator");
        elections[electionId].resultsVisible = visible;
        emit ResultsVisibilityUpdated(electionId, visible);
    }

    function registerCandidate(uint16 electionId , string memory candidateName, address candidateAddress) external onlyCreatorOrAdmin(electionId) {
        require(elections[electionId].isActive && !isCandidateRegistered[electionId][candidateAddress], "Inactive Election or Candidate is registered");
        require(!isBannedFromElection[electionId][msg.sender] && candidateAddress != elections[electionId].creator, "Banned or Creator should not be a candidate");

        uint8 candidateId = elections[electionId].candidateCount++;
        require(candidateId < 100, "Max candidates");

        electionCandidates[electionId][candidateId] =  Candidate(candidateName, candidateAddress,  0);
        isCandidateRegistered[electionId][candidateAddress] = true;

        emit CandidateRegistered(electionId, candidateId,  candidateName , candidateAddress);
     
    }

   function vote(uint16 electionId, uint8 candidateId) external electionActive(electionId) {
        require(!hasVoted[electionId][msg.sender] && !isBannedFromElection[electionId][msg.sender], "Unauthorized");
        require(msg.sender != elections[electionId].creator, "Creator can't vote");

        electionCandidates[electionId][candidateId].voteCount++;
        hasVoted[electionId][msg.sender] = true;
        emit VoteCast(electionId, candidateId, msg.sender);
   }

    function banAddressFromElection(uint16 electionId, address user) external onlyCreatorOrAdmin(electionId) {
        require(msg.sender == elections[electionId].creator && !isBannedFromElection[electionId][user], "Unauthorized or already banned");
        isBannedFromElection[electionId][user] = true;
        emit UserBanned(electionId, user);
    }

    function unbanAddressFromElection(uint16 electionId, address user) external onlyCreatorOrAdmin(electionId) {
        require(msg.sender == elections[electionId].creator && !isBannedFromElection[electionId][user], "Unauthorized or already banned");
        isBannedFromElection[electionId][user] = false;
        emit UserUnbanned(electionId, user);
    }

    function addAdmin(uint16 electionId, address admin) external {
        require(msg.sender == elections[electionId].creator && !isElectionAdmin[electionId][admin], "Invalid admin");
        require(electionAdmins[electionId].length < maxAdminPerElection && admin != address(0), "Limit or zero address");

        isElectionAdmin[electionId][admin] = true;
        electionAdmins[electionId].push(admin);
        emit AdminAdded(electionId, admin);
    }

    function removeElectionAdmin(uint16 electionId, address admin) external {
        require(msg.sender == elections[electionId].creator && admin != msg.sender, "Unauthorized");

        if (isElectionAdmin[electionId][admin]) {
            isElectionAdmin[electionId][admin] = false;

            // Remove admin from the array
            address[] storage admins = electionAdmins[electionId];
            for (uint256 i = 0; i < admins.length; i++) {
                if (admins[i] == admin) {
                    admins[i] = admins[admins.length - 1];
                    admins.pop();
                    break;
                }
            }

            emit AdminRemoved(electionId, admin);
        }
    }


   // VIEW FUNCTIONS

   function getCandidate(uint16 electionId , uint8 candidateId) external view returns (Candidate memory) {
        require(elections[electionId].resultsVisible || block.timestamp > elections[electionId].endTime, "Result not visible yet");
        return electionCandidates[electionId][candidateId];
   }

    function getAllElectionsWithCandidates() external view returns (uint16[] memory ids, string[] memory electionTitles, address[] memory creators, string[][] memory allCandidateNames, address[][] memory allCandidateAddresses) {
        uint256 length = allElectionIds.length;

        ids = new uint16[](length);
        electionTitles = new string[](length);
        creators = new address[](length);
        allCandidateNames = new string[][](length);
        allCandidateAddresses = new address[][](length);

        for (uint16 i = 0; i < length; i++) {
            uint16 electionId = allElectionIds[i];

            ids[i] = electionId;
            electionTitles[i] = elections[electionId].electionTitle;
            creators[i] = elections[electionId].creator;

            uint8 candidateCount = elections[electionId].candidateCount;

            string[] memory names = new string[](candidateCount);
            address[] memory addresses = new address[](candidateCount);

            for(uint8 j = 0; j < candidateCount; j++) {
                names[j] = electionCandidates[electionId][j].candidateName;
                addresses[j] = electionCandidates[electionId][j].candidateAddress;
            }

            allCandidateNames[i] = names;
            allCandidateAddresses[i] = addresses;

        }

        return (ids , electionTitles, creators, allCandidateNames, allCandidateAddresses);
    }
   
   function hasUserVoted(uint16 electionId , address userAddress) external view returns (bool) {
        return hasVoted[electionId][userAddress];
   }

   function getWinner(uint16 electionId)  external view returns(string[] memory candidateNames, address[] memory candidateAddresses, uint16 voteCount)  {
        require(elections[electionId].resultsVisible || block.timestamp > elections[electionId].endTime, "Result not visible yet");

       uint16 highestVoteCount = 0 ;  /* initialize with zero */
       uint16 count = 0;

        // First pass: find highest vote count
       for(uint8 i = 0; i < elections[electionId].candidateCount; ++i) {
            uint16 votes = electionCandidates[electionId][i].voteCount;
            if (votes > highestVoteCount ) {
                highestVoteCount = votes;
                count = 1;
            } else if (votes == highestVoteCount) {
                count++;
            }
       }

       // Second Pass:  Handling Ties
       candidateNames = new string[](count);
       candidateAddresses = new address[](count);

       uint8 index = 0;
       
       for (uint8 i = 0; i < elections[electionId].candidateCount; i++) {
            if(electionCandidates[electionId][i].voteCount == highestVoteCount) {
                candidateNames[index] = electionCandidates[electionId][i].candidateName;
                candidateAddresses[index] = electionCandidates[electionId][i].candidateAddress;
                index++;
            }
       }

       voteCount = highestVoteCount;
       return (candidateNames,  candidateAddresses , voteCount);
   }

   function getResultBreakdown(uint16 electionId) external view returns (string[] memory candidateNames, uint32 startTime, uint32 endTime, uint16[] memory voteCounts, uint16[] memory percentages ) {
        require(elections[electionId].resultsVisible || block.timestamp > elections[electionId].endTime, "Result not visible yet");

        uint16 totalVotes = 0;
        for (uint8 i = 0; i < elections[electionId].candidateCount; i++) {
            totalVotes += electionCandidates[electionId][i].voteCount;
        }

       candidateNames = new string[](elections[electionId].candidateCount);   /* initialize array to the required number of slots */
       voteCounts = new uint16[](elections[electionId].candidateCount);
       percentages = new uint16[](elections[electionId].candidateCount);
       startTime = elections[electionId].startTime;
       endTime = elections[electionId].endTime;

       for (uint8 i = 0; i < elections[electionId].candidateCount; i++) {
            Candidate memory _candidate = electionCandidates[electionId][i];
            candidateNames[i] = _candidate.candidateName;
            voteCounts[i] = _candidate.voteCount;
            percentages[i] = totalVotes > 0 ? (_candidate.voteCount * 100) / totalVotes : 0;
       }

       return ( candidateNames, startTime , endTime , voteCounts, percentages);
   }

    function getElection(uint16 electionId)  external view electionExists(electionId) returns (Election memory) {
        return elections[electionId];
    }

    function getAdmins(uint16 electionId) external view returns (address[] memory) {
        return electionAdmins[electionId];
    }


}