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

		INCLUDE	exec/interrupts.i
		INCLUDE	exec/nodes.i
		INCLUDE	lvo/exec.i

		INCLUDE	libraries/maestix.i
		INCLUDE	maestix_lib.i
		INCLUDE	maestixpriv.i

		IFD	_MAKE_68020
		 MACHINE 68020
		ENDC

		SECTION	text,CODE

**
* Initializes the transmit FIFO.
*
*	-> A5.l ^MaestroBase
*
		public	InitTFIFO
InitTFIFO	movem.l	d2-d7/a2-a4,-(SP)
		move.l	(mb_HardBase,a5),a4
		move.l	4.w,a6
	;-- realtime FX enabled?
		tst.b	(mb_RealtimeFX,a5)
		bne	.realfx
	;-- fill from queue
		bsr	WriteTFIFO
		bra	.exit
	;-- fill with zeros
.realfx		lea	(mh_tfifo,a4),a0
		moveq	#(1280/32)-1,d0
		moveq	#0,d1
		moveq	#0,d2
		moveq	#0,d3
		moveq	#0,d4
		moveq	#0,d5
		sub.l	a1,a1
		sub.l	a2,a2
		sub.l	a3,a3
.rclearloop	movem.l	d1-d5/a1-a3,(a0)
		dbra	d0,.rclearloop
	;-- done
.exit		movem.l	(SP)+,d2-d7/a2-a4
		rts

**
* Handle MaestroPro hardware interrupt.
*
*	-> A1.l	^MaestroBase
*	<- CCR-Z is set
*	D0-D1,A0-A1,A5-A6 are trashed
*
		public	IntServer
IntServer	movem.l	d2-d7/a2-a4,-(sp)
		move.l	4.w,a6			; keep it, it will be used later
		move.l	a1,a5
	;-- realtime FX enabled?
		tst.b	(mb_RealtimeFX,a5)
		bne	.realfx
	;-- handle transmit interrupt
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_TFINTE,d0
		beq	.notransmit
		move.l	(mb_HardBase,a5),a4
		move	(mh_status,a4),d0
		btst	#MASB_THALF,d0		; transmit FIFO is half full?
		beq	.notransmit		;   yes: no need to take action
		btst	#MASB_TEMPTY,d0		; transmit FIFO ran empty?
		beq	.tfifo_error		;   yes: uh oh, that's bad!
		bsr	WriteTFIFO		; transmit FIFO half empty, fill it up.
		bra	.notransmit
	;---- stop transmit FIFO if it ran empty
.tfifo_error	and	#~(MAMF_TFENA|MAMF_TFINTE)&$FFFF,(mb_ModusReg,a5)
		or	#MAMF_EMUTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		st	(mb_TError,a5)		; report transmit FIFO error	;; TODO: cleared where?
	;-- handle receive interrupt
.notransmit	move	(mb_ModusReg,a5),d0
		btst	#MAMB_RFINTE,d0
		beq	.noreceive
		move.l	(mb_HardBase,a5),a4
		move	(mh_status,a4),d0
		btst	#MASB_RHALF,d0		; receive FIFO less than half full?
		bne	.noreceive		;    yes: no need to take action
		btst	#MASB_RFULL,d0		; receive FIFO is full?
		beq	.rfifofull		;    yes: that's bad too!
		bsr	ReadRFIFO		; receive FIFO half full, purge it
		bra	.noreceive
	;---- stop receive FIFO if it ran full
.rfifofull	and	#~(MAMF_RFENA|MAMF_RFINTE),(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		st	(mb_RError,a5)		; report receive FIFO error	;; TODO: cleared where?
	;-- int handler completed
.noreceive	movem.l	(sp)+,d2-d7/a2-a4
		moveq	#0,d0			; remember to set the Z flag
		rts

	;-- REALTIME EFFECTS
.realfx		move	(mb_ModusReg,a5),d0
		btst	#MAMB_RFINTE,d0		; interrupt is enabled?
		beq	.noreceive
		move.l	(mb_HardBase,a5),a4
		move	(mh_status,a4),d0
		btst	#MASB_TEMPTY,d0		; transmit FIFO empty?
		beq	.realdone		;    yes: we were too slow, stop
		btst	#MASB_RFULL,d0		; receive FIFO full?
		beq	.realdone		;    (should never happen)
	;-- process buffers
		move.b	(mb_LevelFlag,a5),d5	; levelmeter
		ror.l	#1,d5			; Move flag to bit 31 (long sign)
		move.l	(mb_RT_A0,a5),a0	; A0 FX parameter
		move.l	(mb_RT_A1,a5),a1	; A1 FX parameter
		move.l	(mb_RT_D2,a5),d2	; D2 FX parameter
		move.l	(mb_RT_D3,a5),d3	; D3 FX parameter
		move.l	(mb_RT_D6,a5),d6	; D6 aggregator variable
		move.l	(mb_RT_D7,a5),d7	; D7 aggregator variable
		move.l	(mb_RT_Call,a5),a3	; pointer to FX callback
		lea	(.return,PC),a2		; A2: return address (avoid stack)
		move	#192,d4			; 384 double words
.loop		movem	(mh_rfifo,a4),d0-d1	; fetch one stereo sample
		jmp	(a3)			; process it
.return		movem	d0-d1,(mh_tfifo,a4)	; transmit result
		tst.l	d5
		bpl	.do_loop		; LevelFlag reset? no post-level required
		bsr	post_level
.do_loop	dbra	d4,.loop
	;-- remember aggregation values
		move.l	d6,(mb_RT_D6,a5)
		move.l	d7,(mb_RT_D7,a5)
		bra	.noreceive
	;-- FIFO overflow during realtime FX
	; Both FIFOs are processed synchronously, so an overflow should never
	; happen. But now we are here, let's handle it like a pro. :)
	; RFINTE is not set, but clearing it won't hurt...
.realdone	and	#~(MAMF_RFENA|MAMF_RFINTE|MAMF_TFENA|MAMF_TFINTE)&$FFFF,(mb_ModusReg,a5)
		or	#MAMF_EMUTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)	; stop all FIFOs and ints
		st	(mb_RError,a5)			; report receive error	;; TODO: cleared where?
		st	(mb_TError,a5)			; report transmit error
		bra	.noreceive

	;-- Handle level meter
	; D0.w: left, D1.w: right sample
post_level	tst	d0
		bpl	.l_pos
		neg	d0
.l_pos		move	(mb_PostLevelL,a5),d5
		cmp	d5,d0
		blo	.l_ok
		move	d0,(mb_PostLevelL,a5)
.l_ok		tst	d1
		bpl	.r_pos
		neg	d1
.r_pos		move	(mb_PostLevelR,a5),d5
		cmp	d5,d1
		blo	.r_ok
		move	d1,(mb_PostLevelR,a5)
.r_ok		rts


**
* Fill transmit FIFO.
*
* Copyback is turned off.
*
*	-> A4.l	^Hardware base
*	-> A5.l	^MaestroBase
*	-> A6.l	^ExecBase
*	D0-D7,A0-A4 are trashed
*
WriteTFIFO	add.w	#mh_tfifo,a4		; A4: ^Transmit FIFO
	;-- prepare
		move.l	(mb_CurrTMsg,a5),d0	; do we have a current message?
		bne	.gotmsg
		move.l	(mb_TPort,a5),a0	; no: fetch one from queue
		exec.q	GetMsg
		tst.l	d0
		beq	.error			; no message, we may run empty
		clr.l	(mb_CurrTPos,a5)	; clean position
		move.l	d0,a3
		move.l	(dmn_BufPtr,a3),a0	; fetch buffer ptr
		bra	.outputs
.gotmsg		move.l	d0,a3			; message is in A3
		move.l	(dmn_BufPtr,a3),a0	; A0: buffer start
		add.l	(mb_CurrTPos,a5),a0
.outputs	move.l	(dmn_BufLen,a3),d0	; D0: buffer length
		sub.l	(mb_CurrTPos,a5),d0
	;-- handle extended node
		cmp	#dmn_SIZEOF,(MN_LENGTH,a3)	; is it an extended node?
		bls	.noext
		move	(edmn_Flags,a3),d1	; yes: handle mono/dual buffers
		btst	#EDMNB_MONO,d1
		bne	.write_mono
		btst	#EDMNB_DUAL,d1
		bne	.write_dual
.noext	;-- copy to FIFO
		cmp.l	#1024,d0		; >= 1024 bytes: fast copy
		bhs	.fastput
.slowloop	subq.l	#4,d0			; < 1024 bytes: slow copy
		bcs	.bufdone		;   buffer is empty after that
		move.l	(a0)+,(a4)
		bra	.slowloop
	;---- fast copy to FIFO
.fastput	moveq	#7,d0
.putloop	movem.l	(a0)+,d1-d6/a1-a2	; 8 * 128 bytes = 1024 bytes
		movem.l	d1-d6/a1-a2,(a4)
		movem.l	(a0)+,d1-d6/a1-a2
		movem.l	d1-d6/a1-a2,(a4)
		movem.l	(a0)+,d1-d6/a1-a2
		movem.l	d1-d6/a1-a2,(a4)
		movem.l	(a0)+,d1-d6/a1-a2
		movem.l	d1-d6/a1-a2,(a4)
		dbra	d0,.putloop
	;-- update pointers
		move.l	(mb_CurrTPos,a5),d0	; increment position
		add.l	#1024,d0		; by 1024 bytes
		cmp.l	(dmn_BufLen,a3),d0	; reached end of buffer?
		blo.b	.bufnotend
	;-- buffer has been transmitted
.bufdone	move.l	a3,a1
		exec.q	ReplyMsg
		clr.l	(mb_CurrTMsg,a5)	; no current message at the moment
		rts
	;-- buffer still has data left
.bufnotend	move.l	a3,(mb_CurrTMsg,a5)	; update pointers
		move.l	d0,(mb_CurrTPos,a5)
		rts
	;-- failed
.error		clr.l	(mb_CurrTMsg,a5)
		rts

	;-- handle mono buffer
.write_mono	move	#255,d1
.monoloop	subq.l	#2,d0			; buffer completed?
		bcs	.bufdone
		move	(a0),(a4)		; write same value to L+R channel
		move	(a0)+,(a4)
		dbra	d1,.monoloop
		move.l	(mb_CurrTPos,a5),d0	; update pointers
		add.l	#512,d0
		cmp.l	(dmn_BufLen,a3),d0
		blo	.bufnotend
		bra	.bufdone

	;-- handle dual buffer
.write_dual	move	#255,d1
		move.l	(edmn_BufPtrR,a3),a1	; A1: ^Right channel
		add.l	(mb_CurrTPos,a5),a1	; A0: ^Left channel
.dualloop	subq.l	#2,d0			; buffer completed?
		bcs	.bufdone
		move	(a0)+,(a4)		; left channel from left buffer
		move	(a1)+,(a4)		; right channel from right buffer
		dbra	d1,.dualloop
		move.l	(mb_CurrTPos,a5),d0
		add.l	#512,d0
		cmp.l	(dmn_BufLen,a3),d0	; update pointers
		blo	.bufnotend
		bra	.bufdone


**
* Read from receive FIFO.
*
*	-> A4.l	^HardBase
*	-> A5.l	^MaestroBase
*	-> A6.l	^ExecBase
*	D0-D7/A0-A4 are trashed.
*
ReadRFIFO	add.w	#mh_rfifo,a4		; A4: ^Read FIFO
	;-- prepare
		move.l	(mb_CurrRMsg,a5),d0	; is there a current message?
		bne	.gotmsg
		move.l	(mb_RPort,a5),a0	; no: fetch a new one from queue
		exec.q	GetMsg
		tst.l	d0
		beq	.error			; queue is empty, do nothing
		clr.l	(mb_CurrRPos,a5)	; set buffer pointers
		move.l	d0,a3
		move.l	(dmn_BufPtr,a3),a0
		bra	.input
.gotmsg		move.l	d0,a3
		move.l	(dmn_BufPtr,a3),a0
		add.l	(mb_CurrRPos,a5),a0
.input		move.l	(dmn_BufLen,a3),d0
		sub.l	(mb_CurrTPos,a5),d0
	;-- check for extended node
		cmp	#dmn_SIZEOF,(MN_LENGTH,a3)
		bls	.noext
		btst	#EDMNB_MONO,(edmn_Flags+1,a3)	; handle mono buffer
		bne	.read_mono
		btst	#EDMNB_DUAL,(edmn_Flags+1,a3)	; handle dual buffer
		bne	.read_dual
.noext	;-- wait for WC to become low
.waitlow	move	(mh_status-mh_rfifo,a4),d1
		btst	#MASB_DWC,d1		; receive FIFO is half filled now
		bne	.waitlow		;; TODO: ineffective?
	;-- read from FIFO
		cmp.l	#1024,d0		; >= 1024 bytes left in buffer?
		bhs	.fastget		; then use fast copy
.slowloop	subq.l	#4,d0			; fill remaining space
		bcs	.bufdone		; and we're done
		move.l	(a0)+,(a4)
		bra	.slowloop
	;-- read 1024 bytes quickly
.fastget	moveq	#7,d0			; 8 * 128 bytes = 1024 bytes
		moveq	#32,d7			; post-increment is not available here
.getloop	movem.l	(a4),d1-d6/a1-a2	; so we add after each movem
		movem.l	d1-d6/a1-a2,(a0)
		add.l	d7,a0
		movem.l	(a4),d1-d6/a1-a2
		movem.l	d1-d6/a1-a2,(a0)
		add.l	d7,a0
		movem.l	(a4),d1-d6/a1-a2
		movem.l	d1-d6/a1-a2,(a0)
		add.l	d7,a0
		movem.l	(a4),d1-d6/a1-a2
		movem.l	d1-d6/a1-a2,(a0)
		add.l	d7,a0
		dbra	d0,.getloop
	;-- check remaining space
		move.l	(mb_CurrRPos,a5),d0
		add.l	#1024,d0
		cmp.l	(dmn_BufLen,a3),d0	; end of buffer has been reached?
		blo.b	.bufnotend
	;-- reply filled buffer
.bufdone	move.l	a3,a1
		jsr	_EXECReplyMsg(a6)
		clr.l	(mb_CurrRMsg,a5)	; no current buffer
		rts
	;-- update pointers
.bufnotend	move.l	a3,(mb_CurrRMsg,a5)
		move.l	d0,(mb_CurrRPos,a5)
		rts
	;-- error
.error		clr.l	(mb_CurrRMsg,a5)
		rts

	;-- fill a mono buffer
.read_mono	move	#255,d1
.monoloop	subq.l	#2,d0
		bcs	.bufdone
		move	(a4),d2			; left channel
		ext.l	d2
		move	(a4),d3			; right channel
		ext.l	d3
		add.l	d3,d2
		asr.l	#1,d2			; mono value = (left + right) / 2
		move	d2,(a0)+		; write to buffer
		dbra	d1,.monoloop
		move.l	(mb_CurrRPos,a5),d0	; update pointers
		add.l	#512,d0
		cmp.l	(dmn_BufLen,a3),d0
		blo	.bufnotend
		bra	.bufdone

	;-- fill dual buffers
.read_dual	move	#255,d1
		move.l	(edmn_BufPtrR,a3),a1	; A1: ^right buffer
		add.l	(mb_CurrTPos,a5),a1	; A0: ^left buffer
.dualloop	subq.l	#2,d0
		bcs	.bufdone
		move	(a4),(a0)+		; left channel to left buffer
		move	(a4),(a1)+		; right channel to right buffer
		dbra	d1,.dualloop
		move.l	(mb_CurrRPos,a5),d0	; update pointers
		add.l	#512,d0
		cmp.l	(dmn_BufLen,a3),d0
		blo	.bufnotend
		bra	.bufdone
