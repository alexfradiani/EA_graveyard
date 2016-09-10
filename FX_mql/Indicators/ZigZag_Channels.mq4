//+------------------------------------------------------------------+
//|                       ZigZag Channels                            | 
//|                                              ZigZag_Channels.mq4 |
//|                                         Developed by Coders Guru |
//|                                            http://www.xpworx.com |
//+------------------------------------------------------------------+
#property copyright "xpworx"
#property link      "http://www.xpworx.com"
//+------------------------------------------------------------------+
//"Last Modified: 2011.09.20";
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
//+------------------------------------------------------------------+
//---- indicator parameters
extern   int      ExtDepth          = 12;
extern   int      ExtDeviation      = 5;
extern   int      ExtBackstep       = 3;
extern   int      BreakPips         = 5;
extern   color    UpperBandColor    = Blue;
extern   color    LowerBandColor    = Red;
extern   int      back              = 1;
extern   bool     AlertOn           = true;
//+------------------------------------------------------------------+
double ExtMapBuffer[];
double upperband[];
double lowerband[];
//+------------------------------------------------------------------+
double      mPoint               = 0.0001;
//+------------------------------------------------------------------+
string   pro  = "ZigZag Channel v2";
string   ver  = "";
string   tn;
//+------------------------------------------------------------------+
int deinit()
{
   DeleteObjects();
   return (0);
}
//+------------------------------------------------------------------+
int init()
{
   DeleteObjects();

   Stamp("ver",pro,15,30);
   string copy = "C 2005-2011 XPWORX. All rights reserved.";
   copy = StringSetChar(copy,0,'©');
   Stamp("copyright",copy ,15,40);
     
   mPoint = GetPoint(); 
      
   IndicatorBuffers(3);   
   
   SetIndexBuffer(0,upperband);
   SetIndexBuffer(1,lowerband);
   SetIndexBuffer(2,ExtMapBuffer);
   
   SetIndexLabel(0,"Upper band");
   SetIndexLabel(1,"Lower band");
   
   SetIndexStyle(0,DRAW_NONE); 
   SetIndexStyle(1,DRAW_NONE);
   SetIndexStyle(2,DRAW_NONE);
   
   SetIndexDrawBegin(0,300);
   
   return(0);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
{
     
   DrawTrends();
     
   for(int i=0; i<50; i++)
   {
      upperband[i] = ObjectGetValueByShift("uptrend",i);
      lowerband[i] = ObjectGetValueByShift("dntrend",i);
   }
     
   if(AlertOn)
   {
      if(Close[0]>upperband[0]+BreakPips*mPoint && Open[0]<upperband[0])
      AlertOnce(Symbol()+ ": " + PeriodToText() + "  -  Buy Signal / " + tn,0);
         
      if(Close[0]<lowerband[0]-BreakPips*mPoint  && Open[0]>lowerband[0])
      AlertOnce(Symbol()+ ": " + PeriodToText() + "  -  Sell Signal / " + tn,1);         
   }
   
   TrendName();
   
   return(0);
}

void TrendName()
{
   tn = "noisy";
   if(upperband[0]<upperband[10] && lowerband[0]<lowerband[10]) tn = "falling trend";
   if(upperband[0]>upperband[10] && lowerband[0]>lowerband[10]) tn = "rising trend";
   if(upperband[0]<upperband[10] && lowerband[0]>lowerband[10]) tn = "triangle trend";
   
   Stamp("trend_name",tn,15,60);   
}

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
  
void DrawTrends()
{
   bool up_exist = false;
   bool dn_exist = false;
   string up_name = "uptrend";
   string dn_name = "dntrend";
   
   double temp = 0;
   int count = 0;
   double p1 , p2 , p3 , p4;
   int    b1 , b2 , b3 , b4;
      
   //get last up
   for(int i = 0 ; i < 500 ; i++)
   {
      temp = iCustom(NULL,0,"zigzag",ExtDepth,ExtDeviation,ExtBackstep,0,i);
      if (temp != 0) count = count+1;
      if(count == back + 1 && temp != 0) {p1 = temp; b1 = i;}
      if(count == back + 2 && temp != 0) {p2 = temp; b2 = i;}
      if(count == back + 3 && temp != 0) {p3 = temp; b3 = i;}
      if(count == back + 4 && temp != 0) {p4 = temp; b4 = i;}
      if(count == back + 5) break;
   }   
   
   double price1 , price2 , price3 , price4;
   int    bar1 , bar2 , bar3 , bar4;
      
   if(p1>p2)
   {
      price1=p1;
      price2=p2;
      price3=p3;
      price4=p4;
      bar1=b1;
      bar2=b2;
      bar3=b3;
      bar4=b4;
   }
   else
   {
      price1=p2;
      price2=p1;
      price3=p4;
      price4=p3;
      bar1=b2;
      bar2=b1;
      bar3=b4;
      bar4=b3;
   }   
   
   //Comment(price1,":",price2,":",price3,":",price4,"\n",bar1,":",bar2,":",bar3,":",bar4);
   
   for(int cnt=ObjectsTotal();cnt>=0;cnt--)
   {
      if (StringFind(ObjectName(cnt),up_name,0)>-1) up_exist=true;
      if (StringFind(ObjectName(cnt),dn_name,0)>-1) dn_exist=true;
   }
   
   if (dn_exist)
   {
      ObjectSet(dn_name,OBJPROP_TIME1,Time[bar4]);
      ObjectSet(dn_name,OBJPROP_TIME2,Time[bar2]);
      ObjectSet(dn_name,OBJPROP_PRICE1,price4);
      ObjectSet(dn_name,OBJPROP_PRICE2,price2);
      ObjectSet(dn_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSet(dn_name,OBJPROP_WIDTH,2);
      ObjectSet(dn_name,OBJPROP_COLOR,LowerBandColor);  
      WindowRedraw();
   }
   else
   {
      ObjectCreate(dn_name,OBJ_TREND,0,Time[bar4],price4,Time[bar2],price2);      
      ObjectSet(dn_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSet(dn_name,OBJPROP_WIDTH,2);
      ObjectSet(dn_name,OBJPROP_COLOR,LowerBandColor);  
      WindowRedraw();
   }
   
   if (up_exist)
   {
      ObjectSet(up_name,OBJPROP_TIME1,Time[bar3]);
      ObjectSet(up_name,OBJPROP_TIME2,Time[bar1]);
      ObjectSet(up_name,OBJPROP_PRICE1,price3);
      ObjectSet(up_name,OBJPROP_PRICE2,price1);
      ObjectSet(up_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSet(up_name,OBJPROP_WIDTH,2);
      ObjectSet(up_name,OBJPROP_COLOR,UpperBandColor);  
      WindowRedraw();
   }
   else
   {
      ObjectCreate(up_name,OBJ_TREND,0,Time[bar3],price3,Time[bar1],price1);     
      ObjectSet(up_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSet(up_name,OBJPROP_WIDTH,2);
      ObjectSet(up_name,OBJPROP_COLOR,UpperBandColor);  
      WindowRedraw();
   }  
}

string PeriodToText()
{
   switch (Period())
   {
      case 1:
            return("M1");
            break;
      case 5:
            return("M5");
            break;
      case 15:
            return("M15");
            break;
      case 30:
            return("M30");
            break;
      case 60:
            return("H1");
            break;
      case 240:
            return("H4");
            break;
      case 1440:
            return("D1");
            break;
      case 10080:
            return("W1");
            break;
      case 43200:
            return("MN1");
            break;
   }
}

bool AlertOnce(string msg, int ref)
{  
   static int LastAlert[10];
   
   if( LastAlert[ref] == 0 || LastAlert[ref] < Bars)
   {
      Alert(msg);
      LastAlert[ref] = Bars;
      return (true);
   }
   return(false);
}

void Stamp(string objName , string text , int x , int y)
{
   string Obj="Stamp_" + objName;
   int objs = ObjectsTotal();
   string name;
  
   for(int cnt=0;cnt<ObjectsTotal();cnt++)
   {
      name=ObjectName(cnt);
      if (StringFind(name,Obj,0)>-1) 
      {
         ObjectSet(Obj,OBJPROP_XDISTANCE,x);
         ObjectSet(Obj,OBJPROP_YDISTANCE,y);
         WindowRedraw();
      }
      else
      {
         ObjectCreate(Obj,OBJ_LABEL,0,0,0);
         ObjectSetText(Obj,text,8,"arial",Orange);
         ObjectSet(Obj,OBJPROP_XDISTANCE,x);
         ObjectSet(Obj,OBJPROP_YDISTANCE,y);
         WindowRedraw();
      }
   }
   if (ObjectsTotal() == 0)
   {
         ObjectCreate(Obj,OBJ_LABEL,0,0,0);
         ObjectSetText(Obj,text,8,"arial",Orange);
         ObjectSet(Obj,OBJPROP_XDISTANCE,x);
         ObjectSet(Obj,OBJPROP_YDISTANCE,y);
         WindowRedraw();

   }
   
   return(0);
}

void DeleteObjects()
{
   int objs = ObjectsTotal();
   string name;
   for(int cnt=ObjectsTotal()-1;cnt>=0;cnt--)
   {
      name=ObjectName(cnt);
      if (StringFind(name,"xpMA",0)>-1) ObjectDelete(name);
      if (StringFind(name,"Stamp",0)>-1) ObjectDelete(name);
      if (StringFind(name,"trend_name",0)>-1) ObjectDelete(name);
      if (StringFind(name,"uptrend",0)>-1) ObjectDelete(name);    
      if (StringFind(name,"dntrend",0)>-1) ObjectDelete(name);      
      WindowRedraw();
   }
}