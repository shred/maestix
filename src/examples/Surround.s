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
** This demonstration shows how to manually realise a real time effect
** using the maestix library. It allocates the Maestro soundcard,
** select the default input and sends the surround signal to output.
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

BUFSIZE		EQU	24*1024			;size of FIFO data block

		SECTION	text,CODE

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
	;-- create buffer space
		move.l	#BUFSIZE*5,d0		; five buffers
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocMem
		move.l	d0,buffer
		beq	error4
	;-- allocate signal bits
		sub.l	a1,a1
		exec	FindTask
		move.l	d0,maintask
		moveq	#-1,d0
		exec	AllocSignal
		move.b	d0,donesigbit
		cmp.b	#-1,d0
		beq.w	error5
	;-- open window
		sub.l	a0,a0
		lea	windowtags(PC),a1
		intui	OpenWindowTagList
		move.l	d0,window
		beq	error6
	;-- start surround task
		move.l	#tasktags,d1
		dos	CreateNewProc
		tst.l	d0
		beq	error7
		moveq	#0,d0
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Wait
	;-- wait for user to close window
.mainloop	move.l	window(PC),a0
		move.l	wd_UserPort(a0),a0
		exec	WaitPort
.nextmsg	move.l	window(PC),a0
		move.l	wd_UserPort(a0),a0
		exec	GetMsg
		tst.l	d0
		beq.b	.mainloop
		move.l	d0,a0
		cmp.l	#IDCMP_CLOSEWINDOW,im_Class(a0)
		bne.b	.nextmsg
	;-- exit
exit		move.l	surrtask(PC),a1		; shut down surround task
		moveq	#0,d0
		move.b	surrsigbit(PC),d1
		bset	d1,d0
		exec	Signal
		moveq	#0,d0			; wait for exit
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Wait
error7		move.l	window(PC),a0		; close window
		intui	CloseWindow
error6		move.b	donesigbit(PC),d0
		exec	FreeSignal
error5		move.l	buffer(PC),a1		; free all buffers
		move.l	#BUFSIZE*5,d0
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
* Surround Task.
*
SurroundProc
	;-- signal setup
		sub.l	a1,a1
		exec	FindTask
		move.l	d0,surrtask
		moveq	#-1,d0
		exec	AllocSignal
		move.b	d0,surrsigbit
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
	;-- set mode
		move.l	maestro(PC),a0
		lea	modustags(PC),a1
		maest	SetMaestro
	;-- read current status
		move.l	maestro(PC),a0
		move.l	#MSTAT_Signal,d0	; we want to check the input signal
		maest	GetStatus
		tst.l	d0
		beq	.error3			; no signal: leave
	;-- create messageports
		exec	CreateMsgPort		; receiver messageport
		move.l	d0,rport
		beq	.error3
		exec	CreateMsgPort		; transmitter messageport
		move.l	d0,tport
		beq	.error4
	;-- initialize messages
		move.l	rport(PC),d1		; D1: ^Receive Reply Port
		move.l	tport(PC),d2		; D2: ^Transmit Reply Port
		lea	msg1(PC),a0		; ^1st Message
		lea	msg2(PC),a1		; (this should have been a loop)
		lea	msg3(PC),a2
		lea	msg4(PC),a3
		lea	msg5(PC),a4
		move.l	buffer(PC),d0		; get buffer ptr
		move.l	d0,(dmn_BufPtr,a0)	; set buffer 1
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a1)	; set buffer 2
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a2)	; set buffer 3
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a3)	; set buffer 4
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a4)	; set buffer 5
		move.l	#BUFSIZE,(dmn_BufLen,a0) ; set buffer length
		move.l	#BUFSIZE,(dmn_BufLen,a1)
		move.l	#BUFSIZE,(dmn_BufLen,a2)
		move.l	#BUFSIZE,(dmn_BufLen,a3)
		move.l	#BUFSIZE,(dmn_BufLen,a4)
		move.l	d1,(MN_REPLYPORT,a0)	; two messages to the receiver
		move.l	d1,(MN_REPLYPORT,a1)
		move.l	d2,(MN_REPLYPORT,a2)	; three messages to the transmitter
		move.l	d2,(MN_REPLYPORT,a3)
		move.l	d2,(MN_REPLYPORT,a4)
		move	#dmn_SIZEOF,(MN_LENGTH,a0)	 ; set msg length
		move	#dmn_SIZEOF,(MN_LENGTH,a1)
		move	#dmn_SIZEOF,(MN_LENGTH,a2)
		move	#dmn_SIZEOF,(MN_LENGTH,a3)
		move	#dmn_SIZEOF,(MN_LENGTH,a4)
	;-- start receiver
		move.l	maestro(PC),a0		; send first message to receiver
		lea	msg1(PC),a1
		maest	ReceiveData		; it will start the receiver
		move.l	maestro(PC),a0
		lea	msg2(PC),a1
		maest	ReceiveData		; second message to receiver queue
		move.l	maestro(PC),a0
		lea	msg3(PC),a1		; send third message to transmitter
		maest	TransmitData		; it will start the transmitter
		move.l	maestro(PC),a0
		lea	msg4(PC),a1		; fourth and fifth message
		maest	TransmitData		; are sent to transmitter queue
		move.l	maestro(PC),a0
		lea	msg5(PC),a1
		maest	TransmitData
	;-- wait for messages
.mainloop	move.l	tport(PC),a0		; message from the transmitter?
		exec	GetMsg
		tst.l	d0
		bne.b	.gottransmit		; process it
		move.l	rport(PC),a0		; message from the receiver?
		exec	GetMsg
		tst.l	d0
		bne.b	.gotreceive		; process it
		moveq	#0,d0			; signal to stop the process?
		move.b	surrsigbit(PC),d1
		bset	d1,d0
		move.l	rport(PC),a0
		move.b	MP_SIGBIT(a0),d1
		bset	d1,d0
		move.l	tport(PC),a0
		move.b	MP_SIGBIT(a0),d1
		bset	d1,d0
		exec	Wait
		move.b	surrsigbit(PC),d1
		btst	d1,d0
		beq.b	.mainloop
		bra.b	.exit
	;-- process transmitter event
.gottransmit	move.l	maestro(PC),a0		; just send this message buffer
		move.l	d0,a1			; to the receiver queue
		move.l	rport(PC),(MN_REPLYPORT,a1) ; so it will get new audio data
		maest	ReceiveData		; remember to set the reply
		bra.b	.mainloop		; port to the receiver!
	;-- process receiver event
.gotreceive	bsr	surround	; compute the surround effect
		bra.b	.mainloop	; result will be sent to transmitter queue
	;-- leave task
.exit		move.l	maestro(PC),a0		; stop transmitter and flush messages
		maest	FlushTransmit
		move.l	maestro(PC),a0		; stop receiver and flush messages
		maest	FlushReceive
		move.l	tport(PC),a0		; delete transmit port
		exec	DeleteMsgPort
.error4		move.l	rport(PC),a0		; delete receive port
		exec	DeleteMsgPort
.error3		move.l	maestro(PC),a0		; release MaestroPro
		maest	FreeMaestro
.error2		move.l	maintask(PC),a1		; signal that we are done
		moveq	#0,d0
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Signal
.error1		rts

**
* Calculates surround effect.
*
*	-> D0.l	Pointer to Maestro message
*
surround	move.l	d0,a1
	;-- get buffer pointers
		move.l	dmn_BufPtr(a1),a0	; A0: ^Buffer start
		move.l	dmn_BufLen(a1),d0
		lea	(a0,d0.l),a2		; A2: ^Buffer end
	;-- surrounding
.loop		move	(a0),d0			; left sample
		ext.l	d0
		move	2(a0),d1		; right sample
		ext.l	d1
		sub.l	d1,d0
		asr.l	#1,d0			; D0 = (right - left) / 2
		move	d0,(a0)+		; write result into buffer
		move	d0,(a0)+		; (left and right channel)
		cmp.l	a2,a0			; end of buffer reached?
		blo.b	.loop
	;-- send buffer to transmitter queue
		move.l	maestro(PC),a0		; remember to set the
		move.l	tport(PC),(MN_REPLYPORT,a1) ; transmitter's reply port!
		maest	TransmitData		; send to transmitter
	;-- done
		rts


maintask	dc.l	0			; ^Main task
surrtask	dc.l	0			; ^Surround task
surrsigbit	dc.b	0			; Surround task signal bit
donesigbit	dc.b	0			; Main task done sigbit
		even
maestbase	dc.l	0			; ^Maestix Lib Base
intuibase	dc.l	0			; ^Intuition Lib Base
dosbase		dc.l	0			; ^DOS Lib Base
maestro		dc.l	0			; ^Maestro Base
rport		dc.l	0			; ^Receive MsgPort
tport		dc.l	0			; ^Transmit MsgPort
buffer		dc.l	0			; ^Data buffer
window		dc.l	0			; ^Window structure
msg1		ds.b	dmn_SIZEOF		; ^first message
msg2		ds.b	dmn_SIZEOF		; ^second message
msg3		ds.b	dmn_SIZEOF		; ^third message
msg4		ds.b	dmn_SIZEOF		; ^fourth message
msg5		ds.b	dmn_SIZEOF		; ^fifth message

modustags	dc.l	MTAG_Input,INPUT_STD	; set user's standard input
		dc.l	MTAG_Output,OUTPUT_FIFO	; output FIFO data
		dc.l	MTAG_CopyProh,CPROH_INPUT; CPROH like input
		dc.l	MTAG_Emphasis,EMPH_OFF	; turn off emphasis
		dc.l	MTAG_Source,SRC_INPUT	; source like input
		dc.l	MTAG_Rate,RATE_INPUT	; rate like input
		dc.l	TAG_DONE

tasktags	dc.l	NP_Entry,SurroundProc
		dc.l	NP_Priority,30
		dc.l	NP_Name,.name
		dc.l	TAG_DONE
.name		dc.b	"Maestix surround process",0
		even

windowtags	dc.l	WA_IDCMP,IDCMP_CLOSEWINDOW
		dc.l	WA_Title,.title
		dc.l	WA_InnerWidth,150
		dc.l	WA_InnerHeight,0
		dc.l	WA_DragBar,-1
		dc.l	WA_DepthGadget,-1
		dc.l	WA_CloseGadget,-1
		dc.l	WA_Activate,-1
		dc.l	WA_RMBTrap,-1
		dc.l	TAG_DONE
.title		dc.b	"Surround generator",0
		even

maestname	dc.b	"maestix.library",0
intuiname	dc.b	"intuition.library",0
dosname		dc.b	"dos.library",0
		even
