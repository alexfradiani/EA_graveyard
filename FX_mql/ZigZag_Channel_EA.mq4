//+------------------------------------------------------------------+
//|                                            ZigZag_Channel_EA.mq4 |
//|                                                     Coders' Guru |
//|                                            http://www.xpworx.com |
//|                                   Last Modification = 2011.10.28 |
//+------------------------------------------------------------------+
#property copyright "Coders' Guru"
#property link      "http://www.xpworx.com"
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
extern   string      _                          = "Trade limits";
extern   double      Lots                       = 0.1;
extern   int         TakeProfit                 = 100; 
extern   int         StopLoss                   = 50;
extern   int         TrailingStop               = 50;
extern   int         ECN_Broker                 = true;
extern   int         Slippage                   = 5;
extern   bool        UseMoneyManagement         = true;
extern   double      RiskFactor                 = 0.1;
extern   int         MagicNumber                = 12345;
extern   bool        AutoGenerateMagicNumber    = true;
extern   string      __                         = "ZigZag Channel Indicator settings";
//+------------------------------------------------------------------+
extern   int      ExtDepth                = 12;
extern   int      ExtDeviation            = 5;
extern   int      ExtBackstep             = 3;
extern   int      BreakPips               = 5;
extern   int      back                    = 1;
color    UpperBandColor          = Blue;
color    LowerBandColor          = Red;
bool     AlertOn                 = false;
//+------------------------------------------------------------------+
//--- Global variables
double   mPoint               = 0.0001;
//+------------------------------------------------------------------
int init()
{
   if(AutoGenerateMagicNumber) MagicNumber = GetMagicNumber(558854);
   
   mPoint = GetPoint();
   
   return(0);
}
//+------------------------------------------------------------------+
int deinit() 
{
   Comment("");
   return(0);
}
//+------------------------------------------------------------------+
int start()
{
   int  signal = CheckSignal();
   
   bool BuyCondition = false , SellCondition = false , CloseBuyCondition = false , CloseSellCondition = false; 
   
   if (signal==1)
       BuyCondition = true;
       
   if (signal==-1)
      SellCondition = true;
   
   if (BuyCondition)
      CloseSellCondition = true;
   
   if (SellCondition)
      CloseBuyCondition = true;
      
   
   if(UseMoneyManagement)
   Lots=CalcLots(RiskFactor);
   
   if(TradeExist(MagicNumber)==false) 
   {
      int ticket;
      
      if(BuyCondition) //<-- BUY condition
      {
         if(NewBar(0))
         ticket = OpenOrder(ECN_Broker,OP_BUY,0,Lots,Slippage,StopLoss,TakeProfit,MagicNumber,WindowExpertName(),5,500);
      }
      if(SellCondition) //<-- SELL condition
      {
         if(NewBar(1))
         ticket = OpenOrder(ECN_Broker,OP_SELL,0,Lots,Slippage,StopLoss,TakeProfit,MagicNumber,WindowExpertName(),5,500);
      }
   }
     
   for(int cnt = 0 ; cnt < OrdersTotal() ; cnt++)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() == Symbol() && OrderMagicNumber()== MagicNumber)
      {
         if(CloseBuyCondition && OrderType()==OP_BUY) CloseOrder(OrderTicket(),0,Slippage,5,500); 
         if(CloseSellCondition && OrderType()==OP_SELL) CloseOrder(OrderTicket(),0,Slippage,5,500); 
      }
   }
   
   if(TrailingStop>0)TrailOrders(TrailingStop,MagicNumber);
   
   return(0);
}
//+------------------------------------------------------------------+
int CheckSignal()
{
   double upperband = iCustom(NULL,0,"ZigZag_Channels",ExtDepth,ExtDeviation,ExtBackstep,BreakPips,
   UpperBandColor,LowerBandColor,back,AlertOn,0,0);
   
   double lowerband = iCustom(NULL,0,"ZigZag_Channels",ExtDepth,ExtDeviation,ExtBackstep,BreakPips,
   UpperBandColor,LowerBandColor,back,AlertOn,1,0);
      
   if(Close[1]>upperband+BreakPips*mPoint && Open[1]<upperband)
   return(1); //buy
      
         
   if(Close[1]<lowerband-BreakPips*mPoint  && Open[1]>lowerband)
   return(-1); //sell
                 
   return(0);
}
//+------------------------------------------------------------------+
double CalcLots(double Risk)
{
   double tmpLot = 0, MinLot = 0, MaxLot = 0;
   MinLot = MarketInfo(Symbol(),MODE_MINLOT);
   MaxLot = MarketInfo(Symbol(),MODE_MAXLOT);
   tmpLot = NormalizeDouble(AccountBalance()*Risk/1000,2);
      
   if(tmpLot < MinLot)
   {
      Print("LotSize is Smaller than the broker allow minimum Lot!");
      return(MinLot);
   } 
   if(tmpLot > MaxLot)
   {
      Print ("LotSize is Greater than the broker allow minimum Lot!");
      return(MaxLot);
   } 
   return(tmpLot);
}
//+------------------------------------------------------------------+
double nd(double value)
{
   return(NormalizeDouble(value,Digits));
}
//+------------------------------------------------------------------+
int OpenOrder(bool STP, int TradeType, double Price, double TradeLot, int TradeSlippage, double TradeStopLoss, 
double TradeTakeProfit, int TradeMagicNumber, string TradeComment , int TriesCount, int Pause)
{
   int ticket=0, cnt=0;
   bool DobuleLimits;
   double point = GetPoint();

   double ask,bid;
   
   if(Price>0)
   {  
      ask = nd(Price);
      bid = nd(Price);
   }
   else
   {
      ask = nd(Ask);
      bid = nd(Bid);   
   }
   

   if(TradeStopLoss==0 && TradeTakeProfit==0) DobuleLimits = false;
   else
   {
      if(TradeStopLoss!=0) DobuleLimits = TradeStopLoss-MathFloor(TradeStopLoss)>0;
      else DobuleLimits = TradeTakeProfit-MathFloor(TradeTakeProfit)>0;
   }
   
   double sl=0,tp=0;
   
   if(STP==true)
   {
      if(TradeType == OP_BUY)
      {
         if(DobuleLimits==true)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(TradeStopLoss);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(TradeTakeProfit);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               if(sl==0 && tp==0)
               {
                  ticket=OrderSend(Symbol(),OP_BUY,TradeLot,ask,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Green);
               }
               else
               {
                  ticket=OrderSend(Symbol(),OP_BUY,TradeLot,ask,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Green);
                  if(ticket>-1) 
                  {
                     OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
                     OrderModify(ticket,OrderOpenPrice(),sl,tp,0,Green);
                  }
               }
               if(ticket==-1){Print("error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
         
         if(DobuleLimits==false)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(ask-TradeStopLoss*point);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(ask+TradeTakeProfit*point);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               if(sl==0 && tp==0)
               {
                  ticket=OrderSend(Symbol(),OP_BUY,TradeLot,ask,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Green);
               }
               else
               {
                  ticket=OrderSend(Symbol(),OP_BUY,TradeLot,ask,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Green);
                  if(ticket>-1) 
                  {
                     OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
                     OrderModify(ticket,OrderOpenPrice(),sl,tp,0,Green);
                  }
               }
               if(ticket==-1){Print("error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
      }
   
      if(TradeType == OP_SELL)
      {
         if(DobuleLimits==true)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(TradeStopLoss);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(TradeTakeProfit);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               if(sl==0 && tp==0)
               {
                  ticket=OrderSend(Symbol(),OP_SELL,TradeLot,bid,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Red);
               }
               else
               {
                  ticket=OrderSend(Symbol(),OP_SELL,TradeLot,bid,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Red);
                  if(ticket>-1) 
                  {
                     OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
                     OrderModify(ticket,OrderOpenPrice(),sl,tp,0,Red);
                  }
               }
               if(ticket==-1){Print("order=",TradeType," error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
         
         if(DobuleLimits==false)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(bid+TradeStopLoss*point);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(bid-TradeTakeProfit*point);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               if(sl==0 && tp==0)
               {
                  ticket=OrderSend(Symbol(),OP_SELL,TradeLot,bid,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Red);
               }
               else
               {
                  ticket=OrderSend(Symbol(),OP_SELL,TradeLot,bid,TradeSlippage,0,0,TradeComment,TradeMagicNumber,0,Red);
                  if(ticket>-1) 
                  {
                     OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
                     OrderModify(ticket,OrderOpenPrice(),sl,tp,0,Red);
                  }
               }
               if(ticket==-1){Print("order=",TradeType," error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
      }
   }
   
   if(STP==false)
   {
      if(TradeType == OP_BUY)
      {
         if(DobuleLimits==true)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(TradeStopLoss);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(TradeTakeProfit);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               ticket=OrderSend(Symbol(),OP_BUY,TradeLot,ask,TradeSlippage,sl,tp,TradeComment,TradeMagicNumber,0,Green);
               if(ticket==-1){Print("order=",TradeType," error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
         
         if(DobuleLimits==false)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(ask-TradeStopLoss*point);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(ask+TradeTakeProfit*point);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               ticket=OrderSend(Symbol(),OP_BUY,TradeLot,ask,TradeSlippage,sl,tp,TradeComment,TradeMagicNumber,0,Green);
               if(ticket==-1){Print("order=",TradeType," error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
      }
      
      if(TradeType == OP_SELL)
      {
         if(DobuleLimits==true)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(TradeStopLoss);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(TradeTakeProfit);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               ticket=OrderSend(Symbol(),OP_SELL,TradeLot,bid,TradeSlippage,sl,tp,TradeComment,TradeMagicNumber,0,Red);
               if(ticket==-1){Print("order=",TradeType," error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
         
         if(DobuleLimits==false)
         {
            if(TradeStopLoss==0) sl = 0; else sl = nd(bid+TradeStopLoss*point);
            if(TradeTakeProfit==0) tp = 0; else tp = nd(bid-TradeTakeProfit*point);
            
            for(cnt = 0 ; cnt < TriesCount ; cnt++)
            {
               ticket=OrderSend(Symbol(),OP_SELL,TradeLot,bid,TradeSlippage,sl,tp,TradeComment,TradeMagicNumber,0,Red);
               if(ticket==-1){Print("order=",TradeType," error=",GetLastError()," ask=",ask," bid=",bid," sl=",sl," tp=",tp," lots=",TradeLot); Sleep(Pause); continue;} else {break;}  
            }
         }
      }
   }
   return(ticket);
}
//+------------------------------------------------------------------+
bool NewBar(int ref) 
{
	static datetime LastTime[10];
	if (Time[0] != LastTime[ref]) 
	{
		LastTime[ref] = Time[0];		
		return (true);
	} 
	return (false); //else
}
//+------------------------------------------------------------------+
bool TradeExist(int magic)
{
   int total  = OrdersTotal();
   for(int cnt = 0 ; cnt < total ; cnt++)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()== magic && OrderType()<=OP_SELL)
      return (true);
    }
    return (false);
}
//+------------------------------------------------------------------+
bool CloseOrder(int ticket, double lots, int slippage, int tries, int pause)
{
   bool result=false;
   double ask = nd(Ask);
   double bid = nd(Bid);
   
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
   {
      if(OrderType()==OP_BUY)
      {
         for(int c = 0 ; c < tries ; c++)
         {
            if(lots==0) result = OrderClose(OrderTicket(),OrderLots(),bid,slippage,Violet);
            else result = OrderClose(OrderTicket(),lots,bid,slippage,Violet);
            if(result==true) break; 
            else
            {
               Sleep(pause);
               continue;
            }
         }
      }
      if(OrderType()==OP_SELL)
      {
         for(c = 0 ; c < tries ; c++)
         {
            if(lots==0) result = OrderClose(OrderTicket(),OrderLots(),ask,slippage,Violet);
            else result = OrderClose(OrderTicket(),lots,ask,slippage,Violet);
            if(result==true) break; 
            else
            {
               Sleep(pause);
               continue;
            }
         }
      }
   }
   return(result);
}
//+------------------------------------------------------------------+
bool TrailOrders(int ts, int magic)
{
   if(ts<=0) return(false);
 
   bool result;
   
   double point = GetPoint();   
      
   double ask = nd(Ask);
   double bid = nd(Bid);
   
   for(int cnt=0;cnt<OrdersTotal();cnt++) 
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      
      if(OrderSymbol()==Symbol()  && OrderMagicNumber()==magic)
      {
         if(OrderType()==OP_SELL)  
         { 
            if(OrderOpenPrice()-ask > point*ts)
            {
               if(OrderStopLoss()>(ask+point*ts)+point || OrderStopLoss()==0)
               {
                  result = OrderModify(OrderTicket(),OrderOpenPrice(),ask+point*ts,OrderTakeProfit(),0,Red);
               }
            }
         }
        
         if(OrderType()==OP_BUY)  
         { 
            if(bid-OrderOpenPrice() > point*ts)
            {
               if(OrderStopLoss()<(bid-point*ts)-point || OrderStopLoss()==0)
               {
                  result = OrderModify(OrderTicket(),OrderOpenPrice(),bid-point*ts,OrderTakeProfit(),0,Green);
               }
            }
         }
      }
   }
   
   return(result);
}


int GetMagicNumber(int base)
{
   int Reference = 0;
   string symbol = StringUpperCase(Symbol());
   if (StringFind(symbol,"AUDCAD")>-1) Reference = base + 1001 + Period();
   if (StringFind(symbol,"AUDJPY")>-1) Reference = base + 2002 + Period();
   if (StringFind(symbol,"AUDNZD")>-1) Reference = base + 3003 + Period();
   if (StringFind(symbol,"AUDUSD")>-1) Reference = base + 4004 + Period();
   if (StringFind(symbol,"CHFJPY")>-1) Reference = base + 5005 + Period();
   if (StringFind(symbol,"EURAUD")>-1) Reference = base + 6006 + Period();
   if (StringFind(symbol,"EURCAD")>-1) Reference = base + 7007 + Period();
   if (StringFind(symbol,"EURCHF")>-1) Reference = base + 8008 + Period();
   if (StringFind(symbol,"EURGBP")>-1) Reference = base + 9009 + Period();
   if (StringFind(symbol,"EURJPY")>-1) Reference = base + 1010 + Period();
   if (StringFind(symbol,"EURUSD")>-1) Reference = base + 1111 + Period();
   if (StringFind(symbol,"GBPCHF")>-1) Reference = base + 1212 + Period();
   if (StringFind(symbol,"GBPJPY")>-1) Reference = base + 1313 + Period();
   if (StringFind(symbol,"GBPUSD")>-1) Reference = base + 1414 + Period();
   if (StringFind(symbol,"NZDJPY")>-1) Reference = base + 1515 + Period();
   if (StringFind(symbol,"NZDUSD")>-1) Reference = base + 1616 + Period();
   if (StringFind(symbol,"USDCHF")>-1) Reference = base + 1717 + Period();
   if (StringFind(symbol,"USDJPY")>-1) Reference = base + 1818 + Period();
   if (StringFind(symbol,"USDCAD")>-1) Reference = base + 1919 + Period();
   if (Reference == 0) Reference = base + 2020 + Period();
   return(Reference);
}
//+------------------------------------------------------------------+
string StringUpperCase(string str)
{
   int s = StringLen(str);
   int chr = 0;
   string temp;
   for (int c = 0 ; c < s ; c++)
   {
      chr = StringGetChar(str,c);
      if (chr >= 97 && chr <=122) chr = chr - 32;
      temp = temp + CharToStr(chr);
   }
   return (temp);  
}
//+------------------------------------------------------------------+
double GetPoint(string symbol = "")
{
   if(symbol=="" || symbol == Symbol())
   {
      if(Point==0.00001) return(0.0001);
      else if(Point==0.001) return(0.01);
      else return(Point);
   }
   else
   {
      RefreshRates();
      double tPoint = MarketInfo(symbol,MODE_POINT);
      if(tPoint==0.00001) return(0.0001);
      else if(tPoint==0.001) return(0.01);
      else return(tPoint);
   }
}
//+------------------------------------------------------------------+


