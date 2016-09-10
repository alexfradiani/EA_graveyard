//+------------------------------------------------------------------+
//|                                                ALX_m1_3MAs.mq4   |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * scalping with M1 and 3 MAs correlation
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades
extern double BASE_PIPS = 1000; //limit for SL

/*data for orders*/
struct order_t {
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

/*for execution on each bar*/
datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
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
    double ma10 = iMA(NULL, PERIOD_M1, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma20 = iMA(NULL, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma30 = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    double ema = iMA(NULL, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE, 0);
    double prevEma = iMA(NULL, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    if(lastTime != Time[0]) {
        if(Ask >= ma10)
            if(ma10 > ma20 && ma20 > ma30) {
                if(ema > prevEma && MathAbs(Ask - ema) <= 10*Point)    
                    if(ma10 - ma20 > 10*Point && ma20 - ma30 > 5*Point)
                        if(buyOrder.ticket == -1)
                            createBuy();
            }
        
        if(Bid <= ma10)
            if(ma10 < ma20 && ma20 < ma30) {
                if(ema < prevEma && MathAbs(Bid - ema) <= 10*Point)
                    if(ma20 - ma10 > 10*Point && ma30 - ma20 > 5*Point)
                        if(sellOrder.ticket == -1)
                            createSell();
            }
            
        lastTime = Time[0];
    }
    
    //----------------------------------------------------------------------------------Exit rules
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        else if(buyOrder.price - Bid > 50*Point)
            closeBuy();
        else if(ema < ma30)
            closeBuy();
        else if(Bid - buyOrder.price > 50*Point)
            buyOrder.sl = buyOrder.price + 50*Point;
    }
    
    if(sellOrder.ticket != -1) {
        if(Ask > sellOrder.sl)
            closeSell();
        else if(Ask - sellOrder.price > 50*Point)
            closeSell();
        else if (ema > ma30)
            closeSell();
        else if(sellOrder.price - Ask > 50*Point)
            sellOrder.sl = sellOrder.price - 50*Point;
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Determine size of lots based on acc money available
 */
double setLotSize() {
    double fm = AccountFreeMargin();
    double inc = fm - 1000;
    
    double x_lot;
    if(inc >= 0)
        x_lot = NormalizeDouble(inc/100, 0);
    else
        x_lot = 0;
    
    return 0.1 + 0.01*x_lot;
}

/**
 * Create a buy order
 */
void createBuy() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS); 
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - (BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point);
	//double takeprofit = oprice + 100*Point;
	
	double osize = setLotSize();
	
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
	double stoploss = oprice + (BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point);
	//double takeprofit = oprice - 100*Point;
	
	double osize = setLotSize();
	
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