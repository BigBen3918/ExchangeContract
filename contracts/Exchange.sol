//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import './FixedSupplyToken.sol';
import './Ownable.sol';
import './SafeMath.sol';

contract Exchange is Ownable {

    using SafeMath for uint256;

    uint weiValue = 10**uint(18);

    struct Offer {
        address trader;
        uint amount;
    }

    struct OrderBook {

        uint higherPrice;
        uint lowerPrice;

        mapping(uint => Offer) offers;

        //to represent a queue
        //offers_start == 1 ? an offer exists in the queue
        uint offers_start;
        uint offers_end;
    }

    struct Token {
        string symbolName;

        address tokenContract;

        // price is the key for order book linkedlist
        mapping(uint => OrderBook) buyOrderBook;
        //HEAD of the linked list for the buy order book
        uint highestBuyPrice;
        //TAIL of the linked list for the buy order book
        uint lowestBuyPrice;
        // buy amount across all the book
        uint amountBuy;

        // price is the key for order book linkedlist
        mapping(uint => OrderBook) sellOrderBook;
        //HEAD of the linked list for the sell order book
        uint lowestSellPrice;
        //TAIL of the linked list for the sell order book
        uint highestSellPrice;
        // sell amount across all the book
        uint amountSell;
    }

    // support a maximum of 255 contracts as we start from 1
    mapping(uint8 => Token) tokens;
    uint8 tokenIndex;

    mapping(address => mapping(uint8 => uint)) tokenBalancesForAddress;

    mapping(address => uint) etherBalanceForAddress;

    //////////////
    /// EVENTS ///
    //////////////

    event TokenAdded(address indexed _initiator, uint _timestamp, uint8 indexed _tokenIndex, string _symbolName);

    event TokenDeposited(address indexed _initiator, uint _timestamp, uint8 indexed _tokenIndex, string _symbolName, uint _amount);

    event TokenWithdrawn(address indexed _initiator, uint _timestamp, uint8 indexed _tokenIndex, string _symbolName, uint _amount);

    event EtherDeposited(address indexed _initiator, uint _timestamp, uint _amountInWei);

    event EtherWithdrawn(address indexed _initiator, uint _timestamp, uint _amountInWei);

    ////////////////////
    /// ORDER EVENTS ///
    ////////////////////

    event BuyLimitOrderCreated(address indexed _who, uint timestamp, string _symbolName, uint _amountInWei, uint _priceInWei, uint _orderKey, string orderType);

    event SellLimitOrderCreated(address indexed _who, uint timestamp, string _symbolName, uint _amountInWei, uint _priceInWei, uint _orderKey, string orderType);

    event BuyLimitOrderCanceled(address indexed _who, uint timestamp, string _symbolName, uint _amountInWei, uint _priceInWei, uint _orderKey, string orderType);

    event SellLimitOrderCanceled(address indexed _who, uint timestamp, string _symbolName, uint _amountInWei, uint _priceInWei, uint _orderKey, string orderType);

    event BuyLimitOrderFulfilled(address indexed _who, uint timestamp, string _symbolName, uint _amountInWei, uint _priceInWei, uint _orderKey, string orderType);

    event SellLimitOrderFulfilled(address indexed _who, uint timestamp, string _symbolName, uint _amountInWei, uint _priceInWei, uint _orderKey, string orderType);

    ////////////////////////////////
    /// ETHER DEPOSIT & WITHDRAW ///
    ////////////////////////////////

    // function depositEther() public payable {
    //     etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].add(msg.value);
    //     emit EtherDeposited(msg.sender, now, msg.value);
    // }

    // function withdrawEther(uint amountInWei) public {
    //     require(
    //         amountInWei <= etherBalanceForAddress[msg.sender],
    //         "amountInWei less than sender ether balance "
    //     );
    //     etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].sub(amountInWei);
    //     msg.sender.transfer(amountInWei);

    //     emit EtherWithdrawn(msg.sender, now, amountInWei);
    // }


    function getBalanceInWei() public view returns (uint) {
        return etherBalanceForAddress[msg.sender];
    }

    ////////////////////////
    /// TOKEN MANAGEMENT ///
    ////////////////////////

    // Only admin function
    function addToken(string memory symbolName, address tokenContract) public onlyOwner {
        require(!hasToken(symbolName));
        require(tokenIndex < 255);

        tokenIndex ++;
        tokens[tokenIndex].symbolName = symbolName;
        tokens[tokenIndex].tokenContract = tokenContract;
        emit TokenAdded(msg.sender, block.timestamp, tokenIndex, symbolName);
    }

    function hasToken(string memory symbolName) public view returns (bool) {
        uint8 index = getSymbolIndex(symbolName);
        return (index > 0);
    }

    function getSymbolIndex(string memory symbolName) internal view returns (uint8) {
        for (uint8 i = 1; i <= tokenIndex; i++) {
            Token storage token = tokens[i];
            if (stringsEqual(symbolName, token.symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function stringsEqual(string memory strA, string storage strB) internal view returns (bool) {
        bytes memory strA_bytes = bytes(strA);
        bytes storage strB_bytes = bytes(strB);

        if (strB_bytes.length != strB_bytes.length) {
            return false;
        }
        for (uint8 i = 0; i < strA_bytes.length; i++) {
            if (strA_bytes[i] != strB_bytes[i]) {
                return false;
            }
        }
        return true;
    }


    ////////////////////////////////
    /// TOKEN DEPOSIT & WITHDRAW ///
    ////////////////////////////////

    // function depositToken(string symbolName, uint amount) public {
    //     require(hasToken(symbolName), "token is not referenced in the exchange");
    //     uint8 idx = getSymbolIndex(symbolName);
    //     ERC20Interface token = ERC20Interface(tokens[idx].tokenContract);
    //     require(token.transferFrom(msg.sender, address(this), amount));
    //     tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].add(amount);
    //     emit TokenDeposited(msg.sender, now, idx, symbolName, amount);
    // }

    // function withdrawToken(string symbolName, uint amount) public {
    //     require(hasToken(symbolName), "token is not referenced in the exchange");
    //     uint8 idx = getSymbolIndex(symbolName);
    //     uint tokenBalance = tokenBalancesForAddress[msg.sender][idx];
    //     require(tokenBalance >= amount, "token amount less than sender token balance");
    //     tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].sub(amount);
    //     emit TokenWithdrawn(msg.sender, now, idx, symbolName, amount);
    //     ERC20Interface token = ERC20Interface(tokens[idx].tokenContract);
    //     require(token.transfer(msg.sender, amount));
    // }

    function getBalanceToken(address _account, string memory symbolName) public view returns (uint) {
        require(hasToken(symbolName), "token is not referenced in the exchange");

        uint8 idx = getSymbolIndex(symbolName);
        return tokenBalancesForAddress[_account][idx];
    }
    /* function getBalanceToken(string symbolName) public view returns (uint) {
        require(hasToken(symbolName), "token is not referenced in the exchange");

        uint8 idx = getSymbolIndex(symbolName);
        return tokenBalancesForAddress[msg.sender][idx];
    } */

    /////////////////////////////
    /// ORDER BOOK MANAGEMENT ///
    /////////////////////////////

    ///////// BUY ORDER /////////

    function getBuyOrderBookPricesAndAmount(string memory symbolName) public view returns (uint, uint, uint) {
        require(hasToken(symbolName), "token is not referenced in the exchange");

        uint8 idx = getSymbolIndex(symbolName);
        Token storage token = tokens[idx];
        return (token.highestBuyPrice, token.lowestBuyPrice, token.amountBuy);
    }

    function getBuyOrderBookOffersStartAndEnd(string memory symbolName, uint priceInWei) public view returns (uint, uint) {
        require(hasToken(symbolName), "token is not referenced in the exchange");
        uint8 idx = getSymbolIndex(symbolName);
        Token storage token = tokens[idx];
        return (token.buyOrderBook[priceInWei].offers_start, token.buyOrderBook[priceInWei].offers_end);
    }

    function getBuyOrderBookOffersOrderTraderAndAmount(string memory symbolName, uint priceInWei, uint offerIndex) public view returns (address, uint) {
        require(hasToken(symbolName), "token is not referenced in the exchange");
        uint8 idx = getSymbolIndex(symbolName);
        Token storage token = tokens[idx];
        OrderBook storage orderBook = token.buyOrderBook[priceInWei];
        Offer storage offer = orderBook.offers[offerIndex];
        return (offer.trader, offer.amount);
    }

    function matchSellOrder(Token storage token, uint8 idx, uint amount, uint priceInWei) internal returns (uint) {
        uint currentSellPrice = token.lowestSellPrice;
        uint remainingAmount = amount;
        uint etherAmountInWei;
        while (currentSellPrice != 0 && currentSellPrice <= priceInWei && remainingAmount > 0) {
            OrderBook storage sellOrderBook = token.sellOrderBook[currentSellPrice];
            uint offer_idx = sellOrderBook.offers_start;
            while (offer_idx <= sellOrderBook.offers_end && remainingAmount > 0) {
                Offer storage offer = sellOrderBook.offers[offer_idx];
                // skip the canceled order
                if (offer.amount == 0) {
                    sellOrderBook.offers_start++;
                    offer_idx ++;
                    continue;
                }
                // 1. take no more than remainingAmount
                uint minAmount = offer.amount;
                if (offer.amount > remainingAmount) {
                    minAmount = remainingAmount;
                }
                remainingAmount -= minAmount;
                token.amountSell -= minAmount;
                // tokens increases for the buyer
                tokenBalancesForAddress[msg.sender][idx] += minAmount;
                // ether changes hands
                etherBalanceForAddress[msg.sender] -= minAmount.mul(currentSellPrice).div(weiValue);
                etherBalanceForAddress[offer.trader] += minAmount.mul(currentSellPrice).div(weiValue);
                // 2. partial or complete order fulfilled ?
                if (minAmount == offer.amount) { 
                    sellOrderBook.offers_start ++;
                    // emit SellLimitOrderFulfilled(offer.trader, timestamp, symbolName, offer.amount, currentSellPrice, offer_idx, "sell");
                    // auto withdraw - withdrawEther
                    etherAmountInWei = offer.amount.mul(currentSellPrice).div(weiValue);
                    // require( etherAmountInWei <= etherBalanceForAddress[offer.trader], "etherAmountInWei less than sender ether balance error1" );
                    etherBalanceForAddress[offer.trader] = etherBalanceForAddress[offer.trader].sub(etherAmountInWei);
                    payable(offer.trader).transfer(etherAmountInWei);
                    // emit EtherWithdrawn(offer.trader, timestamp, etherAmountInWei);
                    // auto withdraw - withdrawToken
                    // require(tokenBalancesForAddress[msg.sender][idx] >= offer.amount, "token amount less than sender token balance SellLimitOrderFulfilled withdrawToken error2");
                    tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].sub(offer.amount);
                    // emit TokenWithdrawn(msg.sender, timestamp, idx, symbolName, offer.amount);
                    ERC20Interface(tokens[idx].tokenContract).transfer(msg.sender, offer.amount);
                    // require(ERC20Interface(tokens[idx].tokenContract).transfer(msg.sender, offer.amount) == true);
                } else {
                    // auto withdraw - withdrawEther
                    etherAmountInWei = minAmount.mul(currentSellPrice).div(weiValue);
                    // require( etherAmountInWei <= etherBalanceForAddress[offer.trader], "etherAmountInWei less than sender ether balance error3" );
                    etherBalanceForAddress[offer.trader] = etherBalanceForAddress[offer.trader].sub(etherAmountInWei);
                    payable(offer.trader).transfer(etherAmountInWei);
                    // emit EtherWithdrawn(offer.trader, timestamp, etherAmountInWei);
                    // auto withdraw - withdrawToken
                    // require(tokenBalancesForAddress[msg.sender][idx] >= minAmount, "token amount less than sender token balance SellLimitOrderFulfilled withdrawToken error4");
                    tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].sub(minAmount);
                    // emit TokenWithdrawn(msg.sender, timestamp, idx, symbolName, minAmount);
                    ERC20Interface(tokens[idx].tokenContract).transfer(msg.sender, minAmount);
                    // require(ERC20Interface(tokens[idx].tokenContract).transfer(msg.sender, minAmount) == true);
                }
                offer.amount -= minAmount;
                // 3. move to the next offer
                offer_idx ++;
            }
            currentSellPrice = sellOrderBook.higherPrice;
            token.lowestSellPrice = currentSellPrice;
        }
        return remainingAmount;
    }

    function buyToken(string memory symbolName, uint amount, uint priceInWei) public payable returns (uint) {
        uint timestamp = block.timestamp;
        require(hasToken(symbolName), "token is not referenced in the exchange error5");
        // deposit part
        etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].add(msg.value);
        emit EtherDeposited(msg.sender, timestamp, msg.value);

        require(etherBalanceForAddress[msg.sender] >= amount.mul(priceInWei).div(weiValue),
            "ether balance for msg.sender is not enough to cover amount * priceInWei error6");

        uint8 idx = getSymbolIndex(symbolName);
        Token storage token = tokens[idx];
        // 1. check that no matching sell orders. priceInWei <= priceInWei in sell orders
        uint remainingAmount = matchSellOrder(token, idx, amount, priceInWei);

        if (remainingAmount == 0) {
            emit BuyLimitOrderFulfilled(msg.sender, timestamp, symbolName, amount, priceInWei, 0, "buy");
            // auto withdraw //
            return 0;
        }

        // 2. place remaining unfulfilled order quantity at price in the buy order list. ordered by descending order
        uint currentPrice = token.highestBuyPrice;
        while (priceInWei < currentPrice && priceInWei >= token.lowestBuyPrice) {
            currentPrice = token.buyOrderBook[currentPrice].lowerPrice;
        }

        //3. Found the index in the buyOrderBook. Now need to insert it.
        //3.a case if first buy order in the buy order book
        if (token.amountBuy == 0) {
            token.lowestBuyPrice = priceInWei;
            token.highestBuyPrice = priceInWei;
            token.buyOrderBook[priceInWei].offers_start = 1;
            // to mention a new offer at this price
        }
        //3.b case if priceInWei is the highest price (new head of the list) or first order
        else if (priceInWei > token.highestBuyPrice) {
            token.buyOrderBook[priceInWei].lowerPrice = token.highestBuyPrice;
            token.buyOrderBook[token.highestBuyPrice].higherPrice = priceInWei;
            token.highestBuyPrice = priceInWei;
            token.buyOrderBook[priceInWei].offers_start = 1;
            // to mention a new offer at this price
        }
        //3.c case if priceInWei is the lowest price (new tail of the list)
        else if (priceInWei < token.lowestBuyPrice) {
            token.buyOrderBook[priceInWei].higherPrice = token.lowestBuyPrice;
            token.buyOrderBook[token.lowestBuyPrice].lowerPrice = priceInWei;
            token.lowestBuyPrice = priceInWei;
            token.buyOrderBook[priceInWei].offers_start = 1;
        }
        //3.d case if priceInWei does not exist in the list
        else if (priceInWei != currentPrice) {
            uint previousHigherPrice = token.buyOrderBook[currentPrice].higherPrice;
            token.buyOrderBook[currentPrice].higherPrice = priceInWei;
            token.buyOrderBook[priceInWei].lowerPrice = currentPrice;
            token.buyOrderBook[previousHigherPrice].lowerPrice = priceInWei;
            token.buyOrderBook[priceInWei].higherPrice = previousHigherPrice;
            token.buyOrderBook[priceInWei].offers_start = 1;
        }
        //4. push the offer in the offer queue
        OrderBook storage orderBook = token.buyOrderBook[priceInWei];
        orderBook.offers_end ++;
        orderBook.offers[orderBook.offers_end] = Offer(msg.sender, remainingAmount);

        //5. add to the buy order book total quantity
        token.amountBuy = token.amountBuy.add(remainingAmount);
        etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].sub(remainingAmount.mul(priceInWei).div(weiValue));
        emit BuyLimitOrderCreated(msg.sender, timestamp, symbolName, remainingAmount, priceInWei, orderBook.offers_end, "buy");

        // 6. return order position
        return orderBook.offers_end;
    }

    ///////// SELL ORDER /////////

    // function getSellOrderBookPricesAndAmount(string symbolName) public view returns (uint, uint, uint) {
    //     require(hasToken(symbolName), "token is not referenced in the exchange  error7");

    //     uint8 idx = getSymbolIndex(symbolName);
    //     Token storage token = tokens[idx];
    //     return (token.lowestSellPrice, token.highestSellPrice, token.amountSell);
    // }

    // function getSellOrderBookOffersStartAndEnd(string symbolName, uint priceInWei) public view returns (uint, uint) {
    //     require(hasToken(symbolName), "token is not referenced in the exchange  error8");

    //     uint8 idx = getSymbolIndex(symbolName);
    //     Token storage token = tokens[idx];
    //     return (token.sellOrderBook[priceInWei].offers_start, token.sellOrderBook[priceInWei].offers_end);
    // }

    // function getSellOrderBookOffersOrderTraderAndAmount(string symbolName, uint priceInWei, uint offerIndex) public view returns (address, uint) {
    //     require(hasToken(symbolName), "token is not referenced in the exchange  error9");

    //     uint8 idx = getSymbolIndex(symbolName);
    //     Token storage token = tokens[idx];
    //     OrderBook storage orderBook = token.sellOrderBook[priceInWei];
    //     Offer storage offer = orderBook.offers[offerIndex];
    //     return (offer.trader, offer.amount);
    // }

    function matchBuyOrder(Token storage token, string memory symbolName, uint8 idx, uint amount, uint priceInWei) internal returns (uint) {
        uint currentBuyPrice = token.highestBuyPrice;
        uint remainingAmount = amount;
        uint etherAmountInWei;
        while (currentBuyPrice > 0 && currentBuyPrice >= priceInWei && remainingAmount > 0) {
            OrderBook storage buyOrderBook = token.buyOrderBook[currentBuyPrice];
            uint offer_idx = buyOrderBook.offers_start;
            while (offer_idx <= buyOrderBook.offers_end && remainingAmount > 0) {
                Offer storage offer = buyOrderBook.offers[offer_idx];

                // skip the canceled order
                if (offer.amount == 0) {
                    buyOrderBook.offers_start ++;
                    offer_idx ++;
                    continue;
                }
                // 1. take no more than remainingAmount
                uint minAmount = offer.amount;
                if (offer.amount > remainingAmount) {
                    minAmount = remainingAmount;
                }
                remainingAmount -= minAmount;
                token.amountBuy -= minAmount;
                // tokens change hands
                tokenBalancesForAddress[msg.sender][idx] -= minAmount;
                tokenBalancesForAddress[offer.trader][idx] += minAmount;
                // ether increase for the seller
                etherBalanceForAddress[msg.sender] += minAmount.mul(currentBuyPrice).div(weiValue);
                // 2. partial or complete order fulfilled ?
                if (minAmount == offer.amount) {
                    buyOrderBook.offers_start ++;
                    emit BuyLimitOrderFulfilled(offer.trader, block.timestamp, symbolName, minAmount, currentBuyPrice, offer_idx, "buy");
                    // auto withdraw - withdrawEther
                    etherAmountInWei = minAmount.mul(currentBuyPrice).div(weiValue);
                    require( etherAmountInWei <= etherBalanceForAddress[msg.sender], "etherAmountInWei less than sender ether balance  error10" );
                    etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].sub(etherAmountInWei);
                    payable(msg.sender).transfer(etherAmountInWei);
                    emit EtherWithdrawn(offer.trader, block.timestamp, etherAmountInWei);
                    // auto withdraw - withdrawToken
                    require(tokenBalancesForAddress[offer.trader][idx] >= minAmount, "token amount less than sender token balance SellLimitOrderFulfilled withdrawToken  error11");
                    tokenBalancesForAddress[offer.trader][idx] = tokenBalancesForAddress[offer.trader][idx].sub(minAmount);
                    emit TokenWithdrawn(offer.trader, block.timestamp, idx, symbolName, minAmount);
                    require(ERC20Interface(tokens[idx].tokenContract).transfer(offer.trader, minAmount) == true);
                }
                else {
                    // auto withdraw - withdrawEther
                    etherAmountInWei = minAmount.mul(currentBuyPrice).div(weiValue);
                    require( etherAmountInWei <= etherBalanceForAddress[msg.sender], "etherAmountInWei less than sender ether balance  error12" );
                    etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].sub(etherAmountInWei);
                    payable(msg.sender).transfer(etherAmountInWei);
                    emit EtherWithdrawn(offer.trader, block.timestamp, etherAmountInWei);
                    // auto withdraw - withdrawToken
                    require(tokenBalancesForAddress[offer.trader][idx] >= minAmount, "token amount less than sender token balance SellLimitOrderFulfilled withdrawToken  error13");
                    tokenBalancesForAddress[offer.trader][idx] = tokenBalancesForAddress[offer.trader][idx].sub(minAmount);
                    emit TokenWithdrawn(offer.trader, block.timestamp, idx, symbolName, minAmount);
                    require(ERC20Interface(tokens[idx].tokenContract).transfer(offer.trader, minAmount) == true);
                }
                offer.amount -= minAmount;
                // 3. move to the next offer
                offer_idx ++;
            }
            currentBuyPrice = buyOrderBook.lowerPrice;
            if (buyOrderBook.lowerPrice != 0) {
                token.highestBuyPrice = buyOrderBook.lowerPrice;
            }
        }
        return remainingAmount;
    }

    function sellToken(string memory symbolName, uint amount, uint priceInWei) public returns (uint) {
        require(hasToken(symbolName), "token is not referenced in the exchange");
        // deposit Token
        uint8 idx = getSymbolIndex(symbolName);
        ERC20Interface token_deposit = ERC20Interface(tokens[idx].tokenContract);
        require(token_deposit.approve(msg.sender, amount));
        require(token_deposit.transferFrom(msg.sender, address(this), amount));
        tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].add(amount);
        emit TokenDeposited(msg.sender, block.timestamp, idx, symbolName, amount);

        uint256 tokenBalance = getBalanceToken(msg.sender, symbolName);
        require(amount <= tokenBalance, 'token balance for msg.sender is not enough to cover the sell order  error14');
        Token storage token = tokens[idx];

        // 1. check that no matching buy orders. priceInWei >= priceInWei in buy orders
        uint remainingAmount = matchBuyOrder(token, symbolName, idx, amount, priceInWei);

        if (remainingAmount == 0) {
            emit SellLimitOrderFulfilled(msg.sender, block.timestamp, symbolName, amount, priceInWei, 0, "sell");
            // auto withdraw //
            return 0;
        }

        // 2. place remaining unfulfilled order quantity in the sell order book sorted by ascending order
        uint currentPrice = token.lowestSellPrice;
        while (priceInWei > currentPrice && priceInWei <= token.highestSellPrice) {
            currentPrice = token.sellOrderBook[currentPrice].higherPrice;
        }

        //3. Found the index in the sellOrderBook. Now need to insert it.
        //3.a case if first sell order in the sell order book
        if (token.amountSell == 0) {
            token.lowestSellPrice = priceInWei;
            token.highestSellPrice = priceInWei;
            token.sellOrderBook[priceInWei].offers_start = 1;
            // to mention a new offer at this price
        }
        //3.b case if priceInWei is the lowest price (new head of the list)
        else if (priceInWei < token.lowestSellPrice) {
            token.sellOrderBook[priceInWei].higherPrice = token.lowestSellPrice;
            token.sellOrderBook[token.lowestSellPrice].lowerPrice = priceInWei;
            token.lowestSellPrice = priceInWei;
            token.sellOrderBook[priceInWei].offers_start = 1;
            // to mention a new offer at this price
        }
        //3.c case if priceInWei is the highest price (new tail of the list)
        else if (priceInWei > token.highestSellPrice) {
            token.sellOrderBook[priceInWei].lowerPrice = token.highestSellPrice;
            token.sellOrderBook[token.highestSellPrice].higherPrice = priceInWei;
            token.highestSellPrice = priceInWei;
            token.sellOrderBook[priceInWei].offers_start = 1;
            // to mention a new offer at this price
        }
        //3.d case if priceInWei does not exist in the list
        else if (priceInWei != currentPrice) {
            uint previousLowerPrice = token.sellOrderBook[currentPrice].lowerPrice;
            token.sellOrderBook[currentPrice].lowerPrice = priceInWei;
            token.sellOrderBook[priceInWei].higherPrice = currentPrice;
            token.sellOrderBook[previousLowerPrice].higherPrice = priceInWei;
            token.sellOrderBook[priceInWei].lowerPrice = previousLowerPrice;
            token.sellOrderBook[priceInWei].offers_start = 1;
            // to mention a new offer at this price
        }

        // 4 push the offer in the offer queue
        OrderBook storage orderBook = token.sellOrderBook[priceInWei];
        orderBook.offers_end ++;
        orderBook.offers[orderBook.offers_end] = Offer(msg.sender, remainingAmount);
        //5. add to the sell order book total quantity
        token.amountSell = token.amountSell.add(remainingAmount);
        tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].sub(remainingAmount);
        emit SellLimitOrderCreated(msg.sender, block.timestamp, symbolName, remainingAmount, priceInWei, orderBook.offers_end, "sell");
        // 6. return order position
        return orderBook.offers_end;
    }

    //////// CANCEL ORDER ////////

    // can a cancel be run at the same time than an execution because many transactions can happen in the same block ?
    // can a cancel front run an execution and put the exchange into an inconsistent state ?
    function cancelBuyLimitOrder(string memory symbolName, uint priceInWei, uint orderPosition) public {
        uint timestamp = block.timestamp;
        require(hasToken(symbolName), "token is not referenced in the exchange  error15");
        // uint256 tokenBalance = getBalanceToken(msg.sender, symbolName);
        uint8 idx = getSymbolIndex(symbolName);
        Token storage token = tokens[idx];
        Offer storage offer = token.buyOrderBook[priceInWei].offers[orderPosition];
        require(offer.trader == msg.sender, "the offer trader is not the sender error16");
        require(offer.amount != 0, "the order has already been canceled");
        etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].add(offer.amount.mul(priceInWei).div(weiValue));
        token.amountBuy = token.amountBuy.sub(offer.amount);
        emit BuyLimitOrderCanceled(msg.sender, timestamp, symbolName, offer.amount, priceInWei, orderPosition, "buy");
        uint etherAmountInWei = offer.amount.mul(priceInWei).div(weiValue);
        require(etherAmountInWei <= etherBalanceForAddress[msg.sender], "etherAmountInWei less than sender ether balance  error17" );
        etherBalanceForAddress[msg.sender] = etherBalanceForAddress[msg.sender].sub(etherAmountInWei);
        payable(offer.trader).transfer(etherAmountInWei);
        emit EtherWithdrawn(offer.trader, timestamp, etherAmountInWei);
        offer.amount = 0;
    }

    // can a cancel be run at the same time than an execution because many transactions can happen in the same block ?
    // can a cancel front run an execution and put the exchange into an inconsistent state ?
    function cancelSellLimitOrder(string memory symbolName, uint priceInWei, uint orderPosition) public {
        uint timestamp = block.timestamp;
        require(hasToken(symbolName), "token is not referenced in the exchange  error18");
        // uint256 tokenBalance = getBalanceToken(msg.sender, symbolName);
        uint8 idx = getSymbolIndex(symbolName);
        Token storage token = tokens[idx];
        Offer storage offer = token.sellOrderBook[priceInWei].offers[orderPosition];
        require(offer.trader == msg.sender, "the offer trader is not the sender  error19");
        require(offer.amount != 0, "the order has already been canceled  error20");
        tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].add(offer.amount);
        token.amountSell = token.amountSell.sub(offer.amount);
        emit SellLimitOrderCanceled(msg.sender, timestamp, symbolName, offer.amount, priceInWei, orderPosition, "sell");
        require(tokenBalancesForAddress[msg.sender][idx] >= offer.amount, "token amount less than sender token balance error20");
        tokenBalancesForAddress[msg.sender][idx] = tokenBalancesForAddress[msg.sender][idx].sub(offer.amount);
        emit TokenWithdrawn(msg.sender, timestamp, idx, symbolName, offer.amount);
        require(ERC20Interface(tokens[idx].tokenContract).transfer(msg.sender, offer.amount) == true);
        offer.amount = 0;
    }
}
