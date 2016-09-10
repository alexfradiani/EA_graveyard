//+------------------------------------------------------------------+
//|                                         Alx_AdvancedStairs.mq4   |
//|                                             Alexander Fradiani   |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * DAILY STAIRS STRATEGY
 * escalate trades during day recursively. 
 * when trade goes wrong by a differential, start another trade in opposite direction
 * escalate until accumulated pips generate profit.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define MIDDLE_UP 0.5
#define NONE 0
#define MIDDLE_DOWN -0.5
#define DOWN -1

#define DY 50

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

//Structure for bollinger triggers
struct _BS {
    int triggerState;
};
_BS BS;

// structure for long-term bollinger checking
struct _LBS {
    double currArea;
    int lastExtreme;
};
_LBS LBS;

int workingDay;     //day of current operation
double dayPips;        //accumulated of a day
datetime lastTime;  //for execution on each bar

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    datetime time;
    double size;
};

struct trade_t {
    double acum;     //accumulated pips with stair trades
    order_t order;   //associated order
    int parentPointer;  //parent trade
    int stairPointer;   //stair created
};
trade_t stairs[40]; //max 40 stairs.
int stairIndex;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    workingDay = Day();
    dayPips = 0;
    
    BS.triggerState = NONE;
    
    initLBS();
    
    stairIndex = -1;
    
    //for testing..
    createSell();
    
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
    /*if(Day() != workingDay) { //new day
        workingDay = Day();
        dayPips = 0;
    }
    
    if( dayPips >= BASE_PIPS*Point && dayIsClear() == TRUE ) {  //goal of day reached, don't risk more...
        RefreshRates();
        return;
    }
    else */
    
    parseStrategy();
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * INIT Long term bollinger sensor
 * determine last extreme when starting EA 
 */
void initLBS() {
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
    if(stairIndex == -1) {  //catching first trade of day
        double downBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 1);
        double upBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 1);
        double middleBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
        double ldBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_LOWER, 1);
        double luBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_UPPER, 1);
        double lmBand = iBands(NULL, 0, 1200, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
        
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
    else {
        parseStairs();
    }
}

/**
 * Only for starter trades
 * When a trigger is dispatched, check global conditions for possible trade
 */
void dispatchEvent(int optype) {
    if(optype == OP_BUY) {
        if(LBS.currArea == MIDDLE_DOWN) { //area in right place
            if(LBS.lastExtreme == DOWN) {  //coming from long term trigger
                createBuy();
            }
        }
    }
    
    if(optype == OP_SELL) {
        if(LBS.currArea == MIDDLE_UP) { //area in right place
            if(LBS.lastExtreme == UP) {  //coming from long term trigger
                createSell();
            }
        }
    }
}

/**
 * Verify currently running trades
 */
void parseStairs() {
    for(int i = 0; i < stairIndex; i++) {   //loop through all trades
        bool removeAndReorder = FALSE;
        
        //set original order profit
        double currProfit = 0;
        int oppositeOp = 0;
        if(stairs[i].order.op_type == OP_BUY) {
            currProfit = Bid - stairs[i].order.price;
            oppositeOp = OP_SELL;
        }
        else if(stairs[i].order.op_type == OP_SELL) {
            currProfit = stairs[i].order.price - Ask;
            oppositeOp = OP_BUY;
        }
            
        double acum = stairs[i].acum;
        int threshold  = 0;
        if(stairs[i].order.op_type == OP_BUY && stairs[i].order.price + acum + currProfit >= stairs[i].order.tp)
            threshold = 1;
        if(stairs[i].order.op_type == OP_SELL && stairs[i].order.price - acum - currProfit <= stairs[i].order.tp)
            threshold = 1;
        if(stairs[i].order.op_type == OP_BUY && stairs[i].order.price + currProfit <= stairs[i].order.sl)
            threshold = -1;
        if(stairs[i].order.op_type == OP_SELL && stairs[i].order.price - currProfit >= stairs[i].order.sl)
            threshold = -1;
        
        if(threshold > 0) {  //good movement threshold
            if(stairs[i].parentPointer == -1) { //original trade
                closeStair(stairs[i].order);
                
                if(stairs[i].stairPointer != -1) {  //update the child
                    int toUpdate = stairs[i].stairPointer;
                    stairs[toUpdate].parentPointer = -1;
                }  
                
                removeAndReorder = TRUE;
            }
            else { //stair trade
                int toUpdate = stairs[i].parentPointer;
                stairs[toUpdate].acum += acum + currProfit;
                closeStair(stairs[i].order);
                
                //run a new stair
                updateStair(toUpdate, i);
            }   
        }
        else if(threshold < 0) {  //bad movement threshold
            if(stairs[i].stairPointer == -1) {  //stair must be created
                if(priceCovered() == FALSE) {
                    stairs[i].stairPointer = stairIndex;
                    createStair(i);
                }
            }
        }
        
        if(removeAndReorder == TRUE) { //Reorder array after closing parent trade
            for(int p = i; p < stairIndex; p++) {
                stairs[p] = stairs[p + 1];
            }
            i--;
            stairIndex--;
            if(stairIndex == 0)
                stairIndex = -1;
        }
    }
}

/**
 * avoid overriding of stairs
 */
bool priceCovered() {
    for(int i = 0; i < stairIndex; i++) {
        double top;
        double bottom;
        
        if(stairs[i].order.op_type == OP_BUY) {
            top = stairs[i].order.tp;
            bottom = stairs[i].order.sl;
        }
        else {
            top = stairs[i].order.sl;
            bottom = stairs[i].order.tp;
        }
        
        if(Bid <= top && Bid >= bottom)
            return TRUE;
        if(Ask <= top && Ask >= bottom)
            return TRUE;
    }
    
    return FALSE;
}

/**
 * Close stair
 */
void closeStair(order_t &order) {
    double price;
    if(order.op_type == OP_BUY)
        price = Bid;
    else
        price = Ask;
        
    int close = OrderClose(order.ticket, order.size, price, 3, Blue);
} 

/**
 * update a stair
 */
void updateStair(int parent, int index) {
    stairs[index].acum = 0;
    stairs[index].parentPointer = parent;
    
    double oprice;
    double stoploss;
    double takeprofit;
    
    int optype = stairs[index].order.op_type;
    if(optype == OP_BUY) {
        oprice = MarketInfo(Symbol(), MODE_ASK);
    	stoploss = oprice - DY*Point;
    	takeprofit = oprice + DY*Point;
    }
    else {
        oprice = MarketInfo(Symbol(), MODE_BID);
    	stoploss = oprice + DY*Point;
    	takeprofit = oprice - DY*Point;
    }

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
    stairs[index].order.op_type = optype;
    stairs[index].order.price = oprice;
    stairs[index].order.sl = stoploss;
    stairs[index].order.tp = takeprofit;
    stairs[index].order.ticket = order;
    stairs[index].order.time = lastTime;
    stairs[index].order.size = osize;
}

/**
 * create a new stair
 */
void createStair(int index) {
    stairs[stairIndex].acum = 0;
    stairs[stairIndex].parentPointer = index;
    stairs[stairIndex].stairPointer = -1;
    
    double oprice;
    double stoploss;
    double takeprofit;
    
    int optype = stairs[index].order.op_type == OP_BUY ? OP_SELL : OP_BUY;
    if(optype == OP_BUY) {
        oprice = MarketInfo(Symbol(), MODE_ASK);
    	stoploss = oprice - DY*Point;
    	takeprofit = oprice + DY*Point;
    }
    else {
        oprice = MarketInfo(Symbol(), MODE_BID);
    	stoploss = oprice + DY*Point;
    	takeprofit = oprice - DY*Point;
    }

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
    stairs[stairIndex].order.op_type = optype;
    stairs[stairIndex].order.price = oprice;
    stairs[stairIndex].order.sl = stoploss;
    stairs[stairIndex].order.tp = takeprofit;
    stairs[stairIndex].order.ticket = order;
    stairs[stairIndex].order.time = lastTime;
    stairs[stairIndex].order.size = osize;
    
    stairIndex++;
}
 
/**
 * Create a starter buy order
 */
void createBuy() {
    if(stairIndex >= 0) {
        Alert("CANNOT START BUY, stairs not cleared");
        Print("CANNOT START BUY, stairs not cleared");
        
        return;
    }
    
    stairIndex = 0;
    stairs[stairIndex].acum = 0;
    stairs[stairIndex].parentPointer = -1;
    stairs[stairIndex].stairPointer = -1;
    
    //create order
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - DY*Point;
	double takeprofit = oprice + DY*Point;

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
    stairs[stairIndex].order.op_type = optype;
    stairs[stairIndex].order.price = oprice;
    stairs[stairIndex].order.sl = stoploss;
    stairs[stairIndex].order.tp = takeprofit;
    stairs[stairIndex].order.ticket = order;
    stairs[stairIndex].order.time = lastTime;
    stairs[stairIndex].order.size = osize;
    
    stairIndex++;
}

/**
 * Create a starter sell order
 */
void createSell() {
    if(stairIndex >= 0) {
        Alert("CANNOT START SELL, stairs not cleared");
        Print("CANNOT START SELL, stairs not cleared");
        
        return;
    }
    
    stairIndex = 0;
    stairs[stairIndex].acum = 0;
    stairs[stairIndex].parentPointer = -1;
    stairs[stairIndex].stairPointer = -1;
    
    //create order
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = oprice + DY*Point;
	double takeprofit = oprice - DY*Point;

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
    stairs[stairIndex].order.op_type = optype;
    stairs[stairIndex].order.price = oprice;
    stairs[stairIndex].order.sl = stoploss;
    stairs[stairIndex].order.tp = takeprofit;
    stairs[stairIndex].order.ticket = order;
    stairs[stairIndex].order.time = lastTime;
    stairs[stairIndex].order.size = osize;
    
    stairIndex++;
}