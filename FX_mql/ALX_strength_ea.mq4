//+------------------------------------------------------------------+
//|                                           ALX_strength_ea.mq4    |
//|                                           Alexander Fradiani     |
//|                                                                  |
//+------------------------------------------------------------------+

/**
 * - EA based on strength of currencies for trades
 */

#property copyright "Alexander Fradiani"
#property version   "1.00"
#property strict

extern double R_VOL = 0.1;  //Risk Volume. volume of trades

//symbols being tracked for trades
string pairs[];

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
    
    RefreshRates();       
}
//+------------------------------------------------------------------+

/**
 * Stochastics for deciding trades
 */
void evaluateStochs(string pair) {
    double m5_st = iStochastic(pair, PERIOD_M5, 14, 1, 1, MODE_SMA, 0, MODE_MAIN, 0);
    if(m5_st <= 11) { //m5 in long signal
        //Print("Stoch m5: ", m5_st);
        double m15_st_0 = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 0);
        double m15_st_1 = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
        
        double diff = m15_st_0 - m15_st_1;
        //Print("diff m15:", diff);
        if(diff > 0) {  //15 moving in right direction
            double m30_st_0 = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 0);
            double m30_st_1 = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
            
            diff = m30_st_0 - m30_st_1;
            //Print("diff m30:", diff);
            if(diff > 0) { //30 also
                Print("LONG ENTRY");
            }
        }
    }
    
    if(m5_st >= 89) { //m5 in short signal
        //Print("Stoch m5: ", m5_st);
        double m15_st_0 = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 0);
        double m15_st_1 = iStochastic(pair, PERIOD_M15, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
        
        double diff = m15_st_0 - m15_st_1;
        //Print("diff m15:", diff);
        if(diff < 0) {  //15 moving in right direction
            double m30_st_0 = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 0);
            double m30_st_1 = iStochastic(pair, PERIOD_M30, 14, 3, 3, MODE_SMA, 0, MODE_MAIN, 1);
            
            diff = m30_st_0 - m30_st_1;
            //Print("diff m30:", diff);
            if(diff < 0) { //30 also
                Print("SHORT ENTRY");
            }
        }
    }
}

/**
 * determine pairs
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