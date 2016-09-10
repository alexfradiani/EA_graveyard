//+------------------------------------------------------------------+
//|                                               BLG_Scalper.mq4    |
//|                                               Alexander Fradiani |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * Bollinger bands simple scalping:
 * - buys or sells at price touching borders of Bands
 * - trail at middle line and opposite border line.
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define OFFSIDE_DOWN -1
#define OFFSIDE_NONE 0
#define OFFSIDE_UP 1

#define BULLISH 1
#define BEARISH -1

//values for the dynamic SL based on bands
#define UPPERBAND 1
#define MIDDLEBAND 0
#define LOWERBAND -1
#define NONE -99

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double WORST_SL = 0.02000;

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl; //normal sl based on price
    int dyn_sl; //dynamic sl based on the value of the B Bands.
    int op_type;
};

order_t buyOrder;
order_t sellOrder;
datetime lastTime;

int offPos;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    lastTime = Time[0];
    offPos = OFFSIDE_NONE;
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(Time[0] != lastTime) {
        //Print("evaluating ", Time[0]);
        lastTime = Time[0];
        
        double downBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 1);
        double upBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 1);
        double middleBand = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 1);
        
        if(Close[1] <= downBand) {
            offPos = OFFSIDE_DOWN;
            //Print("Enter OFFSIDE_DOWN. downBand: ", downBand, " Close[1]: ", Close[1]);
        }
        else if(Close[1] >= upBand) {
            offPos = OFFSIDE_UP;
            //Print("Enter OFFSIDE_UP. upBand: ", upBand, " Close[1]: ", Close[1]);
        }
        else { //INSIDE bands area
            if(offPos == OFFSIDE_DOWN && buyOrder.ticket == -1) {
                //Print("Enter BANDS AREA. downBand: ", downBand, " Close[1]: ", Close[1]);
                if(Close[1] > Open[1])
                    createBuy();
            }
            
            if(offPos == OFFSIDE_UP && sellOrder.ticket == -1) {
                //Print("Enter BANDS AREA. upBand: ", upBand, " Close[1]: ", Close[1]);
                if(Close[1] < Open[1])
                    createSell();
            }
            
            offPos = OFFSIDE_NONE;
        }
        
        //Check stops
        if(buyOrder.ticket != -1) {
            //update SL based on dyn_sl
            if(buyOrder.dyn_sl == MIDDLEBAND)
                buyOrder.sl = middleBand;
            else if(buyOrder.dyn_sl == UPPERBAND)
                buyOrder.sl = upBand;
            
            //Print("checking stoploss. SL: ", buyOrder.sl, " Close[1]: ", Close[1]);
            if(Close[1] <= buyOrder.sl || Open[0] <= buyOrder.sl)
                closeBuy();
            else {
                //Print("Bid: ", Bid, " upBand: ", upBand, " middleBand: ", middleBand);
                if(barTop() >= middleBand && buyOrder.dyn_sl == NONE) {
                    //Print("buy order #", buyOrder.ticket, " updated SL to middleBand");
                    buyOrder.sl = middleBand;
                    buyOrder.dyn_sl = MIDDLEBAND;
                }
                if(barTop() >= upBand && (buyOrder.dyn_sl == NONE || buyOrder.dyn_sl == MIDDLEBAND)) {
                    //Print("buy order #", buyOrder.ticket, " updated SL to upBand");
                    buyOrder.sl = upBand;
                    buyOrder.dyn_sl = UPPERBAND;
                }
            }
        }
        if(sellOrder.ticket != -1) {
            //update SL based on dyn_sl
            if(sellOrder.dyn_sl == MIDDLEBAND)
                sellOrder.sl = middleBand;
            else if(sellOrder.dyn_sl == LOWERBAND)
                sellOrder.sl = downBand;
            
            if(Close[1] >= sellOrder.sl || Open[0] >= sellOrder.sl)
                closeSell();
            else {
                if(barBottom() <= middleBand && sellOrder.dyn_sl == NONE) {
                    sellOrder.sl = middleBand;
                    sellOrder.dyn_sl = MIDDLEBAND;
                }
                if(barBottom() <= downBand && (sellOrder.dyn_sl == NONE || sellOrder.dyn_sl == MIDDLEBAND)) {
                    sellOrder.sl = downBand;
                    sellOrder.dyn_sl = LOWERBAND;
                }
            }
        }
    }
}
//+------------------------------------------------------------------+

/**
 * Create a buy order
 */
void createBuy() {
    int optype = OP_BUY;
    double oprice = MarketInfo(Symbol(), MODE_ASK);
    double stoploss = setSL(optype);
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.dyn_sl = NONE;
    buyOrder.ticket = order;
    
    //Print("BUY created. Close[1] was: ", Close[1]," Ask: ", buyOrder.price," SL: ", buyOrder.sl);
}

/**
 * Create a sell order
 */
void createSell() {
    int optype = OP_SELL;
    double oprice = MarketInfo(Symbol(), MODE_BID);
	double stoploss = setSL(optype);
	int order = OrderSend(
		Symbol(), //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0, //NormalizeDouble(stoploss, Digits), //Stop loss
		0 //NormalizeDouble(takeprofit, Digits) //Take profit
	);
	
	//save order
    sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
    sellOrder.dyn_sl = NONE;
    sellOrder.ticket = order;
    
    //Print("SELL created. Close[1] was: ", Close[1]," Bid: ", sellOrder.price," SL: ", sellOrder.sl);
}

void closeBuy() {
    OrderClose(buyOrder.ticket, R_VOL, Bid, 3, Blue);
    buyOrder.ticket = -1;
}

void closeSell() {
    OrderClose(sellOrder.ticket, R_VOL, Ask, 3, Blue);
    sellOrder.ticket = -1;
}

/**
 * SL logic.
 */
double setSL(int optype) {
    double sl = 0;
    
    if(optype == OP_BUY) {
        sl = Close[1] - NormalizeDouble(WORST_SL, 5);
        //Print("setting sl. Close[1]: ", Close[1], " 5%: ", WORST_SL, " sl: ", sl);
    }    
    else if(optype == OP_SELL)
        return Close[1] + NormalizeDouble(WORST_SL, 5);
    
    return sl;
}

/**
 * return the price extreme
 */
double barTop() {
    if(Open[1] > Close[1])
        return Open[1];
    else
        return Close[1];
}

double barBottom() {
    if(Open[1] > Close[1])
        return Close[1];
    else
        return Open[1];
}