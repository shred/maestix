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

**
** This demonstration shows the basic receive functions of the
** maestix library. It allocates the Maestro soundcard, selects
** the default input and displays the level of the incoming
** signal using an intuition window.
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
WINDOW_WIDTH	EQU	50			; width of output window

		SECTION	text,CODE

start	;-- open all libraries
		lea	maestname(PC),a1	; maestix.library
		moveq	#35,d0			;  V35+
		exec	OpenLibrary
		move.l	d0,maestbase
		beq	error1
		lea	intuiname(PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,intuibase
		beq	error2
		lea	gfxname(PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,gfxbase
		beq	error3
		lea	dosname(PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,dosbase
		beq	error4
	;-- create buffers
		move.l	#BUFSIZE*3,d0		; size of three buffers
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		exec	AllocMem
		move.l	d0,buffer
		beq	error5
	;-- allocate signal bits
		sub.l	a1,a1			; get task ptr
		exec	FindTask
		move.l	d0,disptask
		moveq	#-1,d0			; allocate a signal bit
		exec	AllocSignal
		move.b	d0,dispsigbit
		cmp.b	#-1,d0			; no signals free?
		beq.w	error6
		moveq	#-1,d0			; allocate a 2nd signal bit
		exec	AllocSignal
		move.b	d0,donesigbit
		cmp.b	#-1,d0			; no signals free?
		beq.w	error7
	;-- open output window
		sub.l	a0,a0
		lea	windowtags(PC),a1
		intui	OpenWindowTagList
		move.l	d0,window
		beq	error8
	;-- start level task
		move.l	#tasktags,d1
		dos	CreateNewProc
		tst.l	d0
		beq	error9
		moveq	#0,d0			; wait for task to be launched
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Wait
	;-- main loop
.mainloop	move.l	window(PC),a0		; window message?
		move.l	wd_UserPort(a0),a0
		exec	GetMsg
		tst.l	d0
		bne.b	.gotwindow
		moveq	#0,d0
		move.b	dispsigbit(PC),d1
		bset	d1,d0
		move.l	window(PC),a0
		move.l	wd_UserPort(a0),a0
		move.b	MP_SIGBIT(a0),d1
		bset	d1,d0
		exec	Wait
		move.b	dispsigbit(PC),d1
		btst	d1,d0
		beq.b	.mainloop
	;-- got a signal for drawing new levels
.drawsig	moveq	#0,d0			; D0: x coordinate left
		move	leftlevel,d1		; D1: left level
		lsr	#8,d1			;  (Range 0..128)
		move	oldleft(PC),d2		; D2: old left level
		move	d1,oldleft		;  store new "old" level
		bsr	drawlevel		; draw this level
		moveq	#WINDOW_WIDTH/2,d0	; D0: x coordinate left
		move	rightlevel,d1		; D1: right level
		lsr	#8,d1			;  (Range 0..128)
		move	oldright(PC),d2		; D2: old right level
		move	d1,oldright		;  store new "old" level
		bsr	drawlevel		; draw this level
		bra.b	.mainloop		; and back to the main loop
	;-- got a window event
.gotwindow	move.l	d0,a0
		cmp.l	#IDCMP_CLOSEWINDOW,im_Class(a0)
		bne.b	.mainloop
	;-- exit program
exit		move.l	leveltask(PC),a1	; signal level task to shut down
		moveq	#0,d0
		move.b	levelsigbit(PC),d1
		bset	d1,d0
		exec	Signal
		moveq	#0,d0			; wait for signal task to exit
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Wait
error9		move.l	window(PC),a0		; close window
		intui	CloseWindow
error8		move.b	donesigbit(PC),d0
		exec	FreeSignal
error7		move.b	dispsigbit(PC),d0
		exec	FreeSignal
error6		move.l	buffer(PC),a1		; free buffer memory
		move.l	#BUFSIZE*3,d0
		exec	FreeMem
error5		move.l	dosbase(PC),a1
		exec	CloseLibrary
error4		move.l	gfxbase(PC),a1
		exec	CloseLibrary
error3		move.l	intuibase(PC),a1
		exec	CloseLibrary
error2		move.l	maestbase(PC),a1
		exec	CloseLibrary
error1		moveq	#0,d0
		rts

**
* Draws the level into the window.
*
*	-> D0.w	X coordinate
*	-> D1.w	Current level
*	-> D2.w	Previous level
*
drawlevel	movem.l	a0-a4/d0-d7,-(sp)
	;-- compute coordinates
		move.l	window(PC),a4		; ^Window
		moveq	#0,d3			; for calculations
		move.b	wd_BorderLeft(a4),d3	; left border width
		add	d3,d0			; add to x
		move.b	wd_BorderTop(a4),d3	; window title height
		add	#128,d3			; +128 (bottom)
		neg	d1			; d3 - new level
		add	d3,d1
		neg	d2			; d2 - old level
		add	d3,d2
	;-- what color?
		moveq	#3,d3			; start with blue
		cmp	d2,d1			; compare old vs. new
		beq.b	.done			; old = new -> leave
		blo.b	.colour_ok		; old > new -> blue is ok
		exg	d2,d1			; old < new ->
		moveq	#0,d3			;      use grey instead
.colour_ok	movem.l	d0-d2,-(sp)		; stash coordinates
		move	d3,d0			; set A Pen
		move.l	wd_RPort(a4),a1		; ^Rast Port
		gfx	SetAPen
		movem.l	(sp)+,d0-d2		; restore coordinates
	;-- fill box
		move	d2,d3			; ymax -> D3
		move	d0,d2			; xmax := xmin
		add	#WINDOW_WIDTH/2-1,d2	;       +bar width
		move.l	wd_RPort(a4),a1		; ^RastPort
		gfx	RectFill
	;-- done
.done		movem.l	(sp)+,a0-a4/d0-d7
		rts

**
* This process measures the level of the input signal.
*
LevelProc
	;-- exit?
		sub.l	a1,a1
		exec	FindTask
		move.l	d0,leveltask
		moveq	#-1,d0
		exec	AllocSignal
		move.b	d0,levelsigbit
		cmp.b	#-1,d0
		beq	.error1
		move.l	disptask(PC),a1		; task is done
		moveq	#0,d0
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Signal			; signal that we're leaving
	;-- allocate MaestroPro
		sub.l	a0,a0			; no tags
		maest	AllocMaestro
		move.l	d0,maestro		; ^Maestro base
		beq	.error2
	;-- set input mode
		move.l	maestro(PC),a0		; ^Maestro base
		lea	modustags(PC),a1	; ^Modus tags
		maest	SetMaestro		; set them
	;-- read board status
		move.l	maestro(PC),a0		; ^Maestro base
		move.l	#MSTAT_Signal,d0	; we want to check the input signal
		maest	GetStatus		; get the card status
		tst.l	d0
		beq	.error3			; input has no signal, leave
	;-- create receiver messageport
		exec	CreateMsgPort
		move.l	d0,rport
		beq	.error4
	;-- init the buffer messages
		move.l	rport(PC),d1		; ^Receive Reply Port
		lea	msg1(PC),a0		; ^1st Message
		lea	msg2(PC),a1		;  (this should have been a loop)
		lea	msg3(PC),a2
		move.l	buffer(PC),d0		; get buffer ptr
		move.l	d0,(dmn_BufPtr,a0)	; set buffer1
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a1)	; set buffer2
		add.l	#BUFSIZE,d0
		move.l	d0,(dmn_BufPtr,a2)	; set buffer 3
		move.l	#BUFSIZE,(dmn_BufLen,a0) ; set buffer length
		move.l	#BUFSIZE,(dmn_BufLen,a1)
		move.l	#BUFSIZE,(dmn_BufLen,a2)
		move.l	d1,(MN_REPLYPORT,a0)	; set Reply-Port
		move.l	d1,(MN_REPLYPORT,a1)
		move.l	d1,(MN_REPLYPORT,a2)
		move	#dmn_SIZEOF,(MN_LENGTH,a0) ; set msg length
		move	#dmn_SIZEOF,(MN_LENGTH,a1)
		move	#dmn_SIZEOF,(MN_LENGTH,a2)
	;-- start receiver
		move.l	maestro(PC),a0		; transmit msg to library
		lea	msg1(PC),a1
		maest	ReceiveData		; the 1st (starts receiver!)
		move.l	maestro(PC),a0
		lea	msg2(PC),a1
		maest	ReceiveData		; and the 2nd
		move.l	maestro(PC),a0
		lea	msg3(PC),a1
		maest	ReceiveData		; and the 3nd
	;-- wait for messages
.mainloop	move.l	rport(PC),a0		; get a maestix message?
		exec	GetMsg
		tst.l	d0			; got one?
		bne.b	.gotmaestro		; then evaluate it
		moveq	#0,d0			; create wait mask
		move.b	levelsigbit(PC),d1	; signal for exiting
		bset	d1,d0
		move.l	rport(PC),a0		; second, from receive port
		move.b	MP_SIGBIT(a0),d1	; sig bit
		bset	d1,d0			; set this bit
		exec	Wait			; wait for these events
		move.b	levelsigbit(PC),d1	; exit forced?
		btst	d1,d0			; test this bit
		beq.b	.mainloop		; not wanted -> main loop
		bra.b	.exit			; wanted -> leave
	;-- process maestix event
.gotmaestro	bsr	maestix			; evaluate it
		move.l	disptask(PC),a1		; show new level
		moveq	#0,d0
		move.b	dispsigbit(PC),d1
		bset	d1,d0
		exec	Signal			; signals the exit
		bra.b	.mainloop		; and try again
	;-- leave task
.exit		move.l	maestro(PC),a0		; stop receiver
		maest	FlushReceive
		move.l	rport(PC),a0		; delete receive port
		exec	DeleteMsgPort
.error4		move.b	levelsigbit(PC),d0	; free signal bit
		exec	FreeSignal
.error3		move.l	maestro(PC),a0		; release MaestroPro
		maest	FreeMaestro
.error2		move.l	disptask(PC),a1		; task is done
		moveq	#0,d0
		move.b	donesigbit(PC),d1
		bset	d1,d0
		exec	Signal			; signals the exit
.error1		rts				; done (freed by DOS)

**
* Evaluate Maestix buffer and draw level.
*
*	-> D0.l	^Maestro Message
*
maestix		move.l	d0,a1
	;-- get buffer pointer
		move.l	dmn_BufPtr(a1),a0
		move.l	dmn_BufLen(a1),d0
		subq.l	#1,d0
	;-- find peak level for each channel
		moveq	#0,d6			; left maximum goes here
		moveq	#0,d7			; right maximum here
.getmax		move	(a0)+,d1		; get one word (left)
		bpl.b	.notneg_l
		neg	d1			; absolute value
.notneg_l	cmp	d6,d1			; new maximum?
		blo.b	.nxtword_l
		move	d1,d6			; store as new maximum
.nxtword_l	move	(a0)+,d1		; get next word (right)
		bpl.b	.notneg_r
		neg	d1			; absolute value
.notneg_r	cmp	d7,d1			; new maximum?
		blo.b	.nxtword_r
		move	d1,d7			; store as new maximum
.nxtword_r	subq.l	#4,d0			; processed 4 bytes
		bcc.b	.getmax
		move	d6,leftlevel		; store new levels
		move	d7,rightlevel
	;-- re-send buffer to Maestix
		move.l	maestro(PC),a0		; put message back to queue
		maest	ReceiveData
	;-- done
		rts


disptask	dc.l	0		; ^Display task
leveltask	dc.l	0		; ^Level task
dispsigbit	dc.b	0		; Display task signal bit
levelsigbit	dc.b	0		; Level task signal bit
donesigbit	dc.b	0		; Display task done sigbit
		even
maestbase	dc.l	0		; ^Maestix Lib Base
intuibase	dc.l	0		; ^Intuition Lib Base
gfxbase		dc.l	0		; ^Graphics Lib Base
dosbase		dc.l	0		; ^DOS Lib Base
stdout		dc.l	0		; ^Output File Handle
maestro		dc.l	0		; ^Maestro Base
rport		dc.l	0		; ^Receive MsgPort
buffer		dc.l	0		; ^Data Buffer
window		dc.l	0		; ^Window Structure
msg1		ds.b	dmn_SIZEOF	; ^First Message
msg2		ds.b	dmn_SIZEOF	; ^Second Message
msg3		ds.b	dmn_SIZEOF	; ^Third Message
leftlevel	dc.w	0		; Current Level Left
rightlevel	dc.w	0		; Current Level Right
oldleft		dc.w	0		; Previous Level Left
oldright	dc.w	0		; Previous Level Right

modustags	dc.l	MTAG_Input,INPUT_STD		; use standard input
		dc.l	MTAG_Output,OUTPUT_BYPASS	; bypass signal to output
		dc.l	TAG_DONE

tasktags	dc.l	NP_Entry,LevelProc
		dc.l	NP_Priority,25
		dc.l	NP_Name,.name
		dc.l	TAG_DONE
.name		dc.b	"Maestix level process",0
		even

windowtags	dc.l	WA_IDCMP,IDCMP_CLOSEWINDOW
		dc.l	WA_Title,.title
		dc.l	WA_InnerWidth,WINDOW_WIDTH
		dc.l	WA_InnerHeight,129
		dc.l	WA_DragBar,-1
		dc.l	WA_DepthGadget,-1
		dc.l	WA_CloseGadget,-1
		dc.l	WA_Activate,-1
		dc.l	WA_RMBTrap,-1
		dc.l	TAG_DONE
.title		dc.b	"DAT Level",0
		even

maestname	dc.b	"maestix.library",0
intuiname	dc.b	"intuition.library",0
gfxname		dc.b	"graphics.library",0
dosname		dc.b	"dos.library",0
		even
