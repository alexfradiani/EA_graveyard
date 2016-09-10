//+------------------------------------------------------------------+
//|                                        Alx_MarketDynnamics.mq4   |
//|                                             Alexander Fradiani   |
//+------------------------------------------------------------------+
/**
 * double setup system:
 *    - trending market state
 *    - and non-directional (choppy) market state
 * use wilder ADX(ADXR), directional-movement to determine state.
 * select top currencies for trading.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define MIDDLE_UP 0.5
#define NONE 0
#define MIDDLE_DOWN -0.5
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

#define ALL_SYMBOLS_N 20
#define ACTIVE_SYMBOLS_N 10

datetime lastTime;  //for execution on each bar

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    datetime time;
    double size;
};

struct _symbSorter {
    double adxr;
    string symbol;
};

string allSymbols[ALL_SYMBOLS_N];
_symbSorter stracked[ACTIVE_SYMBOLS_N];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0]; 
 
    //--------------------------------------------------------------------load all symbols being tracked
    allSymbols[0]  = "EURUSDi";  allSymbols[1]  = "GBPUSDi";  allSymbols[2]  = "USDCHFi";  allSymbols[3]  = "USDJPYi";
    allSymbols[4]  = "EURGBPi";  allSymbols[5]  = "EURCHFi";  allSymbols[6]  = "EURJPYi";  allSymbols[7]  = "GBPCHFi";
    allSymbols[8]  = "GBPCHFi";  allSymbols[9]  = "GBPJPYi";  allSymbols[10] = "CHFJPYi";  allSymbols[11] = "USDCADi";
    allSymbols[12] = "EURCADi";  allSymbols[13] = "GBPCADi";  allSymbols[14] = "CADCHFi";  allSymbols[15] = "CADJPYi";
    allSymbols[16] = "AUDCADi";  allSymbols[17] = "AUDUSDi";  allSymbols[18] = "EURAUDi";  allSymbols[19] = "GBPAUDi";
 
    setActiveSymbols();
 
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
    
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * determine the symbols that are going to be tracked for
 * the current ticks
 */
void setActiveSymbols() {
    //Determine ADXR of all tracked symbols
    _symbSorter tosort[ALL_SYMBOLS_N];
    for(int i = 0; i < ALL_SYMBOLS_N; i++) {
        double adx = iADX(allSymbols[i], 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
        double adx_14 = iADX(allSymbols[i], 0, 14, PRICE_CLOSE, MODE_MAIN, 15);
        double adxr = (adx + adx_14) / 2;
        
        tosort[i].adxr = adxr;
        tosort[i].symbol = allSymbols[i];
        Print(tosort[i].symbol, " adxr:", tosort[i].adxr);
    }
    
    //order in descending mode
    for(int i = 0; i < ALL_SYMBOLS_N; i++)
        for(int j = i; j < ALL_SYMBOLS_N; j++)
            if(tosort[j].adxr > tosort[i].adxr) {
                _symbSorter temp;
                temp.adxr = tosort[i].adxr;
                temp.symbol = tosort[i].symbol;
                
                tosort[i].adxr = tosort[j].adxr;
                tosort[i].symbol = tosort[j].symbol;
                
                tosort[j].adxr = temp.adxr;
                tosort[j].symbol = temp.symbol;
            }
            
    //take the top trending first
    int trending = 0;
    int rcont = 0;
    while(tosort[trending].adxr > 25 && rcont < ACTIVE_SYMBOLS_N) {
        stracked[rcont].adxr = tosort[trending].adxr;
        stracked[rcont].symbol = tosort[trending].symbol;
        trending++;
        rcont++;
    }
    //take the top choppy then
    int choppy = ACTIVE_SYMBOLS_N - 1;
    while(rcont < ACTIVE_SYMBOLS_N && tosort[choppy].adxr < 25) {
        stracked[rcont].adxr = tosort[choppy].adxr;
        stracked[rcont].symbol = tosort[choppy].symbol;
        choppy--;
        rcont++;
    }
    
    Print("tracked symbols in order: ");
    for(int i = 0; i < ACTIVE_SYMBOLS_N; i++)
        Print(stracked[i].symbol, " adxr:", stracked[i].adxr);
} 
 
/**
 * Render conditions for trades.
 */
void parseStrategy() {
    
}
 
/**
 * OPEN an order
 */
void openOrder(int op_type, order_t &trade, double dyTP, double dySL) {
    double oprice;
    double stoploss;
    double takeprofit;
    
    //create order
    if(op_type == OP_BUY) {
        oprice = MarketInfo(Symbol(), MODE_ASK);
    	stoploss = dySL;
    	takeprofit = dyTP;
    }
    else {
        oprice = MarketInfo(Symbol(), MODE_BID);
    	stoploss = dySL;
    	takeprofit = dyTP;
    }
	double osize = R_VOL;
	
	int order = OrderSend(
		Symbol(), //symbol
		op_type, //operation
		osize, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    trade.op_type = op_type;
    trade.price = oprice;
    trade.sl = stoploss;
    trade.tp = takeprofit;
    trade.ticket = order;
    trade.time = lastTime;
    trade.size = osize;
}

/**
 * CLOSE an order
 */
bool closeOrder(order_t &trade) {
    double price;
    if(trade.op_type == OP_BUY)
        price = Bid;
    else
        price = Ask;
        
    bool close = OrderClose(trade.ticket, trade.size, price, 3, Blue);
    if(close == TRUE)
        trade.ticket = -1;
        
    return close;
} 