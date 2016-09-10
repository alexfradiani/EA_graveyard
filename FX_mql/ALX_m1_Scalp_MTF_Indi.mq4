//+------------------------------------------------------------------+
//|                                      ALX_m1_Scalp_MTF_Indi.mq4   |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * scalping with M1 correlation with H1
 * using 5EMAs - 34EMAs
 * in indicator ALX_mtf_ma
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

int triggerSignal = NONE;
int priceSide = NONE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    triggerSignal = NONE;
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
    if(lastTime != Time[0]) {
        if(buyOrder.ticket != -1)
            closeBuy();
        if(sellOrder.ticket != -1)
            closeSell();
        
        double ma1800 = iMA(NULL, PERIOD_M1, 1800, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma1800_old = iMA(NULL, PERIOD_M1, 1800, 0, MODE_SMA, PRICE_CLOSE, 1);
        
        double ma600 = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma600_old = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 1);
    
        double ma30 = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma30_old = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 1);
        
        double ma20 = iMA(NULL, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma20_old = iMA(NULL, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE, 1);
        
        double ma10 = iMA(NULL, PERIOD_M1, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma10_old = iMA(NULL, PERIOD_M1, 10, 0, MODE_SMA, PRICE_CLOSE, 1);
        
        //if(ma1800_old < ma1800)
            //if(ma600_old < ma600)
                if(ma30_old < ma30)
                    if(ma20_old < ma20)
                        if(ma10_old < ma10)
                            if(Open[0] >= ma10)
                                if(buyOrder.ticket == -1) {
                                    createBuy();
                                }
            
        //if(ma1800_old > ma1800)
            //if(ma600_old > ma600)
                if(ma30_old > ma30)
                    if(ma20_old > ma20)
                        if(ma10_old > ma10)
                            if(Open[0] <= ma10)
                                if(sellOrder.ticket == -1) {
                                    createSell();
                                }
        
        lastTime = Time[0];
    }
    
    //----------------------------------------------------------------------------------Exit rules
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        else {
            //
        }
    }
    
    if(sellOrder.ticket != -1) {
        if(Ask > sellOrder.sl)
            closeSell();
        else {
            //
        }
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
	//double stoploss = oprice - (BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point);
	//double takeprofit = oprice + 100*Point;
	double stoploss = oprice - 10*Point;
	double takeprofit = oprice + 10*Point;
	
	double osize = R_VOL; //setLotSize();
	
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
}

/**
 * Create a sell order
 */
void createSell() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	//double stoploss = oprice + (BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point);
	//double takeprofit = oprice - 100*Point;
	double stoploss = oprice + 10*Point;
	double takeprofit = oprice - 10*Point;
	
	double osize = R_VOL; //setLotSize();
	//double osize = setLotSize();
	
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
}

void closeBuy() {
    OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3, Blue);
    sellOrder.ticket = -1;
}