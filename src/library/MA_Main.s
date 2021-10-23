*
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
*

		INCLUDE	exec/initializers.i
		INCLUDE	exec/libraries.i
		INCLUDE	exec/lists.i
		INCLUDE	exec/resident.i
		INCLUDE	exec/semaphores.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/expansion.i

		INCLUDE	maestixpriv.i

		IFD	_MAKE_68020
		 MACHINE 68020
		ENDC

		SECTION	text,CODE

DEF_DELAY	EQU	100		; Default Setup Delay (ms)

VERSION		EQU	42		;<- Version
REVISION	EQU	0		;<- Revision

SETVER		MACRO			;<- Version String Macro
		dc.b	"42.00"
		ENDM

SETDATE		MACRO			;<- Date String MACRO
		dc.b	"23.10.2021"
		ENDM

**
** NOTE: THIS PART MUST BE THE START OF THE LIBRARY. DO NOT CHANGE THE ORDER.
**

**
* Start, avoid invocation from CLI.
*
Start		moveq	#0,d0
		rts


**
* Describe library
*
InitDDescrip	dc.w	RTC_MATCHWORD
		dc.l	InitDDescrip
		dc.l	EndCode
		dc.b	RTF_AUTOINIT,VERSION,NT_LIBRARY,0
		dc.l	libname,libidstring,Init
libname		dc.b	"maestix.library",0
libidstring	dc.b	"maestix.library "
		SETVER
		dc.b	" ("
		SETDATE
		dc.b	")"
		IFD	_MAKE_68020
		dc.b	" 68020+"
		ENDC
		dc.b	13,10,0

**
* Copyright note for hex reader
*
		dc.b	"(C) 1995-2021 Richard 'Shred' K\xF6rber ",$a
		dc.b	"License: GNU Lesser General Public License v3 ",$a
		dc.b	"Source: https://maestix.shredzone.org",0
		even
		cnop	0,4


**
* Init table
*
Init		dc.l	mab_SIZEOF,FuncTab,DataTab,InitFct


**
* Function table. Keep this order, only append!
*
FuncTab		dc.l	Open,Close,Expunge,Null	; Standard functions
		dc.l	AllocMaestro		; -30
		dc.l	FreeMaestro		; -36
		dc.l	SetMaestro		; -42
		dc.l	GetStatus		; -48
		dc.l	TransmitData		; -54
		dc.l	ReceiveData		; -60
		dc.l	FlushTransmit		; -66
		dc.l	FlushReceive		; -72
		dc.l	StartRealtime		; -78
		dc.l	StopRealtime		; -84
		dc.l	UpdateRealtime		; -90
		dc.l	Null			; -96
		dc.l	ReadPostLevel		; -102
		dc.l	-1


**
* Data table
*
DataTab		INITBYTE LN_TYPE,NT_LIBRARY
		INITLONG LN_NAME,libname
		INITBYTE LIB_FLAGS,LIBF_SUMUSED|LIBF_CHANGED
		INITWORD LIB_VERSION,VERSION
		INITWORD LIB_REVISION,REVISION
		INITLONG LIB_IDSTRING,libidstring
		dc.l	0


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
		move.l	d0,maestbase
		move.l	a6,(mab_SysLib,a5)
		move.l	a6,execbase
		move.l	a0,(mab_SegList,a5)
	;-- set default parameters
		move.l	#DEF_DELAY,(mab_Delay,a5)
		sf	(mab_DefInput,a5)
		sf	(mab_DefStudio,a5)
	;-- initialize hardware access semaphore
		lea	(mbsemaphore,PC),a0
		exec	InitSemaphore
	;-- open libraries
		lea	(utilsname,PC),a1	; utility.library
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,utilsbase
		beq	.error1
		lea	(expname,PC),a1		; expansion.library
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,expbase
		beq	.error2
		lea	(dosname,PC),a1		; dos.library
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,dosbase
		beq	.error3
		lea	(maudioname,PC),a1	; macroaudio.library (optional)
		moveq	#0,d0
		exec	OpenLibrary
		move.l	d0,maudiobase
	;-- done
		move.l	a5,d0
.exit		movem.l	(sp)+,d1-d7/a0-a6
		rts
	;-- failed
.error4		move.l	(maudiobase,PC),d0
		beq	.err_noma
		move.l	d0,a1
		exec	CloseLibrary
.err_noma	move.l	(dosbase,PC),a1
		exec	CloseLibrary
.error3		move.l	(expbase,PC),a1
		exec	CloseLibrary
.error2		move.l	(utilsbase,PC),a1
		exec	CloseLibrary
.error1		moveq	#0,d0
		bra.b	.exit


**
* Open library
*
*	-> D0.l	Version
*	-> A6.l	^LibBase
*	<- D0.l	^LibBase if successful
*
Open		addq	#1,(LIB_OPENCNT,a6)		; count another instance
		bclr	#MALB_DELEXP,(mab_Flags+1,a6)	; do not expunge!
		move.l	a6,d0
		rts


**
* Close library
*
*	-> A6.l	^LibBase
*	<- D0.l	^SegList or 0
*
Close		moveq	#0,d0
		subq	#1,(LIB_OPENCNT,a6)		; decrement instance counter
		bne	.notlast
		btst	#MALB_DELEXP,(mab_Flags+1,a6)	; expunge?
		beq	.notlast
		bsr	Expunge				; yes, expunge!
.notlast	rts


**
* Expunge library
*
*	-> A6.l	^LibBase
*
Expunge		movem.l	d2/a5-a6,-(sp)
	;-- check state
		move.l	a6,a5
		move.l	(mab_SysLib,a5),a6
		tst.l	maestrobase		; hardware is still active?
		bne	.abort			; then abort expunge
		tst	(LIB_OPENCNT,a5)	; are we still opened somewhere?
		beq	.expimmed
.abort		bset	#MALB_DELEXP,(mab_Flags+1,a5)	; remember expunge
		moveq	#0,d0			; but do not expunge yet
		bra	.exit
	;-- close library
.expimmed	move.l	(mab_SegList,a5),d2	; remove seg list
		move.l	a5,a1
		exec	Remove
	;-- close own resources
		move.l	(maudiobase,PC),d0
		beq	.noma
		move.l	d0,a1
		exec	CloseLibrary
.noma		move.l	(dosbase,PC),a1
		exec	CloseLibrary
		move.l	(expbase,PC),a1
		exec	CloseLibrary
		move.l	(utilsbase,PC),a1
		exec	CloseLibrary
	;-- free memory
		moveq	#0,d0
		move.l	a5,a1
		move	(LIB_NEGSIZE,a5),d0
		sub.l	d0,a1
		add	(LIB_POSSIZE,a5),d0
		exec	FreeMem
	;-- done
		move.l	d2,d0
.exit		movem.l	(sp)+,d2/a5-a6
		rts

**
* Do nothing
*
Null		moveq	#0,d0
		rts


		public	execbase,utilsbase,maestbase,expbase,dosbase,maudiobase
		public	mbsemaphore

execbase	dc.l	0			; ^exec.library
utilsbase	dc.l	0			; ^utility.library
expbase		dc.l	0			; ^expansion.library
dosbase		dc.l	0			; ^dos.library
maestbase	dc.l	0			; ^maestix.library :)
maudiobase	dc.l	0			; ^macroaudio.library

mbsemaphore	ds.b	SS_SIZE,0		; hardware semaphore

utilsname	dc.b	"utility.library",0
expname		dc.b	"expansion.library",0
dosname		dc.b	"dos.library",0
maudioname	dc.b	"macroaudio.library",0
		even
