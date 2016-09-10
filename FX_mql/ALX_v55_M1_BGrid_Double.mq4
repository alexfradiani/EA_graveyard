//+------------------------------------------------------------------+
//|                                     ALX_v55_M1_BGrid_Double.mq4  |
//+------------------------------------------------------------------+

/**
 * use bollinger tops and bottoms.
 * play simultaneously buys & sells
 * with controlled martingale.
 */

#property copyright "ALEXANDER FRADIANI"
#property link "http://www.fradiani.com"
#property version   "1.00"
#property strict

#define GRID_Y 52
#define TRADE_SIZE 0.01

#define UP 1
#define DOWN -1
#define NONE 0

datetime lastTime;

struct order_t {     //DATA for orders
    int ticket;
    double price;
    int op_type;
    double size;
    string symbol;
};

struct cycle_t {
    order_t currFollow;
    double accum;
};
cycle_t buyCycle, sellCycle;
int priceSide, maDirection;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    
    buyCycle.currFollow.ticket = -1;
    buyCycle.accum = 0;
    buyCycle.currFollow.size = TRADE_SIZE;
    
    sellCycle.currFollow.ticket = -1;
    sellCycle.accum = 0;
    sellCycle.currFollow.size = TRADE_SIZE;
    
    priceSide = NONE;
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    lastTime = Time[0];
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    //read Bollinger bands
    double higherBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double middleBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    double lowerBand = iBands(Symbol(), PERIOD_M1, 60, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    
    double upThreshold = middleBand + 0.8*(higherBand - middleBand);
    double downThreshold = middleBand - 0.8*(middleBand - lowerBand);
    
    double m3_0 = iMA(Symbol(), PERIOD_M1, 3, 0, MODE_SMA, PRICE_CLOSE, 0);
    double m3_1 = iMA(Symbol(), PERIOD_M1, 3, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    if(m3_0 > m3_1)
        maDirection = UP;
    else if(m3_0 < m3_1)
        maDirection = DOWN;
    else
        maDirection = NONE;
    
    //--------------------------------------------------------------------------------CREATE BUY OR SELL
    double point = MarketInfo(Symbol(), MODE_POINT);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    
    if(bid > upThreshold)
        priceSide = UP;
    else if(bid < downThreshold)
        priceSide = DOWN;
    
    if(priceSide == UP && maDirection == DOWN && bid < upThreshold && bid > middleBand) {  //SELL TRIGGER
        if(MathAbs(sellCycle.currFollow.price - ask) >= GRID_Y*point || sellCycle.currFollow.ticket == -1) {
            if(sellCycle.currFollow.ticket != -1) {
                bool in_profit = FALSE;
                
                if(sellCycle.accum + (sellCycle.currFollow.price - ask)*sellCycle.currFollow.size >= 0)
                    in_profit = TRUE;
                
                closeSellCycle(in_profit);
            }
            
            if(buyCycle.currFollow.ticket != -1) {
                bool in_profit = FALSE;
                
                if(buyCycle.accum + (bid - buyCycle.currFollow.price)*buyCycle.currFollow.size >= 0)
                    in_profit = TRUE;
                
                closeBuyCycle(in_profit);
            }
            
            createBuy();
            createSell();
        }
    }
    
    if(priceSide == DOWN && maDirection == UP && bid > downThreshold && bid < middleBand) {
        if(MathAbs(bid - buyCycle.currFollow.price) >= GRID_Y*point || buyCycle.currFollow.ticket == -1) {
            if(sellCycle.currFollow.ticket != -1) {
                bool in_profit = FALSE;
                
                if(sellCycle.accum + (sellCycle.currFollow.price - ask)*sellCycle.currFollow.size >= 0)
                    in_profit = TRUE;
                
                closeSellCycle(in_profit);
            }
            
            if(buyCycle.currFollow.ticket != -1) {
                bool in_profit = FALSE;
                
                if(buyCycle.accum + (bid - buyCycle.currFollow.price)*buyCycle.currFollow.size >= 0)
                    in_profit = TRUE;
                
                closeBuyCycle(in_profit);
            }
            
            createBuy();
            createSell();
        }
    }
   
    //------------------------------------------------------------------------------------------- CLOSEs
    
    //STOP LOSSES
    /*if(buyCycle.currFollow.ticket != -1) {
        if(bid - buyCycle.currFollow.price <= -1*GRID_Y * point)
            closeBuyCycle(FALSE);
    }
    
    if(sellCycle.currFollow.ticket != -1) {
        if(sellCycle.currFollow.price - ask <= -1*GRID_Y * point)
            closeSellCycle(FALSE);
    }*/
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Open a BUY order
 */
void createBuy() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = buyCycle.currFollow.size;
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	
	int order = OrderSend(
        Symbol(), //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        10, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        buyCycle.currFollow.price = oprice;
        buyCycle.currFollow.ticket = order;
        buyCycle.currFollow.size = osize;
    }
}

/**
 * Open a SELL order
 */
void createSell() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = sellCycle.currFollow.size;
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	
	int order = OrderSend(
        Symbol(), //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        10, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        sellCycle.currFollow.price = oprice;
        sellCycle.currFollow.ticket = order;
        sellCycle.currFollow.size = osize;
    }
}

/**
 * close BUY cycle
 */
void closeBuyCycle(bool in_profit = TRUE) {
    bool stillOpen = TRUE;    
    double bid = MarketInfo(Symbol(), MODE_BID);
    while(stillOpen) {
        if(OrderClose(buyCycle.currFollow.ticket, buyCycle.currFollow.size, bid, 10, clrNONE)) {
            buyCycle.currFollow.ticket = -1;
            
            if(in_profit == FALSE) {
                buyCycle.accum += (bid - buyCycle.currFollow.price) * buyCycle.currFollow.size;
                buyCycle.currFollow.size *= 2;
            }
            else {
                buyCycle.accum = 0;
                buyCycle.currFollow.size = TRADE_SIZE;
            }
            
            stillOpen = FALSE;
        }
    }
}

/**
 * close SELL cycle
 */
void closeSellCycle(bool in_profit = FALSE) {
    bool stillOpen = TRUE;    
    double ask = MarketInfo(Symbol(), MODE_ASK);
    while(stillOpen) {
        if(OrderClose(sellCycle.currFollow.ticket, sellCycle.currFollow.size, ask, 10, clrNONE)) {
            sellCycle.currFollow.ticket = -1;
            sellCycle.accum = 0;
            
            if(in_profit == FALSE) {
                sellCycle.accum += (sellCycle.currFollow.price - ask) * sellCycle.currFollow.size;
                sellCycle.currFollow.size *= 2;
            }
            else {
                sellCycle.accum = 0;
                sellCycle.currFollow.size = TRADE_SIZE;
            }
            
            stillOpen = FALSE;
        }
    }
}