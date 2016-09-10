//+------------------------------------------------------------------+
//|                                       ALX_v32_D_ADX_M1RecT.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * ADX Daily for long-term trend. M1 ADX triggers.
 * RULES:
 *    - M1 trigger in the direction of long-term trend
 *    - Recovery orders when adx goes in opposite direction, acumlate pips for original trade.
 * EXIT:
 *    - BASE POINTS profit or loss.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define MAX_TRADES 10

#define UP 1
#define DOWN -1
#define NONE 0

#define BASE_PIPS 50

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
};

struct trade_t {      //DATA for trade logic
    order_t original;
    order_t recovery;
    double acum;
};
trade_t trades[MAX_TRADES];
int tradeCount;

datetime lastBarTime;
int trendState = 0;
double lastCrossPrice;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastBarTime = Time[0];
    lastCrossPrice = Bid;
    
    tradeCount = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { /*...*/ }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() { 
    //------------------------------------------------------------------------- TRADE rules
    //GLOBAL SIDE
    double adxMinus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
    double adxPlus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
    double adxdiff = MathAbs(adxMinus - adxPlus);
    
    double adxMinusOld = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
    double adxPlusOld = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
    double diffOld = MathAbs(adxMinusOld - adxPlusOld);
    
    if(Time[0] != lastBarTime) {
        if(adxdiff >= diffOld) {
            if(adxPlus > adxMinus)
                trendState = UP;
            else
                trendState = DOWN;
        }
        else if(adxdiff < diffOld) {
            if(adxPlus > adxMinus)
                trendState = DOWN;
            else
                trendState = UP;
        }
        
        //LOCAL SIDE
        double adxP = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
        double adxM = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
        double adxPOld = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_PLUSDI, 2);
        double adxMOld = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_MINUSDI, 2);
        if(trendState == DOWN) {
            if(adxPOld > adxMOld && adxP < adxM) {
                if(Ask < lastCrossPrice && tradeCount < MAX_TRADES) {
                    createSell(trades[tradeCount].original);
                    trades[tradeCount].recovery.ticket = -1;
                    tradeCount++;
                }
                
                lastCrossPrice = Ask;
            }
        }
        else {
            if(adxPOld < adxMOld && adxP > adxM) {
                if(Bid > lastCrossPrice && tradeCount < MAX_TRADES) {
                    createBuy(trades[tradeCount].original);
                    trades[tradeCount].recovery.ticket = -1;
                    tradeCount++;
                }
                
                lastCrossPrice = Bid;
            }
        }
        
        lastBarTime = Time[0];  
    }
    
    //------------------------------------------------------------------------- EXIT & RECOVERY rules
    for(int i = 0; i < tradeCount; i++) {
        double adxP = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
        double adxM = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
        double adxPOld = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_PLUSDI, 2);
        double adxMOld = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_MINUSDI, 2);
        
        if(trades[i].original.op_type == OP_BUY) {  //original order is BUY
            double diff = Bid - trades[i].original.price;
            //check recovery trade
            if(trades[i].recovery.ticket == -1) { //verify if recovery must be opened
                if((adxPOld > adxMOld && adxP < adxM) && Bid < trades[i].original.price) {
                    createSell(trades[i].recovery);
                }
            }
            else {
                if(adxPOld < adxMOld && adxP > adxM) {
                    bool close = OrderClose(trades[i].recovery.ticket, trades[i].recovery.size, Ask, 3, Blue);
                    if(close == TRUE) {
                        trades[i].recovery.ticket = -1;
                        trades[i].acum += trades[i].recovery.price - Ask;
                    }
                    else
                        diff += trades[i].recovery.price - Ask;
                }
                else
                    diff += trades[i].recovery.price - Ask;
            }
            
            diff += trades[i].acum;
            if(diff >= BASE_PIPS*Point || diff <= -1*BASE_PIPS*Point) {
                closeTrade(i);
            }
        }
        else if(trades[i].original.op_type == OP_SELL) {  //original order is SELL
            double diff = trades[i].original.price - Ask;
            //check recovery trade
            if(trades[i].recovery.ticket == -1) { //verify if recovery must be opened
                if((adxPOld < adxMOld && adxP > adxM) && Ask > trades[i].original.price) {
                    createBuy(trades[i].recovery);
                }
            }
            else {
                if(adxPOld > adxMOld && adxP < adxM) {
                    bool close = OrderClose(trades[i].recovery.ticket, trades[i].recovery.size, Ask, 3, Blue);
                    if(close == TRUE) {
                        trades[i].recovery.ticket = -1;
                        trades[i].acum += Bid - trades[i].original.price;
                    }
                    else
                        diff += Bid - trades[i].original.price;
                }
                else
                    diff += Bid - trades[i].original.price;
            }
            
            diff += trades[i].acum;
            if(diff >= BASE_PIPS*Point || diff <= -1*BASE_PIPS*Point) {
                closeTrade(i);
            }
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 
 
/**
 * Create a buy order
 */
void createBuy(order_t &buyOrder) {
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - BASE_PIPS*Point + MarketInfo(Symbol(), MODE_SPREAD)*Point;

	double osize = R_VOL;
	
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		osize, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.ticket = order;
    buyOrder.size = osize;
}

/**
 * Create a sell order
 */
void createSell(order_t &sellOrder) {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = oprice + BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point;
	
	double osize = R_VOL;
	
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		osize, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
    sellOrder.ticket = order;
    sellOrder.size = osize;
}

void closeTrade(int i) {
    bool stillOpen = TRUE;
    
    while(stillOpen) {
        bool recoveryClosed;
        if(trades[i].recovery.ticket != -1)
            recoveryClosed = OrderClose(trades[i].recovery.ticket, trades[i].recovery.size, Ask, 3, Blue);
        else
            recoveryClosed = TRUE;
            
        bool originalClosed;
        if(trades[i].original.ticket != -1)
            originalClosed = OrderClose(trades[i].original.ticket, trades[i].original.size, Ask, 3, Blue);
        else
            originalClosed = TRUE;
        
        if(recoveryClosed == TRUE && originalClosed == TRUE)
            stillOpen = FALSE;
        else
            stillOpen = TRUE;
    }
    
    reOrderTrades(i);
}

void reOrderTrades(int pos) {
    for(int i = pos; i < tradeCount; i++) {
        trades[i].acum = trades[i+1].acum;
        
        trades[i].original.op_type = trades[i+1].original.op_type;
        trades[i].original.price = trades[i+1].original.price;
        trades[i].original.sl = trades[i+1].original.sl;
        trades[i].original.ticket = trades[i+1].original.ticket;
        trades[i].original.size = trades[i+1].original.size;
        
        trades[i].recovery.op_type = trades[i+1].recovery.op_type;
        trades[i].recovery.price = trades[i+1].recovery.price;
        trades[i].recovery.sl = trades[i+1].recovery.sl;
        trades[i].recovery.ticket = trades[i+1].recovery.ticket;
        trades[i].recovery.size = trades[i+1].recovery.size;
    }
    
    tradeCount--;
}