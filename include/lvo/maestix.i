
		INCLUDE	maestix_lib.i

maest		MACRO
		IFNC	"\0","q"
		  move.l maestbase(PC),a6
		ENDC
		jsr	_LVO\1(a6)
		ENDM
