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
};
struct gale_trade_t {
    int cycleIndex;
    order_t orders[15];
};

gale_trade_t trades[MAX_TRADES];
int tradeIndex;

order_t buyOrder;
order_t sellOrder;

int priceSide = NONE;

int bars;
int maxBars;

int zz_confirm = 0;
int zz_direction = NONE;

int stochSide = NONE;
bool enableTrigger = TRUE;

int shortMA, dayMA;

//DATA for trade cycle
struct cycle_t {
    order_t orders[10];
    double accum;
    int index;
    int day;
};
cycle_t trade;

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
    lastTime = NULL;
    tradeIndex = 0;
    
    priceSide = NONE;
    
    currentDay = -1;
    trade.index = 0;
    
    for(int i = 0; i < ArraySize(ranges); i++)
        ranges[i] = 0;
    
    lastBar = Time[0];
    inLondonSession = FALSE;
    countedDays = rangeDays = 0;
    
    //orderPairs();
    //currency_strength("EUR");
    //EventSetTimer(60);
    ////Print("timer set");
//---
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
    lastTime = NULL;
    tradeIndex = 0;
    
    int total = 0;
    for(int i = 0; i < ArraySize(ranges); i++)
        total += ranges[i];
    
    int accum = 0;
    for(int i = 0; i < ArraySize(ranges); i++) {
        accum += ranges[i];
        Print("days under ", (i+1)*100, " range: ", ranges[i], " / accum.%: ", NormalizeDouble(accum*100/total, 2));
    }
    Print("total days: ", total);
    
    /*Print("Counted days: ", countedDays, " range days: ", rangeDays);
    
    for(int i = 1; i < ArraySize(tryArray); i++) {
        Print("ocurrency for ", i, " tries: ", tryArray[i]);
    }*/
//---
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
    /*
    //---------------------------------------------------------------------------------- TIME metric and trade rules
    datetime currentTime = TimeCurrent();
    int h = TimeHour(currentTime);
    
    //LONDON session accumulation
    if(h >= londonOpen && h < nyOpen) {
        inLondonSession = TRUE;
        
        if(lastBar != Time[0]) {
            double open = iOpen(Symbol(), PERIOD_M1, 1);
            double high = iHigh(Symbol(), PERIOD_M1, 1);
            double low = iLow(Symbol(), PERIOD_M1, 1);
            
            dayMovUp += high - open;
            dayMovDown += open - low;
        }
    }
    else
        inLondonSession = FALSE;
    
    //After NYO
    if(h >= nyOpen) {
        Comment(dayMovUp - dayMovDown);
        
        if(dayAvailable == TRUE && isTradingDay() == TRUE)
            if(trade.index == 0) {  //create day trade
                if(dayMovUp - dayMovDown > 0)
                    createBuy(TRADE_SIZE);
                else if(dayMovUp - dayMovDown < 0)
                    createSell(TRADE_SIZE);
                    
                dayAvailable = FALSE;
            }
    }
    
    if(lastBar != Time[0])
        lastBar = Time[0];
    
    //New Day, reset counter
    if(currentDay != TimeDay(currentTime)) {
        dayMovUp = 0;
        dayMovDown = 0;
        currentDay = TimeDay(currentTime);
        dayAvailable = TRUE;
        
        adjustGMTOpenings();
    }
    
    //---------------------------------------------------------------------------------- TRADE MANAGEMENT
    double point = MarketInfo(Symbol(), MODE_POINT);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    
    if(trade.index > 0) {
        double trade_price = trade.orders[trade.index - 1].price;
        double trade_size = trade.orders[trade.index - 1].size;
    
        if(trade.orders[trade.index - 1].op_type == OP_BUY) {  //CASE BUY
            double current_profit = (bid - trade_price) / point * trade_size;
            
            calculateAccum();
            
            if(current_profit + trade.accum >= MONEY_TARGET) {  //TAKE PROFITS
                ////Print("close by profit");
                closeTrade();
            }
            
            if(bid - trade_price <= -1 * GRID_Y * point) { //martingale increase
                createSell(trade_size * 2);
            }
            
            if(current_profit + trade.accum <= -1 * MONEY_MAX_RISK) {  //stop at max risk
                ////Print("close by max risk");
                closeTrade(); //MAX LOSS
            }
            
            //if(currentDay != trade.day && inLondonSession == TRUE)  //stop at expiration
            //    closeTrade();
        }
        
        if(trade.index > 0 && trade.orders[trade.index - 1].op_type == OP_SELL) {  //CASE SELL
            double current_profit = (trade_price - ask) / point * trade_size;
            
            calculateAccum();
            
            if(current_profit + trade.accum >= MONEY_TARGET) {  //TAKE PROFITS
                ////Print("curr profit ", current_profit);
                ////Print("total ", current_profit + trade.accum);
                ////Print("close by profit");
                closeTrade();
            }
            
            if(trade_price - ask <= -1 * GRID_Y * point) { //martingale increase
                createBuy(trade_size * 2);
            }
            
            if(current_profit + trade.accum <= -1 * MONEY_MAX_RISK) {  //stop at max risk
                ////Print("close by max risk");
                closeTrade(); //MAX LOSS
            }
            
            //if(currentDay != trade.day && inLondonSession == TRUE)  //stop at expiration
            //    closeTrade();
        }
    } */
    
    datetime currentTime = TimeCurrent();
    if(currentDay != TimeDay(currentTime)) {
        if(isTradingDay() == TRUE) {
            for(int i = 100; i <= 3000; i += 100) {
                double point = MarketInfo(Symbol(), MODE_POINT);
                double range = (iHigh(Symbol(), PERIOD_D1, 1) - iLow(Symbol(), PERIOD_D1, 1)) / point;
                if(range >= i-100 && range <= i - 1) {
                    ranges[i/100 - 1]++;
                    
                    if(i == 100 || i == 200)
                        Print("low day range: ", Time[0]);
                }
            }
                
            currentDay = TimeDay(currentTime);
        }
    }  
    /*
    double point = MarketInfo(Symbol(), MODE_POINT);
    if(lastTime != Time[0]) {
        if(MathAbs(Open[1] - Close[1]) >= 50*point)
            Print("Extreme movement: ", Time[0]);
        
        lastTime = Time[0];
    } */
    
    //datetime currentTime = TimeCurrent();
    
    if(isTradingDay() == TRUE) {
        double point = MarketInfo(Symbol(), MODE_POINT);
        if(lastBar != Time[0]) {
        
            adjustGMTOpenings();
        
            if(currentDay != TimeDay(currentTime)) {
                inLondonSession = FALSE;
                
                /*if(rangeDone == FALSE)
                    Print(Time[0], " - day without range");*/
                
                rangeDone = FALSE;
                
                pivot = 0.0;
                
                countedDays++;
                currentDay = TimeDay(currentTime);
            }
            
            int h = TimeHour(currentTime);
            if(h >= londonOpen) {
                if(inLondonSession == FALSE) {
                    pivot = Open[0];
                    tradePivot = pivot;
                    trys = 0;
                    Print("pivot set to: ", pivot);
                }
                
                inLondonSession = TRUE;
            }
            
            //check range
            if(pivot > 0) {
            
                if(Bid - tradePivot >= 60*point && (tradeType == -99 || tradeType == OP_SELL)) {
                    trys++;
                    tradePivot = Bid;
                    tradeType = OP_BUY;
                }
                
                if(tradePivot - Bid >= 60*point && (tradeType == -99 || tradeType == OP_BUY)) {
                    trys++;
                    tradePivot = Bid;
                    tradeType = OP_SELL;
                }
            
                if(MathAbs(iHigh(Symbol(), PERIOD_M1, 1) - pivot) >= 400*point && rangeDone == FALSE) {
                    rangeDays++;
                    rangeDone = TRUE;
                    
                    tradeType = 0;
                    tradePivot = 0;
                    
                    tryArray[trys]++;
                    trys = 0;
                }
                if(MathAbs(iLow(Symbol(), PERIOD_M1, 1) - pivot) >= 400*point && rangeDone == FALSE) {
                    rangeDays++;
                    rangeDone = TRUE;
                    
                    tradeType = -99;
                    tradePivot = 0;
                    
                    tryArray[trys]++;
                    trys = 0;
                }
            }
            double mvmt = 0;
            if(iHigh(Symbol(), PERIOD_M1, 1) > pivot)
                mvmt = (iHigh(Symbol(), PERIOD_M1, 1) - pivot) / point;
            else if(iLow(Symbol(), PERIOD_M1, 1) < pivot)
                mvmt = (pivot - iLow(Symbol(), PERIOD_M1, 1)) / point;
            
            string msg = "Counted days: " + countedDays + " range days: " + rangeDays; 
            msg += " [current pivot: " + DoubleToStr(pivot, 5) + " mvmt: " + NormalizeDouble(mvmt,0) + "] \n";
            msg += "currentDay: " + currentDay;
            Comment(msg);    
            lastBar = Time[0];
        }
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Mondays and Fridays excluded from trading.
 * statistically these days are usually consolidation, no strong trend direction.
 */
bool isTradingDay() {
    datetime t = TimeCurrent();
    
    int wday = TimeDayOfWeek(t);
    if(wday >= 2 && wday <= 4)  //tuesday to thursday
        return TRUE;
    else
        return FALSE;
}

/**
 * Adjust London and New York time switch during winter and summer
 */
void adjustGMTOpenings() {
    datetime t = TimeCurrent();
    
    int year = TimeYear(t);
    int month = TimeMonth(t);
    int day = TimeDay(t);
    switch(year) {
        case 2010:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 28)) && (month < 10 || (month == 10 && day < 31 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 14)) && (month < 11 || (month == 11 && day < 7 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2011:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 27)) && (month < 10 || (month == 10 && day < 30 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 13)) && (month < 11 || (month == 11 && day < 6 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2012:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 25)) && (month < 10 || (month == 10 && day < 28 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 11)) && (month < 11 || (month == 11 && day < 4 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2013:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 31)) && (month < 10 || (month == 10 && day < 27 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 10)) && (month < 11 || (month == 11 && day < 3 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2014:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 30)) && (month < 10 || (month == 10 && day < 26 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 9)) && (month < 11 || (month == 11 && day < 2 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        case 2015:
            //london offset
            if( (month >= 4 || (month == 3 && day >= 29)) && (month < 10 || (month == 10 && day < 25 )) )
                londonOpen = 7;
            else
                londonOpen = 8;
            //ny offset
            if( (month >= 4 || (month == 3 && day >= 8)) && (month < 11 || (month == 11 && day < 1 )) )
                nyOpen = 12;
            else
                nyOpen = 13;
        break;
        default: 
            Alert("SESSION DATES FOR THIS YEAR ARE NECESSARY");
    }
}

/**
 * calculate accumulated from trades
 */
void calculateAccum() {
    double point = MarketInfo(Symbol(), MODE_POINT);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    
    trade.accum = 0;
    for(int i = 0; i < trade.index - 1; i++) {
        if(trade.orders[i].op_type == OP_BUY) {
            ////Print("order ", i, " at ", (bid - trade.orders[i].price) / point * trade.orders[i].size);
            trade.accum += (bid - trade.orders[i].price) / point * trade.orders[i].size;
        }
        else {
            ////Print("order ", i, " at ", (trade.orders[i].price - ask) / point * trade.orders[i].size);
            trade.accum += (trade.orders[i].price - ask) / point * trade.orders[i].size;
        }
        ////Print("trade accum ", trade.accum);
    }
}

/**
 * Order pairs based on more movement
 */
void orderPairs() {
    //---------------------------------------------------------------Get the movement amount of each pair
    for(int pIndex = 0; pIndex < ALL_SYMB_N; pIndex++) {
        double movUp = 0;
        double movDown = 0;
        double medBar = 0;
        
        for(int i = 1; i <= 2880 /*last 2 days*/; i++) {
            double open = iOpen(defaultPairs[pIndex], PERIOD_M1, i);
            double high = iHigh(defaultPairs[pIndex], PERIOD_M1, i);
            double low = iLow(defaultPairs[pIndex], PERIOD_M1, i);
            
            movUp += high - open;
            movDown += open - low;
        }
        
        orderedPairs[pIndex].symbol = defaultPairs[pIndex];
        orderedPairs[pIndex].movement = (movUp - movDown) / MarketInfo(defaultPairs[pIndex], MODE_POINT);
    }
    
    //---------------------------------------------------------------Order by descending mode
    for(int i = 0; i < ALL_SYMB_N; i++) {
        for(int j = i; j < ALL_SYMB_N; j++) {
            if(orderedPairs[j].movement > orderedPairs[i].movement) {
                _symbSorter temp;
                temp.movement = orderedPairs[i].movement;
                temp.symbol = orderedPairs[i].symbol;
                
                orderedPairs[i].movement = orderedPairs[j].movement;
                orderedPairs[i].symbol = orderedPairs[j].symbol;
                
                orderedPairs[j].movement = temp.movement;
                orderedPairs[j].symbol = temp.symbol;
            }
        }
    }
    
    for(int i = 0; i < ALL_SYMB_N; i++)
        ////Print("ordered pairs ", orderedPairs[i].symbol, ": ", orderedPairs[i].movement);
}

/**
 * Find the pairs with less daily directional movement. (safer option for strategy)
 * Don't repeat any major more than 2 times
 */
/*void findFittestPairs() {
    //get movement
    for(int i = 0; i < 28; i++) {
        double adx = iADX(Pairs[i], PERIOD_D1, 15, PRICE_CLOSE, MODE_MAIN, 0);
        
        orderedPairs[i].symbol = Pairs[i];
        orderedPairs[i].movement = adx;
    }
    
    //ordering
    for(int i = 0; i < 28; i++) {
        for(int j = i; j < 28; j++) {
            if(orderedPairs[j].movement < orderedPairs[i].movement) {
                _ordererdPair temp;
                temp.movement = orderedPairs[i].movement;
                temp.symbol = orderedPairs[i].symbol;
                
                orderedPairs[i].movement = orderedPairs[j].movement;
                orderedPairs[i].symbol = orderedPairs[j].symbol;
                
                orderedPairs[j].movement = temp.movement;
                orderedPairs[j].symbol = temp.symbol;
            }
        }
    }
    
    //filter repeated majors
    int repeats[8];
    _ordererdPair fittestPairs[8];
    int fitIndex = 0;
    for(int i = 0; i < 28; i++) {
        int leftCurrencyCount = 0;
        int rightCurrencyCount = 0;
        string leftCurrency = StringSubstr(orderedPairs[i].symbol, 0, 3);
        string rightCurrency = StringSubstr(orderedPairs[i].symbol, 3, 3);
        
        for(int j = 0; j < fitIndex; j++) {
            string takenPair = fittestPairs[j].symbol;
            string takenLeft = StringSubstr(takenPair, 0, 3);
            string takenRight = StringSubstr(takenPair, 3, 3);
            
            if(leftCurrency == takenLeft || leftCurrency == takenRight)
                leftCurrencyCount++;
            if(rightCurrency == takenLeft || rightCurrency == takenRight)
                rightCurrencyCount++;    
        }
        
        if(leftCurrencyCount < 2 && rightCurrencyCount < 2) {
            fittestPairs[fitIndex].symbol = orderedPairs[i].symbol;
            fitIndex++;
        }
    }
    
    ////Print
    for(int i = 0; i < 28; i++) {
        //Print("order pair: ", orderedPairs[i].symbol, " adx: ", orderedPairs[i].movement);
    }
    for(int i = 0; i < 8; i++)
        //Print("**** FITTEST ", fittestPairs[i].symbol);
}*/

/*void setPairsStrengths() {
    //strength of Mains
    for(int i = 0; i < 8; i++)
        currency_strength(Mains[i]);
    
    //strengths of pairs
    for(int i = 0; i < 28; i++) {
        string pair = Pairs[i];
        int lCurrency = getCurrencyAsInteger(StringSubstr(pair, 0, 3));
        int rCurrency = getCurrencyAsInteger(StringSubstr(pair, 3, 3));
        
        orderedPairs[i][0] = NormalizeDouble(BaseStr[lCurrency] - BaseStr[rCurrency], 2);  //strength
        orderedPairs[i][1] = i; //index of pair
    }
    
    //find stronger and weaker pairs
    ArraySort(orderedPairs, WHOLE_ARRAY, 0, MODE_DESCEND);
}*/

/**
 * Evaluate ZigZag indicator to determine current movement
 */
int evalZZ(string symbol) {
    int points = 0;
    double p0 = 0.0, p1 = 0.0;
    int i = 1;
    while(points < 2) {
        double zg = iCustom(symbol, 0, "ZigZag", 15, 30, 0, 0, i);
        if(zg != 0.0) {
            points++;
            if(points == 1)
                p0 = zg;
            if(points == 2)
                p1 = zg;
        }
        i++;
    }
    if(p0 - p1 > 0 && zz_direction <= NONE) {
        if(zz_confirm <= 0)
            zz_confirm++;
        else {
            zz_confirm = 0;
            zz_direction = UP;
        }
    }
    else if(p0 - p1 < 0 && zz_direction >= NONE) {
        if(zz_confirm >= 0)
            zz_confirm--;
        else {
            zz_confirm = 0;
            zz_direction = DOWN;
        }
    }
    
    return NONE;
}

void OnTimer() {
    
}

/**
 * Calculate the strengths of a currency relative to the other majors
 * the strength is added to the BaseStr array in the position of that currency
 * returns the strength of the currency parameter 
 */
/*double currency_strength(string currency) {
    string sym;  //symbol for comparison
    double range = 0.0;
    double ratio = 0.0;
    double strength = 0;
    int calctype = 0;
    int intCurrency = getCurrencyAsInteger(currency);
    int count = 0;
    
    for(int x = 0; x < 28; x++) {
        sym = Pairs[x];
        if(currency == StringSubstr(sym, 0, 3) || currency == StringSubstr(sym, 3, 3)) { //pair contains currency under evaluation
            calctype = (currency == StringSubstr(sym, 0, 3)) ? UP : DOWN;

            range = MarketInfo(sym, MODE_HIGH) - MarketInfo(sym, MODE_LOW);
            if(range == 0.0)
                continue;
            
            ratio = 100 * (iClose(sym, PERIOD_M1, 0) - iClose(sym, PERIOD_D1, 1)) / range;
            if(ratio == 0.0)
                continue;
            
            count++;
            if(calctype == UP)
                strength += ratio;
            else
                strength -= ratio;
        }      
    }      
    BaseStr[intCurrency] = strength / count;
    
    return strength / count;
}*/

/**
 * Get the index of a currency in BaseStr array
 */
int getCurrencyAsInteger(string currency) {
    if(currency == "USD")
        return 0;
    if(currency == "EUR")
        return 1;
    if(currency == "GBP")
        return 2;
    if(currency == "CHF")
        return 3;
    if(currency == "JPY")
        return 4;
    if(currency == "CAD")
        return 5;
    if(currency == "AUD")
        return 6;
    if(currency == "NZD")
        return 7;
    
    return -1;
}
/*
void timerFunc() {
    for(int i = 100; i>= 1; i-- ) {
        double zg = iCustom(Symbol(), PERIOD_M15, "ZigZag", 0, i);
        if(zg != 0)
            //Print("zig zag value: ", zg, " i: ", i);
    }
}*/


/**
 * Order pairs based on more movement
 */
/*void orderPairs() {
    //---------------------------------------------------------------Get the movement amount of each pair
    for(int pIndex = 0; pIndex < ALL_SYMB_N; pIndex++) {
        double movUp = 0;
        double movDown = 0;
        double medBar = 0;
        
        for(int i = 1; i <= 60; i++) {
            double open = iOpen(defaultPairs[pIndex], PERIOD_M1, i);
            double high = iHigh(defaultPairs[pIndex], PERIOD_M1, i);
            double low = iLow(defaultPairs[pIndex], PERIOD_M1, i);
            
            movUp += high - open;
            movDown += open - low;
            medBar += high - low;
        }
        
        orderedPairs[pIndex].medBar = medBar / 10;
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
    
    ////Print to console
    for(int i = 0; i < ALL_SYMB_N; i++)
        //Print("pairs ordered: ", orderedPairs[i].symbol, " movement: ", orderedPairs[i].movement);
}
*/

/**
 * Allow only one trade for symbol
 */
bool symbolAvailable(string symbol) {
    for(int i = 0; i < tradeIndex; i++) {
        if(trades[i].orders[0].symbol == symbol)
            return false;
    }
    
    return true;
}

/** 
 * Set a trade in the symbol specified
 *//*
void evaluateTrade(int i) {
    string symbol = orderedPairs[i].symbol;
    double movement = orderedPairs[i].movement;
    
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    if(movement > 0) {
        double sl = ask - PIP_TARGET*MarketInfo(symbol, MODE_POINT) - MarketInfo(symbol, MODE_SPREAD)*MarketInfo(symbol, MODE_POINT);
        
        trades[tradeIndex].cycleIndex = 0;
        createBuy(symbol, sl, INIT_SIZE, tradeIndex);
    }
    else {
        double sl = bid + PIP_TARGET*MarketInfo(symbol, MODE_POINT) + MarketInfo(symbol, MODE_SPREAD)*MarketInfo(symbol, MODE_POINT);
        
        trades[tradeIndex].cycleIndex = 0;
        createSell(symbol, sl, INIT_SIZE, tradeIndex);
    }
} */

/**
 * render all current trades and check if cycles need to be added
 *//*
void checkTradeCycles() {
    for(int i = 0; i < tradeIndex; i++) {
        int lastCycle = trades[i].cycleIndex - 1;
        
        string symbol = trades[i].orders[lastCycle].symbol;
        double bid = MarketInfo(symbol, MODE_BID);
        double ask = MarketInfo(symbol, MODE_ASK);
        double point = MarketInfo(symbol, MODE_POINT);
        
        if(trades[i].orders[lastCycle].op_type == OP_BUY) {
            if( bid <= trades[i].orders[lastCycle].sl ) {  //need to create new cycle
                double sl = trades[i].orders[lastCycle].price;
                double nsize = 2*trades[i].orders[lastCycle].size;
                createBuy(symbol, sl, nsize, i);
            }    
        }
        else {
            if( ask >= trades[i].orders[lastCycle].sl ) {  //need to create new cycle
                double sl = trades[i].orders[lastCycle].price;
                double nsize = 2*trades[i].orders[lastCycle].size;
                createSell(symbol, sl, nsize, i); 
            }
        }
    }
}*/

/**
 * Open a BUY order
 *//*
void createBuy(string symbol, double sl, double size, int tradePos) {
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);
    double stoploss = sl;
	double osize = size;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        5, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order != -1) {
        int cycle = trades[tradePos].cycleIndex;
        trades[tradePos].orders[cycle].symbol = symbol;
        trades[tradePos].orders[cycle].op_type = optype;
        trades[tradePos].orders[cycle].price = oprice;
        trades[tradePos].orders[cycle].ticket = order;
        trades[tradePos].orders[cycle].size = osize;
        trades[tradePos].orders[cycle].sl = stoploss;
        
        trades[tradePos].cycleIndex++;
        if(size == INIT_SIZE)
            tradeIndex++;
    }
}
*/
/**
 * Open a SELL order
 */
/*void createSell(string symbol, double sl, double size, int tradePos) {
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);
    double stoploss = sl;
	double osize = size;
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        5, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order != -1) {
        int cycle = trades[tradePos].cycleIndex;
        trades[tradePos].orders[cycle].symbol = symbol;
        trades[tradePos].orders[cycle].op_type = optype;
        trades[tradePos].orders[cycle].price = oprice;
        trades[tradePos].orders[cycle].ticket = order;
        trades[tradePos].orders[cycle].size = osize;
        trades[tradePos].orders[cycle].sl = stoploss;
        
        trades[tradePos].cycleIndex++;
        if(size == INIT_SIZE)
            tradeIndex++;
    }
}*/

/**
 * reorder array after closing trade
 */
void reorderTrades(int i) {
    for(int p = i; p < tradeIndex - 1; p++) {
        trades[p].cycleIndex = trades[p+1].cycleIndex;
        for(int c = 0; c < trades[p].cycleIndex; c++) {
            trades[p].orders[c].op_type = trades[p+1].orders[c].op_type;
            trades[p].orders[c].price = trades[p+1].orders[c].price;
            trades[p].orders[c].size = trades[p+1].orders[c].size;
            trades[p].orders[c].sl = trades[p+1].orders[c].sl;
            trades[p].orders[c].symbol = trades[p+1].orders[c].symbol;
            trades[p].orders[c].ticket = trades[p+1].orders[c].ticket;
        }
    }
   
    tradeIndex--;
}

/**
 * Close an order
 */
bool closeOrder(int tI, int cI) {
    double price;
    if(trades[tI].orders[cI].op_type == OP_BUY)
        price = MarketInfo(trades[tI].orders[cI].symbol, MODE_BID);
    else
        price = MarketInfo(trades[tI].orders[cI].symbol, MODE_ASK);
        
    bool closed = OrderClose(trades[tI].orders[cI].ticket, trades[tI].orders[cI].size, price, 3, Blue);
    return closed;
}

void createBuy(double osize) {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        10, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        trade.orders[trade.index].ticket = order;
        trade.orders[trade.index].op_type = optype;
        trade.orders[trade.index].price = oprice;
        trade.orders[trade.index].size = osize;
        trade.orders[trade.index].symbol = symbol;
        
        trade.index++;
        trade.day = currentDay;
    }
}

void createSell(double osize) {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);
	
	int order = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        10, //slippage???
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(order > 0) {
        trade.orders[trade.index].ticket = order;
        trade.orders[trade.index].op_type = optype;
        trade.orders[trade.index].price = oprice;
        trade.orders[trade.index].size = osize;
        trade.orders[trade.index].symbol = symbol;
        
        trade.index++;
        trade.day = currentDay;
    }
}

void closeBuy() {
    bool close = OrderClose(buyOrder.ticket, buyOrder.size, Bid, 3);
    if(close)
        buyOrder.ticket = -1;
}

void closeSell() {
    bool close = OrderClose(sellOrder.ticket, sellOrder.size, Ask, 3);
    if(close)
        sellOrder.ticket = -1;
}

/**
 * DETERMINE the size of next lot based on grid table
 */
/*double calcNextSize() {
    double accumLoss = 0;
    double accumPips = 0;
    
    double level_size = TRADE_SIZE;
    for(int i = 1; i <= cycle.level; i++) {
        accumPips = i * GRID_Y;
        accumLoss += level_size * GRID_Y;
        level_size = accumLoss / (accumPips / 3);
    }
    
    return level_size;
}*/

/**
 * Close all orders
 */
void closeTrade() {
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    while(trade.index > 0) {
        bool stillOpen = TRUE;
        while(stillOpen) {
            double price = 0;
            if(trade.orders[trade.index - 1].op_type == OP_BUY)
                price = bid;
            else
                price = ask;
                
            if(OrderClose(trade.orders[trade.index - 1].ticket, trade.orders[trade.index - 1].size, price, 10, clrNONE)) {
                trade.index--;
                
                stillOpen = FALSE;
            }
        }
    }
}