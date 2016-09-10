//+------------------------------------------------------------------+
//|                                               RSI_Scalper_v2.mq4 |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * THIS VERSION:
 * - SIMULTANEOUS BUYS OR SELLS CAN BE OPENED, USING ARRAY FOR ORDERS
 * - FOR TRADES OLDER THAN A DAY, IF THE SMA CROSSING INDICATES WRONG DIRECTION, CLOSE THEM..
 */

#property copyright "Alexander Fradiani"
#property version   "2.00"
#property strict

#define RSI_LOW 30
#define RSI_HIGH 70

#define BULLISH 1
#define BEARISH -1

#define CROSS_UP 1
#define CROSS_NONE 0
#define CROSS_DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    int op_type;
};

datetime lastTime;
int crossPosition;
order_t buys[];
order_t sells[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    //set first value of crossPosition.
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 1);
    if(rsi >= RSI_HIGH)
        crossPosition = CROSS_UP;
    else if(rsi <= RSI_LOW)
        crossPosition = CROSS_DOWN;
    else
        crossPosition = CROSS_NONE;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //read current RSI
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 1);
    
    if(rsi >= RSI_HIGH) {  //crossed up
        closeBuys();
        
        crossPosition = CROSS_UP;
    }
    else if(rsi <= RSI_LOW) {  //crossed down
        closeSells();
        
        crossPosition = CROSS_DOWN;
    }
    else {  //non crossing area
        if(crossPosition == CROSS_DOWN) { //coming up from down-crossing, time to buy
            if(typeOfDay() == BULLISH)
                createBuy();
        }
        
        if(crossPosition == CROSS_UP) {  //coming down from up-crossing, time to sell
            if(typeOfDay() == BEARISH)
                createSell();
        }
        
        crossPosition = CROSS_NONE;
    }
    
    //SL checking. trail a stop after moving half the rsi
    if(lastTime != Time[0]) {
        lastTime = Time[0];
        
        double middle_rsi = (RSI_HIGH + RSI_LOW) / 2;
        for(int i = 0; i < ArraySize(buys); i++) {
            if(Open[0] < buys[i].sl && buys[i].sl != 0) {
                OrderClose(buys[i].ticket, R_VOL, Bid, 3, Blue);
                o_array_remove(buys, buys[i].ticket);
                if(i > 0) i--;
            }
            else if(rsi >= middle_rsi && buys[i].sl < Open[0])
                buys[i].sl = Open[0];
        }
        
        for(int i = 0; i < ArraySize(sells); i++) {
            if(Open[0] > sells[i].sl && sells[i].sl != 0) {
                OrderClose(sells[i].ticket, R_VOL, Ask, 3, Blue);
                o_array_remove(sells, sells[i].ticket);
                if(i > 0) i--;
            }
            else if(rsi <= middle_rsi && sells[i].sl < Open[0])
                sells[i].sl = Open[0];
        }
    }
}
//+------------------------------------------------------------------+

/**
 * Identify type of day according to movement of sma5 and sma8
 */
int typeOfDay() {
    //GET the trend from the daily timeframe
    double lastDayClose = iClose(NULL, PERIOD_D1, 1);
    double sma8 = iMA(NULL, PERIOD_D1, 8, 0, MODE_SMA, PRICE_CLOSE, 1);
    double sma5 = iMA(NULL, PERIOD_D1, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    //Print("last day close: ", lastDayClose, " SMA8: ", sma8, " SMA5: ", sma5);
    
    if(sma5 > sma8) {
        return BULLISH;
    }
    else {
        return BEARISH;
    }
}

/**
 * Create a buy order
 */
void createBuy() {
    if(ArraySize(buys) > 0) return; //filter just one trade

    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = setSL(optype);
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    order_t newOrder;
    newOrder.op_type = optype;
    newOrder.price = oprice;
    newOrder.sl = stoploss;
    newOrder.ticket = order;
    o_array_push(buys, newOrder);
}

/**
 * Create a sell order
 */
void createSell() {
    if(ArraySize(sells) > 0) return; //filter just one trade

    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = setSL(optype);
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    order_t newOrder;
    newOrder.op_type = optype;
    newOrder.price = oprice;
    newOrder.sl = stoploss;
    newOrder.ticket = order;
    o_array_push(sells, newOrder);
}

void closeBuys() {
    for(int i = 0; i < ArraySize(buys); i++) {
        OrderClose(buys[i].ticket, R_VOL, Bid, 3, Blue);
        o_array_remove(buys, buys[i].ticket);
        if(i > 0) i--;  
    }
}

void closeSells() {
    for(int i = 0; i < ArraySize(sells); i++) {
        OrderClose(sells[i].ticket, R_VOL, Ask, 3, Blue);
        o_array_remove(sells, sells[i].ticket);
        if(i > 0) i--;  
    }
}

/**
 * SL logic.  TODO..
 */
double setSL(int optype) {
    if(optype == OP_BUY)
        return Open[0] - 31*Point;
    else if(optype == OP_SELL)
        return Open[0] + 31*Point;
    
    return 0;
}

/**
 * insert order to array
 */
void o_array_push(order_t&  array[], order_t& order) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = order;
}

/**
 * remove an order from array and resize
 */
void o_array_remove(order_t& array[], int ticket) {
    int length = ArraySize(array);
    order_t narray[];
    
    ArrayResize(narray, length - 1);
    for(int i = 0, j = 0; i < length; i++) {
    	if(array[i].ticket == ticket)
    		continue;
    	else {
    		narray[j] = array[i];
    		j++;
    	}
    }
    
    ArrayCopy(array, narray);
    ArrayResize(array, length - 1);
}