//+------------------------------------------------------------------+
//|                                  ALX_v61_UltraGale_SideAB_v2.mq4 |
//|                               Copyright 2015, Alexander Fradiani |
//|                                         https://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * Fusion of grid behaviour both in trend and against trend
 *
 * SideA executes buy cycle, expecting trend continuation if bullish price action, or retracement if bearish
 * SideB executes sell cycle, expecting trend continuation if bearish price action, or retracement if bullish
 *
 * V2 - difference from original in creating the martingale steps,
 *      this version adds new leves for both the profiting side and the losing side 
 */

#property copyright "Copyright 2015, Alexander Fradiani"
#property link      "https://www.fradiani.com"
#property version   "1.00"
#property strict

//Money Management
#define MAX_LOSS 1000
#define GRID_Y 100

//Cycles constants
#define INIT_SIZE 0.01
#define SIZE_STEP 0.01
#define PROFIT_STEPS 2
#define SLIPPAGE 5

#define SIDE_A 1
#define SIDE_B -1
#define NONE 0

//Order structure
struct order_t {     
    int ticket;
    double price;
    int op_type;
    double size;
    string symbol;
    double sl;
    double tp;
};
order_t A_order, B_order;

//Cycle control variables
int cycleIsActive;
int profitSide;
double A_accum, B_accum;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    A_order.ticket = -1;
    B_order.ticket = -1;
    
    profitSide = NONE;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    A_order.ticket = -1;
    B_order.ticket = -1;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //--------------------------------------------------------------------------------------------- TIME metric and trade rules
    datetime currentTime = TimeCurrent();
    int h = TimeHour(currentTime);
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    double middleBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    if(bid >= middleBand - 5*point && bid <= middleBand + 5*point) {  //around middle bollinger
        if(cycleIsActive == FALSE) {
            A_createBuy(INIT_SIZE);
            B_createSell(INIT_SIZE);
            
            cycleIsActive = TRUE;
        }
    }
    
    if(cycleIsActive == TRUE) {
        if( bid <= A_order.sl && (profitSide == NONE || profitSide == SIDE_B) ) {  //defining side
            A_createBuy(A_order.size + SIZE_STEP);
            profitSide = SIDE_B;
        }
        
        if( ask >= B_order.sl && (profitSide == NONE || profitSide == SIDE_A) ) {  //defining side
            B_createSell(B_order.size + SIZE_STEP);
            profitSide = SIDE_A;
        }
        
        if(profitSide == SIDE_A) {
            if(bid >= A_order.price + PROFIT_STEPS*GRID_Y*point && A_accum >= 0)  //new level in buy side when profiting
                A_createBuy(A_order.size + SIZE_STEP);
        }
        
        if(profitSide == SIDE_B) {
            if(ask <= B_order.price - PROFIT_STEPS*GRID_Y*point && B_accum >= 0)  //new level in sell side when profiting
                B_createSell(B_order.size + SIZE_STEP);
        }
        
        //Equilibrium point. take profits
        double accumA = (bid - A_order.price)*A_order.size/point + A_accum;
        double accumB = (B_order.price - ask)*B_order.size/point + B_accum;
        if(accumA + accumB >= INIT_SIZE * GRID_Y) {
            Print("accumA: ", accumA, " accumB: ", accumB);
            closeCycle();
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/********************************************** GENERAL Functions ************************************************************/

/**
 * close both sides
 */
void closeCycle() {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    
    bool closeA = OrderClose(A_order.ticket, A_order.size, bid, SLIPPAGE, clrNONE);
    bool closeB = OrderClose(B_order.ticket, B_order.size, ask, SLIPPAGE, clrNONE);
    
    A_order.ticket = -1;
    B_order.ticket = -1;
    
    A_accum = 0;
    B_accum = 0;
    
    cycleIsActive = FALSE;
    profitSide = NONE;
}

/********************************************** SIDE A Functions *************************************************************/

/**
 * Try New level
 * when prices has moved a significant amount, 
 * try to increase buy size without affecting possible retrace profit
 */
void A_tryNewLevel() {
    string symbol = Symbol();
    double point = MarketInfo(symbol, MODE_POINT);
    double ask = MarketInfo(symbol, MODE_ASK);
    double bid = MarketInfo(symbol, MODE_BID);
    double spread = MarketInfo(symbol, MODE_SPREAD);
    
    //Determine necessary retrace for sideB break even
    double neededRetrace = spread + MathAbs(B_accum) / B_order.size;
    
    //check if retracement will maintain side A profitable
    double sideAProfit = A_accum + (bid - A_order.price)*A_order.size/point;
    double nextSize = A_order.size + SIZE_STEP;
    if(sideAProfit - (neededRetrace*nextSize) > 0) { //execute next level
        Print("try new A level. neededRetrace: ", neededRetrace, " Aprofits: ", sideAProfit, " nextSize: ", nextSize);
        if(OrderClose(A_order.ticket, A_order.size, bid, SLIPPAGE, clrNONE)) {  //TODO: callback for synch close order and creation
	        A_order.ticket = -1;
	        A_accum += (bid - A_order.price)*A_order.size/point;
	        
	        A_createBuy(nextSize);
	    }
    }
}

/**
 * Create BUY
 */
void A_createBuy(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);
    double stoploss = oprice - GRID_Y * point;
	
	//if creating a new level, close previous
	if(A_order.ticket != -1) {
	    double bid = MarketInfo(symbol, MODE_BID);
	    
	    if(OrderClose(A_order.ticket, A_order.size, bid, SLIPPAGE, clrNONE)) {  //TODO: callback for synch close order and creation
	        A_accum += (bid - A_order.price)*A_order.size/point;
	    }
	}
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        A_order.ticket = order;
        A_order.op_type = optype;
        A_order.price = oprice;
        A_order.size = osize;
        A_order.symbol = symbol;
        A_order.sl = stoploss;
    }
}

/********************************************** SIDE B Functions *************************************************************/

/**
 * Try New level
 * when prices has moved a significant amount, 
 * try to increase sell size without affecting possible retrace profit
 */
void B_tryNewLevel() {
    string symbol = Symbol();
    double point = MarketInfo(symbol, MODE_POINT);
    double ask = MarketInfo(symbol, MODE_ASK);
    double bid = MarketInfo(symbol, MODE_BID);
    double spread = MarketInfo(symbol, MODE_SPREAD);
    
    //Determine necessary retrace for sideA break even
    double neededRetrace = spread + MathAbs(A_accum) / A_order.size;
    
    //check if retracement will maintain side B profitable
    double sideBProfit = B_accum + (B_order.price - ask)*B_order.size/point;
    double nextSize = B_order.size + SIZE_STEP;
    if(sideBProfit - (neededRetrace*nextSize) > 0) { //execute next level
        Print("try new B level. neededRetrace: ", neededRetrace, " Bprofits: ", sideBProfit, " nextSize: ", nextSize);
        if(OrderClose(B_order.ticket, B_order.size, ask, SLIPPAGE, clrNONE)) {  //TODO: callback for synch close order and creation
	        B_order.ticket = -1;
	        B_accum += (B_order.price - ask)*B_order.size/point;
	        
	        B_createSell(nextSize);
	    }
    }
}

/**
 * Create SELL
 */
void B_createSell(double osize) {
    string symbol = Symbol();
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);
    double stoploss = oprice + GRID_Y * point;
	
	//if creating a new level, close previous
	if(B_order.ticket != -1) {
	    double ask = MarketInfo(symbol, MODE_ASK);
	    
	    if(OrderClose(B_order.ticket, B_order.size, ask, SLIPPAGE, clrNONE)) {  //TODO: callback for synch close order and creation
	        B_accum += (B_order.price - ask)*B_order.size/point;
	    }
	}
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        B_order.ticket = order;
        B_order.op_type = optype;
        B_order.price = oprice;
        B_order.size = osize;
        B_order.symbol = symbol;
        B_order.sl = stoploss;
    }
}