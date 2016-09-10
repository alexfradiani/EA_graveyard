//+------------------------------------------------------------------+
//|                                     ALX_AdvancedBollinger.mq4    |
//|                                             Alexander Fradiani   |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * ADVANCED BOLLINGER
 * statistically determine conditions for bollinger trigger with better chances of profit
 * establish day approachable goals to reduce bad probabilities
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define MIDDLE_UP 0.5
#define NONE 0
#define MIDDLE_DOWN -0.5
#define DOWN -1

#define BASE_PIPS  50

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

//Structure for bollinger triggers
struct _BS {
    int triggerState;
};
_BS BS;

// structure for long-term bollinger checking
struct _LBS {
    bool blockedSell;
    bool blockedBuy;
    double currArea;
    int lastExtreme;
};
_LBS LBS;

int workingDay;     //day of current operation
double pips;        //accumulated of a day
datetime lastTime;  //for execution on each bar

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    double tp;
    int op_type;
    datetime time;
    double size;
};
order_t buyOrder;
order_t sellOrder;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    workingDay = Day();
    pips = 0;
    
    BS.triggerState = NONE;
    
    initLBS();
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //...  
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //Day goal verification
    if(Day() != workingDay) { //new day
        workingDay = Day();
        pips = 0;
    }
    
    if(pips >= BASE_PIPS*Point) {  //goal of day reached, don't risk more...
        RefreshRates();
        return;
    }
    else
        parseStrategy();
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * INIT Long term bollinger sensor
 * determine last extreme when starting EA 
 */
void initLBS() {    
    LBS.blockedBuy = FALSE;
    LBS.blockedSell = FALSE;
    LBS.currArea = NONE;
    LBS.lastExtreme = NONE;
    
    int i = 1;
    while(LBS.lastExtreme == NONE) {
        double ldBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_LOWER, i);
        double luBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_UPPER, i);
        
        if(Close[i] >= luBand)
            LBS.lastExtreme = UP;
        else if(Close[i] <= ldBand)
            LBS.lastExtreme = DOWN;
        
        i++;
    }
} 
 
/**
 * Render conditions for trades.
 */
void parseStrategy() {
    double downBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 1);
    double upBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 1);
    double middleBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
    double ldBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_LOWER, 1);
    double luBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_UPPER, 1);
    double lmBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
    
    checkCurrentTrades();
    
    if(lastTime != Time[0]) {
        //long term orientation
        double prevArea = LBS.currArea;
        
        if(Close[1] >= luBand) {
            LBS.currArea = UP;
            LBS.lastExtreme = UP;    
        }
        else if(Close[1] > lmBand)
            LBS.currArea = MIDDLE_UP;
        else if(Close[1] == lmBand)
            LBS.currArea = NONE;
        else if(Close[1] > ldBand)
            LBS.currArea = MIDDLE_DOWN;
        else {
            LBS.currArea = DOWN;
            LBS.lastExtreme = DOWN;
        }
        
        if(prevArea != LBS.currArea)
            LBS.blockedBuy = LBS.blockedSell = FALSE;
        
        //short term trigger
        if(Close[1] >= upBand)
            BS.triggerState = UP;
        if(Open[0] <= upBand && BS.triggerState == UP) {
            dispatchEvent(OP_SELL);
            
            BS.triggerState = NONE;
        }
        
        if(Close[1] <= downBand) {  //possible buy trigger
            BS.triggerState = DOWN;
        }
        if(Open[0] >= downBand && BS.triggerState == DOWN) {
            dispatchEvent(OP_BUY);
            
            BS.triggerState = NONE;
        }
        
        lastTime = Time[0];
    }
}

/**
 * Verify currently running trades
 */
void checkCurrentTrades() {
    if(buyOrder.ticket != -1) {
        double diff = Bid - buyOrder.price;
        
        if(Bid <= buyOrder.sl) {
            closeBuy();
            pips += diff;
            
            if(diff < 0) //bad trade
                LBS.blockedBuy = TRUE;
        }
        else if(Bid - buyOrder.price >= 100*Point) {
            int times = floor( (Bid - buyOrder.price)/(50*Point) );
            buyOrder.sl = buyOrder.price + times*50*Point;
        }
    }
    
    if(sellOrder.ticket != -1) {
        double diff = sellOrder.price - Ask;
        
        if(Ask >= sellOrder.sl) {
            closeSell();
            pips += diff;
            
            if(diff < 0) //bad trade
                LBS.blockedSell = TRUE;
        }
        else if(sellOrder.price - Ask >= 100*Point) {
            int times = floor( (sellOrder.price - Ask)/(50*Point) );
            sellOrder.sl = sellOrder.price - times*50*Point;
        }
    }
}

/**
 * When a trigger is dispatched, check global conditions for possible trade
 */
void dispatchEvent(int optype) {
    if(buyOrder.ticket != -1 || sellOrder.ticket != -1)
        return;
    
    if(optype == OP_BUY) {
        if(LBS.blockedBuy == FALSE) {
            if(LBS.currArea == MIDDLE_DOWN) { //area in right place
                if(LBS.lastExtreme == DOWN) {  //coming from long term trigger
                    createBuy();
                }
            }
        }
    }
    
    if(optype == OP_SELL) {
        if(LBS.blockedSell == FALSE) {
            if(LBS.currArea == MIDDLE_UP) { //area in right place
                if(LBS.lastExtreme == UP) {  //coming from long term trigger
                    createSell();
                }
            }
        }
    }
}
 
/**
 * Create a buy order
 */
void createBuy() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);
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
    buyOrder.time = lastTime;
    buyOrder.size = osize;
}

/**
 * Create a sell order
 */
void createSell() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);
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
    sellOrder.time = lastTime;
    sellOrder.size = osize;
}

void closeBuy() {
    OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3, Blue);
    sellOrder.ticket = -1;
}