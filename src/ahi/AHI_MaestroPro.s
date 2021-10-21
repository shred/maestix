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

TRUE		EQU	1	; "AHI-True" (sadly this is necessary)

		INCLUDE	devices/ahi.i
		INCLUDE	dos/dos.i
		INCLUDE	dos/dosextens.i
		INCLUDE	dos/dostags.i
		INCLUDE	exec/initializers.i
		INCLUDE	exec/libraries.i
		INCLUDE	exec/lists.i
		INCLUDE	exec/memory.i
		INCLUDE	exec/resident.i
		INCLUDE	exec/tasks.i
		INCLUDE	intuition/intuition.i
		INCLUDE	libraries/ahi_sub.i
		INCLUDE libraries/maestix.i
		INCLUDE	lvo/dos.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/intuition.i
		INCLUDE lvo/maestix.i
		INCLUDE	lvo/utility.i

		INCLUDE	ahipriv.i

		IFD	_MAKE_68020
		 MACHINE 68020
		ENDC

PLAYBACKBUFANZ	EQU	4		; Number of playback buffers

RECORDBUFANZ	EQU	4		; Number of record buffers
RECORDBUFSIZE	EQU	4*1024		; Size of record buffer (<32KB)

TASKPRI		EQU	120		; Audio task priority
STACKSIZE	EQU	4096		; Task stack size

ENVBUFFERSIZE	EQU	200		; Size of env variables store

AHIDB_MyModeID	EQU	AHIDB_UserBase+0


		SECTION	text,CODE

VERSION		EQU	2		;<- Version
REVISION	EQU	4		;<- Revision

SETVER          MACRO                   ;<- Version String Macro
		dc.b	"2.4"
		ENDM

SETDATE         MACRO                   ;<- Date String MACRO
		dc.b	"23.10.21"
		ENDM


		rsreset			; MAIN STRUCTURE
main_MHandle	rs.l	1		; Maestro handle
main_AHICtrl	rs.l	1		; ^related AudioControl
main_ModeID	rs.l	1		; AudioMode ID

main_PBTask	rs.l	1		; Playback Task
main_PBBufList	rs.l	1		; APTR * List of all playback buffers
main_PBBufNum	rs.w	1		; Number of playback buffers

main_RECTask	rs.l	1		; Record Task
main_RECWait	rs.l	1		; Buffer waiting
main_RECBufList	rs.l	1		; APTR * List of all record buffers
main_RECBufSize	rs.l	1		; Size of each record buffer
main_RECBufNum	rs.w	1		; Number of record buffers

main_PBPort	rs.b	MP_SIZE		; Reply-Port for Playback (PBTask!)
main_RECPort	rs.b	MP_SIZE		; Reply-Port for Record (RECTask!)
main_CurrAHIRM	rs.l	1		; Free AHIRM
main_WaitAHIRM	rs.l	1		; Waiting AHIRM
main_AHIRM1	rs.l	3		; AHI RecordMessage 1
main_AHIRM2	rs.l	3		; AHI RecordMessage 2
main_CurrInput	rs.w	1		; Currently selected input
main_SIZEOF	rs.w	0

		rsreset			; TASK STRUCTURE
task_Task	rs.b	TC_SIZE		; Task
task_Stack	rs.b	STACKSIZE	; Stack
task_SIZEOF	rs.w	0

**
* Avoid start from CLI.
*
Start		moveq	#0,d0
		rts

**
* Describe library.
*
InitDDescrip	dc.w	RTC_MATCHWORD
		dc.l	InitDDescrip
		dc.l	EndCode
		dc.b	RTF_AUTOINIT,VERSION,NT_LIBRARY,0
		dc.l	libname,libidstring,Init
libname		dc.b	"maestropro.audio",0
libidstring	dc.b	"maestropro "
		SETVER
		dc.b	" ("
		SETDATE
		dc.b	")"
		IFD	_MAKE_68020
		 dc.b	" 68020"
		ENDC
		dc.b	13,10,0

**
* Copyright note for hex reader
*
		dc.b	"(C) 1997-2021 Richard 'Shred' K\xF6rber ",$a
		dc.b	"License: GNU General Public License v3 ",$a
		dc.b	"Source: https://maestix.shredzone.org",0
		even
		cnop	0,4

**
* Init table
*
Init		dc.l	ahb_SIZEOF,FuncTab,DataTab,InitFct

**
* Function table. Keep this order, only append!
*
FuncTab		dc.l	Open,Close,Expunge,Null	; Standard
		dc.l	AHIsub_AllocAudio	; -30
		dc.l	AHIsub_FreeAudio	; -36
		dc.l	AHIsub_Disable		; -42
		dc.l	AHIsub_Enable		; -48
		dc.l	AHIsub_Start		; -54
		dc.l	AHIsub_Update		; -60
		dc.l	AHIsub_Stop		; -66
		dc.l	AHIsub_SetVol		; -72
		dc.l	AHIsub_SetFreq		; -78
		dc.l	AHIsub_SetSound		; -84
		dc.l	AHIsub_SetEffect	; -90
		dc.l	AHIsub_LoadSound	; -96
		dc.l	AHIsub_UnloadSound	; -102
		dc.l	AHIsub_GetAttr		; -108
		dc.l	AHIsub_HardwareControl	; -114
		dc.l	-1

**
* Data table
*
DataTab         INITBYTE	LN_TYPE,NT_LIBRARY
		INITLONG	LN_NAME,libname
		INITBYTE	LIB_FLAGS,LIBF_SUMUSED|LIBF_CHANGED
		INITWORD	LIB_VERSION,VERSION
		INITWORD	LIB_REVISION,REVISION
		INITLONG	LIB_IDSTRING,libidstring
		dc.l		0

**
* Initialize library
*
*	-> D0.l	^LibBase
*	-> A0.l	^SegList
*	-> A6.l	^SysLibBase
*	<- D0.l	^LibBase
*
InitFct		movem.l	d1-d7/a0-a6,-(sp)
	;-- remember vectors
		move.l	d0,a5
		move.l	d0,mybase
		move.l	a6,(ahb_SysLib,a5)
		move.l	a6,execbase
		move.l	a0,(ahb_SegList,a5)
	;-- open libraries
		lea	(dosname,PC),a1		; dos
		moveq	#37,d0
		exec	OpenLibrary
		move.l	d0,dosbase
		beq	.error1
		lea	(utilsname,PC),a1	; utilities
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,utilsbase
		beq	.error2
		lea	(maestixname,PC),a1	; maestix
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,maestbase
		bne	.gotmstx
		lea	(maestixname,PC),a0
		moveq	#36,d0
		bsr	warnlib
	;-- done
.gotmstx	move.l	a5,d0
.exit		movem.l	(sp)+,d1-d7/a0-a6
		rts
	;-- error
.error2		move.l	(dosbase,PC),a1
		exec	CloseLibrary
.error1		moveq	#0,d0
		bra	.exit

	;-> a0.l ^Libname
	;-> d0.l ^libver
warnlib         move.l  d0,-(SP)
		move.l	a0,-(SP)
		lea	(.intuiname,PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,a6
		sub.l	a0,a0
		lea	(.easy,PC),a1
		sub.l	a2,a2
		move.l	SP,a3
		intui.q	EasyRequestArgs
		addq.l	#8,SP
		move.l	a6,a1
		exec	CloseLibrary
		rts

.easy		dc.l	EasyStruct_SIZEOF,0,.title,.body,.gadget
.title		dc.b	"maestropro.audio request",0
.body		dc.b	"Couldn't open %s V%ld",0
.gadget		dc.b	"Okay",0
.intuiname	dc.b	"intuition.library",0
		even

**
* Open library
*
*	-> D0.l	Version
*	-> A6.l	^LibBase
*	<- D0.l	^LibBase if successful
*
Open		addq	#1,(LIB_OPENCNT,a6)
		bclr	#AHLB_DELEXP,(ahb_Flags+1,a6)
		move.l	a6,d0
		rts

**
* Close library
*
*	-> A6.l	^LibBase
*	<- D0.l	^SegList or 0
*
Close		moveq	#0,d0
		subq	#1,(LIB_OPENCNT,a6)
		bne.b	.notlast
		btst	#AHLB_DELEXP,(ahb_Flags+1,a6)
		beq.b	.notlast
		bsr.b	Expunge
.notlast	rts

**
* Expunge library
*
*	-> A6.l	^LibBase
*                                                    *
Expunge		movem.l	d2/a5-a6,-(sp)
		move.l	a6,a5
		move.l	(ahb_SysLib,a5),a6
		tst	(LIB_OPENCNT,a5)
		beq	.expimmed
.abort		bset	#AHLB_DELEXP,(ahb_Flags+1,a5)
		moveq	#0,d0
		bra	.exit
.expimmed	move.l	(ahb_SegList,a5),d2
		move.l	a5,a1
		exec	Remove
	;-- close own resources
		move.l	(utilsbase,PC),a1
		exec	CloseLibrary
		move.l	(maestbase,PC),a1
		exec	CloseLibrary
	;-- release memory
		moveq	#0,d0
		move.l	a5,a1
		move	(LIB_NEGSIZE,a5),d0
		sub.l	d0,a1
		add	(LIB_POSSIZE,a5),d0
		exec	FreeMem
		move.l	d2,d0
.exit		movem.l	(sp)+,d2/a5-a6
		rts

**
* Do nothing
*                                                   *
Null		moveq	#0,d0
		rts


******* maestropro.audio/AHIsub_AllocAudio ************************************
*
*   NAME
*       AHIsub_AllocAudio -- Allocates and initializes the audio hardware.
*
*   SYNOPSIS
*       result = AHIsub_AllocAudio( tags, audioctrl);
*       D0                          A1    A2
*
*       ULONG AHIsub_AllocAudio( struct TagItem *, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Allocate and initialize the audio hardware. Decide if and how you
*       wish to use the mixing routines provided by 'ahi.device', by looking
*       in the AHIAudioCtrlDrv structure and parsing the tag list for tags
*       you support.
*
*       1) Use mixing routines with timing:
*           You will need to be able to play any number of samples from
*           about 80 up to 65535 with low overhead.
*           - Update AudioCtrl->ahiac_MixFreq to nearest value that your
*             hardware supports.
*           - Return AHISF_MIXING|AHISF_TIMING.
*       2) Use mixing routines without timing:
*           If the hardware can't play samples with any length, use this
*           alternative and provide timing yourself. The buffer must
*           take less than about 20 ms to play, preferable less than 10!
*           - Update AudioCtrl->ahiac_MixFreq to nearest value that your
*             hardware supports.
*           - Store the number of samples to mix each pass in
*             AudioCtrl->ahiac_BuffSamples.
*           - Return AHISF_MIXING
*           Alternatively, you can use the first method and call the
*           mixing hook several times in a row to fill up a buffer.
*           In that case, AHIsub_GetAttr(AHIDB_MaxPlaySamples) should
*           return the size of the buffer plus AudioCtrl->ahiac_MaxBuffSamples.
*           If the buffer is so large that it takes more than (approx.) 10 ms to
*           play it for high sample frequencies, AHIsub_GetAttr(AHIDB_Realtime)
*           should return FALSE.
*       3) Don't use mixing routines:
*           If your hardware can handle everyting without using the CPU to
*           mix the channels, you tell 'ahi.device' this by not setting
*           neither the AHISB_MIXING nor the AHISB_TIMING bit.
*
*       If you can handle stereo output from the mixing routines, also set
*       bit AHISB_KNOWSTEREO.
*
*       If you can handle hifi (32 bit) output from the mixing routines,
*       set bit AHISB_KNOWHIFI.
*
*       If this driver can be used to record samples, set bit AHISB_CANRECORD,
*       too (regardless if you use the mixing routines in AHI or not).
*
*       If the sound card has hardware to do DSP effects, you can set the
*       AHISB_CANPOSTPROCESS bit. The output from the mixing routines will
*       then be two separate buffers, one wet and one dry. You sould then
*       apply the Fx on the wet buffer, and post-mix the two buffers before
*       you send the sampels to the DAC. (V3)
*
*   INPUTS
*       tags - pointer to a taglist.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   TAGS
*       The tags are from the audio database (AHIDB_#? in <devices/ahi.h>),
*       NOT the tag list the user called ahi.device/AHI_AllocAudio() with.
*
*   RESULT
*       Flags, defined in <libraries/ahi_sub.h>.
*
*   EXAMPLE
*
*   NOTES
*       You don't have to clean up on failure, AHIsub_FreeAudio() will
*       allways be called.
*
*   BUGS
*
*   SEE ALSO
*       AHIsub_FreeAudio(), AHIsub_Start()
*
*****************************************************************************
AHIsub_AllocAudio
		movem.l	d1-d7/a0-a6,-(SP)
		move.l	a2,a5
		move.l	a1,a4
		clr.l	(ahiac_DriverData,a5)
		IFD	_MAKE_68020
		 tst.l	(maestbase,PC)		; test maestix presence
		ELSE
		 move.l	(maestbase,PC),d0
		ENDC
		beq	.error
	;-- alloc main structure memory
		move.l	#main_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocVec
		move.l	d0,(ahiac_DriverData,a5)
		beq	.error
		move.l	d0,a3
		move.l	a5,(main_AHICtrl,a3)
	;-- evaluate tag list
		move.l	a4,a0
		move.l	#AHIDB_MyModeID,d0
		moveq	#0,d1
		utils	GetTagData
		move.l	d0,(main_ModeID,a3)
		beq	.error
	;-- adapt mix freq
		move.l	#32000,d1
		cmp.l	#$000E0004,d0
		beq	.mfokay
		move.l	#44100,d1
		cmp.l	#$000E0003,d0
		beq	.mfokay
		move.l	#48000,d1
.mfokay		move.l	d1,(ahiac_MixFreq,a5)
	;-- allocate MaestroPro
		sub.l	a0,a0
		maest	AllocMaestro
		move.l	d0,(main_MHandle,a3)
		beq	.error
	;-- setup MaestroPro
		lea	(.mtags_noinput,PC),a1
		move.l	(main_ModeID,a3),d0
		cmp.l	#$000E0001,d0
		beq	.noin
		lea	(.mtags_input,PC),a1
.noin		move.l	(main_MHandle,a3),a0
		maest	SetMaestro
		move	#INPUT_STD,(main_CurrInput,a3)
	;-- return feature set
		moveq	#AHISF_CANRECORD|AHISF_KNOWSTEREO|AHISF_MIXING|AHISF_TIMING,d0
.exit		movem.l	(SP)+,d1-d7/a0-a6
		rts
	;-- failed
.error		moveq	#AHISF_ERROR,d0
		bra	.exit

	;-- maestro tags if there is no input signal
.mtags_noinput	dc.l	MTAG_Input,INPUT_SRC48K
		dc.l	MTAG_Source,SRC_DAT
		dc.l	MTAG_Rate,RATE_48000
		dc.l	TAG_DONE

	;-- maestro tags if there is an input signal
.mtags_input	dc.l	MTAG_Input,INPUT_STD
		dc.l	MTAG_Source,SRC_INPUT
		dc.l	MTAG_Rate,RATE_INPUT
		dc.l	TAG_DONE


******* [driver].audio/AHIsub_FreeAudio *************************************
*
*   NAME
*       AHIsub_FreeAudio -- Deallocates the audio hardware.
*
*   SYNOPSIS
*       AHIsub_FreeAudio( audioctrl );
*                         A2
*
*       void AHIsub_FreeAudio( struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Deallocate the audio hardware and other resources allocated in
*       AHIsub_AllocAudio(). AHIsub_Stop() will always be called by
*       'ahi.device' before this call is made.
*
*   INPUTS
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       It must be safe to call this routine even if AHIsub_AllocAudio()
*       was never called, failed or called more than once.
*
*   SEE ALSO
*       AHIsub_AllocAudio()
*
*****************************************************************************
AHIsub_FreeAudio
		movem.l	d0-d7/a0-a6,-(SP)
		move.l	a2,a5
		move.l	(ahiac_DriverData,a5),a4
		move.l	a4,d0
		beq	.nodriver
	;-- free maestro
		move.l	(main_MHandle,a4),d0
		beq	.nompro
		move.l	d0,a0
		maest	FreeMaestro
.nompro	;-- free main structure
		move.l	a4,a1
		exec	FreeVec
	;-- done
.nodriver	movem.l	(SP)+,d0-d7/a0-a6
		rts


******* [driver].audio/AHIsub_Disable ***************************************
*
*   NAME
*       AHIsub_Disable -- Temporary turn off audio interrupt/task
*
*   SYNOPSIS
*       AHIsub_Disable( audioctrl );
*                       A2
*
*       void AHIsub_Disable( struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       If you are lazy, then call exec.library/Disable().
*       If you are smart, only disable your own interrupt or task.
*
*   INPUTS
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       This call should be guaranteed to preserve all registers.
*       This call nests.
*
*   SEE ALSO
*       AHIsub_Enable(), exec.library/Disable()
*
*****************************************************************************
AHIsub_Disable	movem.l	a0-a3/a6/d0-d3,-(SP)
		exec	Disable
		movem.l	(SP)+,a0-a3/a6/d0-d3
		rts


******* [driver].audio/AHIsub_Enable ****************************************
*
*   NAME
*       AHIsub_Enable -- Turn on audio interrupt/task
*
*   SYNOPSIS
*       AHIsub_Enable( audioctrl );
*                      A2
*
*       void AHIsub_Enable( struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       If you are lazy, then call exec.library/Enable().
*       If you are smart, only enable your own interrupt or task.
*
*   INPUTS
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       This call should be guaranteed to preserve all registers.
*       This call nests.
*
*   SEE ALSO
*       AHIsub_Disable(), exec.library/Enable()
*
*****************************************************************************
AHIsub_Enable	movem.l	a0-a3/a6/d0-d3,-(SP)
		exec	Enable
		movem.l	(SP)+,a0-a3/a6/d0-d3
		rts


******* [driver].audio/AHIsub_Start *****************************************
*
*   NAME
*       AHIsub_Start -- Starts playback or recording
*
*   SYNOPSIS
*       error = AHIsub_Start( flags, audioctrl );
*       D0                    D0     A2
*
*       ULONG AHIsub_Start(ULONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       What to do depends what you returned in AHIsub_AllocAudio().
*
*     * First, assume bit AHISB_PLAY in flags is set. This means that you
*       should begin playback.
*
*     - AHIsub_AllocAudio() returned AHISF_MIXING|AHISF_TIMING:
*
*       A) Allocate a mixing buffer of ahiac_BuffSize bytes.
*       B) Create/start an interrupt or task that will do 1-4 over and over
*          again until AHIsub_Stop() is called. Note that it is not a good
*          idea to do the actual mixing and conversion in a real hardware
*          interrupt. Signal a task or create a Software Interrupt to do
*          the number crunching.
*
*       1) Call the user Hook ahiac_PlayerFunc with the following parameters:
*                  A0 - (struct Hook *)
*                  A2 - (struct AHIAudioCtrlDrv *)
*                  A1 - Set to NULL.
*
*       2) Call the mixing Hook (ahiac_MixerFunc) with the following
*          parameters:
*                  A0 - (struct Hook *)           - The Hook itself
*                  A2 - (struct AHIAudioCtrlDrv *)
*                  A1 - (WORD *[])                - The mixing buffer.
*          Note that ahiac_MixerFunc preserves ALL registers.
*          The user Hook ahiac_SoundFunc will be called by the mixing
*          routine when a sample have been processed, so you don't have to
*          worry about that.
*          How the buffer will be filled is indicated by ahiac_Flags.
*          It is allways filled with signed 16-bit (32 bit if AHIDBB_HIFI in
*          in ahiac_Flags is set) words, even if playback is 8 bit. If
*          AHIDBB_STEREO is set (in ahiac_Flags), data for left and right
*          channel are interleved:
*           1st sample left channel,
*           1st sample right channel,
*           2nd sample left channel,
*           ...,
*           ahiac_BuffSamples:th sample left channel,
*           ahiac_BuffSamples:th sample right channel.
*          If AHIDBB_STEREO is cleared, the mono data is stored:
*           1st sample,
*           2nd sample,
*           ...,
*           ahiac_BuffSamples:th sample.
*          Note that neither AHIDBB_STEREO nor AHIDBB_HIFI will be set if
*          you didn't report that you understand these flags when
*          AHI_AllocAudio() was called.
*
*          For AHI V2, the type of buffer is also avalable in ahiac_BuffType.
*          It is suggested that you use this value instead. ahiac_BuffType
*          can be one of AHIST_M16S, AHIST_S16S, AHIST_M32S and AHIST_S32S.
*
*       3) Convert the buffer if needed and feed it to the audio hardware.
*          Note that you may have to clear CPU caches if you are using DMA
*          to play the buffer, and the buffer is not allocated in non-
*          cachable RAM.
*
*       4) Wait until the whole buffer has been played, then repeat.
*
*       Use double buffering if possible!
*
*       You may DECREASE ahiac_BuffSamples slightly, for example to force an
*       even number of samples to be mixed. By doing this you will make
*       ahiac_PlayerFunc to be called at wrong frequency so be careful!
*       Even if ahiac_BuffSamples is defined ULONG, it will never be greater
*       than 65535.
*
*       ahiac_BuffSize is the largest size of the mixing buffer that will be
*       needed until AHIsub_Stop() is called.
*
*       ahiac_MaxBuffSamples is the maximum number of samples that will be
*       mixed (until AHIsub_Stop() is called). You can use this value if you
*       need to allocate DMA buffers.
*
*       ahiac_MinBuffSamples is the minimum number of samples that will be
*       mixed. Most drivers will ignore it.
*
*       If AHIsub_AllocAudio() returned with the AHISB_CANPOSTPROCESS bit set,
*       ahiac_BuffSize is large enough to hold two buffers. The mixing buffer
*       will be filled with the wet buffer first, immedeately followed by the
*       dry buffer. I.e., ahiac_BuffSamples sample frames wet data, then
*       ahiac_BuffSamples sample frames dry data. The DSP fx should only be
*       applied to the wet buffer, and the two buffers should then be added
*       together. (V3)
*
*     - If AHIsub_AllocAudio() returned AHISF_MIXING, do as described above,
*       except calling ahiac_PlayerFunc. ahiac_PlayerFunc should be called
*       ahiac_PlayerFreq times per second, clocked by timers on your sound
*       card or by using 'realtime.library'. No other Amiga resources may
*       be used for timing (like direct CIA timers).
*       ahiac_MinBuffSamples and ahiac_MaxBuffSamples are undefined if
*       AHIsub_AllocAudio() returned AHISF_MIXING (AHISB_TIMING bit not set).
*
*     - If AHIsub_AllocAudio() returned with neither the AHISB_MIXING nor
*       the AHISB_TIMING bit set, then just start playback. Don't forget to
*       call ahiac_PlayerFunc ahiac_PlayerFreq times per second. Only your
*       own timing hardware or 'realtime.library' may be used. Note that
*       ahiac_MixerFunc, ahiac_BuffSamples, ahiac_MinBuffSamples,
*       ahiac_MaxBuffSamples and ahiac_BuffSize are undefined. ahiac_MixFreq
*       is the frequency the user wants to use for recording, if you support
*       that.
*
*     * Second, assume bit AHISB_RECORD in flags is set. This means that you
*       should start to sample. Create a interrupt or task that does the
*       following:
*
*       Allocate a buffer (you chose size, but try to keep it reasonable
*       small to avoid delays - it is suggested that RecordFunc is called
*       at least 4 times/second for the lowers sampling rate, and more often
*       for higher rates), and fill it with the sampled data. The format
*       should always be AHIST_S16S (even with 8 bit mono samplers), which
*       means:
*           1st sample left channel,
*           1st sample right channel (same as prev. if mono),
*           2nd sample left channel,
*           ... etc.
*       Each sample is a signed word (WORD). The sample rate should be equal
*       to the mixing rate.
*
*       Call the ahiac_SamplerFunc Hook with the following parameters:
*           A0 - (struct Hook *)           - The Hook itself
*           A2 - (struct AHIAudioCtrlDrv *)
*           A1 - (struct AHIRecordMessage *)
*       The message should be filled as follows:
*           ahirm_Type - Set to AHIST_S16S.
*           ahirm_Buffer - A pointer to the filled buffer.
*           ahirm_Samples - How many sample frames stored.
*       You must not destroy the buffer until next time the Hook is called.
*
*       Repeat until AHIsub_Stop() is called.
*
*     * Note that both bits may be set when this function is called.
*
*   INPUTS
*       flags - See <libraries/ahi_sub.h>.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   RESULT
*       Returns AHIE_OK if successful, else an error code as defined
*       in <devices/ahi.h>. AHIsub_Stop() will always be called, even
*       if this call failed.
*
*   NOTES
*       The driver must be able to handle multiple calls to this routine
*       without preceding calls to AHIsub_Stop().
*
*   SEE ALSO
*       AHIsub_Update(), AHIsub_Stop()
*
*****************************************************************************
AHIsub_Start	movem.l	d1/a4-a6,-(SP)
		move.l	a2,a5
		move.l	(ahiac_DriverData,a5),a4
		move.l	d0,d1
	;-- playback?
		btst	#AHISB_PLAY,d1
		beq	.no_play
		bsr	start_playback
		bne	.exit
	;-- record?
.no_play	btst	#AHISB_RECORD,d1
		beq	.no_record
		bsr	start_record
		bne	.exit
	;-- done
.no_record	moveq	#AHIE_OK,d0
.exit		movem.l	(SP)+,d1/a4-a6
		rts

**
* Start playback.
*
*	-> A5.l	^AudioCtrl
*	-> A4.l	^DriverData
*	<- D0.l	Error code or 0 (+CCR)
*
start_playback	movem.l	d1-d7/a0-a6,-(SP)
	;-- stop a running playback
		moveq	#AHISF_PLAY,d0
		move.l	(mybase,PC),a6
		jsr	(-66,a6)		; AHIsub_Stop
		moveq	#0,d0
		jsr	(-60,a6)		; AHIsub_Update
	;-- already running?
		tst.l	(main_PBTask,a4)
		bne	.running
	;-- allocate mix buffer
		lea	(.bufvarname,PC),a0	; evaluate number of buffers
		move.l	#PLAYBACKBUFANZ,d0
		bsr	GetEnvLong
		move	d0,(main_PBBufNum,a4)
		beq	.err_nomem
		moveq	#0,d0			; allocate bufferptr array
		move	(main_PBBufNum,a4),d0
		lsl.l	#2,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocVec
		move.l	d0,(main_PBBufList,a4)
		beq	.err_nomem
		move.l	d0,a3			; A3: ^Bufferptr
		move	(main_PBBufNum,a4),d3
		subq	#1,d3
.allocloop	move.l	(ahiac_BuffSize,a5),d0
		add.l	#edmn_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocVec
		move.l	d0,(a3)+		; remember pointer
		beq	.err_nomem
		move.l	d0,a0
		lea	(edmn_SIZEOF,a0),a1
		move.l	a1,(edmn_BufPtr,a0)
		move.l	(ahiac_BuffSize,a4),(edmn_BufLen,a0)
		move	#edmn_SIZEOF,(MN_LENGTH,a0)
		dbra	d3,.allocloop
	;-- launch playback task
		move.l	a4,a0
		lea	(PBTask,PC),a1
		bsr	LaunchTask
		move.l	d0,(main_PBTask,a4)
		beq	.err_nomem
	;-- create messageport
		lea	(main_PBPort,a4),a0
		move.l	d0,(MP_SIGTASK,a0)
		move.b	#SIGBREAKB_CTRL_E,(MP_SIGBIT,a0)
		lea	(MP_MSGLIST,a0),a0
		NEWLIST	a0
	;- send ctrl-c
		move.l	d0,a1
		move.l	#SIGBREAKF_CTRL_C,d0
		exec	Signal
	;-- switch to FIFO
		move.l	(main_MHandle,a4),a0
		lea	(.pbtags,PC),a1
		maest	SetMaestro
	;-- write message
		lea	(main_PBPort,a4),a2
		move.l	(main_PBBufList,a4),a3
		move	(main_PBBufNum,a4),d3
		subq	#1,d3
.putloop	move.l	(main_MHandle,a4),a0
		move.l	(a3)+,a1
		move.l	a2,(MN_REPLYPORT,a1)
		maest	TransmitData
		dbra	d3,.putloop
	;-- let's go
.running	moveq	#0,d0
.exit           movem.l	(SP)+,d1-d7/a0-a6	; remember: +CCR
		rts
	;-- error: no memory
.err_nomem	moveq	#AHIE_NOMEM,d0
		bra	.exit

	;-- playback tags
.pbtags		dc.l	MTAG_Output,OUTPUT_FIFO
		dc.l	TAG_DONE

	;-- strings
.bufvarname	dc.b	"AHImproPBBufNumber",0
		even

**
* Start recording.
*
*	-> A5.l	^AudioCtrl
*	-> A4.l	^DriverData
*	<- D0.l	Error-Code or 0 (+CCR)
*
start_record    movem.l	(SP)+,d1-d7/a0-a6
	;-- stop recording
		moveq	#AHISF_RECORD,d0
		move.l	(mybase,PC),a6
		jsr	(-66,a6)		; AHIsub_Stop
		moveq	#0,d0
		jsr	(-60,a6)		; AHIsub_Update
	;-- already running?
		tst.l	(main_RECTask,a4)
		bne	.running
	;-- set AHIRM
		lea	(main_AHIRM1,a4),a0
		move.l	a0,(main_CurrAHIRM,a4)
		lea	(main_AHIRM2,a4),a0
		move.l	a0,(main_WaitAHIRM,a4)
	;-- allocate sample buffer
		lea	(.sizevarname,PC),a0	; evaluate record buffer size
		move.l	#RECORDBUFSIZE,d0
		bsr	GetEnvLong
		and.l	#$FFFFFFFC,d0		; round down to multiple of four
		move.l	d0,(main_RECBufSize,a4)
		beq	.err_nomem
		lea	(.bufvarname,PC),a0	; evaluate number of buffers
		move.l	#RECORDBUFANZ,d0
		bsr	GetEnvLong
		move	d0,(main_RECBufNum,a4)
		beq	.err_nomem
		moveq	#0,d0			; allocate bufferptr array
		move	(main_RECBufNum,a4),d0
		lsl.l	#2,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocVec
		move.l	d0,(main_RECBufList,a4)
		beq	.err_nomem
		move.l	d0,a3
		move	(main_RECBufNum,a4),d3
		subq	#1,d3
.allocloop	move.l	(main_RECBufSize,a4),d0
		add.l	#edmn_SIZEOF,d0
		move.l	#MEMF_PUBLIC,d1
		exec	AllocVec
		move.l	d0,(a3)+
		beq	.err_nomem
		move.l	d0,a0
		lea	(edmn_SIZEOF,a0),a1
		move.l	a1,(edmn_BufPtr,a0)
		move.l	(main_RECBufSize,a4),(edmn_BufLen,a0)
		clr.l	(edmn_Flags,a0)
		move	#edmn_SIZEOF,(MN_LENGTH,a0)
		dbra	d3,.allocloop
	;-- launch record task
		move.l	a4,a0
		lea	(RECTask,PC),a1
		bsr	LaunchTask
		move.l	d0,(main_RECTask,a4)
		beq	.err_nomem
	;-- create messageport
		lea	(main_RECPort,a4),a0
		move.l	d0,(MP_SIGTASK,a0)
		move.b	#SIGBREAKB_CTRL_E,(MP_SIGBIT,a0)
		lea	(MP_MSGLIST,a0),a0
		NEWLIST	a0
	;-- send ctrl-c
		move.l	d0,a1
		move.l	#SIGBREAKF_CTRL_C,d0
		exec	Signal
	;-- send messages
		clr.l	(main_RECWait,a4)
		lea	(main_RECPort,a4),a2
		move.l	(main_RECBufList,a4),a3
		move	(main_RECBufNum,a4),d3
		subq	#1,d3
.putloop	move.l	(main_MHandle,a4),a0
		move.l	(a3)+,a1
		move.l	a2,(MN_REPLYPORT,a1)
		maest	ReceiveData
		dbra	d3,.putloop
	;-- done
.running	moveq	#0,d0
.exit           movem.l	(SP)+,d1-d7/a0-a6
		rts
	;-- error: no memory
.err_nomem	moveq	#AHIE_NOMEM,d0
		bra	.exit

	;-- strings
.sizevarname	dc.b	"AHImproRecBufSize",0
.bufvarname	dc.b	"AHImproRecBufNumber",0
		even


******* [driver].audio/AHIsub_Update ****************************************
*
*   NAME
*       AHIsub_Update -- Update some variables
*
*   SYNOPSIS
*       AHIsub_Update( flags, audioctrl );
*                      D0     A2
*
*       void AHIsub_Update(ULONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       All you have to do is to update some variables:
*       Mixing & timing: ahiac_PlayerFunc, ahiac_MixerFunc, ahiac_SamplerFunc,
*       ahiac_BuffSamples (and perhaps ahiac_PlayerFreq if you use it).
*       Mixing only: ahiac_PlayerFunc, ahiac_MixerFunc, ahiac_SamplerFunc and
*           ahiac_PlayerFreq.
*       Nothing: ahiac_PlayerFunc, ahiac_SamplerFunc and ahiac_PlayerFreq.
*
*   INPUTS
*       flags - Currently no flags defined.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   RESULT
*
*   NOTES
*       This call must be safe from interrupts.
*
*   SEE ALSO
*       AHIsub_Start()
*
*****************************************************************************
AHIsub_Update	rts


******* [driver].audio/AHIsub_Stop ******************************************
*
*   NAME
*       AHIsub_Stop -- Stops playback.
*
*   SYNOPSIS
*       AHIsub_Stop( flags, audioctrl );
*                    D0     A2
*
*       void AHIsub_Stop( ULONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Stop playback and/or recording, remove all resources allocated by
*       AHIsub_Start().
*
*   INPUTS
*       flags - See <libraries/ahi_sub.h>.
*       audioctrl - pointer to an AHIAudioCtrlDrv structure.
*
*   NOTES
*       It must be safe to call this routine even if AHIsub_Start() was never
*       called, failed or called more than once.
*
*   SEE ALSO
*       AHIsub_Start()
*
*****************************************************************************
AHIsub_Stop	movem.l	d0-d7/a0-a6,-(SP)
		move.l	a2,a5
		move.l	(ahiac_DriverData,a5),a4
		move.l	d0,d7
	;-- playback
		btst	#AHISB_PLAY,d7
		beq	.no_play
		move.l	(main_PBTask,a4),d0	; playback is running?
		beq	.check_play		;  no: nothing to do
		move.l	d0,a0
		bsr	KillTask		; kill playback task
		move.l	(main_MHandle,a4),a0	; switch to bypass
		lea	(.pbtags,PC),a1
		maest	SetMaestro
		clr.l	(main_PBTask,a4)
		move.l	(main_MHandle,a4),a0	; stop transmission
		maest	FlushTransmit
.check_play	move.l	(main_PBBufList,a4),d0	; free all buffers
		beq	.no_play
		move.l	d0,a3
		move	(main_PBBufNum,a4),d2
		subq	#1,d2
		bcs	.pb_free
.pb_loop	move.l	(a3)+,d0
		beq	.pb_nobuf
		move.l	d0,a1
		exec	FreeVec
.pb_nobuf	dbra	d2,.pb_loop
.pb_free	move.l	(main_PBBufList,a4),a1
		exec	FreeVec
		clr.l	(main_PBBufList,a4)
	;-- recording
.no_play	btst	#AHISB_RECORD,d7
		beq	.no_record
		move.l	(main_RECTask,a4),d0	; record is running?
		beq	.check_rec		;  no: nothing to do
		move.l	d0,a0
		bsr	KillTask		; kill record task
		clr.l	(main_RECTask,a4)
		move.l	(main_MHandle,a4),a0	; stop receiving
		maest	FlushReceive
.check_rec	clr.l	(main_RECWait,a4)
		move.l	(main_RECBufList,a4),d0	;free all buffers
		beq	.no_record
		move.l	d0,a3
		move	(main_RECBufNum,a4),d2
		subq	#1,d2
		bcs	.rec_free
.rec_loop	move.l	(a3)+,d0
		beq	.rec_nobuf
		move.l	d0,a1
		exec	FreeVec
.rec_nobuf	dbra	d2,.rec_loop
.rec_free	move.l	(main_RECBufList,a4),a1
		exec	FreeVec
		clr.l	(main_RECBufList,a4)
.no_record
	;-- done
.exit		movem.l	(SP)+,d0-d7/a0-a6
		rts

	;-- tags
.pbtags		dc.l	MTAG_Output,OUTPUT_BYPASS
		dc.l	TAG_DONE


******* [driver].audio/AHIsub_#? ********************************************
*
*   NAME
*       AHIsub_SetEffect -- Set effect.
*       AHIsub_SetFreq -- Set frequency.
*       AHIsub_SetSound -- Set sound.
*       AHIsub_SetVol -- Set volume and stereo panning.
*       AHIsub_LoadSound -- Prepare a sound for playback.
*       AHIsub_UnloadSound -- Discard a sound.
*
*   SYNOPSIS
*       See functions in 'ahi.device'.
*
*   IMPLEMENTATION
*       If AHIsub_AllocAudio() did not return with bit AHISB_MIXING set,
*       all user calls to these function will be routed to the driver.
*
*       If AHIsub_AllocAudio() did return with bit AHISB_MIXING set, the
*       calls will first be routed to the driver, and only handled by
*       'ahi.device' if the driver returned AHIS_UNKNOWN. This way it is
*       possible to add effects that the sound card handles on its own, like
*       filter and echo effects.
*
*       For what each funtion does, see the autodocs for 'ahi.device'.
*
*   INPUTS
*       See functions in 'ahi.device'.
*
*   NOTES
*       See functions in 'ahi.device'.
*
*   SEE ALSO
*       ahi.device/AHI_SetEffect(), ahi.device/AHI_SetFreq(),
*       ahi.device/AHI_SetSound(), ahi.device/AHI_SetVol(),
*       ahi.device/AHI_LoadSound(), ahi.device/AHI_UnloadSound()
*
*
*****************************************************************************
AHIsub_SetVol
AHIsub_SetFreq
AHIsub_SetSound
AHIsub_SetEffect
AHIsub_LoadSound
AHIsub_UnloadSound
		moveq	#AHIS_UNKNOWN,d0
		rts


******* [driver].audio/AHIsub_GetAttr ***************************************
*
*   NAME
*       AHIsub_GetAttr -- Returns information about audio modes or driver
*
*   SYNOPSIS
*       AHIsub_GetAttr( attribute, argument, default, taglist, audioctrl );
*       D0              D0         D1        D2       A1       A2
*
*       LONG AHIsub_GetAttr( ULONG, LONG, LONG, struct TagItem *,
*                            struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Return the attribute based on a tag list and an AHIAudioCtrlDrv
*       structure, which are the same that will be passed to
*       AHIsub_AllocAudio() by 'ahi.device'. If the attribute is
*       unknown to you, return the default.
*
*   INPUTS
*       attribute - Is really a Tag and can be one of the following:
*           AHIDB_Bits - Return how many output bits the tag list will
*               result in.
*           AHIDB_MaxChannels - Return the resulting number of channels.
*           AHIDB_Frequencies - Return how many mixing/sampling frequencies
*               you support
*           AHIDB_Frequency - Return the argument:th frequency
*               Example: You support 3 frequencies 32, 44.1 and 48 kHz.
*                   If argument is 1, return 44100.
*           AHIDB_Index - Return the index which gives the frequency closest
*               to argument.
*               Example: You support 3 frequencies 32, 44.1 and 48 kHz.
*                   If argument is 40000, return 1 (=> 44100).
*           AHIDB_Author - Return pointer to name of driver author:
*               "Martin 'Leviticus' Blom"
*           AHIDB_Copyright - Return pointer to copyright notice, including
*               the '(C)' character: "(C) 1996 Martin Blom" or "Public Domain"
*           AHIDB_Version - Return pointer version string, normal Amiga
*               format: "paula 1.5 (18.2.96)\r\n"
*           AHIDB_Annotation - Return pointer to an annotation string, which
*               can be several lines.
*           AHIDB_Record - Are you a sampler, too? Return TRUE or FALSE.
*           AHIDB_FullDuplex - Return TRUE or FALSE.
*           AHIDB_Realtime - Return TRUE or FALSE.
*           AHIDB_MaxPlaySamples - Normally, return the default. See
*               AHIsub_AllocAudio(), section 2.
*           AHIDB_MaxRecordSamples - Return the size of the buffer you fill
*               when recoring.
*
*           The following are associated with AHIsub_HardwareControl() and are
*           new for V2.
*           AHIDB_MinMonitorVolume
*           AHIDB_MaxMonitorVolume - Return the lower/upper limit for
*               AHIC_MonitorVolume. If unsupported but always 1.0, return
*               1.0 for both.
*           AHIDB_MinInputGain
*           AHIDB_MaxInputGain - Return the lower/upper limit for
*               AHIC_InputGain. If unsupported but always 1.0, return 1.0 for
*               both.
*           AHIDB_MinOutputVolume
*           AHIDB_MaxOutputVolume - Return the lower/upper limit for
*               AHIC_OutputVolume.
*           AHIDB_Inputs - Return how many inputs you have.
*           AHIDB_Input - Return a short string describing the argument:th
*               input. Number 0 should be the default one. Example strings
*               can be "Line 1", "Mic", "Optical" or whatever.
*           AHIDB_Outputs - Return how many outputs you have.
*           AHIDB_Output - Return a short string describing the argument:th
*               output. Number 0 should be the default one. Example strings
*               can be "Line 1", "Headphone", "Optical" or whatever.
*       argument - extra info for some attributes.
*       default - What you should return for unknown attributes.
*       taglist - Pointer to a tag list that eventually will be fed to
*           AHIsub_AllocAudio(), or NULL.
*       audioctrl - Pointer to an AHIAudioCtrlDrv structure that eventually
*           will be fed to AHIsub_AllocAudio(), or NULL.
*
*   NOTES
*
*   SEE ALSO
*       AHIsub_AllocAudio(), AHIsub_HardwareControl(),
*       ahi.device/AHI_GetAudioAttrsA()
*
*****************************************************************************
AHIsub_GetAttr	movem.l	d1-d7/a0-a6,-(SP)
		move.l	a2,a5
		move.l	a1,a4
		move.l	(ahiac_DriverData,a5),a3
	; CAUTION: A3 can be NULL if the driver wasn't properly
	;   initialized yet.
		move.l	d2,d7
		move.l	d1,d6
		move.l	d0,d5
	;-- check fast tags
		lea	(.fasttags,PC),a0
		utils	FindTagItem
		tst.l	d0
		bne	.foundtag
	;-- number of inputs?
		cmp.l	#AHIDB_Inputs,d5
		bne	.no_inputs
		bsr	.get_aid
		sub.l	#$000E0001,d0		; no input signal?
		beq	.exit			; then 0 inputs
		moveq	#3,d0
		bra	.exit			; else 3 inputs
	;-- input names?
.no_inputs	cmp.l	#AHIDB_Input,d5
		bne	.no_input
		lea	(.inputnames,PC),a0	;; TODO: proper range check!
		IFD	_MAKE_68020
		 move.l	(a0,d6.l*4),d0
		ELSE
		 move.l	d6,d0
		 add.l	d0,d0
		 add.l	d0,d0
		 move.l	(a0,d0.l),d0
		ENDC
		bra	.exit
	;-- frequency?
.no_input	cmp.l	#AHIDB_Frequency,d5
		bne	.no_freq
		bsr	.get_aid
		move.l	d0,d1
		move.l	#48000,d0
		sub.l	#$000E0001,d1		; no input signal?
		beq	.exit			; then 48kHz
		subq.l	#1,d1			; 48kHz
		beq	.exit
		move.l	#44100,d0
		subq.l	#1,d1			; 44.1kHz
		beq	.exit
		move.l	#32000,d0
		bra	.exit			; 32kHz
	;-- record available?
.no_freq	cmp.l	#AHIDB_Record,d5
		bne	.no_rec
		bsr	.get_aid
		sub.l	#$000E0001,d0		; no input signal?
		beq	.exit			; then no record
		moveq	#TRUE,d0
		bra	.exit			; else record available
	;-- full duplex?
.no_rec		cmp.l	#AHIDB_FullDuplex,d5
		bne	.no_fulldup
		bsr	.get_aid
		sub.l	#$000E0001,d0		; no input signal?
		beq	.exit			; then no full duplex
		moveq	#TRUE,d0
		bra	.exit			; else full duplex
	;-- unknown tag?
.no_fulldup	move.l	d7,d0			; return default value
		bra	.exit
	;-- fast tag found
.foundtag	move.l	d0,a0			; use value from tag list
		move.l	(4,a0),D0
	;-- done
.exit		movem.l	(SP)+,d1-d7/a0-a6
		rts

	;-- get audio id
.get_aid	move.l	a4,a0
		move.l	#AHIDB_MyModeID,d0
		moveq	#0,d1
		utils	GetTagData
		rts

	;-- fast tag list
.fasttags	dc.l	AHIDB_Bits,16		; 16 bits only
		dc.l	AHIDB_Frequencies,1	; there is always only one freq available
		dc.l	AHIDB_Index,0		; so it's always the first one ;)
		dc.l	AHIDB_Author,.author
		dc.l	AHIDB_Copyright,.copyright
		dc.l	AHIDB_Version,libidstring
		dc.l	AHIDB_Annotation,.anno
		dc.l	AHIDB_Realtime,TRUE	; we offer realtime sound
		dc.l	AHIDB_MaxRecordSamples,RECORDBUFSIZE>>2
		dc.l	AHIDB_MinMonitorVolume,0	; 0.0 (no monitoring)
		dc.l	AHIDB_MaxMonitorVolume,0	; 0.0 (no monitoring)
		dc.l	AHIDB_MinInputGain,$10000	; 1.0 (cannot change gain)
		dc.l	AHIDB_MaxInputGain,$10000	; 1.0 (cannot change gain)
		dc.l	AHIDB_MinOutputVolume,$10000	; 1.0 (cannot change volume)
		dc.l	AHIDB_MaxOutputVolume,$10000	; 1.0 (cannot change volume)
		dc.l	AHIDB_Outputs,1
		dc.l	AHIDB_Output,.outpt
		dc.l	TAG_DONE

	;-- list of input name
.inputnames	dc.l	.in_default,.in_optical,.in_coaxial

	;-- strings
.author		dc.b	"Richard 'Shred' K\xF6rber",0
.copyright	dc.b	"\xA9 1997-2021 Richard 'Shred' K\xF6rber, GPLv3",0
.anno		dc.b	"https://maestix.shredzone.org",0
.in_default	dc.b	"Default",0
.in_optical	dc.b	"Optical",0
.in_coaxial	dc.b	"Coaxial",0
.outpt          EQU	.in_optical
		even


******* [driver].audio/AHIsub_HardwareControl *******************************
*
*   NAME
*       AHIsub_HardwareControl -- Modify sound card settings
*
*   SYNOPSIS
*       AHIsub_HardwareControl( attribute,  argument, audioctrl );
*       D0                      D0          D1        A2
*
*       LONG AHIsub_HardwareControl( ULONG, LONG, struct AHIAudioCtrlDrv * );
*
*   IMPLEMENTATION
*       Set or return the state of a particular hardware component. AHI uses
*       AHIsub_GetAttr() to supply the user with limits and what tags are
*       available.
*
*   INPUTS
*       attribute - Is really a Tag and can be one of the following:
*           AHIC_MonitorVolume - Set the input monitor volume to argument.
*           AHIC_MonitorVolume_Query - Return the current input monitor
*               volume (argument is ignored).
*
*           AHIC_InputGain - Set the input gain to argument. (V2)
*           AHIC_InputGain_Query (V2)
*
*           AHIC_OutputVolume - Set the output volume to argument. (V2)
*           AHIC_OutputVolume_Query (V2)
*
*           AHIC_Input - Use the argument:th input source (default is 0). (V2)
*           AHIC_Input_Query (V2)
*
*           AHIC_Output - Use the argument:th output destination (default
*               is 0). (V2)
*           AHIC_Output_Query (V2)
*
*       argument - What value attribute should be set to.
*       audioctrl - Pointer to an AHIAudioCtrlDrv structure.
*
*   RESULT
*       Return the state of selected attribute. If you were asked to set
*       something, return TRUE. If attribute is unknown to you or unsupported,
*       return FALSE.
*
*   NOTES
*       This call must be safe from interrupts.
*
*   SEE ALSO
*       ahi.device/AHI_ControlAudioA(), AHIsub_GetAttr()
*
*****************************************************************************
AHIsub_HardwareControl
		movem.l	d1-d7/a0-a6,-(SP)
		IFD	_MAKE_68020
		 tst.l	(maestbase,PC)		; test for maestix
		ELSE
		 move.l	(maestbase,PC),d7
		ENDC
		beq	.false
		move.l	a2,a5
		move.l	(ahiac_DriverData,a5),a4
	;-- choose input?
		cmp.l	#AHIC_Input,d0
		bne	.no_input
		cmp.l	#2,d1			; max. 2
		bhi	.false			;   else unsupported
		move	d1,(main_CurrInput,a4)
		pea	(.tags,PC)
		pea	TAG_MORE.w
		move.l	d1,-(SP)
		pea	MTAG_Input
		move.l	(main_MHandle,a4),a0
		move.l	SP,a1
		maest	SetMaestro
		add.l	#4*4,SP			; restore stack
		moveq	#-1,d0			; successful
		bra	.exit
	;-- query input?
.no_input	cmp.l	#AHIC_Input_Query,d0
		bne	.no_in_query
		moveq	#0,d0
		move	(main_CurrInput,a4),d0
		bra	.exit
	;-- otherwise: not supported
.no_in_query
.false		moveq	#0,d0
	;-- done
.exit		movem.l	(SP)+,d1-d7/a0-a6
		rts

.tags		dc.l	MTAG_Source,SRC_INPUT
		dc.l	MTAG_Rate,RATE_INPUT
		dc.l	TAG_DONE


**
* Launch sub task.
*
* 	-> A0.l	^Main
*	-> A1.l	^Task code
*	<- D0.l	^Task structure
*
LaunchTask	movem.l	d1-d7/a0-a6,-(SP)
		move.l	a0,a5
		move.l	a1,a3
	;-- allocate memory for task structure
		move.l	#task_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocVec
		tst.l	d0
		beq	.exit
		move.l	d0,a4
	;-- initialize
		lea	(.taskname,PC),a0
		move.l	a0,(LN_NAME,a4)
		lea	(.taskvarname,PC),a0
		moveq	#TASKPRI,d0
		bsr	GetEnvLong
		move.b	#NT_TASK,(LN_TYPE,a4)
		move.b	d0,(LN_PRI,a4)
		lea	(TC_MEMENTRY,a4),a0
		NEWLIST	a0
		lea	(TC_SIZE,a4),a0
		move.l	a0,(TC_SPLOWER,a4)
		add.l	#STACKSIZE-8,a0
		move.l	a0,(TC_SPUPPER,a4)
		move.l	a5,-(a0)
		move.l	a0,(TC_SPREG,a4)
	;-- start task
		move.l	a4,a1
		move.l	a3,a2
		sub.l	a3,a3
		exec	AddTask
	;-- done
		move.l	a4,d0
.exit		movem.l	(SP)+,d1-d7/a0-a6
		rts

	;-- strings
.taskname	dc.b	"Maestix AHI driver",0
.taskvarname	dc.b	"AHImproTaskPri",0
		even


**
* Kill a sub task.
*
*	-> A0.l	^Task structure
*
KillTask	movem.l	d0-d7/a0-a6,-(SP)
		move.l	a0,a5
	;-- remove task
		move.l	a5,a1
		exec	RemTask
	;-- release memory
		move.l	a5,a1
		exec	FreeVec
	;-- done
.exit		movem.l	(SP)+,d0-d7/a0-a6
		rts


**
* Playback task.
*
PBTask		move.l	(4,SP),A5		; ^main
	;-- wait for ctrl-c
		move.l	#SIGBREAKF_CTRL_C,d0
		exec	Wait
	;-- wait for audio message
.loop		lea	(main_PBPort,a5),a0
		exec	GetMsg
		tst.l	d0
		bne	.gotmsg
		lea	(main_PBPort,a5),a0
		exec	WaitPort
		bra	.loop
.gotmsg		move.l	d0,a4
	;-- do some AHI magic
		move.l	(main_AHICtrl,a5),a2	; invoke player hook
		move.l	(ahiac_PlayerFunc,a2),a0
		sub.l	a1,a1
		movem.l	a4-a5,-(SP)
		utils	CallHookPkt
		movem.l	(SP)+,a4-a5
		move.l	(main_AHICtrl,a5),a2	; invoke mixer hook
		move.l	(ahiac_MixerFunc,a2),a0
		move.l	(edmn_BufPtr,a4),a1
		movem.l	a4-a5,-(SP)
		utils	CallHookPkt
		movem.l	(SP)+,a4-a5
		move.l	(main_AHICtrl,a5),a2	; correct buffer length
		move.l	(ahiac_BuffSamples,a2),d0
		add.l	d0,d0
		bset	#EDMNB_MONO,(edmn_Flags+1,a4)
		move.l	(ahiac_Flags,a2),d1
		btst	#AHIACB_STEREO,d1
		beq	.mono
		add.l	d0,d0
		bclr	#EDMNB_MONO,(edmn_Flags+1,a4)
.mono		move.l	d0,(edmn_BufLen,a4)
	;-- send  buffer
		move.l	a4,a1
		move.l	(main_MHandle,a5),a0
		maest	TransmitData
	;-- done
		bra	.loop


**
* Record task.
*
RECTask		move.l	(4,SP),a5		; ^main
	;-- wait for ctrl-c
		move.l	#SIGBREAKF_CTRL_C,d0
		exec	Wait
	;-- wait for audio message
.loop		lea	(main_RECPort,a5),a0
		exec	GetMsg
		tst.l	d0
		bne	.gotmsg
		lea	(main_RECPort,a5),a0
		exec	WaitPort
		bra	.loop
.gotmsg		move.l	d0,a4
	;-- do some AHI magic
		move.l	(main_AHICtrl,a5),a2	; invoke player hook
		move.l	(ahiac_SamplerFunc,a2),a0
		move.l	(main_CurrAHIRM,a5),a1
		move.l	#AHIST_S16S,(ahirm_Type,a1)
		move.l	(edmn_BufPtr,a4),(ahirm_Buffer,a1)
		move.l	(edmn_BufLen,a4),d0
		lsr.l	#2,d0
		move.l	d0,(ahirm_Length,a1)
		move.l	(main_RECWait,a5),a3	; current message in hook
		move.l	a4,(main_RECWait,a5)	; this is the new message
		move.l	(main_WaitAHIRM,a5),a4
		move.l	a1,(main_WaitAHIRM,a5)
		movem.l	a3-a5,-(SP)
		utils	CallHookPkt
		movem.l	(SP)+,a3-a5
		move.l	a4,(main_CurrAHIRM,a5)
	;-- recycle buffer
		move.l	a3,d0
		beq	.loop			; do not recycle
		move.l	a3,a1
		move.l	(main_MHandle,a5),a0
		maest	ReceiveData
	;-- done
		bra	.loop


**
* Get env variable as long
*
*	-> A0.l	^EnvVar name
*	-> D0.l	Default value
*	<- D0.l	Env value (or default if not present or invalid)
*
GetEnvLong	movem.l	d1-d3/d7/a0-a5,-(SP)
		move.l	d0,d7
		move.l	a0,a4
	;-- allocate buffer
		move.l	#ENVBUFFERSIZE,d0
		move.l	#MEMF_PUBLIC,d1
		exec	AllocVec
		tst.l	d0
		beq	.error
		move.l	d0,a5
	;-- search for env variable
		move.l	a4,d1			; name
		move.l	a5,d2			; buffer ptr
		move.l	#ENVBUFFERSIZE-1,d3	; buffer size
		moveq	#0,d4
		dos	GetVar
		cmp.l	#-1,d0			; not present?
		beq	.error2
	;-- convert to number
		pea	0.w			; make room on stack
		move.l	a5,d1			; buffer
		move.l	SP,d2
		dos	StrToLong		; convert
		move.l	(SP)+,d1		; retrieve result
		cmp.l	#-1,d0			; could not convert?
		beq	.error2
	;-- success: use parsed value
		move.l	d1,d7
	;-- release buffer
.error2		move.l	a5,a1
		exec	FreeVec
	;-- done
.error		move.l	d7,d0
		movem.l	(SP)+,d1-d3/d7/a0-a5
		rts


dosbase		dc.l	0		; ^dos
utilsbase	dc.l	0		; ^utility
maestbase	dc.l	0		; ^maestix
execbase	dc.l	0		; ^exec
mybase		dc.l	0		; ^own base

dosname		dc.b	"dos.library",0
utilsname	dc.b	"utility.library",0
maestixname	dc.b	"maestix.library",0
		even

		cnop	0,4
EndCode		ds.w	0
