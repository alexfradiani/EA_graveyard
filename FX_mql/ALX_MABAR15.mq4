//+------------------------------------------------------------------+
//|                                               ALX_MABAR15.mq4    |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * Integrated EA from indicators,
 * (main reference, "money making manual trading system" forex-tsd forums...)
 * - NonLAGMA 
 * - SSL_fast_sbar_mtf
 * - stepStopExpert for takeprofits and stops.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern int GMT_FIX  = 0; //difference for GMT hour comparison

/*variables for step stops*/
extern double InitialStop = 100;
extern double BreakEven = 20;    // Profit Lock in pips  
extern double StepSize = 5;
extern double MinDistance = 10;

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    int op_type;
};

order_t buyOrder;
order_t sellOrder;

/*for execution on each bar*/
datetime lastTime;

int MIN_CONST = 1;

int nonlagDirection = 0;
int memlag = 0;
int sslDirection = 0;
int trading;

bool swBuy;
bool swSell;

/*For step stops*/
bool step_BE;
int step_K;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    swBuy = FALSE;
    swSell = FALSE;
    
    step_BE = FALSE;
    step_K = 0;
    
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
    /*if(Time[0] == lastTime)
        return;
    
    lastTime = Time[0];*/

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
    
    if(nonlag != 0) {
        if(nonlag > 0)
            nonlagDirection = UP;
        else if(nonlag < 0)    
            nonlagDirection = DOWN;
            
        //Print("Nonlag Direction ", nonlagDirection);
    }
    else
        nonlagDirection = NONE;
    
    if(memlag == DOWN && nonlagDirection == UP) {
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
    //} 
    
    memlag = nonlagDirection;
    
    //Print("NonlagUp ", nonlagUp);
    //Print("NonlagDn ", nonlagDn);
   
    if(nonlagDirection == NONE || nonlagDirection == DOWN)
        swBuy = FALSE;
    if(sslDirection == DOWN)
        swBuy = FALSE;
    if(nonlagDirection == NONE || nonlagDirection == UP)
        swSell = FALSE;
    if(sslDirection == UP)
        swSell = FALSE;
    
    //stepStops();
    RefreshRates();
    
    /*if(OrdersTotal() == 0) {
        step_BE = FALSE;
        step_K = 0;
    }*/
}
//+------------------------------------------------------------------+

/**
 * check opened orders, if none, buyOrder and sellOrder must be cleaned
 */
/*void refreshOrders() {
    int totalCurrOrders = OrdersTotal();
    if(totalCurrOrders == 0) {
        buyOrder.ticket = -1;
        sellOrder.ticket = -1;
        
        step_BE = FALSE;
        step_K = 0;
    }
    else {
        bool swBuy = FALSE;
        bool swSell = FALSE;
        for(int i = 0; i < totalCurrOrders; i++) {
            int order = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if(buyOrder.ticket == OrderTicket())
                swBuy = TRUE;
            if(sellOrder.ticket == OrderTicket())
                swSell = TRUE;
        }
        
        if(swBuy == FALSE)
            buyOrder.ticket = -1;
        if(swSell == FALSE)
            sellOrder.ticket = -1;
    }
}*/

/**
 * Create a buy order
 */
void createBuy() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = oprice - 50*Point;
	double takeprofit = oprice + 50*Point;
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
	double stoploss = oprice + 50*Point;
	double takeprofit = oprice - 50*Point;
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

/**
 * SL logic.
 */
double setSL(int optype, double oprice) {
    double sl = 0;
    
    if(optype == OP_BUY) {
        sl = oprice - InitialStop*Point;
        //Print("setting sl. Close[1]: ", Close[1], " 5%: ", WORST_SL, " sl: ", sl);
    }    
    else if(optype == OP_SELL) {
       sl = oprice + InitialStop*Point;
    }
    
    return sl;
}

void closeBuy() {
    OrderClose(buyOrder.ticket, R_VOL, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, R_VOL, Ask, 3, Blue);
    sellOrder.ticket = -1;
}

/**
 * Define stops using steps.
 * FROM: StepStopExpert_v1.1
 */
void stepStops() {
    double buyStop, sellStop;
    int total = OrdersTotal();
    
    int digit = MarketInfo(Symbol(), MODE_DIGITS);
    
    for(int cnt = 0; cnt < total; cnt++) { 
        OrderSelect(cnt, SELECT_BY_POS);
        int mode = OrderType();
        if(OrderSymbol() == Symbol()) { //current symbol
            if(mode == OP_BUY) {
                buyStop = OrderStopLoss();
                if(Bid - OrderOpenPrice() > 0 || OrderStopLoss() == 0) {  //if profit, or no stoploss defined
                    if(Bid - OrderOpenPrice() >= Point*BreakEven && !step_BE) {
                        buyStop = OrderOpenPrice();
                        step_BE = true;
                    }
                    
                    if(OrderStopLoss() == 0) {
                        buyStop = OrderOpenPrice() - InitialStop*Point; 
                        step_K = 1;
                        step_BE = false;
                    }
                    
                    if(Bid - OrderOpenPrice() >= step_K*StepSize*Point) {
                        buyStop = OrderStopLoss() + StepSize*Point;
                        
                        if(Bid - buyStop >= MinDistance*Point) { 
                            buyStop = buyStop; 
                            step_K = step_K + 1;
                        }
                        /*else
                            buyStop = OrderStopLoss();*/
                    }                              
                    //Print( " k=",k ," del=", k*StepSize*Point, " buyStop=", buyStop," digit=", digit);
                    if(buyStop != OrderStopLoss())
                        OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(buyStop, digit), OrderTakeProfit(), 0, LightGreen);
                    
                    return;
                }
		    }
            
            if(mode == OP_SELL) {
                sellStop = OrderStopLoss();
                if(OrderOpenPrice() - Ask > 0 || OrderStopLoss() == 0) {
                    if(OrderOpenPrice() - Ask >= Point*BreakEven && !step_BE) {
                        sellStop = OrderOpenPrice(); 
                        step_BE = true;
                    }
                
                    if(OrderStopLoss() == 0) {
                        sellStop = OrderOpenPrice() + InitialStop*Point;
                        step_K = 1;
                        step_BE = false;
                    }
                    
                    if(OrderOpenPrice() - Ask >= step_K*StepSize*Point) {
                        sellStop = OrderStopLoss() - StepSize*Point; 
                        if(sellStop - Ask >= MinDistance*Point) { 
                            sellStop = sellStop;
                            step_K = step_K + 1;
                        }
                        /*else
                            sellStop = OrderStopLoss();*/
                    }
                    //Print( " k=",k," del=", k*StepSize*Point, " sellStop=",sellStop," digit=", digit);
                    if(sellStop != OrderStopLoss())
                        OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(sellStop, digit), OrderTakeProfit(), 0, Yellow); 
                    
                    return;
                }    
            }
        }   
    } 
}