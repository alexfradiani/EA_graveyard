//+------------------------------------------------------------------+
//|                                         ALX_v51_H1_TrendSoul.mq4 |
//+------------------------------------------------------------------+

#property copyright "ALEXANDER FRADIANI"
#property link "http://www.fradiani.com"
#property version   "1.00"
#property strict

#define RISKSL 10000
#define TRADE_SIZE 0.01
#define CYCLE_TARGET 100

#define UP 1
#define DOWN -1
#define NONE 0

datetime lastTime;

struct order_t {     //DATA for orders
    int ticket;
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
    string symbol;
};
order_t trades[100];
int tradeIndex;

double cycleAccum;
int currOp;
int barUsed;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    cycleAccum = 0;
    currOp = -99;
    tradeIndex = 0;
    barUsed = 0;
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
    //read MA
    double ma = iMA(Symbol(), PERIOD_H1, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
    double maPrev = iMA(Symbol(), PERIOD_H1, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
    
    double point = MarketInfo(Symbol(), MODE_POINT);
    if(lastTime != Time[0]) {
        if(tradeIndex > 0) {
            int ci = tradeIndex - 1;
            
            //Check close of winning trade
            if(trades[ci].op_type == OP_BUY) {
                if(Bid - trades[ci].price > 50*point) {
                    closeLastOrder();
                }
            }
            else {
                if(trades[ci].price - Ask > 50*point) {
                    closeLastOrder();
                }
            }
        }
        
        if(ma > maPrev && currOp != OP_BUY) //time to create a BUY
            ;//createBuy();
        
        if(ma < maPrev && currOp != OP_SELL) //time to create a SELL
            ;//createSell();
        
        lastTime = Time[0];
    }
    
    double rtAccum = 0;
    for(int i = 0; i < tradeIndex; i++) {
        if(trades[i].op_type == OP_BUY)
            rtAccum += Bid - trades[i].price;
        else
            rtAccum += trades[i].price - Ask;
    }
    
    if(tradeIndex > 1) {  //cycle existing
        if(rtAccum + cycleAccum > CYCLE_TARGET * point)
            closeCycle();
    }
    if(rtAccum <= -1 * RISKSL * point)
        closeCycle();
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Open a BUY order
 */
void createBuy() {
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
	double osize = TRADE_SIZE;
	
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
        trades[tradeIndex].symbol = Symbol();
        trades[tradeIndex].op_type = optype;
        trades[tradeIndex].price = oprice;
        trades[tradeIndex].ticket = order;
        trades[tradeIndex].size = osize;
        
        currOp = OP_BUY;
        tradeIndex++;
    }
}

/**
 * Open a SELL order
 */
void createSell() {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double osize = TRADE_SIZE;
	
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
        trades[tradeIndex].symbol = Symbol();
        trades[tradeIndex].op_type = optype;
        trades[tradeIndex].price = oprice;
        trades[tradeIndex].ticket = order;
        trades[tradeIndex].size = osize;
        
        currOp = OP_SELL;
        tradeIndex++;
    }
}

/**
 * Close last order
 */
void closeLastOrder() {
    int ci = tradeIndex - 1;
    double price;
    if(trades[ci].op_type == OP_BUY)
        price = MarketInfo(Symbol(), MODE_BID);
    else
        price = MarketInfo(Symbol(), MODE_ASK);
    
    bool stillOpen = TRUE;    
    while(stillOpen) {
        if(OrderClose(trades[ci].ticket, trades[ci].size, price, 10, clrNONE)) {
            trades[ci].ticket = -1;
            
            //accumulate
            if(trades[ci].op_type == OP_BUY)
                cycleAccum += Bid - trades[ci].price;
            else
                cycleAccum += trades[ci].price - Ask;
            
            tradeIndex--;
            currOp = -99;
            if(tradeIndex == 0)
                cycleAccum = 0;
        
            stillOpen = FALSE;
        }
    }
}

/**
 * close cycle of trades when profit is enough
 */
void closeCycle() {
    Print("closing cycle");
    bool tradesOpened = TRUE;
    
    while(tradesOpened) {
        closeLastOrder();
        if(tradeIndex == 0)
            tradesOpened = FALSE;
    }
}