;LBROUTE/ASM - ROUTE Command
	TITLE	<ROUTE - LS-DOS 6.2>
;
CR	EQU	13
PAR_ERR	EQU	44		;Parameter Error
;
*GET	SVCMAC:3		;SVC Macro equivalents
;
	ORG	2400H
;
;	Save stack & call Route routine
;
ROUTE	LD	(SAVESP+1),SP	;Save Stack
	CALL	ROUTE1		;Call route routine
EXIT	LD	HL,0		;Clean Exit
	JR	SAVESP
;
;	I/O Error Handling
;
PRMERR	LD	A,PAR_ERR	;Parameter Error
IOERR	LD	L,A
	LD	H,0
	OR	0C0H		;Set abbrev & return
	LD	C,A
	@@ERROR
	JR	SAVESP		;P/u stack & return
;
;	Internal Error Message Handling
;
CANT	LD	HL,CANT$	;"No mem space...
	DB	0DDH
SPCERR	LD	HL,SPCERR$	;"Devspec req...
	@@LOGOT
ERREXIT	LD	HL,-1		;Set abort code
;
;	P/u stack & Clear any pending <BREAK>
;
SAVESP	LD	SP,$-$		;P/u stack
	@@CKBRKC		;Clear any Break
	RET
;
;	ROUTE1 - Route spec to spec
;
ROUTE1	LD	DE,FCBSRC	;Fetch source spec
	@@FSPEC
	JR	NZ,SPCER	;Jump on error
	LD	A,(DE)
	CP	'*'		;Must be a device
	JR	NZ,SPCER	;Jump if not
	LD	DE,PRMTBL$	;Get parameters
	@@PARAM
	JR	NZ,PRMERR	;Jump on parm error
	LD	DE,(FCBSRC+1)	;Stuff source name
	LD	(RTENAM+3),DE
	@@FLAGS			;Get flag table pointer
;
;	Test NIL parameter
;
NPARM	LD	BC,0		;P/u NIL parm
	LD	A,B
	OR	C
	JP	NZ,NILDCB	;Jump if NIL entered
;
;	Route to device/file - check which
;
	LD	DE,FCBDST	;Fetch destination spec
	@@FSPEC
SPCER	JP	NZ,SPCERR	;Jump on error
	PUSH	DE
	LD	DE,PRMTBL$
	@@PARAM			;Need in case REWIND
	POP	DE
	JR	NZ,PRMERR	;Exit on parm error
	LD	A,(DE)
	CP	'*'		;Test device/file
	JR	NZ,INITFCB	;Jump on file
;
;	Destination spec is a device
;
	LD	DE,(FCBDST+1)	;P/u device name
	LD	HL,(FCBSRC+1)	;Make sure SRC<>DST
	SBC	HL,DE		;  CF is reset
	JP	Z,SPCERR
	@@GTDCB			;Find in tables
	JP	NZ,IOERR	;Jump if not found
CKDCBS	PUSH	HL		;Save DCB address of dest
	CALL	CKSRC		;Locate source DCB
	JP	NZ,IOERR
CKDCB1	EQU	$
	DI
	POP	BC		;Rcvr dest route vector
	PUSH	HL		;Save DCB+0
;
;	Save the old device vector while stuffing new
;
	INC	L		;Bump to vector
	LD	A,(HL)		;Save what's there
	LD	(HL),C		;Stuff dest route
	LD	C,A		;  into DCB of source
	INC	L		;  while saving old
	LD	A,(HL)		;  vector for storage
	LD	(HL),B		;  (could be a FCB)
	LD	B,A
;
;	Now set ROUTE bit and rest of DCB block
;
	POP	HL		;Rcvr ptr to DCB+0
	LD	A,(HL)		;Init the ROUTE bit
	PUSH	AF		;Save old TYPE byte
	AND	7		;Strip any flag bits
	OR	10H
	LD	(HL),A		;Show source is routed
	LD	A,L
	ADD	A,7		;Point to name field
	LD	L,A
	LD	(HL),D		;And stuff in the name
	DEC	L		;  in case this is a
	LD	(HL),E		;  new DCB block
	POP	AF		;P/u old TYPE byte &
	BIT	4,A		;  save old data if
	JR	NZ,CKDCB2	;  not already routed
	DEC	L
	LD	(HL),B		;Stuff old vector
	DEC	L		;  for reclamation
	LD	(HL),C
	DEC	L
	LD	(HL),A		;Stuff old TYPE
CKDCB2	EQU	$
	EI
	RET			;Successful
;
;	Destination is file - init it & posn to end
;
INITFCB	PUSH	DE
	LD	DE,RTENAM	;See if space already
	@@GTMOD			;  allocated for this
	POP	DE
	JR	NZ,NOTRES	;  device name
;
;	Space in memory, re-use it
;
	INC	HL		;Get last byte used
	INC	HL		;  into HL
	LD	A,(HL)
	INC	HL
	LD	H,(HL)
	LD	L,A
	XOR	A		;Set a 0 to show
	LD	(CKIFRES+1),A	;  already resident
	JR	SETBUF
;
;	Not yet resident, get space
;
NOTRES	BIT	0,(IY+'C'-'A')	;Can we alter HIGH$?
	JP	NZ,CANT		;Can't if frozen
	LD	HL,0		;Get high
	LD	B,L
	@@HIGH$
SETBUF	LD	(RTEDVR+2),HL	;Stuff highest used
	INC	HL		;Reserve a page for
	DEC	H		;  the I/O buffer
	PUSH	HL		;Don't lose it
	LD	B,0		;LRL = 0
	@@INIT			;Init the file
	JR	NZ,INITF1	;What? an error?
RPARM	LD	BC,0		;Ck on rewind (no peof)
	INC	B		;Keep file at start
	JR	Z,INITF1	;  if REWIND specified
	@@PEOF			;  else posn file
	JR	Z,INITF1	;  to the end
	CP	1CH		;At End Of File?
INITF1	POP	HL		;Get back buffer pointer
	JP	NZ,IOERR	;Any other error, JuMp
	LD	BC,32+14	;Back up another 32
	XOR	A		;  for the FCB storage
	SBC	HL,BC		;  + 14 for linkage
	PUSH	HL		;Save module start
;
;	Bypass HIGH$ stuff if "ISRES"
;
CKIFRES	OR	-1		;"OR 0" if "ISRES"
	JR	Z,ISRES1
	DEC	HL		;Reset HIGH$ (B=0)
	@@HIGH$			;Stuff new high$
ISRES1	POP	DE		;Rcvr module pointer
	PUSH	DE
	LD	HL,RTEDVR	;Move module to memory
	LDIR
	POP	DE		;Now adjust to true
	LD	HL,14		;  FCB loc'n
	ADD	HL,DE
	JP	CKDCBS		;Go check dcbs
;
;	Scan device tables for source device
;
CKSRC	LD	DE,(FCBSRC+1)	;P/u source device name
	PUSH	DE		;  & save it for later
	@@GTDCB			;Find device in table
	JR	Z,CKSRC1	;Use it if found
	LD	DE,0		;  else find a spare
	@@GTDCB			;  DCB block
	LD	A,33		;Init "No device space...
	JR	NZ,CKSRC2	;Abort if no space
CKSRC1	PUSH	HL
	CALL	CLSFILS		;Close any existing
	POP	HL		;  file routes
CKSRC2	POP	DE		;Recover source name
	RET
;
;	NIL entered, close up any open file
;
NILDCB	CALL	CKSRC		;Check on devqice
	LD	A,(HL)		;Get type byte
	OR	8
	LD	(HL),A		;Show is NIL device
	LD	A,L		;Pt to name field
	ADD	A,6
	LD	L,A
	DI
	LD	(HL),E		;Stuff in our name
	INC	L		;  in case it's a new
	LD	(HL),D		;  DCB block
	EI
	RET			;Successful
;
;	Find the last device route & close any open file
;
CLSFILS	BIT	4,(HL)		;Jump if no route
	JR	Z,CLSFIL1
	INC	HL		;Else p/u link address
	LD	A,(HL)		;  and test that one
	INC	HL		;  for a chain
	LD	H,(HL)
	LD	L,A
	JR	CLSFILS
CLSFIL1	BIT	7,(HL)		;A file?
	RET	Z		;Ret if not
	LD	DE,FCBFIL	;Pt to fcb area
	PUSH	DE
	LD	BC,32
	LDIR			;Fill from device vector
	POP	DE		;Recover start
	@@CLOSE			;Close the file
	RET			;Ret with Z, NZ status
;
;	Messages
;
CANT$	DB	'No memory space available',CR
SPCERR$	DB	'Device spec required',CR
;
PRMTBL$	DB	80H,53H,'NIL',0
	DW	NPARM+1
	DB	56H,'REWIND',0
	DW	RPARM+1
	NOP
;
RTEDVR	JR	$		;No real jump
	DW	$-$		;Stuff of high
	DB	5
RTENAM	DB	'RTExx'
	DW	0,0
;
FCBDST	DB	0
	DS	31
FCBFIL	DB	0
	DS	31
FCBSRC	DB	0
	DS	31
;
	END	ROUTE
