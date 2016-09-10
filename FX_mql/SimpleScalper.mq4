//+------------------------------------------------------------------+
//|                                                SimpleScalper.mq4 |
//|                                               Alexander Fradiani |
//+------------------------------------------------------------------+
#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

extern string clientDesc = "scalper simple test";

extern double risk_vol = 0.1;  //volume of trades
extern double pips_sl = 0.00020;  //pips STOP LOSS threshold
extern double take_profits = 1.0;  //Take profits

int lows = 0;
int highs = 0;

double last = -1;
datetime lastTime;

struct order_t {
    int ticket;
    double price;
    int op_type;
    double lastPivot;
    int reverseCounts; 
};

/*Arrays for keeping track of shorts and longs*/
order_t shorts[];
order_t longs[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {	
	return;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(last < 0)
        last = Close[1];
    
    //1. Track three consecutive higher highs or lower lows to open new orders
    if(lastTime != Time[1]) {
        lastTime = Time[1];
        
        if(Close[1] < last) {
            lows++;
        }
        else
            lows = 0;
            
        if(Close[1] > last) {
            highs++;
        }
        else
            highs = 0;
        
        last = Close[1];
        
        if(lows == 3) { //go short
            double oprice = MarketInfo(Symbol(), MODE_BID);
			int order = OrderSend(
				Symbol(), //symbol
				OP_SELL, //operation
				risk_vol, //volume
				oprice, //price
				3, //slippage???
				0, //Stop loss
				0 //Take profit
			);
			
			//save to shorts
			order_t newShort;
			newShort.lastPivot = Close[1];
			newShort.op_type = OP_SELL;
			newShort.ticket = order;
			newShort.price = oprice;
			newShort.reverseCounts = 0;
			array_push(shorts, newShort);
			
			lows--;
        }
        
        if(highs == 3) {  //go long
            double oprice = MarketInfo(Symbol(), MODE_ASK);
			int order = OrderSend(
				Symbol(), //symbol
				OP_BUY, //operation
				risk_vol, //volume
				oprice, //price
				3, //slippage???
				0, //Stop loss
				0 //Take profit
			);
			
			//save to longs
			order_t newLong;
			newLong.lastPivot = Close[1];
			newLong.op_type = OP_BUY;
			newLong.ticket = order;
			newLong.price = oprice;
			newLong.reverseCounts = 0;
			array_push(longs, newLong);
			
			highs--;
        }
        
        //2. Track open orders for stop loss or take profit
        //FOR SHORTS
        for(int i = 0; i < ArraySize(shorts); i++) {
            OrderSelect(shorts[i].ticket, SELECT_BY_TICKET, MODE_TRADES);
            bool orderWillClose = FALSE;
            
            //order will close with a stop loss of threshold pips.
            if(shorts[i].price - Close[1] <= -1*pips_sl)
                orderWillClose = TRUE;
            
            //order will close after three reverse moves (no need to be consecutive)
            if(Close[1] > shorts[i].lastPivot) {
                shorts[i].lastPivot = Close[1];
                shorts[i].reverseCounts++;
                
                if(shorts[i].reverseCounts == 3)
                    orderWillClose = TRUE;
            }
            
            //Order will close to take profits
            if(OrderProfit() >= take_profits)
                orderWillClose = TRUE;
            
            if(orderWillClose) {
                double oprice = MarketInfo(Symbol(), MODE_ASK);
                OrderClose(shorts[i].ticket, risk_vol, oprice, 10);
                array_remove(shorts, shorts[i].ticket);
                i--;
            }
        }
        
        //FOR LONGS
        for(int i = 0; i < ArraySize(longs); i++) {
            OrderSelect(longs[i].ticket, SELECT_BY_TICKET, MODE_TRADES);
            bool orderWillClose = FALSE;
            
            //order will close with a stop loss of threshold pips.
            if(Close[1] - longs[i].price <= -1*pips_sl)
                orderWillClose = TRUE;
            
            //order will close after three reverse moves (no need to be consecutive)
            if(Close[1] < longs[i].lastPivot) {
                longs[i].lastPivot = Close[1];
                longs[i].reverseCounts++;
                
                if(longs[i].reverseCounts == 3)
                    orderWillClose = TRUE;
            }
            
            //Order will close to take profits
            if(OrderProfit() >= take_profits)
                orderWillClose = TRUE;
            
            if(orderWillClose) {
                double oprice = MarketInfo(Symbol(), MODE_BID);
                OrderClose(longs[i].ticket, risk_vol, oprice, 10);
                array_remove(longs, longs[i].ticket);
                i--;
            }
        }
    }
    
    RefreshRates();
	
	return;
}

//+------------------------------------------------------------------+

/**
 * insert order to array
 */
void array_push(order_t&  array[], order_t& order) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = order;
}

/**
 * remove an order from array and resize
 */
void array_remove(order_t& array[], int ticket) {
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