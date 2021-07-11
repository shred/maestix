*
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
*

		IFND    LIBRARIES_MAESTIX_I
LIBRARIES_MAESTIX_I     SET     1

		IFND    EXEC_TYPES_I
		INCLUDE exec/types.i
		ENDC

		IFND    UTILITY_TAGITEM_I
		INCLUDE utility/tagitem.i
		ENDC

		IFND    EXEC_PORTS_I
		INCLUDE exec/ports.i
		ENDC

		IFND    EXEC_LISTS_I
		INCLUDE exec/lists.i
		ENDC

		IFND    EXEC_LIBRARIES_I
		INCLUDE exec/libraries.i
		ENDC


*------------------------------------------------------------------------*
* Generic library informations

MAESTIXNAME     MACRO
		dc.b    "maestix.library",0
		ENDM

MAESTIXVERSION  EQU     42

    STRUCTURE MaestixBase,0
	STRUCT  mxb_LibNode,LIB_SIZE
	LABEL   mxb_SIZEOF


*------------------------------------------------------------------------*
* MaestroBase structure

    STRUCTURE MaestroBase,0
	WORD    maba_Dummy       ;PRIVATE
	LABEL   maba_SIZEOF


*------------------------------------------------------------------------*
* DataMessage

    STRUCTURE DataMessage,0
	STRUCT  dmn_Message,MN_SIZE     ;struct Message
	APTR    dmn_BufPtr      ;pointer to public buffer memory
	ULONG   dmn_BufLen      ;length of buffer memory (bytes)
	LABEL   dmn_SIZEOF

    STRUCTURE ExtDataMessage,0
	STRUCT  edmn_Message,MN_SIZE    ;struct Message
	APTR    edmn_BufPtr     ;pointer to public buffer memory
	ULONG   edmn_BufLen     ;length of buffer memory (bytes)
	UWORD   edmn_Flags      ;Flags (EDMN see below)
	APTR    edmn_BufPtrR    ;pointer to right buffer (dual mode)
	LABEL   edmn_SIZEOF

* Flags for edmn_Flags
	BITDEF  EDMN,MONO,0     ;Buffer is MONO
	BITDEF  EDMN,DUAL,1     ;Buffer is DUAL

*------------------------------------------------------------------------*
* Tag definitions

_MSTXTAG        EQU     $CD414553       ;Maestix tag base ("MAES")

* SetMaestro() tags
*
MTAG_Input      EQU     _MSTXTAG+$00    ;Input? Def. INPUT_STD
MTAG_Output     EQU     _MSTXTAG+$01    ;Output? Def. OUTPUT_BYPASS
MTAG_SetCSB     EQU     _MSTXTAG+$02    ;Direct CSB access
MTAG_SetUDB     EQU     _MSTXTAG+$03    ;Direct UDB access
MTAG_Studio     EQU     _MSTXTAG+$04    ;Studio mode? (TRUE/FALSE)
MTAG_CopyProh   EQU     _MSTXTAG+$05    ;Copy protection?
MTAG_Emphasis   EQU     _MSTXTAG+$06    ;Emphasis
MTAG_Source     EQU     _MSTXTAG+$07    ;Source category code
MTAG_Rate       EQU     _MSTXTAG+$08    ;Output rate
MTAG_Validity   EQU     _MSTXTAG+$09    ;Validity flag (TRUE/FALSE)
MTAG_ResetUDB   EQU     _MSTXTAG+$0A    ;Reset UDB
MTAG_ResetLSA   EQU     _MSTXTAG+$0C    ;Reset Local Sample Address

* StartRealtime() tags
*
MTAG_Effect     EQU     _MSTXTAG+$0D    ;effect number (see below)
MTAG_A0         EQU     _MSTXTAG+$0E    ;parameter -> A0
MTAG_A1         EQU     _MSTXTAG+$0F    ;parameter -> A1
MTAG_D2         EQU     _MSTXTAG+$10    ;parameter -> D2
MTAG_D3         EQU     _MSTXTAG+$11    ;parameter -> D3
MTAG_CustomCall EQU     _MSTXTAG+$12    ;pointer to custom call
MTAG_PostLevel  EQU     _MSTXTAG+$13    ;Post Levelmeter ?


*------------------------------------------------------------------------*
* Tag values for MTAG_Input

INPUT_STD       EQU     0               ;User selected input
INPUT_OPTICAL   EQU     1               ;optical input
INPUT_COAXIAL   EQU     2               ;coaxial input
INPUT_SRC48K    EQU     3               ;48kHz internal source


*------------------------------------------------------------------------*
* Tag values for MTAG_Output

OUTPUT_BYPASS   EQU     0               ;Bypass
OUTPUT_INPUT    EQU     1               ;from input
OUTPUT_FIFO     EQU     2               ;from FIFO


*------------------------------------------------------------------------*
* Tag values for MTAG_CopyProh

CPROH_OFF       EQU     0               ;No protection requested
CPROH_ON        EQU     1               ;Copy protection requested
CPROH_PROHIBIT  EQU     2               ;Copy prohibited
CPROH_INPUT     EQU     3               ;As input


*------------------------------------------------------------------------*
* Tag values for MTAG_Emphasis

EMPH_OFF        EQU     0               ;no emphasis
EMPH_50us       EQU     1               ;50/15us
EMPH_CCITT      EQU     2               ;CCITT J.17 (studio only)
EMPH_MANUAL     EQU     3               ;Manuell (studio only)
EMPH_INPUT      EQU     4               ;As input
EMPH_ON         EQU     EMPH_50us


*------------------------------------------------------------------------*
* Tag values for MTAG_Source

SRC_INPUT       EQU     0               ;As input
SRC_CD          EQU     $01             ;CD
SRC_DAT         EQU     $03             ;DAT
SRC_DSR         EQU     $0C             ;DSR
SRC_ADCONV      EQU     $06             ;ADC
SRC_INSTR       EQU     $05             ;Instrument


*------------------------------------------------------------------------*
* Tag values for MTAG_Rate

RATE_32000      EQU     0               ;Rate 32000 Hz
RATE_44100      EQU     1               ;Rate 44100 Hz
RATE_48000      EQU     2               ;Rate 48000 Hz
RATE_48000MANU  EQU     3               ;Rate 48000 Hz Manual
RATE_INPUT      EQU     4               ;As input


*------------------------------------------------------------------------*
* Realtime FX codes

RFX_Muting      EQU     0               ;mute incoming signal
RFX_Bypass      EQU     1               ;no manipulation (default)
RFX_ChannelSwap EQU     2               ;swap left and right
RFX_LeftOnly    EQU     3               ;mute right channel
RFX_RightOnly   EQU     4               ;mute left channel
RFX_Mono        EQU     5               ;mono
RFX_Surround    EQU     6               ;surround
RFX_Volume      EQU     7               ;volume
					;MTAG_D2: left volume (0..256)
					;MTAG_D3: right volume (0..256)
RFX_Karaoke     EQU     8               ;filters out the singer
RFX_Foregnd     EQU     9               ;filters out the surround info
RFX_Spatial     EQU     10              ;virtual shifting of the speakers
					;MTAG_D2: shift factor (0..256)
					;         optimum: about 64
RFX_Echo        EQU     11              ;echo effect
					;MTAG_D2: entry volume (0..256)
					;MTAG_D3: fade volume (0..256)
					;MTAG_A0: pointer to mrtor structure
RFX_Mask        EQU     12              ;mask/quantisize
					;MTAG_D2: left mask word
					;MTAG_D3: right mask word
RFX_Offset      EQU     13              ;adding dc offset
					;MTAG_D2: left offset (32767..-32768)
					;MTAG_D3: right offset (32767..-32768)
RFX_Robot       EQU     14              ;robot effect
					;MTAG_D2: gate open (samples)
					;MTAG_D3: gate closed (samples)
					;MTAG_A0: pointer to mrrob structure
RFX_ReSample    EQU     15              ;resample effect
					;MTAG_D2: new rate (left)
					;MTAG_D3: new rate (right)
					;MTAG_A0: pointer to mrres structure
_RFX_COUNT	EQU	16		;Number of effects in this library version

*------------------------------------------------------------------------*
* Torus structure for RFX_Echo

    STRUCTURE MRTorus,0
	APTR    mrtor_PointerL          ;Pointer to left data buffer
	APTR    mrtor_PointerR          ;Pointer to right data buffer
	ULONG   mrtor_Size              ;Size of these buffers (bytes)
	ULONG   mrtor_Offset            ;current offset (init with NULL)
	LABEL   mrtor_SIZEOF

*------------------------------------------------------------------------*
* ReSample structure for RFX_ReSample

    STRUCTURE MRReSample,0
	UWORD   mrres_LMax              ;incoming sampling rate, left
	UWORD   mrres_RMax              ;incoming sampling rate, right
	UWORD   mrres_LCounter          ;counter, init with 0
	UWORD   mrres_RCounter          ;counter, init with 0
	WORD    mrres_LData             ;left audio data, init with 0
	WORD    mrres_RData             ;right audio data, init with 0
	LABEL   mrres_SIZEOF

*------------------------------------------------------------------------*
* GetStatus() values

MSTAT_TFIFO     EQU     0               ;Transmit FIFO Status    (s.b.)
MSTAT_RFIFO     EQU     1               ;Receive FIFO Status     (s.b.)
MSTAT_Signal    EQU     2               ;Signal on input?        (BOOL)
MSTAT_Emphasis  EQU     3               ;Signal uses emphasis?   (BOOL)
MSTAT_DATsrc    EQU     4               ;DAT-Source?             (BOOL)
MSTAT_CopyProh  EQU     5               ;Copy protection?        (BOOL)
MSTAT_Rate      EQU     6               ;Rate                    (ULONG)
MSTAT_UDB       EQU     7               ;get current UDB         (UBYTE)

* Values for TFIFO & RFIFO
*
FIFO_Off        EQU     0               ;FIFO is turned off
FIFO_Running    EQU     1               ;FIFO is active
FIFO_Error      EQU     2               ;FIFO overflow detected

		ENDC
