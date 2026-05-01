;LBDIR/ASM - DIR / CAT Command
	TITLE	<DIR - LS-DOS 6.3>
;
*GET	BUILDVER/ASM:3
	ORG	2400H
;
ENTRY	JP	DIR		;Go if DIR
;
CATBGN	PUSH	HL		;Here if CAT
	LD	HL,0		;Set the DIR (A
	LD	(APARM+1),HL	;  parameter to OFF
	POP	HL		;  and do a DIR
	JR	ENTRY		;  command
;
BLKHASH	EQU	4296H		;Hash code of blank password
;
*GET SVCMAC:3			;Get SVC Macro equivalents and
*GET  VALUES:3			; other misc. equates
;
*GET LBDIRA:3
*GET LBDIRB:3
*GET LBDIRC:3
;
;	Bytes Free =
;
FREE$	EQU	3000H-ENDMEM
;
	IFGT	$,2FFFH
	ERR	'LIB memory region overflow
	ENDIF
;
	SUBTTL	<>
	END	ENTRY
