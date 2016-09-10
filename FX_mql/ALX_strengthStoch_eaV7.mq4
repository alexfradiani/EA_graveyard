//+------------------------------------------------------------------+
//|                                    ALX_strengthStoch_eaV6.mq4    |
//|                                           Alexander Fradiani     |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * VERSION NOTE:
 * price confirmation when executing trade. close when m30 stochastic is moving opposite.
 *
 * - EA based on strength of currencies for trades
 * - Stochastics MTF rules
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double BASE_SL = 500;

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    int op_type;
};

order_t buyOrder;
order_t sellOrder;

struct stoch_status_t {
    double pivot;
    int climbing;
    int weakClimb;
    int lastTrigger;
};
stoch_status_t m5;
stoch_status_t m15;
stoch_status_t m30;

datetime lastTime;
int timePivot = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    m5.lastTrigger = NONE;
    m15.lastTrigger = NONE;
    m30.lastTrigger = NONE;
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastTime = Time[0];
    
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
    evaluateStochs();
    
    RefreshRates();
}
//+------------------------------------------------------------------+

//log for debugging vars state
void printState() {
    Print("M5[climbing:",m5.climbing," weakClimb:",m5.weakClimb," lastTrigger:",m5.lastTrigger," pivot:",m5.pivot," ]"+
        " M15[climbing:",m15.climbing," weakClimb:",m15.weakClimb," lastTrigger:",m15.lastTrigger," pivot:",m15.pivot," ]"+
        " M30[climbing:",m30.climbing," weakClimb:",m30.weakClimb," lastTrigger:",m30.lastTrigger," pivot:",m30.pivot," ]");
}

/**
 * Stochastics for deciding trades
 */
void evaluateStochs() {
    string pair = "EURUSD";
    
    double m5_st, m15_st, m30_st;
    m5_st = m15_st = m30_st = -1;
    
    if(Time[0] != lastTime) {  //Check which stochastics can be updated
        timePivot++;
        
        m5_st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 1);  //new M5
 
        if(timePivot >= 6) {  //new M30 and M15
            m30_st = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
            m15_st = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
           
            timePivot = 0; //pivot reset
        }
        else if(timePivot == 3) {  //new M15
            m15_st = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
        }
        
        lastTime = Time[0];
    }
    
    if(m5_st >= 0) {
        if(m5_st <= 11) {   //******************EVALUATE M5
            m5.climbing = NONE;
            m5.lastTrigger = UP;
        }
        else if(m5_st >= 89) {
            m5.climbing = NONE;
            m5.lastTrigger = DOWN;
        }
        else {
            if(m5.lastTrigger == UP) {
                if(m5.climbing >= NONE) {
                    if(m5_st < m5.pivot)
                        m5.climbing = DOWN;
                    else
                        m5.climbing = UP;
                }    
            }
            else if(m5.lastTrigger == DOWN) {
                if(m5.climbing <= NONE) {
                    if(m5_st > m5.pivot)
                        m5.climbing = UP;
                    else
                        m5.climbing = DOWN;
                }
            }
        }
        
        //update pivot
        m5.pivot = m5_st;
    }
    
    if(m15_st >= 0) {
        if(m15_st <= 21) {   //******************EVALUATE M15
            m15.climbing = NONE;
            m15.lastTrigger = UP;
        }
        else if(m15_st >= 79) {
            m15.climbing = NONE;
            m15.lastTrigger = DOWN;
        }
        else {
            if(m15.lastTrigger == UP) {
                if(m15.climbing >= NONE) {
                    if(m15_st < m15.pivot)
                        m15.climbing = DOWN;
                    else
                        m15.climbing = UP;
                }    
            }
            else if(m15.lastTrigger == DOWN) {
                if(m15.climbing <= NONE) {
                    if(m15_st > m15.pivot)
                        m15.climbing = UP;
                    else
                        m15.climbing = DOWN;
                }
            }
        }
        
        //measure inmediate movement
        if(m15_st > m15.pivot) {
            m15.weakClimb = UP;
        } 
        else if(m15_st < m15.pivot)
            m15.weakClimb = DOWN;
        else {  //equal value
            if(m15.lastTrigger == DOWN)
                m15.weakClimb = DOWN;
            else if(m15.lastTrigger == UP) {
                m15.weakClimb = UP; 
            } 
            else
                m15.weakClimb = NONE;
        }
        
        //update pivot
        m15.pivot = m15_st;
    }
    
    if(m30_st >= 0) {
        if(m30_st <= 21) {   //******************EVALUATE M30
            m30.climbing = NONE;
            m30.lastTrigger = UP;
        }
        else if(m30_st >= 79) {
            m30.climbing = NONE;
            m30.lastTrigger = DOWN;
        }
        else {
            if(m30.lastTrigger == UP) {
                if(m30.climbing >= NONE) {
                    if(m30_st < m30.pivot)
                        m30.climbing = DOWN;
                    else
                        m30.climbing = UP;
                }    
            }
            else if(m30.lastTrigger == DOWN) {
                if(m30.climbing <= NONE) {
                    if(m30_st > m30.pivot)
                        m30.climbing = UP;
                    else
                        m30.climbing = DOWN;
                }
            }
        }
        
        //measure inmediate movement
        if(m30_st > m30.pivot) {
            m30.weakClimb = UP;
        } 
        else if(m30_st < m30.pivot) {
            m30.weakClimb = DOWN;
        } 
        else {  //equal value
            if(m30.lastTrigger == DOWN) {
                m30.weakClimb = DOWN;
            } 
            else if(m30.lastTrigger == UP) {
                m30.weakClimb = UP;
            } 
            else
                m30.weakClimb = NONE;
        }
        
        //update pivot 
        m30.pivot = m30_st;
        
        //printState();
    }

    if(m5.lastTrigger == UP) { //conditions for longs
        if(m30.weakClimb == UP && m30.lastTrigger == UP) {
            if(priceCorrelation(UP, pair) == UP) {    
                if(buyOrder.ticket == -1)
                    createBuy(pair);
            }
        }
    }
    
    if(m5.lastTrigger == DOWN) { //conditions for shorts
        if(m30.weakClimb == DOWN && m30.lastTrigger == DOWN) {
            if(priceCorrelation(DOWN, pair) == DOWN) {
                if(sellOrder.ticket == -1)
                    createSell(pair);
            }
        }
    }
    
    //**********************************************************************************verify stops and profits
    if(buyOrder.ticket != -1) {
        if(m5.lastTrigger == DOWN && Bid - buyOrder.price > 0) {
            closeBuy();
            if(Bid - buyOrder.price > 0) {
                if(priceCorrelation(UP, pair) == UP)
                    ;//createBuy(pair);
            }
        }
        else if(Bid <= buyOrder.sl) { //critic stoploss
            closeBuy();
        }
    }
    
    if(sellOrder.ticket != -1) {
        if(m5.lastTrigger == UP && sellOrder.price - Ask > 0) {
            closeSell();
            if(sellOrder.price - Ask > 0) {
                if(priceCorrelation(DOWN, pair) == DOWN)
                    ;//createSell(pair);
            }
        }        
        else if(Ask >= sellOrder.sl) { //critic stoploss
            closeSell();
        }    
    }
}

/** Evaluate the relationship between the stochastic and price movement
 * for confirmation of possible trade
 */
int priceCorrelation(int evaluating, string pair) {
    int i = 1;
    int offsets = 0;
    double st;
    
    int stochIndexes[2];
    double stochValues[2];
    
    if(evaluating == UP) {
        stochValues[0] = stochValues[1] = 999;
        stochIndexes[0] = stochIndexes[1] = -1;
        
        //leave current down peak if inside
        /*bool inside_offset = TRUE;
        while(inside_offset) {
            st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, i);
            if(st <= 50)
                i++;
            else
                inside_offset = FALSE;
        }*/
        
        //take two low reference peaks
        bool peakTaken = FALSE;
        while(offsets < 2) {
            st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, i);
            if(st <= 11 && st < stochValues[offsets]) {
                stochValues[offsets] = st;
                stochIndexes[offsets] = i;
                peakTaken = TRUE;
            }
            else if(st > 50 && peakTaken == TRUE) {
                peakTaken = FALSE;
                offsets++;
            }
            i++;
        }
        
        double price0 = iClose(pair, PERIOD_M5, stochIndexes[0]);
        double price1 = iClose(pair, PERIOD_M5, stochIndexes[1]);
        
        Print("-- PriceCorrelation. Evaluating UP");
        Print("PriceCorrelation - peak0 at ", Time[stochIndexes[0]], " stoch: ", stochValues[0], " price: ", price0);
        Print("PriceCorrelation - peak1 at ", Time[stochIndexes[1]], " stoch: ", stochValues[1], " price: ", price1);
        
        if(price0 > price1) {
            Print("-- result UP");
            return UP;
        }
    }
    else if(evaluating == DOWN) {
        stochValues[0] = stochValues[1] = 0;
        stochIndexes[0] = stochIndexes[1] = -1;
        
        //leave current high peak if inside
        /*bool inside_offset = TRUE;
        while(inside_offset) {
            st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, i);
            if(st > 50)
                i++;
            else
                inside_offset = FALSE;
        }*/
        
        //take two high reference peaks
        bool peakTaken = FALSE;
        while(offsets < 2) {
            st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, i);
            if(st >= 89 && st > stochValues[offsets]) {
                stochValues[offsets] = st;
                stochIndexes[offsets] = i;
                peakTaken = TRUE;
            }
            else if(st <= 50 && peakTaken == TRUE) {
                peakTaken = FALSE;
                offsets++;
            }
            i++;
        }
        
        double price0 = iClose(pair, PERIOD_M5, stochIndexes[0]);
        double price1 = iClose(pair, PERIOD_M5, stochIndexes[1]);
        
        Print("PriceCorrelation. Evaluating DOWN");
        Print("PriceCorrelation - peak0 at ", Time[stochIndexes[0]], " stoch: ", stochValues[0], " price: ", price0);
        Print("PriceCorrelation - peak1 at ", Time[stochIndexes[1]], " stoch: ", stochValues[1], " price: ", price1);
        
        if(price0 < price1) {
            Print("-- result DOWN");
            return DOWN;
        }
    }
    
    return NONE;
} 

/**
 * Create a buy order
 */
void createBuy(string pair) {
    int digit = MarketInfo(pair, MODE_DIGITS);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(pair, MODE_ASK);
	double stoploss = oprice - BASE_SL*Point;
	//double takeprofit = oprice + 50*Point;
	int order = OrderSend(
		pair, //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0, //NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.ticket = order;
    
    //Print("BUY created. Close[1] was: ", Close[1]," Ask: ", buyOrder.price," SL: ", buyOrder.sl);
}

/**
 * Create a sell order
 */
void createSell(string pair) {
    int digit = MarketInfo(pair, MODE_DIGITS);

    int optype = OP_SELL;
    double oprice = MarketInfo(pair, MODE_BID);
	double stoploss = oprice + BASE_SL*Point;
	//double takeprofit = oprice - 50*Point;
	int order = OrderSend(
		pair, //symbol
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