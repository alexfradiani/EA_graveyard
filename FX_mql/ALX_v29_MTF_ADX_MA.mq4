//+------------------------------------------------------------------+
//|                                         ALX_v29_MTF_ADX_MA.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * configuration for trend market state
 * RULES:
 *    - execute and stop orders according to daily adx trend indicator.
 *    - MA's crossings serve as triggers
 * EXIT:
 *    - MA cross in profit
 *    - stop signal from global adx.
 *    - risk STOP LOSS is touched.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define DI_MIN_DISTANCE 5.0

#define UP 1
#define DOWN -1
#define NONE 0

#define BASE_PIPS 3000

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
};
order_t buyOrder;
order_t sellOrder;

datetime lastBarTime;
int trendState = 0;
int maSide = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastBarTime = Time[0];

    //Define initial states
    double adxMinus = iADX(NULL, PERIOD_D1, 14, PRICE_OPEN, MODE_MINUSDI, 0);
    double adxPlus = iADX(NULL, PERIOD_D1, 14, PRICE_OPEN, MODE_PLUSDI, 0);
    
    if(MathAbs(adxMinus - adxPlus) < DI_MIN_DISTANCE)
        trendState = NONE;
    else {
        if(adxPlus > adxMinus)
            trendState = UP;
        else
            trendState = DOWN;            
    }
    
    double ema3 = iMA(NULL, PERIOD_M1, 3, 0, MODE_EMA, PRICE_MEDIAN, 1);
    double ema27 = iMA(NULL, PERIOD_M1, 27, 0, MODE_EMA, PRICE_MEDIAN, 1);
    
    if(ema3 >= ema27)
        maSide = UP;
    else
        maSide = DOWN;
    
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
    double adxMain = iADX(NULL, PERIOD_D1, 14, PRICE_OPEN, MODE_MAIN, 0);
    double adxMinus = iADX(NULL, PERIOD_D1, 14, PRICE_OPEN, MODE_MINUSDI, 0);
    double adxPlus = iADX(NULL, PERIOD_D1, 14, PRICE_OPEN, MODE_PLUSDI, 0);
    
    if(adxMain > 25) {
        if(MathAbs(adxMinus - adxPlus) < DI_MIN_DISTANCE && trendState != NONE) {
            trendState = NONE;
            Print("trendState NONE");
        }
        else if(MathAbs(adxMinus - adxPlus) >= DI_MIN_DISTANCE && trendState == NONE) {
            if(adxPlus > adxMinus) {
                trendState = UP;
                createBuy();
                Print("trendState UP");
            }
            else {
                trendState = DOWN;
                createSell();
                Print("trendState DOWN");
            }
        }
    }
    else
        trendState = NONE;
    
    double ema3 = iMA(NULL, PERIOD_M1, 3, 0, MODE_EMA, PRICE_MEDIAN, 1);
    double ema27 = iMA(NULL, PERIOD_M1, 27, 0, MODE_EMA, PRICE_MEDIAN, 1);
    if(lastBarTime != Time[0]) {    
        if(ema3 > ema27 && maSide == DOWN) {
            if(trendState == UP)
                if(buyOrder.ticket == -1)
                    createBuy();
                
            maSide = UP;
        }
        
        if(ema3 < ema27 && maSide == UP) {
            if(trendState == DOWN)
                if(sellOrder.ticket == -1)
                    createSell();
            
            maSide = DOWN;
        }
        
        lastBarTime = Time[0];
    }
    
    //--------------------------------------------------------------------------------------EXIT RULES
    if(buyOrder.ticket != -1) {
        if(ema3 < ema27 && Bid - buyOrder.price > 100*Point)  //close in profit
            closeBuy();
        else if(Bid < buyOrder.sl)  //RISK SL
            closeBuy();
        else if(trendState < UP)
            closeBuy();
    }
    if(sellOrder.ticket != -1) {
        if(ema3 > ema27 && sellOrder.price - Ask > 100*Point) //close in profit
            closeSell();
        else if(Ask > sellOrder.sl)  //RISK SL
            closeSell();
        else if(trendState > DOWN)
            closeSell();
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 
 
/**
 * Create a buy order
 */
void createBuy() {
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
    buyOrder.size = osize;
}

/**
 * Create a sell order
 */
void createSell() {
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
    sellOrder.size = osize;
}

void closeBuy() {
    bool close = OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3, Blue);
    if(close == TRUE)
        buyOrder.ticket = -1;
}

void closeSell() {
    bool close = OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3, Blue);
    if(close == TRUE)
        sellOrder.ticket = -1;
}