//+------------------------------------------------------------------+
//|                                     ALX_v54_M1_BollingerGrid.mq4 |
//+------------------------------------------------------------------+

/**
 * play direction of trend.
 * use bollinger tops and bottoms.
 * controlled martingale to improve winning rate
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
    int followsCount;
    double accum;
};
cycle_t buyCycle, sellCycle;
int priceSide, maDirection;
double cycleSize, cycleAccum;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    
    buyCycle.currFollow.ticket = -1;
    buyCycle.followsCount = 0;
    buyCycle.accum = 0;
    
    sellCycle.currFollow.ticket = -1;
    sellCycle.followsCount = 0;
    sellCycle.accum = 0;
    
    cycleAccum = 0;
    cycleSize = TRADE_SIZE;
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
    
    double m5_0 = iMA(Symbol(), PERIOD_M1, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
    double m5_1 = iMA(Symbol(), PERIOD_M1, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    if(m5_0 > m5_1)
        maDirection = UP;
    else if(m5_0 < m5_1)
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
    
    if(priceSide == UP && maDirection == DOWN && bid < upThreshold && bid > middleBand)
        if(sellCycle.currFollow.ticket == -1 && buyCycle.currFollow.ticket == -1)
            createSell();
    
    if(priceSide == DOWN && maDirection == UP && bid > downThreshold && bid < middleBand)
        if(sellCycle.currFollow.ticket == -1 && buyCycle.currFollow.ticket == -1)
            createBuy();
   
    //------------------------------------------------------------------------------------------- CLOSEs
    if(cycleSize > TRADE_SIZE) {
        if(buyCycle.currFollow.ticket != -1) {
            if(cycleAccum + (bid - buyCycle.currFollow.price)*cycleSize >= 0)
                closeBuyCycle(TRUE);
        }
        
        if(sellCycle.currFollow.ticket != -1) {
            if(cycleAccum + (sellCycle.currFollow.price - ask)*cycleSize >= 0)
                closeSellCycle(TRUE);
        }    
    }
    else {
        if(buyCycle.currFollow.ticket != -1) {
            if(bid >= upThreshold)
                closeBuyCycle(TRUE);
        }
        
        if(sellCycle.currFollow.ticket != -1) {
            if(ask <= downThreshold)
                closeSellCycle(TRUE);
        }
    }
    
    //STOP LOSSES
    if(buyCycle.currFollow.ticket != -1) {
        if(bid - buyCycle.currFollow.price <= -1*GRID_Y * point)
            closeBuyCycle(FALSE);
    }
    
    if(sellCycle.currFollow.ticket != -1) {
        if(sellCycle.currFollow.price - ask <= -1*GRID_Y * point)
            closeSellCycle(FALSE);
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Open a BUY order
 */
void createBuy() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = cycleSize;
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
    double osize = cycleSize;
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
                cycleAccum += (bid - buyCycle.currFollow.price) * cycleSize;
                cycleSize *= 2;
            }
            else {
                cycleAccum = 0;
                cycleSize = TRADE_SIZE;
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
            sellCycle.followsCount = 0;
            
            if(in_profit == FALSE) {
                cycleAccum += (sellCycle.currFollow.price - ask) * cycleSize;
                cycleSize *= 2;
            }
            else {
                cycleAccum = 0;
                cycleSize = TRADE_SIZE;
            }
            
            stillOpen = FALSE;
        }
    }
}