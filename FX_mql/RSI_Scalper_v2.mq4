//+------------------------------------------------------------------+
//|                                               RSI_Scalper_v2.mq4 |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+
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

int crossPosition;
order_t buyOrder;
order_t sellOrder;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
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
        if(buyOrder.ticket != -1) {  //close active buy
            OrderClose(buyOrder.ticket, R_VOL, Bid, 3, Blue);
            buyOrder.ticket = -1;
        }
        
        crossPosition = CROSS_UP;
    }
    else if(rsi <= RSI_LOW) {  //crossed down
        if(sellOrder.ticket != -1) {
            OrderClose(sellOrder.ticket, R_VOL, Ask, 3, Blue);
            sellOrder.ticket = -1;
        }
        
        crossPosition = CROSS_DOWN;
    }
    else {  //non crossing area
        if(crossPosition == CROSS_DOWN) { //coming up from down-crossing, time to buy
            if(typeOfDay() == BULLISH && buyOrder.ticket == -1)
                createBuy();
        }
        
        if(crossPosition == CROSS_UP) {  //coming down from up-crossing, time to sell
            if(typeOfDay() == BEARISH && sellOrder.ticket == -1)
                createSell();
        }
        
        crossPosition = CROSS_NONE;
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
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = setSL(optype);
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		stoploss, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.ticket = order;
}

/**
 * Create a sell order
 */
void createSell() {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = setSL(optype);
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		stoploss, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
    sellOrder.ticket = order;
}

/**
 * SL logic.  TODO..
 */
double setSL(int optype) {
   
    return 0;
}