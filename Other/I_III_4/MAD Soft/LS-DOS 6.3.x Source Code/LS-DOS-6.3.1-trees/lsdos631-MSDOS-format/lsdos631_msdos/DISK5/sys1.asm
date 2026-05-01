;SYS1/ASM - LS-DOS 6.2
	TITLE	<SYS1 - LS-DOS 6.2>
;
LD___A	EQU	3AH		;LD A,(nnnn)
;
@SMALL	EQU	0		;Switch for "SMALL" or
				;  "FULL" library
;
LIBA	EQU	08000H
LIBB	EQU	0A000H		;Set bit 5
LIBC	EQU	0C000H		;Set bit 6
LF	EQU	10
CR	EQU	13
*LIST	OFF			;Get SYS0/EQU
*GET	BUILDVER/ASM:3		;<631>
*GET	SYS0/EQU:2		;Xref of lowcore/sysres
*LIST	ON
*GET	COPYCOM:3		;Copyright message
;
	ORG	1E00H
;
SYS1	JR	SYS1BGN		;Hop around pointer
	DW	LIBTBL$		;LIBTBL pointer
SYS1BGN	AND	70H		;Strip all but ept
	RET	Z		;Back on zero entry
	CP	10H		;Ck for @EXIT
	JR	Z,CMD
	CP	40H		;Ck for FSPEC
	JP	Z,FSPEC
	CP	50H		;Ck for FEXT
	JP	Z,FEXT
	CP	60H		;Ck for PARAM
	JP	Z,PARAM
	CP	70H		;Ck for vacant entry
	RET	Z
;
;	Entry code for CMNDI (30) and CMNDR (20) SVCs
;
	LD	DE,INBUF$	;Move 79 characters
	PUSH	DE		;  from (HL) to buffer
	LD	BC,79
	LDIR
	EX	DE,HL		;Terminate with ETX
	LD	(HL),3
	POP	HL		;Recover buffer start
	CP	30H		;Ck entry for CMNDI
	JR	Z,CMD30		;Go on CMNDI
	CALL	@CKBRKC		;Clear the Break bit
	LD	A,(CFLAG$)
	OR	2		;Set CMNDR bit
	LD	(CFLAG$),A	;Put it back
	JP	CMD20		;  & go on CMNDR
;
;	Entry for @EXIT & @CMNDI
;
CMD30	CALL	CLEANUP		;Reset Break, stack, etc.
	JR	CMD3A
;
CMD	CALL	CLEANUP		;Reset Break, stack, etc.
	JR	CMDCONT
;
CLEANUP
	DI			;Stop for a moment
	LD	HL,0		;Reset vectored BREAK
	CALL	@BREAK		;  to system
	POP	HL		;P/u local RETurn
	LD	SP,STACK$	;Reset stack pointer
	LD	BC,@EXIT	;Establish ret address
	PUSH	BC
	PUSH	HL		;Put back local return
	LD	A,(SFLAG$)	;DEBUG to be on or off?
	RLCA
	LD	A,0C9H		;Bit 7, 1=on, 0=off
	JR	NC,DBGOFF	;Go if OFF
	XOR	A		;  else reset to on
DBGOFF	LD	(@DBGHK),A
	LD	HL,KFLAG$	;Point to KFLAG$
	LD	A,11111001B	;Reset pause and enter
	AND	(HL)		;Merge together
	LD	(HL),A
	LD	HL,SFLAG$	;Point to SFLAG
	LD	A,11111000B	;Reset 3 lo bits
	AND	(HL)		;Merge with old
	LD	(HL),A
	LD	HL,2FFFH	;Reset LOW$
	LD	(LOW$),HL
;
;	Reset video ram handler pointer
;
	LD	HL,OPREG_SV_AREA
	LD	(OPREG_SV_PTR),HL
	LD	A,(CFLAG$)	;P/u CFLAG
	AND	20H		;Leave only bit 5
	LD	(CFLAG$),A	;  and put it back
	LD	HL,INBUF$	;Point to command line
	PUSH	HL		;Xfer start
	POP	BC		;  to BC
	EI
	CALL	@CKBRKC		;Check and clear BREAK
	RET			;Local cleanup done
;
CMDCONT	LD	A,(EFLAG$)	;P/u ECI flag
	OR	A		;Check if set
	JR	Z,CMD1A		;Go if normal
	OR	10001111B	;Set for SYS13 but
				;  leave user entry code
	RST	40
;
CMD1A	LD	HL,RDYMSG$	;Display ready message
	CALL	@DSPLY
CMD2	LD	HL,CFLAG$	;Let the world know we
	SET	2,(HL)		;  are in the command
	PUSH	HL		;  interpreter
	LD	HL,INBUF$	;Get 79 chars max
	LD	BC,79<8		;No fill char for now
	CALL	@KEYIN
	EX	(SP),HL		;Turn off the interpreter
	RES	2,(HL)		;  bit & reget the buffer
	POP	HL
	JR	C,CMD		;Jump on <BREAK>
;
;	Entry from @EXIT & @CMNDI
;
CMD3A
	LD	A,(HL)		;Check for comment
	CP	'.'		;If so go before CR
	JR	Z,CMD20		;  is displayed
;
	LD	A,CR		;Do a line feed on
	CALL	@DSP		;  CMNDI and @EXIT
;
;	Entry from @CMNDR plus the above
;
;	Always bring in bank 0
;
CMD20	XOR	A		;Prepare for bank-0
	LD	B,A		;Set function and
	LD	C,A		;  bank number to 0
	CALL	@BANK		;Invoke bank 0
;
;	Process the command entry
;
	CALL	@LOGER		;Log the entry
	LD	DE,CFCB$	;Point to command FCB
	LD	A,(HL)		;Jump on comment
	CP	'.'
	JR	Z,COMMENT
	CP	'*'		;Check if alternate CMD
	JR	NZ,CKNOEXC	;  processor needed
	PUSH	HL
	POP	BC		;Get Buffer in BC
	INC	HL		;Move HL past '*'
	LD	A,0FFH		;Set up for SYS13 entry
	RST	40		;  # 7, and do it
CKNOEXC	SUB	'!'		;Test for program force
	JR	NZ,NOEXC
	INC	HL		;Bump past the '!'
NOEXC	LD	(TSTEXC+1),A
	CALL	FSPEC		;Fetch command spec
	JR	NZ,WHAT		;Jump on error
	PUSH	HL		;Save terminator pointer
TSTEXC	LD	A,0		;Test if prog force
	OR	A
	JR	Z,NOTLIB	;Jump if starting "!"
	LD	BC,LIBTBL$	;Pt to tbl of LIB cmds
	CALL	@FNDPRM		;Check for a match
	JR	Z,CMD4		;Jump if it is
NOTLIB	LD	HL,DFTEXT	;Else assume prg file, so
	CALL	FEXT		;  default 'EXT' to CMD
	POP	HL		;Rcvr terminator pointer
	LD	A,(CFLAG$)	;Ck LIB only execution
	AND	10H		;CFLAG$ bit-4
	JP	Z,@RUN		;The program else WHAT?
;
;	Process non-entry
;
WHAT	LD	HL,-1		;Set to show abort
	RET
;
;	Process "dot" comment
;
COMMENT	LD	A,(SFLAG$)	;Ret if <DO> in effect
	BIT	5,A		;  else get another
	JP	Z,CMD2		;  input line
	LD	HL,0		;Set for no error
	RET
;
;	Process LIB command
;
CMD4	POP	HL		;Rcvr terminator pointer
	LD	A,0C9H		;Turn off DEBUG
	LD	(@DBGHK),A
	LD	A,D		;Test bit 7 of high
	RLCA			;  order LIB address
	PUSH	DE		;Ret to address of
	RET	NC		;  vector if bit 7 = 0
	POP	DE
	LD	B,E		;Else put overlay # in
	RLCA			;Calculate needed library
	RLCA			;  by rotating 7-5 into
	ADD	A,84H		;  2-0 & adding RST base
	RST	28H
;
;	BOOT code brings back the ROM
;
BOOTIT	XOR	A		;SVC-0 => @IPL
	RST	40
;
;	LIBRARY look-up table starts here
;
LIBTBL$	EQU	$		;Start of library table
;
	IF	@SMALL
;
;	Use this table for SMALL (OEM) library
;
; DB 'APPEND'
; DW LIBA!31H
	DB	'ATTRIB'
	DW	LIBB!51H
	DB	'AUTO  '
	DW	LIBB!11H
;DB 'BOOT  '
; DW BOOTIT
; DB 'BUILD '
; DW LIBB!33H
; DB 'CAT   '
; DW LIBA!20H
; DB 'CLS   '
; DW LIBA!24H
	DB	'COPY  '
	DW	LIBA!32H
; DB 'CREATE'
; DW LIBB!13H
	DB	'DATE  '
	DW	LIBB!15H
; DB 'DEBUG '
; DW LIBB!14H
; DB 'DEVICE'
; DW LIBA!61H
	DB	'DIR   '
	DW	LIBA!21H
	DB	'DO    '
	DW	LIBA!91H
; DB 'DUMP  '
; DW LIBB!71H
	DB	'FILTER'
	DW	LIBA!66H
	DB	'FORMS '
	DW	LIBC!0B1H
; DB 'FREE  '
; DW LIBB!22H
; DB 'LIB   '
; DW LIBA!19H
; DB 'LINK  '
; DW LIBA!62H
; DB 'LIST  '
; DW LIBA!41H
; DB 'LOAD  '
; DW LIBA!81H
; DB 'MEMORY'
; DW LIBA!1EH
; DB 'PURGE '
; DW LIBB!72H
	DB	'REMOVE'
	DW	LIBA!18H
; DB 'RENAME'
; DW LIBA!53H
; DB 'RESET '
; DW LIBA!63H
; DB 'ROUTE '
; DW LIBA!64H
; DB 'RUN   '
; DW LIBA!82H
	DB	'SET   '
	DW	LIBA!65H
; DB 'SETCOM'
; DW LIBC!0B2H
; DB 'SETKI '
; DW LIBC!0B3H
; DB 'SPOOL '
; DW LIBC!0A2H
	DB	'SYSGEN'
	DW	LIBC!1CH
	DB	'SYSTEM'
	DW	LIBC!0A1H
	DB	'TIME  '
	DW	LIBB!16H
; DB 'TOF   '
; DW LIBA!25H
	DB	'VERIFY'
	DW	LIBB!1BH
	NOP			;Patch 'K' here for KILL
;	DB	'ILL  '
;	DW	LIBA!18H
	NOP
;
;
	ELSE
;
; This table for FULL library
;
	DB	'APPEND'
	DW	LIBA!31H
	DB	'ATTRIB'
	DW	LIBB!51H
	DB	'AUTO  '
	DW	LIBB!11H
	DB	'BOOT  '
	DW	BOOTIT
	DB	'BUILD '
	DW	LIBB!33H
	DB	'CAT   '
	DW	LIBA!20H
	DB	'CLS   '
	DW	LIBA!24H
	DB	'COPY  '
	DW	LIBA!32H
	DB	'CREATE'
	DW	LIBB!13H
	DB	'DATE  '
	DW	LIBB!15H
	DB	'DEBUG '
	DW	LIBB!14H
	DB	'DEVICE'
	DW	LIBA!61H
	DB	'DIR   '
	DW	LIBA!21H
	DB	'DO    '
	DW	LIBA!91H
	DB	'DUMP  '
	DW	LIBB!71H
	DB	'FILTER'
	DW	LIBA!66H
	DB	'FORMS '
	DW	LIBC!0B1H
	DB	'FREE  '
	DW	LIBB!22H
	DB	'ID    '
	DW	LIBA!26H
	DB	'LIB   '
	DW	LIBA!19H
	DB	'LINK  '
	DW	LIBA!62H
	DB	'LIST  '
	DW	LIBA!41H
	DB	'LOAD  '
	DW	LIBA!81H
	DB	'MEMORY'
	DW	LIBA!1EH
	DB	'PURGE '
	DW	LIBB!72H
	DB	'REMOVE'
	DW	LIBA!18H
	DB	'RENAME'
	DW	LIBA!53H
	DB	'RESET '
	DW	LIBA!63H
	DB	'ROUTE '
	DW	LIBA!64H
	DB	'RUN   '
	DW	LIBA!82H
	DB	'SET   '
	DW	LIBA!65H
	DB	'SETCOM'
	DW	LIBC!0B2H
	DB	'SETKI '
	DW	LIBC!0B3H
	DB	'SPOOL '
	DW	LIBC!0A2H
	DB	'SYSGEN'
	DW	LIBC!1CH
	DB	'SYSTEM'
	DW	LIBC!0A1H
	DB	'TIME  '
	DW	LIBB!16H
	DB	'TOF   '
	DW	LIBA!25H
	DB	'VERIFY'
	DW	LIBB!1BH
	NOP			;Patch 'K' here for KILL
;	DB	'ILL  '
;	DW	LIBA!18H
	NOP
;
	ENDIF
;
;
;	Routine to fetch a filespec/devicespec
;
FSPEC	PUSH	DE		;Save pointer to DCB
	CALL	@PARSER		;Parse expected command
	JR	NZ,FSP5		;NZ=not file, ck for device
	CP	'/'		;EXT separator?
	JR	NZ,FSP1
	LD	(DE),A		;File extent coming,
	INC	DE		;  get it
	LD	B,3		;EXT is 3-chars max
	CALL	@PAR1
FSP1	CP	'.'		;Password entered?
	JR	NZ,FSP2
	LD	(DE),A		;Password coming,
	INC	DE		;  get it also
	CALL	@PARSER
	JR	NZ,FSP6		;Return if error
FSP2	CP	':'		;Drive entered?
	JR	NZ,FSP3
	LD	(DE),A		;A one-byte drive
	INC	DE		;  has been had
	LD	B,1
	CALL	@PAR1
	JR	NZ,FSP6		;Return if error
FSP3	CP	'!'		;Update EOF always?
	JR	NZ,FSP4
	LD	(DE),A		;Yes, slow but accurate
	INC	DE		;Inc buffer pointers
	INC	HL
	LD	A,(HL)
FSP4	LD	C,A		;Save separator char
	LD	A,3
	LD	(DE),A		;Stuff an ETX
	IF	@BLD631
	ELSE
	XOR	A
	ENDIF
	LD	A,C		;P/u separator
	POP	DE		;P/u start of DCB
	PUSH	DE
	LD	BC,PREPTBL	;Ck on prepositions
	CALL	@FNDPRM
	POP	DE		;Can use TO, ON,
	JR	Z,FSPEC		;  OVER, USING
	XOR	A
	RET
FSP5	CP	'*'		;Ck on device spec
	JR	NZ,FSP6		;Jump if not device
	LD	(DE),A		;  else stuff the '*'
	INC	DE
	LD	B,2		;Xfer two char device
	CALL	@PAR1
	JR	Z,FSP4		;Terminate buffer
FSP6	POP	DE
	RET
;
;	Preposition table
;
PREPTBL	DB	'TO    '
	DW	SBUFF$
	DB	'ON    '
	DW	SBUFF$
	DB	'OVER  '
	DW	SBUFF$
	DB	'USING '
	DW	SBUFF$
	NOP
;
;	Fetch default file extension
;
FEXT	PUSH	DE		;Save FCB pointer
	PUSH	HL		;Save EXT default pointer
	EX	DE,HL		;Exchange pointers
	INC	HL
	LD	B,9		;Init for 9-char test
FEX1	LD	A,(HL)		;Ret if extension start
	CP	'/'		;  is found
	JR	Z,FEX3
	JR	C,FEX4		;Jump on other separator
	CP	':'		;Jump on digit 0-9
	JR	C,FEX2
	CP	'A'		;Jump on special char
	JR	C,FEX4
FEX2	INC	HL		;Advance past A-Z,0-9
	DJNZ	FEX1
FEX3	POP	HL		;User entered file ext
	POP	DE		;FCB start
	RET
;
;	Use default extension
;
FEX4	LD	BC,15		;Point to position past
	ADD	HL,BC		;  the filespec
	LD	D,H
	LD	E,L
	INC	DE		;Make room for '/EXT'
	INC	DE		;  which is 4 chars
	INC	DE
	INC	DE
	INC	BC		;Now move 16 bytes
	LDDR
	POP	HL		;Recover pointer to EXT
	INC	HL		;Point to 3rd char
	INC	HL
	LD	C,3		;Move in 3 chars
	LDDR
	LD	A,'/'		;Put in the slash
	LD	(DE),A
	POP	DE		;Point back to FCB
	RET
;
;	Get the code for the @PARAM SVC
;
*GET	PARAM:3
;
DFTEXT	DB	'CMD'		;Default extension
RDYMSG$	DB	LF,14,'LS-DOS Ready',CR
;	ELSE
;RDYMSG$	DB	LF,14,'TRSDOS Ready',CR
;	ENDIF
LAST	EQU	$
	IFGT	$,DIRBUF$
	ERR	'Module too big'
	ENDIF
	ORG	MAXCOR$-2
	DW	LAST-SYS1	;Size of overlay
	END	SYS1
