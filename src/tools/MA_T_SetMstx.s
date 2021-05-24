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

MAX_DELAY	EQU	30000		; maximum DAT setup delay (ms)

VERSION		MACRO
		dc.b	"2.2"
		ENDM
DATE		MACRO
		dc.b	"25.9.97"
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
		moveq	#40,d0
		exec	OpenLibrary
		move.l	d0,maestbase
		bne	.gotmstx
		lea	(msg_nomstx,PC),a0	; lib is not installed
		sub.l	a1,a1
		bsr	Print
		bra	.error3
	;-- card is allocated?
.gotmstx	move.l	(ArgList+arg_Force,PC),d0	; we don't care in FORCE mode
		bne	.force
		move.l	(maestbase,PC),a0
		tst.l	(mab_AllocMstx,a0)
		beq	.force
		lea	(msg_allocated,PC),a0	; it is in use
		sub.l	a1,a1
		bsr	Print
		bra	.error4
	;-- optical/coaxial input
.force		move.l	(ArgList+arg_Input,PC),a0
		move.l	a0,d0
		beq	.no_input
		move.l	(maestbase,PC),a1
		move.b	(a0),d0			; optical?
		cmp.b	#"o",d0
		beq	.optical
		cmp.b	#"O",d0
		beq	.optical
		cmp.b	#"c",d0			; coaxial?
		beq	.coaxial
		cmp.b	#"C",d0
		beq	.coaxial
		move.l	a0,-(sp)		; cannot parse user input
		lea	(msg_optcoaxonly,PC),a0
		move.l	sp,a1
		bsr	Print
		addq.l	#4,sp
		bra	.no_input
.optical	sf	(mab_DefInput,a1)	; set default optical
		lea	(msg_setopt,PC),a0
		sub.l	a1,a1
		bsr	Print
		bra	.no_input
.coaxial	st	(mab_DefInput,a1)	; set default coaxial
		lea	(msg_setcoax,PC),a0
		sub.l	a1,a1
		bsr	Print
	;-- DAT delay
.no_input	move.l	(ArgList+arg_Delay,PC),a0
		move.l	a0,d0
		beq	.no_delay
		move.l	(maestbase,PC),a1
		move.l	(a0),d0			; read delay number
		bmi	.out_range		; must not be negative
		cmp.l	#MAX_DELAY,d0
		bhi	.out_range		; must not exceed maximum
		move.l	d0,(mab_Delay,a1)
		lea	(msg_setdelay,PC),a0
		move.l	d0,-(sp)
		move.l	sp,a1
		bsr	Print
		addq.l	#4,sp
		bra	.no_delay
.out_range	lea	(msg_outrange,PC),a0	; out of range
		pea	MAX_DELAY
		move.l	d0,-(sp)
		move.l	sp,a1
		bsr	Print
		addq.l	#8,sp
	;-- studio mode on
.no_delay	move.l	(ArgList+arg_NoStudio,PC),d0
		beq	.no_nostudio
		move.l	(maestbase,PC),a0
		sf	(mab_DefStudio,a0)
		lea	(msg_nostudio,PC),a0
		sub.l	a1,a1
		bsr	Print
	;-- studio mode off
.no_nostudio	move.l	(ArgList+arg_Studio,PC),d0
		beq	.no_studio
		move.l	(maestbase,PC),a0
		st	(mab_DefStudio,a0)
		lea	(msg_studio,PC),a0
		sub.l	a1,a1
		bsr	Print
	;-- to be continued...
.no_studio
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
version		dc.b	0,"$VER: SetMstx V"
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
arg_Input	rs.l	1			; Input type
arg_Delay	rs.l	1			; delay
arg_NoStudio	rs.l	1			; no default studio mode
arg_Studio	rs.l	1			; default studio mode
arg_Quiet	rs.l	1			; quiet output
arg_Force	rs.l	1			; force
arg_SIZEOF	rs.w	0

ArgList		ds.b	arg_SIZEOF
template	dc.b	"I=INPUT/K,D=DELAY/K/N,NST=NOSTUDIO/S,ST=STUDIO/S,Q=QUIET/S,F=FORCE/S",0
		even

	;-- texts
msg_hail	dc.b	"\n       \2331m-- SetMstx V"
		VERSION
		dc.b	" ("
		DATE
		dc.b	") --\2330m\n"
		dc.b	"  maestix.library configuration tool.\n"
		dc.b	"\xA9 1995-2021 Richard 'Shred' K\xF6rber - https://maestix.shredzone.org\n\n",0

msg_nomstx	dc.b	"Needs maestix.library V40 or higher!\n",0

msg_allocated	dc.b	"MaestroPro is currently in use. Can't setup!\n",0

msg_optcoaxonly	dc.b	"INPUT: '%s' is not a valid input...\n",0
msg_setopt	dc.b	"Default input is now optical.\n",0
msg_setcoax	dc.b	"Default input is now coaxial.\n",0

msg_outrange	dc.b	"DELAY: %ld is not within range (0..%ld ms)...\n",0
msg_setdelay	dc.b	"Delay set to %ld ms.\n",0

msg_nostudio	dc.b	"Studio mode turned off as default.\n",0
msg_studio	dc.b	"Studio mode turned on as default.\n",0

msg_help	dc.b	"\X9B4m Template:         \X9B0m\n\n"
		dc.b	"  INPUT/K    =[o|c]  select default input\n"
		dc.b	"  DELAY/K/N          time (ms) your dat deck needs to set up\n"
		dc.b	"  NOSTUDIO/S         turn off studio mode by default\n"
		dc.b	"  STUDIO/S           turn on studio mode by default\n"
		dc.b	"  QUIET/S            be quiet\n"
		dc.b	"  FORCE/S            do even if board is allocated\n\n"
		dc.b	"Please read the doc file for further details.\n",0
		even

	;-- string constants
dosname		dc.b	"dos.library",0
maestname	dc.b	"maestix.library",0
		even
