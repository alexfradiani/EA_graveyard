//+------------------------------------------------------------------+
//|                                                   ALX_H_MAs.mq4  |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * 8EMA and 34EMA in H1
 * trigger from crossings and retracements.
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
    double ema8 = iMA(NULL, 0, 8, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ema34 = iMA(NULL, 0, 34, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    //---------------------------------------------------------------conditions for trade
    if(ema8 >= ema34) {
        if(priceSide == DOWN) {
            trendBurned = FALSE;
            timeAnchor = TimeCurrent();
        }
        
        priceSide = UP;
        double elapsed = (TimeCurrent() - timeAnchor) / 60;
        if(elapsed >= 5) {
            if(sellOrder.ticket != -1)
                closeSell();
        
            if(buyOrder.ticket == -1 && trendBurned == FALSE)
                createBuy();
            
            trendBurned = TRUE;
        }
    }
    else {
        if(priceSide == UP) {
            trendBurned = FALSE;
            timeAnchor = TimeCurrent();
        }
        
        priceSide = DOWN;
        double elapsed = (TimeCurrent() - timeAnchor) / 60;
        if(elapsed >= 5) {
            if(buyOrder.ticket != -1)
                closeBuy();
                
            if(sellOrder.ticket == -1 && trendBurned == FALSE)
                createSell();
            
            trendBurned = TRUE;
        }
    }
    
    //---------------------------------------------------------------exit strategy
    if(lastTime != Time[0]) {
        double prev0 = iMA(NULL, 0, 8, 0, MODE_EMA, PRICE_CLOSE, 1);
        double prev1 = iMA(NULL, 0, 8, 0, MODE_EMA, PRICE_CLOSE, 2);
        
        if(buyOrder.ticket != -1) {
            if(prev0 < prev1 && Bid > buyOrder.price)
                closeBuy();
        }
                
        if(sellOrder.ticket != -1) {
            if(prev0 > prev1 && Ask < sellOrder.price)
                closeSell();
        }
        
        lastTime = Time[0];
    }
    
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        else if(Bid - buyOrder.price > 30*Point)  //assure minimum profits
            buyOrder.sl = buyOrder.price + 30*Point;
    }
    if(sellOrder.ticket != -1) {
        if(Ask > sellOrder.sl)
            closeSell();
        else if(sellOrder.price - Ask > 30*Point)  //assure minimum profits
            sellOrder.sl = sellOrder.price - 30*Point;
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
	double stoploss = oprice - BASE_SL*Point;
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
    
    //Print("BUY created. Close[1] was: ", Close[1]," Ask: ", buyOrder.price," SL: ", buyOrder.sl);
}

/**
 * Create a sell order
 */
void createSell() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);

    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = oprice + BASE_SL*Point;
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