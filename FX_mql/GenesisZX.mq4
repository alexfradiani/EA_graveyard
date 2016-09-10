#property copyright "Mika Akerberg akerbergmika@live.fi"
#property version "1.1"
#property strict

#define UP 1
#define NEUTRAL 0
#define DOWN -1
#define BullColor clrDarkGreen
#define BearColor clrMaroon

extern double tradeVolume = 0.05;
extern double AdrTP = 10.0;
extern double AdrSL = 30.0;
extern int x_axis = 1;
extern int y_axis = 12;
extern int historySize = 15;
extern int zz_tf = 5; // zigzag tf to use
extern double stochastic_period = 4; // stochastic period to trigger the trades
extern int stochastic_tf = 5; // stochastic tf
extern bool sendPushNotifications = true; //send information with push notifications 
extern bool debug = 0; // show additional debug messages

double hst[28][15];
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
double BaseStr[8];
string postfix=StringSubstr(Symbol(),6,6);
string sn = "csm";
string Pair;
color BackGrnCol =C'20,20,20';

// Import/Export trades to file

const uint account_number = AccountNumber();
string DataFileName = StringConcatenate("trades_",account_number,".bin"); // save with account number to prevent mixing trades with different accounts
extern string DataFileDirectory = "Data";
//////

static datetime tradeDay=0; // variable to hold current date to see when it changes

double tradeDZZ[28]; /* Array to save decision zigzig to prevent opening more than one trade per zigzag match */

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
  int               cpair;
  int               orderopenbar;
  double            price;
  double            stoploss;
  double            takeprofit;
  datetime          time;
  int               lm; //lastmodifybar
}; trades_t trades[];

struct zz_t {
  double f;
  double s;
  char direction;
};


void buildTradesStruct(){
  
  int ordersTotal=OrdersTotal();
  if(ordersTotal < 1) return;
  
  for(int i=ordersTotal-1; i>=0; i--) {
    
    if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
    trades_t newTrade;
    newTrade.ticket=OrderTicket();
    newTrade.cpair=getPairAsInteger(OrderSymbol());
    newTrade.op_type=OrderType();
    newTrade.stoploss=OrderStopLoss();
    newTrade.takeprofit=OrderTakeProfit();
    trades_push(trades,newTrade);
  }
  PrintFormat("trades struct built, %d trades open",ArraySize(trades));
}

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
   
   for (int i=0;i<ArraySize(Pairs);i++){
     if (StringLen(postfix)>0) Pairs[i]=Pairs[i]+postfix;
     if (MarketInfo(Pairs[i],MODE_DIGITS) == 4 || MarketInfo(Pairs[i],MODE_DIGITS) == 2) {
       CpairInfo[i].PairPip = MarketInfo(Pairs[i],MODE_POINT);
       CpairInfo[i].PairPipsFactor = 1;
     } else { 
       CpairInfo[i].PairPip = MarketInfo(Pairs[i],MODE_POINT)*10;
       CpairInfo[i].PairPipsFactor = 10;
     }   
   }
   
   ArrayInitialize(hst,0);

   buildTradesStruct();

   tradeDay = TimeDay(Time[0]);
   GetAdrValues();
   PlotSpreadPips();

   EventSetTimer(1);
   drawMains();
   calculate();
   drawStrengths();
   drawSuggested();

   return(INIT_SUCCEEDED);

}


void OnTimer(){

  PlotSpreadPips();

  if (tradeDay != TimeDay(Time[0])) { // Day has changed - update ADR values
    GetAdrValues();
    tradeDay = TimeDay(Time[0]);
  }
  if (TimeSeconds(TimeLocal()) % 20 == 0) {
    drawMains();
    calculate();
  }
  if (TimeSeconds(TimeLocal()) % 30 == 0) {
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
  double strength = hst[pair][14];

  int d=MarketInfo(sPair,MODE_DIGITS);

  double stoploss = MarketInfo(sPair, MODE_ASK) - ((adrvalues[pair].adr10 / 100) * AdrSL) * CpairInfo[pair].PairPip;
  double takeprofit = MarketInfo(sPair, MODE_ASK) + ((adrvalues[pair].adr10 / 100) * AdrTP) * CpairInfo[pair].PairPip;
  double openprice = NormalizeDouble(MarketInfo(sPair, MODE_ASK),d);
  string comment = StringFormat("%.1f:%.2f",CpairInfo[pair].PairSpread, strength);
  int ticket=OrderSend(sPair,OP_BUY,tradeVolume,openprice,3,stoploss,takeprofit,comment,0,0,clr);
  
  if (ticket) {
    trades_t newTrade;
    newTrade.ticket=ticket;
    newTrade.cpair=pair;
    newTrade.op_type=OP_BUY;
    newTrade.orderopenbar=Bars;
    newTrade.stoploss = stoploss;
    newTrade.takeprofit = takeprofit;
    trades_push(trades,newTrade);
    }
  
}

void openSell(int pair, color clr){

  string sPair = Pairs[pair];
  double strength = hst[pair][14];

  int d=MarketInfo(sPair,MODE_DIGITS);
  double stoploss = MarketInfo(sPair, MODE_BID) + ((adrvalues[pair].adr10 / 100) * AdrSL) * CpairInfo[pair].PairPip;
  double takeprofit = MarketInfo(sPair, MODE_BID) - ((adrvalues[pair].adr10 / 100) * AdrTP) * CpairInfo[pair].PairPip;
  double openprice = NormalizeDouble(MarketInfo(sPair, MODE_BID),d);
  string comment = StringFormat("%.1f:%.2f",CpairInfo[pair].PairSpread, strength);
  int ticket=OrderSend(sPair,OP_SELL,tradeVolume,openprice,3,stoploss,takeprofit,comment,0,0,clr);
  if (ticket) {
    trades_t newTrade;
    newTrade.ticket=ticket;
    newTrade.cpair=pair;
    newTrade.op_type=OP_SELL;
    newTrade.orderopenbar=Bars;
    newTrade.stoploss = stoploss;
    newTrade.takeprofit = takeprofit;
    trades_push(trades,newTrade);
    }
  
}

/*
void checkTrades(){

  int ordersTotal=OrdersTotal();
  if(ordersTotal < 1) return;
  color close = clrNONE;

  double p=Point;
  int d=Digits;
  
  for(int i=ordersTotal-1; i>=0; i--) {
    
    if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
    Pair = OrderSymbol();

    if(trades[i].op_type==OP_BUY){
      
      
      if(close != clrNONE) if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),3,close)){}
    }
    
    if(trades[i].op_type==OP_SELL){
      
      
      if(close != clrNONE) if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),3,close)){}
    }
  }
}
*/

void checkTrades(){

  int ordersTotal=ArraySize(trades);
  if(ordersTotal < 1) return;
  color close = clrNONE;

  double p=Point;
  int d=Digits;

  int pair;
  
  for(int i=ordersTotal-1; i>=0; i--) {
    
    if(!OrderSelect(trades[i].ticket,SELECT_BY_TICKET,MODE_TRADES)) {
      trades_remove(trades, trades[i].ticket);
      continue;
    }
    
    pair = trades[i].cpair;
    if (!trades[i].time) {
      trades[i].time = OrderOpenTime();
      trades[i].price = OrderOpenPrice();
    }
    if (trades[i].stoploss != OrderStopLoss()) trades[i].stoploss = OrderStopLoss(); // update struct if sl/tp has been modified manually
    if (trades[i].takeprofit != OrderTakeProfit()) trades[i].takeprofit = OrderTakeProfit(); 
      
    
    //    PrintFormat("checkTrades - check if %s order (int %d) is good, strength %f",OrderSymbol(),pair,hst[pair][14]);
    if(trades[i].op_type==OP_BUY){
      if (hst[pair][14] < -10) {
        close = clrMagenta;
        sendNotification(StringFormat("CLOSEBUY %s due to strength %.2f (%.2f %s)", OrderSymbol(),hst[pair][14],OrderProfit(),AccountCurrency()));
        Print("Closed BUY ",OrderTicket()," ",OrderSymbol()," at ",MarketInfo(OrderSymbol(), MODE_BID), " due to strength ",hst[pair][14]);
      }
      if (MarketInfo(OrderSymbol(), MODE_BID) > trades[i].takeprofit) { close = clrGreen; }
      if (MarketInfo(OrderSymbol(), MODE_BID) < trades[i].stoploss) { close = clrRed; }
      
      if(close != clrNONE) {
        if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),3,close)){}
        trades_remove(trades, trades[i].ticket); 
        break; 
        checkTrades(); 
      }
    }
    
    if(trades[i].op_type==OP_SELL){

      if (hst[pair][14] > 10) {
        close = clrMagenta;
        sendNotification(StringFormat("CLOSESELL %s due to strength %.2f (%.2f %s)", OrderSymbol(),hst[pair][14],OrderProfit(),AccountCurrency()));
        Print("Closed SELL ",OrderTicket()," ",OrderSymbol()," at ",MarketInfo(OrderSymbol(), MODE_BID), " due to strength ",hst[pair][14]);
      } 
      
      if (MarketInfo(OrderSymbol(), MODE_ASK) < trades[i].takeprofit) { close = clrGreen; }
      if (MarketInfo(OrderSymbol(), MODE_ASK) > trades[i].stoploss) { close = clrRed; }
      
      if(close != clrNONE) {
        if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),3,close)){}
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
      SetText(sn+"-str-"+IntegerToString(x)+"-"+IntegerToString(i),DoubleToStr(hst[i][x],2),(x*56-x)+75+x_axis,(i*18)+y_axis,clrBlack,10);
      det_colorMains(hst[i][x],StringConcatenate("Curs-",IntegerToString(x),"-",IntegerToString(i)));
    }
  }
  
}


void drawSuggested(){
  for (int i=0;i<28;i++){
    sTrades[i][0] = NormalizeDouble(hst[i][14],2);
    sTrades[i][1] = i;
  }
  ArraySort(sTrades, 0, 0, MODE_DESCEND);


  for (int i=0;i<28;i++){
    int thisPair = sTrades[i][1];
    double spread = CpairInfo[thisPair].PairSpread;
    SetText(sn+"-strades-"+IntegerToString(i), StringConcatenate(Pairs[thisPair], "    ", DoubleToStr(sTrades[i][0],2)),x_axis+920,y_axis+(i*18),clrBlack,8);
    SetText(sn+"-strades-spread-"+IntegerToString(i), DoubleToStr(spread,1),x_axis+1040,y_axis+(i*18),(spread<2.5?BullColor:BearColor),8);

      det_colorMains(NormalizeDouble(sTrades[i][0],2),StringConcatenate("Strades-",i));
  }



  // EVALUATE POSSIBLE TRADES AND TAKE ACTION IF ZIGZAG MATCH STRENGTHS

  int buyPairs[];
  int sellPairs[];

  for (int i=0;i<7;i++)
    array_push(buyPairs,sTrades[i][1]);
  for (int i=27;i>20;i--)
    array_push(sellPairs,sTrades[i][1]);



  int curpair,lastdir;
  //Longs
  for (int i=0;i<7;i++){
    curpair = buyPairs[i];

    zz_t zz = getZZ(Pairs[curpair]); // iStochastic(NULL,0,5,3,3,MODE_SMA,0,MODE_MAIN,0
    double stochastic = iStochastic(Pairs[curpair], stochastic_tf, stochastic_period, 1,1, MODE_SMA, 0, MODE_MAIN, 0); // We scan that stochastic_period,1,1 main line goes to >90 / <10
    if (zz.direction==UP) SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(234),x_axis+1070,(i*18)+y_axis,BearColor,9); 
    if (zz.direction==DOWN) {
      if (tradeDZZ[curpair] != zz.s && stochastic < 10 && hst[curpair][14]>30) {
        tradeDZZ[curpair] = zz.s; // same previous zz can't trigger new trades to open
        openBuy(curpair, clrGreen);
      }
      SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(233),x_axis+1070,(i*18)+y_axis,BullColor,9); 
    }
  }

  // Shorts
  int tmp_i=0;
  for (int i=27;i>20;i--){
    curpair = sellPairs[tmp_i];
    tmp_i++;

    zz_t zz = getZZ(Pairs[curpair]);
    double stochastic = iStochastic(Pairs[curpair], stochastic_tf, stochastic_period, 1,1, MODE_SMA, 0, MODE_MAIN, 0); // We scan that stochastic_period,1,1 main line goes to >90 / <10

    if (zz.direction==UP) {
      if (tradeDZZ[curpair] != zz.s && stochastic > 90 && hst[curpair][14]<-30) {
        tradeDZZ[curpair] = zz.s;
        openSell(curpair, clrRed);
      }
      SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(234),x_axis+1070,(i*18)+y_axis,BearColor,9); 
    }
    if (zz.direction==DOWN) SetObjText(sn+"-strades-zz-"+IntegerToString(i),CharToStr(233),x_axis+1070,(i*18)+y_axis,BullColor,9); 
  }
}
/////////////////////////////////////////////
zz_t getZZ(string symbol) {//char direction){
  zz_t zz;
  double z_first=0,z_second=0;
  uchar n=0,i=1;
  while(n<2) {
    if (z_second > 0) z_first = z_second;
    z_second = iCustom(symbol, 5, "ZigZagMika", 0, i);
    if (z_second > 0) n++;
    i++;
  }
  zz.f = z_first;
  zz.s = z_second;
  zz.direction = (zz.f > zz.s) ? UP : DOWN;
  return zz;
}


void start(){}
void calculate(){

  //  double modePoint,curHigh;
  //int tf=1440;
  double str=0;
  for (int i=0;i<28;i++){
    Pair = Pairs[i];

    for (int x=0;x<14;x++){
      //      int z = x+1;
      hst[i][x] = NormalizeDouble(hst[i][x+1],2);
    }

    int fCur = getCurrencyAsInteger(StringSubstr(Pair,0,3));
    int lCur = getCurrencyAsInteger(StringSubstr(Pair,3,3));
    
    str = (BaseStr[fCur] > BaseStr[lCur]) ? (BaseStr[fCur] - (BaseStr[lCur])) : -(BaseStr[lCur] - (BaseStr[fCur]));
    if (str > 100) str = 100.0;
    if (str < -100) str = -100.0;
    hst[i][14] = NormalizeDouble(str,2);
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

      SetText(sn+"-MainsCurVal-"+i+"-"+x,DoubleToStr(TmpArray[i][0],2),(x*73-x)+30+x_axis,(i*18)+y_axis+525,clrBlack,9);
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


/**
 * Calculate the strengths of a currency relative to the other majors
 * the strength is added to the BaseStr array in the position of that currency
 * returns the strength of the currency parameter 
 */
double currency_strength(string currency) {
  string sym;  //symbol for comparison
  double range = 0.0;
  double ratio = 0.0;
  double strength = 0;
  int calctype = 0;
  int intCurrency = getCurrencyAsInteger(currency);
  int count = 0;
  
  for(int x = 0; x < 28; x++) {
    sym = Pairs[x];
    if(currency == StringSubstr(sym, 0, 3) || currency == StringSubstr(sym, 3, 3)) { //pair contains currency under evaluation
      calctype = (currency == StringSubstr(sym, 0, 3)) ? UP : DOWN;
      
      range = MarketInfo(sym, MODE_HIGH) - MarketInfo(sym, MODE_LOW);
      if(range == 0.0)
        continue;
      
      ratio = 100 * (iClose(sym, PERIOD_M1, 0) - iClose(sym, PERIOD_D1, 1)) / range;
      if(ratio == 0.0)
        continue;
      
      count++;
      if(calctype == UP)
        strength += ratio;
      else
        strength -= ratio;
    }      
  }
  BaseStr[intCurrency] = strength / count;
  
  return strength / count;
}

/**
 * Get the index of a currency in BaseStr array
 */
int getCurrencyAsInteger(string currency) {
    if(currency == "USD")
        return 0;
    if(currency == "EUR")
        return 1;
    if(currency == "GBP")
        return 2;
    if(currency == "CHF")
        return 3;
    if(currency == "JPY")
        return 4;
    if(currency == "CAD")
        return 5;
    if(currency == "AUD")
        return 6;
    if(currency == "NZD")
        return 7;
    
    return -1;
}

/**
 *  Get the index of a currencypair in Pairs array

string Pairs[28] = {"EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", 
                    "USDCHF", "USDCAD", "USDJPY", "EURJPY", 
                    "GBPJPY", "CHFJPY", "CADJPY", "AUDJPY", 
                    "NZDJPY", "EURAUD", "EURCAD", "EURCHF", 
                    "EURGBP", "EURNZD", "GBPCHF", "GBPNZD", 
                    "GBPCAD", "GBPAUD", "AUDCAD","AUDNZD", 
                    "AUDCHF", "NZDCAD", "NZDCHF", "CADCHF"};


 */

int getPairAsInteger(string cpair){
  cpair = StringSubstr(cpair,0,6);
  if(cpair=="EURUSD") return 0;
  if(cpair=="GBPUSD") return 1;
  if(cpair=="AUDUSD") return 2;
  if(cpair=="NZDUSD") return 3;
  if(cpair=="USDCHF") return 4;
  if(cpair=="USDCAD") return 5;
  if(cpair=="USDJPY") return 6;
  if(cpair=="EURJPY") return 7;
  if(cpair=="GBPJPY") return 8;
  if(cpair=="CHFJPY") return 9;
  if(cpair=="CADJPY") return 10;
  if(cpair=="AUDJPY") return 11;
  if(cpair=="NZDJPY") return 12;
  if(cpair=="EURAUD") return 13;
  if(cpair=="EURCAD") return 14;
  if(cpair=="EURCHF") return 15;
  if(cpair=="EURGBP") return 16;
  if(cpair=="EURNZD") return 17;
  if(cpair=="GBPCHF") return 18;
  if(cpair=="GBPNZD") return 19;
  if(cpair=="GBPCAD") return 20;
  if(cpair=="GBPAUD") return 21;
  if(cpair=="AUDCAD") return 22;
  if(cpair=="AUDNZD") return 23;
  if(cpair=="AUDCHF") return 24;
  if(cpair=="NZDCAD") return 25;
  if(cpair=="NZDCHF") return 26;
  if(cpair=="CADCHF") return 27;
  return -1;
}

/*
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
      /

      if (calctype == UP) strength += ratio;
      else strength -= ratio;
    }      
  }
  strength = strength / count;
  BaseStr[intPair] = NormalizeDouble(strength,2);
  return (BaseStr[intPair]);
}
*/


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


/* 
bool importTrades() {
  int default_size=20;
  int size=0;
  trades_t tmpTrades[]; // init temporary trades struct
  ArrayResize(tmpTrades,default_size);
  ResetLastError();
  int fh=FileOpen(DataFileDirectory+"//"+DataFileName, FILE_READ|FILE_BIN|FILE_COMMON);
  if(fh!=INVALID_HANDLE) {
    if (debug) PrintFormat("importTrades, file open true, file path: %s\\Files\\",TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    while(!FileIsEnding(fh)) {
      uint bytesread=FileReadStruct(fh,tmpTrades[size]);        
      if (bytesread!=sizeof(trades_t)){
        PrintFormat("importTrades, error reading data. Error = %d",GetLastError());
        FileClose(fh);
        return(false);
      } else {
        size++;
        //--- check if the array is overflown
        if(size==default_size){
          //--- increase the array dimension
          default_size+=20;
          ArrayResize(tmpTrades,default_size);
        }
      }
    }
    FileClose(fh);

    
    PrintFormat("importTrades - import complete");
    return(true);
  } else {
    PrintFormat("importTrades - failed to open %s file, error = %d",DataFileName,GetLastError());
    return(false);
  }
}

bool exportTrades() {
  ResetLastError();
  int size = ArraySize(trades);
  int fh = FileOpen(DataFileDirectory+"//"+DataFileName,FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
  if(fh!=INVALID_HANDLE){
    if (debug) PrintFormat("exportTrades - file open: true - path: %s\\Files\\",TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    uint counter=0;
    //--- write array values in the loop
    for(int i=0;i<size;i++){
      uint byteswritten = FileWriteStruct(fh, trades[i]);
      if(byteswritten!=sizeof(trades_t)) {
        PrintFormat("exportTrades - error read data. error = %d",GetLastError());
        FileClose(fh);
        return(false);
      }
      else
        counter += byteswritten;
    }
    if (debug) PrintFormat("%d bytes of information is written to %s file",DataFileName,counter);
    FileClose(fh);
    if (debug) PrintFormat("Data is written, %s file is closed",DataFileName);
    return(true);
  }
  else {
    PrintFormat("exportTrades - failed to open %s file, error = %d",DataFileName,GetLastError());
    return(false);
  }
} 
*/


bool sendNotification(string msg){
  if (!sendPushNotifications) return true;
  bool sent=false;
  uchar failed_cnt = 0;
  while (sent<1 && failed_cnt<4){
    if (SendNotification(msg)){
      sent=true;
      Sleep(500);
      return true;
    } else {
      PrintFormat("sendNotification, unable to send (%d): %d",failed_cnt, GetLastError());
      failed_cnt++;
    }
    Sleep(500);
  }
  return false;
}