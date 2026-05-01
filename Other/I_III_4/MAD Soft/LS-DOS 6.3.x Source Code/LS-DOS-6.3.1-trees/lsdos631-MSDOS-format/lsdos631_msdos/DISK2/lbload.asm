;LBLOAD/ASM - LOAD & RUN Commands
	TITLE	<LOAD/RUN - LS-DOS 6.2>
;
CR	EQU	13
@RUN	EQU	77
RST28	EQU	28H
*GET	SVCMAC:3		;SVC Macro equivalents
;
	ORG	2400H
;
;	RUN entry point
;
RUN	JP	RUN0		;RUN entry point
;
;	LOAD entry point
;
LOAD	CALL	COMMON		;Parse parms & filespec
	JR	NZ,IOERR
	LD	A,(XPARM+1)	;If not (X), go to it
	OR	A
	JR	NZ,NEEDPR
	LD	DE,FCB		;Pt to fcb
	@@LOAD
	JR	NZ,IOERR	;Go on error
	JR	EXIT		;  or just exit
;
;	Need to prompt for the system disk
;
NEEDPR	CALL	LOADIT		;Load the file
	JR	NZ,IOERR	;Exit if error
	LD	HL,0		;Init no error
;
;	Get the system disk back in system drive
;
PMTSYS	PUSH	HL		;Save cmd line ptr
	LD	HL,PMTSYS$
	CALL	FLASH
	POP	HL		;Rcvr cmnd line ptr
	RET
;
;	RUN command entry
;
RUN0	CALL	COMMON		;Parse common args
	JR	NZ,IOERR	;Go on error
	LD	A,(XPARM+1)
	OR	A
	LD	DE,FCB
	JR	NZ,RUN1		;Prompt if (X)
	LD	A,@RUN		;RUN SVC number
	JP	RST28
;
RUN1	PUSH	HL		;Save cmnd line ptr
	LD	DE,FCB
	CALL	LOADIT
	EX	(SP),HL		;Get cmd ptr & save ept
	JR	Z,PMTSYS	;Run if prog OK or
	POP	HL		;  pop TRAADR & error
;
;	Error handling
;
IOERR	CP	63		;If extended error
	JR	Z,EXTERR	;  handle by @LOGOT
	LD	L,A		;Put error # into HL
	LD	H,0
	OR	0C0H		;Set short error and ret
	LD	C,A
	@@ERROR
	RET
EXTERR	@@LOGOT
	LD	HL,-1
	RET
EXIT	LD	HL,0
	RET
;
;	Flash the prompt & await reply
;
FLASH0	CALL	RESKFLG		;Reset 3-bit field
FLASH	LD	BC,16893	;Delay for 250 ms
	@@PAUSE
	LD	A,(IY+'K'-'A')
	AND	4!1		;Wait for no ENTER!BRK
	JR	NZ,FLASH0
	CALL	RESKFLG		;Reset in case BREAK
FLS1	@@DSPLY			;Display the message
	JP	NZ,IOERR	;Abort on error
	LD	BC,4000H
	CALL	FLS2		;Blink start
	JR	NZ,GOTBRK	;Handle BREAK
	LD	C,1EH		;Cursor erase to EOL
	CALL	DSP
	LD	BC,3333H	;Wait
	CALL	FLS2		;Wait & ck enter
	JR	NZ,GOTBRK	;Handle BREAK
	JR	FLS1		;Loop until ENTER
;
;	FLS2 - Delay a while & ck on <BREAK/ENTER>
;
FLS2	@@CKBRKC		;<BREAK> hit ?
	JR	Z,CKENT		;No - check <ENTER>
	LD	C,1EH		;Erase Line
	CALL	DSP		;Output byte
	XOR	A		;Set NZ
	INC	A		;
	RET			;And RETurn
;
CKENT	BIT	2,(IY+'K'-'A')	;Ck ENTER bit
	JR	NZ,FLS4		;Go on ENTER down
	DEC	BC		;Count down
	LD	A,B
	OR	C
	JR	NZ,FLS2
	RET			;Return with Z-flag
;
;	ENTER condition found
;
FLS4	POP	AF		;Pop return code
FLS5	@@KBD			;Clear type ahead buffer
	JR	Z,FLS5		;Loop if have character
	LD	C,1EH		;Wipe line
	CALL	DSP
	LD	C,14		;Cursor on
	CALL	DSP
RESKFLG	LD	A,(IY+'K'-'A')	;Reset 3-bit field
	AND	0F8H
	LD	(IY+'K'-'A'),A
	XOR	A		;Set Z-flag
	RET
;
GOTBRK	LD	HL,STOP$	;Point to error message
	LD	A,63		;Init extended error
	RET			;  & return NZ
;
;	Common initialization routine
;
COMMON	LD	DE,PRMTBL	;Parm of X?
	@@PARAM
	RET	NZ		;Ret with error code
COMM1	@@FLAGS			;Get flag table pointer
COMM1A	LD	A,(HL)		;Skip past spaces
	CP	' '
	JR	NZ,COMM2
	INC	HL
	JR	COMM1A
COMM2	LD	DE,FCB		;Get filespec
	@@FSPEC
	JR	NZ,COMM3	;Go on error
	LD	A,(DE)		;Device specs not allowed
	CP	'*'
	JR	NZ,COMM4	;Go if OK
COMM3	LD	HL,SPCREQ$	;Point to error message
	LD	A,63		;Init extended error
	OR	A		;Set NZ condition
	RET
;
COMM4	PUSH	HL		;Save cmdline ptr
	LD	HL,CMDEXT	;Default to CMD
	@@FEXT
	CALL	GOSYS2		;Get SYS2 for open
	POP	HL		;Pop the INBUF$ pointer
	RET	NZ
XPARM	LD	DE,0		;Ck on X parm
	LD	A,D
	OR	E
	RET	Z		;Back on no (X)
	PUSH	HL		;Save pointer
	LD	HL,PMTSRC$	;Init prompt
	CALL	FLASH		;Prompt for source disk
	POP	DE		;Pointer to DE
	RET	NZ		;Back on error in HL
	EX	DE,HL		;If no error, pointer
	RET			;  back to HL
;
;	Call SYS2 for open routine
;
GOSYS2	LD	A,84H		;Load sys2
	RST	28H
;
;	Loading routine
;
LOADIT	LD	DE,FCB
	SET	2,(IY+'S'-'A')	;Turn on RUN flag
	@@LOAD			;Load the file
	RET	Z
	PUSH	AF		;Save error ret code
	CALL	PMTSYS		;Get system disk back
	POP	AF		;Rcvr error ret code
	RET
;
DSP	@@DSP			;Display byte
	RET	Z		;Return if OK
	JP	IOERR
;
;
SPCREQ$	DB	'File spec required',CR
PMTSYS$	DB	15,29,30,'Insert SYSTEM disk <ENTER>',29,3
PMTSRC$	DB	15,29,30,'Insert SOURCE disk <ENTER>',29,3
STOP$	DB	14,29,'Command aborted',CR
;
PRMTBL	DB	80H,41H,'X',0
	DW	XPARM+1
	NOP
;
CMDEXT	DB	'CMD'
FCB	DB	0
	DS	31
;
	END	LOAD
