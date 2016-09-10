//+------------------------------------------------------------------+
//|                                               ALX_H_MTF_MAs.mq4  |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * MTF. 4 Hour - 1 Hour - 15min
 * 200SMA and 5EMA
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double BASE_SL = 500;

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
datetime timeAnchor;

int priceSide = 0;  //position of price with respect to nonlagma

bool trendBurned = TRUE;

int m15Trend, h1Trend, h4Trend;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    timeAnchor = TimeCurrent();
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    priceSide = NONE;
    
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
    //check mtf movement
    double m15_5ema = iMA(NULL, PERIOD_M15, 5, 0, MODE_EMA, PRICE_CLOSE, 1);
    double h1_5ema = iMA(NULL, PERIOD_H1, 5, 0, MODE_EMA, PRICE_CLOSE, 1);
    double h4_5ema = iMA(NULL, PERIOD_H4, 5, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    double m15_200sma = iMA(NULL, PERIOD_M15, 200, 0, MODE_SMA, PRICE_CLOSE, 1);
    double h1_200sma = iMA(NULL, PERIOD_H1, 200, 0, MODE_SMA, PRICE_CLOSE, 1);
    double h4_200sma = iMA(NULL, PERIOD_H4, 200, 0, MODE_SMA, PRICE_CLOSE, 1);

    if(h1_5ema > h1_200sma)
        h1Trend = UP;
    else
        h1Trend = DOWN;
    if(m15_5ema > m15_200sma)
        m15Trend = UP;
    else
        m15Trend = DOWN;
    if(h4_5ema > h4_200sma)
        h4Trend = UP;
    else
        h4Trend = DOWN;

    if(m15Trend == UP && h1Trend == UP && h4Trend == UP) {
        if(priceSide <= NONE && trendBurned == FALSE) {
            if(buyOrder.ticket != -1)
                closeBuy();
            createBuy();
            
            trendBurned = TRUE;
        }
        priceSide = UP;
    }
    else if(m15Trend == DOWN && h1Trend == DOWN && h4Trend == DOWN) {
        if(priceSide >= NONE && trendBurned == FALSE) {
            if(sellOrder.ticket != -1)
                closeSell();
            createSell();
            
            trendBurned = TRUE;
        }
        priceSide = DOWN;
    }            
    else {
        priceSide = NONE;
        trendBurned = FALSE;
    }
    
    /*if(lastTime != Time[0]) {
        Print("m15_5ema: ", m15_5ema, " m15_200sma: ", m15_200sma);
        Print("m15Trend: ", m15Trend, " h1Trend: ", h1Trend, " h4Trend: ", h4Trend, 
            " trenBurned: ", trendBurned, " priceSide: ", priceSide);
        
        lastTime = Time[0];
    }*/
    
    //---------------------------------------------------------------exit strategy  
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        else if(Bid > buyOrder.tp)  //assure minimum profits
            buyOrder.sl = buyOrder.tp - 10*Point;
    }
    if(sellOrder.ticket != -1) {
        if(Ask > sellOrder.sl)
            closeSell();
        else if(Ask < sellOrder.tp)  //assure minimum profits
            sellOrder.sl = sellOrder.tp + 10*Point;
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
 * Determine STOP LOSS
 */
double setStopLoss(int optype) {
    double peak = 0;

    if(optype == OP_BUY) {
        peak = 9999999;
        for(int i = 0; i < 32; i++) { //find the peak as sl
            if(Low[i] < peak)
                peak = Low[i] - 5*Point;
        }
    }
    else if(optype == OP_SELL) {
        peak = 0;
        for(int i = 0; i < 32; i++) { //find the peak as sl
            if(High[i] > peak)
                peak = High[i] + 5*Point;
        }
    }
    
    return peak;
}

/**
 * Create a buy order
 */
void createBuy() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = setStopLoss(optype);
	double takeprofit = oprice + 2*(oprice - stoploss);
	
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
    buyOrder.tp = takeprofit;
    buyOrder.ticket = order;
    buyOrder.time = lastTime;
    buyOrder.size = osize;
    
    //Print("BUY created. Close[1] was: ", Close[1]," Ask: ", buyOrder.price," SL: ", buyOrder.sl);
}

/**
 * Create a sell order
 */
void createSell() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);

    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = setStopLoss(optype);
	double takeprofit = oprice - 2*(stoploss - oprice);
	
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
    sellOrder.tp = takeprofit;
    sellOrder.ticket = order;
    sellOrder.time = lastTime;
    sellOrder.size = osize;
    
    //Print("SELL created. Close[1] was: ", Close[1]," Bid: ", sellOrder.price," SL: ", sellOrder.sl);
}

void closeBuy() {
    OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3, Blue);
    sellOrder.ticket = -1;
}