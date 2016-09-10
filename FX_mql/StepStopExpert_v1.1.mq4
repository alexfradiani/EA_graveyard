//+------------------------------------------------------------------+
//|                                            StepStopExpert_v1.mq4 |
//|                                  Copyright © 2006, Forex-TSD.com |
//|                         Written by IgorAD,igorad2003@yahoo.co.uk |   
//|            http://finance.groups.yahoo.com/group/TrendLaboratory |                                      
//+------------------------------------------------------------------+
#property copyright "Copyright © 2006, Forex-TSD.com "
#property link      "http://www.forex-tsd.com/"

//---- input parameters
extern double     InitialStop     = 30;
extern double     BreakEven       = 20;    // Profit Lock in pips  
extern double     StepSize        =  5;
extern double     MinDistance     = 10;

int   k, digit=0;
bool BE = false;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {

//----
   return(0);
  }

// ---- Stepped Stops
void StepStops()
{        
    double BuyStop, SellStop;
    int total=OrdersTotal();
    for (int cnt=0;cnt<total;cnt++)
    { 
     OrderSelect(cnt, SELECT_BY_POS);   
     int mode=OrderType();    
        if ( OrderSymbol()==Symbol() ) 
        {
            if ( mode==OP_BUY )
            {
               BuyStop = OrderStopLoss();
               if ( Bid-OrderOpenPrice()>0 || OrderStopLoss()==0) 
               {
               if ( Bid-OrderOpenPrice()>=Point*BreakEven && !BE) {BuyStop = OrderOpenPrice();BE = true;}
               
               if (OrderStopLoss()==0) {BuyStop = OrderOpenPrice() - InitialStop * Point; k=1; BE = false;}
               
               if ( Bid-OrderOpenPrice()>= k*StepSize*Point) 
               {
               BuyStop = OrderStopLoss()+ StepSize*Point; 
               if (Bid - BuyStop >= MinDistance*Point)
               { BuyStop = BuyStop; k=k+1;}
               else
               BuyStop = OrderStopLoss();
               }                              
               //Print( " k=",k ," del=", k*StepSize*Point, " BuyStop=", BuyStop," digit=", digit);
               OrderModify(OrderTicket(),OrderOpenPrice(),
                           NormalizeDouble(BuyStop, digit),
                           OrderTakeProfit(),0,LightGreen);
			      return(0);
			      }
			   }
            if ( mode==OP_SELL )
            {
               SellStop = OrderStopLoss();
               if ( OrderOpenPrice()-Ask>0 || OrderStopLoss()==0) 
               {
               if ( OrderOpenPrice()-Ask>=Point*BreakEven && !BE) {SellStop = OrderOpenPrice(); BE = true;}
               
               if ( OrderStopLoss()==0 ) { SellStop = OrderOpenPrice() + InitialStop * Point; k=1; BE = false;}
               
               if ( OrderOpenPrice()-Ask>=k*StepSize*Point) 
               {
               SellStop = OrderStopLoss() - StepSize*Point; 
               if (SellStop - Ask >= MinDistance*Point)
               { SellStop = SellStop; k=k+1;}
               else
               SellStop = OrderStopLoss();
               }
               //Print( " k=",k," del=", k*StepSize*Point, " SellStop=",SellStop," digit=", digit);
               OrderModify(OrderTicket(),OrderOpenPrice(),
   		                  NormalizeDouble(SellStop, digit),
   		                  OrderTakeProfit(),0,Yellow);	    
               return(0);
               }    
            }
         }   
      } 
}

// ---- Scan Trades
int ScanTrades()
{   
   int total = OrdersTotal();
   int numords = 0;
      
   for(int cnt=0; cnt<total; cnt++) 
   {        
   OrderSelect(cnt, SELECT_BY_POS);            
   if(OrderSymbol() == Symbol() && OrderType()<=OP_SELL) 
   numords++;
   }
   return(numords);
}

         	                    
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//---- 
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
   digit  = MarketInfo(Symbol(),MODE_DIGITS);

   
   if (ScanTrades()<1) return(0);
   else
   if (BreakEven>0 || InitialStop>0 || StepSize>0) StepStops(); 
   
 return(0);
}//int start
//+------------------------------------------------------------------+





