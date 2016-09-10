//+------------------------------------------------------------------+
//|                                       Alx_MarketDyn_trends.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+
/**
 * configuration for trend market state
 * RULES:
 *    - if HOUR ADX >= 25 AND is moving up
 *    - direction determined by DI with more movement (depending on relation between +DI and -DI)
 *     confirmation in M1 crossing of (9)EMA and (81)EMA in right direction. 
 * EXIT:
 *    - crossing of (9)EMA and (81)EMA in opposite direction (OR)
 *    risk STOP LOSS is touched.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

#define STATE_TREND 1
#define STATE_CHOPPY 0

#define BASE_PIPS 500

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

datetime lastTime;  //for execution on each bar

int marketState;
int marketDirection;

struct order_t {     //DATA for orders
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
 
    setState();
 
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
    bool newBar = FALSE;
    if(lastTime != Time[0]) {
        setState();
        
        lastTime = Time[0];
        newBar = TRUE;
    }
    
    if(marketState == STATE_TREND)
        parseStrategy();
    
    checkOpenTrades(newBar);
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 

/**
 * Determine state of the market
 */
void setState() {
    double adx_0 = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 1);
    double diPlus_0 = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
    double diMinus_0 = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
    
    double adx_1 = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 2);
    double diPlus_1 = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_PLUSDI, 2);
    double diMinus_1 = iADX(Symbol(), PERIOD_H1, 14, PRICE_CLOSE, MODE_MINUSDI, 2);
    
    double adxMov = adx_0 - adx_1;
    double diPlusMov = diPlus_0 - diPlus_1;
    double diMinusMov = diMinus_0 - diMinus_1;
    
    if(adx_0 >= 25 && adx_0 - adx_1 >= 0) {
        marketState = STATE_TREND;
        //determine trend direction
        if((diPlusMov > 0 && diMinusMov > 0) || (diPlusMov < 0 && diMinusMov < 0)) {  //same direction
            if(diPlusMov > diMinusMov)
                marketDirection = UP;
            else if(diPlusMov < diMinusMov)
                marketDirection = DOWN;
            else {
                if(diMinus_0 > diPlus_0)
                    marketDirection = DOWN;
                else
                    marketDirection = UP;
            }   
        }
        if((diPlusMov >= 0 && diMinusMov < 0) || (diPlusMov > 0 && diMinusMov <= 0)) {  // different direction
            marketDirection = UP;
        }
        if((diPlusMov <= 0 && diMinusMov > 0) || (diPlusMov < 0 && diMinusMov >= 0)) {  // different direction
            marketDirection = DOWN;
        }
        if(diPlusMov == 0 && diMinusMov == 0) {
            if(diMinus_0 > diPlus_0)
                marketDirection = DOWN;
            else
                marketDirection = UP;
        }
    }
    else
        marketState = STATE_CHOPPY;
}
 
/**
 * Render conditions for trades.
 */
void parseStrategy() {
    double ema9_0 = iMA(NULL, 0, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
    double ema81_0 = iMA(NULL, 0, 81, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    double ema9_1 = iMA(NULL, 0, 9, 0, MODE_EMA, PRICE_CLOSE, 2);
    double ema81_1 = iMA(NULL, 0, 81, 0, MODE_EMA, PRICE_CLOSE, 2);
    
    if(marketDirection == UP) {
        if(ema9_1 <= ema81_1 && ema9_0 > ema81_0)
            if(buyOrder.ticket == -1)
                createBuy();
    }
    
    if(marketDirection == DOWN) {
        if(ema9_1 >= ema81_1 && ema9_0 < ema81_0)
            if(sellOrder.ticket == -1)
                createSell();
    }
}

/**
 * Evaluate opened trades for possible close
 */
void checkOpenTrades(bool newBar) {
    double ema9_0 = iMA(NULL, 0, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
    double ema81_0 = iMA(NULL, 0, 81, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    double ema9_1 = iMA(NULL, 0, 9, 0, MODE_EMA, PRICE_CLOSE, 2);
    double ema81_1 = iMA(NULL, 0, 81, 0, MODE_EMA, PRICE_CLOSE, 2);
    
    if(buyOrder.ticket != -1) {
        if(Bid <= buyOrder.sl) {
            closeBuy();
        }
        
        if(newBar == TRUE) {
             if(ema9_1 >= ema81_1 && ema9_0 < ema81_0)
                closeBuy();
        }    
    }
    if(sellOrder.ticket != -1) {
        if(Ask >= sellOrder.sl) {
            closeSell();
        }
        
        if(newBar == TRUE) {
             if(ema9_1 <= ema81_1 && ema9_0 > ema81_0)
                closeSell();
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