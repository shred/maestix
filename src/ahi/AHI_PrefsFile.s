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

		INCLUDE	devices/ahi.i
		INCLUDE	libraries/ahi_sub.i

		ORG	0

TRUE		EQU	1		; "AHI-True"
FALSE		EQU	0		; "AHI-False"

AHIDB_MyModeID	EQU	AHIDB_UserBase+0

BEG:

*** FORM AHIM
		dc.b	"FORM"
		dc.l	E-S
S:		dc.b	"AHIM"


*** AUDN
DrvName:	dc.b	"AUDN"
		dc.l	.e-.s
.s		dc.b	"maestropro",0
		even
.e


*** AUDM

ModeA:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0001
		dc.l	AHIDB_MyModeID,$000E0001
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,FALSE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Fix 48k",0
		even
.e

ModeB:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0002
		dc.l	AHIDB_MyModeID,$000E0002
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,FALSE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Input 48k",0
		even
.e

ModeC:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0003
		dc.l	AHIDB_MyModeID,$000E0003
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,FALSE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Input 44.1k",0
		even
.e

ModeD:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0004
		dc.l	AHIDB_MyModeID,$000E0004
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,FALSE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Input 32k",0
		even
.e

ModeE:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0005
		dc.l	AHIDB_MyModeID,$000E0001
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,TRUE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Fix 48k ++",0
		even
.e

ModeF:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0006
		dc.l	AHIDB_MyModeID,$000E0002
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,TRUE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Input 48k ++",0
		even
.e

ModeG:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0007
		dc.l	AHIDB_MyModeID,$000E0003
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,TRUE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Input 44.1k ++",0
		even
.e

ModeH:		dc.b	"AUDM"
		dc.l	.e-.s
.s		dc.l	AHIDB_AudioID,$000E0008
		dc.l	AHIDB_MyModeID,$000E0004
		dc.l	AHIDB_Volume,TRUE
		dc.l	AHIDB_Panning,TRUE
		dc.l	AHIDB_Stereo,TRUE
		dc.l	AHIDB_HiFi,FALSE
		dc.l	AHIDB_MultTable,FALSE
		dc.l	AHIDB_PingPong,FALSE
		dc.l	AHIDB_Name,.name-.s
		dc.l	TAG_DONE
.name		dc.b	"MaestroPro: Input 32k ++",0
		even
.e

		even
E:
END:
