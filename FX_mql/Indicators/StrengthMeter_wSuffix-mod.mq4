//+------------------------------------------------------------------+
//|                                                     strMeter.mq4 |
//|                                                          Flotsom |
//+------------------------------------------------------------------+
//downloaded from http://www.forexfactory.com/showthread.php?p=6321574#post6321574
//added autosuffix-function, fxdaytrader (forexBaron.net)
#property indicator_separate_window
#property indicator_buffers 8
#property copyright "Copyright by flotsom // mod. JimDandy, fxdaytrader"
#property link "http://ForexBaron.net"
#define X_BARSPACING		22
#define Y_BARSPACING		1
#define BAR_STR				"I"
#define BAR_ANGLE			90
#define X_BASELINE0			0
#define X_BASELINE1			200
#define X_BASELINE2			500
#define X_CUROFF			0
#define X_DIVOFF			-5
#define Y_BASELINE0			70
#define Y_BASELINE1			70
#define Y_BASELINE2			85
#define Y_BASELINE3			135
#define Y_BASELINE4			138
#define FTSIZE_BAR			13
#define FTSIZE_CUR			7
#define FTSIZE_SYM			6
#define SCALE				10000
#define PIXEL_SCALE			0.5
#define SUGCHT_HEIGHT		40
#define LINECHTHEIGHT0		50
#define LINECHTHEIGHT1		90

#define MAX					100
#define MIN					0
#property indicator_maximum	MAX
#property indicator_minimum	MIN
//*/

extern string	Currencies		= "EUR,USD,GBP,JPY,CHF,CAD,AUD,NZD";
extern string	CurrDisplay		= "1,1,1,1,1,1,1,1";
//extern string	SymbolFixes		="";									//for irregular Symbols
extern bool    AutoSuffixAdjust  = true; //try to get symbol suffix automatically, fxdaytrader
extern string	SymbolSuffixes		="";									//for irregular Symbols
extern string	SymbolPrefixes		="";									//for irregular Symbols
extern string	ShowSignal		= "EURUSD,EURCHF,EURJPY,GBPUSD,USDCHF,GBPJPY,GBPCHF,AUDUSD";
extern int		TimeFrame		= 0;
extern int		StrengthBase	= 60;
extern int		RecentCHBase	= 10;
extern bool		ShowLineChart	= true;
extern bool		ShowBarChart	= true;
extern bool		UpdateOnTick	= false;
extern bool		AllowAlert		= false;
extern bool		AllowSound		= false;
extern int		MinAlertIntv	= 30;
extern int		LineChartBars	= 200;
extern int		LegendOffestY	= 20;
extern int		MeterPosition	= 20;
extern color	BullColor		= Green;
extern color	BearColor		= Red;
extern color	Color0			= Magenta;
extern color	Color1			= Blue;
extern color	Color2			= Red;
extern color	Color3			= Yellow;
extern color	Color4			= Gray;
extern color	Color5			= Green;
extern color	Color6			= Brown;
extern color	Color7			= Orange;
extern color	TextColor		= White;

double	oLine0[],oLine1[],oLine2[],oLine3[],oLine4[],oLine5[],oLine6[],oLine7[];

int			gCurs,gSyms;
int			gBC,gTF,gWindow,gXoff,gYoff;
string		gCur[],gSym[];
int			gSymCurLft[],gSymCurRgt[];
int			gSymLastNtfDir[],gSymNtfList[];
double		gPrBuf[],gSymWgt[],gCurWgt[];
string		gObjPrefix,gPrfx,gSufx;
bool		gShow[],gShowSym[];
color		gCurColor[8];
datetime	gSymLastNtfTime[];

int init()
{
	gBC=0;
	setPairs();
	gXoff=MeterPosition;
	int id;
	id=newID();
	gObjPrefix=StringConcatenate(id,"_strM_");
	gTF=TimeFrame;
	IndicatorShortName("");
	return(0);
}

//deinitialization
int deinit()
{
	gWindow=WindowOnDropped();
	ObjectsDeleteAll(gWindow);
	return(0);
}

int start()
{
	if (!UpdateOnTick) {
		if (gBC==iBars(Symbol(),gTF)) return(0);
		gBC=iBars(Symbol(),gTF);
	}
	gWindow=WindowOnDropped();
	if (gWindow==-1) {
		Print("window error");
		return(0);
	}
	ObjectsDeleteAll(gWindow);
	drawLines();
	drawMeter();
	
	return(0);
}

//Draw Begin
void drawLegend()
{
	int i,y;
	string name;

	y=FTSIZE_CUR*2;
	if (ShowBarChart) y+=LegendOffestY+Y_BASELINE0+100*PIXEL_SCALE;

	for (i=0;i<gCurs;i++) {
		name=StringConcatenate(gObjPrefix,i,"_LEGT");
		drawLabel(name,i*X_BARSPACING+X_BASELINE0+X_CUROFF,y,gCur[i],gCurColor[i],0,FTSIZE_CUR);
		if (!gShow[i] || i>=8) continue;
		name=StringConcatenate(gObjPrefix,i,"_LEGL");
		drawLabel(name,i*X_BARSPACING+X_BASELINE0+X_CUROFF,y+3," ___",gCurColor[i],0,FTSIZE_CUR);
	}
}

void drawLines()
{
	int i,j,bm;
	double k,b,max,min,upper,lower;
	calc(0,LineChartBars-1,StrengthBase,LineChartBars);
	lower=MIN;
	if (!ShowLineChart) return;
	if (ShowBarChart) upper=(LINECHTHEIGHT0*MAX+(100-LINECHTHEIGHT0)*MIN)/100;
	else upper=(LINECHTHEIGHT1*MAX+(100-LINECHTHEIGHT1)*MIN)/100;
	max=0;min=0;
	for (i=0;i<gCurs;i++) {
		bm=i*LineChartBars;
		for (j=0;j<LineChartBars;j++) {
			if (gPrBuf[bm+j]>max) max=gPrBuf[bm+j];
			if (gPrBuf[bm+j]<min) min=gPrBuf[bm+j];
		} 
	}
	if (max-min==0) return;
	k=(upper-lower)/(max-min);
	b=lower-min*k;//*/
//	k=1;b=0;
	for (i=0;i<gCurs && i<8;i++) {
		if (!gShow[i]) continue;
		bm=i*LineChartBars;
		for (j=0;j<LineChartBars;j++) {
			switch (i) {
			case 0:oLine0[j]=k*gPrBuf[bm+j]+b;break;
			case 1:oLine1[j]=k*gPrBuf[bm+j]+b;break;
			case 2:oLine2[j]=k*gPrBuf[bm+j]+b;break;
			case 3:oLine3[j]=k*gPrBuf[bm+j]+b;break;
			case 4:oLine4[j]=k*gPrBuf[bm+j]+b;break;
			case 5:oLine5[j]=k*gPrBuf[bm+j]+b;break;
			case 6:oLine6[j]=k*gPrBuf[bm+j]+b;break;
			case 7:oLine7[j]=k*gPrBuf[bm+j]+b;break;
			}
		}
		SetIndexDrawBegin(i,Bars-LineChartBars);
	}
	drawLegend();
}

void drawLabel(string name, int x, int y, 
				string text, color clr, double angle=BAR_ANGLE,
				int fontsize=FTSIZE_BAR, string font="Arial")
{
//	ObjectDelete(name);
	ObjectCreate(name,OBJ_LABEL,gWindow,0,0);
	ObjectSetText(name,text,fontsize,font,clr);
	ObjectSet(name,OBJPROP_XDISTANCE,x+gXoff);
	ObjectSet(name,OBJPROP_YDISTANCE,y+gYoff);
	ObjectSet(name,OBJPROP_ANGLE,angle);
}

void drawTexts()
{
	int i,j;
	string name;

	j=0;
	for (i=0;i<gCurs;i++) {
		if (!gShow[i]) continue;
		name=StringConcatenate(gObjPrefix,0,"_",i,"_SYM");
		drawLabel(name,j*X_BARSPACING+X_BASELINE0+X_CUROFF,Y_BASELINE0,gCur[i],TextColor,0,FTSIZE_CUR);
		name=StringConcatenate(gObjPrefix,1,"_",i,"_SYM");
		drawLabel(name,j*X_BARSPACING+X_BASELINE1+X_CUROFF,Y_BASELINE0,gCur[i],TextColor,0,FTSIZE_CUR);
		j++;
	}
}

void drawBars(int section,int isym,double level)
{
	int i,x,y0,ystep,yend,b;
	static int offsetX[]={X_BASELINE0,X_BASELINE1,X_BASELINE2};
	string name;
	color clr;

	x=offsetX[section]+isym*X_BARSPACING;
	
	if (level>0) {
		b=MathRound(level*PIXEL_SCALE);
		yend=Y_BASELINE1-b;
		y0=Y_BASELINE1;
		ystep=-Y_BARSPACING;
		clr=BullColor;
	} else {
		b=MathRound(-level*PIXEL_SCALE);
		yend=Y_BASELINE2+b;
		y0=Y_BASELINE2;
		ystep=Y_BARSPACING;
		clr=BearColor;
	}
	b=b/Y_BARSPACING;
	
	for (i=0;i<b;i++) {
		name=StringConcatenate(gObjPrefix,section,"_",isym,"_",i);
		drawLabel(name,x,y0+i*ystep,BAR_STR,clr);
	}
	return;
}

void drawMeter()
{
	int i,j,k;
	double value,level,max,min;
	int sdir[],rdir[];
	
	ArrayResize(sdir,gCurs);
	ArrayResize(rdir,gCurs);
	ArrayInitialize(sdir,0);
	ArrayInitialize(rdir,0);

	calc(0,0,StrengthBase,1);

	max=0;min=0;
	for (i=0;i<gCurs;i++) {
		value=gPrBuf[i];
		if (value>0) {
			sdir[i]=1;
			if (value>max) max=value;
		} else if (value<0) {
			sdir[i]=-1;
			if (value<min) min=value;
		}
	}

	if (ShowBarChart) {
		k=0;
		for (i=0;i<gCurs;i++) {
			if (!gShow[i]) continue;
			value=gPrBuf[i];
			if (value>0) level=MathRound(100*value/max);
			else level=-MathRound(100*value/min);
			drawBars(0,k,level);
			k++;
		}
	}

	calc(0,0,RecentCHBase,1);

	max=0;min=0;
	for (i=0;i<gCurs;i++) {
		value=gPrBuf[i];
		if (value>0) {
			rdir[i]=1;
			if (value>max) max=value;
		} else if (value<0) {
			rdir[i]=-1;
			if (value<min) min=value;
		}
	}

	if (ShowBarChart) {
		k=0;
		for (i=0;i<gCurs;i++) {
			if (!gShow[i]) continue;
			value=gPrBuf[i];
			if (value>0) level=MathRound(100*value/max);
			else level=-MathRound(100*value/min);
			drawBars(1,k,level);
			k++;
		}
		drawTexts();
	}

	string sym,name;
//	color clr;
	int symidx;
	k=0;
	for (i=0;i<gCurs;i++) {
		if (!gShow[i]) continue;
		if (sdir[i]!=rdir[i]) continue;
		for (j=i+1;j<gCurs;j++) {
			if (!gShow[j]) continue;
			if (sdir[j]!=rdir[j]) continue;
			if (sdir[i]==sdir[j]) continue;
			sym=makeSym(i,j);
			symidx=lookupSym(sym);
			
			if (symidx<0) {
				sym=makeSym(j,i);
				symidx=lookupSym(sym);
				if (symidx<0) continue;
				if (sdir[i]>0) level=-SUGCHT_HEIGHT;
				else level=SUGCHT_HEIGHT;
			} else if (sdir[i]>0) level=SUGCHT_HEIGHT;
			else level=-SUGCHT_HEIGHT;
			if (!gShowSym[symidx]) continue;
			if (ShowBarChart) {
				drawBars(2,k*2,level);
				name=StringConcatenate(gObjPrefix,"_",k,"_DIV");
				drawLabel(name,k*2*X_BARSPACING+X_BASELINE2+X_DIVOFF,Y_BASELINE0,sym,TextColor,0,FTSIZE_SYM);
			}
			gSymNtfList[symidx]=level;
			k++;
		}
	}
	if (AllowAlert || AllowSound) doNotify();
}

void doNotify()
{
	int i,j;
	datetime dt;
	string alstr="Suggested pairs:";

	dt=TimeCurrent();
	j=0;
	for (i=0;i<gSyms;i++) {
		if (gSymNtfList[i]==0) continue;
		if (gSymNtfList[i]!=gSymLastNtfDir[i] || dt-gSymLastNtfTime[i]>MinAlertIntv) {
			j++;
			gSymLastNtfDir[i]=gSymNtfList[i];
			alstr=StringConcatenate(alstr,"[",gSym[i],"]");
		}
		gSymLastNtfTime[i]=dt;
	}
	if (j==0) return;
	if (AllowAlert) Alert(alstr);
	if (AllowSound) PlaySound("alert.wav");
}//*/
//Draw End

//| Strength calc Begin
void calc(int start,int end,int bars_back, int prbuflen)
{
	int i,j,l,r;
	double ratio,base;
	double wgt[];
	
	ArrayResize(wgt,gCurs);
	for (i=0;i<gCurs;i++) wgt[i]=gCurWgt[i];
	
	ArrayInitialize(gPrBuf,0);
	for (i=0;i<gSyms;i++) {
		l=gSymCurLft[i];
		r=gSymCurRgt[i];
		l*=prbuflen;
		r*=prbuflen;
		for (j=0;j<prbuflen;j++) {
			base=iOpen(gSym[i],gTF,j+bars_back);
			if (base==0) continue;
			ratio=iClose(gSym[i],gTF,j)/base;
			gPrBuf[l+j]+=gSymWgt[i]*ratio;
			gPrBuf[r+j]+=gSymWgt[i]/ratio;
		}
	}
	for (i=0;i<gCurs;i++) {
		l=i*prbuflen;
		for (j=0;j<prbuflen;j++) {
			if (wgt[i]==0) continue;
			gPrBuf[l+j]/=wgt[i];
			gPrBuf[l+j]-=SCALE;
		}
	}

}

//| Strength calc End

//| Init settings Begin
bool testSym(string sym)
{
	GetLastError();
	if (iBars(sym,gTF)>0) return (true);
	int error=GetLastError();
	if (4066==error) {
		Print("Waiting for data of [",sym,"].");
		return (true);
	}
//	if (error!=0) Print("Error ",error," occured testing Symbol [",sym,"]");
	return (false);
}

int lookupSym(string sym)
{
	for (int i=0;i<gSyms;i++)
		if (gSym[i]==sym) return (i);
//	int error=GetLastError();
//	if (error!=0) Print("Error ",error," occured looking up Symbol [",sym,"], i=",i,"|gSyms=",gSyms);
	return (-1);
}

bool findNaddPair(int left,int right,int c)
{
	string sym=makeSym(left,right);
	int s=lookupSym(sym);
	if (s<0) {
		if (testSym(sym)) {
			gSym[gSyms]=sym;
			gSymCurLft[gSyms]=left;
			gSymCurRgt[gSyms]=right;
			gSyms++;
		} else return(false);
	}
//	Print("Symbol [",sym,"] found for currency [",gCur[c],"].");
	return (true);
}

void setPairs()
{
	int i,j,k,s;
	string current,workstr;
   gPrfx=SymbolPrefixes;
   if (!AutoSuffixAdjust) gSufx=SymbolSuffixes;
   if (AutoSuffixAdjust) gSufx = GetAutoSymbolSuffix();
   
   workstr = normalizeStr(Currencies,",");
Print("workstr returned is "+workstr);

	s = 0;gCurs=0;
	i = StringFind(workstr,",",s);
	while (i > 0)
	{
		if (i-s>0) {
			current = stringUpperCase(StringSubstr(workstr,s,i-s));
			gCurs++;
			ArrayResize(gCur,gCurs);
			gCur[gCurs-1]=current;
		}
		s = i + 1;
		i = StringFind(workstr,",",s);
	}
	ArrayResize(gSym,(gCurs-1)*gCurs/2);
	ArrayResize(gSymCurLft,(gCurs-1)*gCurs/2);
	ArrayResize(gSymCurRgt,(gCurs-1)*gCurs/2);
	ArrayResize(gPrBuf,LineChartBars*gCurs);
	ArrayResize(gCurWgt,gCurs);
	ArrayResize(gShow,gCurs);

	gSyms=0;
	for (i=0;i<gCurs;i++) {
		k=0;current="";
		for (j=0;j<gCurs;j++) {
			if (i==j) continue;
			if (findNaddPair(i,j,i)) {k++;current=current+"["+makeSym(i,j)+"]";continue;}
			if (findNaddPair(j,i,i)) {k++;current=current+"["+makeSym(j,i)+"]";continue;}
		//	Print("No Symbol found for ",gCur[i]," vs ",gCur[j]," not found.");
		}
		if (k>0) {
			Print (k," Symbols found for currency [",gCur[i],"]:",current);
			continue;
		}
		Print ("No symbol found for currency [",gCur[i],"], removed from list.");
		gCurs--;
		for (j=i;j<gCurs;j++) gCur[j]=gCur[j+1];
		i--;
	}//*/
	ArrayResize(gShowSym,gSyms);
	ArrayResize(gSymWgt,gSyms);
	ArrayResize(gSymLastNtfDir,gSyms);
	ArrayResize(gSymLastNtfTime,gSyms);
	ArrayResize(gSymNtfList,gSyms);
	ArrayInitialize(gCurWgt,0);
	ArrayInitialize(gSymLastNtfDir,0);
	ArrayInitialize(gSymLastNtfTime,0);
	ArrayInitialize(gSymNtfList,0);
	ArrayInitialize(gSymWgt,100);
	for (i=0;i<gSyms;i++) {
		gCurWgt[gSymCurLft[i]]+=gSymWgt[i];
		gCurWgt[gSymCurRgt[i]]+=gSymWgt[i];
		gSymWgt[i]*=SCALE;
		gShowSym[i]=false;
	}
	workstr = normalizeStr(ShowSignal,",");
	s = 0;i = StringFind(workstr,",",s);
	while (i > 0)
	{
		if (i-s>0) {
			current = stringUpperCase(StringSubstr(workstr,s,i-s));
			k=lookupSym(StringConcatenate(gPrfx,current,gSufx));
			if (k>=0) {
				gShowSym[k]=true;
			}
		}
		s = i + 1;
		i = StringFind(workstr,",",s);
	}
	current="";
	for (i=0;i<gSyms;i++) if (gShowSym[i]) current=StringConcatenate(current,"[",gSym[i],"]");
	Print("Show signal of ",current);
	Print("Symbols setting finished.");
	
	int lines;
	if (gCurs>8) lines=8;
	else lines=gCurs;
	if (lines>0) {SetIndexBuffer(0,oLine0);gCurColor[0]=Color0;}
	if (lines>1) {SetIndexBuffer(1,oLine1);gCurColor[1]=Color1;}
	if (lines>2) {SetIndexBuffer(2,oLine2);gCurColor[2]=Color2;}
	if (lines>3) {SetIndexBuffer(3,oLine3);gCurColor[3]=Color3;}
	if (lines>4) {SetIndexBuffer(4,oLine4);gCurColor[4]=Color4;}
	if (lines>5) {SetIndexBuffer(5,oLine5);gCurColor[5]=Color5;}
	if (lines>6) {SetIndexBuffer(6,oLine6);gCurColor[6]=Color6;}
	if (lines>7) {SetIndexBuffer(7,oLine7);gCurColor[7]=Color7;}
	for (i=0;i<lines;i++) gShow[i]=true;
	workstr = normalizeStr(CurrDisplay,",");
	j=0;s=0;i = StringFind(workstr,",",s);
	while (i>=0 && j<lines) {
		k = StrToInteger(StringSubstr(workstr,s,i-s));
		if (k==0) gShow[j]=false;
		j++;
		s = i + 1;
		i = StringFind(workstr,",",s);
	}
	for (i=0;i<lines;i++) {
		SetIndexLabel(i,gCur[i]);
		SetIndexStyle(i,DRAW_LINE,EMPTY,EMPTY,gCurColor[i]);
	}
	
}//*/

int newID()
{
	int id;
	if(!GlobalVariableCheck("id")) {
		id=0;
	} else id=1+GlobalVariableGet("id");
	GlobalVariableSet("id",id);
	
	return(id);
}




//////////////////////////////////////////////////////
string makeSym(int left, int right)
{
	return (StringConcatenate(gPrfx,gCur[left],gCur[right],gSufx));
}
////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////
string normalizeStr(string s,string div)//s =USD and div = ,
{
	string workstr = StringTrimLeft(StringTrimRight(s));
	if (StringSubstr(workstr,StringLen(workstr),1) != div)
		workstr = StringConcatenate(workstr,div);
	return (workstr);
}
////////////////////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////////////////////////////////
string stringUpperCase(string str)
{
	string s=str;
	int Char,lenght=StringLen(str)-1;
	while(lenght>=0)
	 {
		Char=StringGetChar(s,lenght);
		if((Char>96 && Char<123) || (Char>223 && Char<256))
			s=StringSetChar(s,lenght,Char-32);
		else if(Char>-33 && Char<0)
			s=StringSetChar(s,lenght,Char+224);
		lenght--;
	 }
	return(s);
} 

string GetAutoSymbolSuffix() {
 string suffix="";
  if (StringLen(Symbol())>6) suffix = StringSubstr(Symbol(),6,StringLen(Symbol())-6);
 return(suffix);
}