//+------------------------------------------------------------------+
//|                                             TrendFinder_v2.mq4   |
//|                                               Alexander Fradiani |
//+------------------------------------------------------------------+
#property copyright "Alexander Fradiani"
#property version   "3.00"
#property strict

#include <TSetup.mqh>

extern string clientDesc = "TrendFinder(2.0 Bullish + Bearish) (3.0 trade criteria)";

datetime lastTime;

/* pivot points (price extremes in chart) as start of possible trends */
struct ref_t {
    int index;
    double price;
    datetime refTime;
};
ref_t bullRef;
ref_t bearRef;

trend_t trends[]; //defined in include file
order_t orders[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() { 
    bullRef.price = 100000;
    bearRef.price = -100000;
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    /*Print("Final trend array status:");
    for(int i = 0; i < ArraySize(trends); i++) {
        Print("i: ",i," indexP1: ",trends[i].indexP1,
            " (",Time[trends[i].indexP1],") indexP2: ",trends[i].indexP2," (",Time[trends[i].indexP2],")");
    }*/
	//Print("last time ", Time[trends[ArraySize(trends) - 1].indexP1], " at index ", trends[ArraySize(trends) - 1].indexP1);
	
	return;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(lastTime != Time[0]) {
        lastTime = Time[0];
        
        TSetup_checkTrades();
        analyzeBar();
    }
    
    RefreshRates();
	
	return;
}

//+------------------------------------------------------------------+

/**
 * IDENTIFY POSSIBLE TRENDS AND ACT ACCORDINGLY
 */
void analyzeBar() {
    /**
     V3:
     TRade logic (ewaves cross + testSwOut-testSwIn of trend).
     progressive stops for SL, and taking profit with trailing of stops.
     
     FROM v2:
     Trends up y Trends down funcionando simultaneamente.
     
     FROM v1:
     Trend up:
     el lowRef sirve como pivote,
     con cada nuevo close, se pregunta si es menor al lowRef para actualizar el pivote
     Al contrario, si es mayor, y se cumple que:
        - la distancia entre pivote y el close es mayor al parametro minimo
        - el angulo del posible trend (chequear todos los closes entre esos dos puntos para ajustar la pendiente) es aceptable 
     se crea el trend entonces..
     
     Para cada Trend activo en array,
        - Si el nuevo close reduce el angulo del trend a un valor inaceptable, eliminar trend.
        - Si el nuevo close se mantiene dentro del rango test del trend, chequear posible operacion de trade
            (actualizar pendiente si es necesario)
     OJO:
        - cada Close puede ser punto de partida solo de un trend.
        - para hacer algun order, un trend debe ser tocado en el test area un numero de veces (definido por parametro),
        - chequear nuevamente cada test si se actualiza la pendiente de un trend.
    **/
    
    if(Bars <= 1)
        return;
    
    //-------------------------------------------------------------------------- update ALL INDEXES
    bullRef.index++;
    bearRef.index++;
    for(int i = 0; i < ArraySize(trends); i++) {
        trends[i].indexP1++;
        trends[i].indexP2++;
        //update tests indexes too
        for(int j = 0; j < trends[i].testCount; j++)
            trends[i].tests[j]++;
    }
    
    //-------------------------------------------------------------------------- check pivots of bulls or bears
    if(bullBarBorder(1) < bullRef.price) {
        bullRef.price = bullBarBorder(1);
        bullRef.index = 1;
        bullRef.refTime = Time[1];
        //Print("bullRef time: ", bullRef.refTime);
    }
    
    if(bearBarBorder(1) > bearRef.price) {
        bearRef.price = bearBarBorder(1);
        bearRef.index = 1;
        bearRef.refTime = Time[1];
        //Print("bearRef time: ", bearRef.refTime);
    }
    
    //check possible new trends
    int pivotIndex = bullRef.index > bearRef.index ? bullRef.index : bearRef.index;
    while(pivotIndex > MIN_TREND_LENGTH) { //distance satisfies the minimum
        evalPossibleTrends(pivotIndex);
        pivotIndex --;
    }
    
    //-------------------------------------------------------------------------- update all active trends
    for(int i = 0; i < ArraySize(trends); i++) {
        //check validity
        //Print("calc angle between ", trends[i].indexP1, " and ", 1);
        double angle = calcLineAngle(trends[i].indexP1, 1); 
        if(MathAbs(angle) < MIN_TREND_ANGLE || angleTwisted(trends[i].angle, angle)) {  //Trend Line is broken
            TrendDelete(0, StringConcatenate("t_", trends[i].tname)); //remove line from chart
            
            Print("delete trend from: ", Time[trends[i].indexP1], " at: ", Time[1], " angle: ", angle);
            array_remove(trends, trends[i].indexP1);
            i--;
        }
        else { // ANGLE calculation and test touches.
            //Print("PARSING trend from ", Time[trends[i].indexP1]," to ", Time[trends[i].indexP2]," at :", Time[1]);
            //update trend angle if new angle is lower. (but still valid)
            if(MathAbs(angle) < MathAbs(trends[i].angle)) {
                trends[i].angle = angle;
                trends[i].indexP2 = 1;
                
                double barBorder = angle > 0 ? bullBarBorder(1) : bearBarBorder(1);
                TrendPointChange(0, StringConcatenate("t_", trends[i].tname), 1, Time[1], barBorder); //change line in chart
            }
            
            validateTestPoints(trends[i]); //check previous test points of trend
            //is new price a valid out position for trading?
            if(!inTrendTestArea(trends[i], 1, TRUE))
                if(trends[i].test_swOut == TRUE && trends[i].test_swIn == TRUE && trends[i].burned == FALSE)
                    TSetup_evalPossibleTrade(trends[i]);
                    
            //Print("--- swIn: ", trends[i].test_swIn, " swOut: ", trends[i].test_swOut);
        }
    }
}

/**
 * CREATE new trends if satisfy conditions
 */
void evalPossibleTrends(int pivotIndex) {
    double angle = calcLineAngle(pivotIndex, 1);
    bool valid = validateLineAngle(pivotIndex, 1, angle);
    if(valid) {
        if(availablePoint(pivotIndex)) {
            createTrend(pivotIndex, 1, angle); // create a new trend line
            //Print("valid new trend: p1 ", Time[pivotIndex], " p2 ", Time[1], " angle: ", angle);
        }
    }
    //else
        //Print("no trend between ", Time[pivotIndex], " and ", Time[1]);
}

/**
 * check if this point is taken by another trend or if its free
 */
bool availablePoint(int index) {
    for(int i = 0; i < ArraySize(trends); i++) {
        if(trends[i].indexP1 == index) {
            //Print("not available");
            return FALSE;
        }
    }
    
    return TRUE;
}

/**
 * Calculate angle of line
 */
double calcLineAngle(int index1, int index2) {
    double angle;
    
    double x = index1 - index2; //order is inversed
    double y;
    if(bullBarBorder(index2) >= bullBarBorder(index1))
        y = (bullBarBorder(index2) - bullBarBorder(index1)) / Y_UNIT;
    else
        y = (bearBarBorder(index2) - bearBarBorder(index1)) / Y_UNIT;
    angle = MathArctan(y / x);
    
    //if(angle >= 0.5)
        //Print("calc. angle. index1: ", Time[index1], ", index2: ", Time[index2], " x: ", x, ", y: ", y, " angle: ", angle);
    return angle;
}

/**
 * Verify the angle between two points and check if it is a valid trend line
 * testing all price borders between
 */
bool validateLineAngle(int index1, int index2, double angle) {
    if(MathAbs(angle) < MIN_TREND_ANGLE) {
        //Print("angle too small: ", angle);
        return FALSE;
    }
        
    for(int i = index1 - 1; i > index2; i--) {
        int x = index1 - i;
        
        if(angle < 0) { // bearish
            double y = bearBarBorder(index1) + x*MathTan(angle)*Y_UNIT;
            
            if(bearBarBorder(i) > y + Y_UNIT*TREND_TEST_AREA/2) {
                //Print(Time[index1], " - " , Time[index2], " y: ", y, " bar: ", bearBarBorder(i), " at ", Time[i]);
                return FALSE;
            }
        }
        else { //bullish
            double y = bullBarBorder(index1) + x*MathTan(angle)*Y_UNIT;
            
            if(bullBarBorder(i) < y - Y_UNIT*TREND_TEST_AREA/2) {
                //Print("price invalidated for trend ", Time[index1], " - " , Time[index2], " y: ", y, " bar: ", bullBarBorder(i), " at ", Time[i]);
                return FALSE;
            }
        } 
    }
    
    return TRUE;
}

/**
 * Verify if the angle of a trend has changed orientation
 */
bool angleTwisted(double angle1, double angle2) {
    if(angle1 > 0 && angle2 < 0)
        return TRUE;
        
    if(angle1 < 0 && angle2 > 0)
        return TRUE;
        
    return FALSE;
}

/**
 * Check if a price is inside test area of a trend
 */
bool inTrendTestArea(trend_t& trend, int index, bool evaluatingClose) {
    double space = Y_UNIT*TREND_TEST_AREA / 2;
    
    int x = trend.indexP1 - index;
    double firstY = trend.angle > 0 ? bullBarBorder(trend.indexP1) : bearBarBorder(trend.indexP1);
    double y = firstY + x*MathTan(trend.angle)*Y_UNIT;
    
    double p_point;
    if(evaluatingClose)
        p_point = Close[index];
    else
        p_point = trend.angle > 0 ? bullBarBorder(index) : bearBarBorder(index);
    
    bool touched;
    if(p_point <= y + space && p_point >= y - space)
        touched = TRUE;    
    else
        touched = FALSE;
    
    //Print("testing point in trend area: [", y-space, ", ", y+space, "] price: ", p_point," result: ", touched);
    return touched;
}

/**
 * validate a trend, to check swOut/swIn states
 */
void validateTestPoints(trend_t& trend) {
    trend.test_swIn = FALSE;
    trend.test_swOut = FALSE;
    for(int i = trend.indexP1; i > 1; i--) {
        bool inArea = inTrendTestArea(trend, i, FALSE);
        if(!inArea) {
            trend.test_swOut = TRUE;
            if(trend.test_swIn == TRUE)
                trend.burned = TRUE;
        }
        else if(trend.test_swOut == TRUE)
            trend.test_swIn = TRUE;
    }    
}

/**
 * FOR bullish trend:
 * a bar going up, take the open
 * a bar going down, take the close
 */
double bullBarBorder(int index) {
    if(Close[index] <= Open[index])
        return Close[index];
    else
        return Open[index];
}

/**
 * FOR bearish trend:
 * a bar going up, take the close
 * a bar going down, take the open
 */
double bearBarBorder(int index) {
    if(Close[index] <= Open[index])
        return Open[index];
    else
        return Close[index];
}

/**
 * Create a new trend, add to trends array
 */
void createTrend(int p1, int p2, double angle) {
    trend_t newT;
    
    newT.angle = angle;
    newT.indexP1 = p1;
    newT.indexP2 = p2;
    
    newT.testCount = 0;
    newT.test_swIn = FALSE;
    newT.test_swOut = FALSE;
    newT.burned = FALSE;

    newT.tname = GetTickCount();
    
    array_push(trends, newT);
    //Print("trends size: ", ArraySize(trends));
    
    //Draw line in chart
    datetime time1 = Time[p1];
    double price1 = angle > 0 ? bullBarBorder(p1) : bearBarBorder(p1);
    datetime time2 = Time[p2];
    double price2 = angle > 0 ? bullBarBorder(p2) : bearBarBorder(p2);
    TrendCreate(0, StringConcatenate("t_", newT.tname), 0, time1, price1, time2, price2, clrRed, STYLE_SOLID, 1, false, true, false, true);
}
 
/**
 * insert trend to array
 */
void array_push(trend_t&  array[], trend_t& trend) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = trend;
}

/**
 * remove a trend from array and resize
 */
void array_remove(trend_t& array[], int indexP1) {
    int length = ArraySize(array);
    trend_t narray[];
    
    ArrayResize(narray, length - 1);
    for(int i = 0, j = 0; i < length; i++) {
    	if(array[i].indexP1 == indexP1)
    		continue;
    	else {
    		narray[j] = array[i];
    		j++;
    	}
    }
    
    ArrayCopy(array, narray);
    ArrayResize(array, length - 1);
}

/**
 * insert order to array
 */
void o_array_push(order_t&  array[], order_t& order) {
	int length = ArraySize(array);
	length++;
	
	ArrayResize(array, length);
	array[length - 1] = order;
}

/**
 * remove an order from array and resize
 */
void o_array_remove(order_t& array[], int ticket) {
    int length = ArraySize(array);
    order_t narray[];
    
    ArrayResize(narray, length - 1);
    for(int i = 0, j = 0; i < length; i++) {
    	if(array[i].ticket == ticket)
    		continue;
    	else {
    		narray[j] = array[i];
    		j++;
    	}
    }
    
    ArrayCopy(array, narray);
    ArrayResize(array, length - 1);
}

/**
 * TREND DRAWING *********************************************************************************************************************
 * Taken from MQL DOCS
 *
 */
 
 //+------------------------------------------------------------------+
//| Create a trend line by the given coordinates                     |
//+------------------------------------------------------------------+
bool TrendCreate(const long            chart_ID=0,        // chart's ID
                 const string          name="TrendLine",  // line name
                 const int             sub_window=0,      // subwindow index
                 datetime              time1=0,           // first point time
                 double                price1=0,          // first point price
                 datetime              time2=0,           // second point time
                 double                price2=0,          // second point price
                 const color           clr=clrRed,        // line color
                 const ENUM_LINE_STYLE style=STYLE_SOLID, // line style
                 const int             width=1,           // line width
                 const bool            back=false,        // in the background
                 const bool            selection=true,    // highlight to move
                 const bool            ray_left=false,    // line's continuation to the left
                 const bool            ray_right=false,   // line's continuation to the right
                 const bool            hidden=true,       // hidden in the object list
                 const long            z_order=0)         // priority for mouse click
  {
//--- set anchor points' coordinates if they are not set
   ChangeTrendEmptyPoints(time1,price1,time2,price2);
//--- reset the error value
   ResetLastError();
//--- create a trend line by the given coordinates
   if(!ObjectCreate(chart_ID,name,OBJ_TREND,sub_window,time1,price1,time2,price2))
     {
      Print(__FUNCTION__,
            ": failed to create a trend line! Error code = ",GetLastError());
      return(false);
     }
//--- set line color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line display style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the line by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- enable (true) or disable (false) the mode of continuation of the line's display to the left
   ObjectSetInteger(chart_ID,name,OBJPROP_RAY_LEFT,ray_left);
//--- enable (true) or disable (false) the mode of continuation of the line's display to the right
   ObjectSetInteger(chart_ID,name,OBJPROP_RAY_RIGHT,ray_right);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Move trend line anchor point                                     |
//+------------------------------------------------------------------+
bool TrendPointChange(const long   chart_ID=0,       // chart's ID
                      const string name="TrendLine", // line name
                      const int    point_index=0,    // anchor point index
                      datetime     time=0,           // anchor point time coordinate
                      double       price=0)          // anchor point price coordinate
  {
//--- if point position is not set, move it to the current bar having Bid price
   if(!time)
      time=TimeCurrent();
   if(!price)
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- reset the error value
   ResetLastError();
//--- move trend line's anchor point
   if(!ObjectMove(chart_ID,name,point_index,time,price))
     {
      Print(__FUNCTION__,
            ": failed to move the anchor point! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| The function deletes the trend line from the chart.              |
//+------------------------------------------------------------------+
bool TrendDelete(const long   chart_ID=0,       // chart's ID
                 const string name="TrendLine") // line name
  {
//--- reset the error value
   ResetLastError();
//--- delete a trend line
   if(!ObjectDelete(chart_ID,name))
     {
      Print(__FUNCTION__,
            ": failed to delete a trend line! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Check the values of trend line's anchor points and set default   |
//| values for empty ones                                            |
//+------------------------------------------------------------------+
void ChangeTrendEmptyPoints(datetime &time1,double &price1,
                            datetime &time2,double &price2)
  {
//--- if the first point's time is not set, it will be on the current bar
   if(!time1)
      time1=TimeCurrent();
//--- if the first point's price is not set, it will have Bid value
   if(!price1)
      price1=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- if the second point's time is not set, it is located 9 bars left from the second one
   if(!time2)
     {
      //--- array for receiving the open time of the last 10 bars
      datetime temp[10];
      CopyTime(Symbol(),Period(),time1,10,temp);
      //--- set the second point 9 bars left from the first one
      time2=temp[0];
     }
//--- if the second point's price is not set, it is equal to the first point's one
   if(!price2)
      price2=price1;
  }