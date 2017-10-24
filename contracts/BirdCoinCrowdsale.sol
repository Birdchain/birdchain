pragma solidity ^0.4.13;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/crowdsale/RefundVault.sol";
import "./BirdCoin.sol";

contract BirdCoinCrowdsale is Ownable {
    using SafeMath for uint256;

    address constant FOUNDERS_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9; // Wallet address where ethereum will be kept
    address constant EARLY_BIRDS_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant ETHEREUM_WALLET = 0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7;
    address constant TEAM_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    address constant BOUNTY_WALLET = 0xEA3E63a29e40DAce4559EE4e566655Fab65FEcB9;
    uint256 constant TOTAL_LEVELS = 3;
    uint256 constant RATE = 42000;
    uint256 constant MIN_STAKE = 0.5 ether;
    uint256 constant MAX_STAKE = 300 ether;
    uint256 constant TOTAL_ETH = 200000 ether;
    uint256 constant SOFT_CAP = 10000 ether;
    uint256 constant DONATION_CAP = 50 ether;
    uint constant SILVER = 1 ether;
    uint constant GOLD = 5 ether;

    BirdCoin public token;
    RefundVault public vault;

    mapping (address => uint256) private purchasers;

    bool public isFinalized = false;
    uint256 public membersCount = 0;
    uint256 public weiRaised;
    uint256 public icoBalance;
    uint256 teamBalance;
    uint256 foundersBalance;
    uint256 earlyBirdsBalance;
    uint256 bountyBalance;
    uint256 public specialBalance;
    uint256 saleBalance;
    uint256 private startTime = now;
    uint256 private endTime = startTime + 3 * 24 * 60 * 60;
    uint public currentStage = 0;

    struct Stages {
        uint limit;
        uint discount;
    }
    Stages[] stagesList;
    mapping (address => uint8) whitelist;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event Finalized();

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

        require(startTime >= now);
        require(endTime >= startTime);
        require(RATE > 0);
        require(FOUNDERS_WALLET != 0x0);

        token = new BirdCoin();
        token.lockTill(endTime);
        vault = new RefundVault(FOUNDERS_WALLET);

        icoBalance = TOTAL_ETH.mul(43).div(100);
        teamBalance = TOTAL_ETH.mul(14).div(100);
        foundersBalance = TOTAL_ETH.mul(13).div(100);
        earlyBirdsBalance = TOTAL_ETH.mul(23).div(100);
        specialBalance = TOTAL_ETH.mul(1).div(100);
        bountyBalance = TOTAL_ETH.mul(6).div(100);
        saleBalance = icoBalance.add(specialBalance);
    }

    function () payable {
        if (!isFinalized) {
            buyTokens(msg.sender);
        } else {
            claimRefund();
        }
    }

    function addToWhitelist(address addr, uint8 level) public onlyOwner {
        require(level > 0 && level <= TOTAL_LEVELS);
        require(whitelist[addr] <= 0);
        whitelist[addr] = level;
        membersCount++;
    }

    function buyTokens(address beneficiary) public payable {
        require(validPurchase(beneficiary));

        uint256 weiAmount = msg.value;
        require(weiRaised.add(weiAmount) < TOTAL_ETH);

        uint256 tokens = calcTokens(beneficiary, weiAmount);

        purchasers[beneficiary] = msg.value;

        token.mint(beneficiary, tokens);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
        forwardFunds();
    }

    function forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }

    function validPurchase(address beneficiary) internal constant returns (bool) {
        bool validAddress = beneficiary != 0x0;
        bool isWhitelisted = whitelist[beneficiary] > 0;
        bool isSenderBeneficiary = msg.sender == beneficiary;
        bool hasNotPaid = (purchasers[beneficiary] == 0);
        bool withinPeriod = now >= startTime && now <= endTime;
        bool withinRangePurchase = msg.value >= MIN_STAKE && msg.value <= MAX_STAKE;
        return validAddress && withinPeriod && withinRangePurchase && isWhitelisted && isSenderBeneficiary && hasNotPaid;
    }

    /******************** Token amount calculations  ********************/

    function calcTokens(address addr, uint256 amount) private returns (uint256) {
        weiRaised = weiRaised.add(amount);

        uint256 totalInvest = amount.mul(stagesList[currentStage].discount).div(100);
        if (weiRaised >= stagesList[currentStage].limit) {
            uint256 excess = weiRaised.sub(stagesList[currentStage].limit);
            totalInvest = amount.sub(excess).mul(stagesList[currentStage].discount);
            if (currentStage != 10) {
                totalInvest = totalInvest.add(excess.mul(stagesList[currentStage.add(1)].discount));
                currentStage++;
            }
        }

        icoBalance = icoBalance.sub(totalInvest);

        if (whitelist[addr] == 2 && specialBalance >= SILVER) {
            totalInvest = totalInvest.add(SILVER);
            specialBalance = specialBalance.sub(SILVER);
        }

        if (whitelist[addr] == 3 && specialBalance >= GOLD) {
            totalInvest = totalInvest.add(GOLD);
            specialBalance = specialBalance.sub(GOLD);
        }

        return totalInvest.mul(RATE);
    }

    /**************************** Refunds  *****************************/

    function claimRefund() public {
        require(isFinalized);
        require(!goalReached());

        vault.refund(msg.sender);
    }

    function finalize() onlyOwner public {
        require(!isFinalized);
        require(now > endTime);

        if (goalReached()) {
            vault.close();
        } else {
            vault.enableRefunds();
        }

        token.mint(this, icoBalance.add(specialBalance));

        bountyReward();
        earlyBirdsReward();
        teamReward();
        foundersReward();

        Finalized();

        isFinalized = true;
    }

    function goalReached() private constant returns (bool) {
        return weiRaised >= SOFT_CAP;
    }

    /********************* Token distribution ********************/

    function calcAdditionalTokens(address _purchaser) constant public returns (uint256) {
        if (purchasers[_purchaser] > 0 && goalReached()) {
            uint256 totalBalanceLeft = icoBalance.add(specialBalance);
            uint256 totalSold = saleBalance.sub(totalBalanceLeft);
            uint256 value = purchasers[_purchaser];
            return totalBalanceLeft.mul(value).div(totalSold).mul(RATE);
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

    function teamReward() onlyOwner private {
        token.lockTill(now + 60 * 60 * 24 * 365 * 2); // 2years
        token.mint(TEAM_WALLET, teamBalance);
        teamBalance = 0;
        forwardFunds();
    }

    function bountyReward() onlyOwner private {
        token.mint(BOUNTY_WALLET, bountyBalance);
        bountyBalance = 0;
        forwardFunds();
    }

    function foundersReward() onlyOwner private {
        token.lockTill(now + 60 * 60 * 24 * 365 * 2); // 2years
        token.mint(FOUNDERS_WALLET, foundersBalance);
        foundersBalance = 0;
        forwardFunds();
    }

    function earlyBirdsReward() onlyOwner private {
        token.mint(EARLY_BIRDS_WALLET, earlyBirdsBalance);
        earlyBirdsBalance = 0;
        forwardFunds();
    }
}
