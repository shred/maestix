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

**
** This demonstration shows the basic functions of the maestix
** library. It allocates the Maestro soundcard, select the default
** input and shows wether there is a signal, and if so,	it analyzes
** the rate, source and emphasis bits.
**

		INCLUDE	libraries/maestix.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/dos.i
		INCLUDE	lvo/maestix.i

		SECTION	text,CODE

start	;-- open all libraries
		lea	maestname(PC),a1
		moveq	#35,d0
		exec	OpenLibrary
		move.l	d0,maestbase
		beq	error1
		lea	dosname(PC),a1
		moveq	#0,d0
		exec	OpenLibrary
		move.l	d0,dosbase
		beq	error2
	;-- open stdout
		dos	Output
		move.l	d0,stdout
		beq	error3
	;-- allocate maestro
		sub.l	a0,a0			; no tags
		maest	AllocMaestro
		move.l	d0,maestro		; ^maestrobase
		beq	error3
		lea	msg_allocated(PC),a0
		bsr	print
	;-- set mode
		move.l	maestro(PC),a0		; ^Maestro base
		lea	modustags(PC),a1	 ;^Modus tags
		maest	SetMaestro
		lea	msg_modusset(PC),a0
		bsr	print
	;-- read signal status
		move.l	maestro(PC),a0
		moveq	#MSTAT_Signal,d0	; check input signal
		maest	GetStatus
		tst.l	d0
		bne.b	.foundsig		; no signal on input?
		lea	msg_nosignal(PC),a0	; then print an error
		bsr	print
		bra	exit			; and leave
	;-- read input status
.foundsig	lea	msg_sigfound(PC),a0	; confirm that we have a signal
		bsr	print
	;---- check emphasis
		move.l	maestro(PC),a0
		moveq	#MSTAT_Emphasis,d0
		maest	GetStatus		; input signal uses emphasis?
		tst.l	d0
		bne.b	.emphused
		lea	msg_no(PC),a0		;   "no"...
		bsr	print
.emphused	lea	msg_emphasis(PC),a0	;   "emphasis"
		bsr	print
	;---- check copy prohibition
		move.l	maestro(PC),a0
		moveq	#MSTAT_CopyProh,d0	; input signal is copy prohibited?
		maest	GetStatus
		tst.l	d0
		bne.b	.prohibit
		lea	msg_no(PC),a0		;   "no"...
		bsr	print
.prohibit	lea	msg_prohibit(PC),a0	;   "copy prohibition"
		bsr	print
	;---- check DAT source
		move.l	maestro(PC),a0
		moveq	#MSTAT_DATsrc,d0	; input signal is from DAT?
		maest	GetStatus
		tst.l	d0
		bne.b	.datsrc
		lea	msg_no(PC),a0		;   "no"...
		bsr	print
.datsrc		lea	msg_datsource(PC),a0	;   "DAT source"
		bsr	print
	;---- check sampling rate
		move.l	maestro(PC),a0
		moveq	#MSTAT_Rate,d0		; sampling rate?
		maest	GetStatus
		cmp.l	#44100,d0		;   44.1 kHz?
		bne.b	.not441
		lea	msg_44100hz(PC),a0
		bsr	print
		bra	exit
.not441		cmp.l	#48000,d0		;   48kHz?
		bne.b	.is32
		lea	msg_48000hz(PC),a0
		bsr	print
		bra	exit
.is32		lea	msg_32000hz(PC),a0	;   otherwise it's 32kHz
		bsr	print
	;-- exit
exit		move.l	maestro(PC),a0		; Release MaestroPro board
		maest	FreeMaestro
		lea	msg_freed(PC),a0
		bsr	print
error3		move.l	dosbase(PC),a1
		exec	CloseLibrary
error2		move.l	maestbase(PC),a1
		exec	CloseLibrary
error1		moveq	#0,d0
		rts

	;-- tags
modustags	dc.l	MTAG_Input,INPUT_STD	; select user's standard input
		dc.l	MTAG_Output,OUTPUT_BYPASS ; bypass input signal to output
		dc.l	TAG_DONE

**
* Print a text to STDOUT.
*
*	-> A0.l	^text to print, 0 terminated
*
print		movem.l	d0-d3/a0-a3,-(sp)
		move.l	stdout(PC),d1		; use STDOUT
		move.l	a0,d2
		moveq	#-1,d3			; get string length
.scanend	addq.l	#1,d3
		tst.b	(a0)+
		bne.b	.scanend
		dos	Write			; print
		movem.l	(sp)+,d0-d3/a0-a3
		rts


maestbase	dc.l		0		; ^Maestix Lib Base
dosbase		dc.l		0		; ^Dos Lib Base
stdout		dc.l		0		; ^Output FH
maestro		dc.l		0		; ^Maestro Base

msg_allocated	dc.b		"** allocated maestro",$a,0
msg_modusset	dc.b		"** set modus",$a,$a,0
msg_nosignal	dc.b		"No signal on standard input",$a,0
msg_sigfound	dc.b		"Signal found on standard input",$a,$a,0
msg_no		dc.b		"no ",0
msg_emphasis	dc.b		"emphasis",$a,0
msg_prohibit	dc.b		"copy prohibition",$a,0
msg_datsource	dc.b		"DAT source",$a,0
msg_44100hz	dc.b		"rate: 44100 Hz",$a,0
msg_48000hz	dc.b		"rate: 48000 Hz",$a,0
msg_32000hz	dc.b		"rate: 32000 Hz",$a,0
msg_freed	dc.b		$a,"** freed maestro",$a,0

maestname	dc.b		"maestix.library",0
dosname		dc.b		"dos.library",0
		even
