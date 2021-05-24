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

		INCLUDE	exec/execbase.i
		INCLUDE	exec/interrupts.i
		INCLUDE	exec/nodes.i
		INCLUDE	exec/ports.i
		INCLUDE	libraries/configvars.i
		INCLUDE	utility/tagitem.i
		INCLUDE	lvo/exec.i
		INCLUDE	lvo/expansion.i
		INCLUDE	lvo/utility.i

		INCLUDE	libraries/maestix.i
		INCLUDE	maestix_lib.i
		INCLUDE	maestixpriv.i

		SECTION	text,CODE

		IFD	_MAKE_68020
		 MACHINE 68020
		ENDC

**
* Start a realtime effect.
*
* Other playbacks or recordings must be stopped before.
*
*	-> A0.l	^MaestroBase
*	-> A1.l	^Tags (NULL: no tags)
*
* Tags:
* 	MTAG_Effect	Effect to be used
*	MTAG_A0		A0 parameter
*	MTAG_A1		A1 parameter
*	MTAG_D2		D2 parameter
*	MTAG_D3		D3 parameter
*	MTAG_CustomCall	Use a custom effect
*	MTAG_PostLevel	Activate level meter
*
		public	StartRealtime
StartRealtime	movem.l	d0-d7/a0-a6,-(sp)
		move.l	a0,a5
		move.l	a1,a4
	;-- obtain hardware semaphore
		lea	(mb_Semaphore,a5),a0
		exec	ObtainSemaphore
	;-- realtime FX already running?
		tst.b	(mb_RealtimeFX,a5)
		bne	.done			; yes: leave
		st	(mb_RealtimeFX,a5)	; otherwise mark as in use
	;-- evaluate FX callback pointer
		move.l	a4,a0
		move.l	#MTAG_Effect,d0		; what effect?
		moveq	#RFX_Bypass,d1		; default: bypass
		utils	GetTagData
		cmp.l	#_RFX_COUNT,d0		; unknown effect?
		bhs	.done			; then do nothing
		lea	(FX_tab,PC),a0		; find matching effect handler
		IFD	_MAKE_68020
		 move.l	(a0,d0.l*4),d1
		ELSE
		 add.l	d0,d0
		 add.l	d0,d0
		 move.l	(a0,d0.l),d1
		ENDC
		move.l	a4,a0			; custom effect?
		move.l	#MTAG_CustomCall,d0
		utils	GetTagData
		move.l	d0,(mb_RT_Call,a5)	; set callback pointer
	;-- A0 parameter
		move.l	a4,a0
		move.l	#MTAG_A0,d0
		moveq	#0,d1
		utils	GetTagData
		move.l	d0,(mb_RT_A0,a5)
	;-- A1 parameter
		move.l	a4,a0
		move.l	#MTAG_A1,d0
		moveq	#0,d1
		utils	GetTagData
		move.l	d0,(mb_RT_A1,a5)
	;-- D2 parameter
		move.l	a4,a0
		move.l	#MTAG_D2,d0
		moveq	#0,d1
		utils	GetTagData
		move.l	d0,(mb_RT_D2,a5)
	;-- D3 parameter
		move.l	a4,a0
		move.l	#MTAG_D3,d0
		moveq	#0,d1
		utils	GetTagData
		move.l	d0,(mb_RT_D3,a5)
	;-- post level meter
		move.l	a4,a0
		move.l	#MTAG_PostLevel,d0
		moveq	#0,d1
		utils	GetTagData
		tst.l	d0
		sne	(mb_LevelFlag,a5)
	;-- initialize FIFOs
		move.l	(mb_HardBase,a5),a4
		or	#MAMF_EMUTE,(mb_ModusReg,a5)	; turn on mute
		move	(mb_ModusReg,a5),(mh_modus,a4)
		lea	(mh_status,a4),a3
		st	(mb_TFirst,a5)		; flag first access
	;-- synchronize
		exec	Disable			;; TODO: timeout
.waitdwc	move	(a3),d0
		btst	#MASB_DWC,d0		; wait for DWC to become high
		beq	.waitdwc
.waitsync	move	(a3),d0
		btst	#MASB_DLR,d0		; wait for DLR to become high
		beq	.waitsync
		btst	#MASB_DWC,d0		; wait for DWC to become low
		bne	.waitsync
	;-- enable FIFOs and interrupts
		or	#MAMF_TFENA|MAMF_RFENA|MAMF_RFINTE|MAMF_TFINTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		exec	Enable
	;-- unmute
		and	#~MAMF_EMUTE,(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
	;-- release hardware semaphore
.done		lea	(mb_Semaphore,a5),a0
		exec	ReleaseSemaphore
	;-- done
		movem.l	(SP)+,d0-d7/a0-a6
		rts


**
* Modify a running realtime FX.
*
*	-> A0.l	^MaestroBase
*	-> A1.l	^Tags (NULL: none)
*
* Tags:
*	MTAG_A0		New A0 value
*	MTAG_A1		New A1 value
*	MTAG_D2		New D2 value
*	MTAG_D3		New D3 value
*
		public	UpdateRealtime
UpdateRealtime	movem.l	d0-d7/a0-a6,-(SP)
		move.l	a0,a5
		move.l	a1,a4
	;-- obtain hardware semaphore
		lea	(mb_Semaphore,a5),a0
		exec	ObtainSemaphore
	;-- is a realtime FX active?
		tst.b	(mb_RealtimeFX,a5)
		beq	.done			; no: leave
	;-- update A0 value
		move.l	a4,a0
		move.l	#MTAG_A0,d0
		utils	FindTagItem
		tst.l	d0
		beq	.no_a0
		move.l	d0,a0
		move.l	(4,a0),(mb_RT_A0,a5)
	;-- update A1 value
.no_a0		move.l	a4,a0
		move.l	#MTAG_A1,d0
		utils	FindTagItem
		tst.l	d0
		beq	.no_a1
		move.l	d0,a0
		move.l	(4,a0),(mb_RT_A1,a5)
	;-- update D2 value
.no_a1		move.l	a4,a0
		move.l	#MTAG_D2,d0
		utils	FindTagItem
		tst.l	d0
		beq	.no_d2
		move.l	d0,a0
		move.l	(4,a0),(mb_RT_D2,a5)
	;-- update D3 value
.no_d2		move.l	a4,a0
		move.l	#MTAG_D3,d0
		utils	FindTagItem
		tst.l	d0
		beq	.no_d3
		move.l	d0,a0
		move.l	(4,a0),(mb_RT_D3,a5)
.no_d3	;-- release hardware semaphore
.done		lea	(mb_Semaphore,a5),a0
		exec	ReleaseSemaphore
	;-- done
		movem.l	(SP)+,d0-d7/a0-a6
		rts


**
* Stop realtime FX.
*
*	-> A0.l	^MaestroBase
*
		public	StopRealtime
StopRealtime	movem.l	d0-d3/a0-a6,-(sp)
		move.l	a0,a5
	;-- obtain hardware semaphore
		lea	(mb_Semaphore,a5),a0
		exec	ObtainSemaphore
	;-- is realtime FX active?
		tst.b	(mb_RealtimeFX,a5)
		beq	.done			; no: nothing to do
	;-- disable FIFOs and interrupts
		move.l	(mb_HardBase,a5),a4	;; TODO: mute
		exec	Disable
		and	#!(MAMF_TFENA|MAMF_RFENA|MAMF_TFINTE|MAMF_RFINTE),(mb_ModusReg,a5)
		move	(mb_ModusReg,a5),(mh_modus,a4)
		exec	Enable
	;-- clear realtime state
		sf	(mb_RealtimeFX,a5)
		sf	(mb_LevelFlag,a5)
	;-- wait for clean exit
		move.l	#500,d0			; 500us should be sufficient
		bsr	TimerDelay
	;-- release hardware semaphore
.done		lea	(mb_Semaphore,a5),a0
		exec	ReleaseSemaphore
	;-- done
		movem.l	(sp)+,d0-d3/a0-a6
		rts


**
* Read post level from level meter.
*
* Current level is also cleared.
*
*	-> A0.l	^MaestroBase
*	-> A1.l	^Tags (currently ignored, set to NULL)
*	<- D0.l LSB: left, MSB: right level
*
		public	ReadPostLevel
ReadPostLevel	move.l	(mb_PostLevelR,a0),d0	;; TODO requires offset order, ugly
		clr.l	(mb_PostLevelR,a0)
		rts


**
* Table of realtime effects
*
FX_tab		dc.l	Muting, Bypass, ChannelSwap, LeftOnly
		dc.l	RightOnly, Mono, Surround, Volume
		dc.l	Karaoke, Foregnd, Spatial, Echo
		dc.l	Mask, Offset, Robot, ReSample
*
* ALL THE FOLLOWING REALTIME EFFECTS GET THESE PARAMETERS:
*	-> D0.w	Left channel sample
*	-> D1.w	Right channel sample
*	-> D2.l	D2 parameter
*	-> D3.l	D3 parameter
*	-> A0.l A0 parameter
*	-> A1.l A1 parameter
*	-> A2.l	^return address (do not use rts)
*	<- D0.w New left channel sample
*	<- D1.w New right cannel sample
*
* The realtime effects will ignore all parameters unless noted otherwise.
**


**
* Muting: Mute both channels.
*
Muting		moveq	#0,d0
		moveq	#0,d1
		jmp	(a2)


**
* Bypass: Do nothing.
*
Bypass		jmp	(a2)


**
* ChannelSwap: Swap both channels.
*
ChannelSwap	exg	d0,d1
		jmp	(a2)


**
* LeftOnly: Mute right channel.
*
LeftOnly	moveq	#0,d1
		jmp	(a2)


**
* RightOnly: Mute left channel.
*
RightOnly	moveq	#0,d0
		jmp	(a2)


**
* Mono: Convert to mono.
*
Mono		ext.l	d0
		ext.l	d1
		add.l	d1,d0
		asr.l	#1,d0		; D0 = (D0 + D1) / 2
		move	d0,d1		; D1 is the same
		jmp	(a2)


**
* Surround: Create a pseudo surround sound.
*
Surround	ext.l	d0
		ext.l	d1
		sub.l	d1,d0
		asr.l	#1,d0		; D0 = (D1 - D0) / 2
		move	d0,d1		; D1 is the same
		jmp	(a2)


**
* Volume: Change volume.
*
* 	-> D2.l	Left volume (0..255)
*	-> D3.l	Right volume (0..255)
*
Volume		muls	d2,d0
		asr.l	#8,d0
		muls	d3,d1
		asr.l	#8,d1
		jmp	(a2)


**
* Karaoke: Remove center channel.
*
Karaoke		ext.l	d0
		ext.l	d1
		move.l	d1,d2
		add.l	d0,d2
		asr.l	#1,d2		; D2 = (D0 + D1) / 2 (center signal)
		sub.l	d2,d1		; D1 = D1 - D2
		sub.l	d2,d0		; D0 = D0 - D2
		jmp	(a2)


**
* Foreground: Compute surround front channels.
*
Foregnd		ext.l	d0
		ext.l	d1
		move.l	d1,d2
		sub.l	d0,d2
		asr.l	#1,d2		; D2 = (D0 - D1) / 2 (surround signal)
		sub.l	d2,d1		; D1 = D1 - D2
		add.l	d2,d0		; D0 = D0 - D2
		jmp	(a2)


**
* Spatial: Simulate spatial sound.
*
*	-> D2.l	Effect intensity (0..255)
*
Spatial		ext.l	d0
		ext.l	d1
		move	d0,d6
		muls	d2,d6
		asr.l	#8,d6		; D6 = left signal, dampened by D2
		move	d1,d7
		muls	d2,d7
		asr.l	#8,d7		; D7 = right signal, dampened by D2
		add.l	d6,d1
		add.l	d7,d0
		asr.l	#1,d1		; D1 = (D1 + D6) / 2
		asr.l	#1,d0		; D0 = (D0 + D7) / 2
		jmp	(a2)


**
* Echo: Generate an echo. Requires a lot of CPU power.
*
*	-> A0.l	^Ring buffer
*	-> D2.l Starting volume (0..256)
*	-> D3.l Reverb volume (0..256)
*
Echo		move	d5,-(sp)
		move	d0,d5
		move.l	(mrtor_PointerL,a0),a1
		move.l	(mrtor_Offset,a0),d6
		move	(a1,d6.l),d7
		ext.l	d7
		ext.l	d0
		add.l	d7,d0
		asr.l	#1,d0
		move	(a1,d6.l),d7		; current word
		muls	d3,d7			; generate reverb
		asr.l	#8,d7
		muls	d2,d5			; starting volume
		asr.l	#8,d5
		add.l	d5,d7			; sum
		asr.l	#1,d7
		move	d7,(a1,d6.l)		; this is the new value
		move	d1,d5
		move.l	(mrtor_PointerR,a0),a1
		move	(a1,d6.l),d7
		ext.l	d7
		ext.l	d1
		add.l	d7,d1
		asr.l	#1,d1
		move	(a1,d6.l),d7		; current word
		muls	d3,d7			; generate reverb
		asr.l	#8,d7
		muls	d2,d5			; starting volume
		asr.l	#8,d5
		add.l	d5,d7			; sum
		asr.l	#1,d7
		move	d7,(a1,d6.l)		; this is the new value
		addq.l	#2,d6			; increment ring buffer pointer
		cmp.l	(mrtor_Size,a0),d6
		blo	.isok
		sub.l	(mrtor_Size,a0),d6
.isok		move.l	d6,(mrtor_Offset,a0)
		move	(sp)+,d5
		jmp	(a2)


**
* Mask: Quantisize input signal.
*
*	-> D2.l	Left mask
*	-> D3.l Right mask
*
Mask		and	d2,d0
		and	d3,d1
		jmp	(a2)


**
* Offset: Adds a DC offset to the signal.
*
*	-> D2.l	Left offset
*	-> D3.l	Right offset
*
Offset		add	d2,d0
		bvc	.noovll			; avoid clipping
		bmi	.neg_l
		move	#32767,d0
		bra	.noovll
.neg_l		move	#-32768,d0
.noovll		add	d3,d1
		bvc	.noovlr			; avoid clipping
		bmi	.neg_r
		move	#32767,d1
		bra	.noovlr
.neg_r		move	#-32768,d1
.noovlr		jmp	(a2)


**
* Robot: Simulate a robot voice.
*
*	-> D2.l	Length of open gate
*	-> D3.l	Length of closed gate
*	-> A0.l	Robot structure
*
Robot		move.l	(mrrob_Counter,a0),d7	; sample counter
		addq.l	#1,d7			;   decrement
		bmi	.gate_close
		cmp.l	d2,d7
		blo	.done			; gate is still open
		move.l	d3,d7
		beq	.done
		neg.l	d7
.gate_close	moveq	#0,d0			; gate is closed
		moveq	#0,d1
.done		move.l	d7,(mrrob_Counter,a0)	; remember counter
		jmp	(a2)


**
* ReSample: Sample to a different rate.
*
*	-> D2.l	Rate left
*	-> D3.l	Rate right
*	-> A0.l	ReSample structure
*
ReSample	move	(mrres_LCounter,a0),d6	; collect left channel
		add	d2,d6
		move	(mrres_LMax,a0),d7
		cmp	d7,d6
		blo	.l_ok
		sub	d7,d6
		move	d0,(mrres_LData,a0)
		bra	.l_done
.l_ok		move	(mrres_LData,a0),d0	; restart collection
.l_done		move	d6,(mrres_LCounter,a0)
		move	(mrres_RCounter,a0),d6	; collect right channel
		add	d3,d6
		move	(mrres_RMax,a0),d7
		cmp	d7,d6
		blo	.r_ok
		sub	d7,d6
		move	d1,(mrres_RData,a0)
		bra	.r_done
.r_ok		move	(mrres_RData,a0),d1	; restart collection
.r_done		move	d6,(mrres_RCounter,a0)
		jmp	(a2)
