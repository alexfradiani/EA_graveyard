//+------------------------------------------------------------------+
//|                                    ALX_M1_H1_MAs_Integrals.mq4   |
//|                                             Alexander Fradiani   |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * M1 and H1 interaction
 * Moving averages 30SMA H1 -> 1800 SMA M1
 *                 10SMA H1 -> 600 SMA M1
 *                 30SMA M1 direction filter. 
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades
extern double BASE_PIPS = 50; //limit for SL

int instantSide = NONE; //price position with respect to the M1 30SMA
int localSide = NONE;  //price position with respect to the H1 10SMA
int globalSide = NONE; // position of H1 10SMA with respect to H1 30SMA

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

//Used for validating correct trend lines and trades
struct _riemann {
    //to verify if a riemann block can continue to execute trades
    bool validSell;
    bool validBuy;
    
    //to check if price is choppy around H1 MA, signaling indecision.
    int buyPerformance;
    int sellPerformance;
    
    double pips; //pips accumulated on a riemann block
    bool ma30Sw; //to validate trades that are in the wrong side of the ma30.
};
_riemann riemann;

order_t buyOrder;
order_t sellOrder;

/*for execution on each bar*/
datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    riemann.validBuy = FALSE;
    riemann.validSell = FALSE;
    riemann.pips = 0;
    riemann.buyPerformance = 1;
    riemann.sellPerformance = 1;
    
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
     *  10SMA(H1) must be upside 30SMA(H1) (globalSide is UP)
     *  price is: going up from 10SMA(H1) for first time (localSide enters UP) (riemann starts)
     *        or: price is going up from 30SMA(M1) (instantSide enters UP) and RIEMANN is VALID!
     *  EXIT when:
     *  price goes below 10SMA(H1) (localSide enters DOWN) OR (ensuring 50pips for current riemann block)
     *  price goes below 30SMA(M1) (instantSide enters DOWN) IF IN PROFIT!
            --> exception: when order started below 30SMA, wait until goes up for the first time.
     **/
     
    double ma1800 = iMA(NULL, PERIOD_M1, 1800, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma600 = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma600_old = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 5);
    double ma30 = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    //--------------------------------------------------------------------Exit rules
    if(buyOrder.ticket != -1) {
        //check ma30 switch
        if(Bid > ma30)
            riemann.ma30Sw = TRUE;
        
        if(Bid <= buyOrder.sl) {
            closeBuy();
            
            riemann.validBuy = FALSE;
            riemann.buyPerformance = 1;
        }
        else if(Bid < ma30) {
            instantSide = DOWN;
            if(riemann.ma30Sw == TRUE && Bid - buyOrder.price > 10*Point) {   //takeprofit
                closeBuy();
                riemann.pips += Bid - buyOrder.price; // register profits for this riemann block
                riemann.buyPerformance = 1;
            }
        }
        
        if(Bid < ma600) {      //stoploss
            closeBuy();
            localSide = DOWN;
            
            riemann.validBuy = FALSE;
            if(riemann.pips == 0)
                riemann.buyPerformance = -1; //skeptic validation next time.
        }
    }
    
    if(sellOrder.ticket != -1) {
        //check ma30 switch
        if(Bid < ma30)
            riemann.ma30Sw = TRUE;
        
        if(Bid >= sellOrder.sl) {
            closeSell();
            
            riemann.validSell = FALSE;
            riemann.sellPerformance = 1;
        }
        else if(Bid > ma30) {
            instantSide = UP;
            if(riemann.ma30Sw == TRUE && sellOrder.price - Bid > 10*Point) {   //takeprofit
                closeSell();
                riemann.pips += sellOrder.price - Bid; // register profits for this riemann block
                riemann.sellPerformance = 1;
            }
        }
        
        if(Bid > ma600) {      //stoploss
            closeSell();
            localSide = UP;
            
            riemann.validSell = FALSE;
            if(riemann.pips == 0)
                riemann.sellPerformance = -1; //skeptic validation next time.
        }
    }
    //--------------------------------------------------------------------  Trade Rules
    
    if(lastTime != Time[0]) {
        //global side position
        if(ma600 > ma1800)
            globalSide = UP;
        else if(ma600 < ma1800)
            globalSide = DOWN;
        else
            globalSide = NONE;
        
        if(Open[0] > ma600) {
            if(localSide == DOWN && globalSide == UP) {
                if(ma600 > ma600_old) {
                    bool skc = skepticCheck(OP_BUY);
                    if(skc == TRUE) { //additional condition to reduce noise in prices too close to avrg.
                        if(buyOrder.ticket == -1) {
                            riemann.validBuy = TRUE;  //riemann checkpoint
                            riemann.pips = 0;
                            createBuy();
                            
                            //check ma30 switch
                            if(Open[0] > ma30)
                                riemann.ma30Sw = TRUE;
                            else
                                riemann.ma30Sw = FALSE;
                        }
                    }
                }
            }
            localSide = UP;
            
            if(Open[0] > ma30) {
                if(instantSide <= NONE && riemann.validBuy == TRUE)
                    if(buyOrder.ticket == -1)
                        createBuy();
                        
                instantSide = UP;
            }
            else
                instantSide = DOWN;    
        }
        else if(Open[0] < ma600) {
            if(localSide == UP && globalSide == DOWN) {
                if(ma600 < ma600_old) {
                    if(skepticCheck(OP_SELL) == TRUE) { //additional condition to reduce noise in prices too close to avrg.
                        if(sellOrder.ticket == -1) {
                            riemann.validSell = TRUE;   //riemann checkpoint
                            riemann.pips = 0;
                            createSell();
                            
                            //check ma30 switch
                            if(Open[0] < ma30)
                                riemann.ma30Sw = TRUE;
                            else
                                riemann.ma30Sw = FALSE;
                        }
                    }
                }
            }
            localSide = DOWN;
            
            if(Open[0] < ma30) {
                if(instantSide >= NONE && riemann.validSell == TRUE)
                    if(sellOrder.ticket == -1)
                        createSell();
                        
                instantSide = DOWN;
            }
            else
                instantSide = UP;    
        }
        
        lastTime = Time[0];
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

bool skepticCheck(int optype) {  //additional filter for price too close to the H1 MA and choppy
    bool res = TRUE;
    double ma30 = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma30_old = iMA(NULL, PERIOD_M1, 30, 0, MODE_SMA, PRICE_CLOSE, 1);
    double ma600 = iMA(NULL, PERIOD_M1, 600, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    if(optype == OP_BUY && riemann.buyPerformance > 0)
        res = TRUE;
    else if(optype == OP_SELL && riemann.sellPerformance > 0)
        res = TRUE;
    else {
        if(optype == OP_BUY) {
            if(ma30_old < ma30) {  //good average 
                double high = High[0];
                for(int i = 0; i < 10; i++) { //establish a high threshold
                    if(High[i] > high)
                        high = High[i];
                }
                //no more than 50 pips up
                if(MathAbs(high - ma600) > 50*Point)
                    high = ma600 + 50*Point;
                
                if(Open[0] >= high)
                    res = TRUE;
            }
            else
                res = FALSE;
        }
        else if(optype == OP_SELL) {
            if(ma30_old > ma30) {
                double low = Low[0];
                for(int i = 0; i < 10; i++) { //establish a high threshold
                    if(Low[i] < low)
                        low = Low[i];
                }
                //no more than 50 pips down
                if(MathAbs(low - ma600) > 50*Point)
                    low = ma600 - 50*Point;
                
                if(Open[0] <= low)
                    res = TRUE;
            } 
            else
                res = FALSE;
        }
    }
    
    return res;
}

/**
 * Determine STOP LOSS BASED ON RIEMANN EXPECTATION
 */
double setSL(double oprice, int optype) {
    double range;
    
    if(riemann.pips >= 50*Point)
        range = riemann.pips - 50*Point;
    else
        range = BASE_PIPS*Point;
    
    if(optype == OP_BUY) {
        return oprice - range;
    }
    else if(optype == OP_SELL) {
        return oprice + range;
    }
    else
        return oprice;
}

/**
 * Create a buy order
 */
void createBuy() {
    int digit = MarketInfo(Symbol(), MODE_DIGITS); 
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double stoploss = setSL(oprice, optype);

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
	double stoploss = setSL(oprice, optype);
	
	//Print("riemann pips: ", riemann.pips);
	//Print("STOPLOSS SET AT ", stoploss);
	
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