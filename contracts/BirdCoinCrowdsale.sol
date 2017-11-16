pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/crowdsale/RefundVault.sol";
import "./BirdCoin.sol";

contract BirdCoinCrowdsale is Ownable {
    using SafeMath for uint256;

    address constant FOUNDERS_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9; // Wallet address where ethereum will be kept
    address constant WHITELISTER_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant EARLY_BIRDS_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant TEAM_WALLET_1_YEAR = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant TEAM_WALLET_2_YEAR = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant TEAM_WALLET_3_YEAR = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant TEAM_WALLET_4_YEAR = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant BOUNTY_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    uint256 constant RATE = 42000;
    uint256 constant MIN_STAKE = 0.1 ether;
    uint256 constant MAX_STAKE = 2000 ether;
    uint256 constant HARD_CAP = 86000 ether;
    uint256 constant SOFT_CAP = 10000 ether;
    uint constant SILVER = 1 ether;
    uint constant GOLD = 5 ether;

    BirdCoin public token;
    RefundVault public vault;

    mapping (address => uint256) private purchasers;

    bool public isFinalized = false;
    uint256 public membersCount = 0;
    uint256 public weiRaised;
    uint256 public icoBalance;
    uint256 startTime = now;
    uint256 public endTime = startTime.add(60 * 60 * 24 * 36);
    uint256 public icoBalanceLeft;
    uint256 public initialIcoBalance;
    uint public currentStage = 0;

    struct Stages {
        uint limit;
        uint discount;
    }
    Stages[] stagesList;
    mapping (address => uint32) whitelist;

    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount, uint256 bonus, uint stage);

    function BirdCoinCrowdsale() {
        stagesList.push(Stages({limit: 9500 ether, discount: 150 }));
        stagesList.push(Stages({limit: 18000 ether, discount: 145 }));
        stagesList.push(Stages({limit: 26500 ether, discount: 140 }));
        stagesList.push(Stages({limit: 35000 ether, discount: 135 }));
        stagesList.push(Stages({limit: 43500 ether, discount: 130 }));
        stagesList.push(Stages({limit: 52000 ether, discount: 125 }));
        stagesList.push(Stages({limit: 60500 ether, discount: 120 }));
        stagesList.push(Stages({limit: 69000 ether, discount: 115 }));
        stagesList.push(Stages({limit: 77500 ether, discount: 110 }));
        stagesList.push(Stages({limit: 86000 ether, discount: 105 }));

        require(startTime >= now && endTime >= startTime);

        token = new BirdCoin();
        vault = new RefundVault(FOUNDERS_WALLET);

        icoBalance = 4698750000 ether;
        initialIcoBalance = icoBalance;
    }

    function () payable {
        if (!isFinalized) {
            buyTokens();
        } else {
            claimRefund();
        }
    }

    modifier onlyWhitelister() {
        require(msg.sender == WHITELISTER_WALLET);
        _;
    }

    function addToWhitelist(address addr, uint8 level) public onlyWhitelister {
        require(whitelist[addr] == 0 && (level == 1 || level == 5 || level == 2 || level == 6 || level == 10));
        whitelist[addr] = level;
        membersCount = membersCount.add(1);
    }

    function buyTokens() public payable {
        require(validPurchase());

        weiRaised = weiRaised.add(msg.value);

        uint256 tokens = 0;
        uint256 excess = 0;
        if (weiRaised >= stagesList[currentStage].limit) {
            excess = weiRaised.sub(stagesList[currentStage].limit);
            tokens = msg.value.sub(excess).mul(stagesList[currentStage].discount).div(100);
            currentStage = currentStage.add(1);
            if (currentStage < 10) {
                tokens = tokens.add(excess.mul(stagesList[currentStage].discount).div(100));
                excess = 0;
            }
        } else {
            tokens = msg.value.mul(stagesList[currentStage].discount).div(100);
        }

        uint256 bonus = 0;
        if (whitelist[msg.sender] & 4 == 4 && msg.value >= 0.5 ether) {
            bonus = SILVER;
        }

        if (whitelist[msg.sender] & 8 == 8 && msg.value >= GOLD) {
            bonus = GOLD;
        }

        tokens = tokens.add(bonus).mul(RATE);
        icoBalance = icoBalance.sub(tokens);
        token.mint(msg.sender, tokens);
        uint256 value = msg.value.sub(excess);
        purchasers[msg.sender] = tokens;
        TokenPurchase(msg.sender, value, tokens, bonus, currentStage);
        vault.deposit.value(value)(msg.sender);
        if (excess > 0) {
            weiRaised = weiRaised.sub(excess);
            msg.sender.transfer(excess);
        }
    }

    function validPurchase() internal constant returns (bool) {
        bool validAddress = (msg.sender != 0x0);
        bool isWhitelisted = (whitelist[msg.sender] & 1 == 1 && msg.value <= 2.5 ether) || whitelist[msg.sender] & 2 == 2;
        bool withinPeriod = (now >= startTime && now <= endTime);
        bool withinRangePurchase = (msg.value >= MIN_STAKE && msg.value <= MAX_STAKE);
        bool isStageValid = currentStage < 10;
        return validAddress && withinPeriod && withinRangePurchase && isWhitelisted && isStageValid;
    }

    /**************************** Refunds  *****************************/

    function claimRefund() private {
        require(isFinalized);
        require(!goalReached());

        vault.refund(msg.sender);
    }

    function finalize() onlyOwner public {
        require(!isFinalized);
        require(now > endTime || HARD_CAP - weiRaised < MIN_STAKE);

        if (goalReached()) {
            vault.close();
            token.unlockTokens();

            bountyReward();
            earlyBirdsReward();
            teamReward();
            foundersReward();

            token.mint(this, icoBalance);
            token.finishMinting();
            icoBalanceLeft = icoBalance;
        } else {
            vault.enableRefunds();
        }

        isFinalized = true;
    }

    function goalReached() private constant returns (bool) {
        return weiRaised >= SOFT_CAP;
    }

    /********************* Token distribution ********************/

    function calcAdditionalTokens(address _purchaser) constant public returns (uint256) {
        if (purchasers[_purchaser] > 0 && isFinalized && goalReached()) {
            uint256 value = purchasers[_purchaser];
            uint256 result = icoBalanceLeft.mul(value).div(initialIcoBalance.sub(icoBalanceLeft));
            return result;
        }

        return 0;
    }

    function withdraw(address _purchaser) public {
        uint256 additionalTokens = calcAdditionalTokens(_purchaser);
        if (additionalTokens > 0) {
            purchasers[_purchaser] = 0;
            token.transferCrowdsale(_purchaser, additionalTokens);
        }
    }

    function teamReward() private {
        uint256 partPerYear = 294000000 ether;
        uint yearInSeconds = 31536000;

        token.lockTill(TEAM_WALLET_1_YEAR, startTime.add(yearInSeconds));
        token.mint(TEAM_WALLET_1_YEAR, partPerYear);

        token.lockTill(TEAM_WALLET_2_YEAR, startTime.add(yearInSeconds.mul(2)));
        token.mint(TEAM_WALLET_2_YEAR, partPerYear);

        token.lockTill(TEAM_WALLET_3_YEAR, startTime.add(yearInSeconds.mul(3)));
        token.mint(TEAM_WALLET_3_YEAR, partPerYear);

        token.lockTill(TEAM_WALLET_4_YEAR, startTime.add(yearInSeconds.mul(4)));
        token.mint(TEAM_WALLET_4_YEAR, partPerYear);
    }

    function bountyReward() private {
        token.mint(BOUNTY_WALLET, 504000000 ether);
    }

    function foundersReward() private {
        token.lockTill(FOUNDERS_WALLET, startTime.add(63072000)); // 2years
        token.mint(FOUNDERS_WALLET, 1092000000 ether);
    }

    function earlyBirdsReward() private {
        token.mint(EARLY_BIRDS_WALLET, 1932000000 ether);
    }
}
