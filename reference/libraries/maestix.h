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

#ifndef LIBRARIES_MAESTIX_H
#define LIBRARIES_MAESTIX_H     (1)

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif

#ifndef UTILITY_TAGITEM_H
#include <utility/tagitem.h>
#endif

#ifndef EXEC_PORTS_H
#include <exec/ports.h>
#endif

#ifndef EXEC_LISTS_H
#include <exec/lists.h>
#endif

#ifndef EXEC_LIBRARIES_H
#include <exec/libraries.h>
#endif


/* ------------------------------------------------------------------------ */
/*  Generic library informations */


#define MAESTIXVERSION  (42)

struct MaestixBase {
        struct  Library mxb_LibNode;
};


/* ------------------------------------------------------------------------ */
/*  MaestroBase structure */

struct MaestroBase {
        WORD    maba_Dummy;     /* PRIVATE */
};


/* ------------------------------------------------------------------------ */
/*  DataMessage */

struct DataMessage {
        struct  Message dmn_Message;    /* struct Message */
        APTR    dmn_BufPtr;     /* pointer to public buffer memory */
        ULONG   dmn_BufLen;     /* length of buffer memory (bytes) */
};

struct ExtDataMessage {
        struct  Message edmn_Message;   /* struct Message */
        APTR    edmn_BufPtr;    /* pointer to public buffer memory */
        ULONG   edmn_BufLen;    /* length of buffer memory (bytes) */
        UWORD   edmn_Flags;     /* EDMN flags, see below */
        APTR    edmn_BufPtrR;   /* pointer to right buffer (dual mode) */
};

/* Flags for edmn_Flags */
#define EDMNB_MONO (0)          /* Buffer is Mono */
#define EDMNF_MONO (0x0001)
#define EDMNB_DUAL (1)          /* Buffer is Dual */
#define EDMNF_DUAL (0x0002)


/* ------------------------------------------------------------------------ */
/*  Tag definitions */

#define _MSTXTAG        (0xCD414553)    /* Maestix tag base ("MAES") */

/*  SetMaestro() tags */

#define MTAG_Input      (_MSTXTAG+0x00) /* Input? Def. INPUT_STD */
#define MTAG_Output     (_MSTXTAG+0x01) /* Output? Def. OUTPUT_BYPASS */
#define MTAG_SetCSB     (_MSTXTAG+0x02) /* Direct CSB access */
#define MTAG_SetUDB     (_MSTXTAG+0x03) /* Direct UDB access */
#define MTAG_Studio     (_MSTXTAG+0x04) /* Studio mode? (TRUE/FALSE) */
#define MTAG_CopyProh   (_MSTXTAG+0x05) /* Copy protection? */
#define MTAG_Emphasis   (_MSTXTAG+0x06) /* Emphasis */
#define MTAG_Source     (_MSTXTAG+0x07) /* Source category code */
#define MTAG_Rate       (_MSTXTAG+0x08) /* Output rate */
#define MTAG_Validity   (_MSTXTAG+0x09) /* Validity flag (TRUE/FALSE) */
#define MTAG_ResetUDB   (_MSTXTAG+0x0A) /* Reset UDB */
#define MTAG_ResetLSA   (_MSTXTAG+0x0C) /* Reset Local Sample Address */

/*  StartRealtime() tags */

#define MTAG_Effect     (_MSTXTAG+0x0D) /* effect number (see below) */
#define MTAG_A0         (_MSTXTAG+0x0E) /* parameter -> A0 */
#define MTAG_A1         (_MSTXTAG+0x0F) /* parameter -> A1 */
#define MTAG_D2         (_MSTXTAG+0x10) /* parameter -> D2 */
#define MTAG_D3         (_MSTXTAG+0x11) /* parameter -> D3 */
#define MTAG_CustomCall (_MSTXTAG+0x12) /* pointer to custom call */
#define MTAG_PostLevel  (_MSTXTAG+0x13) /* Post levelmeter ? */


/* ------------------------------------------------------------------------ */
/*  Tag values for MTAG_Input */

#define INPUT_STD       (0)     /* User selected input */
#define INPUT_OPTICAL   (1)     /* optical input */
#define INPUT_COAXIAL   (2)     /* coaxial input */
#define INPUT_SRC48K    (3)     /* 48kHz internal source */


/* ------------------------------------------------------------------------ */
/*  Tag values for MTAG_Output */

#define OUTPUT_BYPASS   (0)     /* Bypass */
#define OUTPUT_INPUT    (1)     /* from input */
#define OUTPUT_FIFO     (2)     /* from FIFO */


/* ------------------------------------------------------------------------ */
/*  Tag values for MTAG_CopyProh */

#define CPROH_OFF       (0)     /* No protection requested */
#define CPROH_ON        (1)     /* Copy protection requested */
#define CPROH_PROHIBIT  (2)     /* Copy prohibited */
#define CPROH_INPUT     (3)     /* As input */


/* ------------------------------------------------------------------------ */
/*  Tag values for MTAG_Emphasis */

#define EMPH_OFF        (0)     /* no emphasis */
#define EMPH_50us       (1)     /* 50/15us */
#define EMPH_CCITT      (2)     /* CCITT J.17 (studio only) */
#define EMPH_MANUAL     (3)     /* Manuell (studio only) */
#define EMPH_INPUT      (4)     /* As input */
#define EMPH_ON         (EMPH_50us)


/* ------------------------------------------------------------------------ */
/*  Tag values for MTAG_Source */

#define SRC_INPUT       (0)     /* As input */
#define SRC_CD          (0x01)  /* CD */
#define SRC_DAT         (0x03)  /* DAT */
#define SRC_DSR         (0x0C)  /* DSR */
#define SRC_ADCONV      (0x06)  /* ADC */
#define SRC_INSTR       (0x05)  /* Instrument */


/* ------------------------------------------------------------------------ */
/*  Tag values for MTAG_Rate */

#define RATE_32000      (0)     /* Rate 32000 Hz */
#define RATE_44100      (1)     /* Rate 44100 Hz */
#define RATE_48000      (2)     /* Rate 48000 Hz */
#define RATE_48000MANU  (3)     /* Rate 48000 Hz Manual */
#define RATE_INPUT      (4)     /* As input */


/* ------------------------------------------------------------------------ */
/*  Realtime FX codes */

#define RFX_Muting      (0)     /* mute incoming signal */
#define RFX_Bypass      (1)     /* no manipulation (default) */
#define RFX_ChannelSwap (2)     /* swap left and right */
#define RFX_LeftOnly    (3)     /* mute right channel */
#define RFX_RightOnly   (4)     /* mute left channel */
#define RFX_Mono        (5)     /* mono */
#define RFX_Surround    (6)     /* surround */
#define RFX_Volume      (7)     /* volume */
                                /* MTAG_D2: left volume (0..256) */
                                /* MTAG_D3: right volume (0..256) */
#define RFX_Karaoke     (8)     /* filters out the singer */
#define RFX_Foregnd     (9)     /* filters out the surround info */
#define RFX_Spatial     (10)    /* virtual shifting of the speakers */
                                /* MTAG_D2: shift factor (0..256) */
                                /*          optimum: about 64 */
#define RFX_Echo        (11)    /* echo effect */
                                /* MTAG_D2: entry volume (0..256) */
                                /* MTAG_D3: decay volume (0..256) */
                                /* MTAG_A0: pointer to MRTorus structure */
#define RFX_Mask        (12)    /* mask/quantisize */
                                /* MTAG_D2: left mask word */
                                /* MTAG_D3: right mask word */
#define RFX_Offset      (13)    /* adding dc offset */
                                /* MTAG_D2: left offset (32767..-32768) */
                                /* MTAG_D3: right offset (32767..-32768) */
#define RFX_Robot       (14)    /* robot effect */
                                /* MTAG_D2: gate open (samples) */
                                /* MTAG_D3: gate closed (samples) */
                                /* MTAG_A0: pointer to mrrob structure */
#define RFX_ReSample    (15)    /* resample effect */
                                /* MTAG_D2: new rate (left) */
                                /* MTAG_D3: new rate (right) */
                                /* MTAG_A0: pointer to mrres structure */

/* ------------------------------------------------------------------------ */
/*  Torus structure for RFX_Echo */

struct MRTorus {
        APTR    mrtor_PointerL; /* Pointer to left data buffer */
        APTR    mrtor_PointerR; /* Pointer to right data buffer */
        ULONG   mrtor_Size;     /* Size of these buffers (bytes) */
        ULONG   mrtor_Offset;   /* current offset (init with NULL) */
};

/* ------------------------------------------------------------------------ */
/* ReSample structure for RFX_ReSample */

struct MRReSample {
        UWORD   mrres_LMax;     /* incoming sampling rate, left */
        UWORD   mrres_RMax;     /* incoming sampling rate, right */
        UWORD   mrres_LCounter; /* counter, init with 0 */
        UWORD   mrres_RCounter; /* counter, init with 0 */
        WORD    mrres_LData;    /* left audio data, init with 0 */
        WORD    mrres_RData;    /* right audio data, init with 0 */
};

/* ------------------------------------------------------------------------ */
/*  GetStatus() values */

#define MSTAT_TFIFO     (0)     /* Transmit FIFO Status    (s.b.) */
#define MSTAT_RFIFO     (1)     /* Receive FIFO Status     (s.b.) */
#define MSTAT_Signal    (2)     /* Signal on input?        (BOOL) */
#define MSTAT_Emphasis  (3)     /* Signal uses emphasis?   (BOOL) */
#define MSTAT_DATsrc    (4)     /* DAT-Source?             (BOOL) */
#define MSTAT_CopyProh  (5)     /* Copy protection?        (BOOL) */
#define MSTAT_Rate      (6)     /* Rate                    (ULONG) */
#define MSTAT_UDB       (7)     /* get current UDB         (UBYTE) */

/*  Values for TFIFO & RFIFO */

#define FIFO_Off        (0)     /* FIFO is turned off */
#define FIFO_Running    (1)     /* FIFO is active */
#define FIFO_Error      (2)     /* FIFO overflow detected */

#endif
