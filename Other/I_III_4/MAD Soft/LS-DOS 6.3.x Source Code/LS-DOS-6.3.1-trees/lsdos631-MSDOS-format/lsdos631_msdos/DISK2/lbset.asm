;LBSET/ASM - Set and Filter commands
	TITLE	<SET/FILTER - LS-DOS 6.2>
;
CR	EQU	13
*GET	SVCMAC:3		;SVC Macro equivalents
;
;	ORG this up here to allow driver programs to
;	load at X'2400' without clobbering this program
;
	ORG	2C00H
;
;	FILTER entry point
;
	JP	FILTER		;Filter entry point
;
;	SET entry point
;
SET	@@FLAGS			;Flag table pointer
	BIT	0,(IY+'C'-'A')	;Can't use if memory
	JP	NZ,CANT		;  is frozen
	LD	DE,DEVFCB	;Get filespec
	@@FSPEC
	JP	NZ,DEVREQ	;Quit if bad name
	LD	A,(DE)		;Ck on devicespec
	CP	'*'
	JP	NZ,DEVREQ	;Must have device
	LD	DE,PGMFCB	;Get driver or filter
	@@FSPEC			;  filespec
	JP	NZ,SPCREQ	;Must be entered
	LD	A,(DE)		;Target cannot be device
	CP	'*'		;  since this is SET
	JP	Z,SPCREQ
	PUSH	HL		;Save INBUF$ pointer
	PUSH	DE		;  and FCB start
	LD	HL,SAVSPEC	;Save the filter/driver
	EX	DE,HL		;  filespec to try /DVR
	LD	BC,32		;  if /FLT is not found
	LDIR
	POP	DE		;Recover FCB
	LD	HL,FLTEXT	;Default extension is FLT
	@@FEXT			;Use default EXT if none
	POP	HL		;Recover cmdline posn
;
;	Make sure device is not in system
;
	PUSH	HL		;Save INBUF$ pointer
	LD	DE,(DEVFCB+1)	;P/u device name
	@@GTDCB			;Find device DCB address
	JR	NZ,NEWDCB	;Go if not found
	BIT	3,(HL)		;  else check if NIL
	LD	A,39		;Init "Device in use...
	JR	Z,ERRPOP	;Error if not NIL
;
;	Inhibit SETting any system device
;
	PUSH	HL		;Save DCB pointer
	LD	HL,DEVFCB	;Determine if system
	LD	D,H		;  device by attempting
	LD	E,L		;  to rename it
	@@RENAM			;The error code will be
	POP	HL		;  either 19 or 40
	CP	40		;Protected system device?
	JR	Z,ERRPOP
	JR	GOTDCB		;  else we have it
;
;	Device not found - Locate spare DCB
;
NEWDCB	LD	DE,0		;Find spare device
	@@GTDCB			;  table position
	LD	A,33		;"no device space avail
	JR	NZ,ERRPOP	;Exit on error
;
;	DCB available - Load the driver/filter
;
GOTDCB	PUSH	HL		;Save table address
	SET	2,(IY+'S'-'A')	;Allow use with EXEC only
	LD	DE,PGMFCB	;Load the target file
	@@LOAD			;Transfer address in HL
	JR	Z,LOADOK	;Go if file found
	AND	3FH		;Strip flags
	CP	31		;Program not found?
	JR	NZ,LOADERR	;Abort on any other
;
;	No FILTER found - Check on DRIVER
;
	LD	DE,SAVSPEC	;Original filename
	LD	HL,DVREXT	;Try with /DVR
	@@FEXT
	SET	2,(IY+'S'-'A')	;Allow use with EXEC only
	@@LOAD
	JR	Z,LOADOK	;Go if file found
LOADERR	POP	HL		;Clean the stack
ERRPOP	POP	HL
	JP	IOERR		;Abort on load error
;
;	Move device name into string buffer
;
LOADOK	POP	DE		;Rcvr table address
	PUSH	DE
	DI			;Don't interrupt me
	LD	A,8		;Set up as NIL first
	LD	(DE),A
NOSET	INC	E		;Transfer device name
	INC	E		;  entered in command
	INC	E		;  to the device table
	LD	A,8		;Show RESET as NIL
	LD	(DE),A
	INC	E
	INC	E		;Point to name field
	INC	E
	LD	A,(DEVFCB+1)	;Move name to DCB
	LD	(DE),A
	INC	E
	LD	A,(DEVFCB+2)
	LD	(DE),A
	EI			;Interrupts back on
GODOIT	POP	DE		;Recover DCB address
	EX	(SP),HL		;Stack prog's TRAADR
	SET	3,(IY+'C'-'A')	;Set system request
	RET			;  & go to it
;
;	FILTER *dev *dev routine
;
FILTER	LD	DE,DEVFCB	;Get first spec
	@@FSPEC
	JP	NZ,DEVREQ	;Quit on bad name
	LD	A,(DE)		;Ck on devicespec
	CP	'*'
	JP	NZ,DEVREQ	;Must have device
	LD	DE,PGMFCB	;Get filter device spec
	@@FSPEC
	JP	NZ,SPCREQ	;Must be entered
	LD	A,(DE)		;Target must be a device
	CP	'*'		;  since this is FILTER
	JP	NZ,DEVREQ
	LD	DE,(PGMFCB+1)	;Get filter DCB address
	@@GTDCB
	JR	NZ,IOERR	;Quit if not found
	BIT	6,(HL)		;Must be a filter
	JR	Z,NOTFLT	;Quit if not
;
;	FILTER must be inactive to use it
;
	LD	D,H		;Xfer FILTER DCB pointer
	LD	E,L		;  to DE & locate the
	INC	L		;  DCB pointer in the
	LD	A,(HL)		;  the FILTER module
	INC	L
	LD	H,(HL)
	LD	L,A
	LD	BC,4		;HL now points to the
	ADD	HL,BC		;  entry point. Get its
	LD	C,(HL)		;  DCB address by peeking
	INC	C		;  past the name field
	ADD	HL,BC
	LD	A,(HL)		;Get low-order
	INC	HL
	LD	H,(HL)		;Get hi-order
	LD	L,A
				;If DCB is NOT pointing
	SBC	HL,DE		;  to itself, then it
	JR	NZ,ACTFLT	;  is an active filter
;
;	The filter DCB pointer points to its DCB
;
	PUSH	DE		;Save filter DCB
	LD	DE,(DEVFCB+1)	;Find the device DCB
	@@GTDCB
	POP	DE
	JR	NZ,IOERR	;Quit if not found
;
;	Swap the 1st three bytes of DCB & FILT DCB
;
	LD	B,3
SWAP	LD	C,(HL)
	LD	A,(DE)
	LD	(HL),A
	LD	A,C
	LD	(DE),A
	INC	L
	INC	E
	DJNZ	SWAP
	JR	EXIT
;
FLTEXT	DB	'FLT'
DVREXT	DB	'DVR'
;
IOERR	LD	L,A		;Transfer error code
	LD	H,0		;  to HL
	OR	0C0H		;Set abbrev & return
	LD	C,A
	@@ERROR
	RET
;
ACTFLT	LD	HL,ACTFLT$
	DB	0DDH
NOTFLT	LD	HL,NOTFLT$
	DB	0DDH
DEVREQ	LD	HL,DEVREQ$
	DB	0DDH
CANT	LD	HL,CANT$
	DB	0DDH
SPCREQ	LD	HL,SPCREQ$
	@@LOGOT
	LD	HL,-1
	RET
;
EXIT	LD	HL,0
	@@CKBRKC		;Clear out break
	RET
;
SPCREQ$	DB	'File spec required',CR
DEVREQ$	DB	'Device spec required',CR
CANT$	DB	'No memory space available',CR
NOTFLT$	DB	'Device is not a filter',CR
ACTFLT$	DB	'FILTER module is in use',CR
;
SAVSPEC	DS	32
DEVFCB	DS	32		;Device file control block
PGMFCB	DS	32		;Driver/filter FCB
;
	END	SET
