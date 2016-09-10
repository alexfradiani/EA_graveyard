//+------------------------------------------------------------------+
//|                                     ALX_M1_H1_MultiScalp.mq4     |
//|                                             Alexander Fradiani   |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * M1 and H1 interaction
 * Moving averages
 *                 10SMA H1 -> 600 SMA M1
 *                 RSI M1 scalping
 *                 Bollinger bands scalping
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades
#define BASE_PIPS  10

int localSide = NONE;  //position of price with respect to SMA
int rsiSide = NONE;

bool blockedRSI_buy;
bool blockedRSI_sell;

int workingDay;   //day of current operation

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
    
    blockedRSI_buy = FALSE;
    blockedRSI_sell = FALSE;
    
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
    double ma600 = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 0);
    double rsi = iRSI(NULL, PERIOD_M1, 8, PRICE_CLOSE, 0);
    double rsiOld = iRSI(NULL, PERIOD_M1, 8, PRICE_CLOSE, 1);
    
    if(lastTime != Time[0]) {    
        if(Open[0] < ma600)
            localSide = DOWN;
        else if(Open[0] > ma600)
            localSide = UP;
        else
            localSide = NONE;
            
        if(rsiOld > 70) {
            blockedRSI_buy = FALSE;
            rsiSide = UP;
        }
        else if(rsiOld < 30) {
            blockedRSI_sell = FALSE;
            rsiSide = DOWN;  
        }
        else
            rsiSide = NONE;
            
        lastTime = Time[0];
    }
    
    //--------------------------------------------------------------------  Trade Rules
    if(localSide == UP && rsiSide == DOWN && rsi > 30)
        if(buyOrder.ticket == -1 && blockedRSI_buy == FALSE)
            createBuy();
    
    if(localSide == DOWN && rsiSide == UP && rsi < 70)
        if(sellOrder.ticket == -1 && blockedRSI_sell == FALSE)
            createSell();
    
    //--------------------------------------------------------------------Exit rules
    if(buyOrder.ticket != -1) {
        double diff = Bid - buyOrder.price - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(rsiSide == UP && rsi < 70 && diff > 0) {
            closeBuy();
            blockedRSI_buy = TRUE;
        }
        
        if(Bid < buyOrder.sl) {
            closeBuy();
            blockedRSI_buy = TRUE;
        }
        else if(diff >= 10*Point)
            buyOrder.sl = buyOrder.price + 10*Point+ MarketInfo(Symbol(), MODE_SPREAD)*Point;
    }
    
    if(sellOrder.ticket != -1) {
        double diff = sellOrder.price - Ask - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(rsiSide == DOWN && rsi > 30 && diff > 0) {
            closeSell();
            blockedRSI_sell = TRUE;
        }
        
        if(Ask > sellOrder.sl) {
            closeSell();
            blockedRSI_sell = TRUE;    
        }
        else if(diff >= 10*Point)
            sellOrder.sl = sellOrder.price - 10*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point;
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Create a buy order
 */
void createBuy() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS); 
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - (BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point);

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
	double stoploss = oprice + (BASE_PIPS*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point);
	
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