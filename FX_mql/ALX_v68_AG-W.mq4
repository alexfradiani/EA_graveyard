//+------------------------------------------------------------------+
//|                                                 ALX_v68_AG-W.mq4 |
//|                          Copyright 2015-2016, Alexander Fradiani |
//|                                          http://www.fradiani.com |
//+------------------------------------------------------------------+

/**
 * ANTI-GRID WEIGHTED
 *
 * every GRID_Y pips represents a new stair.
 * 
 * AG System:
 *     - leave both trades sl and tp opened
 *     - use priceMap to weight every stair in the direction of the coming trend
 */

#property copyright "Copyright 2015-2016, Alexander Fradiani"
#property link      "http://www.fradiani.com"
#property version   "1.00"
#property strict

//Money Management
#define TARGET 1

//Position constants
#define UP 1
#define NONE 0
#define DOWN -1

//Trade constants
#define MAX_ORDERS 500
#define MAX_STAIRS 100
#define SLIPPAGE 10
#define ORDER_SIZE 0.01
#define GRID_Y 118

//price map structure, for weights
struct pricemapcell_t {
    double highborder;
    double lowborder;
    double bs;  //size of buys in this stair
    double ss;  // size of sells in this stair
};
pricemapcell_t priceMap[MAX_STAIRS];
int mapTop, mapBottom;  //indexes for map extremes

//Order structure
struct order_t {     
    int ticket;
    string symbol;
    double price;
    int op_type;
    double size;
    
    int pmi;  //Price Map Index
};
order_t AG[MAX_ORDERS];  //list of orders
int AG_i; //index of last order in array
int pivot; //pivot that has the focus in the grid

//strategy variables
double accum, AG_float;
datetime lastBar;

int londonOpen, nyOpen;
bool inTradingHour;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    resetSystem();
    
    lastBar = Time[0];
    inTradingHour = FALSE;
    adjustGMTOpenings();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    resetSystem();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    datetime currentTime = TimeCurrent();
    
    //price values
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
        
    //---------------------------------------------------------------------------------------------TRADING RULES
    if(systemActive() == FALSE && inTradingHour == TRUE) { //no current activity
        //initial movement guess
        double ma_0 = iMA(Symbol(), PERIOD_H1, 12, 0, MODE_SMA, PRICE_CLOSE, 0);
        double ma_2 = iMA(Symbol(), PERIOD_H1, 12, 0, MODE_SMA, PRICE_CLOSE, 2);
        if(ma_0 > ma_2) {
            initPriceMap(ask, point, ORDER_SIZE, 0.0);
            AG_createBuy(ORDER_SIZE, mapTop);
        }
        else {
            initPriceMap(bid, point, 0.0, ORDER_SIZE);
            AG_createSell(ORDER_SIZE, mapBottom);
        }
    }
    
    if(lastBar != Time[0]) {
        //verify hours of day
        int hour = TimeHour(currentTime);
        if(hour >= londonOpen && hour <= nyOpen + 7)
            inTradingHour = TRUE;
        else
            inTradingHour = FALSE;
            
        lastBar = Time[0];
    }
    
    //---------------------------------------------------------------------------------------------PROFIT AND LOSSES
    if(systemActive() == TRUE) { //current cycle in process
        //calculate floating trades profit/loss
        AG_float = 0.0;
        for(int i = 0; i <= AG_i; i++) {
            if(AG[i].ticket != -1) {
                if(AG[i].op_type == OP_BUY)
                    AG_float += (bid - AG[i].price) / point * AG[i].size;
                else
                    AG_float += (AG[i].price - ask) / point * AG[i].size;
            }
        }
        
        if(AG_float >= TARGET)  //profit taken
            closeSystem();
        else {
            //adjust current position if grid continues
            if(AG[pivot].op_type == OP_BUY) {
                if(bid - AG[pivot].price <= -1 * GRID_Y * point) {
                    priceMapAdjust(DOWN, bid);
                }
                else if(ask - AG[pivot].price >= GRID_Y * point) {
                    priceMapAdjust(UP, ask);
                }
            }
            else if(AG[pivot].op_type == OP_SELL) {
                if(AG[pivot].price - ask <= -1 * GRID_Y * point) {
                    priceMapAdjust(UP, ask);
                }
                else if(AG[pivot].price - bid >= GRID_Y * point) {
                    priceMapAdjust(DOWN, bid);
                }
            }
        }
    }
    
    writeComments();
    RefreshRates();
}
//+------------------------------------------------------------------+

/**
 * Comments for log in terminal
 */
void writeComments() {
    datetime t = TimeCurrent();
    int wday = TimeDayOfWeek(t);
    string msg = "Week-day: " + IntegerToString(wday) + " \n";
    msg += "AG float: " + DoubleToString(AG_float, 2) + " \n";
    msg += "mapTop: "+IntegerToString(mapTop - (MAX_STAIRS/2 -1))+" mapBottom: "+IntegerToString(mapBottom - (MAX_STAIRS/2 -1))+" \n";
    msg += "pivot: " + IntegerToString(pivot);
    
    Comment(msg);
}

/**
 * Check is a cycle is in action
 */
bool systemActive() {
    if(AG[0].ticket != -1)
        return TRUE;
    else
        return FALSE;
} 
 
/**
 * Reset all system variables
 */
void resetSystem() {
    //reset AG
    for(int i = 0; i < MAX_ORDERS; i++) {
        AG[i].ticket = -1;
        AG[i].size = 0.0;
    }
    AG_i = 0;
    pivot = 0;
    
    //reset priceMap
    for(int i = 0; i < MAX_STAIRS; i++) {
        priceMap[i].bs = 0.0;
        priceMap[i].ss = 0.0;
        priceMap[i].highborder = 0.0;
        priceMap[i].lowborder = 0.0;
    }
    mapBottom = 0;
    mapTop = 0;
    
    //clean chart from previous pricemap
    ObjectsDeleteAll(0, OBJ_HLINE);
}

/**
 * CLOSE a complete cycle
 */
void closeSystem() {
    while(AG[0].ticket != -1) {
        AG_close(0);
    }
    
    resetSystem();  //reset variables
}

/**
 * INIT the price map grid cells
 */
void initPriceMap(double price, double point, double bs, double ss) {
    //digits
    int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
    
    //init middle cell
    mapBottom = mapTop = MAX_STAIRS / 2 - 1;
    double highborder = price + GRID_Y / 2 * point;
    double lowborder = price - GRID_Y / 2 * point;
    
    priceMap[MAX_STAIRS / 2 - 1].highborder = highborder;
    priceMap[MAX_STAIRS / 2 - 1].lowborder = lowborder;
    priceMap[MAX_STAIRS / 2 - 1].bs = bs;
    priceMap[MAX_STAIRS / 2 - 1].ss = ss;
    
    //init down side from the middle
    for(int i = mapBottom - 1; i >= 0; i--) {
        int distance = MathAbs(i - (MAX_STAIRS/2 - 1));
        
        double middlepoint = price - distance * GRID_Y * point;
        priceMap[i].highborder = NormalizeDouble(middlepoint + GRID_Y / 2 * point, digits);
        priceMap[i].lowborder = NormalizeDouble(middlepoint - GRID_Y / 2 * point, digits);
    }
    
    //init up side from the middle
    for(int i = mapTop + 1; i < MAX_STAIRS; i++) {
        int distance = MathAbs(i - (MAX_STAIRS/2 - 1));
        
        double middlepoint = price + distance * GRID_Y * point;
        priceMap[i].highborder = NormalizeDouble(middlepoint + GRID_Y / 2 * point, digits);
        priceMap[i].lowborder = NormalizeDouble(middlepoint - GRID_Y / 2 * point, digits);
    }
    
    //draw pricemap in chart window
    drawPriceMap();
}

/** 
 * Draw lines of current pricemap in chart window
 */
void drawPriceMap() {
    for(int i = 39; i <= 59; i++) {
        string obj_name = "pmi " + IntegerToString(i-49);
        ObjectCreate(obj_name, OBJ_HLINE, 0, Time[0], priceMap[i].lowborder);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrWhite);
    }
}

/**
 * update price map weights according to movement
 */
void priceMapAdjust(int direction, double price) {
    int currentCell = AG[pivot].pmi;  //current price map index
    int pmi = -1;
    double nw = 0.0;
    double pw = 0.0;
    switch(direction) {
        case UP:
            //locate the map cell where price is going
            for(int i = currentCell; i < MAX_STAIRS; i++)
                if(price <= priceMap[i].highborder && price >= priceMap[i].lowborder) {
                    pmi = i;
                    break;
                }
            
            //update border index of map
            if(pmi > mapTop)
                mapTop = pmi;
            
            //determine ballance of weights in that cell
            if(priceMap[pmi].bs <= priceMap[pmi].ss)
                nw = priceMap[pmi].ss + ORDER_SIZE - priceMap[pmi].bs;
                
            //verify middle cell pending weight
            if(priceMap[currentCell].ss > priceMap[currentCell].bs) {
                pw = priceMap[currentCell].ss - priceMap[currentCell].bs;
                
                /*if(currentCell == mapBottom || currentCell == mapTop)
                    pw = pw - ORDER_SIZE;  //borders of pricemap can maintain 1 size difference*/
            }
            
            nw = ORDER_SIZE;
            if(nw > 0)  //create if necessary
                AG_createBuy(nw, pmi);
            priceMap[pmi].bs += nw;
        break;
        
        case DOWN:
            //locate the map cell where price is going
            for(int i = currentCell; i >= 0; i--)
                if(price <= priceMap[i].highborder && price >= priceMap[i].lowborder) {
                    pmi = i;
                    break;
                }
            
            //update border index of map
            if(pmi < mapBottom)
                mapBottom = pmi;
            
            //determine ballance of weights in that cell
            if(priceMap[pmi].ss <= priceMap[pmi].bs)
                nw = priceMap[pmi].bs + ORDER_SIZE - priceMap[pmi].ss;
                
            //verify middle cell pending weight
            if(priceMap[currentCell].bs > priceMap[currentCell].ss) {
                pw = priceMap[currentCell].bs - priceMap[currentCell].ss;
                
                /*if(currentCell == mapBottom || currentCell == mapTop)
                    pw = pw - ORDER_SIZE;  //borders of pricemap can maintain 1 size difference*/
            }
            
            nw = ORDER_SIZE;
            if(nw > 0)  //create if necessary
                AG_createSell(nw, pmi);
            priceMap[pmi].ss += nw;
        break;
    }
    
    //update pivot based on pricemap
    updatePivotFromPMI(pmi);
}

/**
 * UPDATE pivot trade
 * according to orders in pricemap 
 */
void updatePivotFromPMI(int pmi) {
    for(int i = 0; i <= AG_i; i++)
        if(AG[i].pmi == pmi)
            pivot = i; //use the last order in that pricemap cell
}

/**
 * AG
 * CLOSE
 */
bool AG_close(int index) {
    string symbol = Symbol();
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(Symbol(), MODE_POINT);
    
    double price;
    if(AG[index].op_type == OP_BUY)
        price = bid;
    else
        price = ask;
    bool closed = OrderClose(AG[index].ticket, AG[index].size, price, SLIPPAGE, clrNONE);
    if(closed) {  
        AG[index].ticket = -1;
            
        //reorder array
        for(int i = index; i <= AG_i - 1; i++) {
            AG[i].ticket = AG[i+1].ticket;
            AG[i].symbol = AG[i+1].symbol;
            AG[i].price = AG[i+1].price;
            AG[i].op_type = AG[i+1].op_type;
            AG[i].size = AG[i+1].size;
            AG[i].pmi = AG[i+1].pmi;
        }
        if(AG_i > 0)
            AG_i--;
    }
    
    return TRUE;
}

/**
 * AG
 * CREATE a buy
 */
void AG_createBuy(double osize, int pmi) {
    string symbol = Symbol();
    int optype = OP_BUY;
    double oprice = MarketInfo(symbol, MODE_ASK);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(AG[AG_i].ticket != -1)
            AG_i++; //increase order index
        
        AG[AG_i].ticket = ticket;
        AG[AG_i].op_type = optype;
        AG[AG_i].price = oprice;
        AG[AG_i].size = osize;
        AG[AG_i].symbol = symbol;
        AG[AG_i].pmi = pmi;
    }
}

/**
 * AG
 * CREATE a SELL 
 */
void AG_createSell(double osize, int pmi) {
    string symbol = Symbol();
    int optype = OP_SELL;
    double oprice = MarketInfo(symbol, MODE_BID);

	int ticket = OrderSend(
        symbol, //symbol
        optype, //operation
        osize, //volume
        oprice, //price
        SLIPPAGE, //slippage
        0,//NormalizeDouble(stoploss, digit), //Stop loss
        0//NormalizeDouble(takeprofit, digit) //Take profit
    );
    
    if(ticket > 0) {
        if(AG[AG_i].ticket != -1)
            AG_i++; //increase order index
        
        AG[AG_i].ticket = ticket;
        AG[AG_i].op_type = optype;
        AG[AG_i].price = oprice;
        AG[AG_i].size = osize;
        AG[AG_i].symbol = symbol;
        AG[AG_i].pmi = pmi;
    }
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