//+------------------------------------------------------------------+
//|                                         ALX_M1_H1_DAYSCALP.mq4   |
//|                                             Alexander Fradiani   |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * M1 and H1 interaction
 * Moving averages
 *                 10SMA H1 -> 600 SMA M1
 *                 30SMA M1 direction filter. 
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

#define DAY_TARGET 100

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades
#define BASE_PIPS  10

int instantSide = NONE; //price position with respect to the M1 30SMA
int localSide = NONE;  //position of M1 30SMA with respect to the H1 10SMA

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

//Used for managing day goals
int workingDay;   //day of current operation
double workingGoal;  //accumulated for day goal

order_t buyOrder;
order_t sellOrder;

/*for execution on each bar*/
datetime lastTime;

bool bannedBar = FALSE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    
    workingDay = Day();
    workingGoal = 0;
    
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
    /** Rules for method: (case for longs)
     *  30SMA(M1) > 10SMA(H1) (localSide is UP), 30SMA is going up
     *  price is below 30SMA(M1) (instantSide is DOWN) and starting to go up
     *  EXIT when:
     *  40 pips stoploss
     *  +50 pips takeprofit
     *  touching 30 sma(m1) in profit 
     **/
     
    double ma600 = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma30 = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma30_old = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    //--------------------------------------------------------------------Exit rules
    if(buyOrder.ticket != -1) {
        double diff = Bid - buyOrder.price - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(Bid <= buyOrder.sl) {
            closeBuy();
            workingGoal += diff;
            bannedBar = TRUE;
        }
        else if(Bid - buyOrder.price > MarketInfo(Symbol(), MODE_SPREAD)*Point) {
            int times = floor( (Bid - buyOrder.price)/(50*Point) );
            buyOrder.sl = buyOrder.price + MarketInfo(Symbol(), MODE_SPREAD)*Point + times*50*Point;
        }
        
        if(Bid <= ma30 && diff > 0) {
            closeBuy();
            workingGoal += diff;
            bannedBar = TRUE;
        }
    }
    
    if(sellOrder.ticket != -1) {
        double diff = sellOrder.price - Ask - MarketInfo(Symbol(), MODE_SPREAD)*Point;
        
        if(Ask >= sellOrder.sl) {
            closeSell();
            workingGoal += diff;
            bannedBar = TRUE;
        }
        else if(sellOrder.price - Ask > MarketInfo(Symbol(), MODE_SPREAD)*Point) {
            int times = floor( (sellOrder.price - Ask)/(50*Point) );
            sellOrder.sl = sellOrder.price - MarketInfo(Symbol(), MODE_SPREAD)*Point - times*50*Point;
        }
        
        if(Ask >= ma30 && diff > 0) {
            closeSell();
            workingGoal += diff;
            bannedBar = TRUE;
        }
    }
    //--------------------------------------------------------------------  Trade Rules
    
    if(workingDay == Day()) {
        if(NormalizeDouble(workingGoal, 4) < DAY_TARGET*Point) {
            //Print("working goal: ", workingGoal, " target: ", DAY_TARGET*Point);
            if(lastTime != Time[0]) {
                if(ma30 > ma600)
                    localSide = UP;
                else if(ma30 < ma600)
                    localSide = DOWN;
                else
                    localSide = NONE;
                
                if(Open[0] < ma30)
                    instantSide = DOWN;
                else if(Open[0] > ma30)
                    instantSide = UP;
                else
                    instantSide = NONE;
                    
                lastTime = Time[0];
                bannedBar = FALSE;
            }
            
            if(localSide == UP && instantSide == DOWN) {   //CREATE A BUY
                if(Bid >= ma30)
                    if(ma30 > ma30_old)
                        if(buyOrder.ticket == -1 && bannedBar == FALSE)
                            createBuy();
            }
            
            if(localSide == DOWN && instantSide == UP) {   //CREATE A SELL
                if(Bid <= ma30)
                    if(ma30 < ma30_old)
                        if(sellOrder.ticket == -1 && bannedBar == FALSE)
                            createSell();
            }
        }
    }
    else {
        workingDay = Day();
        workingGoal = 0;
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