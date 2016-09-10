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

#define CLOSED 0
#define FORCING -1
#define FORMING 1
#define COLLECTING_BUY 2
#define COLLECTING_SELL 3

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

//Variables to control forcing probabilities
int levelStatus;
int levelIndex;
double levelTP;
double levelSL;
double levelLoss;
double offset;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    //allSymbols[0]  = "AUDUSD";  allSymbols[1]  = "USDCAD";  allSymbols[2]  = "USDCHF";  allSymbols[3]  = "EURUSD";
    //allSymbols[4]  = "GBPUSD";  allSymbols[5]  = "USDJPY";  allSymbols[6]  = "NZDUSD";
    
    lastBarTime = Time[0];
    levelStatus = CLOSED;
    
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
    //----------------------------CYCLE:  (CLOSED OR FORCING) -> FORMING -> COLLECTING_(BUY OR SELL) -> (CLOSED OR FORCING)
    
    if(lastBarTime != Time[0]) {
        if(levelStatus == CLOSED || levelStatus == FORCING) {  //start neutral operation
            createBuy();
            createSell();
            
            if(levelStatus == CLOSED) { //initial expectancy
                levelIndex = 1;
                levelTP = 10*Point;  
                levelSL = 7*Point;
                levelLoss = 0;
            }
            
            levelStatus = FORMING;
        }
        
        if(levelStatus == FORMING) { //define the trend
            if(Bid - buyOrder.price >= levelTP) {  //moving half way from objective
                closeSell();
                
                levelLoss += sellOrder.price - Ask;
                buyOrder.sl = Bid - levelSL;
                offset = Ask;
                levelStatus = COLLECTING_BUY;
            }
            
            if(sellOrder.price - Ask > levelTP) {
                closeBuy();
                
                levelLoss += Bid - buyOrder.price;
                sellOrder.sl = Ask + levelSL;
                offset = Bid;
                levelStatus = COLLECTING_SELL;
            }
        }
        
        lastBarTime = Time[0];
    }
    
    if(levelStatus == COLLECTING_BUY) {
        if(Bid - offset >= levelTP) {  //profit
            double times = floor( (Bid - offset)/levelTP );
            buyOrder.sl = offset + times*levelTP + (buyOrder.price - sellOrder.price);
        }
        
        if(Bid <= buyOrder.sl) {
            if(Bid > offset) { //in profit
                levelStatus = CLOSED;
                closeBuy();
            }
            else {  
                closeBuy();
                
                levelIndex++;
                if(levelIndex > 5) {  //limit reached, take losses.
                    levelStatus = CLOSED;
                }
                else { //move to next level. force trade.
                    levelLoss += Bid - buyOrder.price;
                    levelTP = MathAbs(levelLoss) + 10*Point;
                    levelSL = levelTP/1.5;
                    
                    levelStatus = FORCING;
                }
            }
        }
    }
    
    if(levelStatus == COLLECTING_SELL) {
        if(offset - Ask >= levelTP) {  //profit
            double times = floor( (offset - Ask)/levelTP );
            sellOrder.sl = offset - times*levelTP - (buyOrder.price - sellOrder.price);
        }
        
        if(Ask >= sellOrder.sl) {
            if(Ask < offset) { //close in profit
                levelStatus = CLOSED;
                closeSell();
            }
            else {  
                closeSell();
                
                levelIndex++;
                if(levelIndex > 5) {  //limit reached, take losses.
                    levelStatus = CLOSED;
                }
                else { //move to next level. force trade.
                    levelLoss += sellOrder.price - Ask;
                    levelTP = MathAbs(levelLoss) + 10*Point;
                    levelSL = levelTP/1.5;
                    
                    levelStatus = FORCING;
                }
            }
        }
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