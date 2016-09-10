//+------------------------------------------------------------------+
//|                                       ALX_v56_M1_AB_LotFenix.mq4 |
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
    double moneyAccum;
    double pipsAccum;
    int cycleLevel;
    double cycleSize;
};
cycle_t buyCycle, sellCycle;
int priceSide, maDirection;

int cycleLevel;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    
    buyCycle.currFollow.ticket = -1;
    buyCycle.moneyAccum = 0;
    buyCycle.pipsAccum = 0;
    buyCycle.cycleLevel = 0;
    buyCycle.cycleSize = TRADE_SIZE;
    
    sellCycle.currFollow.ticket = -1;
    sellCycle.moneyAccum = 0;
    sellCycle.pipsAccum = 0;
    sellCycle.cycleLevel = 0;
    sellCycle.cycleSize = TRADE_SIZE;
    
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
    double point = MarketInfo(Symbol(), MODE_POINT);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    
    if(buyCycle.currFollow.ticket == -1 && sellCycle.currFollow.ticket == -1) {
        createBuy();
        //createSell();
    }
    
    if(buyCycle.currFollow.ticket != -1) {
        if(bid - buyCycle.currFollow.price >= 10 * point) {
            closeBuyCycle();
            
            buyCycle.moneyAccum += (bid - buyCycle.currFollow.price)*buyCycle.currFollow.size/point;
            if(buyCycle.moneyAccum >= 0) {
                buyCycle.cycleSize = TRADE_SIZE;
                buyCycle.cycleLevel = 0;
            }
            
            createBuy();
        }
        else if(bid - buyCycle.currFollow.price <= -1* 100 * point) {
            buyCycle.cycleLevel++;
            
            buyCycle.moneyAccum += (bid - buyCycle.currFollow.price) * buyCycle.currFollow.size / point;
            buyCycle.cycleSize = NormalizeDouble( MathAbs(buyCycle.moneyAccum)/(buyCycle.cycleLevel * 100 / 3), 2 );
            Print(buyCycle.cycleSize);
            
            closeBuyCycle();
            createBuy();
        }
    }
    /*
    if(sellCycle.currFollow.ticket != -1) {
        if(sellCycle.currFollow.price - ask >= 10 * point) {
            closeSellCycle();
            
            sellCycle.moneyAccum += (sellCycle.currFollow.price - ask)*sellCycle.currFollow.size/point;
            if(sellCycle.moneyAccum >= 0) {
                sellCycle.cycleSize = TRADE_SIZE;
                sellCycle.cycleLevel = 0;
            }
            
            createSell();
        }
        else if(sellCycle.currFollow.price - ask <= -1* 100 * point) {
            sellCycle.cycleLevel++;
            
            sellCycle.moneyAccum += (sellCycle.currFollow.price - ask) * buyCycle.currFollow.size / point;
            sellCycle.cycleSize = NormalizeDouble( MathAbs(sellCycle.moneyAccum)/(sellCycle.cycleLevel * 100 / 3), 2 );
            
            closeSellCycle();
            createSell();
        }
    }*/
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Open a BUY order
 */
void createBuy() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double osize = buyCycle.cycleSize;
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
    double osize = sellCycle.cycleSize;
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
            
            stillOpen = FALSE;
        }
    }
}