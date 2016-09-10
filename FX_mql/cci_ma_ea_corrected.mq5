//+------------------------------------------------------------------+
//|                                                    cci_ma_ea.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
//--- input parameters
input int      StopLoss=30;      // Stop Loss
input int      TakeProfit=50;    // Take Profit
input int      MA_Period=26;     // MA Period
input int      CCI_Period1=50;   // CCI Period 1
input int      CCI_Period2=28;   // CCI Period 2
input int      EA_Magic=999;     // EA Magic Number
input double   Lot=0.1;          // Lots to Trade
//--- Other parameters
int maHandle;                   // handle for our Moving Average indicator
int cciHandle1,cciHandle2;      // handle for our CCI indicator
double maVal[];                 // dynamic array to hold the values of Moving Average for each bars
double cciVal1[],cciVal2[];       // dynamic array to hold the values of CCI for each bars
double p1_close,p2_close;       // variable to store the close value of Bar 1 and Bar 2 respectively
//--- Define some useful values
double cczero = 0.0000;
double ccip = 1.0000;
double ccim = -1.0000;
double ccmaxa = 100.0000;
double ccmaxb = 95.0000;
double ccmina = -100.0000;
double ccminb = -95.0000;
int STP, TKP;        // To be used for Stop Loss & Take Profit values
MqlRates mrate[];    // To be used to store the prices, volumes and spread of each bar
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Get the handle for Moving Average indicator
   maHandle=iMA(_Symbol,Period(),MA_Period,0,MODE_EMA,PRICE_TYPICAL);
//--- Get the handle for CCI indicator 1
   cciHandle1=iCCI(_Symbol,PERIOD_CURRENT,CCI_Period1,PRICE_TYPICAL);
//--- Get the handle for CCI indicator 2
   cciHandle2=iCCI(_Symbol,PERIOD_CURRENT,CCI_Period2,PRICE_TYPICAL);
//--- What if handle returns Invalid Handle
   if(maHandle<0 || cciHandle1<0 || cciHandle2<0)
     {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
     }
/*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
*/
// the rates arrays
   ArraySetAsSeries(mrate,true);
// the CCI 1 values arrays
   ArraySetAsSeries(cciVal1,true);
// the CCI 2 values arrays
   ArraySetAsSeries(cciVal2,true);
// the MA values arrays
   ArraySetAsSeries(maVal,true);

//--- Let us handle brokers that offers 5 OR 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits==5 || _Digits==3)
     {
      STP = STP*10;
      TKP = TKP*10;
     }
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release our indicator handles
   IndicatorRelease(maHandle);
   IndicatorRelease(cciHandle1);
   IndicatorRelease(cciHandle2);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Do we have enough bars to work with
   int Mybars=Bars(_Symbol,_Period);
   if(Mybars<60) // if total bars is less than 60 bars
    {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }

//--- Define some MQL5 Structures we will use for our trade
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results

//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price))     // line 100
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");  // line 103
      return;
     }

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      return;
     }

//--- EA should only check for new trade if we have a new bar
//--- Lets declare a static datetime variable
   static datetime Prev_time;
//--- :ets get the start time for the current bar (Bar 0)
   datetime Bar_time[1];
//--- Copy the current bar time
   Bar_time[0]=mrate[0].time;
//--- We don't have a new bar when both times are the same
   if(Prev_time==Bar_time[0])
     {
      return;
     }
//--- We have a new Bar, so copy time to static value, save
   Prev_time=Bar_time[0];

//--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(maHandle,0,0,5,maVal)<0)
     {
      Alert("Error copying MA indicator Buffers - error:",GetLastError(),"!!");
      return;
     }
   if(CopyBuffer(cciHandle1,0,0,5,cciVal1)<0 || CopyBuffer(cciHandle2,0,0,5,cciVal2)<0)
     {
      Alert("Error copying CCI indicator buffer - error:",GetLastError());
      return;
     }
//--- We have no errors, so continue
//--- Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
   p1_close=mrate[1].close;  // bar 1 close price
   p2_close=mrate[2].close;  // bar 2 close price

//--- Do we have positions opened already?
   bool Buy_opened=false,Sell_opened=false;
   if(PositionSelect(_Symbol)==true) // we have an opened position
     {
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         Buy_opened=true;  //It is a Buy
         double msl=PositionGetDouble(POSITION_SL);
         double mtp=PositionGetDouble(POSITION_TP);
         if(CheckTrade("BUY")==true)
           {
            Buy_opened=false;
           }
        }
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)   // line 159
        {
         Sell_opened=true; // It is a Sell
         double smsl=PositionGetDouble(POSITION_SL);
         double smtp=PositionGetDouble(POSITION_TP);
         if(CheckTrade("SELL")==true)
           {
            Sell_opened=false;
           }
        }
     }

//--- Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1=(cciVal1[3]<cczero) && (cciVal1[2]>cczero);    // CCI 1 crosses upwards from zero
   bool Buy_Condition_2=(p2_close>maVal[2]);                           // Bar 2 closed price above MA
   bool Buy_Condition_3=(p1_close>p2_close);                           // Bar 1 close price higher than Bar 2 close price
   bool Buy_Condition_4=(cciVal1[0]>ccip) && (cciVal2[0]>ccip);        // CCI 1 and CCI 2 are positive

//--- Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = (cciVal1[3]>cczero) && (cciVal1[2]<cczero); // CCI 1 crosses downwards below zero
   bool Sell_Condition_2 = (p2_close < maVal[2]);                      // Bar 2 closed price below MA
   bool Sell_Condition_3=(p1_close<p2_close);                          // Bar 1 close price lower than Bar 2 close price
   bool Sell_Condition_4=(cciVal1[0]<ccim) && (cciVal2[0]<ccim);       // CCI 1 and CCI 2 are negative 

/*
    1. Check for a long/Buy Setup 
*/
//--- Putting all together   
   if(Buy_Condition_1 && Buy_Condition_2)
     {
      if(Buy_Condition_3 && Buy_Condition_4)
        {
//--- any opened Buy position?
         if(Buy_opened)
           {
            Alert("We already have a Buy position!!!");
            return;    // Don't open a new Buy Position
           }
         mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.ask,_Digits);            // latest ask price
         mrequest.sl = NormalizeDouble(latest_price.ask - STP*_Point,_Digits);  // Stop Loss
         mrequest.tp = NormalizeDouble(latest_price.ask + TKP*_Point,_Digits);  // Take Profit
         mrequest.symbol = _Symbol;                                             // currency pair
         mrequest.volume = Lot;                                                 // number of lots to trade
         mrequest.magic = EA_Magic;                                             // Order Magic Number
         mrequest.type = ORDER_TYPE_BUY;                                        // Buy Order
         mrequest.type_filling = ORDER_FILLING_IOC;                             // Order execution type
         mrequest.deviation=100;                                                // Deviation from current price
//--- Send order
         OrderSend(mrequest,mresult);
//--- Get the return code of the trade server
         if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
           {
            Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
           }
         else
           {
            Alert("The Buy order request could not be completed -error:",GetLastError());
            return;
           }
        }
     }
/*
    2. Check for a Short/Sell Setup : 
*/
//--- Putting all together
   else if(Sell_Condition_1 && Sell_Condition_2)
     {
      if(Sell_Condition_3 && Sell_Condition_4)
        {
//--- any opened Sell position?
         if(Sell_opened)
           {
            Alert("We already have a Sell position!!!");
            return;    // Don't open a new Sell Position
           }
         mrequest.action = TRADE_ACTION_DEAL;                                   // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.bid,_Digits);            // latest Bid price
         mrequest.sl = NormalizeDouble(latest_price.bid + STP*_Point,_Digits);  // Stop Loss
         mrequest.tp = NormalizeDouble(latest_price.bid - TKP*_Point,_Digits);  // Take Profit
         mrequest.symbol = _Symbol;                                             // currency pair
         mrequest.volume = Lot;                                                 // number of lots to trade
         mrequest.magic = EA_Magic;                                             // Order Magic Number
         mrequest.type = ORDER_TYPE_SELL;                                       // Sell Order
         mrequest.type_filling = ORDER_FILLING_IOC;                             // Order execution type
         mrequest.deviation=100;                                                // Deviation from current price
//--- Send order
         OrderSend(mrequest,mresult);
//--- Get the return code of the trade server
         if(mresult.retcode==10009 || mresult.retcode==10008) // Request is completed or order placed
           {
            Alert("A Sell order has been successfully placed with Ticket#:",mresult.order,"!!");
           }
         else
           {
            Alert("The Sell order request could not be completed -error:",GetLastError());
            return;
           }
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|  Checks for close conditions                                     |
//+------------------------------------------------------------------+
bool checkClose(string ptype)
  {
   bool mark=false;
   if(ptype=="BUY")
     {
//--- Can we close this position
      if(cciVal1[2]>ccmaxa && cciVal1[1]<ccmaxb) // CCI I crosses downward from +100
        {
         mark=true;
        }
     }
   if(ptype=="SELL")
     {
//--- Can we close this position
      if(cciVal1[2]<ccmina && cciVal1[1]>ccminb)// CCI 1 crosses upward from -100
        {
         mark=true;
        }
     }
   return(mark);
  }
//+------------------------------------------------------------------+
//|  Checks for trade                                                |
//+------------------------------------------------------------------+
bool CheckTrade(string otyp)
  {
   bool marker=false;
   for(int i=1; i<=PositionsTotal();i++)    // line 292
     {
      if(PositionSelect(_Symbol)==true)
        {
         if(PositionGetInteger(POSITION_MAGIC)==EA_Magic && PositionGetString(POSITION_SYMBOL)==_Symbol) // our EA
           {
//--- check if we can close the order
            Alert("checkclose-",otyp," is: ",checkClose(otyp));
            if(checkClose(otyp)==true)
              {
               double pvol = PositionGetDouble(POSITION_VOLUME);
               ulong pdev = 100;
               if(CloseTrade(otyp,pvol,pdev)==true)
                 {
                  marker=true;
                 }
              }
           }
        }
     }
   return(marker);
  }
//+------------------------------------------------------------------+
//|  Closes the trade                                                |
//+------------------------------------------------------------------+
bool CloseTrade(string otype,double vol,ulong dev)
  {
   MqlTradeRequest trequest;
   MqlTradeResult tresult;
   ENUM_ORDER_TYPE ptype;
   if(otype=="BUY")
     {
      ptype=ORDER_TYPE_SELL;
      trequest.price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
     }
   else
     {
      ptype=ORDER_TYPE_BUY;
      trequest.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
     }
   trequest.action=TRADE_ACTION_DEAL;
   trequest.type=ptype;
   trequest.volume=vol;
   trequest.sl=0;
   trequest.tp=0;
   trequest.deviation=dev;
   trequest.magic=EA_Magic;
   trequest.symbol=_Symbol;
   trequest.type_filling=ORDER_FILLING_FOK;
//--- Send
   OrderSend(trequest,tresult);
//-- Check result
   if(tresult.retcode==10009 || tresult.retcode==10008) // Request successfully completed 
     {
      Alert("A opened position has been successfully closed with Ticket#:",tresult.order,"!!");
      return(true);
     }
   else
     {
      Alert("The position close request could not be completed - error: ",GetLastError());
      return(false);
     }
  }
//+------------------------------------------------------------------+