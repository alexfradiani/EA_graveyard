//+------------------------------------------------------------------+
//|                                               RSI_BLG_ADX.mq4    |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * RSI + BOLLINGER BANDS + ADX scalping:
 * - ADX Above 20. crossing of +DI/-DI lines.
 * - RSI in right side >= 50 or <= 50
 * - Price in correct side of Bollinger Bands
 *
 * - trail SL when RSI changes side and when reaches high/low
 * - Minimum 1:1 risk reward!!
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define BULLISH 1
#define BEARISH -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double FIVE_PERCENT = 500;

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    int op_type;
    bool trailed;
};

order_t buyOrder;
order_t sellOrder;
datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    
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
    /*if(lastTime != Time[0]) {
        lastTime = Time[0];*/
        //ADX read
        double adx_PlusDi = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
        double adx_PrevPlusDi = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
        double adx_MinusDi = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
        double adx_PrevMinusDi = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
        
        if(adx_PrevPlusDi < adx_PrevMinusDi && adx_PlusDi > adx_MinusDi) { //crossing up
            //Print("ADX crossing up at ", Time[0]);
            
            double adx_strength = iADX(NULL, 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
            if(adx_strength >= 20) { //adx with strength
                //Print("ADX main line: ", adx_strength);
                
                //read current RSI
                double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
                if(rsi <= 50) { //oversold condition
                    //Print("RSI at: ", rsi);
                    
                    //read Bollinger Bands
                    double middleBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
                    Print("Bollinger in: ", middleBand);
                    if(Open[0] <= middleBand) {
                        Print("Long entry here!! (type of day: ", typeOfDay(), ")");
                    }
                }
            }
        }
    /*}*/
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
		0, //NormalizeDouble(stoploss, Digits), //Stop loss
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
		0, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
    sellOrder.ticket = order;
}

void closeBuy() {
    OrderClose(buyOrder.ticket, R_VOL, Bid, 3, Blue);
    buyOrder.ticket = -1;
    buyOrder.trailed = FALSE;
}

void closeSell() {
    OrderClose(sellOrder.ticket, R_VOL, Ask, 3, Blue);
    sellOrder.ticket = -1;
    sellOrder.trailed = FALSE;
}

/**
 * SL logic.
 */
double setSL(int optype) {
    if(optype == OP_BUY)
        return Bid - FIVE_PERCENT*Point;
    else if(optype == OP_SELL)
        return Ask + FIVE_PERCENT*Point;
    
    return 0;
}