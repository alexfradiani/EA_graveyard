//+------------------------------------------------------------------+
//|                                         ALX_v52_M1_TrendGrid.mq4 |
//+------------------------------------------------------------------+

/**
 * Grid trending.
 * play direction of trend.
 */

#property copyright "ALEXANDER FRADIANI"
#property link "http://www.fradiani.com"
#property version   "1.00"
#property strict

#define GRID_Y 333
#define TRADE_SIZE 0.01
#define TARGET 33
#define RISKSTOP 100  //in money

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
cycle_t peakBuyCycle, peakSellCycle;
cycle_t rootBuyCycle, rootSellCycle;
int priceMov8H, priceMov4H;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    
    peakBuyCycle.accum = 0;
    peakBuyCycle.followsCount = 0;
    rootBuyCycle.accum = 0;
    rootBuyCycle.followsCount = 0;
    
    peakSellCycle.accum = 0;
    peakSellCycle.followsCount = 0;
    rootSellCycle.accum = 0;
    rootSellCycle.followsCount = 0;
    
    priceMov4H = priceMov8H = NONE;
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
    //read Long term MA
    double hma8 = iMA(Symbol(), PERIOD_M1, 480, 0, MODE_SMA, PRICE_CLOSE, 0);
    double hma4 = iMA(Symbol(), PERIOD_M1, 240, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    double m3 = iMA(Symbol(), PERIOD_M1, 3, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    double point = MarketInfo(Symbol(), MODE_POINT);
    if(lastTime != Time[0]) {
        int prevPriceMov4H = priceMov4H;
        int prevPriceMov8H = priceMov8H;
        
        if(m3 < hma8)
            priceMov8H = DOWN;
        if(m3 > hma8)
            priceMov8H = UP;
        if(m3 < hma4)
            priceMov4H = DOWN;
        if(m3 > hma4)
            priceMov4H = UP;
        
        //------------------------------------------------------------------------------ trigger of root orders
        if(prevPriceMov4H < priceMov4H && rootBuyCycle.followsCount == 0)
            createRootBuy();
        if(prevPriceMov8H < priceMov8H && rootBuyCycle.followsCount == 0)
            createRootBuy();
            
        if(prevPriceMov4H > priceMov4H && rootSellCycle.followsCount == 0)
            createRootSell();
        if(prevPriceMov8H > priceMov8H && rootSellCycle.followsCount == 0)
            createRootSell();
          
        //------------------------------------------------------------------------------ trigger of peak orders
        if(prevPriceMov4H == priceMov4H && priceMov4H == UP)
            if(rootBuyCycle.followsCount == 0 && peakBuyCycle.followsCount == 0)
                createPeakBuy();
        if(prevPriceMov8H == priceMov8H && priceMov8H == UP)
            if(rootBuyCycle.followsCount == 0 && peakBuyCycle.followsCount == 0)
                createPeakBuy();
        
        if(prevPriceMov4H == priceMov4H && priceMov4H == DOWN)
            if(rootSellCycle.followsCount == 0 && peakSellCycle.followsCount == 0)
                createPeakSell();
        if(prevPriceMov8H == priceMov8H && priceMov8H == DOWN)
            if(rootSellCycle.followsCount == 0 && peakSellCycle.followsCount == 0)
                createPeakSell();
        
        //------------------------------------------------------------------------------ close profits
        if(rootBuyCycle.followsCount == 1) {
            if(Bid - rootBuyCycle.currFollow.price >= TARGET*point)
                closeRootBuyCycle();
        }
        if(rootSellCycle.followsCount == 1) {
            if(rootSellCycle.currFollow.price - Ask >= TARGET*point)
                closeRootSellCycle();
        }
        
        if(peakBuyCycle.followsCount == 1) {
            if(Bid - peakBuyCycle.currFollow.price >= TARGET*point)
                closePeakBuyCycle();
        }
        if(peakSellCycle.followsCount == 1) {
            if(peakSellCycle.currFollow.price - Ask >= TARGET*point)
                closePeakSellCycle();
        }
        
        lastTime = Time[0];
    }
    
    //Check if new follows need to be created, or closed.
    //------------------------------------------------------------------------------------------- root
    if(rootBuyCycle.followsCount > 0) {
        double currAccum = (Bid - rootBuyCycle.currFollow.price) * rootBuyCycle.currFollow.size/point;
        if(currAccum + rootBuyCycle.accum >= TRADE_SIZE * TARGET)
            closeRootBuyCycle();
        else if(currAccum + rootBuyCycle.accum < -1*RISKSTOP)
            closeRootBuyCycle();
        else if(Bid - rootBuyCycle.currFollow.price <= -1*GRID_Y*point)
            createRootBuy();
    }
    
    if(rootSellCycle.followsCount > 0) {
        double currAccum = (rootSellCycle.currFollow.price - Ask) * rootSellCycle.currFollow.size/point;
        if(currAccum + rootSellCycle.accum >= TRADE_SIZE * TARGET)
            closeRootSellCycle();
        else if(currAccum + rootSellCycle.accum <= -1*RISKSTOP)
            closeRootSellCycle();
        else if(rootSellCycle.currFollow.price - Ask <= -1*GRID_Y*point)
            createRootSell();
    }
    
    //------------------------------------------------------------------------------------------- peaks
    if(peakBuyCycle.followsCount > 0) {
        double currAccum = (Bid - peakBuyCycle.currFollow.price) * peakBuyCycle.currFollow.size/point;
        if(currAccum + peakBuyCycle.accum >= TRADE_SIZE * TARGET)
            closePeakBuyCycle();
        else if(currAccum + peakBuyCycle.accum < -1*RISKSTOP)
            closePeakBuyCycle();
        else if(Bid - peakBuyCycle.currFollow.price <= -1*GRID_Y*point)
            createPeakBuy();
    }
    
    if(peakSellCycle.followsCount > 0) {
        double currAccum = (peakSellCycle.currFollow.price - Ask) * peakSellCycle.currFollow.size/point;
        if(currAccum + peakSellCycle.accum >= TRADE_SIZE * TARGET)
            closePeakSellCycle();
        else if(currAccum + peakSellCycle.accum <= -1*RISKSTOP)
            closePeakSellCycle();
        else if(peakSellCycle.currFollow.price - Ask <= -1*GRID_Y*point)
            createPeakSell();
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Open a ROOT BUY order
 */
void createRootBuy() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = TRADE_SIZE;
    
    if(rootBuyCycle.followsCount > 0) {
        bool stillOpen = TRUE;    
        while(stillOpen) {
            if(OrderClose(rootBuyCycle.currFollow.ticket, rootBuyCycle.currFollow.size, Bid, 10, clrNONE)) {
                rootBuyCycle.accum += (Bid - rootBuyCycle.currFollow.price) * rootBuyCycle.currFollow.size/point;
                stillOpen = FALSE;
            }
        }   
        
        osize = rootBuyCycle.currFollow.size * 2;  
    }
    
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
        rootBuyCycle.followsCount++;
        
        rootBuyCycle.currFollow.price = oprice;
        rootBuyCycle.currFollow.ticket = order;
        rootBuyCycle.currFollow.size = osize;
    }
}

/**
 * Open a PEAK BUY order
 */
void createPeakBuy() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = TRADE_SIZE;
    
    if(peakBuyCycle.followsCount > 0) {
        bool stillOpen = TRUE;    
        while(stillOpen) {
            if(OrderClose(peakBuyCycle.currFollow.ticket, peakBuyCycle.currFollow.size, Bid, 10, clrNONE)) {
                peakBuyCycle.accum += (Bid - peakBuyCycle.currFollow.price) * peakBuyCycle.currFollow.size/point;
                stillOpen = FALSE;
            }
        }   
        
        osize = peakBuyCycle.currFollow.size * 2;  
    }
    
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
        peakBuyCycle.followsCount++;
        
        peakBuyCycle.currFollow.price = oprice;
        peakBuyCycle.currFollow.ticket = order;
        peakBuyCycle.currFollow.size = osize;
    }
}

/**
 * Open a ROOT SELL order
 */
void createRootSell() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = TRADE_SIZE;
    
    if(rootSellCycle.followsCount > 0) {
        bool stillOpen = TRUE;    
        while(stillOpen) {
            if(OrderClose(rootSellCycle.currFollow.ticket, rootSellCycle.currFollow.size, Ask, 10, clrNONE)) {
                rootSellCycle.accum += (rootSellCycle.currFollow.price - Ask) * rootSellCycle.currFollow.size/point;
                stillOpen = FALSE;
            }
        }   
        
        osize = rootSellCycle.currFollow.size * 2;  
    }
    
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
        rootSellCycle.followsCount++;
        
        rootSellCycle.currFollow.price = oprice;
        rootSellCycle.currFollow.ticket = order;
        rootSellCycle.currFollow.size = osize;
    }
}

/**
 * Open a PEAK SELL order
 */
void createPeakSell() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = TRADE_SIZE;
    
    if(peakSellCycle.followsCount > 0) {
        bool stillOpen = TRUE;    
        while(stillOpen) {
            if(OrderClose(peakSellCycle.currFollow.ticket, peakSellCycle.currFollow.size, Ask, 10, clrNONE)) {
                peakSellCycle.accum += (peakSellCycle.currFollow.price - Ask) * peakSellCycle.currFollow.size/point;
                stillOpen = FALSE;
            }
        }   
        
        osize = peakSellCycle.currFollow.size * 2;  
    }
    
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
        peakSellCycle.followsCount++;
        
        peakSellCycle.currFollow.price = oprice;
        peakSellCycle.currFollow.ticket = order;
        peakSellCycle.currFollow.size = osize;
    }
}

/**
 * close ROOT BUY cycle
 */
void closeRootBuyCycle() {
    bool stillOpen = TRUE;    
    while(stillOpen) {
        if(OrderClose(rootBuyCycle.currFollow.ticket, rootBuyCycle.currFollow.size, Bid, 10, clrNONE)) {
            rootBuyCycle.accum = 0;
            rootBuyCycle.followsCount = 0;
            stillOpen = FALSE;
        }
    }
}

/**
 * close ROOT SELL cycle
 */
void closeRootSellCycle() {
    bool stillOpen = TRUE;    
    while(stillOpen) {
        if(OrderClose(rootSellCycle.currFollow.ticket, rootSellCycle.currFollow.size, Ask, 10, clrNONE)) {
            rootSellCycle.accum = 0;
            rootSellCycle.followsCount = 0;
            stillOpen = FALSE;
        }
    }
}

/**
 * close PEAK BUY cycle
 */
void closePeakBuyCycle() {
    bool stillOpen = TRUE;    
    while(stillOpen) {
        if(OrderClose(peakBuyCycle.currFollow.ticket, peakBuyCycle.currFollow.size, Bid, 10, clrNONE)) {
            peakBuyCycle.accum = 0;
            peakBuyCycle.followsCount = 0;
            stillOpen = FALSE;
        }
    }
}

/**
 * close PEAK SELL cycle
 */
void closePeakSellCycle() {
    bool stillOpen = TRUE;    
    while(stillOpen) {
        if(OrderClose(peakSellCycle.currFollow.ticket, peakSellCycle.currFollow.size, Ask, 10, clrNONE)) {
            peakSellCycle.accum = 0;
            peakSellCycle.followsCount = 0;
            stillOpen = FALSE;
        }
    }
}