
#property copyright "GVC"
#property link      "http://www.metaquotes.net"
#property version   "1.00"
#property strict
#include <stdlib.mqh>
#include <WinUser32.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

#define BullColor Lime
#define BearColor Red

enum dbu {Constant=0,OneMinute=1,FiveMinutes=5};
enum strp {Daily=0,Weekly=1};

input bool   UseDefaultPairs  = true; // Use the default 28 pairs
input string OwnPairs         = ""; // Comma seperated own pair list
input dbu DashUpdate          = 1; // Dashboard update interval
input int    Magic_Number     = 2346;
input double lot              = 0.01;
input bool autotrade          = false;
input int MaxTrades           = 3; // Max trades per pair
input int MaxTotalTrades      = 0; // Max total trades overall
extern int MaxSpread          = 4.0;
input int  Basket_Target      = 0; 
input double BasketP1         = 90.0; // At profit 1
input double BasketL1         = 30.0; // Lock 1
input double BasketP2         = 200.0; // At profit 2
input double BasketL2         = 100.0; // Lock 2
input double BasketP3         = 300.0; // At profit 3
input double BasketL3         = 200.0; // Lock 3
input double BasketP4         = 500.0; // At profit 4
input double BasketL4         = 350.0; // Lock 4
input double BasketP5         = 700.0; // At profit 5
input double BasketL5         = 600.0; // Lock 5
input double BasketP6         = 1000.0; // At profit 6
input double BasketL6         = 900.0; // Lock 6
input bool TrailLastLock      = false; // Trail the last set lock
input double TrailDistance    = 0.0; // Trail distance 0 means last lock
input int  Basket_StopLoss    = 0;
extern int StopProfit = 0; // Stop after this many profitable baskets
extern double Adr1tp = 0; // Takeprofit percent adr(10) 0=None
extern double Adr1sl = 0; // Stoploss adr percent adr(10) 0 = None
extern int StopLoss = 0; // Stop after this many losing baskets baskets
extern bool UseRSI = false; // Use RSI to select
extern bool UseCCI = false; // Use CCI to select
extern bool UseHheatMap = false; //Use Heat Map
extern strp StrengthPeriod = 0; // Calculate strength over period...
input bool OnlyAddProfit = false;
input bool CloseAllSession = false; // Close all trades after session(s)
input bool UseSession1 = true;
input string sess1start = "00:00";
input string sess1end = "23:59";
input string sess1comment = "AUTO SESS1";
input bool UseSession2 = false;
input string sess2start = "00:00";
input string sess2end = "23:59";
input string sess2comment = "AUTO SESS2";
input bool UseSession3 = false;
input string sess3start = "00:00";
input string sess3end = "23:59";
input string sess3comment = "AUTO SESS3";
input ENUM_TIMEFRAMES TimeFrame  = 1440; //TimeFrame to open chart
extern string usertemplate = "Dash";
input int   x_axis            =0;
input int   y_axis            =50;
extern bool mChngCol = true;     // Change box colour according to value

string button_close_basket_All = "btn_Close ALL"; 
string button_close_basket_Prof = "btn_Close Prof";
string button_close_basket_Loss = "btn_Close Loss";; 
 
string DefaultPairs[] = {"AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD","CADCHF","CADJPY","CHFJPY","EURAUD","EURCAD","EURCHF","EURGBP","EURJPY","EURNZD","EURUSD","GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD","GBPUSD","NZDCAD","NZDCHF","NZDJPY","NZDUSD","USDCAD","USDCHF","USDJPY"};
string TradePairs[];

string   _font="Consolas";

struct pairinf {
   double PairPip;
   int pipsfactor;
   double Pips;
   double Spread;
   double point;
   int lastSignal;
}; pairinf pairinfo[];

#define NONE 0
#define DOWN -1
#define UP 1

#define NOTHING 0
#define BUY 1
#define SELL 2

struct signal {
   double Signalm1;
   double Signalm5;
   double Signalm15;
   double Signalm30;
   double Signalh1;
   double Signalh4;
   double Signald1;
   double Signalw1;
   double Signalmn;
   double Signalhah4;
   double Signalperc;
   double Signalhad1;
   double Signaltc;
   double Signalcc;
   double Signalusd;
   double prevSignalusd;
   double buystrength;
   double sellstrength;
   
}; signal signals[];

double totalbuystrength,totalsellstrength;

color ProfitColor,ProfitColor1,ProfitColor2,ProfitColor3,PipsColor,Color,Color1,Color2,Color3,Color4,Color5,Color6,Color7,Color8,Color9,Color10,
      Color11,Color12,LotColor,LotColor1,OrdColor,OrdColor1;
color BackGrnCol =C'20,20,20';
color LineColor=clrBlack;
color TextColor=clrBlack;

struct adrval {
   double adr;
   double adr1;
   double adr5;
   double adr10;
   double adr20;
}; adrval adrvalues[];

double totalprofit,totallots;

datetime s1start,s2start,s3start;
datetime s1end,s2end,s3end;

string comment;
int strper = PERIOD_W1;
int profitbaskets = 0;
int lossbaskets = 0;
int ticket;
int    orders  = 0;
double blots[28],slots[28],bprofit[28],sprofit[28],tprofit[28],bpos[28],spos[28];
bool CloseAll;
string postfix=StringSubstr(Symbol(),6,6);
int   symb_cnt=0;
int period1[]= {240,1440,10080};
double factor;
int labelcolor,labelcolor1,labelcolor2=clrNONE,labelcolor3,labelcolor4,labelcolor5,labelcolor6,labelcolor7,
    labelcolor8,labelcolor9,labelcolor10,labelcolor11; 
double GetBalanceSymbol,SymbolMaxDD,SymbolMaxHi;
double PercentFloatingSymbol=0;
double PercentMaxDDSymbol=0;
datetime newday=0;
datetime newm1=0; 
/* HP */
int localday = 99;
bool s1active = false;
bool s2active = false;
bool s3active = false;
MqlDateTime sess;
string strspl[];
double currentlock = 0.0;
bool trailstarted = false;
double lockdistance = 0.0;
int totaltrades = 0;
int maxtotaltrades=0;
double stoploss;
double takeprofit;
/* HP */
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {   
                  
    if (UseDefaultPairs == true)
      ArrayCopy(TradePairs,DefaultPairs);
    else
      StringSplit(OwnPairs,',',TradePairs);
   
   if (ArraySize(TradePairs) <= 0) {
      Print("No pairs to trade");
      return(INIT_FAILED);
   }
   
   ArrayResize(adrvalues,ArraySize(TradePairs));
   ArrayResize(signals,ArraySize(TradePairs));
   ArrayResize(pairinfo,ArraySize(TradePairs));
               
   if (StrengthPeriod == 0)
      strper = PERIOD_D1;

    for(int i=0;i<ArraySize(TradePairs);i++){
    TradePairs[i]=TradePairs[i]+postfix;

      if (MarketInfo(TradePairs[i] ,MODE_DIGITS) == 4 || MarketInfo(TradePairs[i] ,MODE_DIGITS) == 2) {
         pairinfo[i].PairPip = MarketInfo(TradePairs[i] ,MODE_POINT);
         pairinfo[i].pipsfactor = 1;
      } else { 
         pairinfo[i].PairPip = MarketInfo(TradePairs[i] ,MODE_POINT)*10;
         pairinfo[i].pipsfactor = 10;
      }
       for(int a=0;a<5;a++)
         SetPanel("BP",0,x_axis-1,y_axis-3,1100,451,C'30,30,30',C'61,61,61',1);
         SetPanel("Bar",0,x_axis,y_axis-30,1100,27,Maroon,LineColor,1);        
//SetPanel("Panel"+IntegerToString(i),0,x_axis,(i*16)+y_axis,68,15,labelcolor,LineColor,1);         
         SetPanel("Spread"+IntegerToString(i),0,x_axis+70,(i*16)+y_axis-2,30,17,labelcolor,C'61,61,61',1);
         SetPanel("Pips"+IntegerToString(i),0,x_axis+101,(i*16)+y_axis-2,35,17,labelcolor,C'61,61,61',1);
         SetPanel("Adr"+IntegerToString(i),0,x_axis+137,(i*16)+y_axis-2,40,17,labelcolor,C'61,61,61',1);
         SetPanel("m1"+IntegerToString(i),0,x_axis+180,(i*16)+y_axis,45,15,BackGrnCol,C'61,61,61',1);
        // SetPanel("m5"+IntegerToString(i),0,x_axis+205,(i*16)+y_axis,20,15,Color1,White,1);
         SetPanel("m15"+IntegerToString(i),0,x_axis+230,(i*16)+y_axis,20,15,Color2,White,1);
         SetPanel("m30"+IntegerToString(i),0,x_axis+255,(i*16)+y_axis,20,15,Color3,White,1);
         SetPanel("h1"+IntegerToString(i),0,x_axis+280,(i*16)+y_axis,20,15,Color4,White,1);
         SetPanel("h4"+IntegerToString(i),0,x_axis+305,(i*16)+y_axis,20,15,Color5,White,1);
         SetPanel("d1"+IntegerToString(i),0,x_axis+330,(i*16)+y_axis,20,15,Color6,White,1);
         SetPanel("w1"+IntegerToString(i),0,x_axis+355,(i*16)+y_axis,20,15,Color7,White,1);
         SetPanel("mn1"+IntegerToString(i),0,x_axis+380,(i*16)+y_axis,20,15,Color8,White,1);
         for(int a=0;a<5;a++){
         SetPanel("ha4"+IntegerToString(i)+IntegerToString(a),0,(a*20)+x_axis+410,(i*16)+y_axis-2,20,17,labelcolor,C'61,61,61',1);}
        // SetPanel("had1"+IntegerToString(i),0,x_axis+430,(i*16)+y_axis-2,20,17,labelcolor,C'61,61,61',1);
        // SetPanel("tc"+IntegerToString(i),0,x_axis+450,(i*16)+y_axis-2,20,17,labelcolor,C'61,61,61',1);
         SetPanel("TP",0,x_axis+1040,y_axis-27,55,20,Black,White,1);
         SetPanel("TP1",0,x_axis+220,y_axis-50,125,20,Black,White,1);
         SetPanel("TP2",0,x_axis+345,y_axis-50,160,20,Black,White,1);
         SetPanel("TP3",0,x_axis+505,y_axis-50,160,20,Black,White,1);
         SetPanel("TP4",0,x_axis+665,y_axis-50,130,20,Black,White,1);
         SetPanel("TP5",0,x_axis+795,y_axis-50,130,20,Black,White,1);
         SetPanel("TP6",0,x_axis+95,y_axis-50,100,20,Black,White,1);
         SetPanel("TP7",0,x_axis+921,y_axis-50,130,20,Black,White,1);
         SetPanel("TP8",0,x_axis+1051,y_axis-50,22,20,Black,White,1);
         SetPanel("TP9",0,x_axis+1073,y_axis-50,22,20,Black,White,1);
         SetPanel("A1"+IntegerToString(i),0,x_axis+695,(i*16)+y_axis-2,36,17,labelcolor,C'61,61,61',1);
         SetPanel("A2"+IntegerToString(i),0,x_axis+731,(i*16)+y_axis-2,265,17,C'30,30,30',C'61,61,61',1);          
         SetPanel("A3"+IntegerToString(i),0,x_axis+834,(i*16)+y_axis-2,265,17,C'30,30,30',C'61,61,61',1);   
         SetPanel("B1"+IntegerToString(i),0,x_axis+730,(i*16)+y_axis+3,5,12,labelcolor1,labelcolor2,1);
         SetPanel("B2"+IntegerToString(i),0,x_axis+735,(i*16)+y_axis+3,5,12,labelcolor3,labelcolor2,1);
         SetPanel("B3"+IntegerToString(i),0,x_axis+740,(i*16)+y_axis+3,5,12,labelcolor4,labelcolor2,1);
         SetPanel("B4"+IntegerToString(i),0,x_axis+745,(i*16)+y_axis+3,5,12,labelcolor5,labelcolor2,1);
         SetPanel("B5"+IntegerToString(i),0,x_axis+750,(i*16)+y_axis+3,5,12,labelcolor6,labelcolor2,1);
         SetPanel("B6"+IntegerToString(i),0,x_axis+755,(i*16)+y_axis+3,5,12,labelcolor7,labelcolor2,1);
         SetPanel("B7"+IntegerToString(i),0,x_axis+760,(i*16)+y_axis+3,5,12,labelcolor8,labelcolor2,1);
         SetPanel("B8"+IntegerToString(i),0,x_axis+765,(i*16)+y_axis+3,5,12,labelcolor9,labelcolor2,1);
         SetPanel("B9"+IntegerToString(i),0,x_axis+770,(i*16)+y_axis+3,5,12,labelcolor10,labelcolor2,1);
         SetPanel("B10"+IntegerToString(i),0,x_axis+775,(i*16)+y_axis+3,5,12,labelcolor11,labelcolor2,1);
         SetPanel("DIR"+IntegerToString(i),0,x_axis+675,(i*16)+y_axis-2,20,17,labelcolor,C'61,61,61',1);

         SetText("Spr1"+IntegerToString(i),0,x_axis+72,(i*16)+y_axis,Orange,8);
         SetText("Pp1"+IntegerToString(i),0,x_axis+103,(i*16)+y_axis,PipsColor,8);
         SetText("S1"+IntegerToString(i),0,x_axis+143,(i*16)+y_axis,Yellow,8);
         SetText("bLots"+IntegerToString(i),DoubleToStr(blots[i],2),x_axis+840,(i*16)+y_axis,LotColor,8);
         SetText("sLots"+IntegerToString(i),DoubleToStr(slots[i],2),x_axis+880,(i*16)+y_axis,LotColor1,8);
         SetText("bPos"+IntegerToString(i),DoubleToStr(bpos[i],0),x_axis+920,(i*16)+y_axis,OrdColor,8);
         SetText("sPos"+IntegerToString(i),DoubleToStr(spos[i],0),x_axis+940,(i*16)+y_axis,OrdColor1,8);
         SetText("TProf"+IntegerToString(i),DoubleToStr(MathAbs(bprofit[i]),2),x_axis+970,(i*16)+y_axis,ProfitColor,8);
         SetText("SProf"+IntegerToString(i),DoubleToStr(MathAbs(sprofit[i]),2),x_axis+1010,(i*16)+y_axis,ProfitColor2,8);
         SetText("TtlProf"+IntegerToString(i),DoubleToStr(MathAbs(tprofit[i]),2),x_axis+1060,(i*16)+y_axis,ProfitColor3,8);
         SetText("TotProf",DoubleToStr(MathAbs(totalprofit),2),x_axis+1043,y_axis-22,ProfitColor1,8);
         SetText("usdintsig"+IntegerToString(i),DoubleToStr(MathAbs(signals[i].Signalusd),0)+"%",x_axis+700,(i*16)+y_axis+1,Color9,8);
         SetText("Lowest","Lowest= "+DoubleToStr(SymbolMaxDD,2)+" ("+DoubleToStr(PercentMaxDDSymbol,2)+"%)",x_axis+670,y_axis-47,BearColor,8);
         SetText("Highest","Highest= "+DoubleToStr(SymbolMaxHi,2)+" ("+DoubleToStr(PercentFloatingSymbol,2)+"%)",x_axis+800,y_axis-47,BullColor,8);
         SetText("Lock","Lock= "+DoubleToStr(currentlock,2),x_axis+925,y_axis-47,BullColor,8);
         SetText("Won",IntegerToString(profitbaskets,2),x_axis+1053,y_axis-47,BullColor,8);
         SetText("Lost",IntegerToString(lossbaskets,2),x_axis+1075,y_axis-47,BearColor,8);
         SetText("Percent"+IntegerToString(i),DoubleToStr(signals[i].Signalperc,2)+"%",x_axis+185,(i*16)+y_axis,Color12,8);

         SetText("Pr1"+IntegerToString(i),TradePairs[i],x_axis+780,(i*16)+y_axis,clrWhite,7);       
         SetText("TPr","Basket TakeProfit =$ "+DoubleToStr(Basket_Target,0),x_axis+378,y_axis-47,Yellow,8);
         SetText("SL","Basket StopLoss =$ -"+DoubleToStr(Basket_StopLoss,0),x_axis+538,y_axis-47,Yellow,8);
         SetText("Symbol","Symbol        Spread   Pips     ADR",x_axis+4,y_axis-25,White,8);
         SetText("Direct","Candle Direction",x_axis+270,y_axis-30,White,8);
         SetText("Trend","  Map      M15  M30   H1    H4    D1   W1   MN",x_axis+183,y_axis-17,White,8);
         SetText("Signal","Signal",x_axis+440,y_axis-30,White,8);
         SetText("MA","H4   D1 RSI CCI",x_axis+413,y_axis-17,White,8);
         SetText("Trades","Buy       Sell     Buy  Sell      Buy      Sell",x_axis+840,y_axis-17,White,8);
         SetText("TTr","Lots           Orders",x_axis+860,y_axis-30,White,8);
         SetText("Tottrade","Profit",x_axis+980,y_axis-30,White,8);
         SetText("PerChange","  Heat",x_axis+183,y_axis-30,White,8);
        
         Create_Button(IntegerToString(i)+"Pair",TradePairs[i],70 ,14,x_axis+2 ,(i*16)+y_axis,clrDarkGray,LineColor);
         Create_Button(i+"BUY","BUY",50 ,15,x_axis+520,(i*16)+y_axis,clrRoyalBlue,clrWhite);           
         Create_Button(i+"SELL","SELL",50 ,15,x_axis+570 ,(i*16)+y_axis,clrGoldenrod,clrWhite);
         Create_Button(i+"CLOSE","CLOSE",50 ,15,x_axis+620 ,(i*16)+y_axis,clrRed,clrWhite);
   }

   Create_Button(button_close_basket_All,"CLOSE ALL",90 ,18,x_axis+530 ,y_axis-25,clrDarkGray,clrWhite);
   Create_Button(button_close_basket_Prof,"CLOSE PROFIT",90 ,18,x_axis+630 ,y_axis-25,clrDarkGray,clrGreenYellow);
   Create_Button(button_close_basket_Loss,"CLOSE LOSS",90 ,18,x_axis+730 ,y_axis-25,clrDarkGray,clrRed);

   newday = 0;
   newm1=0;

/*  HP  */
   localday = 99;
   s1active = false;
   s2active = false;
   s3active = false;
   trailstarted = false;

   if (MaxTotalTrades == 0)
      maxtotaltrades = ArraySize(TradePairs) * MaxTrades;
   else
      maxtotaltrades = MaxTotalTrades;
/*  HP  */

   EventSetTimer(1);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   ObjectsDeleteAll();
      
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {

   Trades();

   TradeManager();

   PlotTrades();

   PlotSpreadPips();

      GetSignals();

      Geth4d1();
      
      GetTrendChange();
      
      GetCommodity();
      
      //ChngBoxCol(0,0);

   if (newday != iTime("EURUSD"+postfix,PERIOD_D1,0)) {
      GetAdrValues();
      PlotAdrValues();
      newday = iTime("EURUSD"+postfix,PERIOD_D1,0);
   }
          
   if (DashUpdate == 0 || (DashUpdate == 1 && newm1 != iTime("EURUSD"+postfix,PERIOD_M1,0)) || (DashUpdate == 5 && newm1 != iTime("EURUSD"+postfix,PERIOD_M5,0))) {

      
   for(int i=0;i<ArraySize(TradePairs);i++) 
   for(int a=0;a<5;a++){
      SetColors(i);
      if(mChngCol)
           ChngBoxCol((signals[i].Signalperc * 100), i);
              
      if(signals[i].Signalhah4==UP){SetObjText("Sig"+IntegerToString(i),CharToStr(233),x_axis+415,(i*16)+y_axis,BullColor,9);}
      if(signals[i].Signalhah4==DOWN){SetObjText("Sig"+IntegerToString(i),CharToStr(234),x_axis+415,(i*16)+y_axis+2,BearColor,9);}
      if(signals[i].Signalhad1==UP){SetObjText("SGD"+IntegerToString(i),CharToStr(233),x_axis+435,(i*16)+y_axis,BullColor,9);}
      if(signals[i].Signalhad1==DOWN){SetObjText("SGD"+IntegerToString(i),CharToStr(234),x_axis+435,(i*16)+y_axis+2,BearColor,9);}
      if(signals[i].Signaltc==UP){SetObjText("TC"+IntegerToString(i),CharToStr(233),x_axis+455,(i*16)+y_axis,BullColor,9);}
      if(signals[i].Signaltc==DOWN){SetObjText("TC"+IntegerToString(i),CharToStr(234),x_axis+455,(i*16)+y_axis+2,BearColor,9);}
      if(signals[i].Signalcc==UP){SetObjText("CCI"+IntegerToString(i),CharToStr(233),x_axis+475,(i*16)+y_axis,BullColor,9);}
      if(signals[i].Signalcc==DOWN){SetObjText("CCI"+IntegerToString(i),CharToStr(234),x_axis+475,(i*16)+y_axis+2,BearColor,9);}
      
      SetText("Percent"+IntegerToString(i),DoubleToStr(signals[i].Signalperc,2)+"%",x_axis+185,(i*16)+y_axis,clrBlack,8);
     
      if(MathAbs(signals[i].Signalusd)>MathAbs(signals[i].prevSignalusd)){SetObjText("SD"+IntegerToString(i),CharToStr(216),x_axis+680,(i*16)+y_axis,BullColor,9);}
      if(MathAbs(signals[i].Signalusd)<MathAbs(signals[i].prevSignalusd)){SetObjText("SD"+IntegerToString(i),CharToStr(215),x_axis+680,(i*16)+y_axis,BearColor,9);}
      if(signals[i].Signalusd==signals[i].prevSignalusd){SetObjText("SD"+IntegerToString(i),"",x_axis+680,(i*16)+y_axis,clrWhite,9);}
      ObjectSetText("usdintsig"+IntegerToString(i),DoubleToStr(MathAbs( signals[i].Signalusd),0)+"%",8,NULL,Color9);
         
      if (pairinfo[i].Pips>20&&signals[i].Signalusd>80.0&&signals[i].Signalm1==UP&&signals[i].Signalm5==UP&&signals[i].Signalm15==UP&&signals[i].Signalm30==UP&&signals[i].Signalh1==UP&&signals[i].Signalh4==UP&&signals[i].Signald1==UP&&signals[i].Signalw1==UP&&signals[i].Signalmn==UP&&signals[i].Signalhah4==UP&&signals[i].Signalhad1==UP&&(signals[i].Signaltc == UP || UseRSI==false)&&(signals[i].Signalcc == UP || UseCCI==false)&&(signals[i].Signalperc >0.5 || UseHheatMap==false)) {
         labelcolor = clrGreen;
         if ((bpos[i]+spos[i]) < MaxTrades && pairinfo[i].lastSignal != BUY && autotrade == true && (OnlyAddProfit == false || bprofit[i] >= 0.0) && pairinfo[i].Spread <= MaxSpread && inSession() == true && totaltrades <= maxtotaltrades) {
            pairinfo[i].lastSignal = BUY;
            ticket=OrderSend(TradePairs[i],OP_BUY,lot,MarketInfo(TradePairs[i],MODE_ASK),100,0,0,comment,Magic_Number,0,Blue);
            if (OrderSelect(ticket,SELECT_BY_TICKET) == true) {
               stoploss = OrderOpenPrice() - ((adrvalues[i].adr10 / 100) * Adr1sl) * pairinfo[i].PairPip;
               takeprofit = OrderOpenPrice() + ((adrvalues[i].adr10 / 100) * Adr1tp) * pairinfo[i].PairPip;
               OrderModify(ticket,OrderOpenPrice(),NormalizeDouble(stoploss,MarketInfo(TradePairs[i],MODE_DIGITS)),NormalizeDouble(takeprofit,MarketInfo(TradePairs[i],MODE_DIGITS)),0,clrBlue);
            }
         }
      } else {
         if (pairinfo[i].Pips<-20&&signals[i].Signalusd<-80.0&&signals[i].Signalm1==DOWN&&signals[i].Signalm5==DOWN&&signals[i].Signalm15==DOWN&&signals[i].Signalm30==DOWN&&signals[i].Signalh1==DOWN&&signals[i].Signalh4==DOWN&&signals[i].Signald1==DOWN&&signals[i].Signalw1==DOWN&&signals[i].Signalmn==DOWN&&signals[i].Signalhah4==DOWN&&signals[i].Signalhad1==DOWN&&(signals[i].Signaltc == DOWN || UseRSI==false)&&(signals[i].Signalcc == DOWN || UseCCI==false)&&(signals[i].Signalperc <-0.5 || UseHheatMap==false)) {
            labelcolor = clrFireBrick;
            if ((bpos[i]+spos[i]) < MaxTrades && pairinfo[i].lastSignal != SELL && autotrade == true && (OnlyAddProfit == false || sprofit[i] >= 0.0) && pairinfo[i].Spread <= MaxSpread && inSession() == true && totaltrades <= maxtotaltrades) {
               pairinfo[i].lastSignal = SELL;
               ticket=OrderSend(TradePairs[i],OP_SELL,lot,MarketInfo(TradePairs[i],MODE_BID),100,0,0,comment,Magic_Number,0,Red);
               if (OrderSelect(ticket,SELECT_BY_TICKET) == true) {
                  stoploss = OrderOpenPrice() + ((adrvalues[i].adr10 / 100) * Adr1sl) * pairinfo[i].PairPip;
                  takeprofit = OrderOpenPrice() - ((adrvalues[i].adr10 / 100) * Adr1tp) * pairinfo[i].PairPip;
                  OrderModify(ticket,OrderOpenPrice(),NormalizeDouble(stoploss,MarketInfo(TradePairs[i],MODE_DIGITS)),NormalizeDouble(takeprofit,MarketInfo(TradePairs[i],MODE_DIGITS)),0,clrBlue);
               }
            }
         } else {
            labelcolor = BackGrnCol;
            pairinfo[i].lastSignal = NOTHING;
         }  
      }

//         ColorPanel("BP",C'30,30,30',C'61,61,61',1);
         ColorPanel("Bar",Maroon,LineColor);
         if (labelcolor != BackGrnCol)        
            ColorPanel(IntegerToString(i)+"Pair",labelcolor,clrBlack);        
         else
            ColorPanel(IntegerToString(i)+"Pair",clrGray,clrBlack);        

         //ColorPanel("m1"+IntegerToString(i),clrNONE,Color12);
       //  ColorPanel("m5"+IntegerToString(i),Color1,White);
         ColorPanel("m15"+IntegerToString(i),Color2,White);
         ColorPanel("m30"+IntegerToString(i),Color3,White);
         ColorPanel("h1"+IntegerToString(i),Color4,White);
         ColorPanel("h4"+IntegerToString(i),Color5,White);
         ColorPanel("d1"+IntegerToString(i),Color6,White);
         ColorPanel("w1"+IntegerToString(i),Color7,White);
         ColorPanel("mn1"+IntegerToString(i),Color8,White);
         ColorPanel("Spread"+IntegerToString(i),labelcolor,C'61,61,61');
         ColorPanel("ha4"+IntegerToString(i)+IntegerToString(a),labelcolor,C'61,61,61');
         //ColorPanel("had1"+IntegerToString(i),labelcolor,C'61,61,61');
         //ColorPanel("Percent"+IntegerToString(i),Color12,C'61,61,61');
         ColorPanel("Pips"+IntegerToString(i),labelcolor,C'61,61,61');
         ColorPanel("Adr"+IntegerToString(i),labelcolor,C'61,61,61');
         ColorPanel("DIR"+IntegerToString(i),labelcolor,C'61,61,61');
         ColorPanel("TP",Black,White);
         ColorPanel("TP1",Black,White);
         ColorPanel("TP2",Black,White);
         ColorPanel("TP3",Black,White);
         ColorPanel("TP4",Black,White);
         ColorPanel("TP5",Black,White);
         ColorPanel("A1"+IntegerToString(i),labelcolor,C'61,61,61');
         ColorPanel("A2"+IntegerToString(i),C'30,30,30',C'61,61,61');          
         ColorPanel("A3"+IntegerToString(i),labelcolor,C'61,61,61');   
         ColorPanel("B1"+IntegerToString(i),labelcolor1,labelcolor2);
         ColorPanel("B2"+IntegerToString(i),labelcolor3,labelcolor2);
         ColorPanel("B3"+IntegerToString(i),labelcolor4,labelcolor2);
         ColorPanel("B4"+IntegerToString(i),labelcolor5,labelcolor2);
         ColorPanel("B5"+IntegerToString(i),labelcolor6,labelcolor2);
         ColorPanel("B6"+IntegerToString(i),labelcolor7,labelcolor2);
         ColorPanel("B7"+IntegerToString(i),labelcolor8,labelcolor2);
         ColorPanel("B8"+IntegerToString(i),labelcolor9,labelcolor2);
         ColorPanel("B9"+IntegerToString(i),labelcolor10,labelcolor2);
         ColorPanel("B10"+IntegerToString(i),labelcolor11,labelcolor2);
      }
      if (DashUpdate == 1)
         newm1 = iTime("EURUSD"+postfix,PERIOD_M1,0);
      else if (DashUpdate == 5)
         newm1 = iTime("EURUSD"+postfix,PERIOD_M5,0);
   }
   WindowRedraw();    
}
  
//+------------------------------------------------------------------+

void SetText(string name,string text,int x,int y,color colour,int fontsize=12)
  {
   if (ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

    ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
    ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
    ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
    ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
    ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
    ObjectSetString(0,name,OBJPROP_TEXT,text);
  }
//+------------------------------------------------------------------+

void SetObjText(string name,string CharToStr,int x,int y,color colour,int fontsize=12)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,CharToStr);
   ObjectSetString(0,name,OBJPROP_FONT,"Wingdings");
  }  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetPanel(string name,int sub_window,int x,int y,int width,int height,color bg_color,color border_clr,int border_width)
  {
   if(ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))
     {
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
      ObjectSetInteger(0,name,OBJPROP_COLOR,border_clr);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,border_width);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,0);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,0);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
     }
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg_color);
  }
void ColorPanel(string name,color bg_color,color border_clr)
  {
   ObjectSetInteger(0,name,OBJPROP_COLOR,border_clr);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg_color);
  }
//+------------------------------------------------------------------+
void Create_Button(string but_name,string label,int xsize,int ysize,int xdist,int ydist,int bcolor,int fcolor)
{
    
   if(ObjectFind(0,but_name)<0)
   {
      if(!ObjectCreate(0,but_name,OBJ_BUTTON,0,0,0))
        {
         Print(__FUNCTION__,
               ": failed to create the button! Error code = ",GetLastError());
         return;
        }
      ObjectSetString(0,but_name,OBJPROP_TEXT,label);
      ObjectSetInteger(0,but_name,OBJPROP_XSIZE,xsize);
      ObjectSetInteger(0,but_name,OBJPROP_YSIZE,ysize);
      ObjectSetInteger(0,but_name,OBJPROP_CORNER,CORNER_LEFT_UPPER);     
      ObjectSetInteger(0,but_name,OBJPROP_XDISTANCE,xdist);      
      ObjectSetInteger(0,but_name,OBJPROP_YDISTANCE,ydist);         
      ObjectSetInteger(0,but_name,OBJPROP_BGCOLOR,bcolor);
      ObjectSetInteger(0,but_name,OBJPROP_COLOR,fcolor);
      ObjectSetInteger(0,but_name,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,but_name,OBJPROP_HIDDEN,true);
      //ObjectSetInteger(0,but_name,OBJPROP_BORDER_COLOR,ChartGetInteger(0,CHART_COLOR_FOREGROUND));
      ObjectSetInteger(0,but_name,OBJPROP_BORDER_TYPE,BORDER_RAISED);
      
      ChartRedraw();      
   }

}
void OnChartEvent(const int id,  const long &lparam, const double &dparam,  const string &sparam)
  {
   if(id==CHARTEVENT_OBJECT_CLICK)
  
      {
      if (sparam==button_close_basket_All)
        {
               ObjectSetString(0,button_close_basket_All,OBJPROP_TEXT,"Closing...");               
               close_basket(Magic_Number);
               ObjectSetInteger(0,button_close_basket_All,OBJPROP_STATE,0);
               ObjectSetString(0,button_close_basket_All,OBJPROP_TEXT,"Close Basket"); 
               return;
        }
//-----------------------------------------------------------------------------------------------------------------     
      if (sparam==button_close_basket_Prof)
        {
               ObjectSetString(0,button_close_basket_Prof,OBJPROP_TEXT,"Closing...");               
               close_profit();
               ObjectSetInteger(0,button_close_basket_Prof,OBJPROP_STATE,0);
               ObjectSetString(0,button_close_basket_Prof,OBJPROP_TEXT,"Close Basket"); 
               return;
        }
//----------------------------------------------------------------------------------------------------------------- 
      if (sparam==button_close_basket_Loss)
        {
               ObjectSetString(0,button_close_basket_Loss,OBJPROP_TEXT,"Closing...");               
               close_loss();
               ObjectSetInteger(0,button_close_basket_Loss,OBJPROP_STATE,0);
               ObjectSetString(0,button_close_basket_Loss,OBJPROP_TEXT,"Close Basket"); 
               return;
        }
//-----------------------------------------------------------------------------------------------------------------
     if (StringFind(sparam,"BUY") >= 0)
        {
               int ind = StringToInteger(sparam);
               ticket=OrderSend(TradePairs[ind],OP_BUY,lot,MarketInfo(TradePairs[ind],MODE_ASK),100,0,0,"OFF",Magic_Number,0,Blue);
               if (OrderSelect(ticket,SELECT_BY_TICKET) == true) {
                  stoploss = OrderOpenPrice() - ((adrvalues[ind].adr10 / 100) * Adr1sl) * pairinfo[ind].PairPip;
                  takeprofit = OrderOpenPrice() + ((adrvalues[ind].adr10 / 100) * Adr1tp) * pairinfo[ind].PairPip;
                  OrderModify(ticket,OrderOpenPrice(),NormalizeDouble(stoploss,MarketInfo(TradePairs[ind],MODE_DIGITS)),NormalizeDouble(takeprofit,MarketInfo(TradePairs[ind],MODE_DIGITS)),0,clrBlue);
               }
               ObjectSetInteger(0,ind+"BUY",OBJPROP_STATE,0);
               ObjectSetString(0,ind+"BUY",OBJPROP_TEXT,"BUY"); 
               return;
        }
     if (StringFind(sparam,"SELL") >= 0)
        {
               int ind = StringToInteger(sparam);
               ticket=OrderSend(TradePairs[ind],OP_SELL,lot,MarketInfo(TradePairs[ind],MODE_BID),100,0,0,"OFF",Magic_Number,0,Red);
               if (OrderSelect(ticket,SELECT_BY_TICKET) == true) {
                  stoploss = OrderOpenPrice() + ((adrvalues[ind].adr10 / 100) * Adr1sl) * pairinfo[ind].PairPip;
                  takeprofit = OrderOpenPrice() - ((adrvalues[ind].adr10 / 100) * Adr1tp) * pairinfo[ind].PairPip;
                  OrderModify(ticket,OrderOpenPrice(),NormalizeDouble(stoploss,MarketInfo(TradePairs[ind],MODE_DIGITS)),NormalizeDouble(takeprofit,MarketInfo(TradePairs[ind],MODE_DIGITS)),0,clrBlue);
               }
               ObjectSetInteger(0,ind+"SELL",OBJPROP_STATE,0);
               ObjectSetString(0,ind+"SELL",OBJPROP_TEXT,"SELL");
               return;
        }
     if (StringFind(sparam,"CLOSE") >= 0)
        {
               int ind = StringToInteger(sparam);
               closeOpenOrders(TradePairs[ind]);               
               ObjectSetInteger(0,ind+"CLOSE",OBJPROP_STATE,0);
               ObjectSetString(0,ind+"CLOSE",OBJPROP_TEXT,"CLOSE");
               return;
        }
         
      if (StringFind(sparam,"Pair") >= 0) {
         int ind = StringToInteger(sparam);
         ObjectSetInteger(0,sparam,OBJPROP_STATE,0);
         OpenChart(ind);
         return;         
      }   
     }
}
//+------------------------------------------------------------------+
//| closeOpenOrders                                                  |
//+------------------------------------------------------------------+
void closeOpenOrders(string currency ) {
   int cnt = 0;

   for (cnt = OrdersTotal()-1 ; cnt >= 0 ; cnt--) {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)==true) {
         if(OrderType()==OP_BUY && OrderSymbol() == currency && OrderMagicNumber()==Magic_Number)
            ticket=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),5,Violet);
         else if(OrderType()==OP_SELL && OrderSymbol() == currency && OrderMagicNumber()==Magic_Number) 
            ticket=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),5,Violet);
         else if(OrderType()>OP_SELL) //pending orders
            ticket=OrderDelete(OrderTicket());
                   
      }
   }
}
void close_basket(int magic_number)
{ 
  
if (OrdersTotal() <= 0)
   return;

int TradeList[][2];
int ctTrade = 0;

for (int i=0; i<OrdersTotal(); i++) {
	OrderSelect(i, SELECT_BY_POS);
   if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)==true && (OrderType()==0 || OrderType()==1) && OrderMagicNumber()==Magic_Number) {
	   ctTrade++;
		ArrayResize(TradeList, ctTrade);
		TradeList[ctTrade-1][0] = OrderOpenTime();
		TradeList[ctTrade-1][1] = OrderTicket();
	}
}
ArraySort(TradeList,WHOLE_ARRAY,0,MODE_ASCEND);

for (int i=0;i<ctTrade;i++) {
      
       if (OrderSelect(TradeList[i][1], SELECT_BY_TICKET)==true) {
            if (OrderType()==0)
               {
               ticket=OrderClose(OrderTicket(),OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), 3,Red);
               if (ticket==-1) Print ("Error: ",  GetLastError());
               
               }
            if (OrderType()==1)
               {
               ticket=OrderClose(OrderTicket(),OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), 3,Red);
               if (ticket==-1) Print ("Error: ",  GetLastError());
               
               }  
            }
      }
  
   for (int i=0;i<ArraySize(TradePairs);i++)
      pairinfo[i].lastSignal = NOTHING;    
}
void close_profit()
{
 int cnt = 0; 
 for (cnt = OrdersTotal()-1 ; cnt >= 0 ; cnt--)
            {
               if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)==true)
               if (OrderProfit() > 0)
               {
                  if(OrderType()==OP_BUY && OrderMagicNumber()==Magic_Number)
                     ticket=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),5,Violet);
                  if(OrderType()==OP_SELL && OrderMagicNumber()==Magic_Number) 
                     ticket=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),5,Violet);
                  if(OrderType()>OP_SELL)
                     ticket=OrderDelete(OrderTicket());
               }
            } 
    }
void close_loss()
{
 int cnt = 0; 
 for (cnt = OrdersTotal()-1 ; cnt >= 0 ; cnt--)
            {
               if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)==true)
               if (OrderProfit() < 0)
               {
                  if(OrderType()==OP_BUY && OrderMagicNumber()==Magic_Number)
                     ticket=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),5,Violet);
                  if(OrderType()==OP_SELL && OrderMagicNumber()==Magic_Number) 
                     ticket=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),5,Violet);
                  if(OrderType()>OP_SELL)
                     ticket=OrderDelete(OrderTicket());
               }
            } 
    }                            
//+------------------------------------------------------------------+
void Trades()
{
   int i, j;
   totallots=0;
   totalprofit=0;
   totaltrades = 0;

   for(i=0;i<ArraySize(TradePairs);i++)
   {
      
      bpos[i]=0;
      spos[i]=0;       
      blots[i]=0;
      slots[i]=0;     
      bprofit[i]=0;
      sprofit[i]=0;
      tprofit[i]=0;
   }
	for(i=0;i<OrdersTotal();i++)
	{
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
         break;

      for(j=0;j<ArraySize(TradePairs);j++)
      {	  
         if((TradePairs[j]==OrderSymbol() || TradePairs[j]=="") && OrderMagicNumber()==Magic_Number)
         {
            TradePairs[j]=OrderSymbol();                       
            tprofit[j]=tprofit[j]+OrderProfit()+OrderSwap()+OrderCommission();
           if(OrderType()==0){ bprofit[j]+=OrderProfit()+OrderSwap()+OrderCommission(); } 
           if(OrderType()==1){ sprofit[j]+=OrderProfit()+OrderSwap()+OrderCommission(); } 
           if(OrderType()==0){ blots[j]+=OrderLots(); } 
           if(OrderType()==1){ slots[j]+=OrderLots(); }
           if(OrderType()==0){ bpos[j]+=+1; } 
           if(OrderType()==1){ spos[j]+=+1; } 
                                
            totallots=totallots+OrderLots();
            totaltrades++;
            totalprofit = totalprofit+OrderProfit()+OrderSwap()+OrderCommission();
            break;
	     }
	  }
   }
   if(OrdersTotal()==0)
      SetText("CTP","No Trades To Monitor",x_axis+225,y_axis-47,Yellow,8);
   else
      SetText("CTP","Monitoring Trades",x_axis+228,y_axis-47,Yellow,8);

   if (inSession() == true)
      SetText("CTPT","Trading",x_axis+99,y_axis-48,Green,9);
   else
      SetText("CTPT","Closed",x_axis+99,y_axis-48,Red,9);
//         SetPanel("TP6",0,x_axis+95,y_axis-50,100,20,Black,White,1);

   }
//+------------------------------------------------------------------+ 

void OpenChart(int ind) {
long nextchart = ChartFirst();
   do {
      string sym = ChartSymbol(nextchart);
      if (StringFind(sym,TradePairs[ind]) >= 0) {
            ChartSetInteger(nextchart,CHART_BRING_TO_TOP,true);
            ChartSetSymbolPeriod(nextchart,TradePairs[ind],TimeFrame);
            ChartApplyTemplate(nextchart,usertemplate);
            return;
         }
   } while ((nextchart = ChartNext(nextchart)) != -1);
   long newchartid = ChartOpen(TradePairs[ind],TimeFrame);
   ChartApplyTemplate(newchartid,usertemplate);
 }
 void GetAdrValues() {

   double s=0.0;

   for (int i=0;i<ArraySize(TradePairs);i++) {

      for(int a=1;a<=20;a++) {
         if(pairinfo[i].PairPip != 0)
            s=s+(iHigh(TradePairs[i],PERIOD_D1,a)-iLow(TradePairs[i],PERIOD_D1,a))/pairinfo[i].PairPip;
         if(a==1)
            adrvalues[i].adr1=MathRound(s);
         if(a==5)
            adrvalues[i].adr5=MathRound(s/5);
         if(a==10)
            adrvalues[i].adr10=MathRound(s/10);
         if(a==20)
            adrvalues[i].adr20=MathRound(s/20);
      }
      adrvalues[i].adr=MathRound((adrvalues[i].adr1+adrvalues[i].adr5+adrvalues[i].adr10+adrvalues[i].adr20)/4.0);
      s=0.0;
   }
 }
void GetSignals() {

   for (int i=0;i<ArraySize(TradePairs);i++) {
      double Openm1    = iOpen(TradePairs[i], PERIOD_M1,0);
      double Closem1   = iClose(TradePairs[i],PERIOD_M1,0);
      double Openm5    = iOpen(TradePairs[i], PERIOD_M5,0);
      double Closem5   = iClose(TradePairs[i],PERIOD_M5,0);
      double Openm15   = iOpen(TradePairs[i], PERIOD_M15,0);
      double Closem15  = iClose(TradePairs[i],PERIOD_M15,0);
      double Openm30   = iOpen(TradePairs[i], PERIOD_M30,0);
      double Closem30  = iClose(TradePairs[i],PERIOD_M30,0);
      double Openh1    = iOpen(TradePairs[i], PERIOD_H1,0);
      double Closeh1   = iClose(TradePairs[i],PERIOD_H1,0);      
      double Openh4     = iOpen(TradePairs[i], PERIOD_H4,0);
      double Closeh4    = iClose(TradePairs[i],PERIOD_H4,0);
      double Opend     = iOpen(TradePairs[i], PERIOD_D1,0);
      double Closed    = iClose(TradePairs[i],PERIOD_D1,0);
      double Openw     = iOpen(TradePairs[i], PERIOD_W1,0);
      double Closew    = iClose(TradePairs[i],PERIOD_W1,0);
      double Openmn    = iOpen(TradePairs[i], PERIOD_MN1,0);
      double Closemn   = iClose(TradePairs[i],PERIOD_MN1,0);

      
      if(Closem1>Openm1)signals[i].Signalm1=UP;
      if(Closem1<Openm1)signals[i].Signalm1=DOWN;
      if(Closem5>Openm5)signals[i].Signalm5=UP;
      if(Closem5<Openm5)signals[i].Signalm5=DOWN;
      if(Closem15>Openm15)signals[i].Signalm15=UP;
      if(Closem15<Openm15)signals[i].Signalm15=DOWN;
      if(Closem30>Openm30)signals[i].Signalm30=UP;
      if(Closem30<Openm30)signals[i].Signalm30=DOWN;
      if(Closeh1>Openh1)signals[i].Signalh1=UP;
      if(Closeh1<Openh1)signals[i].Signalh1=DOWN;
      if(Closeh4>Openh4)signals[i].Signalh4=UP;
      if(Closeh4<Openh4)signals[i].Signalh4=DOWN;
      if(Closed>Opend)signals[i].Signald1=UP;
      if(Closed<Opend)signals[i].Signald1=DOWN;
      if(Closew>Openw)signals[i].Signalw1=UP;
      if(Closew<Openw)signals[i].Signalw1=DOWN;
      if(Closemn>Openmn)signals[i].Signalmn=UP;
      if(Closemn<Openmn)signals[i].Signalmn=DOWN;
   }
}
void Geth4d1() {

   for (int i=0;i<ArraySize(TradePairs);i++) {
   
      double BB1=iMA(TradePairs[i],PERIOD_H4,12,0,MODE_SMA,PRICE_CLOSE,0);      
      double BB10 = iMA(TradePairs[i], PERIOD_D1,12,0,MODE_SMA,PRICE_CLOSE,0);       
      
      if(iClose(TradePairs[i],PERIOD_H4,0)>BB1 )
         signals[i].Signalhah4=UP;
      if(iClose(TradePairs[i],PERIOD_H4,0)<BB1 )
         signals[i].Signalhah4=DOWN;
      if(iClose(TradePairs[i],PERIOD_D1,0)>BB10 )
         signals[i].Signalhad1=UP;
      if(iClose(TradePairs[i],PERIOD_D1,0)<BB10 )
         signals[i].Signalhad1=DOWN;
         
     signals[i].Signalperc = (iClose(TradePairs[i], 1, 0) - iClose(TradePairs[i], 1440, 1)) / iClose(TradePairs[i], 1440, 1) * 100;    

     signals[i].prevSignalusd = signals[i].Signalusd; 

//     for(int e=0;e<ArraySize(period1);e++) {
    
      double high   = iHigh(TradePairs[i],strper,0);
      double low    = iLow(TradePairs[i],strper,0);
      double close  = iClose(TradePairs[i],strper,0);
      double open   = iOpen(TradePairs[i],strper,0);
      double point  = MarketInfo(TradePairs[i],MODE_POINT);
      double range  = (high-low)*point;
      
//     if (StringFind(TradePairs[i],"JPY",0)!=-1)
//         factor=10;
//     else
//         factor=1000;
           
     if (range*point > 0.0) {
        if (open>close)
            signals[i].Signalusd = MathMin((high-close)/range*point/ (-0.01),100);
          else
            signals[i].Signalusd = MathMin((close-low)/range*point*100,100);                                           
     } else {
         signals[i].Signalusd = signals[i].prevSignalusd;
     }
//   }
  }
}
void TradeManager() {

   double AccBalance=AccountBalance();
         
      //- Target
      if(Basket_Target>0 && totalprofit>=Basket_Target) {
         profitbaskets++;
         close_basket(Magic_Number);
         return;
      }
      
      //- StopLoss
      if(Basket_StopLoss>0 && totalprofit<(0-Basket_StopLoss)) {
         lossbaskets++;
         close_basket(Magic_Number);
         return;
      }

      //- Out off session
      if(inSession() == false && totallots > 0.0 && CloseAllSession == true) {
         close_basket(Magic_Number);
         return;
      }

      //- Profit lock stoploss
      if (currentlock != 0.0 && totalprofit < currentlock) {
         profitbaskets++;
         close_basket(Magic_Number);
         return;
      }

      //- Profit lock trail
      if (trailstarted == true && totalprofit > currentlock + lockdistance)
         currentlock = totalprofit - lockdistance;

      //- Lock in profit 1
      if (BasketP1 != 0.0 && BasketL1 != 0.0 && currentlock < BasketL1) {
         if (totalprofit > BasketP1)
            currentlock = BasketL1;
         if (BasketP2 == 0.0 && TrailLastLock == true) {
            trailstarted = true;
            if (TrailDistance != 0.0)
               lockdistance = BasketP1 - TrailDistance;
            else
               lockdistance = BasketL1;
         }
      }
      //- Lock in profit 2
      if (BasketP2 != 0.0 && BasketL2 != 0.0 && currentlock < BasketL2) {
         if (totalprofit > BasketP2)
            currentlock = BasketL2;
         if (BasketP3 == 0.0 && TrailLastLock == true) {
            trailstarted = true;
            if (TrailDistance != 0.0)
               lockdistance = BasketP2 - TrailDistance;
            else
               lockdistance = BasketL2;
         }
      }
      //- Lock in profit 3
      if (BasketP3 != 0.0 && BasketL3 != 0.0 && currentlock < BasketL3) {
         if (totalprofit > BasketP3)
            currentlock = BasketL3;
         if (BasketP4 == 0.0 && TrailLastLock == true) {
            trailstarted = true;
            if (TrailDistance != 0.0)
               lockdistance = BasketP3 - TrailDistance;
            else
               lockdistance = BasketL3;
         }
      }
      //- Lock in profit 4
      if (BasketP4 != 0.0 && BasketL4 != 0.0 && currentlock < BasketL4) {
         if (totalprofit > BasketP4)
            currentlock = BasketL4;
         if (BasketP5 == 0.0 && TrailLastLock == true) {
            trailstarted = true;
            if (TrailDistance != 0.0)
               lockdistance = BasketP4 - TrailDistance;
            else
               lockdistance = BasketL4;
         }
      }
      //- Lock in profit 5
      if (BasketP5 != 0.0 && BasketL5 != 0.0 && currentlock < BasketL5) {
         if (totalprofit > BasketP5)
            currentlock = BasketL5;
         if (BasketP6 == 0.0 && TrailLastLock == true) {
            trailstarted = true;
            if (TrailDistance != 0.0)
               lockdistance = BasketP5 - TrailDistance;
            else
               lockdistance = BasketL5;
         }
      }
      //- Lock in profit 6
      if (BasketP6 != 0.0 && BasketL6 != 0.0 && currentlock < BasketL6) {
         if (totalprofit > BasketP6)
            currentlock = BasketL6;
         if (TrailLastLock == true) {
            trailstarted = true;
            if (TrailDistance != 0.0)
               lockdistance = BasketP6 - TrailDistance;
            else
               lockdistance = BasketL6;
         }
      }


     if(totalprofit<=SymbolMaxDD) {
        SymbolMaxDD=totalprofit;
        GetBalanceSymbol=AccBalance;
     }

     if(GetBalanceSymbol != 0)
      PercentMaxDDSymbol=(SymbolMaxDD*100)/GetBalanceSymbol;
     
     if(totalprofit>=SymbolMaxHi) {
        SymbolMaxHi=totalprofit;
        GetBalanceSymbol=AccBalance;
     }
     
     if(GetBalanceSymbol != 0)
      PercentFloatingSymbol=(SymbolMaxHi*100)/GetBalanceSymbol;

     ObjectSetText("Lowest","Lowest= "+DoubleToStr(SymbolMaxDD,2)+" ("+DoubleToStr(PercentMaxDDSymbol,2)+"%)",8,NULL,BearColor);
     ObjectSetText("Highest","Highest= "+DoubleToStr(SymbolMaxHi,2)+" ("+DoubleToStr(PercentFloatingSymbol,2)+"%)",8,NULL,BullColor);
     ObjectSetText("Lock","Lock= "+DoubleToStr(currentlock,2),8,NULL,BullColor);
     ObjectSetText("Won",IntegerToString(profitbaskets,2),8,NULL,BullColor);
     ObjectSetText("Lost",IntegerToString(lossbaskets,2),8,NULL,BearColor);

}
void SetColors(int i) {
         if(signals[i].Signalm1==1){Color=BullColor;}
         if(signals[i].Signalm1==-1){Color=BearColor;}
         if(signals[i].Signalm5==1){Color1=BullColor;}         
         if(signals[i].Signalm5==-1){Color1 =BearColor;}
         if(signals[i].Signalm15==1){Color2 =BullColor;}
         if(signals[i].Signalm15==-1){Color2=BearColor;}
         if(signals[i].Signalm30==1){Color3=BullColor;}
         if(signals[i].Signalm30==-1){Color3=BearColor;}
         if(signals[i].Signalh1==1){Color4=BullColor;}
         if(signals[i].Signalh1==-1){Color4=BearColor;}
         if(signals[i].Signalh4==1){Color5=BullColor;}
         if(signals[i].Signalh4==-1){Color5=BearColor;}
         if(signals[i].Signald1==1){Color6=BullColor;}
         if(signals[i].Signald1==-1){Color6=BearColor;}
         if(signals[i].Signalw1==1){Color7=BullColor;}
         if(signals[i].Signalw1==-1){Color7=BearColor;}
         if(signals[i].Signalmn==1){Color8=BullColor;}
         if(signals[i].Signalmn==-1){Color8=BearColor;}
         if(signals[i].Signalusd>0){Color9=BullColor;}
         if(signals[i].Signalusd<0){Color9=BearColor;}
         if(signals[i].Signalperc>0){Color12=BullColor;}
         if(signals[i].Signalperc<0){Color12=BearColor;}
         
        if(signals[i].Signalusd>0.0)labelcolor1=clrDodgerBlue;     
    else if(signals[i].Signalusd<0.0)labelcolor1=clrOrangeRed;
         if(signals[i].Signalusd>10.0)labelcolor3=clrDodgerBlue;     
    else if(signals[i].Signalusd<-10.0)labelcolor3=clrOrangeRed;
         else labelcolor3=C'30,30,30'; 
         if(signals[i].Signalusd>20.0)labelcolor4=clrDodgerBlue;     
    else if(signals[i].Signalusd<-20.0)labelcolor4=clrOrangeRed;
         else labelcolor4=C'30,30,30'; 
         if(signals[i].Signalusd>30.0)labelcolor5=clrDodgerBlue;     
    else if(signals[i].Signalusd<-30.0)labelcolor5=clrOrangeRed;
         else labelcolor5=C'30,30,30'; 
         if(signals[i].Signalusd>40.0)labelcolor6=clrDodgerBlue;     
    else if(signals[i].Signalusd<-40.0)labelcolor6=clrOrangeRed;
         else labelcolor6=C'30,30,30'; 
         if(signals[i].Signalusd>50.0)labelcolor7=clrDodgerBlue;     
    else if(signals[i].Signalusd<-50.0)labelcolor7=clrOrangeRed;
         else labelcolor7=C'30,30,30'; 
         if(signals[i].Signalusd>60.0)labelcolor8=clrDodgerBlue;     
    else if(signals[i].Signalusd<-60.0)labelcolor8=clrOrangeRed;
         else labelcolor8=C'30,30,30'; 
         if(signals[i].Signalusd>70.0)labelcolor9=clrDodgerBlue;     
    else if(signals[i].Signalusd<-70.0)labelcolor9=clrOrangeRed;
         else labelcolor9=C'30,30,30'; 
         if(signals[i].Signalusd>80.0)labelcolor10=clrDodgerBlue;     
    else if(signals[i].Signalusd<-80.0)labelcolor10=clrOrangeRed;
         else labelcolor10=C'30,30,30'; 
         if(signals[i].Signalusd>90.0)labelcolor11=clrDodgerBlue;     
    else if(signals[i].Signalusd<-90.0)labelcolor11=clrOrangeRed;
         else labelcolor11=C'30,30,30';   
}
void PlotTrades() {

   for (int i=0; i<ArraySize(TradePairs);i++) {

     if(blots[i]>0){LotColor =Orange;}        
     if(blots[i]==0){LotColor =clrWhite;}
     if(slots[i]>0){LotColor1 =Orange;}        
     if(slots[i]==0){LotColor1 =clrWhite;}
     if(bpos[i]>0){OrdColor =DodgerBlue;}        
     if(bpos[i]==0){OrdColor =clrWhite;}
     if(spos[i]>0){OrdColor1 =DodgerBlue;}        
     if(spos[i]==0){OrdColor1 =clrWhite;}
     if(bprofit[i]>0){ProfitColor =BullColor;}
     if(bprofit[i]<0){ProfitColor =BearColor;}
     if(bprofit[i]==0){ProfitColor =clrWhite;}
     if(sprofit[i]>0){ProfitColor2 =BullColor;}
     if(sprofit[i]<0){ProfitColor2 =BearColor;}
     if(sprofit[i]==0){ProfitColor2 =clrWhite;}
     if(tprofit[i]>0){ProfitColor3 =BullColor;}
     if(tprofit[i]<0){ProfitColor3 =BearColor;}
     if(tprofit[i]==0){ProfitColor3 =clrWhite;}

     if(totalprofit>0){ProfitColor1 =BullColor;}
     if(totalprofit<0){ProfitColor1 =BearColor;}
     if(totalprofit==0){ProfitColor1 =clrWhite;}         

     ObjectSetText("bLots"+IntegerToString(i),DoubleToStr(blots[i],2),8,NULL,LotColor);
     ObjectSetText("sLots"+IntegerToString(i),DoubleToStr(slots[i],2),8,NULL,LotColor1);
     ObjectSetText("bPos"+IntegerToString(i),DoubleToStr(bpos[i],0),8,NULL,OrdColor);
     ObjectSetText("sPos"+IntegerToString(i),DoubleToStr(spos[i],0),8,NULL,OrdColor1);
     ObjectSetText("TProf"+IntegerToString(i),DoubleToStr(MathAbs(bprofit[i]),2),8,NULL,ProfitColor);
     ObjectSetText("SProf"+IntegerToString(i),DoubleToStr(MathAbs(sprofit[i]),2),8,NULL,ProfitColor2);
     ObjectSetText("TtlProf"+IntegerToString(i),DoubleToStr(MathAbs(tprofit[i]),2),8,NULL,ProfitColor3);
     ObjectSetText("TotProf",DoubleToStr(MathAbs(totalprofit),2),8,NULL,ProfitColor1);
   }
}
void PlotAdrValues() {

   for (int i=0;i<ArraySize(TradePairs);i++)
     ObjectSetText("S1"+IntegerToString(i),DoubleToStr(adrvalues[i].adr,0),8,NULL,Yellow);
}
void PlotSpreadPips() {
             
   for (int i=0;i<ArraySize(TradePairs);i++) {
      if(MarketInfo(TradePairs[i],MODE_POINT) != 0 && pairinfo[i].pipsfactor != 0) {
       pairinfo[i].Pips = (iClose(TradePairs[i],PERIOD_D1,0)-iOpen(TradePairs[i], PERIOD_D1,0))/MarketInfo(TradePairs[i],MODE_POINT)/pairinfo[i].pipsfactor;     
       pairinfo[i].Spread=MarketInfo(TradePairs[i],MODE_SPREAD)/pairinfo[i].pipsfactor; 
      }  
     if(pairinfo[i].Pips>0){PipsColor =BullColor;}
     if(pairinfo[i].Pips<0){PipsColor =BearColor;} 
     if(pairinfo[i].Pips==0){PipsColor =clrWhite;}       
     if(pairinfo[i].Spread > MaxSpread)
      ObjectSetText("Spr1"+IntegerToString(i),DoubleToStr(pairinfo[i].Spread,1),8,NULL,Red);
     else
      ObjectSetText("Spr1"+IntegerToString(i),DoubleToStr(pairinfo[i].Spread,1),8,NULL,Orange);
     ObjectSetText("Pp1"+IntegerToString(i),DoubleToStr(MathAbs(pairinfo[i].Pips),0),8,NULL,PipsColor);

   }
}
bool inSession() {
 
   if ((localday != TimeDayOfWeek(TimeLocal()) && s1active == false && s2active == false && s3active == false) || localday == 99) {
      TimeToStruct(TimeLocal(),sess);
      StringSplit(sess1start,':',strspl);sess.hour=(int)strspl[0];sess.min=(int)strspl[1];sess.sec=0;
      s1start = StructToTime(sess);
      StringSplit(sess1end,':',strspl);sess.hour=(int)strspl[0];sess.min=(int)strspl[1];sess.sec=0;
      s1end = StructToTime(sess);
      StringSplit(sess2start,':',strspl);sess.hour=(int)strspl[0];sess.min=(int)strspl[1];sess.sec=0;
      s2start = StructToTime(sess);
      StringSplit(sess2end,':',strspl);sess.hour=(int)strspl[0];sess.min=(int)strspl[1];sess.sec=0;
      s2end = StructToTime(sess);
      StringSplit(sess3start,':',strspl);sess.hour=(int)strspl[0];sess.min=(int)strspl[1];sess.sec=0;
      s3start = StructToTime(sess);
      StringSplit(sess3end,':',strspl);sess.hour=(int)strspl[0];sess.min=(int)strspl[1];sess.sec=0;
      s3end = StructToTime(sess);
      if (s1end < s1start)
         s1end += 24*60*60;
      if (s2end < s2start)
         s2end += 24*60*60;
      if (s3end < s3start)
         s3end += 24*60*60;
      newSession();
      localday = TimeDayOfWeek(TimeLocal());
      Print("Sessions for today");
      if (UseSession1 == true)
         Print("Session 1 From:"+s1start+" until "+s1end);
      if (UseSession2 == true)
         Print("Session 2 From:"+s2start+" until "+s2end);
      if (UseSession3 == true)
         Print("Session 3 From:"+s3start+" until "+s3end);
   }


   if (UseSession1 && TimeLocal() >= s1start && TimeLocal() <= s1end) {
      comment = sess1comment;
      if (s1active == false)
         newSession();         
      else if ((StopProfit != 0 && profitbaskets >= StopProfit) || (StopLoss != 0 && lossbaskets >= StopLoss))
         return(false);
      s1active = true;
      return(true);
   } else {
      s1active = false;
   }   
   if (UseSession2 && TimeLocal() >= s2start && TimeLocal() <= s2end) {
      comment = sess2comment;
      if (s2active == false)
         newSession();
      else if ((StopProfit != 0 && profitbaskets >= StopProfit) || (StopLoss != 0 && lossbaskets >= StopLoss))
         return(false);
      s2active = true;
      return(true);
   } else {
      s2active = false;
   }
   if (UseSession3 && TimeLocal() >= s3start && TimeLocal() <= s3end) {
      comment = sess3comment;
      if (s3active == false)
         newSession();
      else if ((StopProfit != 0 && profitbaskets >= StopProfit) || (StopLoss != 0 && lossbaskets >= StopLoss))
         return(false);
      s3active = true;
      return(true);
   } else {
      s3active = false;
   }
   
   return(false);
}
void newSession() {
   
   profitbaskets = 0;
   lossbaskets = 0;
   SymbolMaxDD = 0.0;
   PercentMaxDDSymbol = 0.0;
   SymbolMaxHi=0.0;
   PercentFloatingSymbol = 0.0;
   currentlock = 0.0;
   trailstarted = false;   
   lockdistance = 0.0;
}
void GetTrendChange() {
   for (int i=0;i<ArraySize(TradePairs);i++) {

      signals[i].Signaltc = NONE;

      double Closelast = iRSI(TradePairs[i],PERIOD_H1,21,0,0);
      double Closebefore = iRSI(TradePairs[i],PERIOD_H1,21,0,1);
      double Openlast = iRSI(TradePairs[i],PERIOD_D1,21,0,0);
      double Openbefore = iRSI(TradePairs[i],PERIOD_D1,21,0,1);
      double Candlelength = MathAbs(Openlast-Closelast);

      // Check for Bearish Engulfing pattern
//      if ((C1>O1)&&(O>C)&&(O>=C1)&&(O1>=C)&&((O-C)>(C1-O1))&&(CL>=(10*pairinfo[i].PairPip))) {
      if (Closelast<Closebefore && Openlast<Openbefore && Closelast>30 && Openlast>30) {
         //if (signals[i].Signalhah4==UP)
            signals[i].Signaltc = DOWN;
      }
 
      // Check for Bullish Engulfing pattern
      
//      if ((O1>C1)&&(C>O)&&(C>=O1)&&(C1>=O)&&((C-O)>(O1-C1))&&(CL>=(10*pairinfo[i].PairPip))) {
      if (Closelast>Closebefore && Openlast>Openbefore && Closelast<70 && Openlast<70)  {
         //if (signals[i].Signalhah4==DOWN)
            signals[i].Signaltc = UP;
      }   
   }
 }
void GetCommodity() {
   for (int i=0;i<ArraySize(TradePairs);i++) {

      signals[i].Signalcc = NONE;

      double cci = iCCI(TradePairs[i],PERIOD_D1,20,5,0);
      double cci_prev = iCCI(TradePairs[i],PERIOD_D1,20,5,1); 
      
      if (cci<-100&&cci<cci_prev) {
         
            signals[i].Signalcc = DOWN;
      }
     
      if (cci>100&&cci>cci_prev)  {
         
            signals[i].Signalcc = UP;
      }   
   }
 }
//-------------------------------------------------------------------------------------+
//-----------------------------------------------------------------------------
void ChngBoxCol(int mVal, int mBx)
 {
   if(mVal >= 0 && mVal < 10)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, White);
   if(mVal > 10 && mVal < 20)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, LightCyan);
   if(mVal > 20 && mVal < 30)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, PowderBlue);
   if(mVal > 30 && mVal < 40)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, PaleTurquoise);
   if(mVal > 40 && mVal < 50)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, LightBlue);
   if(mVal > 50 && mVal < 60)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, SkyBlue);
   if(mVal > 60 && mVal < 70)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Turquoise);
   if(mVal > 70 && mVal < 80)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, DeepSkyBlue);
   if(mVal > 80 && mVal < 90)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, SteelBlue);
   if(mVal > 90 && mVal < 100)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Blue);
   if(mVal > 100)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, MediumBlue);

   if(mVal < 0 && mVal > -10)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, White);
   if(mVal < -10 && mVal > -20)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Seashell);
   if(mVal < -20 && mVal > -30)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, MistyRose);
   if(mVal < -30 && mVal > -40)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Pink);
   if(mVal < -40 && mVal > -50)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, LightPink);
   if(mVal < -50 && mVal > -60)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Plum);
   if(mVal < -60 && mVal >-70)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Violet);
   if(mVal < -70 && mVal > -80)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Orchid);
   if(mVal < -80 && mVal > -90)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, DeepPink);
   if(mVal < -90)
         ObjectSet("m1"+mBx, OBJPROP_BGCOLOR, Red);
   return;
 }
//-----------------------------------------------------------------------------  