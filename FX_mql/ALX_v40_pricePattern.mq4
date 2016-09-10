//+------------------------------------------------------------------+
//|                                       ALX_v40_pricePattern.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+

/**
 * simple bar action triggers
 * traling SL
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    //allSymbols[0]  = "AUDUSD";  allSymbols[1]  = "USDCAD";  allSymbols[2]  = "USDCHF";  allSymbols[3]  = "EURUSD";
    //allSymbols[4]  = "GBPUSD";  allSymbols[5]  = "USDJPY";  allSymbols[6]  = "NZDUSD";
    
    lastBarTime = Time[0];
    
    //setSymbols();
    
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
    //------------------------------------------------------------------------- TRADE rules
    if(lastBarTime != Time[0]) {
        double atr = iATR(NULL, PERIOD_M1, 15, 0);
        
        //identify previous bars
        double bar1 = MathAbs(Close[1] - Open[1]);
        double bar2 = MathAbs(Close[2] - Open[2]);
        
        if(bar1 > bar2 && bar1 + bar2 >= atr) {
            if(Close[1] - Open[1] > 0) {
                double sl = Low[1];
                double rg = Ask - Low[1];
                double tp = Ask + (rg)*1.5;
                
                if(buyOrder.ticket == -1) {    
                    createBuy(sl, tp, rg);
                }
                else if(Bid >= buyOrder.price) {
                    closeBuy();
                    createBuy(sl, tp, rg);
                }
            }
            else if(Close[1] - Open[1] < 0) {
                double sl = High[1];
                double rg = High[1] - Bid;
                double tp = Bid - (rg)*1.5;
                
                if(sellOrder.ticket == -1) {
                    createSell(sl, tp, rg);
                }
                else if(Ask <= sellOrder.price) {
                    closeSell();
                    createSell(sl, tp, rg);
                }
            }
        }
        
        lastBarTime = Time[0];
    }
    
    if(buyOrder.ticket != -1) {
        if(Bid >= buyOrder.price && (Bid - buyOrder.range) > buyOrder.sl)
            buyOrder.sl = Bid - buyOrder.range;
        
        if(Bid >= buyOrder.tp)
            closeBuy();
        if(Bid < buyOrder.sl)
            closeBuy();
    }
    
    if(sellOrder.ticket != -1) {
        //Print("Ask: ", Ask, "sellOrder.price ", sellOrder.price, "(Ask + sellOrder.range) ", 
        //(Ask + sellOrder.range), "sl ", sellOrder.sl);
        if(Ask <= sellOrder.price && (Ask + sellOrder.range) < sellOrder.sl) {
            sellOrder.sl = Ask + sellOrder.range;
            //Print("sell stop loss set to: ", sellOrder.sl);
        }
        
        if(Ask <= sellOrder.tp)
            closeSell();
        if(Ask > sellOrder.sl)
            closeSell();
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+ 

/**
 * Create a buy order
 */
void createBuy(double sl, double tp, double range) {
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
    buyOrder.sl = sl;
    buyOrder.tp = tp;
    buyOrder.range = range;
    buyOrder.ticket = order;
    buyOrder.size = osize;
    
    Print("**BUY: sl:", sl, "tp: ", tp, " range: ", range);
}

/**
 * Create a sell order
 */
void createSell(double sl, double tp, double range) {
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
    sellOrder.sl = sl;
    sellOrder.tp = tp;
    sellOrder.range = range;
    sellOrder.ticket = order;
    sellOrder.size = osize;
    
    Print("**SELL: sl:", sl, "tp: ", tp, " range: ", range);
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