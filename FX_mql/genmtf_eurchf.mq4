//+------------------------------------------------------------------+
//|                                                      mika_pb.mq4 |
//|                                     Copyright 2014,Mika Åkerberg |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014,Mika Åkerberg"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

extern static string clientDesc = "pb-trender";

extern double risk_vol = 0.1;  //volume of trades
extern double pips_sl = 1.5;  //pips STOP LOSS threshold
extern double take_profits = 7;  //Take profits
extern int MaxBuys = 1;
extern int MaxSells = 1;
extern int MaxSumOrders = 0;
extern int MagicNumber=2;


extern string Comments="ea-v1";
int action;
int tradebar=0;
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



if (Bars != tradebar) {


   double TVI=iCustom(NULL,60,"Gen22",0,0);
   double CCI=iCustom(NULL,60,"Gen22",2,0);
   double T3=iCustom(NULL,60,"Gen22",4,0);
   double GHL=iCustom(NULL,60,"Gen22",6,0);
   double TapeUp=iCustom(NULL,0,"GMTS-Tape",0,0);
   double TapeDown=iCustom(NULL,0,"GMTS-Tape",1,0);
 //  double TapeUp4=iCustom(NULL,240,"GMTS-Tape",0,0);
 //  double TapeDown4=iCustom(NULL,240,"GMTS-Tape",1,0);
   double RSI =iRSI(NULL,0,7,PRICE_CLOSE,0);
   double ldMA = iMA(Symbol(),0,20,0,MODE_SMA,PRICE_TYPICAL,0);

   if (TVI==0&&CCI==0&&T3==0&&GHL==0&&TapeDown<1&&ldMA>Ask&& (int)TimeCurrent() > Time[0]+800) {
   //if (RSI<70) OpenShort();
   //else 
   OpenLong();
 tradebar=Bars;

   }
    if (TVI>0&&CCI>0&&T3>0&&GHL>0&&ldMA<Bid&&TapeUp<1 && (int)TimeCurrent() > Time[0]+800) {

//   if (RSI>30) OpenLong();
   //else 
   OpenShort();
 tradebar=Bars;

   }


}
CheckTrades();       
}

void CheckTrades() {

   RefreshRates();

   int i=0,d=Digits;
   for(i=0;i<OrdersTotal();i++) {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
 //     if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderSymbol()!=Symbol()) continue;
      double nRSI =iRSI(NULL,0,7,PRICE_CLOSE,1);
      double pRSI =iRSI(NULL,0,7,PRICE_CLOSE,2);
      if(OrderType()==OP_BUY) {
         if(nRSI>80 && OrderProfit()>0.60){// && OrderProfit()>0.20) {
         //  if(nRSI<pRSI) { //
           if (!OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,d),3)){}
            Sleep(1000); 
         }
      } 
      //}
    
      if(OrderType()==OP_SELL) {
         if (nRSI<20&& OrderProfit()>0.60){// && OrderProfit()>0.20) {
          //  if(nRSI>pRSI) { //and RSI is going down 
            if (!OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,d),3)){}
             Sleep(1000); 
         } 
      }
      
      if (OrderType()==OP_BUYSTOP) {
         if (MathAbs((OrderOpenPrice()-Ask)*100)>0.80) {
//            Print("Altering buystop");
            double OpenPrice=NormalizeDouble(OrderOpenPrice()-40*Point,Digits);
            OrderModify(OrderTicket(),OpenPrice,0,NormalizeDouble(OpenPrice+75*Point,Digits),0);
            Sleep(1000);
      }
   }
   
         if (OrderType()==OP_SELLSTOP) {
         if (MathAbs((Bid-OrderOpenPrice())*100>0.80)) {
            double OpenPrice=NormalizeDouble(OrderOpenPrice()+40*Point,Digits);
//            Print("Altering SELLSTOP Open: ",OrderOpenPrice()," -> ",OpenPrice," (current Bid: ",Bid,") TP: ",NormalizeDouble(OpenPrice-85*Point,Digits));
 
            OrderModify(OrderTicket(),OpenPrice,0,NormalizeDouble(OpenPrice-75*Point,Digits),0);
            Sleep(1000);
      }
   }

   
   
}
}
/*
bool  OrderModify(
   int        ticket,      // ticket
   double     price,       // price
   double     stoploss,    // stop loss
   double     takeprofit,  // take profit
   datetime   exp    
   color      arrow_color  // color
   );
   */
/* originals:

void OpenLong() {
      int d=Digits;
      double p=Point;

      double stoploss=NormalizeDouble(Bid-2400*Point,Digits); //USDZAR 9000
      double takeprofit=NormalizeDouble(Bid+50*Point,Digits); //USDZAR 2200
      OrderSend(Symbol(),OP_BUY,0.05,NormalizeDouble(Ask,d),3,stoploss,takeprofit,"mea");


}

void OpenShort() {
      int d=Digits;
      double p=Point;

      double stoploss=NormalizeDouble(Ask+2400*Point,Digits);
      double takeprofit=NormalizeDouble(Ask-50*Point,Digits); 
      OrderSend(Symbol(),OP_SELL,0.05,NormalizeDouble(Bid,d),3,stoploss,takeprofit,"mea");


}


limits:

void OpenLong() {
      int d=Digits;
      double p=Point;

      double stoploss=NormalizeDouble(Bid-2400*Point,Digits); //USDZAR 9000
      double takeprofit=NormalizeDouble(Bid+50*Point,Digits); //USDZAR 2200
      if (Low[1] < Ask) OrderSend(Symbol(),OP_BUYLIMIT,0.05,Low[1],3,stoploss,takeprofit,"htfs-bll");
      else OrderSend(Symbol(),OP_BUY,0.05,NormalizeDouble(Ask,d),3,stoploss,takeprofit,"htfs-b");

}

void OpenShort() {
      int d=Digits;
      double p=Point;

      double stoploss=NormalizeDouble(Ask+2400*Point,Digits);
      double takeprofit=NormalizeDouble(Ask-50*Point,Digits); 
      if (High[1] > Bid) OrderSend(Symbol(),OP_SELLLIMIT,0.05,High[1],3,stoploss,takeprofit,"htfs-sll");
      else OrderSend(Symbol(),OP_SELL,0.05,NormalizeDouble(Bid,d),3,stoploss,takeprofit,"htfs-s");
}
*/


void OpenLong() {
    int d=Digits;
    double p=Point;
    
    double stoploss=NormalizeDouble(Bid-2400*Point,Digits); //USDZAR 9000
    double takeprofit=NormalizeDouble(Bid+50*Point,Digits); //USDZAR 2200
    
    double target = NormalizeDouble(High[1]+35*p,d);
    //double distance = MathAbs(Ask - target);
    //if(distance < (MarketInfo(Symbol(), MODE_STOPLEVEL) + 5)*p) {
    //    target = Ask + (MarketInfo(Symbol(), MODE_STOPLEVEL) + 5)*p;
    //}
    
    //double spips = (MarketInfo(Symbol(), MODE_STOPLEVEL) + 5)*p;
    //Print("target: ", target, " stoplevel + 5 pips: ", spips);
    
    if (High[1] > Ask) OrderSend(Symbol(),OP_BUYSTOP,0.05,NormalizeDouble(target, d),3,stoploss,NormalizeDouble(takeprofit+10*p,d),"htfs-bll");
//      else OrderSend(Symbol(),OP_BUY,0.04,NormalizeDouble(Ask,d),3,stoploss,takeprofit,"htfs-b");

}

void OpenShort() {
      int d=Digits;
      double p=Point;

      double stoploss=NormalizeDouble(Ask+2400*Point,Digits);
      double takeprofit=NormalizeDouble(Ask-50*Point,Digits);
      
      //double distance
       
      if (Low[1] < Bid) OrderSend(Symbol(),OP_SELLSTOP,0.05,NormalizeDouble(Low[1]-35*p,d),3,stoploss,NormalizeDouble(takeprofit-10*p,d),"htfs-sll");
//      else OrderSend(Symbol(),OP_SELL,0.04,NormalizeDouble(Bid,d),3,stoploss,takeprofit,"htfs-s");
}
