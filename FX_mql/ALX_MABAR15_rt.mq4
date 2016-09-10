//+------------------------------------------------------------------+
//|                                               ALX_MABAR15_rt.mq4 |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * Integrated EA from indicators,
 * (main reference, "money making manual trading system" forex-tsd forums...)
 * - NonLAGMA 
 * - SSL_fast_sbar_mtf
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern int GMT_FIX  = 0; //difference for GMT hour comparison

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    double tp;
    int op_type;
};

order_t buyOrder;
order_t sellOrder;

/*for execution on each bar*/
datetime lastTime;
datetime directionTime;

int MIN_CONST = 5;  //minutes for constant direction

int nonlagDirection = 0;
int memlag = 0;
int setTrend = 0;
int sslDirection = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    directionTime = TimeCurrent();
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    setTrend = 0;
    
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
    //************************read SSL Bar state
    //parameters for indicator
    int Lb = 10;
    int sslMA_method = 0;
    int SSL_BarLevel = 50; // BarLevel 10-90
    bool alertsOn = false;
    bool alertsMessageBox = false;
    bool alertsSound = false;
    string alertsSoundFile = "TP1M.wav";
    bool alertsEmail = false;
    bool alertsAfterBarClose = false;
    int TimeFrame = 240;
    string TimeFrames = "M1;5,15,30,60H1;240H4;1440D1;10080W1;43200MN|0-CurrentTF";
    string MA_method = "SMA0 EMA1 SMMA2 LWMA3";
    
    string name = "SSL_fast_sBar_alert_mtf";
    double sslval = iCustom(NULL, TimeFrame, name, Lb, sslMA_method, SSL_BarLevel, alertsOn, alertsMessageBox,
        alertsSound, alertsSoundFile, alertsEmail, alertsAfterBarClose, 0, 0);
    
    //measure the value of the high buffer
    if(sslval == EMPTY_VALUE)
        sslDirection = DOWN;
    else
        sslDirection = UP;
        
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
    
    name = "NonLagMA_v7.1_EmailAlert_alx";
    double nonlag = iCustom(NULL, 0, name, Price, Length, Displace, PctFilter, note1,
        Color, ColorBarBack, Deviation, note2, AlertMode, note3, WarningMode, SendAlertEmail, 6, 0);
    double nonlagPrevDirection = iCustom(NULL, 0, name, Price, Length, Displace, PctFilter, note1,
        Color, ColorBarBack, Deviation, note2, AlertMode, note3, WarningMode, SendAlertEmail, 6, 1);
        
    if(nonlag != 0) {
        if(nonlag > 0)
            nonlagDirection = UP;
        else if(nonlag < 0)    
            nonlagDirection = DOWN;
            
        //Print("Nonlag Direction ", nonlagDirection);
    }
    else
        nonlagDirection = NONE;
    
    //first values for trends
    if(setTrend != UP && setTrend != DOWN)
        setTrend = nonlagPrevDirection;
    if(memlag != UP && memlag != DOWN) {
        directionTime = TimeCurrent();
        memlag = nonlagDirection;
    }
  
    //starting a new bar
    if(Time[0] != lastTime) {
        bool enteringBar = FALSE;
        double elapsed = (TimeCurrent() - directionTime)/60;
    
        Print("setTrend: ", setTrend, " memlag: ", memlag, " at time:", elapsed);
        directionTime = TimeCurrent();
        //LOG all vars
        
        if(nonlagPrevDirection != setTrend) {
            int currHour = Hour() - GMT_FIX;
            if(currHour >= 6 && currHour <= 21) {
                //if(elapsed >= MIN_CONST) {
                    if(memlag == UP)
                        createBuy();
                    else if(memlag == DOWN)
                        createSell();
                //}
            }    
        
            setTrend = nonlagPrevDirection;
        }
    }
        
    //change in direction
    if( (memlag == DOWN && nonlagDirection == UP) || (memlag == UP && nonlagDirection == DOWN) ) { 
        directionTime = TimeCurrent();
        memlag = nonlagDirection;
    }
    
    /*if(memlag == DOWN && nonlagDirection == UP) {
        //Print("Nonlag value: from DOWN to UP, SSL is:", sslDirection);
        lastTime = TimeCurrent();
        trading = 0;
    }
    if(memlag == UP && nonlagDirection == DOWN) {
        //Print("Nonlag value: from UP to DOWN, SSL is:", sslDirection);
        lastTime = TimeCurrent();
        trading = 0;
    }
    
    //if((TimeCurrent() - lastTime)/60 >= MIN_CONST && !trading) { //min time
        int currHour = Hour() - GMT_FIX;
        if(currHour >= 6 && currHour <= 21) {
  
            if(memlag == UP && sslDirection == UP && OrdersTotal() == 0) {
                //createSell();
                //createBuy();
                //Print("Play hours. nonlag direction constant for min time. Price: ", Bid);
                trading = 1;
            }
            else if(memlag == DOWN && sslDirection == DOWN && OrdersTotal() == 0) {
                //createBuy();
                //createSell();
                //Print("Play hours. nonlag direction constant for min time. Price: ", Bid);
                trading = 1;
            }
        }
    //} */
    
    lastTime = Time[0]; 
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
	double stoploss = oprice - 100*Point;
	double takeprofit = oprice + 100*Point;
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		NormalizeDouble(stoploss, digit), //Stop loss
		NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    /*buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.ticket = order;*/
    
    //Print("BUY created. Close[1] was: ", Close[1]," Ask: ", buyOrder.price," SL: ", buyOrder.sl);
}

/**
 * Create a sell order
 */
void createSell() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);

    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = oprice + 100*Point;
	double takeprofit = oprice - 100*Point;
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		NormalizeDouble(stoploss, digit), //Stop loss
		NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    /*sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
    sellOrder.ticket = order;*/
    
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