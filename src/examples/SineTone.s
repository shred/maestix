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
** This demonstration shows the basic transmit functions of
** the maestix library. It allocates the Maestro soundcard,
** prepares a sine wave buffer and outputs it with an 48 kHz
** sampling rate, resulting in a 1.5 kHz sine wave.
**

		INCLUDE	dos/dostags.i
		INCLUDE	exec/memory.i
		INCLUDE	exec/ports.i
		INCLUDE	intuition/intuition.i
		INCLUDE	libraries/maestix.i
		INCLUDE	lvo/dos.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/graphics.i
		INCLUDE	lvo/intuition.i
		INCLUDE	lvo/maestix.i

BUFSIZE		EQU	12*1024			; size of FIFO data block

		SECTION		text,CODE

start	;-- open all libraries
		lea	maestname(PC),a1	; maestix.library
		moveq	#35,d0			;   V35+
		exec	OpenLibrary
		move.l	d0,maestbase
		beq	error1
		lea	intuiname(PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,intuibase
		beq	error2
		lea	dosname(PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,dosbase
		beq	error3
	;-- allocate buffer memory
		move.l	#BUFSIZE*2,d0		; get two buffers
		moveq	#MEMF_PUBLIC,d1
		exec	AllocMem
		move.l	d0,buffer
		beq	error4
	;-- fill the buffer with sine wave
		lea	sintab(PC),a0		; ^Sine tab
		move.l	buffer(PC),a1		; ^Output puffer
		moveq	#0,d0			; sine tab index pointer
		move.l	#BUFSIZE*2/4,d1		; longword counter
.fillbuff	subq.l	#1,d1			; one longword less
		bcs.b	.filldone		; buffer is filled
		move	(a0,d0.w),(a1)+		; left channel
		move	(a0,d0.w),(a1)+		; right channel
		addq	#2,d0			; source index to next word
		and	#63,d0			; modulo 64
		bra.b	.fillbuff
	;-- allocate signal bit
.filldone	sub.l	a1,a1
		exec	FindTask
		move.l	d0,maintask
		moveq	#-1,d0
		exec	AllocSignal
		move.b	d0,donesigbit
		cmp.b	#-1,d0
		beq.w	error5
	;-- open a window
		sub.l	a0,a0
		lea	windowtags(PC),a1			; but loads of tags
		intui	OpenWindowTagList
		move.l	d0,window
		beq	error6
	;-- launch playback task
		move.l	#tasktags,d1
		dos	CreateNewProc
		tst.l	d0
		beq	error7
		moveq	#0,d0			; wait for task to start
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Wait
	;-- main loop
.mainloop	move.l	window(PC),a0
		move.l	wd_UserPort(a0),a0
		exec	WaitPort
.nextmsg	move.l	window(PC),a0
		move.l	wd_UserPort(a0),a0
		exec	GetMsg
		tst.l	d0
		beq.b	.mainloop
	;-- process window event
		move.l	d0,a0
		cmp.l	#IDCMP_CLOSEWINDOW,im_Class(a0)
		bne.b	.nextmsg
	;-- exit
exit		move.l	sinetask(PC),a1		; stop the sine tone task
		moveq	#0,d0
		move.b	sinesigbit(PC),d1
		bset	d1,d0
		exec	Signal			; send signal to exit
		moveq	#0,d0			; wait for sine tone task to stop
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Wait
		moveq	#20,d1
		dos	Delay
error7		move.l	window(PC),a0		; close window
		intui	CloseWindow
error6		move.b	donesigbit(PC),d0
		exec	FreeSignal
error5		move.l	buffer(PC),a1		; release buffers
		move.l	#BUFSIZE*2,d0
		exec	FreeMem
error4		move.l	dosbase(PC),a1
		exec	CloseLibrary
error3		move.l	intuibase(PC),a1
		exec	CloseLibrary
error2		move.l	maestbase(PC),a1
		exec	CloseLibrary
error1		moveq	#0,d0
		rts

**
* This process outputs a sine tone.
*
SineProc
	;-- exit task?
		sub.l	a1,a1
		exec	FindTask
		move.l	d0,sinetask
		moveq	#-1,d0
		exec	AllocSignal
		move.b	d0,sinesigbit
		cmp.b	#-1,d0
		beq	.error1
		move.l	maintask(PC),a1
		moveq	#0,d0
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Signal
	;-- allocate MaestroPro
		sub.l	a0,a0
		maest	AllocMaestro
		move.l	d0,maestro
		beq	.error2
	;-- set output mode
		move.l	maestro(PC),a0
		lea	modustags(PC),a1
		maest	SetMaestro
	;-- create transmit messageport
		exec	CreateMsgPort
		move.l	d0,tport
		beq	.error4
	;-- initialize messages
		move.l	tport(PC),d1
		lea	msg1(PC),a0
		lea	msg2(PC),a1
		move.l	buffer(PC),d0
		move.l	d0,(dmn_BufPtr,a0)
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a1)
		move.l	#BUFSIZE,(dmn_BufLen,a0)
		move.l	#BUFSIZE,(dmn_BufLen,a1)
		move.l	d1,(MN_REPLYPORT,a0)
		move.l	d1,(MN_REPLYPORT,a1)
		move	#dmn_SIZEOF,(MN_LENGTH,a0)
		move	#dmn_SIZEOF,(MN_LENGTH,a1)
	;-- start transmission
		move.l	maestro(PC),a0
		lea	msg1(PC),a1
		maest	TransmitData		; first buffer starts playback
		move.l	maestro(PC),a0
		lea	msg2(PC),a1
		maest	TransmitData		; second buffer added to queue
	;-- wait for messages
.mainloop	move.l	tport(PC),a0
		exec	GetMsg
		tst.l	d0
		bne.b	.gotmaestro
		moveq	#0,d0
		move.b	sinesigbit(PC),d1
		bset	d1,d0
		move.l	tport(PC),a0
		move.b	MP_SIGBIT(a0),d1
		bset	d1,d0
		exec	Wait
		move.b	sinesigbit(PC),d1
		btst	d1,d0
		beq.b	.mainloop
		bra.b	.exit
	;-- process event from Maestix
.gotmaestro	move.l	maestro(PC),a0		; just resend the message to the queue
		move.l	d0,a1			; for real playback, the buffer would
		maest	TransmitData		; be changed before that
		bra.b	.mainloop
	;-- leave task
.exit		move.l	maestro(PC),a0
		maest	FlushTransmit
		move.l	tport(PC),a0
		exec	DeleteMsgPort
.error4		move.b	sinesigbit(PC),d0
		exec	FreeSignal
.error3		move.l	maestro(PC),a0
		maest	FreeMaestro
.error2		move.l	maintask(PC),a1
		moveq	#0,d0
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Signal
.error1		rts


maintask	dc.l	0
sinetask	dc.l	0
sinesigbit	dc.b	0
donesigbit	dc.b	0
		even
maestbase	dc.l	0
intuibase	dc.l	0
dosbase		dc.l	0
maestro		dc.l	0
tport		dc.l	0
buffer		dc.l	0
window		dc.l	0
msg1		ds.b	dmn_SIZEOF
msg2		ds.b	dmn_SIZEOF

modustags	dc.l	MTAG_Output,OUTPUT_FIFO	; Output FIFO signal
		dc.l	MTAG_Input,INPUT_SRC48K	; Use internal 48kHz source
		dc.l	MTAG_CopyProh,CPROH_OFF	; No copy protection
		dc.l	MTAG_Emphasis,EMPH_OFF	; No emphasis
		dc.l	MTAG_Source,SRC_DAT	; Source is DAT
		dc.l	MTAG_Rate,RATE_48000	; Rate is 48kHz
		dc.l	TAG_DONE

tasktags	dc.l	NP_Entry,SineProc
		dc.l	NP_Priority,25
		dc.l	NP_Name,.name
		dc.l	TAG_DONE
.name		dc.b	"Maestix output process",0
		even

windowtags	dc.l	WA_IDCMP,IDCMP_CLOSEWINDOW
		dc.l	WA_Title,.title
		dc.l	WA_InnerWidth,100
		dc.l	WA_InnerHeight,0
		dc.l	WA_DragBar,-1
		dc.l	WA_DepthGadget,-1
		dc.l	WA_CloseGadget,-1
		dc.l	WA_Activate,-1
		dc.l	WA_RMBTrap,-1
		dc.l	TAG_DONE
.title		dc.b	"Sine Output",0
		even

maestname	dc.b	"maestix.library",0
intuiname	dc.b	"intuition.library",0
dosname		dc.b	"dos.library",0
		even

	;-- Sine Tone Table
sintab		dc.w	 00000, 06393, 12540, 18205
		dc.w	 23170, 27246, 30274, 32138
		dc.w	 32767, 32138, 30274, 27246
		dc.w	 23170, 18205, 12540, 06393
		dc.w	 00000,-06393,-12540,-18205
		dc.w	-23170,-27246,-30274,-32138
		dc.w	-32768,-32138,-30274,-27246
		dc.w	-23170,-18205,-12540,-06393
