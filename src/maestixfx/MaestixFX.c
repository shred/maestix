/*
 * Maestix Library
 *
 * Copyright (C) 2021 Richard "Shred" Koerber
 *	http://maestix.shredzone.org
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <string.h>
#include <clib/alib_protos.h>
#include <devices/timer.h>
#include <exec/memory.h>
#include <libraries/maestix.h>
#include <libraries/mui.h>
#include <MUI/Lamp_mcc.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/maestix.h>
#include <proto/muimaster.h>


#define USE_MFX_COLORS
#define USE_MFX_BODY
#define USE_LOGO_BODY
#define USE_LOGO_COLORS
#include "PIC_mfx.h"
#include "PIC_Logo.h"

#define VERSION "1.5"
#define VDATE   "23.10.2021"

#define REFRESHRATE (50000)       // unit microseconds
#define LEVELINERT  (5)           // slowness of the level meter (bigger = slower)
#define LEDDELAY    (10)          // refresh rate until a stable signal is detected
#define MAX_ECHO    (3)           // maximum echo length in seconds

#define MAKE_ID(a,b,c,d)        \
        ((ULONG) (a)<<24 | (ULONG) (b)<<16 | (ULONG) (c)<<8 | (ULONG) (d))

struct Library *MUIMasterBase;    // Library bases
struct Library *MaestixBase;

struct MaestroBase *mbase;
struct MsgPort *timerport;        // Port for timer.device
struct timerequest *timerio;      // IO structure for timer.device

Object *app;                      // Application object
Object *window;                   // Window object

Object *LV_Effects, *LVL_Effects;
Object *LED_32KHZ, *LED_441KHZ, *LED_48KHZ;
Object *LED_Emphasis, *LED_DatSrc, *LED_CopyProh;
Object *CY_Input, *CY_Format, *CY_SCMS, *CY_Emphasis, *CY_Source, *CY_Rate;
Object *CH_Realtime, *GR_Page, *GR_Encoder;
Object *SL_VolL, *SL_VolR, *SL_Shift, *SL_Entry, *SL_Fade, *SL_Length;
Object *SL_BitL, *SL_BitR, *SL_OffL, *SL_OffR, *SL_Rate, *SL_Duty;
Object *SL_RateL, *SL_RateR;
Object *LM_Left, *LM_Right;

Object **idlist[] = {
  &LVL_Effects,
  &CY_Input,&CY_Format,&CY_SCMS,&CY_Emphasis,&CY_Source,&CY_Rate,
  &CH_Realtime,
  &SL_VolL,&SL_VolR,&SL_Shift,&SL_Entry,&SL_Fade,&SL_Length,
  &SL_BitL,&SL_BitR,&SL_OffL,&SL_OffR,&SL_Rate,&SL_Duty,
  &SL_RateL,&SL_RateR,
  NULL
};

struct MUI_CustomClass *CL_FracSlider;

struct MRTorus    torus = {0};
struct MRReSample resample = {0};

BOOL realtiming = FALSE;

enum {FXP_EMPTY,FXP_VOLUME,FXP_SPATIAL,FXP_ECHO,FXP_QUANTISIZE,FXP_OFFSET,FXP_ROBOT,FXP_RESAMPLE};
enum {ID_LVCHANGE=1,ID_UPDATE,ID_START,ID_STOP,ID_SLIDSETUP,ID_SLIDUPDATE};

const WORD FXType[] =
{
  RFX_Bypass,
  RFX_Muting,
  RFX_LeftOnly,
  RFX_RightOnly,
  RFX_ChannelSwap,
  RFX_Volume,
  RFX_Mono,
  RFX_Karaoke,
  RFX_Spatial,
  RFX_Surround,
  RFX_Foregnd,
  RFX_Robot,
  RFX_Echo,
  RFX_Mask,
  RFX_ReSample,
  RFX_Offset
};
const WORD FXPage[] =
{
  FXP_EMPTY,        // Bypass
  FXP_EMPTY,        // Muting
  FXP_EMPTY,        // LeftOnly
  FXP_EMPTY,        // RightOnly
  FXP_EMPTY,        // ChannelSwap
  FXP_VOLUME,       // Volume
  FXP_EMPTY,        // Mono
  FXP_EMPTY,        // Karaoke
  FXP_SPATIAL,      // Spatial
  FXP_EMPTY,        // Surround
  FXP_EMPTY,        // Foregnd
  FXP_ROBOT,        // Robot
  FXP_ECHO,         // Echo
  FXP_QUANTISIZE,   // Mask
  FXP_RESAMPLE,     // ReSample
  FXP_OFFSET        // Offset
};
const char *FXList[] =
{
  "Bypass",
  "Mute",
  "Left Only",
  "Right Only",
  "Swap Channels",
  "Volume",
  "Mono",
  "Karaoke",
  "Spatial",
  "Surround",
  "Foreground",
  "Robot",
  "Echo",
  "Quantisize",
  "ReSample",
  "Offset",
  NULL
};

const char *CYA_Input[] =
{
  "Default",
  "Optical",
  "Coaxial",
  NULL
};
const char *CYA_Format[] =
{
  "S/P-DIF",
  "AES/EBU",
  NULL
};
const char *CYA_SCMS[] =
{
  "as Input",
  "Off",
  "Restricted",
  "Prohibited",
  NULL
};
const char *CYA_Emphasis[] =
{
  "as Input",
  "Off",
  "50\xB5s",
  "CCITT",
  "Manual",
  NULL
};
const char *CYA_Source[] =
{
  "as Input",
  "CD",
  "DAT",
  "DSR",
  "ADC",
  "Instrument",
  NULL
};
const char *CYA_Rate[] =
{
  "as Input",
  "32000 Hz",
  "44100 Hz",
  "48000 Hz",
  "Manual",
  NULL
};

const char *RG_Title[] =
{
  "About",
  "Realtime FX",
  "Encoder",
  NULL
};

struct MSL_Data
{
  char buf[50];
};

static __saveds ULONG MSL_Dispatcher(
  __reg("a0") struct IClass *cl,
  __reg("a2") Object *obj,
  __reg("a1") Msg msg
)
{
  if(msg->MethodID == MUIM_Numeric_Stringify)
  {
    struct MSL_Data *data = INST_DATA(cl,obj);
    struct MUIP_Numeric_Stringify *m = (APTR)msg;
    sprintf(data->buf,(char*)muiUserData(obj),m->value/10,m->value%10);
    return((ULONG)data->buf);
  }
  return(DoSuperMethodA(cl,obj,msg));
}

LONG xget(Object *obj, ULONG attribute)
{
  LONG x;
  get(obj,attribute,&x);
  return(x);
}
LONG xgetslider(Object *obj)
{
  LONG x;
  get(obj,MUIA_Numeric_Value,&x);
  return(x);
}
Object *MyLabel(STRPTR label)
{
  return MUI_MakeObject(MUIO_Label,label,MUIO_Label_LeftAligned);
}
Object *MyLampObject(STRPTR label)
{
  return HGroup,
           Child, LampObject, MUIA_Lamp_Type, MUIV_Lamp_Type_Big, End,
           Child, MyLabel(label),
           Child, HSpace(0),
         End;
}
Object *MyFracSliderObject(STRPTR fmt, LONG min, LONG max, LONG init)
{
  return NewObject(CL_FracSlider->mcc_Class,0,
           MUIA_UserData      , fmt,
           MUIA_Numeric_Min   , min,
           MUIA_Numeric_Max   , max,
           MUIA_Numeric_Value , init,
         TAG_DONE);
}
Object *MySliderObject(STRPTR fmt, LONG min, LONG max, LONG init)
{
  return SliderObject,
           MUIA_Numeric_Format, fmt,
           MUIA_Numeric_Min   , min,
           MUIA_Numeric_Max   , max,
           MUIA_Numeric_Value , init,
         End;
}
Object *MyLevelmeterObject(STRPTR label)
{
  return LevelmeterObject,
           MUIA_Levelmeter_Label, label,
           MUIA_Numeric_Min, 0,
           MUIA_Numeric_Max, 32768,
         End;
}

void UpdateLED(void)
{
  static UWORD ago = 0;
  ULONG l32k,l44k,l48k,lemp,ldat,lcpr;

  l32k = l44k = l48k = lemp = ldat = lcpr = MUIV_Lamp_Color_Off;

  if(GetStatus(mbase,MSTAT_Signal))
  {
    if(!ago)
    {
      switch(GetStatus(mbase,MSTAT_Rate))
      {
        case 32000: l32k = MUIV_Lamp_Color_Ok; break;
        case 44100: l44k = MUIV_Lamp_Color_Ok; break;
        case 48000: l48k = MUIV_Lamp_Color_Ok; break;
      }
      if(GetStatus(mbase,MSTAT_Emphasis)) lemp = MUIV_Lamp_Color_Ok;
      if(GetStatus(mbase,MSTAT_DATsrc))   ldat = MUIV_Lamp_Color_Ok;
      if(GetStatus(mbase,MSTAT_CopyProh)) lcpr = MUIV_Lamp_Color_Ok;
    }
    else
      ago--;
  }
  else
    ago = LEDDELAY;

  if(!xget(app,MUIA_Application_Iconified))
  {
    set(LED_32KHZ   ,MUIA_Lamp_Color,l32k);
    set(LED_441KHZ  ,MUIA_Lamp_Color,l44k);
    set(LED_48KHZ   ,MUIA_Lamp_Color,l48k);
    set(LED_Emphasis,MUIA_Lamp_Color,lemp);
    set(LED_DatSrc  ,MUIA_Lamp_Color,ldat);
    set(LED_CopyProh,MUIA_Lamp_Color,lcpr);
  }
}


void FX_Vol(ULONG *regd2, ULONG *regd3)
{
  ULONG vol = xgetslider(SL_VolL);
  LONG bal = xgetslider(SL_VolR);

  *regd2 = ((bal>0 ? (vol*(100-bal)/100) : vol)<<8)/100;
  *regd3 = ((bal<0 ? (vol*(100+bal)/100) : vol)<<8)/100;
}

void FX_Spatial(ULONG *regd2)
{
  *regd2 = ((100-xgetslider(SL_Shift))<<8)/100;
}

void FX_Echo(ULONG *regd2, ULONG *regd3)
{
  *regd2 = (xgetslider(SL_Entry)<<8)/100;
  *regd3 = (xgetslider(SL_Fade)<<9)/100;
}

void FX_Mask(ULONG *regd2, ULONG *regd3)
{
  *regd2 = 0xFFFF << (16-xgetslider(SL_BitL));
  *regd3 = 0xFFFF << (16-xgetslider(SL_BitR));
}

void FX_Offset(ULONG *regd2, ULONG *regd3)
{
  *regd2 = xgetslider(SL_OffL);
  *regd3 = xgetslider(SL_OffR);
}

void FX_Robot(ULONG *regd2, ULONG *regd3)
{
  ULONG rate = xgetslider(SL_Rate);
  ULONG duty = xgetslider(SL_Duty);
  ULONG fact = (GetStatus(mbase,MSTAT_Rate)*10);
  *regd2 = (fact * duty) / (100*rate);
  *regd3 = (fact * (100-duty)) / (100*rate);
}

void FX_ReSample(ULONG *regd2, ULONG *regd3)
{
  *regd2 = xgetslider(SL_RateL)*100;
  *regd3 = xgetslider(SL_RateR)*100;
}




int SetRealtime(void)
{
  ULONG regd2,regd3;
  APTR  rega0;
  WORD  rfx = FXType[xget(LVL_Effects,MUIA_List_Active)];

  switch(rfx)
  {
    case RFX_Volume:
      FX_Vol(&regd2,&regd3);
      break;
    case RFX_Spatial:
      FX_Spatial(&regd2);
      break;
    case RFX_Echo:
      torus.mrtor_Size = ((xgetslider(SL_Length) * GetStatus(mbase,MSTAT_Rate)) / 1000 )<<1;
      torus.mrtor_Offset = 0;
      FX_Echo(&regd2,&regd3);
      rega0 = &torus;
      break;
    case RFX_Mask:
      FX_Mask(&regd2,&regd3);
      break;
    case RFX_Offset:
      FX_Offset(&regd2,&regd3);
      break;
    case RFX_Robot:
      FX_Robot(&regd2,&regd3);
      break;
    case RFX_ReSample:
      FX_ReSample(&regd2,&regd3);
      resample.mrres_LMax = resample.mrres_RMax = GetStatus(mbase,MSTAT_Rate);
      resample.mrres_LCounter = resample.mrres_RCounter = 0;
      resample.mrres_LData    = resample.mrres_RData    = 0;
      rega0 = &resample;
      break;
  }
  StartRealtimeTags(mbase,
    MTAG_Effect   , rfx,
    MTAG_A0       , rega0,
    MTAG_D2       , regd2,
    MTAG_D3       , regd3,
    MTAG_PostLevel, TRUE,
    TAG_DONE);
  return(1);
}

int SetupMstx(void)
{
  static UBYTE inpmtx[]  = {INPUT_STD, INPUT_OPTICAL, INPUT_COAXIAL};
  static UBYTE scmsmtx[] = {CPROH_INPUT, CPROH_OFF, CPROH_ON, CPROH_PROHIBIT};
  static UBYTE emphmtx[] = {EMPH_INPUT, EMPH_OFF, EMPH_50us, EMPH_CCITT, EMPH_MANUAL};
  static UBYTE srcmtx[]  = {SRC_INPUT, SRC_CD, SRC_DAT, SRC_DSR, SRC_ADCONV, SRC_INSTR};
  static UBYTE ratemtx[] = {RATE_INPUT, RATE_32000, RATE_44100, RATE_48000, RATE_48000MANU};

  ULONG input,format,scms,emphasis,source,rate;

  StopRealtime(mbase);

  input    = inpmtx[xget(CY_Input,MUIA_Cycle_Active)];
  format   = xget(CY_Format,MUIA_Cycle_Active);
  scms     = scmsmtx[xget(CY_SCMS,MUIA_Cycle_Active)];
  emphasis = emphmtx[xget(CY_Emphasis,MUIA_Cycle_Active)];
  source   = srcmtx[xget(CY_Source,MUIA_Cycle_Active)];
  rate     = ratemtx[xget(CY_Rate,MUIA_Cycle_Active)];

  SetMaestroTags(mbase,
    MTAG_Studio  , format,
    MTAG_Input   , input,
    MTAG_CopyProh, scms,
    MTAG_Emphasis, emphasis,
    MTAG_Source  , source,
    MTAG_Rate    , rate,
    TAG_DONE);

  if(realtiming)
  {
    SetMaestroTags(mbase,MTAG_Output,OUTPUT_FIFO,TAG_DONE);
    return SetRealtime();
  }
  else
  {
    SetMaestroTags(mbase,MTAG_Output,OUTPUT_INPUT,TAG_DONE);
    return(1);
  }
}

void UpdRealtime(void)
{
  ULONG regd2,regd3;
  WORD  rfx = FXType[xget(LVL_Effects,MUIA_List_Active)];

  if(!realtiming) return;

  switch(rfx)
  {
    case RFX_Volume:
      FX_Vol(&regd2,&regd3);
      break;
    case RFX_Spatial:
      FX_Spatial(&regd2);
      break;
    case RFX_Echo:
      FX_Echo(&regd2,&regd3);
      break;
    case RFX_Mask:
      FX_Mask(&regd2,&regd3);
      break;
    case RFX_Offset:
      FX_Offset(&regd2,&regd3);
      break;
    case RFX_Robot:
      FX_Robot(&regd2,&regd3);
      break;
    case RFX_ReSample:
      FX_ReSample(&regd2,&regd3);
      resample.mrres_LCounter = resample.mrres_RCounter = 0;
      break;
  }

  UpdateRealtimeTags(mbase,
    MTAG_D2    , regd2,
    MTAG_D3    , regd3,
    TAG_DONE);
}

void SetLevel(void)
{
  static UWORD leftarray[LEVELINERT]  = {0};
  static UWORD rightarray[LEVELINERT] = {0};

  ULONG level = ReadPostLevelTags(mbase,TAG_DONE);
  UWORD left  = level&0xFFFF;
  UWORD right = (level>>16)&0xFFFF;
  UWORD i;
  ULONG leftsum=leftarray[0], rightsum=rightarray[0];

  for(i=1;i<LEVELINERT;i++)
  {
    leftsum  += (leftarray[i-1]  = leftarray[i] );
    rightsum += (rightarray[i-1] = rightarray[i]);
  }
  leftsum  += (leftarray[LEVELINERT-1]  = left );
  rightsum += (rightarray[LEVELINERT-1] = right);

  set(LM_Left ,MUIA_Numeric_Value,leftsum /(LEVELINERT+1));
  set(LM_Right,MUIA_Numeric_Value,rightsum/(LEVELINERT+1));
}


int main(void)
{
  ULONG sigs=0;
  ULONG id, idcnt;
  ULONG timermask;

  if(MaestixBase = OpenLibrary("maestix.library",MAESTIXVERSION))
  {
    if(mbase = AllocMaestro(NULL))
    {
      timerport = CreateMsgPort();
      if(timerport)
      {
        timermask = (1L<<timerport->mp_SigBit);
        timerio = (struct timerequest *)CreateIORequest(timerport,sizeof(struct timerequest));
        if(timerio)
        {
          if(!OpenDevice("timer.device",UNIT_VBLANK,(struct IORequest *)timerio,0L))
          {
            if(MUIMasterBase = OpenLibrary("muimaster.library",11))
            {
              if(CL_FracSlider = MUI_CreateCustomClass(NULL,MUIC_Slider,NULL,sizeof(struct MSL_Data),(APTR) MSL_Dispatcher))
              {

                torus.mrtor_PointerL = AllocVec(48000*MAX_ECHO*2,MEMF_PUBLIC|MEMF_CLEAR);
                torus.mrtor_PointerR = AllocVec(48000*MAX_ECHO*2,MEMF_PUBLIC|MEMF_CLEAR);

                app = ApplicationObject,
                  MUIA_Application_Title        , "Maestix-FX",
                  MUIA_Application_Version      , "$VER: Maestix-FX V" VERSION " (" VDATE ")",
                  MUIA_Application_Copyright    , "\xA9 1997-2021 by Richard 'Shred' K\xF6rber",
                  MUIA_Application_Author       , "Richard 'Shred' K\xF6rber",
                  MUIA_Application_Description  , "Small MaestroPro FX program",
                  MUIA_Application_Base         , "MAESTIXFX",
                  MUIA_Application_Window       , window = WindowObject,
                    MUIA_Window_Title           , "Maestix-FX V" VERSION,
                    MUIA_Window_ID              , MAKE_ID('M','X','F','X'),
                    WindowContents, VGroup,
                      Child, HGroup,
                        Child, LM_Left  = MyLevelmeterObject("Left"),
                        Child, LM_Right = MyLevelmeterObject("Right"),
                        Child, HGroup,
                          MUIA_FrameTitle, "Input Analysis",
                          MUIA_Frame     , MUIV_Frame_Group,
                          MUIA_Background, MUII_GroupBack,
                          Child, VGroup,
                            MUIA_Weight, 40,
                            Child, LED_32KHZ    = MyLampObject("32000 Hz"),
                            Child, LED_441KHZ   = MyLampObject("44100 Hz"),
                            Child, LED_48KHZ    = MyLampObject("48000 Hz"),
                          End,
                          Child, VGroup,
                            MUIA_Weight, 60,
                            Child, LED_Emphasis = MyLampObject("50\xB5s Emphasis"),
                            Child, LED_DatSrc   = MyLampObject("Source is DAT"),
                            Child, LED_CopyProh = MyLampObject("Copy Restricted"),
                          End,
                        End,
                      End,
                      Child, RegisterGroup(RG_Title),
                        Child, VGroup,                  // About
                          MUIA_Group_SameWidth, TRUE,
                          Child, VSpace(0),
                          Child, HGroup,
                            Child, HSpace(0),
                            Child, HSpace(0),
                            Child, BodychunkObject,
                              MUIA_FixWidth             , MFX_WIDTH ,
                              MUIA_FixHeight            , MFX_HEIGHT,
                              MUIA_Bitmap_Width         , MFX_WIDTH ,
                              MUIA_Bitmap_Height        , MFX_HEIGHT,
                              MUIA_Bodychunk_Depth      , MFX_DEPTH ,
                              MUIA_Bodychunk_Body       , MFX_body  ,
                              MUIA_Bodychunk_Compression, MFX_COMPRESSION,
                              MUIA_Bodychunk_Masking    , MFX_MASKING,
                              MUIA_Bitmap_SourceColors  , MFX_colors,
                              MUIA_Bitmap_Transparent   , 0,
                            End,
                            Child, VGroup, MUIA_Group_VertSpacing,0,
                              Child, VSpace(0),
                              Child, TextObject,
                                MUIA_Text_Contents, "V" VERSION,
                                MUIA_Font         , MUIV_Font_Title,
                              End,
                            End,
                            Child, HSpace(0),
                          End,
                          Child, HGroup,
                            Child, HSpace(5),
                            Child, MUI_MakeObject(MUIO_HBar,2),
                            Child, HSpace(5),
                          End,
                          Child, TextObject,
                            MUIA_Text_PreParse, "\33c",
                            MUIA_Text_Contents, "\xA9 1997-2021 Richard 'Shred' K\xF6rber",
                            MUIA_Font         , MUIV_Font_Tiny,
                          End,
                          Child, VSpace(0),
                          Child, TextObject,
                            MUIA_Text_PreParse, "\33c",
                            MUIA_Text_Contents, "Maestix-FX is part of \33bmaestix.library\33n.\n"
                                                "You are using it at your own risk!\n"
                                                "\33bWARNING:\33n Some effects may damage your\n"
                                                "speakers if volume is turned up high!\n\n"
                                                "URL: https://maestix.shredzone.org",
                          End,
                          Child, VSpace(0),
                          Child, HGroup,
                            Child, HSpace(0),
                            Child, BodychunkObject,
                              MUIA_FixWidth             , LOGO_WIDTH ,
                              MUIA_FixHeight            , LOGO_HEIGHT,
                              MUIA_Bitmap_Width         , LOGO_WIDTH ,
                              MUIA_Bitmap_Height        , LOGO_HEIGHT,
                              MUIA_Bodychunk_Depth      , LOGO_DEPTH ,
                              MUIA_Bodychunk_Body       , Logo_body  ,
                              MUIA_Bodychunk_Compression, LOGO_COMPRESSION,
                              MUIA_Bodychunk_Masking    , LOGO_MASKING,
                              MUIA_Bitmap_SourceColors  , Logo_colors,
                              MUIA_Bitmap_Transparent   , 0,
                            End,
                          End,
                        End,

                        Child, VGroup,
                          Child, HGroup,
                            Child, CH_Realtime = MUI_MakeObject(MUIO_Checkmark,"_Realtime FX"),
                            Child, MUI_MakeObject(MUIO_Label,"_Realtime FX",MUIO_Label_LeftAligned),
                            Child, HSpace(0),
                          End,
                          Child, LV_Effects = ListviewObject,
                            MUIA_CycleChain   , 1,
                            MUIA_Listview_List, LVL_Effects = ListObject,
                              InputListFrame,
                              MUIA_List_SourceArray  , FXList,
                            End,
                          End,
                          Child, RectangleObject,
                            MUIA_Weight,0,
                            MUIA_Rectangle_HBar, TRUE,
                            MUIA_Rectangle_BarTitle, "Parameters",
                          End,
                          Child, GR_Page = VGroup,
                            MUIA_Group_PageMode, TRUE,
                            Child, VSpace(0),           // Group 0 : Empty
                            Child, ColGroup(2),         // Group 1 : Volume
                              MUIA_Group_VertSpacing, 0,
                              Child, MyLabel("Volume"),
                              Child, SL_VolL = MySliderObject("%ld%%",0,200,100),
                              Child, MyLabel("Balance"),
                              Child, SL_VolR = MySliderObject("%ld%%",-100,100,0),
                            End,
                            Child, ColGroup(2),         // Group 2 : Spatial
                              Child, MyLabel("Rejection"),
                              Child, SL_Shift = MySliderObject("%ld%%",0,100,75),
                            End,
                            Child, ColGroup(2),         // Group 3 : Echo
                              MUIA_Group_VertSpacing, 0,
                              Child, MyLabel("Init Vol"),
                              Child, SL_Entry  = MySliderObject("%ld%%",0,100,66),
                              Child, MyLabel("Rept Time"),
                              Child, SL_Length = MySliderObject("%ld ms",10,MAX_ECHO*1000,100),
                              Child, MyLabel("Rept Vol"),
                              Child, SL_Fade   = MySliderObject("%ld%%",0,100,33),
                            End,
                            Child, ColGroup(2),         // Group 4 : Quantisize
                              MUIA_Group_VertSpacing, 0,
                              Child, MyLabel("Left"),
                              Child, SL_BitL  = MySliderObject("%ld bit",1,16,16),
                              Child, MyLabel("Right"),
                              Child, SL_BitR   = MySliderObject("%ld bit",1,16,16),
                            End,
                            Child, ColGroup(2),         // Group 5 : Offset
                              MUIA_Group_VertSpacing, 0,
                              Child, MyLabel("Left"),
                              Child, SL_OffL  = MySliderObject("%ld",-32768,32767,0),
                              Child, MyLabel("Right"),
                              Child, SL_OffR   = MySliderObject("%ld",-32768,32767,0),
                            End,
                            Child, ColGroup(2),         // Group 6 : Robot
                              MUIA_Group_VertSpacing, 0,
                              Child, MyLabel("Rate"),
                              Child, SL_Rate  = MyFracSliderObject("%ld.%ld Hz",1,2000,500),
                              Child, MyLabel("Duty Cycle"),
                              Child, SL_Duty  = MySliderObject("%ld%%",0,100,50),
                            End,
                            Child, ColGroup(2),         // Group 7 : ReSample
                              MUIA_Group_VertSpacing, 0,
                              Child, MyLabel("Left"),
                              Child, SL_RateL = MySliderObject("%ld00 Hz",1,480,441),
                              Child, MyLabel("Right"),
                              Child, SL_RateR = MySliderObject("%ld00 Hz",1,480,441),
                            End,
                          End,
                        End,

                        Child, VGroup,                   // Mode list
                          Child, VSpace(0),
                          Child, GR_Encoder = ColGroup(2),
                            MUIA_FrameTitle, "Encoder",
                            MUIA_Frame     , MUIV_Frame_Group,
                            MUIA_Background, MUII_GroupBack,
                            Child, MyLabel("Input"),
                            Child, CY_Input    = CycleObject, MUIA_Cycle_Entries, CYA_Input, End,
                            Child, MyLabel("Format"),
                            Child, CY_Format   = CycleObject, MUIA_Cycle_Entries, CYA_Format, End,
                            Child, MyLabel("SCMS"),
                            Child, CY_SCMS     = CycleObject, MUIA_Cycle_Entries, CYA_SCMS, End,
                            Child, MyLabel("Emphasis"),
                            Child, CY_Emphasis = CycleObject, MUIA_Cycle_Entries, CYA_Emphasis, End,
                            Child, MyLabel("Source"),
                            Child, CY_Source   = CycleObject, MUIA_Cycle_Entries, CYA_Source, End,
                            Child, MyLabel("Rate"),
                            Child, CY_Rate     = CycleObject, MUIA_Cycle_Entries, CYA_Rate, End,
                          End,
                          Child, VSpace(0),
                        End,

                      End,
                    End,
                  End,
                End;

                if(app)
                {
                  // Init all objects
                  set(LVL_Effects,MUIA_List_Active,MUIV_List_Active_Top);
                  UpdateLED();
                  DoMethod(app,MUIM_Application_ReturnID,ID_STOP);

                  // Set all notifications
                  DoMethod(window     ,MUIM_Notify,MUIA_Window_CloseRequest ,TRUE          ,app,2,MUIM_Application_ReturnID,MUIV_Application_ReturnID_Quit);
                  DoMethod(LVL_Effects,MUIM_Notify,MUIA_List_Active         ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_LVCHANGE);
                  DoMethod(LV_Effects ,MUIM_Notify,MUIA_Listview_DoubleClick,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_START);
                  DoMethod(CH_Realtime,MUIM_Notify,MUIA_Selected            ,TRUE          ,app,2,MUIM_Application_ReturnID,ID_START);
                  DoMethod(CH_Realtime,MUIM_Notify,MUIA_Selected            ,FALSE         ,app,2,MUIM_Application_ReturnID,ID_STOP);
                  DoMethod(CY_Input   ,MUIM_Notify,MUIA_Cycle_Active        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_UPDATE);
                  DoMethod(CY_Format  ,MUIM_Notify,MUIA_Cycle_Active        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_UPDATE);
                  DoMethod(CY_SCMS    ,MUIM_Notify,MUIA_Cycle_Active        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_UPDATE);
                  DoMethod(CY_Emphasis,MUIM_Notify,MUIA_Cycle_Active        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_UPDATE);
                  DoMethod(CY_Source  ,MUIM_Notify,MUIA_Cycle_Active        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_UPDATE);
                  DoMethod(CY_Rate    ,MUIM_Notify,MUIA_Cycle_Active        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_UPDATE);
                  DoMethod(SL_VolL    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_VolR    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_Shift   ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_Entry   ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_Fade    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_Length  ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDSETUP);
                  DoMethod(SL_BitL    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_BitR    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_OffL    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_OffR    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_Rate    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_Duty    ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_RateL   ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);
                  DoMethod(SL_RateR   ,MUIM_Notify,MUIA_Slider_Level        ,MUIV_EveryTime,app,2,MUIM_Application_ReturnID,ID_SLIDUPDATE);

                  // set ObjectIDs
                  for(idcnt=0;;idcnt++)
                  {
                    if(!idlist[idcnt]) break;
                    set(*(idlist[idcnt]),MUIA_ObjectID,idcnt+1);
                  }

                  // Load prefs
                  DoMethod(app,MUIM_Application_Load,MUIV_Application_Load_ENV);

                  // Open window
                  set(window,MUIA_Window_Open,TRUE);
                  timerio->tr_node.io_Command = TR_ADDREQUEST;
                  timerio->tr_time.tv_secs    = 0;
                  timerio->tr_time.tv_micro   = REFRESHRATE;
                  SendIO((struct IORequest *)timerio);        // set timer

                  // Main Loop
                  while((id = DoMethod(app,MUIM_Application_NewInput,&sigs)) != MUIV_Application_ReturnID_Quit)
                  {
                    switch(id)
                    {
                      case ID_LVCHANGE:
                        set(GR_Page,MUIA_Group_ActivePage,FXPage[xget(LVL_Effects,MUIA_List_Active)]);
                      case ID_SLIDSETUP:
                        if(!SetupMstx()) goto DO_STOP;
                        break;
                      case ID_SLIDUPDATE:
                        UpdRealtime();
                        break;
                      case ID_UPDATE:
                        SetupMstx();
                        break;
                      case ID_START:
                        if(realtiming) break;
                        realtiming = TRUE;
                        if(SetupMstx()) break;
                      case ID_STOP:
DO_STOP:                realtiming = FALSE;
                        SetupMstx();
                        break;
                    }
                    if(sigs)                        // wait for MUI signals to occur
                    {
                      sigs = Wait(sigs | timermask | SIGBREAKF_CTRL_C);
                      if(CheckIO((struct IORequest *)timerio))    // request completed?
                      {
                        SetLevel();
                        UpdateLED();
                        timerio->tr_node.io_Command = TR_ADDREQUEST;
                        timerio->tr_time.tv_secs    = 0;
                        timerio->tr_time.tv_micro   = REFRESHRATE;
                        SendIO((struct IORequest *)timerio);        // set timer
                      }
                      if(sigs & SIGBREAKF_CTRL_C) break;    // aborted
                    }
                  }

                  StopRealtime(mbase);
                  if(!CheckIO((struct IORequest *)timerio))
                  {
                    AbortIO((struct IORequest *)timerio);
                    WaitIO((struct IORequest *)timerio);
                  }
                  // save prefs
                  DoMethod(app,MUIM_Application_Save,MUIV_Application_Save_ENV);

                  MUI_DisposeObject(app);           // dispose the application
                }else {
                  PutStr("Couldn't build GUI. Probably lamp.mcc is missing?\n");
                }
                MUI_DeleteCustomClass(CL_FracSlider);
              }
              CloseLibrary(MUIMasterBase);
            }else {
              PutStr("Requires MUI\n");
            }
            CloseDevice((struct IORequest *)timerio);
          }
          DeleteIORequest(timerio);
        }
        DeleteMsgPort(timerport);
      }
      FreeMaestro(mbase);
    }
    CloseLibrary(MaestixBase);
  }
  if(torus.mrtor_PointerL) FreeVec(torus.mrtor_PointerL);
  if(torus.mrtor_PointerR) FreeVec(torus.mrtor_PointerR);
  return 0;                             // return code 0
}
