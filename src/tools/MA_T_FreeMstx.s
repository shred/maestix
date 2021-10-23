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

		INCLUDE	dos/dos.i
		INCLUDE	dos/rdargs.i
		INCLUDE	exec/libraries.i
		INCLUDE	exec/lists.i
		INCLUDE	exec/memory.i
		INCLUDE	exec/nodes.i
		INCLUDE	exec/ports.i
		INCLUDE	libraries/maestix.i
		INCLUDE	utility/tagitem.i
		INCLUDE	lvo/dos.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/maestix.i

		INCLUDE	maestixpriv.i

VERSION         MACRO
		dc.b	"2.2"
		ENDM
DATE            MACRO
		dc.b	"23.10.2021"
		ENDM

		SECTION	text,CODE

**
* Main Entry
*
*	-> A0.l	^args
*	-> D0.l	argc
*	<- D0.l	result
*
Start	;-- open dos.library
		lea	(dosname,PC),a1
		moveq	#36,d0
		exec	OpenLibrary
		move.l	d0,dosbase
		beq.w	.error1
	;-- read arguments
		lea	(template,PC),a0
		move.l	a0,d1
		lea	(ArgList,PC),a0
		move.l	a0,d2
		moveq	#0,d3
		dos	ReadArgs
		move.l	d0,args
		bne	.parseok
		lea	(msg_hail,PC),a0
		move.l	a0,d1
		moveq	#0,d2
		dos	VPrintf
		lea	(msg_help,PC),a0
		move.l	a0,d1
		moveq	#0,d2
		dos	VPrintf
		bra	.error2
	;-- open maestix.library
.parseok	lea	(msg_hail,PC),a0
		sub.l	a1,a1
		bsr	Print
		lea	(maestname,PC),a1
		moveq	#39,d0
		exec	OpenLibrary
		move.l	d0,maestbase
		bne	.gotmstx
		lea	(msg_nomstx,PC),a0	; lib is not installed
		sub.l	a1,a1
		bsr	Print
		bra	.error3
	;-- is the card allocated?
.gotmstx	lea	(.portname,PC),a1	; try to find our rendezvous port
		exec	FindPort
		tst.l	d0			; it's there, free the maestro card
		bne	.free
		move.l	(maestbase,PC),a0
		tst.l	(mab_AllocMstx,a0)
		bne	.bad			; not allocated anyway
		lea	(msg_notyet,PC),a0
		sub.l	a1,a1
		bsr	Print
		bra	.error4
.bad		lea	(msg_notus,PC),a0	; not allocated by us
		sub.l	a1,a1
		bsr	Print
		bra	.error4
	;-- free Maestro
.free		move.l	d0,a1			; remove port
		move.l	a1,-(sp)
		exec	RemPort
		move.l	(sp)+,a1		; free memory
		exec	FreeVec
		move.l	(maestbase,PC),a0
		move.l	(mab_AllocMstx,a0),a0	; free maestro
		maest	FreeMaestro
		clr.l	(mab_AllocMstx,a6)
		lea	(msg_done,PC),a0
		sub.l	a1,a1
		bsr	Print
	;-- done
.done		move.l	(maestbase,PC),a1	; close maestix
		exec	CloseLibrary
		move.l	(args,PC),d1		; release arguments
		dos	FreeArgs
		move.l	(dosbase,PC),a1		; close dos
		exec	CloseLibrary
		moveq	#0,d0
.exit		rts
	;-- errors
.error4		move.l	(maestbase,PC),a1
		exec	CloseLibrary
.error3		move.l	(args,PC),d1
		dos	FreeArgs
.error2		move.l	(dosbase,PC),a1
		exec	CloseLibrary
.error1		moveq	#10,d0			; return code 10
		bra.b	.exit

	;-- tags
.tags		dc.l	MTAG_AllocOnly,-1	; only allocate the board
		dc.l	TAG_DONE

	;-- strings
.portname	dc.b	"maestix rendezvous",0
.portname_e	even



**
* Print to console unless QUIET option is set.
*
*	-> A0.l	^String
*	-> A1.l	^Parameters
*
Print		movem.l	d1-d3/a0-a3,-(sp)
		move.l	(ArgList+arg_Quiet,PC),d0
		bne	.done
		move.l	a0,d1
		move.l	a1,d2
		dos	VPrintf
.done		movem.l	(sp)+,d1-d3/a0-a3
		rts


**
* Variables
*
version		dc.b	0,"$VER: FreeMstx V"
		VERSION
		dc.b	" ("
		DATE
		dc.b	")",$d,$a,0
		even

dosbase		dc.l	0			; ^dos.library
maestbase	dc.l	0			; ^maestix.library
args		dc.l	0			; ^arg parse result

	;-- arguments
		rsreset
arg_Quiet	rs.l	1			; TRUE when quiet
arg_SIZEOF	rs.w	0

ArgList		ds.b	arg_SIZEOF
template	dc.b	"QUIET/S",0
		even

	;-- texts
msg_hail	dc.b	"\n       \2331m-- FreeMstx V"
		VERSION
		dc.b	" ("
		DATE
		dc.b	") --\2330m\n"
		dc.b	"  maestix.library's MaestroPro releaser.\n"
		dc.b	"\xA9 1995-2021 Richard 'Shred' K\xF6rber - https://maestix.shredzone.org\n\n",0

msg_nomstx	dc.b	"Needs maestix.library V39 or higher!\n",0

msg_notyet	dc.b	"MaestroPro is already free!\n",0

msg_notus	dc.b	"MaestroPro has not been allocated by AllocMstx.\n",0

msg_done	dc.b	"MaestroPro is free again.\n",0

msg_help	dc.b	"\2334m Template:         \2330m\n\n"
		dc.b	"  QUIET/S         be quiet\n",0
		even

	;-- string constants
dosname		dc.b	"dos.library",0
maestname	dc.b	"maestix.library",0
		even
