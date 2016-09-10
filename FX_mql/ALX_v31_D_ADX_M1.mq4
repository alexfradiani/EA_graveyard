//+------------------------------------------------------------------+
//|                                           ALX_v31_D_ADX_M1.mq4   |
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

#define BAND_TRIGGER 35
#define LOW_BAND_TRIGGER 10

#define UP 1
#define DOWN -1
#define NONE 0

#define BASE_PIPS 50

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
bool sellEnabled = TRUE;
bool buyEnabled = TRUE;

double lastCrossPrice;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastBarTime = Time[0];
    lastCrossPrice = Bid;
    
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
    //double adxMain = iADX(NULL, PERIOD_D1, 14, PRICE_OPEN, MODE_MAIN, 1);
    double adxMinus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
    double adxPlus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
    double diff = MathAbs(adxMinus - adxPlus);
    
    double adxMinusOld = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
    double adxPlusOld = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
    double diffOld = MathAbs(adxMinusOld - adxPlusOld);
    
    if(Time[0] != lastBarTime) {
        if(diff >= diffOld) {
            if(adxPlus > adxMinus)
                trendState = UP;
            else
                trendState = DOWN;
        }
        else if(diff < diffOld) {
            if(adxPlus > adxMinus)
                trendState = DOWN;
            else
                trendState = UP;
        }
        
        double adxP = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
        double adxM = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
        double adxPOld = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_PLUSDI, 2);
        double adxMOld = iADX(NULL, PERIOD_M1, 14, PRICE_CLOSE, MODE_MINUSDI, 2);
        if(trendState == DOWN) {
            if(adxPOld > adxMOld && adxP < adxM) {
                if(Ask < lastCrossPrice && sellOrder.ticket == -1) {
                    createSell();
                    sellEnabled = FALSE;
                }
                
                lastCrossPrice = Ask;
            }
        }
        else {
            if(adxPOld < adxMOld && adxP > adxM) {
                if(Bid > lastCrossPrice && buyOrder.ticket == -1) {
                    createBuy();
                    buyEnabled = FALSE;
                }
                
                lastCrossPrice = Bid;
            }
        }
        
        lastBarTime = Time[0];  
    }
    
    //------------------------------------------------------------------------- EXIT rules
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        else if(Bid - buyOrder.price > BASE_PIPS*Point) {
            double times = floor( (Bid - buyOrder.price)/(BASE_PIPS*Point) );
            buyOrder.sl = buyOrder.price + times*BASE_PIPS*Point;
        }
    }
    
    if(sellOrder.ticket != -1) {
        if(Ask > sellOrder.sl)
            closeSell();
        else if(sellOrder.price - Ask > BASE_PIPS*Point) {
            double times = floor( (sellOrder.price - Ask)/(BASE_PIPS*Point) );
            sellOrder.sl = sellOrder.price - times*BASE_PIPS*Point;
        }
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