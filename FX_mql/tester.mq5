#property copyright "ALEXANDER FRADIANI"
#property version   "1.00"
#property strict

#define ALL_SYMB_N 28
#define CONCURRENT_TRADES_N 10
#define DAY_TARGET 10

#define UP 1
#define DOWN -1
#define NONE 0

//NECESSARY TO ASSIST IN CONVERSION FROM MQL4
#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11

extern double R_VOL = 0.1;  //Risk Volume. base volume of trades

datetime lastTime;


string defaultPairs[] = {
    "EURUSD.m"  //ONLY FOR BACKTESTING
};

/*
string defaultPairs[] = {
    "AUDCAD.m","AUDCHF.m","AUDJPY.m","AUDNZD.m","AUDUSD.m","CADCHF.m","CADJPY.m",
    "CHFJPY.m","EURAUD.m","EURCAD.m","EURCHF.m","EURGBP.m","EURJPY.m","EURNZD.m",
    "EURUSD.m","GBPAUD.m","GBPCAD.m","GBPCHF.m","GBPJPY.m","GBPNZD.m","GBPUSD.m",
    "NZDCAD.m","NZDCHF.m","NZDJPY.m","NZDUSD.m","USDCAD.m","USDCHF.m","USDJPY.m"
};*/

struct _symbSorter {
    double medBar;
    double movement;
    string symbol;
};
_symbSorter orderedPairs[ALL_SYMB_N];

struct order_t {     //DATA for orders
    ulong ticket;      
    double price;
    double sl;
    double tp;
    int op_type;
    double size;
    string symbol;
};
order_t trades[CONCURRENT_TRADES_N];
int tradeIndex;

double pivot;
double pivotH = 0;
double pivotL = 0;

int pips = 10;
int cycleCount = 0;
int maxCycle = 0;
int currSide = 0;

int fullCycles = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   lastTime = NULL;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
    Print("full cycles: ", fullCycles);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    datetime Time[];
    ArraySetAsSeries(Time, true);
    CopyTime(_Symbol, _Period, 0, 1, Time);
    
    if(lastTime != Time[0]) {
        double bid = MarketInfo(_Symbol, MODE_BID);
        /*if(cycleCount >= 4)
            pips = 30;
        if(cycleCount >= 8)
            pips = 60;*/
        double diff = pips*MarketInfo(_Symbol, MODE_POINT);
        
        if(pivot == 0) {
            pivot = bid;
            pivotH = bid + diff;
            pivotL = bid - diff;
        }
        
        if(bid <= pivotL) {
            if(currSide != DOWN) {
                cycleCount++;
                currSide = DOWN;
                //Print("cycle: ", cycleCount," side DOWN");
            }
            
            if(bid < pivotL - diff) {
                if(cycleCount > maxCycle) {
                    maxCycle = cycleCount;
                    Print("max cycles: ", maxCycle, " date: ", TimeCurrent());
                }
                
                cycleCount = 0;
                currSide = NONE;
                
                pivot = bid;
                pivotH = bid + diff;
                pivotL = bid - diff;
                //Print("new pivot: ", bid);
                fullCycles++;
            }
        }
        
        if(bid >= pivotH) {
            if(currSide != UP) {
                cycleCount++;
                currSide = UP;
                //Print("cycle: ", cycleCount," side UP");
            }
            
            if(bid > pivotH + diff) {
                if(cycleCount > maxCycle) {
                    maxCycle = cycleCount;
                    Print("max cycles: ", maxCycle, " date: ", TimeCurrent());
                }
                
                cycleCount = 0;
                currSide = NONE;
                
                pivot = bid;
                pivotH = bid + diff;
                pivotL = bid - diff;
                //Print("new pivot: ", bid);
                fullCycles++;
            }
        }
        
        if(bid >= pivot && currSide == DOWN) {
            cycleCount++;
            currSide = NONE;
            //Print("cycle: ", cycleCount, " side NONE");
        }
        
        if(bid <= pivot && currSide == UP) {
            cycleCount++;
            currSide = NONE;
            //Print("cycle: ", cycleCount, " side NONE");
        }
        
        lastTime = Time[0];
    }
    
  }
//+------------------------------------------------------------------+


/**
 * Order pairs based on more movement
 */
void orderPairs() {
    //---------------------------------------------------------------Get the movement amount of each pair
    for(int pIndex = 0; pIndex < ALL_SYMB_N; pIndex++) {
        double movUp = 0;
        double movDown = 0;
        double medBar = 0;
        
        for(int i = 1; i <= 100; i++) {
            double open = iOpen(defaultPairs[pIndex], PERIOD_M5, i);
            double high = iHigh(defaultPairs[pIndex], PERIOD_M5, i);
            double low = iLow(defaultPairs[pIndex], PERIOD_M5, i);
            
            movUp += high - open;
            movDown += open - low;
            medBar += high - low;
        }
        
        orderedPairs[pIndex].medBar = medBar / 100;
        orderedPairs[pIndex].symbol = defaultPairs[pIndex];
        orderedPairs[pIndex].movement = (movUp - movDown) / MarketInfo(defaultPairs[pIndex], MODE_POINT);
    }
    
    //---------------------------------------------------------------Order by descending mode
    for(int i = 0; i < ALL_SYMB_N; i++) {
        for(int j = i; j < ALL_SYMB_N; j++) {
            if(MathAbs(orderedPairs[j].movement) > MathAbs(orderedPairs[i].movement)) {
                _symbSorter temp;
                temp.movement = orderedPairs[i].movement;
                temp.medBar = orderedPairs[i].medBar;
                temp.symbol = orderedPairs[i].symbol;
                
                orderedPairs[i].movement = orderedPairs[j].movement;
                orderedPairs[i].medBar = orderedPairs[j].medBar;
                orderedPairs[i].symbol = orderedPairs[j].symbol;
                
                orderedPairs[j].movement = temp.movement;
                orderedPairs[j].medBar = temp.medBar;
                orderedPairs[j].symbol = temp.symbol;
            }
        }
    }
    
    //for(int i = 0; i < ALL_SYMB_N; i++)
        //Print("pairs ordered: ", orderedPairs[i].symbol, " movement: ", orderedPairs[i].movement);
}


/********************************************************************************************************
 * helpers for mql4 style
 */
double MarketInfo(string symbol, int mode) {
    MqlTick tick;
    
    SymbolInfoTick(symbol, tick);
    
    switch(mode) {
        case MODE_ASK:
            return tick.ask;
        case MODE_BID:
            return tick.bid;
        case MODE_POINT:
            return SymbolInfoDouble(symbol, SYMBOL_POINT);
    }
    
    return 0;
}

double iOpen(string symbol, ENUM_TIMEFRAMES tf, int index) {
    if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyOpen(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iClose(string symbol, ENUM_TIMEFRAMES tf, int index) {
    if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyClose(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iHigh(string symbol, ENUM_TIMEFRAMES tf, int index) {
   if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyHigh(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

double iLow(string symbol, ENUM_TIMEFRAMES tf, int index) {
   if(index < 0)
        return(-1);
        
    double Arr[];
    if(CopyLow(symbol, tf, index, 1, Arr) > 0) 
        return Arr[0];
    else 
        return -1;
}

/********************************************************************************************************
 */