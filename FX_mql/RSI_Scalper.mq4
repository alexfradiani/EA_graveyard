//+------------------------------------------------------------------+
//|                                                  RSI_Scalper.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

extern double R_VOL = 0.1;  //Risk Volume. volume of trades

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    int op_type;
};
order_t orders[];

bool downCrossed = FALSE;
bool upCrossed = FALSE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
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
//---
    if(Bars <= 1)
        return;
    
    bool swCloseSell = FALSE;
    bool swCloseBuy = FALSE;
    
    //read current RSI
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 1);
    
    if(rsi <= 30) {
        downCrossed = TRUE;
        
        upCrossed = FALSE;
        swCloseBuy = TRUE;
        swCloseSell = TRUE;
    }
    else if(downCrossed == TRUE) { //bull time
        //open buy
        if(buying() == FALSE)
            createBuy();
    }
    
    if(rsi >= 70) {
        upCrossed = TRUE;
        
        downCrossed = FALSE;
        swCloseBuy = TRUE;
        swCloseSell = TRUE;
    }
    else if(upCrossed == TRUE) { //bear time
        //close buy & open sell
        swCloseBuy = TRUE;
        if(selling() == FALSE)
            createSell();
    }
    
    for(int i = 0; i < ArraySize(orders); i++) {
        if(swCloseBuy) {
            if(orders[i].op_type == OP_BUY) {
                OrderClose(orders[i].ticket, R_VOL, Bid, 3, Blue);
                o_array_remove(orders, orders[i].ticket);
                if(i > 0) i--;
            }
        }
        if(swCloseSell && ArraySize(orders) > 0) {
            if(orders[i].op_type == OP_SELL) {
                OrderClose(orders[i].ticket, R_VOL, Ask, 3, Red);
                o_array_remove(orders, orders[i].ticket);
                i--;
            }
        }
    }
}
//+------------------------------------------------------------------+

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
    order_t newOrder;
    newOrder.op_type = optype;
    newOrder.price = oprice;
    newOrder.sl = stoploss;
    newOrder.ticket = order;
    o_array_push(orders, newOrder);
}

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
    order_t newOrder;
    newOrder.op_type = optype;
    newOrder.price = oprice;
    newOrder.sl = stoploss;
    newOrder.ticket = order;
    o_array_push(orders, newOrder);
}

bool buying() {
    for(int i = 0; i < ArraySize(orders); i++)
        if(orders[i].op_type == OP_BUY)
            return TRUE;
    
    return FALSE;
}

bool selling() {
    for(int i = 0; i < ArraySize(orders); i++)
        if(orders[i].op_type == OP_SELL)
            return TRUE;
    
    return FALSE;
}

double setSL(int op_type) {
    double space = MarketInfo(Symbol(), MODE_STOPLEVEL)*Point;
    if(op_type == OP_BUY)
        return Bid - space - 5*Point;
    else
        return Ask + space + 5*Point;
}

/**
 * insert order to array
 */
void o_array_push(order_t&  array[], order_t& order) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = order;
}

/**
 * remove an order from array and resize
 */
void o_array_remove(order_t& array[], int ticket) {
    int length = ArraySize(array);
    order_t narray[];
    
    ArrayResize(narray, length - 1);
    for(int i = 0, j = 0; i < length; i++) {
    	if(array[i].ticket == ticket)
    		continue;
    	else {
    		narray[j] = array[i];
    		j++;
    	}
    }
    
    ArrayCopy(array, narray);
    ArrayResize(array, length - 1);
}