;HDFORM5/ASM - LDOS X.X - 12/12/83
	TITLE	'<Winchester Format - LDOS 5.1 or 6.x>'
;*=*=*
;       Version equates
; set only 1 drive model TRUE (-1)
;*=*=*
ARM	EQU	0
MTI	EQU	0
LDI	EQU	0
LSI	EQU	0
TRS	EQU	-1
PDC	EQU	0
;*=*=*
RAM	EQU	0		;True for 6.x LDOS
RLS	EQU	51H		;Release version # for GAT
;*=*=*
;Define FORM$ and HELLO$
LOGON	MACRO
FORM$	DB	'TRSH1'		;Must match DRIVER name
HELLO$	DB	LF,'TRSFORM - 5.1.4/c - (C) 1982/83/84 by '
	DB	'Logical System, Inc.',0AH
	DB	'All Rights reserved, by LSI, Milwuakee, Wi. 52332',LF,0DH
	ENDM
	COM	'<Copyright (C) 1983 by Logical Systems Inc.>'
*GET	HDFMT1/ASM:3
*GET	HDFMT2/ASM:3
*GET	HDFMT3/ASM:3
	END	BEGIN
