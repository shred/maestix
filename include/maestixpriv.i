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

*===================================================================
* THIS FILE CONTAINS PRIVATE STRUCTURE ELEMENTS!
*
* They may be changed or deleted without further notice.
* Do not use them in your own code.
*===================================================================

		INCLUDE	exec/libraries.i
		INCLUDE	exec/lists.i
		INCLUDE	exec/nodes.i
		INCLUDE	exec/ports.i
		INCLUDE	exec/types.i
		INCLUDE	exec/semaphores.i

		INCLUDE	libraries/maestix.i

*===================================================================
* The hardware registers and status/modus bits are based on reverse
* engineering, and on the YM3437C and YM3623B datasheets.
*===================================================================

	; MAESTRO PRO HARDWARE REGISTERS
mh_rfifo	EQU	$0000		; Receive FIFO
mh_r_sync	EQU	$1000		; Read Sample Synchronously
mh_rudb		EQU	$2000		; Receive UDB
mh_rudb_sync	EQU	$3000		; Read UDB Synchronously
mh_status	EQU	$4000		; Status
mh_modus	EQU	$5000		; Modus
mh_tfifo	EQU	$6000		; Transmit FIFO
mh_t_sync	EQU	$7000		; Write Sample Synchronously
mh_sleep	EQU	$8000		; Read: Sleep Mode, Write: Power Up

	; THE MODUS REGISTER
MAMB_ECLD	EQU	0		; T: Word Clock
MAMF_ECLD	EQU	1<<MAMB_ECLD
MAMB_ECIN	EQU	1		; T: Data Input
MAMF_ECIN	EQU	1<<MAMB_ECIN
MAMB_ECLK	EQU	2		; T: Data Clock
MAMF_ECLK	EQU	1<<MAMB_ECLK
MAMB_EMUTE	EQU	3		; T: Mute
MAMF_EMUTE	EQU	1<<MAMB_EMUTE
MAMB_ECNTR	EQU	4		; T: Local Sample Address Reset
MAMF_ECNTR	EQU	4<<MAMB_ECNTR
MAMB_EVFL	EQU	5		; T: Validity Flag
MAMF_EVFL	EQU	5<<MAMB_EVFL
MAMB_DSEL	EQU	6		; R: DS1/DS2 Mode Selector
MAMF_DSEL	EQU	1<<MAMB_DSEL
MAMB_OUTPUT	EQU	7		; Output Source: H:FIFO L:Receiver
MAMF_OUTPUT	EQU	1<<MAMB_OUTPUT
MAMB_INPUT	EQU	8		; Input Source: H:Coaxial L:Optical
MAMF_INPUT	EQU	1<<MAMB_INPUT
MAMB_BYPASS	EQU	9		; Output Bypass: H:Output Source L:Input Source
MAMF_BYPASS	EQU	1<<MAMB_BYPASS
MAMB_RFENA	EQU	10		; R-FIFO: Enable
MAMF_RFENA	EQU	1<<MAMB_RFENA
MAMB_TFENA	EQU	11		; T-FIFO: Enable
MAMF_TFENA	EQU	1<<MAMB_TFENA
MAMB_ERSTN	EQU	12		; T: System Reset
MAMF_ERSTN	EQU	1<<MAMB_ERSTN
MAMB_DKMODE	EQU	13		; R: Internal Clock Mode
MAMF_DKMODE	EQU	1<<MAMB_DKMODE
MAMB_RFINTE	EQU	14		; R-FIFO: Interrupt Enable
MAMF_RFINTE	EQU	1<<MAMB_RFINTE
MAMB_TFINTE	EQU	15		; T-FIFO: Interrupt Enable
MAMF_TFINTE	EQU	1<<MAMB_TFINTE

	; THE STATUS REGISTER
MASB_REMPTY	EQU	0		; R-FIFO: Empty
MASF_REMPTY	EQU	1<<MASB_REMPTY
MASB_RHALF	EQU	1		; R-FIFO: Half Full
MASF_RHALF	EQU	1<<MASB_RHALF
MASB_RFULL	EQU	2		; R-FIFO: Full
MASF_RFULL	EQU	1<<MASB_RFULL
MASB_TEMPTY	EQU	3		; T-FIFO: Empty
MASF_TEMPTY	EQU	1<<MASB_TEMPTY
MASB_THALF	EQU	4		; T-FIFO: Half Full
MASF_THALF	EQU	1<<MASB_THALF
MASB_TFULL	EQU	5		; T-FIFO: Full
MASF_TFULL	EQU	1<<MASB_TFULL
MASB_DKMODE	EQU	6		; Reflects DKMODE
MASF_DKMODE	EQU	1<<MASB_DKMODE
MASB_INTREQ	EQU	7		; Interrupt was requested
MASF_INTREQ	EQU	1<<MASB_INTREQ
MASB_SLEEP	EQU	8		; H: Sleeping, L: Powered Up
MASF_SLEEP	EQU	1<<MASB_SLEEP
MASB_DDEP	EQU	9		; R: De-Emphasis
MASF_DDEP	EQU	1<<MASB_DDEP
MASB_DERR	EQU	10		; R: Parity Error
MASF_DERR	EQU	1<<MASB_DERR
MASB_DS1	EQU	11		; R: Rate / Copy Enabled
MASF_DS1	EQU	1<<MASB_DS1
MASB_DS2	EQU	12		; R: Rate / DAT Source
MASF_DS2	EQU	1<<MASB_DS2
MASB_DSSYNC	EQU	13		; R: Subcode Sync
MASF_DSSYNC	EQU	1<<MASB_DSSYNC
MASB_DWC	EQU	14		; R: Word Clock
MASF_DWC	EQU	1<<MASB_DWC
MASB_DLR	EQU	15		; R: Left/Right Channel
MASF_DLR	EQU	1<<MASB_DLR

	; VARIABLES
		rsreset
mb_HardBase	rs.l	1		; ^Hardware Base (0: not allocated)
mb_ModusReg	rs.w	1		; Copy of modus register
mb_TPort	rs.l	1		; ^Transmit MsgPort
mb_RPort	rs.l	1		; ^Receive MsgPort
mb_IntServer	rs.l	1		; ^Int Server Node
mb_CurrTMsg	rs.l	1		; ^Current transmit Message or 0
mb_CurrTPos	rs.l	1		; Current position in Message
mb_CurrRMsg	rs.l	1		; ^Current receive Message or 0
mb_CurrRPos	rs.l	1		; Current position in Message
mb_CSB		rs.l	1		; Channel Status Bits
mb_UDB		rs.l	1		; User Data Bits
mb_UseUDB	rs.b	1		; -1: UDBs are in use
mb_RError	rs.b	1		; -1: Receive Error
mb_TError	rs.b	1		; -1: Transmit Error
mb_AllocOnly	rs.b	1		; -1: Card is allocated only
mb_RealtimeFX	rs.b	1		; -1: Realtime Effects
mb_LevelFlag	rs.b	1		; -1: Enable PostLevel
mb_RT_Call	rs.l	1		; ^Realtime FX Function
mb_RT_A0	rs.l	1		; Realtime FX A0 value
mb_RT_A1	rs.l	1		; Realtime FX A1 value
mb_RT_D2	rs.l	1		; Realtime FX D2 value
mb_RT_D3	rs.l	1		; Realtime FX D3 value
mb_RT_D6	rs.l	1		; Realtime FX D6 aggregator value
mb_RT_D7	rs.l	1		; Realtime FX D7 aggregator value
mb_OldInput	rs.l	1		; Old input value
mb_OldOutput	rs.l	1		; Old output value
mb_PostLevelR	rs.w	1		; Output level R
mb_PostLevelL	rs.w	1		; Output level L
mb_Semaphore	rs.b	SS_SIZE		; Access Semaphore
mb_SIZEOF	rs.w	0

	; LIBRARY BASE
		rsreset
mab_Library	rs.b	LIB_SIZE	; library node
		; PUBLIC
mab_DefInput	rs.b	1		; default input: 0=optical, -1=coax
mab_DefStudio	rs.b	1		; default mode: 0=normal, -1=studio
mab_AllocMstx	rs.l	1		; ^MaestroBase for AllocMstx
mab_Delay	rs.l	1		; DAT setup delay (ms)
		; PRIVATE
mab_Flags	rs.w	1		; Flags
mab_SysLib	rs.l	1		; ^SysBase
mab_SegList	rs.l	1		; ^SegBase
mab_SIZEOF	rs.w	0

	; PRIVATE TAGS
MTAG_AllocOnly	EQU	_MSTXTAG+$0B	; Only allocate the hardware

	; PRIVATE FLAGS
MALB_DELEXP	EQU	0		; Delay expunge
MALF_DELEXP	EQU	1<<MALB_DELEXP
