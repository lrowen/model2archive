;CLIENT/ASM - File to establish sign-on headers
; and version numbers.
;
; EACH STRING SHOULD CONTAIN ONLY 63 CHARACTERS !!
;
	IF	@BLD631
;		 12345678901234567890123456789012345678901234567890
	DB	' - 6.3.1 - Copyright 1982/83/84/86/90 by MISOSYS, ';<631>
	DB	'Inc.,       ',10	;<631>
	ELSE
	DB	' - 6.3.0 - Copyright 1982/83/84/86 by Logical Syst'
	DB	'ems, Inc.   ',10
	ENDIF
;
;	DB	'All Rights Reserved. Licensed 1982/83/84 to Tandy '
;	DB	'Corporation.',10,13
;
;	DB	'All Rights Reserved. Beta-TEST Level/AD, DO NOT DI'
;	DB	'STRIBUTE !! ',10,13
;	DB	'All Rights reserved by LSI, 8970 N. 55th St. Milwa'
;	DB	'ukee, Wisc. ',10,13
	DB	'All Rights Reserved. Unauthorized duplication is p'
	DB	'rohibited.  ',10,13
