//+------------------------------------------------------------------+
//|                                      ALX_strengthStoch_ea.mq4    |
//|                                           Alexander Fradiani     |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * - EA based on strength of currencies for trades
 * - Stochastics MTF rules
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

#define UP 1
#define NONE 0
#define DOWN -1

extern double R_VOL = 0.1;  //Risk Volume. volume of trades
extern double RVRS_DEGREE = 5;  //factor to determine K is moving against trend direction
extern double UPPER_K_AREA = 60;
extern double LOWER_K_AREA = 40;

//symbols being tracked for trades
string pairs[];

struct stochastic_data {
    int currDirection;
    double pivot;
};

/*data for orders*/
struct order_t {
    int ticket;
    double price;
    double sl;
    int op_type;
};

order_t buyOrder;
order_t sellOrder;

stochastic_data m15_kmem;
stochastic_data m30_kmem;

//For controlling stochastics
int m5_lastTrigger = 0;
int m15_lastTrigger = 0;
int m30_lastTrigger = 0;

bool m5_lastTriggerBurned = TRUE;

datetime lastTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    m15_kmem.pivot = -1;
    m30_kmem.pivot = -1;
    
    buyOrder.ticket = -1;
    sellOrder.ticket = -1;
    
    lastTime = Time[0];
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //...  
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    //getStrengthPairs();
    ArrayResize(pairs, 1); pairs[0] = "EURUSD"; //for testing...
    
    for(int i = 0; i < ArraySize(pairs); i++) {
        evaluateStochs(pairs[i]);
    }
    
    if(Time[0] != lastTime) {
        //printState();
    
        lastTime = Time[0];
    }
    
    RefreshRates();
}
//+------------------------------------------------------------------+

//log for debugging vars state
void printState() {
    Print("vars.state: mtriggs[5:",m5_lastTrigger," 15:",m15_lastTrigger," 30:",m30_lastTrigger,"] m5_trgBurned:", 
            m5_lastTriggerBurned, " M15_KMEM pivot: ", m15_kmem.pivot, " direc: ", m15_kmem.currDirection,
            " M30_KMEM pivot: ", m30_kmem.pivot, " direc: ", m30_kmem.currDirection);
}

/**
 * Stochastics for deciding trades
 */
void evaluateStochs(string pair) {
    //m5 state
    double m5_st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 1);
    double m15_st = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
    double m30_st = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
    
    if(m5_st <= 11) {
        //if(m5_lastTrigger == DOWN)
            //Print("M5 new long trigger");
    
        m5_lastTrigger = UP;
        m5_lastTriggerBurned = FALSE;
    }
    else if(m5_st >= 89) {
        //if(m5_lastTrigger == UP)
            //Print("M5 new short trigger");
            
        m5_lastTrigger = DOWN;
        m5_lastTriggerBurned = FALSE;
    }
    
    if(m15_st <= 21) {
        m15_lastTrigger = UP;
    }
    else if(m15_st >= 79) {
        m15_lastTrigger = DOWN;
    }
    
    if(m30_st <= 21) {
        m30_lastTrigger = UP;
    }
    else if(m30_st >= 79) {
        m30_lastTrigger = DOWN;
    }
    
    //check the trend from m15 and m30
    updateKDirection(PERIOD_M15, pair);
    updateKDirection(PERIOD_M30, pair);

    if(m5_lastTrigger == UP && m5_st <= 50) {  //check conditions for longs
        if(m15_kmem.currDirection == UP && m15_lastTrigger == UP) { 
            if(m30_kmem.currDirection == UP && m30_lastTrigger == UP) {
                //Print("M15 is UP, M30 is UP");
                if(m15_kmem.pivot <= UPPER_K_AREA && m30_kmem.pivot <= UPPER_K_AREA) {
                    if(m5_lastTriggerBurned == FALSE && buyOrder.ticket == -1) {    
                        m5_lastTriggerBurned = TRUE;
                        
                        createBuy(pair);
                        Print("-BUY ENTRY- ", Ask);
                        printState();
                    }
                }
            }
        }
    }
    
    if(m5_lastTrigger == DOWN && m5_st >= 50) {   //check conditions for shorts
        if(m15_kmem.currDirection == DOWN && m15_lastTrigger == DOWN) {
            if(m30_kmem.currDirection == DOWN && m30_lastTrigger == DOWN) {
                //Print("M15 is DOWN, M30 is DOWN");
                if(m15_kmem.pivot >= LOWER_K_AREA && m30_kmem.pivot >= LOWER_K_AREA) {
                    if(m5_lastTriggerBurned == FALSE && sellOrder.ticket == -1) {
                        m5_lastTriggerBurned = TRUE;
                        
                        createSell(pair);
                        Print("-SELL ENTRY- ", Bid);
                        printState();
                    }
                }
            }
        }
    }
    
    //verify stops and profits
    checkExits();
}

/**
 * Evaluate conditions for closing orders
 */
void checkExits() {
    if(buyOrder.ticket != -1) {
        if(Bid <= buyOrder.sl) { //critic stoploss
            closeBuy();
            return;
        }
        
        if(m15_kmem.currDirection == DOWN || m30_kmem.currDirection == DOWN) {
            closeBuy();
            return;
        }
        
        if(m15_lastTrigger == DOWN || m30_lastTrigger == DOWN) {
            closeBuy();
            return;
        }
    }
    
    if(sellOrder.ticket != -1) {
        if(Ask >= sellOrder.sl) { //critic stoploss
            closeSell();
            return;
        }
        
        if(m15_kmem.currDirection == UP || m30_kmem.currDirection == UP) {
            closeSell();
            return;
        }
        
        if(m15_lastTrigger == UP || m30_lastTrigger == UP) {
            closeSell();
            return;
        }
    }
}

/**
 * Determine kDirection of a stochastic
 */
void updateKDirection(int tf, string pair) {
    if(tf == PERIOD_M15) {
        double m15_st_0 = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
        
        if(m15_kmem.pivot == -1) {
            m15_kmem.pivot = m15_st_0;
            m15_kmem.currDirection = DOWN;
            
            return;
        }
        
        if(m15_kmem.currDirection == UP) {
            if(m15_kmem.pivot < m15_st_0) {
                m15_kmem.pivot = m15_st_0;
            }
            else if(m15_kmem.pivot - m15_st_0 >= RVRS_DEGREE) {
                m15_kmem.pivot = m15_st_0;
                
                m15_kmem.currDirection = DOWN;  //change in direction
            }    
        }
        else if(m15_kmem.currDirection == DOWN) {
            if(m15_kmem.pivot > m15_st_0) {
                m15_kmem.pivot = m15_st_0;
            }
            else if(m15_st_0 - m15_kmem.pivot >= RVRS_DEGREE) {
                m15_kmem.pivot = m15_st_0;
                
                m15_kmem.currDirection = UP;  //change in direction  
            }    
        }
        
    }
    else if(tf == PERIOD_M30) {
        double m30_st_0 = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
        
        if(m30_kmem.pivot == -1) {
            m30_kmem.pivot = m30_st_0;
            m30_kmem.currDirection = DOWN;
            
            return;
        }
        
        if(m30_kmem.currDirection == UP) {
            if(m30_kmem.pivot < m30_st_0) {
                m30_kmem.pivot = m30_st_0;
            }
            else if(m30_kmem.pivot - m30_st_0 >= RVRS_DEGREE) {
                m30_kmem.pivot = m30_st_0;
                
                m30_kmem.currDirection = DOWN;  //change in direction
            }    
        }
        else if(m30_kmem.currDirection == DOWN) {
            if(m30_kmem.pivot > m30_st_0) {
                m30_kmem.pivot = m30_st_0;
            }
            else if(m30_st_0 - m30_kmem.pivot >= RVRS_DEGREE) {
                m30_kmem.pivot = m30_st_0;
                
                m30_kmem.currDirection = UP;  //change in direction  
            }    
        }
    }
}

/**
 * Create a buy order
 */
void createBuy(string pair) {
    int digit = MarketInfo(pair, MODE_DIGITS);
    
    int optype = OP_BUY;
    double oprice = MarketInfo(pair, MODE_ASK);
	double stoploss = oprice - 200*Point;
	//double takeprofit = oprice + 50*Point;
	int order = OrderSend(
		pair, //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0, //NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    buyOrder.op_type = optype;
    buyOrder.price = oprice;
    buyOrder.sl = stoploss;
    buyOrder.ticket = order;
    
    //Print("BUY created. Close[1] was: ", Close[1]," Ask: ", buyOrder.price," SL: ", buyOrder.sl);
}

/**
 * Create a sell order
 */
void createSell(string pair) {
    int digit = MarketInfo(pair, MODE_DIGITS);

    int optype = OP_SELL;
    double oprice = MarketInfo(pair, MODE_BID);
	double stoploss = oprice + 200*Point;
	//double takeprofit = oprice - 50*Point;
	int order = OrderSend(
		pair, //symbol
		optype, //operation
		R_VOL, //volume
		oprice, //price
		3, //slippage???
		0,//NormalizeDouble(stoploss, digit), //Stop loss
		0//NormalizeDouble(takeprofit, digit) //Take profit
	);
	
	//save order
    sellOrder.op_type = optype;
    sellOrder.price = oprice;
    sellOrder.sl = stoploss;
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
 * determine pairs according to strength indicator
 */
void getStrengthPairs() {
    //define parameters for strength indicator
    string	Currencies		= "EUR,USD,GBP,JPY,CHF,CAD,AUD,NZD";
    string	CurrDisplay		= "1,1,1,1,1,1,1,1";
    //extern string	SymbolFixes		="";									//for irregular Symbols
    bool    AutoSuffixAdjust  = true; //try to get symbol suffix automatically, fxdaytrader
    string	SymbolSuffixes		="";									//for irregular Symbols
    string	SymbolPrefixes		="";									//for irregular Symbols
    string	ShowSignal		= "EURUSD,EURCHF,EURJPY,GBPUSD,USDCHF,GBPJPY,GBPCHF,AUDUSD";
    int		TimeFrame		= 0;
    int		StrengthBase	= 60;
    int		RecentCHBase	= 10;
    bool		ShowLineChart	= true;
    bool		ShowBarChart	= true;
    bool		UpdateOnTick	= false;
    bool		AllowAlert		= false;
    bool		AllowSound		= false;
    int		MinAlertIntv	= 30;
    int		LineChartBars	= 200;
    int		LegendOffestY	= 20;
    int		MeterPosition	= 20;
    color	BullColor		= Green;
    color	BearColor		= Red;
    color	Color0			= Magenta;
    color	Color1			= Blue;
    color	Color2			= Red;
    color	Color3			= Yellow;
    color	Color4			= Gray;
    color	Color5			= Green;
    color	Color6			= Brown;
    color	Color7			= Orange;
    color	TextColor		= White;
    
    bool valid = TRUE;
    int index = 0;
    while(valid) { 
        double spair = iCustom(NULL, 0, "StrengthMeter_wSuffix-mod_alx.mq4", 
            Currencies, CurrDisplay, AutoSuffixAdjust, SymbolSuffixes, SymbolPrefixes, ShowSignal, TimeFrame, StrengthBase,
            RecentCHBase, ShowLineChart, ShowBarChart, UpdateOnTick, AllowAlert, AllowSound, MinAlertIntv, LineChartBars,
            LegendOffestY, MeterPosition, BullColor, BearColor, Color0, Color1, Color2, Color3, Color4, Color5, Color6,
            Color7, TextColor,
            6,
            index);
            
        if(spair == -1)
            valid = FALSE;
        else {
            ArrayResize(pairs, index + 1);
            pairs[index] = getSymbolFromIndex(spair);
        }
        
        index++;       
    }
}

/**
 * get symbol string from numeric index
 */
string getSymbolFromIndex(double sym) {
    string val;
    
    if(sym == 1)
        val = "EURUSD";
    if(sym == 2)
        val = "EURGBP";
    if(sym == 3)
        val = "EURJPY";
    if(sym == 4)
        val = "EURCHF";
    if(sym == 5)
        val = "EURCAD";
    if(sym == 6)
        val = "EURAUD";
    if(sym == 7)
        val = "EURNZD";
    
    if(sym == 8)
        val = "USDEUR";
    if(sym == 9)
        val = "USDGBP";
    if(sym == 10)
        val = "USDJPY";
    if(sym == 11)
        val = "USDCHF";
    if(sym == 12)
        val = "USDCAD";
    if(sym == 13)
        val = "USDAUD";
    if(sym == 14)
        val = "USDNZD";
    
    if(sym == 15)
        val = "GBPEUR";
    if(sym == 16)
        val = "GBPUSD";
    if(sym == 17)
        val = "GBPJPY";
    if(sym == 18)
        val = "GBPCHF";
    if(sym == 19)
        val = "GBPCAD";
    if(sym == 20)
        val = "GBPAUD";
    if(sym == 21)
        val = "GBPNZD";
    
    if(sym == 22)
        val = "JPYEUR";
    if(sym == 23)
        val = "JPYUSD";
    if(sym == 24)
        val = "JPYGBP";
    if(sym == 25)
        val = "JPYCHF";
    if(sym == 26)
        val = "JPYCAD";
    if(sym == 27)
        val = "JPYAUD";
    if(sym == 28)
        val = "JPYNZD";
    
    if(sym == 29)
        val = "CHFEUR";
    if(sym == 30)
        val = "CHFUSD";
    if(sym == 31)
        val = "CHFGBP";
    if(sym == 32)
        val = "CHFJPY";
    if(sym == 33)
        val = "CHFCAD";
    if(sym == 34)
        val = "CHFAUD";
    if(sym == 35)
        val = "CHFNZD";
        
    if(sym == 36)
        val = "CADEUR";
    if(sym == 37)
        val = "CADUSD";
    if(sym == 38)
        val = "CADGBP";
    if(sym == 39)
        val = "CADJPY";
    if(sym == 40)
        val = "CADCHF";
    if(sym == 41)
        val = "CADAUD";
    if(sym == 42)
        val = "CADNZD";
        
    if(sym == 43)
        val = "AUDEUR";
    if(sym == 44)
        val = "AUDUSD";
    if(sym == 45)
        val = "AUDGBP";
    if(sym == 46)
        val = "AUDJPY";
    if(sym == 47)
        val = "AUDCHF";
    if(sym == 48)
        val = "AUDCAD";
    if(sym == 49)
        val = "AUDNZD";
        
    if(sym == 50)
        val = "NZDEUR";
    if(sym == 51)
        val = "NZDUSD";
    if(sym == 52)
        val = "NZDGBP";
    if(sym == 53)
        val = "NZDJPY";
    if(sym == 54)
        val = "NZDCHF";
    if(sym == 55)
        val = "NZDCAD";
    if(sym == 56)
        val = "NZDAUD";
        
    return val;
}