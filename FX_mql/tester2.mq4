//+------------------------------------------------------------------+
//|                                                           tester |
//+------------------------------------------------------------------+

#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define ALL_SYMB_N 28
#define MAX_TRADES 1
#define RISK_LIMIT 1
#define PIP_TARGET 10
#define INIT_SIZE 0.01

#define UP 1
#define DOWN -1
#define NONE 0

#define TRADE_SIZE 0.09
#define MONEY_TARGET 8.33333
#define MONEY_MAX_RISK 1000

#define GRID_Y 100

#define SLIPPAGE 10

datetime lastTime;

//Group of pairs to take the 8 pairs for every main currency with more movement
struct _pairGroup {
    string main;
    string pairs[7];
};
_pairGroup pairGroups[8];

string Mains[8] = {"USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "NZD"};
double orderedMains[8][2];

string suffix = "";
/*string defaultPairs[] = {
    "CADCHF"
};*/
string defaultPairs[28] = {
    "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY",
    "CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD",
    "EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD",
    "NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"
};


double BaseStr[8]; //strenghts of the main currencies
double pstrengths[28]; //strengths of all pais

struct _symbSorter {
    double medBar;
    double movement;
    string symbol;
};
//_symbSorter orderedPairs[ALL_SYMB_N];

struct _ordererdPair {
    string symbol;
    double movement;
};
_ordererdPair orderedPairs[28];

struct order_t {     //DATA for orders
    int ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
    string symbol;
    datetime time;
};
struct gale_trade_t {
    int cycleIndex;
    order_t orders[15];
};

gale_trade_t trades[MAX_TRADES];
int tradeIndex;

order_t buyOrder;
order_t sellOrder;

int priceSide = UP;

int bars;
int maxBars;

int zz_confirm = 0;
int zz_direction = NONE;

int stochSide = NONE;
bool enableTrigger = TRUE;

int shortMA, dayMA;

int currentDay;
double dayMovUp, dayMovDown;
datetime lastBar;

bool inLondonSession = FALSE;
bool dayAvailable = TRUE;

int londonOpen, nyOpen;

int ranges[100];

double pivot;
int countedDays, rangeDays;
bool rangeDone;

int trys;
int tryArray[30];

double tradePivot = 0.0;
int tradeType = -99;

int oIndex = 0;
order_t tradeA, tradeB;

#define TARGET 2

double accum;
bool no_trading = FALSE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    
    tradeA.ticket = -1;
    tradeB.ticket = -1;
    tradeA.size = 0.01;
    tradeB.size = 0.01;
    
    accum = 0;
    
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    double tradeA_float = 0.0;
    if(tradeA.ticket != -1) {
        if(tradeA.op_type == OP_BUY)
                tradeA_float = (bid - tradeA.price) / point * tradeA.size;
            else
                tradeA_float = (tradeA.price - ask) / point * tradeA.size;
    }
    double tradeB_float = 0.0;
    if(tradeB.ticket != -1) {
        if(tradeB.op_type == OP_BUY)
                tradeB_float = (bid - tradeB.price) / point * tradeB.size;
            else
                tradeB_float = (tradeB.price - ask) / point * tradeB.size;
    }
    
    double floating = tradeA_float + tradeB_float;
    
    if(accum + floating >= TARGET) {
        no_trading = TRUE;
        if(tradeA.ticket != -1) {
            if(tradeA.op_type == OP_BUY)
                closeBuy("A");
            else
                closeSell("A");
        }
        if(tradeB.ticket != -1) {
            if(tradeB.op_type == OP_BUY)
                closeBuy("B");
            else
                closeSell("B");
        }
    }
    
    if(no_trading == TRUE)
        return;
    
    //---------------------------------------------------------------------- TRADE A manages
    if(tradeA.ticket == -1) {
        int op = getRandomOp();
        if(op == OP_BUY) {
            createBuy("A");
            createSell("B");
        }
        else {
            createSell("A");
            createBuy("B");
        }
    }
    if(tradeA.op_type == OP_BUY) {
        if(bid - tradeA.price >= GRID_Y * point) {
            closeBuy("A");
            closeSell("B");
            if(tradeA.size > 0.01)
                tradeA.size -= 0.01;
            
            tradeB.size += 0.01;
            
            int op = getRandomOp();
            if(op == OP_BUY) {
                createBuy("A");
                createSell("B");
            }
            else {
                createSell("A");
                createBuy("B");
            }
        }
        else if(bid - tradeA.price <= -1* GRID_Y * point) {
            closeBuy("A");
            closeSell("B");
            
            tradeA.size += 0.01;
             if(tradeB.size > 0.01)
                tradeB.size -= 0.01;
            
            int op = getRandomOp();
            if(op == OP_BUY) {
                createBuy("A");
                createSell("B");
            }
            else {
                createSell("A");
                createBuy("B");
            }
        }
    }    
    else {
        if(tradeA.price - ask >= GRID_Y * point) {
            closeSell("A");
            closeBuy("B");
            
            tradeB.size += 0.01;
            if(tradeA.size > 0.01)
                tradeA.size -= 0.01;
            
            int op = getRandomOp();
            if(op == OP_BUY) {
                createBuy("A");
                createSell("B");
            }
            else {
                createSell("A");
                createBuy("B");
            }
        }
        else if(tradeA.price - ask <= -1* GRID_Y * point) {
            closeSell("A");
            closeBuy("B");
            
            tradeA.size += 0.01;
            if(tradeB.size > 0.01)
                tradeB.size -= 0.01;
            
            int op = getRandomOp();
            if(op == OP_BUY) {
                createBuy("A");
                createSell("B");
            }
            else {
                createSell("A");
                createBuy("B");
            }
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

int getRandomOp() {
    //random value
    datetime t = TimeCurrent();
    int h = TimeHour(t);
    int m = TimeMinute(t);
    int s = TimeSeconds(t);
    
    if( (h+m+s)%2 > 0 )
        return OP_SELL;
    else
        return OP_BUY;
}

void createBuy(string trade) {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

    double osize;
    if(trade == "A")
        osize = tradeA.size;
    else
        osize = tradeB.size;

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(trade == "A") {
            tradeA.ticket = ticket;
            tradeA.op_type = optype;
            tradeA.price = oprice;
            tradeA.size = osize;
            tradeA.symbol = symbol;
        }
        else {
            tradeB.ticket = ticket;
            tradeB.op_type = optype;
            tradeB.price = oprice;
            tradeB.size = osize;
            tradeB.symbol = symbol;
        }
    }
}

void createSell(string trade) {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

    double osize;
    if(trade == "A")
        osize = tradeA.size;
    else
        osize = tradeB.size;

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(trade == "A") {
            tradeA.ticket = ticket;
            tradeA.op_type = optype;
            tradeA.price = oprice;
            tradeA.size = osize;
            tradeA.symbol = symbol;
        }
        else {
            tradeB.ticket = ticket;
            tradeB.op_type = optype;
            tradeB.price = oprice;
            tradeB.size = osize;
            tradeB.symbol = symbol;
        }
    }
}

bool closeBuy(string trade) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double point = MarketInfo(symbol, MODE_POINT);
    
    bool closed = FALSE;
    if(trade == "A")
        closed = OrderClose(tradeA.ticket, tradeA.size, bid, SLIPPAGE, clrNONE);
    else
        closed = OrderClose(tradeB.ticket, tradeB.size, bid, SLIPPAGE, clrNONE);
    if(closed) {
        if(trade == "A") {
            tradeA.ticket = -1;
            accum += (bid - tradeA.price) * tradeA.size / point;
        }
        else {
            tradeB.ticket = -1;
            accum += (bid - tradeB.price) * tradeB.size / point;
        }
    }
    
    return closed;
}

bool closeSell(string trade) {
    string symbol = Symbol();
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(symbol, MODE_POINT);
    
    bool closed = FALSE;
    if(trade == "A")
        closed = OrderClose(tradeA.ticket, tradeA.size, ask, SLIPPAGE, clrNONE);
    else
        closed = OrderClose(tradeB.ticket, tradeB.size, ask, SLIPPAGE, clrNONE);
    if(closed) {
        if(trade == "A") {
            tradeA.ticket = -1;
            accum += (tradeA.price - ask) * tradeA.size / point;
        }
        else {
            tradeB.ticket = -1;
            accum += (tradeB.price - ask) * tradeB.size / point;
        }
    }
    
    return closed;
}