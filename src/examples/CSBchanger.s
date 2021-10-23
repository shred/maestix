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
** This demonstration shows the basic encoder functions of
** the maestix library. It allocates the Maestro soundcard,
** decodes the incoming signal and encodes it again using new
** channel status bits.
**

		INCLUDE		dos/dostags.i
		INCLUDE		exec/ports.i
		INCLUDE		intuition/intuition.i
		INCLUDE		libraries/maestix.i
		INCLUDE		lvo/dos.i
		INCLUDE		lvo/exec.i
		INCLUDE		lvo/graphics.i
		INCLUDE		lvo/intuition.i
		INCLUDE		lvo/maestix.i

		SECTION		text,CODE

start	;-- open all libraries
		lea	maestname(PC),a1	; maestix.library
		moveq	#35,d0			; V35+
		exec	OpenLibrary
		move.l	d0,maestbase
		beq	error1
		lea	intuiname(PC),a1	; intuition.library
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,intuibase
		beq	error2
	;-- allocate MaestroPro board
		sub.l	a0,a0			; no tags
		maest	AllocMaestro
		move.l	d0,maestro		; ^Maestro base
		beq	error3
	;-- set mode
		move.l	maestro(PC),a0		; ^Maestro base
		lea	modustags(PC),a1	; ^Modus tags
		maest	SetMaestro		; set them...
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
error4		move.l	maestro(PC),a0		; release MaestroPro hardware
		maest	FreeMaestro
error3		move.l	intuibase(PC),a1
		exec	CloseLibrary
error2		move.l	maestbase(PC),a1
		exec	CloseLibrary
error1		moveq	#0,d0
		rts


maestbase	dc.l	0			; ^Maestix Lib Base
intuibase	dc.l	0			; ^Intuition Lib Base
maestro		dc.l	0			; ^Maestro Base
window		dc.l	0			; ^Window structure

modustags	dc.l	MTAG_Output,OUTPUT_INPUT	; Output the signal from input
		dc.l	MTAG_Input,INPUT_STD		; Use the user's default input
		dc.l	MTAG_CopyProh,CPROH_OFF		; Turn off CPROH
		dc.l	MTAG_Emphasis,EMPH_INPUT	; Keep emphasis
		dc.l	MTAG_Source,SRC_INPUT		; Keep source type
		dc.l	MTAG_Rate,RATE_INPUT		; Keep rate
		dc.l	TAG_DONE

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
.title		dc.b	"CSBchanger",0
		even

maestname	dc.b	"maestix.library",0
intuiname	dc.b	"intuition.library",0
		even
