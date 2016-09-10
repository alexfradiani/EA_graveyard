//+------------------------------------------------------------------+
//|                                                 ALX_RSI_m1.mq4   |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * Purpose of this EA is to serve as template for M1 RSI scalping
 * with enough filters (MAs, and any other indicators...)
 * to make 1:1 risk ratio profitable in long term
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double BASE_PIPS = 10;

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

/*trigger for RSI extremes*/
int rsiExtreme = 0;

double stochs = 50;
datetime timeAnchor;
bool triggerClose = FALSE;
bool triggerBurned = FALSE;
bool wentOut = TRUE;
datetime lastTriggerTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    
    lastTriggerTime = Time[0];
    
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
    double rsi = iRSI(NULL, PERIOD_M1, 8, PRICE_CLOSE, 1);
    if(lastTime != Time[0]) {
        if(rsi <= 20 || rsi >= 80) {
            if(Time[1] != lastTriggerTime && wentOut == TRUE) {
                triggerBurned = FALSE;
                wentOut = FALSE;
                lastTriggerTime = Time[1];
            }
        }
        
        if(rsi <= 20) {
            rsiExtreme = DOWN;
        }
        else if(rsi >= 80) {            
            rsiExtreme = UP;
        }
        else
            wentOut = TRUE;
            
        double rsi_rt = iRSI(NULL, PERIOD_M1, 8, PRICE_CLOSE, 0);
        if(rsiExtreme == DOWN && rsi_rt > 20) {
            double ns = iStochastic(NULL, PERIOD_M1, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 0);
            if(ns >= 20) {
                if(stochs < 20) {
                    timeAnchor = TimeCurrent();
                }
                
                double elapsed = (TimeCurrent() - timeAnchor);
                if(elapsed >= 0 && buyOrder.ticket == -1 && triggerBurned == FALSE) {
                    //if(Close[1] >= Open[1]) { //previous bar up
                        Print("buy- rsi: ", rsi, " rsi_rt: ", rsi_rt, " ns: ", ns, " stochs: ", stochs);
                        createBuy();
                        triggerBurned = TRUE;
                   // }
                }
            }
            
            stochs = ns;
        }
    }
    
    //exit rules
    if(buyOrder.ticket != -1) {
        if(Bid < buyOrder.sl)
            closeBuy();
        else if(Bid - buyOrder.price > BASE_PIPS*Point)  //assure minimum profits
            buyOrder.sl = buyOrder.price + BASE_PIPS*Point;
            
        double ns = iStochastic(NULL, PERIOD_M1, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 0);
        if(ns >= 80)
            triggerClose = TRUE;
        else if(triggerClose == TRUE)
            closeBuy();
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
    
    triggerClose = FALSE;
}

/**
 * Create a sell order
 */
/*void createSell() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);

    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	
	//OJOOOOOOOOOOOOO
	
	double stoploss = oprice + BASE_PIPS*Point;
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
}*/

void closeBuy() {
    OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3, Blue);
    sellOrder.ticket = -1;
}