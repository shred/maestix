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
** This demonstration shows the realtime effect feature of
** the maestix library. It allocates the Maestro soundcard
** and switches to realtime effect.
**


		INCLUDE	dos/dostags.i
		INCLUDE	exec/ports.i
		INCLUDE	intuition/intuition.i
		INCLUDE	libraries/maestix.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/intuition.i
		INCLUDE	lvo/graphics.i
		INCLUDE	lvo/dos.i
		INCLUDE	lvo/maestix.i

BUFFMS		EQU	333		; <- Echo delay (in milliseconds)
VOLUME		EQU	180		; <- Initial echo volume (0.256)
DECAY		EQU	256		; <- Decay of each echo loop (0..256)

RATE		EQU	44100		; Assumed sampling rate
BUFFSIZE	EQU	((BUFFMS*2*RATE)/1000/2)*2 ; Compute ring buffer size

		SECTION	text,CODE

start	;-- open all libraries
		lea	maestname(PC),a1	; maestix.library
		moveq	#38,d0			;   V38+
		exec	OpenLibrary
		move.l	d0,maestbase
		beq	error1
		lea	intuiname(PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,intuibase
		beq	error2
	;-- allocate MaestroPro
		sub.l	a0,a0			; no tags
		maest	AllocMaestro
		move.l	d0,maestro
		beq	error3
	;-- set mode
		move.l	maestro(PC),a0
		lea	modustags(PC),a1
		maest	SetMaestro
	;-- start realtime FX
		move.l	maestro(PC),a0
		lea	realtags(PC),a1
		maest	StartRealtime
	;-- open a window
		sub.l	a0,a0
		lea	windowtags(PC),a1
		intui	OpenWindowTagList
		move.l	d0,window
		beq	error4
	;-- wait for user to close it
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
	;-- exit program
exit		move.l	window(PC),a0
		intui	CloseWindow
error4		move.l	maestro(PC),a0		; stop realtime FX
		maest	StopRealtime
		move.l	maestro(PC),a0		; release MaestroPro
		maest	FreeMaestro
error3		move.l	intuibase(PC),a1
		exec	CloseLibrary
error2		move.l	maestbase(PC),a1
		exec	CloseLibrary
error1		moveq	#0,d0
		rts


maestbase	dc.l	0
intuibase	dc.l	0
maestro		dc.l	0
window		dc.l	0

modustags	dc.l	MTAG_Output,OUTPUT_FIFO	  ; Output signal from FIFO
		dc.l	MTAG_Input,INPUT_STD	  ; Select user's default input
		dc.l	MTAG_CopyProh,CPROH_INPUT ; CPROH like input
		dc.l	MTAG_Emphasis,EMPH_INPUT  ; Emphasis like input
		dc.l	MTAG_Source,SRC_INPUT	  ; Source like input
		dc.l	MTAG_Rate,RATE_INPUT	  ; Rate like input
		dc.l	TAG_DONE

realtags	dc.l	MTAG_Effect,RFX_Echo	  ; Echo the signal
		dc.l	MTAG_A0,torus		  ; Pointer to ring buffer structure
		dc.l	MTAG_D2,VOLUME		  ; entry volume
		dc.l	MTAG_D3,DECAY		  ; decay volume
		dc.l	TAG_DONE

torus		dc.l	buff_l			; left ring buffer
		dc.l	buff_r			; right ring buffer
		dc.l	BUFFSIZE		; size of buffers
		dc.l	0

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
.title		dc.b	"Realtime FX",0
		even

maestname	dc.b	"maestix.library",0
intuiname	dc.b	"intuition.library",0
		even


		SECTION	buffer,BSS

buff_l		ds.b	BUFFSIZE		; left ring buffer
buff_r		ds.b	BUFFSIZE		; right ring buffer
