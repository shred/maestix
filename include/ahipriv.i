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

		rsreset
ahb_Library	rs.b	LIB_SIZE	; Library-Node
ahb_Flags	rs.w	1		; Flags
ahb_SysLib	rs.l	1		; ^SysBase
ahb_SegList	rs.l	1		; ^SegBase
ahb_SIZEOF	rs.w	0

AHLB_DELEXP	EQU	0		; delay expunge
AHLF_DELEXP	EQU	1<<AHLB_DELEXP

TAG_MSTXBASE	EQU	$000E0000	; Maestix base for AHI
