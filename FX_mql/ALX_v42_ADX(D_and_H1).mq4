//+------------------------------------------------------------------+
//|                                      ALX_v42_ADX(D_and_H1).mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * Price action accumulative EA
 * relies on: 
 *     D1 ADX: +DI must be above -DI
 *     H1 ADX: again +DI must be above -DI
 *     open at each H1 bar.
 *     close in PROFIT when bar closes above 50 pips (minimum day profit)
 *     STOP LOSS, when price goes below H1 ATR(14)
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define DOWN -1
#define NONE 0

#define MIN_DAY_TARGET 50

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    double range;
    int op_type;
    double size;
};
order_t buyOrder;
order_t sellOrder;

datetime lastBarTime;

//Variables to control trades
int d1ADXSide = NONE;
int h1ADXSide = NONE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastBarTime = NULL;
    
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
    //--------------get ADX positions
    double d1ADX_DiPlus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
    double d1ADX_DiMinus = iADX(NULL, PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
    
    if(d1ADX_DiPlus > d1ADX_DiMinus)
        d1ADXSide = UP;
    else if(d1ADX_DiPlus < d1ADX_DiMinus)
        d1ADXSide = DOWN;
    else
        d1ADXSide = NONE;
    
    //----------------check a new H1 Bar
    if(lastBarTime != Time[0]) {
        //--------------------------------check to close previous order
        if(buyOrder.ticket != -1) {
            if(MathAbs(Bid - buyOrder.price) >= MIN_DAY_TARGET*Point)
                closeBuy();
        }
        
        if(sellOrder.ticket != -1) {
            if(MathAbs(sellOrder.price) - Ask >= MIN_DAY_TARGET*Point)
                closeSell();
        }
        
        //--------------------------------possible new trade
        if(d1ADXSide == UP)
            if(buyOrder.ticket == -1)
                createBuy();
        
        if(d1ADXSide == DOWN)
            if(sellOrder.ticket == -1)
                createSell();
        
        lastBarTime = Time[0];
    }
    
    //----------------check in real time SL limit
    if(buyOrder.ticket != -1) {
        //double atr = iATR(NULL, PERIOD_H1, 14, 1);
        
        //if(Bid < buyOrder.price - atr)
            //closeBuy();
            
        if(d1ADXSide == DOWN)  //possible trend reversal
            closeBuy();
    }
    
    if(sellOrder.ticket != -1) {
        //double atr = iATR(NULL, PERIOD_H1, 14, 1);
        
        //if(Ask > sellOrder.price + atr)
            //closeSell();
            
        if(d1ADXSide == UP)  //possible trend reversal
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
    buyOrder.ticket = order;
    buyOrder.size = osize;
}

/**
 * Create a sell order
 */
void createSell() {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	
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