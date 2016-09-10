//+------------------------------------------------------------------+
//|                                     ALX_M1_H1_RSI_RScalp.mq4     |
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
#define BASE_PIPS  8

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

order_t buyOrder, bollBuyOrder;
order_t sellOrder, bollSellOrder;

/*for execution on each bar*/
datetime lastTime;

/*Bollinger variables*/
datetime lastBollTime;
bool blockedBoll_sell;
bool blockedBoll_buy;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    lastBollTime = Time[0];
    
    blockedRSI_buy = FALSE;
    blockedRSI_sell = FALSE;
    
    blockedBoll_buy = FALSE;
    blockedBoll_sell = FALSE;
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    bollBuyOrder.ticket = -1;
    bollSellOrder.ticket = -1;
    
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
            createBuy(buyOrder);
    
    if(localSide == DOWN && rsiSide == UP && rsi < 70)
        if(sellOrder.ticket == -1 && blockedRSI_sell == FALSE)
            createSell(sellOrder);
    
    //--------------------------------------------------------------------Exit rules
    if(buyOrder.ticket != -1) {
        double diff = Bid - buyOrder.price - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(rsiSide == UP && rsi < 70 && diff > 0) {
            closeBuy(buyOrder);
            blockedRSI_buy = TRUE;
        }
        
        if(Bid < buyOrder.sl) {
            closeBuy(buyOrder);
            blockedRSI_buy = TRUE;
        }
        else if(diff >= 10*Point)
            buyOrder.sl = buyOrder.price + 10*Point+ MarketInfo(Symbol(), MODE_SPREAD)*Point;
    }
    
    if(sellOrder.ticket != -1) {
        double diff = sellOrder.price - Ask - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(rsiSide == DOWN && rsi > 30 && diff > 0) {
            closeSell(sellOrder);
            blockedRSI_sell = TRUE;
        }
        
        if(Ask > sellOrder.sl) {
            closeSell(sellOrder);
            blockedRSI_sell = TRUE;    
        }
        else if(diff >= 10*Point)
            sellOrder.sl = sellOrder.price - 10*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point;
    }
    
    parseBollingers();
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * control trades based on bollinger bands
 */
void parseBollingers() {
    double downBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 1);
    double upBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 1);
    double middleBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
    
    if(Close[1] - upBand >= -5*Point) {
        blockedBoll_buy = FALSE;
    }
    else if(downBand - Close[1] >= -5*Point) {
        blockedBoll_sell = FALSE;
    }
    
    if(lastBollTime != Time[0]) {
        if(localSide == UP) {
            if(downBand - Close[1] >= 0) {
                blockedBoll_sell = FALSE;
                
                if(bollBuyOrder.ticket == -1 && blockedBoll_buy == FALSE) {
                    createBuy(bollBuyOrder);
                }
            }    
        }
        else if(localSide == DOWN) {
            if(Close[1] - upBand >= 0) {
                blockedBoll_buy = FALSE;
                
                if(bollSellOrder.ticket == -1 && blockedBoll_sell == FALSE)
                    createSell(bollSellOrder);
            }
        }
        
        lastBollTime = Time[0];
    }
    
    //------------------------------------------------------------------------------EXIT rules for bollinger trades
    if(bollBuyOrder.ticket != -1) {
        double diff = Bid - bollBuyOrder.price - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(Bid >= upBand) {
            closeBuy(bollBuyOrder);
        }
        
        if(Bid < bollBuyOrder.sl) {
            closeBuy(bollBuyOrder);
            blockedBoll_buy = TRUE;
        }
        else if(diff >= 10*Point)
            bollBuyOrder.sl = bollBuyOrder.price + 10*Point + MarketInfo(Symbol(), MODE_SPREAD)*Point;
    }
    
    if(bollSellOrder.ticket != -1) {
        double diff = bollSellOrder.price - Ask - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(Ask <= downBand) {
            closeSell(bollSellOrder);
        }
        
        if(Ask > bollSellOrder.sl) {
            closeSell(bollSellOrder);
            blockedBoll_sell = TRUE;
        }
        else if(diff >= 10*Point)
            bollSellOrder.sl = bollSellOrder.price - 10*Point - MarketInfo(Symbol(), MODE_SPREAD)*Point;
    }
} 
 
/**
 * Create a buy order
 */
void createBuy(order_t &b) {
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
    b.op_type = optype;
    b.price = oprice;
    b.sl = stoploss;
    b.ticket = order;
    b.time = lastTime;
    b.size = osize;
}

/**
 * Create a sell order
 */
void createSell(order_t &s) {
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
    s.op_type = optype;
    s.price = oprice;
    s.sl = stoploss;
    s.ticket = order;
    s.time = lastTime;
    s.size = osize;
}

void closeBuy(order_t &b) {
    OrderClose(b.ticket, b.size, Bid, 3, Blue);
    b.ticket = -1;
}

void closeSell(order_t &s) {
    OrderClose(s.ticket, s.size, Ask, 3, Blue);
    s.ticket = -1;
}