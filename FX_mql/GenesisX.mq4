#property copyright "Mika Akerberg akerbergmika@live.fi"
#property version "1.0"
#property strict

#define UP 1
#define NEUTRAL 0
#define DOWN -1
#define BullColor clrDarkGreen
#define BearColor clrMaroon

extern double tradeVolume = 0.05;
extern double AdrTP = 10.0;
extern double AdrSL = 30.0;
extern int x_axis = 300;
extern int y_axis = 12;
extern int historySize = 15;

string hst[28][15];
double sTrades[28][2]; //value, index

string Pairs[28] = {"EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", 
                    "USDCHF", "USDCAD", "USDJPY", "EURJPY", 
                    "GBPJPY", "CHFJPY", "CADJPY", "AUDJPY", 
                    "NZDJPY", "EURAUD", "EURCAD", "EURCHF", 
                    "EURGBP", "EURNZD", "GBPCHF", "GBPNZD", 
                    "GBPCAD", "GBPAUD", "AUDCAD","AUDNZD", 
                    "AUDCHF", "NZDCAD", "NZDCHF", "CADCHF"};
string Mains[8] = {"USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "NZD"};
double MainsStrength[8][17];
double Strength[28];
double BaseStr[8];
string postfix=StringSubstr(Symbol(),6,6);
string sn = "csm";
string Pair;
color BackGrnCol =C'20,20,20';

static datetime tradeDay=0; // variable to hold current date to see when it changes

double tradeDZZ[28]; /* Array to save decision zigzig (previous!) to prevent opening more than one trade per zigzag match */

struct pairinfo {
  double PairPip;
  int    PairPipsFactor;
  double Pips;
  double PairSpread;
  double PairPoint;
  int    lastSignal;
}; pairinfo CpairInfo[];

struct adrval {
   double adr;
   double adr1;
   double adr5;
   double adr10;
   double adr20;
}; adrval adrvalues[];

/*
  struct cpair_t {
  double lastZZ_p;
}; cpair_t cpair[];
*/

struct trades_t {
int               ticket;
int               op_type;
int               orderopenbar;
double            price;
double            stoploss;
double            takeprofit;
datetime          time;
int               lm; //lastmodifybar
double            r3;
double            r2;
double            r1;
double            pp;
double            s1;
double            s2;
double            s3;
}; trades_t trades[];


int OnInit(){


  /*
  **
  ** DRAW DASHBOARD BASE
  **
  **/

  for (int i=0;i<28;i++){
    SetText(sn+"-"+IntegerToString(i),Pairs[i],x_axis,(i*18)+y_axis,clrWhite,10);
    for (int x=0;x<historySize;x++) {
      SetPanel(sn+"-Curs-"+IntegerToString(x)+"-"+IntegerToString(i),0,(x*55+65)+x_axis,(i*18)+y_axis,55,17,BackGrnCol,C'61,61,61',1);
    }
  }
  
  for (int x=0;x<8;x++)
    for (int i=0;i<historySize-1;i++){
      SetPanel(sn+"-Mains-"+IntegerToString(x)+"-"+IntegerToString(i),0,(i*72+65)+x_axis,(x*18)+y_axis+525,110,17,BackGrnCol,C'61,61,61',1);
    }

   for (int x=0;x<28;x++){
     SetPanel(sn+"-Strades-"+IntegerToString(x),0,x_axis+915,y_axis+(x*18),150,17,BackGrnCol,C'61,61,61',1);
   }
  
   // /DRAW
   /////////////////////////////////////////

   ArrayResize(adrvalues,28);
   ArrayResize(CpairInfo,28);
   
   if (StringLen(postfix)>0) { /* If currencypairs contain suffix */
     for (int i=0;i<ArraySize(Pairs);i++){
       Pairs[i]=Pairs[i]+postfix;
       if (MarketInfo(Pairs[i],MODE_DIGITS) == 4 || MarketInfo(Pairs[i],MODE_DIGITS) == 2) {
         CpairInfo[i].PairPip = MarketInfo(Pairs[i],MODE_POINT);
         CpairInfo[i].PairPipsFactor = 1;
       } else { 
         CpairInfo[i].PairPip = MarketInfo(Pairs[i],MODE_POINT)*10;
         CpairInfo[i].PairPipsFactor = 10;
       }   
     }
   }
   



   EventSetTimer(1);
   drawMains();
   calculate();
   drawStrengths();
   
   return(INIT_SUCCEEDED);

}


void OnTimer(){

  PlotSpreadPips();

  if (tradeDay != TimeDay(Time[0])) { // Day has changed - update ADR values
    GetAdrValues();
    Print("getting adr values");
    tradeDay = TimeDay(Time[0]);
  }
  if (TimeSeconds(TimeCurrent()) % 20 == 0) {
    drawMains();
    calculate();
  }
  if (TimeSeconds(TimeCurrent()) % 30 == 0) {
  drawStrengths();
  drawSuggested();
  }
  checkTrades();
}


/*
**
** 
**
*/

void GetAdrValues() {
  
  double s=0.0;
  
  for (int i=0;i<28;i++) {
    for(int a=1;a<=20;a++) {
      if(CpairInfo[i].PairPip != 0)
        s=s+(iHigh(Pairs[i],PERIOD_D1,a)-iLow(Pairs[i],PERIOD_D1,a))/CpairInfo[i].PairPip;
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
    //    Print("Got adrvalues: ",adrvalues[i].adr);
    s=0.0;
  }
}


void PlotSpreadPips() {
             
   for (int i=0;i<28;i++) {
      if(MarketInfo(Pairs[i],MODE_POINT) != 0 && CpairInfo[i].PairPipsFactor != 0) {
       CpairInfo[i].Pips = (iClose(Pairs[i],PERIOD_D1,0)-iOpen(Pairs[i], PERIOD_D1,0))/MarketInfo(Pairs[i],MODE_POINT)/CpairInfo[i].PairPipsFactor;     
       CpairInfo[i].PairSpread=MarketInfo(Pairs[i],MODE_SPREAD)/CpairInfo[i].PairPipsFactor; 
      }  

   }
}


// TRADE CONTROLS


void openBuy(int pair, color clr){

  string sPair = Pairs[pair];

  int d=Digits;
  double p=Point;

  double stoploss = MarketInfo(sPair, MODE_ASK) - ((adrvalues[pair].adr10 / 100) * AdrSL) * CpairInfo[pair].PairPip;
  double takeprofit = MarketInfo(sPair, MODE_ASK) + ((adrvalues[pair].adr10 / 100) * AdrTP) * CpairInfo[pair].PairPip;

  Print ("Buy, sl: ",stoploss, " - tp: ",takeprofit, " ADR10 : ",adrvalues[pair].adr / 100);

  int ticket=OrderSend(sPair,OP_BUY,tradeVolume,NormalizeDouble(Ask,d),3,stoploss,takeprofit,DoubleToStr(stoploss),0,0,clr);
  if (ticket) {
    trades_t newTrade;
    newTrade.ticket=ticket;
    newTrade.op_type=OP_BUY;
    newTrade.orderopenbar=Bars;
    newTrade.stoploss = stoploss;
    newTrade.takeprofit = takeprofit;
    trades_push(trades,newTrade);
  }
}

void openSell(int pair, color clr){

  string sPair = Pairs[pair];


  int d=Digits;
  double p=Point;
  double stoploss = MarketInfo(sPair, MODE_BID) + ((adrvalues[pair].adr10 / 100) * AdrSL) * CpairInfo[pair].PairPip;
  double takeprofit = MarketInfo(sPair, MODE_BID) - ((adrvalues[pair].adr10 / 100) * AdrTP) * CpairInfo[pair].PairPip;
  Print ("Sell sl: ",stoploss, " - tp: ",takeprofit, " ADR10 : ",adrvalues[pair].adr / 100);
  int ticket=OrderSend(sPair,OP_SELL,tradeVolume,NormalizeDouble(Bid,d),3,stoploss,takeprofit,DoubleToStr(stoploss),0,0,clr);
  trades_t newTrade;
  newTrade.ticket=ticket;
  newTrade.op_type=OP_SELL;
  newTrade.orderopenbar=Bars;
  newTrade.stoploss = stoploss;
  newTrade.takeprofit = takeprofit;
  trades_push(trades,newTrade);
  
}


void checkTrades(){

  int ordersTotal=ArraySize(trades);
  if(ordersTotal < 1) return;
  color close = clrNONE;

  double p=Point;
  int d=Digits;
  
  for(int i=ordersTotal-1; i>=0; i--) {
    
    if(!OrderSelect(trades[i].ticket,SELECT_BY_TICKET,MODE_TRADES)) continue;
    if(OrderSymbol()!=Symbol()) continue;
    
    if (!trades[i].time) {
      trades[i].time = OrderOpenTime();
      trades[i].price = OrderOpenPrice();
    }
    
    if(trades[i].op_type==OP_BUY){
      
      if (Bid > trades[i].takeprofit) { close = clrGreen; }
      if (Bid < trades[i].stoploss) { close = clrRed; }
      
      if(close != clrNONE) if(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,d),3,close)){ 
          trades_remove(trades, trades[i].ticket); 
          break; 
          checkTrades(); 
        }
    }
    
    if(trades[i].op_type==OP_SELL){
      
      if (Bid < trades[i].takeprofit) { close = clrGreen; }
      if (Bid > trades[i].stoploss) { close = clrRed; }
      
      if(close != clrNONE) if(OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,d),3,close)){ 
          trades_remove(trades, trades[i].ticket); 
          break; 
          checkTrades();
        }
    }
  }
}

void trades_push(trades_t &array[],trades_t &order){
  
  int length=ArraySize(array);
  length++;
  ArrayResize(array,length);
  array[length-1]=order;
  
}

void trades_remove(trades_t &array[],int ticket){
  
  int length=ArraySize(array);
  trades_t narray[];
  
  ArrayResize(narray,length-1);
  for(int i=0,j=0; i<length; i++) {
    if(array[i].ticket==ticket)
      continue;
    else {
      narray[j]=array[i];
      j++;
    }
  }
  
  ArrayCopy(array,narray);
  ArrayResize(array,length-1);
}





// /TRADE CONTROLS





void drawStrengths(){

  for (int i=0;i<28;i++){
    for (int x=14;x>=0;x--) {
      SetText(sn+"-str-"+IntegerToString(x)+"-"+IntegerToString(i),NormalizeDouble(hst[i][x],2),(x*56-x)+75+x_axis,(i*18)+y_axis,clrBlack,10);
      det_colorMains(NormalizeDouble(hst[i][x],2),StringConcatenate("Curs-",IntegerToString(x),"-",IntegerToString(i)));
    }
  }
  
}


void drawSuggested(){
  for (int i=0;i<28;i++){
    sTrades[i][0] = hst[i][14];
    sTrades[i][1] = i;
  }
  ArraySort(sTrades, 0, 0, MODE_DESCEND);


  for (int i=0;i<28;i++){
    int thisPair = sTrades[i][1];
    SetText(sn+"-strades-"+i, StringConcatenate(Pairs[thisPair], "    ", NormalizeDouble(sTrades[i][0],2)),x_axis+920,y_axis+(i*18),clrBlack,8);
      det_colorMains(NormalizeDouble(sTrades[i][0],2),StringConcatenate("Strades-",i));
  }


  // EVALUATE POSSIBLE TRADES AND TAKE ACTION IF ZIGZAG MATCH STRENGTHS

  int buyPairs[];
  int sellPairs[];

  for (int i=0;i<4;i++)
    array_push(buyPairs,sTrades[i][1]);
  for (int i=27;i>23;i--)
    array_push(sellPairs,sTrades[i][1]);



  int curpair,lastdir;
  int n,fi;
  //Longs
  for (int i=0;i<4;i++){
    curpair = buyPairs[i];
    n=0;
    fi=0;
    double zz_cur,zz_prev;
    while(n<2){
      if(zz_cur>0) zz_prev=zz_cur;
      zz_cur=iCustom(Pairs[curpair], 5, "ZigZagMika",0,fi);
      if(zz_cur>0) n+=1;
      fi++;
    }
    lastdir = (zz_cur<zz_prev) ? UP:DOWN;
    if (lastdir==UP) SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(233),x_axis+1070,(i*18)+y_axis,BullColor,9); 
    if (lastdir==DOWN) {
      if (tradeDZZ[curpair] != zz_cur) {
        Print("openBuy ",Pairs[curpair], " zzcur/prev: ",zz_cur,"/",zz_prev, " " ,lastdir);

        tradeDZZ[curpair] = zz_cur; // same previous zz can't trigger new trades to open
        openBuy(curpair, clrGreen);
      }
      SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(234),x_axis+1070,(i*18)+y_axis,BearColor,9); 
    }
  }

  // Shorts
  int tmp_i=0;
  for (int i=27;i>23;i--){
    curpair = sellPairs[tmp_i];
    tmp_i++;
    n=0;
    fi=0;
    double zz_cur,zz_prev;
    while(n<2){
      if(zz_cur>0) zz_prev=zz_cur;
      zz_cur=iCustom(Pairs[curpair], 5, "ZigZagMika",0,fi);
      if(zz_cur>0) n+=1;
      fi++;
    }
    lastdir = (zz_cur<zz_prev) ? UP:DOWN;
    //   Print("Pair: ",Pairs[curpair], " zzcur/prev: ",zz_cur,"/",zz_prev);

    if (lastdir==UP) {
      if (tradeDZZ[curpair] != zz_cur) {
        tradeDZZ[curpair] = zz_cur;
        Print("openSell ",Pairs[curpair], " zzcur/prev: ",zz_cur,"/",zz_prev, " " ,lastdir);

        openSell(curpair, clrRed);
      }
      SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(233),x_axis+1070,(i*18)+y_axis,BullColor,9); 
    }
    if (lastdir==DOWN) SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(234),x_axis+1070,(i*18)+y_axis,BearColor,9); 
  }
}
/////////////////////////////////////////////

void start(){}
void calculate(){

  //  double modePoint,curHigh;
  //int tf=1440;

  for (int i=0;i<28;i++){
    Pair = Pairs[i];

    for (int x=0;x<14;x++){
      //      int z = x+1;
      hst[i][x] = hst[i][x+1];
    }

    int fCur = getPairAsInteger(StringSubstr(Pair,0,3));
    int lCur = getPairAsInteger(StringSubstr(Pair,3,3));
    
        if (BaseStr[fCur] > BaseStr[lCur]) {
          hst[i][14] = NormalizeDouble((BaseStr[fCur] - (BaseStr[lCur])),2);
          //          Print("fCur ",BaseStr[fCur], " > ",BaseStr[lCur]," arithm: ",hst[i][14]);
        }else{
          hst[i][14] = NormalizeDouble(-(BaseStr[lCur] - (BaseStr[fCur])),2);
          //          Print("fCur ",BaseStr[fCur], " < ",BaseStr[lCur]," arithm: ",hst[i][14]);

      }

    /*
    modePoint = MarketInfo(Pair, MODE_POINT);
    if (modePoint == 0.0) continue;
    curHigh = (iHigh(Pair, tf, 0) - iLow(Pair, tf, 0)) * modePoint;
    if (curHigh == 0.0) continue;
    Strength[i] = 100.0 * ((MarketInfo(Pair, MODE_BID) - iLow(Pair, tf, 0)) / curHigh * modePoint);
    hst[i][14] = Strength[i];
    */
  }
}

int arr2;
//double MainsUnsorted[8][9];
void drawMains(){
  
  for (int z=0;z<8;z++)
    for (int y=0;y<historySize;y++){
      int tmp = y+1;
      MainsStrength[z][y] = MainsStrength[z][tmp];
    }
  
  for (int z=0;z<8;z++){
    MainsStrength[z][14] = currency_strength(Mains[z]);
    MainsStrength[z][15] = z;
  }

  //  ArrayCopy(MainsUnsorted,MainsStrength, 0, 0, WHOLE_ARRAY);
  //  ArraySort(MainsStrength, 1, 0, MODE_DESCEND);
  double TmpArray[8][2];
  for (int x=1;x<historySize;x++) {
    
    for (int i=0;i<8;i++){
      ArrayInitialize(TmpArray,0);
      for (int tmp_z=0;tmp_z<8;tmp_z++){
        TmpArray[tmp_z][0] = MainsStrength[tmp_z][x];
        TmpArray[tmp_z][1] = MainsStrength[tmp_z][15];
      }
      ArraySort(TmpArray,0,0,MODE_DESCEND);
      int num = x-1;
      arr2 = TmpArray[i][1];
      int rowDir = rowDir(arr2,x,i);
      SetText(sn+"-MainsCurText-"+i+"-"+x,Mains[arr2],(x*73-x-5)+x_axis,(i*18)+y_axis+525,clrBlack,8);
      if(rowDir == UP) {SetObjText(sn+"SD"+IntegerToString(i)+"-"+IntegerToString(x),CharToStr(216),(x*73-x+15)+x_axis,(i*18)+y_axis+525,BullColor,10);}
      if(rowDir == DOWN) {SetObjText(sn+"SD"+IntegerToString(i)+"-"+IntegerToString(x),CharToStr(215),(x*73-x+15)+x_axis,(i*18)+y_axis+525,BearColor,10);}

      SetText(sn+"-MainsCurVal-"+i+"-"+x,NormalizeDouble(TmpArray[i][0],2),(x*73-x)+30+x_axis,(i*18)+y_axis+525,clrBlack,9);
      det_colorMains(TmpArray[i][0],StringConcatenate("Mains-",i,"-",(num)));
    }
  }
}

int rowDir(int cur,int xhist,int icur){
  
  //  for (int x=xhist;x>0;x--){
  int xprev = xhist-1;
  int direction = NEUTRAL;
  if (MainsStrength[cur][xprev] == 0) return (NEUTRAL);
  if (MainsStrength[cur][xhist] > MainsStrength[cur][xprev]) direction = UP;
  if (MainsStrength[cur][xhist] < MainsStrength[cur][xprev]) direction = DOWN;
  return (direction);
}



double currency_strength(string pair) {
  string sym;
  double range;
  double ratio;
  double strength = 0;
  int cnt1 = 0;
  int calctype = 0;
  int intPair = getPairAsInteger(pair);
  int count=1;
 
  for (int x = 0; x < 28; x++) {
    sym = Pairs[x];
    if (pair == StringSubstr(sym, 0, 3) || pair == StringSubstr(sym, 3, 3)) {
      calctype = (pair == StringSubstr(sym, 0, 3)) ? UP : DOWN;

      //range = (iHigh(sym, 1440, 0) - iLow(sym, 1440, 0)) * MarketInfo(sym, MODE_POINT);
      range = (MarketInfo(sym, MODE_HIGH) - MarketInfo(sym, MODE_LOW)) * MarketInfo(sym, MODE_POINT);
      if (range==0.0) continue;
      //ratio = 100.0 * ((MarketInfo(sym, MODE_BID) - iLow(sym, 1440, 0)) / range * MarketInfo(sym, MODE_POINT));
      ratio = 100.0 * (iClose(sym, 1, 0) - iClose(sym, PERIOD_D1, 1)) / range * MarketInfo(sym, MODE_POINT); //iClose(sym, PERIOD_D1, 1);
      if (ratio==0.0) continue;
      count++;

      /*
      range = (MarketInfo(sym, MODE_HIGH) - MarketInfo(sym, MODE_LOW)) * MarketInfo(sym, MODE_POINT);
      if (range != 0.0)
        ratio = (iClose(sym, 1, 0) - iClose(sym, PERIOD_D1, 1)) / iClose(sym, PERIOD_D1, 1) * 100;
      */

      if (calctype == UP) strength += ratio;
      else strength -= ratio;
    }      
  }  
  BaseStr[intPair] = strength / count;
  return (strength / count);
}



/////////////////////////////////////////////////////////////////////////////////////////////
void det_color(double mVal, string mBx) {
  mBx = StringConcatenate(sn,"-",mBx);
   if(mVal == 0)
         ObjectSet(mBx, OBJPROP_BGCOLOR, White);
   if(mVal > 0.01 && mVal < 10)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Red);
   if(mVal > 10.00 && mVal < 20)
         ObjectSet(mBx, OBJPROP_BGCOLOR, DeepPink);
   if(mVal > 20.00 && mVal < 30)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Orchid);
   if(mVal > 30.00 && mVal < 40)
         ObjectSet(mBx, OBJPROP_BGCOLOR, PaleTurquoise);
   if(mVal > 40.00 && mVal < 50)
         ObjectSet(mBx, OBJPROP_BGCOLOR, LightBlue);
   if(mVal > 50.00 && mVal < 60)
         ObjectSet(mBx, OBJPROP_BGCOLOR, SkyBlue);
   if(mVal > 60.00 && mVal < 70)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Turquoise);
   if(mVal > 70.00 && mVal < 80)
         ObjectSet(mBx, OBJPROP_BGCOLOR, DeepSkyBlue);
   if(mVal > 80.00 && mVal < 90)
         ObjectSet(mBx, OBJPROP_BGCOLOR, SteelBlue);
   if(mVal > 90.00 && mVal < 100)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Blue);
   if(mVal == 100)
         ObjectSet(mBx, OBJPROP_BGCOLOR, MediumBlue);
   /*
   if(mVal < 0 && mVal > -10)
         ObjectSet(mBx, OBJPROP_BGCOLOR, White);
   if(mVal < -10 && mVal > -20)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Seashell);
   if(mVal < -20 && mVal > -30)
         ObjectSet(mBx, OBJPROP_BGCOLOR, MistyRose);
   if(mVal < -30 && mVal > -40)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Pink);
   if(mVal < -40 && mVal > -50)
         ObjectSet(mBx, OBJPROP_BGCOLOR, LightPink);
   if(mVal < -50 && mVal > -60)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Plum);
   if(mVal < -60 && mVal >-70)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Violet);
   if(mVal < -70 && mVal > -80)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Orchid);
   if(mVal < -80 && mVal > -90)
         ObjectSet(mBx, OBJPROP_BGCOLOR, DeepPink);
   if(mVal < -90)
         ObjectSet(mBx, OBJPROP_BGCOLOR, Red);
   */
   return;
 }

void det_colorMains(double mVal3, string mBx3){
  mBx3 = StringConcatenate(sn,"-",mBx3);
   if(mVal3 >= 0 && mVal3 < 10)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, White);
   if(mVal3 > 10 && mVal3 < 20)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, LightCyan);
   if(mVal3 > 20 && mVal3 < 30)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, PowderBlue);
   if(mVal3 > 30 && mVal3 < 40)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, PaleTurquoise);
   if(mVal3 > 40 && mVal3 < 50)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, LightBlue);
   if(mVal3 > 50 && mVal3 < 60)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, SkyBlue);
   if(mVal3 > 60 && mVal3 < 70)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Turquoise);
   if(mVal3 > 70 && mVal3 < 80)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, SteelBlue);
   if(mVal3 > 80 && mVal3 < 90)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, SteelBlue);
   if(mVal3 > 90)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, DeepSkyBlue);

   if(mVal3 < 0 && mVal3 > -10)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, White);
   if(mVal3 < -10 && mVal3 > -20)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Seashell);
   if(mVal3 < -20 && mVal3 > -30)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, MistyRose);
   if(mVal3 < -30 && mVal3 > -40)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Pink);
   if(mVal3 < -40 && mVal3 > -50)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, LightPink);
   if(mVal3 < -50 && mVal3 > -60)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Plum);
   if(mVal3 < -60 && mVal3 >-70)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Violet);
   if(mVal3 < -70 && mVal3 > -80)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Orchid);
   if(mVal3 < -80 && mVal3 > -90)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, DeepPink);
   if(mVal3 < -90)
         ObjectSet(mBx3, OBJPROP_BGCOLOR, Red);
   return;
 }



 
 void SetText(string name,string text,int x,int y,color colour,int fontsize=12){
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

void SetObjText(string name,string CharToStr,int x,int y,color colour,int fontsize=12){
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
void SetPanel(string name,int sub_window,int x,int y,int width,int height,color bg_color,color border_clr,int border_width){
  if(ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,sub_window,0,0)){
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
void ColorPanel(string name,color bg_color,color border_clr){
  ObjectSetInteger(0,name,OBJPROP_COLOR,border_clr);
  ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg_color);
}
//+------------------------------------------------------------------+
void Create_Button(string but_name,string label,int xsize,int ysize,int xdist,int ydist,int bcolor,int fcolor){
  
  if(ObjectFind(0,but_name)<0){
    if(!ObjectCreate(0,but_name,OBJ_BUTTON,0,0,0)){
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

/////////////


int deinit() {
  int z=ObjectsTotal();
  for(int y=z;y>=0;y--) {
    if(StringFind(ObjectName(y),sn)>=0)
      ObjectDelete(ObjectName(y));
  }
  return(0);
}


// CUSTOM HELPERS


int getPairAsInteger (string pair) {
  //string Mains[8] = {"USD", "EUR", "GBP", "CHF", "JPY", "CAD", "AUD", "NZD"};
  if (pair=="USD") return(0);
  if (pair=="EUR") return(1);
  if (pair=="GBP") return(2);
  if (pair=="CHF") return(3);
  if (pair=="JPY") return(4);
  if (pair=="CAD") return(5);
  if (pair=="AUD") return(6);
  if (pair=="NZD") return(7);
  return(-1);
}


// ARRAY TOOLS


 void array_push(int&  array[], int val) {
   int length = ArraySize(array);
   length++;
   
   ArrayResize(array, length);
   array[length - 1] = val;
 }
 
 void array_remove(int& array[], int val) {
   int length = ArraySize(array);
   int narray[];
   
   ArrayResize(narray, length - 1);
   for(int i = 0, j = 0; i < length; i++) {
     if(array[i] == val)
       continue;
     else {
       narray[j] = array[i];
       j++;
     }
   }
   
   ArrayCopy(array, narray);
   ArrayResize(array, length - 1);
 }
bool in_array(int& array[], int val) {
  int length = ArraySize(array);
  for(int i = 0; i < length; i++)
    if(array[i] == val)
      return TRUE;
  return FALSE;
}
 
