/*
 * Maestix Library
 *
 * Copyright (C) 2021 Richard "Shred" Koerber
 *	http://maestix.shredzone.org
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <string.h>
#include <clib/alib_protos.h>
#include <dos/dos.h>
#include <dos/dosasl.h>
#include <exec/memory.h>
#include <libraries/maestix.h>
#include <libraries/mpega.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/maestix.h>
#include <proto/MPEGA.h>

#define DATANODES 32              // Data messages (frames)


#define  VERSIONSTR   "1.0"
#define  DATESTR      "12.1.2000"
#define  COPYRIGHTSTR "2000-2021"
#define  URLSTR       "https://maestix.shredzone.org"

#define  NORMAL       "\2330m"
#define  BOLD         "\2331m"
#define  ITALIC       "\2333m"
#define  UNDERLINE    "\2334m"

static char ver[] = "$VER: MaestroPEG " VERSIONSTR " (" DATESTR ") " URLSTR;
static char titletxt[] = \
  BOLD "MaestroPEG " VERSIONSTR " (C) " COPYRIGHTSTR " Richard 'Shred' K\xF6rber" NORMAL "\n";
static char helptxt[] = \
  "  " URLSTR "\n\n"
  ITALIC "Usage:" NORMAL "\n"
  "  FILE/A/M       MPEG files to play (wildcards allowed)\n"
  "  ALL/S          Recursive directories\n"
  "  QUALITY/K/N    Playback quality (0:low .. 2:high), default is 2\n"
  "  TASKPRI/K/N    Task priority during playback, default is 20\n"
  "  BUFFER/K/N     Size of read buffer, default is 2048\n"
  "  INFO/S         Give information about the file\n"
  "  LOOP/S         Repeat to play the files\n"
  "  PRELOAD/S      Loads whole file before playback\n"
  "  NOTIME/S       Suppress the time output during playback\n"
  "  NOPROH/S       Ignore copy prohibition\n"
  "  NOCHECK/S      No check for MPEG file\n"
  "\n";

static char *layer_name[] = { "?", "I", "II", "III" };
static char *mode_name[]  = { "Stereo", "Joined Stereo", "Dual", "Mono" };

struct Parameter
{
  STRPTR *files;
  LONG   all;
  LONG   *quality;
  LONG   *pri;
  LONG   *buf;
  LONG   info;
  LONG   loop;
  LONG   preload;
  LONG   notime;
  LONG   noproh;
  LONG   nocheck;
}
param;

struct MPTag
{
  char tag[3] ;
  char title[30] ;
  char artist[30] ;
  char album[30] ;
  char year[4] ;
  char comment[30] ;
  unsigned char genre ;
};

/**
 * A list of all genres
 */
#define NUM_GENRES (148)
static char *genres[]={
  "Blues",
  "Classic Rock",
  "Country",
  "Dance",
  "Disco",
  "Funk",
  "Grunge",
  "Hip-Hop",
  "Jazz",
  "Metal",
  "New Age",
  "Oldies",
  "Other",
  "Pop",
  "R&B",
  "Rap",
  "Reggae",
  "Rock",
  "Techno",
  "Industrial",
  "Alternative",
  "Ska",
  "Death Metal",
  "Pranks",
  "Soundtrack",
  "Euro-Techno",
  "Ambient",
  "Trip-Hop",
  "Vocal",
  "Jazz+Funk",
  "Fusion",
  "Trance",
  "Classical",
  "Instrumental",
  "Acid",
  "House",
  "Game",
  "Sound Clip",
  "Gospel",
  "Noise",
  "Alt. Rock",
  "Bass",
  "Soul",
  "Punk",
  "Space",
  "Meditative",
  "Instrumental Pop",
  "Instrumental Rock",
  "Ethnic",
  "Gothic",
  "Darkwave",
  "Techno-Industrial",
  "Electronic",
  "Pop-Folk",
  "Eurodance",
  "Dream",
  "Southern Rock",
  "Comedy",
  "Cult",
  "Gangsta",
  "Top 40",
  "Christian Rap",
  "Pop/Funk",
  "Jungle",
  "Native American",
  "Cabaret",
  "New Wave",
  "Psychadelic",
  "Rave",
  "Showtunes",
  "Trailer",
  "Lo-Fi",
  "Tribal",
  "Acid Punk",
  "Acid Jazz",
  "Polka",
  "Retro",
  "Musical",
  "Rock & Roll",
  "Hard Rock",
  "Folk",
  "Folk/Rock",
  "National Folk",
  "Swing",
  "Fusion",
  "Bebob",
  "Latin",
  "Revival",
  "Celtic",
  "Bluegrass",
  "Avantgarde",
  "Gothic Rock",
  "Progressive Rock",
  "Psychedelic Rock",
  "Symphonic Rock",
  "Slow Rock",
  "Big Band",
  "Chorus",
  "Easy Listening",
  "Acoustic",
  "Humour",
  "Speech",
  "Chanson",
  "Opera",
  "Chamber Music",
  "Sonata",
  "Symphony",
  "Booty Bass",
  "Primus",
  "Porn Groove",
  "Satire",
  "Slow Jam",
  "Club",
  "Tango",
  "Samba",
  "Folklore",
  "Ballad",
  "Power Ballad",
  "Rhythmic Soul",
  "Freestyle",
  "Duet",
  "Punk Rock",
  "Drum Solo",
  "Acapella",
  "Euro-House",
  "Dance Hall",
  "Goa",
  "Drum & Bass",
  "Club-House",
  "Hardcore",
  "Terror",
  "Indie",
  "BritPop",
  "Negerpunk",
  "Polsk Punk",
  "Beat",
  "Christian Gangsta Rap",
  "Heavy Metal",
  "Black Metal",
  "Crossover",
  "Contemporary Christian",
  "Christian Rock",
  "Merengue",
  "Salsa",
  "Trash Metal",
  "Anime",
  "JPop",
  "Synthpop"
};

static char template[] = "FILE/A/M,ALL/S,Q=QUALITY/K/N,PRI=TASKPRI/K/N,BUF=BUFFER/K/N,"
                         "INFO/S,LOOP/S,PRE=PRELOAD/S,NOTIME/S,NOPROH/S,NOCHECK/S";

struct Library *MaestixBase;
struct Library *MPEGABase;

struct ExtDataMessage nodes[DATANODES];

struct MaestroBase *mbase;
MPEGA_STREAM *mstream;

MPEGA_CTRL mctrl =
{
  NULL,
  {FALSE, {1, 2, 44100}, {1, 2, 44100}},
  {FALSE, {1, 2, 44100}, {1, 2, 44100}},
  1,
  2048
};

void copystr(STRPTR dest, STRPTR src, ULONG len)
{
  STRPTR ptr;
  CopyMem(src,dest,len);
  ptr = dest+len;
  *ptr = 0;
  while((--ptr) >= dest)
  {
    if(*ptr==' ')
      *ptr=0;
    else
      break;
  }
}

void show_tag(STRPTR filename)
{
  BPTR file;
  struct MPTag tag;
  char str[40];

  if(file = Open(filename,MODE_OLDFILE))
  {
    SetIoErr(0);
    Seek(file,-sizeof(struct MPTag),OFFSET_END);
    if(IoErr() == 0)
    {
      if(-1 != Read(file,&tag,sizeof(struct MPTag)))
      {
        if(!strncmp(tag.tag,"TAG",3))
        {
          copystr((STRPTR)&str,tag.artist,30);
          if(str[0]) Printf(BOLD "Artist:  " NORMAL "%s\n",str);
          copystr((STRPTR)&str,tag.title,30);
          if(str[0]) Printf(BOLD "Title:   " NORMAL "%s\n",str);
          copystr((STRPTR)&str,tag.album,30);
          if(str[0]) Printf(BOLD "Album:   " NORMAL "%s\n",str);
          copystr((STRPTR)&str,tag.year,4);
          if(str[0]) Printf(BOLD "Year:    " NORMAL "%s\n",str);
          if(tag.genre!=255)
            {
            if(tag.genre>=NUM_GENRES)
              Printf(BOLD "Genre:   " NORMAL "Unknown (%ld)\n",(ULONG)tag.genre);
            else
              Printf(BOLD "Genre:   " NORMAL "%s\n",genres[tag.genre]);
            }
          copystr((STRPTR)&str,tag.comment,30);
          if(str[0]) Printf(BOLD "Comment: " NORMAL "%s\n",str);
        }
      }
    }
    Close(file);
  }
}

void mpeg_play(MPEGA_STREAM *mstream, struct MaestroBase *mbase)
{
  BYTE *audiobuffer;
  BYTE *curbuff;
  struct MsgPort *port;
  struct ExtDataMessage *currmsg;
  UWORD node;
  LONG cnt;
  ULONG mask,rmask;
  LONG pri = 20, oldpri;
  WORD *data[MPEGA_MAX_CHANNELS];
  ULONG time, oldtime=123;
  static const ULONG bufsize = (MPEGA_PCM_SIZE+256)<<2;

  if(param.pri) pri = *param.pri;
  if(pri<-128 || pri>127) pri=20;

  if(port = CreateMsgPort())
  {
    mask = SIGBREAKF_CTRL_C | SIGBREAKF_CTRL_D | 1<<(port->mp_SigBit);

    if(audiobuffer = AllocVec(bufsize*DATANODES, MEMF_PUBLIC|MEMF_CLEAR))
    {
      curbuff = audiobuffer;
      for(node=0; node<DATANODES; node++)
      {
        nodes[node].edmn_Message.mn_Length    = sizeof(struct ExtDataMessage);
        nodes[node].edmn_Message.mn_ReplyPort = port;
        nodes[node].edmn_BufPtr  = curbuff;
        nodes[node].edmn_Flags   = (mstream->dec_channels==2 ? EDMNF_DUAL : EDMNF_MONO);
        nodes[node].edmn_BufPtrR = curbuff+(bufsize>>1);
        curbuff += bufsize;

        do
        {
          data[0] = nodes[node].edmn_BufPtr;
          data[1] = nodes[node].edmn_BufPtrR;
          cnt = MPEGA_decode_frame(mstream,(WORD*)data);
        }
        while(cnt==0);
        if(cnt<0) break;
        nodes[node].edmn_BufLen = cnt<<1;
        TransmitData(mbase,(struct DataMessage *)&nodes[node]);
      }

      oldpri = SetTaskPri(FindTask(NULL),pri);

      if(cnt>=0) for(;;)
      {
        currmsg = (struct ExtDataMessage *)GetMsg(port);
        if(!currmsg)
        {
          rmask = Wait(mask);
          if(rmask == SIGBREAKF_CTRL_C)
            Signal(FindTask(NULL),SIGBREAKF_CTRL_C);
          if(  rmask == SIGBREAKF_CTRL_C
             ||rmask == SIGBREAKF_CTRL_D) break;
          continue;
        }

        if(!param.notime)
        {
          MPEGA_time(mstream,&time);
          time += 500;
          time /= 1000;

          if(time != oldtime)
          {
            Printf("\015" BOLD "Time:    " NORMAL "%02ld:%02ld ",
                   time/60,
                   time%60);
            oldtime = time;
          }
        }

        do
        {
          data[0] = currmsg->edmn_BufPtr;
          data[1] = currmsg->edmn_BufPtrR;
          cnt = MPEGA_decode_frame(mstream,(WORD*)data);
        }
        while(cnt==0);

        if(cnt<0) break;

        currmsg->edmn_BufLen = cnt<<1;
        TransmitData(mbase,(struct DataMessage *)currmsg);
      }

      SetTaskPri(FindTask(NULL),oldpri);

      for(node=0; node+1<DATANODES; node++)
      {
        if(!GetMsg(port))
        {
          WaitPort(port);
          continue;
        }
      }
      FlushTransmit(mbase);
      FreeVec(audiobuffer);
      if(!param.notime) PutStr("\233 p\n");
    }
    DeleteMsgPort(port);
  }
}

int main(void)
{
  struct RDArgs *args;
  STRPTR *currfile;
  LONG err;
  ULONG brk;
  BPTR oldlock;
  struct AnchorPath *ap = NULL;

  PutStr(titletxt);

  ap = AllocVec(sizeof(struct AnchorPath),MEMF_PUBLIC|MEMF_CLEAR);
  if(!ap)
    PutStr("** No memory\n");
  else
  if(args = (struct RDArgs *)ReadArgs(template,(LONG *)&param,NULL))
  {
    if(param.quality)
    {
      LONG qual = *param.quality;
      if(qual<0 || qual>2)
        PutStr("** Quality out of range, taking default\n");
      else
      {
        mctrl.layer_1_2.mono.quality   = qual;
        mctrl.layer_1_2.stereo.quality = qual;
        mctrl.layer_3.mono.quality     = qual;
        mctrl.layer_3.stereo.quality   = qual;
      }
    }

    if(param.nocheck)
    {
      mctrl.check_mpeg = 0;
    }

    if(param.buf)
    {
      LONG bsize = *param.buf;
      if(bsize<1024)
        PutStr("** Buffer size must be at least 1024\n");
      else
      {
        mctrl.stream_buffer_size = ((bsize+3)&0xFFFFFFFC);
      }
    }

    if(param.all)
    {
      ap->ap_Flags |= APF_DOWILD;
    }

    currfile = param.files;

    if(MaestixBase = OpenLibrary("maestix.library",41L))
    {
      if(MPEGABase = OpenLibrary("mpega.library",1L))
      {
        if(mbase = AllocMaestro(NULL))
        {
          while(*currfile)
          {
            err = MatchFirst(*currfile,ap);
            while(!err)
            {
              if(ap->ap_Info.fib_DirEntryType < 0)
              {
                oldlock = CurrentDir(ap->ap_Current->an_Lock);

                if(param.preload)
                {
                  mctrl.stream_buffer_size = ((ap->ap_Info.fib_Size+3)&0xFFFFFFFC);
                }

                if(mstream = MPEGA_open(ap->ap_Info.fib_FileName,&mctrl))
                {
                  if(param.info)
                  {
                    Printf("\nMPEG-%ld Layer %s, %s, %ld kbps, %ld Hz, %s\n",
                            mstream->norm,
                            layer_name[mstream->layer],
                            mode_name[mstream->mode],
                            mstream->bitrate,
                            mstream->frequency,
                            (mstream->copyright
                              ? (mstream->original
                                ? "copy protected"
                                : "copy prohibited")
                              : "not copy protected")
                            );
                    if(mstream->private_bit)
                      PutStr("This is a private file!\n");
                  }

                  if((ap->ap_Flags&APF_ITSWILD)||(param.files[1]))
                  {
                    Printf(BOLD "File:    " NORMAL "%s\n",ap->ap_Info.fib_FileName);
                  }

                  if(param.info)
                  {
                    show_tag(ap->ap_Info.fib_FileName);
                  }

                  if(mstream->dec_channels>2)
                  {
                    PutStr("** Cannot play more than 2 channels\n");
                    goto done;
                  }

                  if(  mstream->dec_frequency==44100
                     ||mstream->dec_frequency==32000)
                  {
                    if(  !GetStatus(mbase,MSTAT_Signal)
                       ||(GetStatus(mbase,MSTAT_Rate)!=mstream->dec_frequency))
                    {
                      Printf("** No %ld Hz rate available at the input\n",mstream->dec_frequency);
                      goto done;
                    }
                  }

                  if(mstream->dec_frequency!=48000 && mstream->dec_frequency!=44100)
                  {
                    Printf("** Couldn't generate %ld Hz\n",mstream->dec_frequency);
                    goto done;
                  }

                  if(!param.notime)
                  {
                    ULONG dur = (mstream->ms_duration+500) / 1000;

                    Printf("\2330 p" BOLD "Time:    " NORMAL "00:00 / %02ld:%02ld\015",
                           dur/60,
                           dur%60);
                  }

                  SetMaestroTags(mbase,
                    (mstream->dec_frequency==48000 ? MTAG_Input : TAG_IGNORE), INPUT_SRC48K,
                    MTAG_Output,OUTPUT_FIFO,
                    MTAG_Rate,(mstream->dec_frequency==48000 ? RATE_48000 : RATE_44100),
                    MTAG_CopyProh,(mstream->copyright ? (mstream->original ? CPROH_ON : CPROH_PROHIBIT) : CPROH_OFF),
                    TAG_DONE
                  );

                  if(param.noproh) SetMaestroTags(mbase,MTAG_CopyProh,CPROH_OFF);

                  mpeg_play(mstream,mbase);
done:
                  MPEGA_close(mstream);
                }
                else Printf("** Couldn't open file \"%s\"\n",ap->ap_Info.fib_FileName);

                CurrentDir(oldlock);
              }
              if(SetSignal(0L,0L)&SIGBREAKF_CTRL_C) break;
              err = MatchNext(ap);
            }
            MatchEnd(ap);
            if(SetSignal(0L,0L)&SIGBREAKF_CTRL_C) break;
            currfile++;
            if(param.loop && !(*currfile)) currfile = param.files;
          }
          FreeMaestro(mbase);
        }
        else PutStr("** MaestroPro is already allocated\n");

        CloseLibrary(MPEGABase);
      }
      else PutStr("** Couldn't open mpega.library\n");

      CloseLibrary(MaestixBase);
    }
    else PutStr("** Couldn't open maestix.library\n");

    FreeArgs(args);
  }
  else PutStr(helptxt);

  if(ap) FreeVec(ap);

  return(0);
}
