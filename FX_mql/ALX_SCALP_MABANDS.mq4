//+------------------------------------------------------------------+
//|                                           ALX_SCALP_MABANDS.mq4  |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * NonLagMA + Bollinger Bands for filtering
 * scalping
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double BASE_SL = 5;

int stochTrigger = 0;
int upTestTicks = 0;
int downTestTicks = 0;

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    double tp;
    int op_type;
    datetime time;
};

order_t buyOrder;
order_t sellOrder;

/*for execution on each bar*/
datetime lastTime;

int nonlagDirection = 0;
int priceSide = 0;  //position of price with respect to nonlagma

int lockStep;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lockStep = 1;

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
    //*********************read NonLagMA
    //parameters for indicator
    int Price = 0;  //Apply to Price(0-Close;1-Open;2-High;3-Low;4-Median price;5-Typical price;6-Weighted Close)
    int Length = 40;  //Period of NonLagMA
    int Displace = 0;  //DispLace or Shift
    double PctFilter = 0.5;  //Dynamic filter in decimal
    string note1 = "turn on Color = 1; turn off = 0";
    int Color = 1;  //Switch of Color mode (1-color)  
    int ColorBarBack = 1; //Bar back for color mode
    double Deviation = 0; //Up/down deviation        
    string note2 = "turn on Alert = 1; turn off = 0";
    int AlertMode = 0;  //Sound Alert switch (0-off,1-on) 
    string note3 = "turn on Warning = 1; turn off = 0";
    int WarningMode = 0;  //Sound Warning switch(0-off,1-on)
    bool SendAlertEmail = false; 
    
    string name = "NonLagMA_v7.1_EmailAlert_alx";
    double nonlagD = iCustom(NULL, 0, name, Price, Length, Displace, PctFilter, note1,
        Color, ColorBarBack, Deviation, note2, AlertMode, note3, WarningMode, SendAlertEmail, 6, 0);
    double nonlagV = iCustom(NULL, 0, name, Price, Length, Displace, PctFilter, note1,
        Color, ColorBarBack, Deviation, note2, AlertMode, note3, WarningMode, SendAlertEmail, 0, 0);
        
    //nonlag direction
    if(nonlagD != 0) {
        if(nonlagD > 0)
            nonlagDirection = UP;
        else if(nonlagD < 0)    
            nonlagDirection = DOWN;
    }
    
    double stoch = iStochastic(NULL, PERIOD_M1, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 0);
    double prevStoch = iStochastic(NULL, PERIOD_M1, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 1);
    
    if(lastTime != Time[0]) {
        if(prevStoch <= 20) {
            stochTrigger = UP;
            
            if(buyOrder.ticket != -1)
                closeBuy();
            if(sellOrder.ticket != -1)
                closeSell();
        }
        else if(prevStoch >= 80) {
            stochTrigger = DOWN;
            
            if(buyOrder.ticket != -1)
                closeBuy();
            if(sellOrder.ticket != -1)
                closeSell();    
        }
        
        lastTime = Time[0];
    }
    
    //check to enter trades
    if(stoch >= 50) {
        if(stochTrigger == UP) {
            upTestTicks++;
            
            if(upTestTicks >= 3) {
                if(buyOrder.ticket == -1)
                    createBuy();
                upTestTicks = 0;
            }
        }
        
        if(stoch > 50)
            downTestTicks = 0;
    }
    
    if(stoch <= 50) {
        if(stochTrigger == DOWN) {
            if(sellOrder.ticket == -1) {
                downTestTicks++;
                
                if(downTestTicks >= 3) {
                    createSell();
                    downTestTicks = 0;
                }
            }
        }
        
        if(stoch < 50)
            upTestTicks = 0;
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * lock profits progressively
 */
void stepLock(int direc) {
    int s_amount = 5;

    if(direc == UP) {
        if(Bid - buyOrder.price >= lockStep*s_amount*Point) {
            buyOrder.sl = buyOrder.price + lockStep*s_amount*Point;
            lockStep++;
        }
    }
    else if(direc == DOWN){
        if(sellOrder.price - Ask >= lockStep*s_amount*Point) {
            sellOrder.sl = sellOrder.price - lockStep*s_amount*Point;
            lockStep++;
        }
    }
}

/**
 * inside Bollinger Bands
 */
bool insideBands(int direc) {
    if(direc == UP) {
        double upBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
        
        if(Bid <= upBand)
            return TRUE;
    }
    
    return FALSE;
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
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
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
    
    lockStep = 1;
    
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
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
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
    
    lockStep = 1;
    
    //Print("SELL created. Close[1] was: ", Close[1]," Bid: ", sellOrder.price," SL: ", sellOrder.sl);
}

void closeBuy() {
    OrderClose(buyOrder.ticket, R_VOL, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, R_VOL, Ask, 3, Blue);
    sellOrder.ticket = -1;
}