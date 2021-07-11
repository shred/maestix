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

		INCLUDE	exec/nodes.i
		INCLUDE	exec/ports.i
		INCLUDE	lvo/exec.i

		INCLUDE	libraries/maestix.i
		INCLUDE	maestix_lib.i
		INCLUDE	maestixpriv.i

		IFD	_MAKE_68020
		 MACHINE 68020
		ENDC

		SECTION	text,CODE

**
* Queue given audio message for playback.
*
* Also starts playback.
*
*	-> A0.l	^MaestroBase
*	-> A1.l	^Message with audio data
*
		public	TransmitData
TransmitData	movem.l	d0-d7/a0-a6,-(sp)
		move.l	a0,a5
		move.l	(mb_HardBase,a5),a4
		lea	(mh_status,a4),a3	; A3: ^status register
	;-- put message into queue
		move.l	(mb_TPort,a5),a0
		exec	PutMsg
	;-- is transmit FIFO stopped?
		move	(mb_ModusReg,a5),d0
		btst	#MAMB_TFENA,d0		; active? then we're done here
		bne	.done
	;-- start transmit FIFO
		bsr	Lock
	;-- check input signal
		move.l	a1,-(SP)
		moveq	#MSTAT_Signal,d0
		move.l	a5,a0
		bsr	GetStatus
		tst.l	d0			; is there a signal?
		bne	.sigok
		lea	(.switchtag,PC),a1	; no: switch to SRC48K
		move.l	a5,a0
		bsr	SetMaestro
.sigok		move.l	(SP)+,a1
	;-- initialize transmit FIFO
		or	#MAMF_EMUTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		lea	(mh_status,a4),a3	;; TODO: A3 is set again?
		st	(mb_TFirst,a5)		; first access?
		exec	Disable
	;-- synchronize
.waitdwc	move	(a3),d0			;; TODO: timeout
		btst	#MASB_DWC,d0		; wait for DWC to become high
		beq	.waitdwc
.waitsync	move	(a3),d0
		btst	#MASB_DLR,d0		; wait for DLR to become high
		beq	.waitsync
		btst	#MASB_DWC,d0		; weit for DWC to become low
		bne	.waitsync
	;-- enable transmit FIFO and interrupt
		or	#MAMF_TFINTE|MAMF_TFENA,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		exec	Enable
	;-- unmute output
		and	#~MAMF_EMUTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- release hardware
		bsr	Release
	;-- done
.done		movem.l	(SP)+,d0-d7/a0-a6
		rts

	;-- tags for missing input signal
.switchtag	dc.l	MTAG_Input,INPUT_SRC48K
		dc.l	MTAG_Rate,RATE_48000
		dc.l	TAG_DONE


**
* Queue empty receive messages.
*
* Also starts recording.
*
*	-> A0.l	^MaestroBase
*	-> A1.l	^Message with audio data space to be filled
*
		public	ReceiveData
ReceiveData	movem.l	d0-d2/a0/a2-a6,-(sp)
		move.l	a0,a5
		move.l	(mb_HardBase,a5),a4
	;-- send message to receive queue
		move.l	(mb_RPort,a5),a0
		exec	PutMsg
	;-- check receive FIFO
.nothalf	move	(mb_ModusReg,a5),d0
		btst	#MAMB_RFENA,d0		; is enabled? then we're done...
		bne	.rfiforun
	;-- lock hardware
		bsr	Lock
	;-- synchronize
		lea	(mh_status,a4),a3
		exec	Disable			;; TODO: timeout
.waitdwc	move	(a3),d0
		btst	#MASB_DWC,d0		; wait for DWC to become high
		beq	.waitdwc
.waitsync	move	(a3),d0			; wait for DLR to become high
		btst	#MASB_DLR,d0
		beq	.waitsync
		btst	#MASB_DWC,d0		; wait for DWC to become low
		bne	.waitsync
	;-- enable receive FIFO and interrupt
		or	#MAMF_RFENA|MAMF_RFINTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		exec	Enable
	;-- release hardware
		bsr	Release
	;-- done
.rfiforun	movem.l	(sp)+,d0-d2/a0/a2-a6
		rts


**
* Abort playback and flush transmit queue.
*
*		-> A0.l	^MaestroBase
*
		public	FlushTransmit
FlushTransmit	movem.l	d0-d3/a0-a6,-(sp)
		move.l	a0,a5
	;-- lock hardware
		bsr	Lock
	;-- disable transmit FIFO and interrupt, mute output
		move.l	(mb_HardBase,a5),a4
		and	#~(MAMF_TFENA|MAMF_TFINTE)&$FFFF,(mb_ModusReg,a5)
		or	#MAMF_EMUTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- wait for changes to become effective
		move.l	#500,d0			; 500us should be sufficient...
		bsr	TimerDelay
	;-- reply current transmit message
		move.l	(mb_CurrTMsg,a5),d0
		beq	.tloop
		move.l	d0,a1
		exec	ReplyMsg
		clr.l	(mb_CurrTMsg,a5)
	;-- reply all queued transmit messages
.tloop		move.l	(mb_TPort,a5),a0
		exec	GetMsg
		tst.l	d0
		beq	.done
		move.l	d0,a1
		exec	ReplyMsg
		bra	.tloop
	;-- release hardware
.done		bsr	Release			;; TODO: release earlier
	;-- done
		movem.l	(SP)+,d0-d3/a0-a6
		rts


**
* Stop recording and flush receive queue.
*
*	-> A0.l	^MaestroBase
*
		public	FlushReceive
FlushReceive	movem.l	d0-d3/a0-a6,-(sp)
		move.l	a0,a5
	;-- obtain hardware
		bsr	Lock
	;-- stop receive FIFO and interrupts
		move.l	(mb_HardBase,a5),a4
		and	#~(MAMF_RFENA|MAMF_RFINTE),(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- wait for changes to become effective
		move.l	#500,d0			; 500us should be sufficient...
		bsr	TimerDelay
	;-- reply current receive message
		move.l	(mb_CurrRMsg,a5),d0
		beq	.rloop
		move.l	d0,a1
		exec	ReplyMsg
		clr.l	(mb_CurrRMsg,a5)
	;-- reply all queued receive messages
.rloop		move.l	(mb_RPort,a5),a0
		exec	GetMsg
		tst.l	d0
		beq	.done
		move.l	d0,a1
		exec	ReplyMsg
		bra	.rloop
	;-- release hardware
.done		bsr	Release			;; TODO: release earlier
	;-- done
		movem.l	(sp)+,d0-d3/a0-a6
		rts
