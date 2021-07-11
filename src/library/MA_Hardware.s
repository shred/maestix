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

		INCLUDE	exec/execbase.i
		INCLUDE	exec/interrupts.i
		INCLUDE	exec/nodes.i
		INCLUDE	exec/ports.i
		INCLUDE	exec/memory.i
		INCLUDE	exec/semaphores.i
		INCLUDE	devices/timer.i
		INCLUDE	libraries/configvars.i
		INCLUDE	utility/tagitem.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/utility.i
		INCLUDE	lvo/expansion.i
		INCLUDE	lvo/dos.i

		INCLUDE	libraries/maestix.i
		INCLUDE	maestixpriv.i

		IFD	_MAKE_68020
		 MACHINE 68020
		ENDC

		SECTION	text,CODE

mb_BLOCKSIZE	EQU	mb_SIZEOF+MP_SIZE+MP_SIZE+IS_SIZE

**
* Allocate MaestroPro sound card.
*
*	-> A0.l	^Tags
*	<- D0.l	^MaestroBase, NULL on error
*
* Tags:
*	MTAG_AllocOnly	Only allocate the card
*
		public	AllocMaestro
AllocMaestro	movem.l	d1-d5/a0-a6,-(sp)
		move.l	a0,a3			; remember tags
	;-- is macroaudio.library present?
		tst.l	maudiobase		; present?
		beq	.noma
		moveq	#0,d0			; yes: allocate maestropro.0
		move.l	maudiobase(PC),a6
		jsr	-162(a6)
		tst.l	d0			; successful?
		beq	.error1			; no, not present
		bmi	.error1			; no, in use
	;-- check if card is in use
.noma		lea	(mbsemaphore,PC),a0	; obtain MaestroBase semaphore
		exec	ObtainSemaphore
		tst.l	maestrobase		; there is a base,
		bne	.error1a		; someone else owns the card
	;-- allocate MaestroBase structure
		move.l	#mb_BLOCKSIZE,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocMem
		move.l	d0,maestrobase
		beq	.error1a
		move.l	(maestbase,PC),a0
		move.l	d0,(mab_AllocMstx,a0)
		move.l	d0,a5			; remember the base
		lea	(mbsemaphore,PC),a0	; release MaestroBase semaphore
		exec	ReleaseSemaphore
	;-- initialize semaphore
		lea	(mb_Semaphore,a5),a0	; create a hardware semaphore
		exec	InitSemaphore
	;-- allocate card
		sub.l	a0,a0
		move.l	#18260,d0		; MacroSystems
		moveq	#5,d1			; MaestroPro
		expans	FindConfigDev
		tst.l	d0
		beq	.error2			; there is no such board
		move.l	d0,a0
		move.l	(cd_BoardAddr,a0),a0	; remember hardware base address
		move.l	a0,(mb_HardBase,a5)
	;-- check if card is in use
	; This check is necessary because the original software
	; like Samplitude does not use this library, but accesses
	; the hardware directly.
		move	(mh_status,a0),d0	; read status register
		btst	#MASB_SLEEP,d0		; already powered up?
		beq	.error2			; yes: fail
	;-- allocate MessagePorts
		lea	(mb_SIZEOF,a5),a0	; ^MessagePort 1
		move.b	#PA_IGNORE,(MP_FLAGS,a0)
		lea	(MP_MSGLIST,a0),a1
		move.l	a1,(a1)			; initialize message list
		addq.l	#LH_TAIL,(a1)
		clr.l	LH_TAIL(a1)
		move.l	a1,LH_TAILPRED(a1)
		move.l	a0,(mb_TPort,a5)
		lea	(mb_SIZEOF+MP_SIZE,a5),a0 ; ^MessagePort 2
		move.b	#PA_IGNORE,(MP_FLAGS,a0)
		lea	(MP_MSGLIST,a0),a1
		move.l	a1,(a1)			; initialize message list
		addq.l	#LH_TAIL,(a1)
		clr.l	LH_TAIL(a1)
		move.l	a1,LH_TAILPRED(a1)
		move.l	a0,(mb_RPort,a5)
	;-- card shall only be allocated?
		st	(mb_AllocOnly,a5)	; preemptively set flag
		move.l	a3,a0			; ^tags
		move.l	#MTAG_AllocOnly,d0
		utils	FindTagItem
		tst.l	d0			; present?
		bne	.done			; yes: we're done here
		sf	(mb_AllocOnly,a5)	; clear flag again
	;-- initialize the card
		move.l	(mb_HardBase,a5),a4
		clr	(mb_ModusReg,a5)	; clear modus register
		move	(mb_ModusReg,a5),(mh_modus,a4)
		clr.l	(mb_CSB,a5)		; clear CSB
		clr.l	(mb_UDB,a5)		; clear UDB
		sf	(mb_UseUDB,a5)		; do not use UDB
		move.l	a4,a0
		add.l	#mh_sleep,a0
		move	(a0),d0			; power down
	;-- wait for reset
		move.l	#150000,d0		; 150ms
		bsr	TimerDelay
	;-- setup the card
		move.l	a4,a0
		add.l	#mh_sleep,a0
		move	d0,(a0)			; power up
		move.l	#10000,d0		; 10ms
		bsr	TimerDelay
		or	#MAMF_ECLD|MAMF_ERSTN,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		move.l	a5,a0			; create internal tag list
		pea	(.tags,PC)
		pea	TAG_MORE
		move.l	(maestbase,PC),a6
		move.b	(mab_DefStudio,a6),d0
		IFD	_MAKE_68020
		 extb.l	d0
		ELSE
		 ext	d0
		 ext.l	d0
		ENDC
		move.l	d0,-(SP)
		pea	MTAG_Studio
		move.l	SP,a1
		bsr	SetMaestro		; setup
		add.l	#4*4,SP			; fix stack
	;-- add interrupt server
		lea	(mb_SIZEOF+MP_SIZE+MP_SIZE,a5),a1
		move.l	a1,(mb_IntServer,a5)
		lea	(.intname,PC),a0
		move.l	a0,(LN_NAME,a1)
		move.b	#NT_INTERRUPT,(LN_TYPE,a1)
		move.b	#125,(LN_PRI,a1)
		move.l	a5,(IS_DATA,a1)
		lea	(IntServer,PC),a0
		move.l	a0,(IS_CODE,a1)
		moveq	#13,d0
		exec	AddIntServer
	;-- done
.done		move.l	(maestrobase,PC),d0
.exit		movem.l	(sp)+,d1-d5/a0-a6
		rts
	;-- failed
.error2		move.l	(maestrobase,PC),a1	; release MaestroBase
		move.l	#mb_BLOCKSIZE,d0
		exec	FreeMem
		move.l	(maudiobase,PC),d0	; release card at macroaudio.library
		beq	.err_noma
		moveq	#1,d0
		move.l	maudiobase(PC),a6
		jsr	-162(a6)
.err_noma	clr.l	maestrobase
		move.l	(maestbase,PC),a0
		clr.l	(mab_AllocMstx,a0)
.error1		moveq	#0,d0			; return an error
		bra.b	.exit
.error1a	lea	(mbsemaphore,PC),a0
		exec	ReleaseSemaphore
		bra.b	.error1

	;-- default setup tag list
.tags		dc.l	MTAG_Input,INPUT_STD
		dc.l	MTAG_Output,OUTPUT_BYPASS
		dc.l	MTAG_CopyProh,CPROH_OFF
		dc.l	MTAG_Emphasis,EMPH_OFF
		dc.l	MTAG_Source,SRC_DAT
		dc.l	MTAG_Rate,RATE_48000
		dc.l	MTAG_Validity,-1
		dc.l	MTAG_ResetUDB,-1
		dc.l	TAG_DONE

.intname	dc.b	"maestix.interrupt",0
		even


**
* Release the Maestro card.
*
* 	-> A0.l	^MaestroBase to be freed
*
		public	FreeMaestro
FreeMaestro	movem.l	d0-d3/a0-a6,-(sp)
		move.l	a0,a5
	;-- lock hardware
		bsr	Lock
	;-- reset card
		tst.b	(mb_AllocOnly,a5)	; should only be allocated?
		bne	.skipreset		; then skip reset
		move.l	(mb_HardBase,a5),a0
		move	#0,(mh_modus,a0)
		clr	(mb_ModusReg,a5)
		clr.l	(mb_CSB,a5)
		clr.l	(mb_UDB,a5)
		sf	(mb_UseUDB,a5)
		add.l	#mh_sleep,a0		; put card to sleep
		move	(a0),d0
	;-- stop interrupt servers
		move.l	(mb_IntServer,a5),a1
		moveq	#13,d0
		exec	RemIntServer
	;-- reply current messages
.skipreset	move.l	(mb_CurrTMsg,a5),d0	; current transmit messages
		beq	.notpend
		move.l	d0,a1
		exec	ReplyMsg
		clr.l	(mb_CurrTMsg,a5)
.notpend	move.l	(mb_CurrRMsg,a5),d0	; current receive messages
		beq	.tloop
		move.l	d0,a1
		exec	ReplyMsg
		clr.l	(mb_CurrRMsg,a5)
	;-- reply all pending messages
.tloop		move.l	(mb_TPort,a5),a0	; all transmit messages
		exec	GetMsg
		tst.l	d0
		beq	.rloop
		move.l	d0,a1
		exec	ReplyMsg
		bra	.tloop
.rloop		move.l	(mb_RPort,a5),a0	; all receive messages
		exec	GetMsg
		tst.l	d0
		beq	.freedone
		move.l	d0,a1
		exec	ReplyMsg
		bra	.rloop
	;-- release MaestroBase
.freedone	move.l	a5,a1
		move.l	#mb_BLOCKSIZE,d0
		exec	FreeMem
		move.l	(maudiobase,PC),d0	; release card from macroaudio.library
		beq	.noma
		moveq	#1,d0
		move.l	maudiobase(PC),a6
		jsr	-162(a6)
.noma		clr.l	maestrobase
		move.l	(maestbase,PC),a0
		clr.l	(mab_AllocMstx,a0)
		movem.l	(sp)+,d0-d3/a0-a6
		rts


**
* Set the MaestroPro modes.
*
*	-> A0.l	^MaestroBase
*	-> A1.l	^Tags
*
* Tags:
*	MTAG_Input	Selected Input
*	MTAG_Output	Selected Output
*	MTAG_SetCSB	Channel Status Bits
*	MTAG_SetUDB	User Data Bits
*	MTAG_Studio	Studio Mode
*	MTAG_CopyProh	Copy Protection Flag
*	MTAG_Emphasis	Emphasis
*	MTAG_Source	Signal Source Type
*	MTAG_Rate	Output Rate
*	MTAG_Validity	Validity Flag
*	MTAG_ResetUDB	Reset UDBs
*	MTAG_ResetLSA	Reset Local Sample Address
*
		public	SetMaestro
SetMaestro	movem.l	d0-d7/a0-a6,-(sp)
	;-- preparations
		sf	d5			; D5 is true for long delays
		move.l	a0,a5			; A5 ^MaestroBase
		move.l	(mb_HardBase,a5),a4	; A4 ^Hardware Base
		IFD	_MAKE_68020
		 tst.l	a1
		ELSE
		 move.l	a1,d7
		ENDC
		bne	.gottags
		lea	(.emptytag,PC),a1	; no tags? use empty tag list
.gottags	move.l	a1,d7			; d7 ^Tags
	;-- lock hardware
		bsr	Lock
	;-- select input
		move.l	#MTAG_Input,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.noinput
		move.l	d0,a0
		move.l	(4,a0),d0
		move.l	(mb_OldInput,a5),d1
		move.l	d1,(mb_OldInput,a5)
		cmp.l	d1,d0
		beq	.inp_equal
		st	d5
.inp_equal	bsr	SelectInput
	;-- compute Channel Status Bits
.noinput	move.l	(mb_CSB,a5),d6
		move.l	#MTAG_Studio,d0		; studio mode enabled?
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.nostudio
		move.l	d0,a0
		tst.l	(4,a0)
		beq	.std_off
	;---- studio mode on
		move.l	#$02a5,d6		; 48kHz, no emphasis
		bra	.nostudio
	;---- studio mode is off
.std_off	move.l	#$02000304,d6		; 48kHz DAT, no emphasis
	;---- immediate CSBs?
.nostudio	move.l	#MTAG_SetCSB,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.nocsb
		move.l	(4,a0),d6		; yes, use them instead
	;---- change source type
.nocsb		move.l	#MTAG_Source,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.nosource
		move.l	(4,a0),d0
		bsr	ChangeSource
	;---- copy protection flag
.nosource	move.l	#MTAG_CopyProh,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.noproh
		move.l	(4,a0),d0
		bsr	ChangeProh
	;---- emphasis
.noproh		move.l	#MTAG_Emphasis,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.noemph
		move.l	(4,a0),d0
		bsr	ChangeEmph
	;---- bit rate
.noemph		move.l	#MTAG_Rate,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.norate
		move.l	(4,a0),d0
		bsr	ChangeRate
	;---- set computed Channel Status Bits
.norate		cmp.l	(mb_CSB,a5),d6		; have they changed?
		beq	.nocsbset		; no: do not set hardware
		move.l	d6,d0
		move.l	d0,(mb_CSB,a5)		; remember new CSB
		moveq	#32,d1
		moveq	#%00,d2			; type is CSB
		bsr	ShiftReg		; set hardware shift register
	;-- set User Defined Bits
.nocsbset	move.l	#MTAG_SetUDB,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.noudbset
		move.l	d0,a0
		move.l	(4,a0),d0
		and.l	#$3FFFFFFF,d0		; mask bits
		or.l	#$40000000,d0		; mark as UDB
		move.l	d0,(mb_UDB,a5)		; set them
		st	(mb_UseUDB,a5)		; mark UDB as effective
		moveq	#32,d1
		moveq	#%01,d2			; type is UDB
		bsr	ShiftReg		; set hardware shift registers
		moveq	#%0001,d0
		moveq	#4,d1
		moveq	#%10,d2
		bsr	ShiftReg		; and enable UDB usage
	;-- clear User Defined Bits
.noudbset	move.l	#MTAG_ResetUDB,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.noudb
		sf	(mb_UseUDB,a5)		; mark UDB as ineffective
		moveq	#%0000,d0
		moveq	#4,d1
		moveq	#%10,d2
		bsr	ShiftReg		; disable UDB usage
	;-- set validity flag
.noudb		move.l	#MTAG_Validity,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.novlf
		move.l	d0,a0
		tst.l	(4,a0)
		beq	.notvalid
	;---- data is valid
		and	#~MAMF_EVFL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		bra	.novlf
	;---- data is invalid
.notvalid	or	#MAMF_EVFL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- set output
.novlf		move.l	#MTAG_Output,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.nooutput
		move.l	d0,a0
		move.l	(4,a0),d0
		move.l	(mb_OldOutput,a5),d1
		move.l	d1,(mb_OldOutput,a5)
		cmp.l	#OUTPUT_INPUT,d1	; find out if we need a delay
		beq	.test_nowfifo
		cmp.l	#OUTPUT_FIFO,d1
		beq	.test_nowinput
		bra	.comp
.test_nowfifo	cmp.l	#OUTPUT_FIFO,d0
		beq	.out_equal
		bra	.comp
.test_nowinput	cmp.l	#OUTPUT_INPUT,d0
		beq	.out_equal
.comp		cmp.l	d1,d0
		beq	.out_equal
		st	d5
.out_equal	bsr	SelectOutput
	;-- reset Local Sample Address
.nooutput	move.l	#MTAG_ResetLSA,d0
		move.l	d7,a0
		utils	FindTagItem
		tst.l	d0
		beq	.nolsa
		or	#MAMF_ECNTR,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		moveq	#100,d0
		bsr	TimerDelay
		and	#~MAMF_ECNTR,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- input change delay (if necessary)
.nolsa		tst.b	d5
		beq	.done
		move.l	(maestbase,PC),a0
		move.l	(mab_Delay,a0),D0	; get source change delay
		beq	.done			; 0 -> turned off
		IFD	_MAKE_68020
		 mulu.l	#1000,d0		; ms * 1000 = us
		ELSE
		 mulu	#1000,d0
		ENDC
		bsr	TimerDelay
	;-- release hardware
.done		bsr	Release
	;-- done
		movem.l	(SP)+,d0-d7/a0-a6
		rts

	;-- empty tag list
.emptytag	dc.l	TAG_DONE


**
* Get card status.
*
*	-> A0.l	^MaestroBase
*	-> D0.l Desired MSTAT_ type
*	<- D0.l	Current status of that type
*
		public	GetStatus
GetStatus	movem.l	d1-d2/a4-a6,-(sp)
		move.l	a0,a5			; A5 ^MaestroBase
		move.l	(mb_HardBase,a5),a4	; A4 ^Hardware
	;-- lock hardware
		bsr	Lock
	;-- transmit FIFO status?
		cmp.l	#MSTAT_TFIFO,d0
		bne	.notfifo
		tst.b	(mb_TError,a5)
		beq	.noterror
		moveq	#FIFO_Error,d0
		sf	(mb_TError,a5)
		bra	.done
.noterror	moveq	#FIFO_Off,d0
		move	(mb_ModusReg,a5),d1
		btst	#MAMB_TFENA,d1
		beq	.done
		moveq	#FIFO_Running,d0
		bra	.done
	;-- receive FIFO status?
.notfifo	cmp.l	#MSTAT_RFIFO,d0
		bne	.norfifo
		tst.b	(mb_RError,a5)
		beq	.norerror
		moveq	#FIFO_Error,d0
		sf	(mb_RError,a5)
		bra	.done
.norerror	moveq	#FIFO_Off,d0
		move	(mb_ModusReg,a5),d1
		btst	#MAMB_RFENA,d1
		beq	.done
		moveq	#FIFO_Running,d0
		bra	.done
	;-- input has a signal?
.norfifo	cmp.l	#MSTAT_Signal,d0
		bne	.nosignal
		move	(mb_ModusReg,a5),d0	; internal or external source?
		btst	#MAMB_DKMODE,d0
		beq	.isok
		move	(mh_status,a4),d0	; external signal present?
		btst	#MASB_DERR,d0
		seq	d0
		bra	.booldone
.isok		st	d0			; internal source always has signal
		bra	.booldone
	;-- emphasis?
.nosignal	cmp.l	#MSTAT_Emphasis,d0
		bne	.noemph
		move	(mb_ModusReg,a5),d0	; internal or external source?
		btst	#MAMB_DKMODE,d0
		beq	.emph_off
		move	(mh_status,a4),d0	; external signal present?
		btst	#MASB_DERR,d0		; external source signal is present
		bne	.emph_off		;   otherwise emphasis is off
		btst	#MASB_DDEP,d0		; external source has emphasis bit set?
		sne	d0
		bra	.booldone
.emph_off	sf	d0			; internal source never has emphasis
		bra	.booldone
	;-- DAT source?
.noemph		cmp.l	#MSTAT_DATsrc,d0
		bne	.nodatsrc
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_DKMODE,d0		; internal or external source?
		beq	.dat_on
		move	(mh_status,a4),d0	; external signal present?
		btst	#MASB_DERR,d0		; signal is present
		bne	.dat_on			;   no: DAT is on
		and	#~MAMF_DSEL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		move	(mh_status,a4),d0	; check external source bit
		btst	#MASB_DS2,d0
		sne	d0
		bra	.booldone
.dat_on		st	d0			; internal source is always DAT
		bra	.booldone
	;-- copy prohibited?
.nodatsrc	cmp.l	#MSTAT_CopyProh,d0
		bne	.nocproh
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_DKMODE,d0		; internal or external source?
		beq	.cproh_off
		move	(mh_status,a4),d0
		btst	#MASB_DERR,d0		; external signal present?
		bne	.cproh_off		;   no: copy protection is off
		and	#~MAMF_DSEL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		move	(mh_status,a4),d0	; check external status bit
		btst	#MASB_DS1,d0
		seq	d0
		bra	.booldone
.cproh_off	sf	d0			; internal source has no protection
		bra	.booldone
	;-- bit rate?
.nocproh	cmp.l	#MSTAT_Rate,d0
		bne	.norate
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_DKMODE,d0		; internal or external source?
		beq	.rate_int
		move	(mh_status,a4),d0
		btst	#MASB_DERR,d0		; external signal present?
		bne	.rate_int		;   no: always 48kHz rate
		or	#MAMF_DSEL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		move	(mh_status,a4),d0
		lea	(.ratetab,PC),a6
		IFD	_MAKE_68020
		 bfextu	d0{19:2},d0
		 move.l	(a6,d0.l*4),d0
		ELSE
		 and	#$1800,d0
		 rol	#7,d0
		 move.l	(a6,d0.w),d0
		ENDC
		bra	.done
.rate_int	move.l	#48000,d0		; internal is always 48kHz
		bra	.done
	;-- user defined bits?
.norate		cmp.l	#MSTAT_UDB,d0
		bne	.noudb
		bsr	GetUDB
		bra	.done
	;-- unknown query type
.noudb		moveq	#0,d0
		bra	.done
	;-- extend boolean results
.booldone	IFD	_MAKE_68020
		 extb.l	d0			; extend bool byte to long
		ELSE
		 ext	d0
		 ext.l	d0
		ENDC
	;-- release hardware
.done		bsr	Release
		movem.l	(SP)+,d1-d2/a4-a6
		rts

	;-- table of bit rates
.ratetab	dc.l	44100,44100,48000,32000


**
* Change source category.
*
* This function takes studio mode into account, and can handle
* the case that no input signal is present.
*
*	-> D0.l	new source category
*	-> D6.l	CSBs
*	-> A5.l	^MaestroBase
*	<- D6.l new CSBs
*
ChangeSource	movem.l	a0/d0-d1,-(sp)
		move.l	(mb_HardBase,a5),a0
		btst	#0,d6			; studio mode?
		bne	.done			;   isn't used there
	;-- same as input?
		cmp.l	#SRC_INPUT,d0
		bne	.notinp
		move	(mb_ModusReg,a5),d1
		btst	#MAMB_DKMODE,d1		; fixed 48kHz source?
		beq	.setdat			;   then set DAT
		move	(mh_status,a0),d1
		btst	#MASB_DERR,d1		; input has a signal?
		bne	.setdat			;   if not, set DAT
		and	#~MAMF_DSEL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
		move	(mh_status,a0),d1	; fetch status
		move.l	#SRC_CD,d0		; use CD source
		btst	#MASB_DS2,d1
		beq	.notinp
.setdat		move.l	#SRC_DAT,d0		; use DAT source
	;-- set other bits directly
.notinp		IFD	_MAKE_68020
		 bfins	d0,d6{17:7}
		ELSE
		 and.l	#$7F,d0
		 and.l	#~$7F00,d6
		 lsl.l	#8,d0
		 or.l	d0,d6
		ENDC
	;-- done
.done		movem.l	(sp)+,a0/d0-d1
		rts


**
* Change Copy Prohibited flag
*
* Takes studio mode and no signal on input into account.
* Category must be correct.
*
*	-> D0.l	new prohibit code
*	-> D6.l	CSBs
*	-> A5.l	^MaestroBase
*	<- D6.l	new CSBs
*
ChangeProh	movem.l	d0/a0,-(sp)
		move.l	(mb_HardBase,a5),a0
		btst	#0,d6			; Studio mode?
		bne	.done			;   then ignore it
	;-- as input?
		cmp.l	#CPROH_INPUT,d0
		bne	.notinp
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_DKMODE,d0		; fixed 48kHz source?
		beq	.inpoff			;   then turn off
		move	(mh_status,a0),d0
		btst	#MASB_DERR,d0		; input has signal?
		bne	.inpoff			;   no: turn off
		and	#~MAMF_DSEL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
		move	(mh_status,a0),d0	; fetch status
		btst	#MASB_DS1,d0		; copy permitted?
		bne	.inpoff
		bra	.inpon
	;-- turn copy prohibition off?
.notinp		cmp.l	#CPROH_OFF,d0
		bne	.notoff
.inpoff		bset	#2,d6
		bra	.done
	;-- turn passive copy prohibition on?
.notoff		cmp.l	#CPROH_ON,d0
		bne	.noton
.inpon		bclr	#2,d6
		bset	#15,d6
		bra	.checkdone
	;-- turn active copy prohibition on?
.noton		cmp.l	#CPROH_PROHIBIT,d0
		bne	.done
		bclr	#2,d6
		bclr	#15,d6
	;-- check for CD, DSR
.checkdone	move.l	d6,d0
		and.l	#$7F00,d0
		cmp.l	#$0100,d0		; CD source?
		beq	.iscd
		cmp.l	#$0C00,d0		; DSR source?
		bne	.done
.iscd		bchg	#15,d6			; if so, change bit 15
	;-- done
.done		movem.l	(sp)+,d0/a0
		rts


**
* Change Emphasis flag
*
* Takes studio mode and no signal on input into account.
* Category must be correct.
*
*	-> D0.l	new prohibit code
*	-> D6.l	CSBs
*	-> A5.l	^MaestroBase
*	<- D6.l	new CSBs
*
ChangeEmph	movem.l	d0-d1/a0,-(sp)
		move.l	(mb_HardBase,a5),a0
	;-- same as input?
		cmp.l	#EMPH_INPUT,d0
		bne	.noinput
		move	(mb_ModusReg,a5),d1
		btst	#MAMB_DKMODE,d1		; fixed 48kHz source?
		beq	.inp_off		;   then turn off
		move	(mh_status,a0),d1
		btst	#MASB_DERR,d1		; input has signal?
		bne	.inp_off		;   no: turn off
		btst	#MASB_DDEP,d1		; use input flag
		beq	.inp_off
		bra	.inp_on
	;-- turn off emphasis?
.noinput	cmp.l	#EMPH_OFF,d0
		bne	.nooff
.inp_off	btst	#0,d6			; studio mode?
		beq	.off_custom
		and.l	#~$001c,d6		;   studio emphasis flag
		or.l	#$0004,d6
		bra	.done
.off_custom	and.l	#~$0038,d6		;   custom emphasis flag
		bra	.done
	;-- 50us emphasis?
.nooff		cmp.l	#EMPH_50us,d0
		bne	.no50us
.inp_on		btst	#0,d6			; studio mode?
		beq	.us50_custom
		and.l	#~$001c,d6		;   studio 50us flag
		or.l	#$000c,d6
		bra	.done
.us50_custom	and.l	#~$0038,d6		;   custom 50us flag
		or.l	#$0008,d6
		bra	.done
	;-- CCITT J.17 emphasis?
.no50us		cmp.l	#EMPH_CCITT,d0
		bne	.noccitt
		btst	#0,d6			; only available in studio mode!
		beq	.done
		or.l	#$001c,d6
		bra	.done
	;-- manual emphasis?
.noccitt	cmp.l	#EMPH_MANUAL,d0
		bne	.done
		btst	#0,d6			; only available in studio mode!
		beq	.done
		and.l	#~$001c,d6
	;-- done
.done		movem.l	(sp)+,d0-d1/a0
		rts


**
* Change bit rate.
*
* Takes studio mode and no signal on input into account.
* Category must be correct.
*
*	-> D0.l	new prohibit code
*	-> D6.l	CSBs
*	-> A5.l	^MaestroBase
*	<- D6.l	new CSBs
*
ChangeRate	movem.l	d0-d1/a0,-(sp)
		move.l	(mb_HardBase,a5),a0
	;-- same as input?
		cmp.l	#RATE_INPUT,d0
		bne	.noinput
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_DKMODE,d0		; fixed 48kHz source?
		beq	.set48k			;   then it's 48kHz
		move	(mh_status,a0),d0
		btst	#MASB_DERR,d0		; input has signal?
		bne	.set48k			;   no: 48kHz
		or	#MAMF_DSEL,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
		move	(mh_status,a0),d0	; fetch status
		lea	(.input_tab,PC),a0
		IFD	_MAKE_68020
		 bfextu	d0{19:2},d0
		 move.l	(a0,d0.l*4),d0
		ELSE
		 and	#$1800,d0
		 rol	#7,d0
		 move.l	(a0,d0.w),d0
		ENDC
		bra	.noinput
.set48k		moveq	#RATE_48000,d0		; 48kHz rate
	;-- set rate
.noinput	cmp.l	#RATE_48000MANU,d0	; ignore invalid values
		bhi	.done
		IFND	_MAKE_68020
		 add.l	d0,d0
		 add.l	d0,d0
		ENDC
		btst	#0,d6			; studio or custom mode?
		beq	.rate_custom
	;---- set studio bitrate
		lea	(.studio_tab,PC),a0
		IFD	_MAKE_68020
		 move.b	(a0,d0.l),d0
		 bfins	d0,d6{24:3}
		ELSE
		 and.l	#~$00C0,d6
		 or.l	(a0,d0.l),d6
		ENDC
		bra	.done
	;---- set custom bitrate
.rate_custom	lea	(.custom_tab,PC),a0
		IFD	_MAKE_68020
		 move.b	(a0,d0.l),d0
		 bfins	d0,d6{4:4}
		ELSE
		 and.l	#~$0F000000,d6
		 or.l	(a0,d0.l),d6
		ENDC
	;-- done
.done		movem.l	(sp)+,d0-d1/a0
		rts

	;-- rate and bitmap tables
.input_tab	dc.l	RATE_44100,RATE_44100,RATE_48000,RATE_32000

		IFD	_MAKE_68020
.studio_tab	 dc.b	$7,$2,$4,$0
.custom_tab	 dc.b	$3,$0,$2,$2
		ELSE
.studio_tab	 dc.l	$000000C0,$00000040,$00000080,$00000000
.custom_tab	 dc.l	$03000000,$00000000,$02000000,$02000000
		ENDC


**
* Select an input.
*
*	-> D0.l	Input type (INPUT_...)
*	-> A5.l	^MaestroBase
*
SelectInput	movem.l	d0/a4-a5,-(sp)
		move.l	(mb_HardBase,a5),a4
	;-- standard input?
		cmp.l	#INPUT_STD,d0
		bne	.nostd
		moveq	#INPUT_OPTICAL,d0
		move.l	(maestbase,PC),a0
		tst.b	(mab_DefInput,a0)	; as set in mab_DefInput
		beq	.nostd
		moveq	#INPUT_COAXIAL,d0
	;-- fixed 48kHz source?
.nostd		cmp.l	#INPUT_SRC48K,d0
		bne	.no48k
		and	#~MAMF_DKMODE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		bra	.done
	;-- optical input?
.no48k		cmp.l	#INPUT_OPTICAL,d0
		bne	.noopt
		and	#~MAMF_INPUT,(mb_ModusReg,a5)
		or	#MAMF_DKMODE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		bra	.done
	;-- coaxial input?
.noopt		cmp.l	#INPUT_COAXIAL,d0
		bne	.done
		or	#MAMF_INPUT|MAMF_DKMODE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- done
.done		movem.l	(sp)+,d0/a4-a5
		rts


**
* Select an output.
*
*	-> D0.l	Input type (OUTPUT_...)
*	-> A5.l	^MaestroBase
*
SelectOutput	movem.l	d0/a4-a5,-(sp)
		move.l	(mb_HardBase,a5),a4
	;-- bypass?
		cmp.l	#OUTPUT_BYPASS,d0
		bne	.nobypass
		and	#~MAMF_BYPASS,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		bra	.done
	;-- input?
.nobypass	cmp.l	#OUTPUT_INPUT,d0
		bne	.noinput
		or	#MAMF_BYPASS,(mb_ModusReg,a5)
		and	#~(MAMF_OUTPUT|MAMF_EMUTE),(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		;; TODO:
		; Synchronization issues may occur here.
		; Workaround: set ERSTN=0 before change.
		; After change, set ERSTN=1, and re-set CSBs and UDBs.
		;
		bra	.done
	;-- FIFO?
.noinput	cmp.l	#OUTPUT_FIFO,d0
		bne	.done
		move	#MAMF_BYPASS|MAMF_OUTPUT,d0
		move	(mb_ModusReg,a5),d1
		btst	#MAMB_TFENA,d1
		bne	.nomute
		or	#MAMF_EMUTE,d0
.nomute		or	d0,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		;; TODO:
		; Synchronization issues may occur here.
		; Workaround: set ERSTN=0 before change.
		; After change, set ERSTN=1, and re-set CSBs and UDBs.
		;
	;-- done
.done		movem.l	(sp)+,d0/a4-a5
		rts


**
* Set the shift register.
*
*	-> D0.l	Value to be set
*	-> D1.w	Number of bits (1..32)
*	-> D2.w	Data type (2 bit)
*	-> A5.l	^MaestroBase
*
ShiftReg	movem.l	d0/d5-d7/a0,-(sp)
		move.l	(mb_HardBase,a5),a0
		move.l	d0,d6
		move	d1,d7
	;-- select shift register
		and	#~(MAMF_ECLD|MAMF_ECLK),(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
		move.l	#5000,d0		; 5ms
		bsr	TimerDelay
	;-- shift in the value
		bsr	.doloop
	;-- shift in the type
		move.l	d2,d6
		moveq	#2,d7
		bsr	.doloop
		move.l	#5000,d0		; 5ms
		bsr	TimerDelay
	;-- deselect shift register
		and	#~(MAMF_ECLK|MAMF_ECIN),(mb_ModusReg,a5)
		or	#MAMF_ECLD,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
	;-- done
		movem.l	(SP)+,d0/d5-d7/a0
		rts

	;-- write data
	; D6.l = value, D7.w = number of bits
.setloop	ror.l	#1,d6
		bcc	.clear
	;---- set bit
		or	#MAMF_ECIN|MAMF_ECLK,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
		bra	.bitset
	;---- clear bit
.clear		and	#~MAMF_ECIN,(mb_ModusReg,a5)
		or	#MAMF_ECLK,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
	;---- clock pulse
.bitset		move.l	#1000,d0		; 1ms
		bsr	TimerDelay
		and	#~MAMF_ECLK,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a0)
.doloop		move.l	#1000,d0		; 1ms
		bsr	TimerDelay
		dbra	d7,.setloop
		rts


**
* Get User Data Bits.
*
*	-> A5.l	^MaestroBase
*	<- D0.l Current UDB content (UBYTE)
*
GetUDB		movem.l	a4-a5,-(sp)
		move.l	(mb_HardBase,a5),a4
		exec	Forbid			;; TODO: Timeout!
	;-- wait for sync edge
.waitl		move	(mh_status,a4),d0
		btst	#MASB_DSSYNC,d0		; wait for falling edge
		bne	.waitl
.waith		move	(mh_status,a4),d0	; wait for rising edge
		btst	#MASB_DSSYNC,d0
		beq	.waith
	;-- read UDB
		move	(mh_rudb,a4),d0
		IFD	_MAKE_68020
		 bfextu	d0{24:8},d0
		ELSE
		 and.l	#$000000ff,d0
		ENDC
		exec	Permit
	;-- done
		movem.l	(sp)+,a4-a5
		rts


**
* Lock the hardware. The current thread will gain exclusive access to the
* MaestroPro hardware and the delay timer.
*
*	-> A5.l	^MaestroBase
*
		public	Lock
Lock		movem.l	a0/a6,-(SP)
		lea	(mb_Semaphore,a5),a0
		exec	ObtainSemaphore
		movem.l (SP)+,a0/a6
		rts

**
* Release the hardware lock.
*
*	-> A5.l	^MaestroBase
*
		public	Release
Release		movem.l	a0/a6,-(SP)
		lea	(mb_Semaphore,a5),a0
		exec	ReleaseSemaphore
		movem.l (SP)+,a0/a6
		rts


**
* Wait for a while.
*
* Uses timer.device for the delay.
*
*	-> D0.l	Delay (microseconds)
*
		public	TimerDelay
TimerDelay	movem.l	d0-d1/a0-a1/a6,-(SP)
		move.l	d0,d2
		beq	.done
		moveq	#0,d1
		move.l	#UNIT_MICROHZ,d0
		jsr	TimeDelay		; amiga.lib
.done		movem.l	(SP)+,d0-d1/a0-a1/a6
		rts

	;; TODO: Why do we keep it? It is also provided by the client.
		public	maestrobase
maestrobase	dc.l	0
