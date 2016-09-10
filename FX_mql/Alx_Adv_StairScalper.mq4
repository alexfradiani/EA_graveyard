//+------------------------------------------------------------------+
//|                                       Alx_Adv_StairScalper.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+
/**
 * DAILY STAIRS STRATEGY
 * escalate trades during day recursively. when trade goes wrong by a differential, start another trade in opposite direction
 * escalate until accumulated pips generate profit. Initial trigger with bollinger bands (short and long term)
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define MIDDLE_UP 0.5
#define NONE 0
#define MIDDLE_DOWN -0.5
#define DOWN -1
#define DY 10

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

double acum;        // acumulated pips for stairs resolution
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
order_t stairs[50]; //max 50 stairs
int sI;             //stair index

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    acum = 0;
    sI = 0;
    BS.triggerState = NONE; 
    initLBS();
 
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
    if(sI == 0) {  //catching first trade
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
                openOrder(OP_BUY, DY*Point);
            }
        }
    }
    
    if(optype == OP_SELL) {
        if(LBS.currArea == MIDDLE_UP) { //area in right place
            if(LBS.lastExtreme == UP) {  //coming from long term trigger
                openOrder(OP_SELL, DY*Point);
            }
        }
    }
}

/**
 * Verify currently running trades
 */
void parseStairs() {
    //take possible profits
    if(acum > 0 && sI <= 2) {
        Print("ACUM TAKEN: ", acum/Point, " pip(s)");
        acum = 0;
    }
    
    //----------------------------------------------------------check running stair
    if(stairs[sI -1].op_type == OP_BUY) {  //is a buy
        if(Bid >= stairs[sI - 1].tp) {  //TP
            double diff = Bid - stairs[sI - 1].price;
            acum += diff;
            closeOrder(sI - 1);
            
            //check if open a new stair
            if(sI > 1)
                openOrder(OP_BUY, DY*Point);
        }
        else if(Bid <= stairs[sI - 1].sl) {  //SL
            openOrder(OP_SELL, stairs[sI - 1].price - Bid);
        }
    }
    else {  //is a sell
        if(Ask <= stairs[sI - 1].tp) {  //TP
            double diff = stairs[sI - 1].price - Ask;
            acum += diff;
            closeOrder(sI - 1);
            
            //check if open a new stair
            if(sI > 1)
                openOrder(OP_SELL, DY*Point);
        }
        else if(Ask >= stairs[sI - 1].sl) {  //SL
            openOrder(OP_BUY, Ask - stairs[sI - 1].price);
        }
    }
    
    //------------------------------------------------------------parse older stairs
    for(int i = 0; i < sI - 1; i++) {
        if(stairs[i].op_type == OP_BUY) {  //is a buy
            //check if reached tp
            if(Bid >= stairs[i].tp) {  //TP
                bool close = closeOrder(i);
                if(close == TRUE) {
                    double diff = Bid - stairs[i].price;
                    acum += diff;
                }
            }
            else if( i == 0 && acum + Bid - stairs[i].price >= DY*Point) { //check if acum difference can close it
                bool close = closeOrder(i);
                if(close == TRUE) {
                    acum += Bid - stairs[i].price;
                }
            }
        }
        else {  //is a sell
            //check if reached tp
            if(Ask <= stairs[i].tp) {  //TP
                bool close = closeOrder(i);
                if(close == TRUE) {
                    double diff = stairs[i].price - Ask;
                    acum += diff;
                }
            }
            else if(i == 0 && acum + stairs[i].price - Ask >= DY*Point) { //check if acum difference can close it
                bool close = closeOrder(i);
                if(close == TRUE) {
                    acum += stairs[i].price - Ask;
                }
            }
        }
    }
    
    //--------------------------------------------------------------Reorder array after closing stairs    
    for(int i = 0; i < sI; i++) {
        if(stairs[i].ticket == -1) {
            for(int p = i; p < sI; p++) {
                stairs[p] = stairs[p + 1];
            }
            i--;
            sI--;
        }
    }
    printStairs();
} 
 
/**
 * OPEN an order
 */
void openOrder(int op_type, double dy) {  
    double oprice;
    double stoploss;
    double takeprofit;
    
    //create order
    if(op_type == OP_BUY) {
        oprice = MarketInfo(Symbol(), MODE_ASK);
    	stoploss = oprice - dy;
    	takeprofit = oprice + dy;
    }
    else {
        oprice = MarketInfo(Symbol(), MODE_BID);
    	stoploss = oprice + dy;
    	takeprofit = oprice - dy;
    }
	double osize = R_VOL;
	
	int order = OrderSend(
		Symbol(), //symbol
		op_type, //operation
		osize, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    stairs[sI].op_type = op_type;
    stairs[sI].price = oprice;
    stairs[sI].sl = stoploss;
    stairs[sI].tp = takeprofit;
    stairs[sI].ticket = order;
    stairs[sI].time = lastTime;
    stairs[sI].size = osize;
    sI++;
}

/**
 * CLOSE an order
 */
bool closeOrder(int i) {
    double price;
    if(stairs[i].op_type == OP_BUY)
        price = Bid;
    else
        price = Ask;
        
    bool close = OrderClose(stairs[i].ticket, stairs[i].size, price, 3, Blue);
    if(close == TRUE)
        stairs[i].ticket = -1;
        
    return close;
} 

void printStairs() {
    Print("***start stairs:");
    for(int i = 0; i < sI; i++) {
        Print("S", i, ": p:", stairs[i].price , " tp:", stairs[i].tp , " sl:", stairs[i].sl);
    }
    Print("***close stairs");
}