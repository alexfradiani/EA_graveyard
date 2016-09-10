//+------------------------------------------------------------------+
#property copyright "Mika Åkerberg 12062014"
#property link      ""

extern int tp = 1111;
extern int sl = 700;
extern double Lots =0.02;
extern int RSI_Open_Buy  = 18;
extern int RSI_Close_Buy  = 52;
extern int RSI_Open_Sell = 85;
extern int RSI_Close_Sell  = 50;
extern int MaxBuys = 5;
extern int MaxSells = 5;
extern int MaxSumOrders = 0;
extern int MagicNumber=2;

extern int       KPeriod       =   14;
extern int       DPeriod       =   3;
extern int       Slowing       =   3;
extern int       MAMethod      =   0;
extern int       PriceField    =   0;
extern double       overBought    =  82;
extern double       overSold      =  18;


struct order {
    int id;
    int op_type;
    double price;
    int time;
};
int this_id[];
order pending_longs[];
order pending_shorts[];

extern string Comments="ea-v1";
int action;
int last_pending_long=(int)TimeLocal()+1;
int last_pending_short=(int)TimeLocal()+1;
datetime prev_time=0;

int init() { return(0); }
int deinit() { return(0); }

int start() {
int i=0,type=-1,buys=0,sells=0,buysnow=0,sellsnow=0,cnt=0;
double p=Point,open=0;
int d=Digits;
int _ti;

for(i=0;i<OrdersTotal();i++) {
if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
if(OrderMagicNumber()!=MagicNumber) continue;
if(OrderSymbol()!=Symbol()) continue;
if(OrderType()==OP_BUY) {
 buys++; if(OrderOpenTime()>=Time[0]) buysnow++; }
if(OrderType()==OP_SELL) {
 sells++; if(OrderOpenTime()>=Time[0]) sellsnow++; }
}

//double nRSI =iRSI(NULL,0,7,PRICE_CLOSE,0);
//double nRSI14 =iRSI(NULL,0,14,PRICE_OPEN,0);
//double pRSI =iRSI(NULL,0,7,PRICE_CLOSE,4);

double upPrice = iBands(NULL,0,20,2,0,PRICE_HIGH,MODE_UPPER,0);
double downPrice = iBands(NULL,0,20,2,0,PRICE_LOW,MODE_LOWER,0);
double KFull = iStochastic(NULL,0,KPeriod,DPeriod,Slowing,MAMethod,PriceField,MODE_MAIN,0);
double DFull = iStochastic(NULL,0,KPeriod,DPeriod,Slowing,MAMethod,PriceField,MODE_SIGNAL,0);

if (Ask>upPrice && (int)LocalTime()-last_pending_short>86400) {
   cnt=ArraySize(pending_shorts);
   order newPending;
   newPending.id=cnt+1;
   newPending.op_type=OP_SELL;
   newPending.price=Bid;
   newPending.time=0;
   array_push(pending_shorts, newPending);
   Print("Added pending short");
   last_pending_short=(int)TimeLocal();
}

else if (Bid<downPrice && (int)LocalTime()-last_pending_long>86400) {
   cnt=ArraySize(pending_longs);
   order newPending;
   newPending.id=cnt+1;
   newPending.op_type=OP_BUY;
   newPending.price=Ask;
   newPending.time=0;
   array_push(pending_longs, newPending);
   Print("Added pending long");
   last_pending_long=(int)TimeLocal();
}
if(buys<MaxOrders(buys,sells,0)){
   if (KFull<overSold) {

for (i=0;i<ArraySize(pending_longs);i++){
      array_push_int(this_id, pending_longs[i].id);
      if (!OrderSend(Symbol(),OP_BUY,Lots,NormalizeDouble(Ask,d),3,0,0,Comments,MagicNumber)){}
    Sleep(1000);
   }

if (ArraySize(this_id) != 0) {
   for (_ti=0;_ti<ArraySize(this_id);_ti++){
      array_remove(pending_longs,this_id[_ti]);
   }
}

}
}

if(sells<MaxOrders(buys,sells,1)){
   if (KFull>overBought) {

   for (i=0;i<ArraySize(pending_shorts);i++){
      if (!OrderSend(Symbol(),OP_SELL,Lots,NormalizeDouble(Bid,d),3,0,0,Comments,MagicNumber)){}
    Sleep(1000);
   }

if (ArraySize(this_id) != 0) {
   for (_ti=0;_ti<ArraySize(this_id);_ti++){
      array_remove(pending_shorts,this_id[_ti]);
   }
}

}
}

//if(buys<MaxOrders(buys,sells,0)){ //&&buysnow==0) {
//if(sells<MaxOrders(buys,sells,1)){ //&&sellsnow==0) { 










/*
for(i=0;i<OrdersTotal();i++) {
if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
if(OrderMagicNumber()!=MagicNumber) continue;
if(OrderSymbol()!=Symbol()) continue;
type=OrderType();
if(type==OP_BUY) {
 if(OrderTakeProfit()==0&&OrderStopLoss()==0) {
  open=OrderOpenPrice();
  tp=NormalizeDouble(open+tp*p,d);
  sl=NormalizeDouble(open-sl*p,d);
  Print("Trying to mod ",OrderTicket()," sl: ",sl, " tp: ",tp);
  if (!OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0)){}
  open=0; tp=0; sl=0; type=-1; Sleep(1000); } }
if(OrderType()==OP_SELL) {
 if(OrderTakeProfit()==0&&OrderStopLoss()==0) {
  open=OrderOpenPrice();
  tp=NormalizeDouble(open-tp*p,d);
  sl=NormalizeDouble(open+sl*p,d);
  if (!OrderModify(OrderTicket(),open,sl,tp,0)){}
  open=0; tp=0; sl=0; type=-1; Sleep(1000); } }
}





/*


            KFull[i] = iStochastic(NULL,TimeFrame,KPeriod,DPeriod,Slowing,MAMethod,PriceField,MODE_MAIN,y);
            DFull[i] = iStochastic(NULL,TimeFrame,KPeriod,DPeriod,Slowing,MAMethod,PriceField,MODE_SIGNAL,y);





*/
CheckTrades();

return(0);
}

void CheckTrades() {

   RefreshRates();

   int i=0,d=Digits;
   for(i=0;i<OrdersTotal();i++) {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderSymbol()!=Symbol()) continue;
      double nRSI =iRSI(NULL,0,7,PRICE_CLOSE,1);
      double pRSI =iRSI(NULL,0,7,PRICE_CLOSE,2);
      if(OrderType()==OP_BUY) {
         if((nRSI>RSI_Close_Buy && (OrderProfit()>1))){// && OrderProfit()>0.20) {
         //  if(nRSI<pRSI) { //
           if (!OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Bid,d),3)){}
            Sleep(1000); 
         }
      } 
      //}
    
      if(OrderType()==OP_SELL) {
         if((nRSI<RSI_Close_Sell && (OrderProfit()>1))){// && OrderProfit()>0.20) {
          //  if(nRSI>pRSI) { //and RSI is going down 
            if (!OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(Ask,d),3)){}
             Sleep(1000); 
         } 
      }  
      //}
   }
}

int MaxOrders(int buys, int sells, int type){
   if(MaxSumOrders>0) return(MaxSumOrders-buys-sells);
   if(MaxSumOrders==0) return (type==0) ? MaxBuys : MaxSells;
   return(1000);
}

void array_push(order&  array[], order& _order) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = _order;
}

void array_remove(order& array[], int id) {
    int length = ArraySize(array);
    order narray[];
    
    ArrayResize(narray, length - 1);
    for(int i = 0, j = 0; i < length; i++) {
    	if(array[i].id == id)
    		continue;
    	else {
    		narray[j] = array[i];
    		j++;
    	}
    }
    
    ArrayCopy(array, narray);
    ArrayResize(array, length - 1);
}
void array_push_int(int&  array[], int val) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = val;
}
void array_remove_int(int& array[], int val) {
 	int length = ArraySize(array);
 	int narray[];
 	
 	ArrayResize(narray, length - 1);
 	int j=0;
 	for(int i = 0; i < length; i++) {
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