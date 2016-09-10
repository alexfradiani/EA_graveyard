//+------------------------------------------------------------------+
//|                                    ALX_v57_M1_AB_MinimalGrid.mq4 |
//+------------------------------------------------------------------+

/**
 * take small movements profit.
 * when price goes against trade, start lot mini-martingale based on a percentual retrace,
 * until price moves enough to collect minimum profit
 */

#property copyright "ALEXANDER FRADIANI"
#property link "http://www.fradiani.com"
#property version   "1.00"
#property strict

#define GRID_Y 10
#define TRADE_SIZE 0.01
#define TARGET 0.1

datetime lastTime;

struct order_t {     //DATA for orders
    int ticket;
    double price;
    int op_type;
    double size;
    string symbol;
    double sl;
};
order_t trades[100];
int pivot;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = Time[0];
    
    pivot = 0;
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
    
    if(pivot == 0) {
        createBuy(TRADE_SIZE);  //FOR TESTING
    }
    else {
        int index = pivot - 1;
        
        if(trades[index].op_type == OP_BUY) {
            if(ask - trades[index].price <= -1*GRID_Y*point) {
                double size = calcNextSize();
                createSell(size);
            }
        }
        
        if(trades[index].op_type == OP_SELL) {
            if(trades[index].price - bid <= -1*GRID_Y*point) {
                double size = calcNextSize();
                createBuy(size);
            }
        }
        
        //verify is accum profit is enough
        double diff = 0;
        for(int i = 0; i < pivot; i++) {
            if(trades[i].op_type == OP_BUY)
                diff += (bid - trades[i].price) * trades[i].size / point;
            else
                diff += (trades[i].price - ask) * trades[i].size / point;
        }
        if(diff >= TARGET) {
            int direction = trades[index].op_type;
            
            closeAllTrades();
            
            //open in direction of trend
            if(direction == OP_BUY)
                createBuy(TRADE_SIZE);
            else
                createSell(TRADE_SIZE);
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * DETERMINE the size of next lot based on grid table
 */
double calcNextSize() {
    double accumLoss = 0;
    double accumPips = 0;
    
    double level_size = TRADE_SIZE;
    for(int i = 1; i <= pivot; i++) {
        accumPips = i * GRID_Y;
        accumLoss += level_size * GRID_Y;
        level_size = accumLoss / (accumPips / 3);
    }
    
    return level_size;
}

/**
 * Open a BUY order
 */
void createBuy(double osize) {
    double point = MarketInfo(Symbol(), MODE_POINT);
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
        trades[pivot].op_type = optype;
        trades[pivot].price = oprice;
        trades[pivot].ticket = order;
        trades[pivot].size = osize;
        
        pivot++;
    }
}

/**
 * Open a SELL order
 */
void createSell(double osize) {
    double point = MarketInfo(Symbol(), MODE_POINT);
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
        trades[pivot].op_type = optype;
        trades[pivot].price = oprice;
        trades[pivot].ticket = order;
        trades[pivot].size = osize;
        
        pivot++;
    }
}

/**
 * close Trades
 */
void closeAllTrades() {
    while(pivot > 0) {
        bool stillOpen = TRUE;    
        int _pivot = pivot - 1;
        
        while(stillOpen) {
            double price = 0;
            if(trades[_pivot].op_type == OP_BUY)
                price = MarketInfo(Symbol(), MODE_BID);
            else
                price = MarketInfo(Symbol(), MODE_ASK);
                
            if(OrderClose(trades[_pivot].ticket, trades[_pivot].size, price, 5, clrNONE)) {
                trades[_pivot].ticket = -1;
                
                pivot--;
                stillOpen = FALSE;
            }
        }
    }
}