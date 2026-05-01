;Hdform6/ASM - LDOS X.X - 02/07/84
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
RAM	EQU	-1		;True for 6.x LDOS
RLS	EQU	63H		;Release version # for GAT
;*=*=*
;Define FORM$ and HELLO$
LOGON	MACRO			; dummy macro definiton
	DB	'** Dummy Macro **'
	ENDM
	COM	'<Copyright (C) 1983 by Logical Systems Inc.>'
*GET	BUILDVER/ASM:3			;<631>
*GET	HDFMT1/ASM:3
*GET	HDFMT2/ASM:3
*GET	HDFMT3/ASM:3
	END	BEGIN
