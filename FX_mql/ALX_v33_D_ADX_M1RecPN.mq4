//+------------------------------------------------------------------+
//|                                      ALX_v33_D_ADX_M1RecPN.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * ADX Daily for long-term trend. M1 ADX triggers.
 * RULES:
 *    - M1 trigger in the direction of long-term trend
 *    - Recovery Positive/Negative orders when SL is reached
 * EXIT:
 *    - BASE POINTS profit or recovery loss (when long term trend changes).
 */
 
#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define MAX_TRADES 10

#define UP 1
#define DOWN -1
#define NONE 0
#define NORMAL 0
#define TRAILING_PROFIT 1
#define RECOVERY -1

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

struct recovery_t {
    order_t positive;
    order_t negative;
};

struct trade_t {      //DATA for trade logic
    order_t original;
    recovery_t recovery;
    int status;
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
                    if(areaAvailable(OP_SELL) == TRUE) {
                        createSell(trades[tradeCount].original);
                        trades[tradeCount].recovery.positive.ticket = -1;
                        trades[tradeCount].recovery.negative.ticket = -1;
                        tradeCount++;
                    }
                }
                
                lastCrossPrice = Ask;
            }
        }
        else {
            if(adxPOld < adxMOld && adxP > adxM) {
                if(Bid > lastCrossPrice && tradeCount < MAX_TRADES) {
                    if(areaAvailable(OP_BUY) == TRUE) {
                        createBuy(trades[tradeCount].original);
                        trades[tradeCount].recovery.positive.ticket = -1;
                        trades[tradeCount].recovery.negative.ticket = -1;
                        tradeCount++;
                    }
                }
                
                lastCrossPrice = Bid;
            }
        }
        
        lastBarTime = Time[0];  
    }
    
    //------------------------------------------------------------------------- EXIT & RECOVERY rules
    for(int i = 0; i < tradeCount; i++) {    
        if(trades[i].original.op_type == OP_BUY) {  //original order is BUY
            if(trendState == DOWN) {  //long-term trend change, close.
                closeTrade(i);
            }
            else {
                if(Bid <= trades[i].original.sl && trades[i].status == NORMAL) {   //enter in recovery
                    if(trades[i].recovery.positive.ticket == -1) {   //start recovery
                        createBuy(trades[i].recovery.positive);
                        createSell(trades[i].recovery.negative);
                    }
                }
                
                if(Bid >= trades[i].original.tp) {  //enter in profits
                    trades[i].status = TRAILING_PROFIT;
                    double times = floor( (Bid - trades[i].original.price)/(BASE_PIPS*Point) );
                    trades[i].original.sl = trades[i].original.price + times*BASE_PIPS*Point;
                }
                
                if(trades[i].status == TRAILING_PROFIT && Bid < trades[i].original.sl) {  //take profits
                    closeTrade(i);
                }
            }
        }
        else if(trades[i].original.op_type == OP_SELL) {  //original order is SELL
            if(trendState == UP) {  //long-term trend change, close.
                closeTrade(i);
            }
            else {
                if(Bid <= trades[i].original.sl && trades[i].status == NORMAL) {   //enter in recovery
                    trades[i].status = RECOVERY;
                    createBuy(trades[i].recovery.positive);
                    createSell(trades[i].recovery.negative);
                }
                
                if(Ask <= trades[i].original.tp) {  //enter in profits
                    trades[i].status = TRAILING_PROFIT;
                    double times = floor( (trades[i].original.price - Ask)/(BASE_PIPS*Point) );
                    trades[i].original.sl = trades[i].original.price - times*BASE_PIPS*Point;
                }
                
                if(trades[i].status == TRAILING_PROFIT && Ask > trades[i].original.sl) {  //take profits
                    closeTrade(i);
                }
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
    double takeprofit = oprice + BASE_PIPS*Point + MarketInfo(Symbol(), MODE_SPREAD)*Point;
    
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
    buyOrder.tp = takeprofit;
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
	double takeprofit = oprice - BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point;
	
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
    sellOrder.tp = takeprofit;
    sellOrder.ticket = order;
    sellOrder.size = osize;
}

void closeTrade(int i) {
    bool stillOpen = TRUE;
    
    while(stillOpen) {
        bool recoveryPClosed;
        if(trades[i].recovery.positive.ticket != -1)
            recoveryPClosed = OrderClose(trades[i].recovery.positive.ticket, trades[i].recovery.positive.size, Ask, 3, Blue);
        else
            recoveryPClosed = TRUE;
        
        bool recoveryNClosed;
        if(trades[i].recovery.negative.ticket != -1)
            recoveryNClosed = OrderClose(trades[i].recovery.negative.ticket, trades[i].recovery.negative.size, Ask, 3, Blue);
        else
            recoveryNClosed = TRUE;
            
        bool originalClosed;
        if(trades[i].original.ticket != -1)
            originalClosed = OrderClose(trades[i].original.ticket, trades[i].original.size, Ask, 3, Blue);
        else
            originalClosed = TRUE;
        
        if(recoveryPClosed == TRUE && recoveryNClosed == TRUE && originalClosed == TRUE)
            stillOpen = FALSE;
        else
            stillOpen = TRUE;
    }
    
    reOrderTrades(i);
}

void reOrderTrades(int pos) {
    for(int i = pos; i < tradeCount; i++) {
        trades[i].status = trades[i+1].status;
        
        trades[i].original.op_type = trades[i+1].original.op_type;
        trades[i].original.price = trades[i+1].original.price;
        trades[i].original.sl = trades[i+1].original.sl;
        trades[i].original.ticket = trades[i+1].original.ticket;
        trades[i].original.size = trades[i+1].original.size;
        
        trades[i].recovery.positive.op_type = trades[i+1].recovery.positive.op_type;
        trades[i].recovery.positive.price = trades[i+1].recovery.positive.price;
        trades[i].recovery.positive.sl = trades[i+1].recovery.positive.sl;
        trades[i].recovery.positive.ticket = trades[i+1].recovery.positive.ticket;
        trades[i].recovery.positive.size = trades[i+1].recovery.positive.size;
        
        trades[i].recovery.negative.op_type = trades[i+1].recovery.negative.op_type;
        trades[i].recovery.negative.price = trades[i+1].recovery.negative.price;
        trades[i].recovery.negative.sl = trades[i+1].recovery.negative.sl;
        trades[i].recovery.negative.ticket = trades[i+1].recovery.negative.ticket;
        trades[i].recovery.negative.size = trades[i+1].recovery.negative.size;
    }
    
    tradeCount--;
}

/**
 * Avoid overlapping
 */
bool areaAvailable(int op_type) {
    double price;
    
    if(op_type == OP_BUY)
        price = Bid;
    else
        price = Ask;
    
    for(int i = 0; i < tradeCount; i++) {
        if(trades[i].original.op_type == OP_BUY) {
            if(price >= trades[i].original.sl && price <= trades[i].original.tp)
                return FALSE;
        }
        else {
            if(price <= trades[i].original.sl && price >= trades[i].original.tp)
                return FALSE;
        }
    }
    
    return TRUE;
}