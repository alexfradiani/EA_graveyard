//+------------------------------------------------------------------+
//|                                              Alx_AB_Stairs.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+
/**
 * DAILY STAIRS STRATEGY AB System
 * Based on Alx_Adv_StairScalper
 * only 2 trades simultaneously. Adjust SL to cover areas.
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
double globalAcum;  // to close stairs cycles. ensure real profits
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
order_t tradeA;
order_t tradeB;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    acum = 0;
    globalAcum = 0;
    BS.triggerState = NONE; 
    initLBS();
 
    tradeA.ticket = tradeB.ticket = -1;
 
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
    if(tradeA.ticket == -1) {  //catching first trade
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
        parseStairs(); printStairs();
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
                openOrder(OP_BUY, tradeA, Ask + DY*Point, Ask - DY*Point);
            }
        }
    }
  
    if(optype == OP_SELL) {
        if(LBS.currArea == MIDDLE_UP) { //area in right place
            if(LBS.lastExtreme == UP) {  //coming from long term trigger
                openOrder(OP_SELL, tradeA, Bid - DY*Point, Bid + DY*Point);
            }
        }
    }
}

/**
 * Verify currently running trades
 */
void parseStairs() {
    double absorbedLoss = 0;
    
    if(tradeA.ticket != -1 && tradeB.ticket == -1) {  //only one running
        if(tradeA.op_type == OP_BUY) { // is a BUY
            if(Bid >= tradeA.tp) {  //TP
                bool closed = closeOrder(tradeA);
                if(closed == TRUE)
                    globalAcum = 0;
            }
            else if(Bid <= tradeA.sl) {  //SL
                openOrder(OP_SELL, tradeB, Bid - DY*Point, tradeA.tp);
            }
            
            checkFinishStair(OP_BUY);
        }
        else {  //is a SELL
            if(Ask <= tradeA.tp) {  //TP
                bool closed = closeOrder(tradeA);
                if(closed == TRUE)
                    globalAcum = 0;
            }
            else if(Ask >= tradeA.sl) {  //SL
                openOrder(OP_BUY, tradeB, Ask + DY*Point, tradeA.tp);
            }
            
            checkFinishStair(OP_SELL);
        }
    }
    else {  //both running
        if(tradeB.op_type == OP_BUY) { //TRADE B is BUY
            if(Bid >= tradeB.tp) {  //TP
                bool closed = closeOrder(tradeB);
                if(closed == TRUE) {
                    acum += Bid - tradeB.price;
                    openOrder(OP_BUY, tradeB, Ask + DY*Point, tradeA.tp);
                }
            }
            else {
                //check if tradeA can be closed
                if(acum + tradeA.price - Ask > 0) {
                    bool closed = closeOrder(tradeA);
                    if(closed) {
                        globalAcum += acum + tradeA.price - Ask;
                        acum = 0;
                        
                        //change positions
                        tradeA = tradeB;
                        tradeB.ticket = -1;
                        
                        //check if new trade B must be opened
                        if(checkFinishStair(OP_BUY) == FALSE && tradeA.price - Bid > DY*Point)
                            openOrder(OP_SELL, tradeB, Bid - DY*Point, tradeA.tp);
                    }
                }
                
            }
        }
        else {  //TRADE B is SELL
            if(Ask <= tradeB.tp) {  //TP
                bool closed = closeOrder(tradeB);
                if(closed == TRUE) {
                    acum += tradeB.price - Ask;
                    openOrder(OP_SELL, tradeB, Bid - DY*Point, tradeA.tp);
                }
            }
            else {
                //check if tradeA can be closed
                if(acum + Bid - tradeA.price > 0) {
                    bool closed = closeOrder(tradeA);
                    if(closed) {
                        globalAcum += acum + Bid - tradeA.price;
                        acum = 0;
                        
                        //change positions
                        tradeA = tradeB;
                        tradeB.ticket = -1;
                        
                        //check if new trade B must be opened
                        if(checkFinishStair(OP_SELL) == FALSE && Ask - tradeA.price > DY*Point)
                            openOrder(OP_BUY, tradeB, Ask + DY*Point, tradeA.tp);
                    }
                }       
            }
        }
    }
} 

bool checkFinishStair(int op_type) {
    if(op_type == OP_BUY) {
        if(globalAcum > 0 && globalAcum + Bid - tradeA.price >0 ) { // try to finish stairs
            if(closeOrder(tradeA) == TRUE) {
                globalAcum = 0;
                return TRUE;
            }
        }
    }
    else {
        if(globalAcum > 0 && globalAcum + tradeA.price - Ask > 0) { // try to finish stairs
            if(closeOrder(tradeA) == TRUE) {
                globalAcum = 0;
                return TRUE;
            }
        }
    }
    
    return FALSE;
} 
 
/**
 * OPEN an order
 */
void openOrder(int op_type, order_t &trade, double dyTP, double dySL) {
    double oprice;
    double stoploss;
    double takeprofit;
    
    //create order
    if(op_type == OP_BUY) {
        oprice = MarketInfo(Symbol(), MODE_ASK);
    	stoploss = dySL;
    	takeprofit = dyTP;
    }
    else {
        oprice = MarketInfo(Symbol(), MODE_BID);
    	stoploss = dySL;
    	takeprofit = dyTP;
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
    trade.op_type = op_type;
    trade.price = oprice;
    trade.sl = stoploss;
    trade.tp = takeprofit;
    trade.ticket = order;
    trade.time = lastTime;
    trade.size = osize;
}

/**
 * CLOSE an order
 */
bool closeOrder(order_t &trade) {
    double price;
    if(trade.op_type == OP_BUY)
        price = Bid;
    else
        price = Ask;
        
    bool close = OrderClose(trade.ticket, trade.size, price, 3, Blue);
    if(close == TRUE)
        trade.ticket = -1;
        
    return close;
} 

void printStairs() {
    Print("**[acum: ", acum, ", globalAcum: ", globalAcum, "] stairs: ");
    if(tradeA.ticket != -1) Print("tradeA:", tradeA.price , " tp:", tradeA.tp , " sl:", tradeA.sl);
    if(tradeB.ticket != -1) Print("tradeB:", tradeB.price , " tp:", tradeB.tp , " sl:", tradeB.sl);
}