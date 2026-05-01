;FORMS/ASM - Printer Formatting Filter
	TITLE	<FORMS/FLT - LS-DOS 6.2>
;
LF	EQU	10
CR	EQU	13
;
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	COPYCOM:3		;Copyright message
;
	ORG	2400H
;
BEGIN
	@@CKBRKC		;Check for break
	JR	Z,BEGINA	;Continue if no Break
	LD	HL,-1
	RET			;  else abort
;
BEGINA	PUSH	DE		;Save DCB address
	POP	IX		;  in index reg
	LD	(PFDCB),DE	;  and in filter header
	@@DSPLY	HELLO$		;Welcome the user
;
;	Check if entry from SET command
;
	@@FLAGS			;IY => flag table base
	BIT	3,(IY+'C'-'A')	;System request?
	JP	Z,VIASET	;Quit if not
;
;	Check if filter is already resident
;
	LD	DE,FF$		;Check if filter is
	@@GTMOD			;  already resident
	EX	DE,HL		;Put DCB ptr to HL
	JR	NZ,NOTRES	;Go if not
;
;	Make sure that the new DCB is same as the old
;
	IF	@BLD631
	LD	C,(HL)		;<631>P/u DCB pointer LSB
	INC	HL		;<631>
	LD	B,(HL)		;<631>P/u DCB pointer MSB
	ELSE
	LD	BC,(PFDCB)	;Replace DCB pointer
	LD	A,C		;  with new one
	LD	C,(HL)		;P/u DCB pointer LSB
	NOP
	INC	HL
	LD	A,B
	LD	B,(HL)		;P/u DCB pointer MSB
	ENDIF
	LD	HL,6		;Get old DCB name &
	ADD	HL,BC		;  stuff into error
	LD	A,(HL)		;  message in case
	INC	L		;  a different DCB
	LD	H,(HL)		;  is referenced
	LD	L,A
	LD	(DCBNAM$),HL	;Stuff message with spec
	OR	H
	JR	Z,ISRES
	LD	HL,(PFDCB)	;P/u DCB existing DCB
	OR	A		;  pointer
	SBC	HL,BC		;Same DCB pointer?
	JP	NZ,DCBERR	;Can't install if diff
	JR	ISRES
;
;	Module is not resident
;
NOTRES	LD	DE,'IK'
	@@GTDCB			;Locate low memory ptr
	JP	NZ,IOERR	;Quit if not found
	DEC	L
	LD	D,(HL)		;P/u pointer to
	DEC	L		;  start of free
	LD	E,(HL)		;  low core
	LD	(LCPTR+1),DE	;Save loc for later
	PUSH	HL		;Save low core ptr
	LD	HL,PFEND-PFFLT
	ADD	HL,DE		;Start + driver length
	PUSH	HL
	DEC	HL		;Point to last byte
	LD	(SVEND+1),HL
	LD	BC,1300H	;Max addr + 1
	XOR	A
	SBC	HL,BC
	POP	DE		;Rcvr new lc
	POP	HL		;Rcvr low core ptr
	JR	C,PUTLOW	;If room, put low
;
;	Check if high memory available
;
	@@FLAGS
	BIT	0,(IY+'C'-'A')	;Memory frozen?
	JP	NZ,NOROOM	;"No memory...
	LD	HL,0		;Get HIGH$
	LD	B,L
	@@HIGH$
	LD	(SVEND+1),HL	;Save for relocator
	LD	E,L		;Xfer new last
	LD	D,H		;  to reg DE
	XOR	A		;Calc new start
	LD	BC,PFEND-PFFLT	;BC = filter len
	SBC	HL,BC
	LD	B,0
	@@HIGH$			;Set new HIGH$
	INC	HL		;Point to new start
	EX	DE,HL
	PUSH	DE
	CALL	RELO		;Relocate internal references
	POP	DE
	LD	A,0FFH
	LD	(HGHFLG),A	;Flag to notify user
	JR	MOVMOD		;  himem used
;
;	Room in low core - move driver low
;
PUTLOW	LD	(HL),E		;Stuff low core ptr
	INC	L		;  with new low
	LD	(HL),D
	CALL	RELO		;Relocate vectors
LCPTR	LD	DE,$-$		;Low core pointer
;
;	Move module to memory
;
MOVMOD	PUSH	DE		;Save start
	LD	HL,PFFLT
	LD	BC,PFEND-PFFLT	;Calc driver length
	LDIR
	POP	DE		;Pop filter start
	SET	5,(IY+'D'-'A')	;Set PF in DFLAG$
;
ISRES	LD	HL,PFACT$	;Init "FORMS installed
	LD	(IX),40H!7	;Init DCB type to "C/P/G"
	LD	(IX+1),E	;  & filter & stuff the
	LD	(IX+2),D	;  filter address
	@@LOGOT			;Display installation
	LD	A,$-$
HGHFLG	EQU	$-1		;Flag filter went high
	OR	A		;Skip if not set
	JR	Z,NTHGH
	LD	HL,HMEM$	;  else show "Went in himem
	@@LOGOT
NTHGH	LD	HL,0		;No error
	RET			;Done, back to user
;
;	Relocate internal references in driver
;
RELO	PUSH	IX
	LD	IX,RELTAB	;Point to relocation tbl
SVEND	LD	HL,$-$		;Find distance to move
	LD	(PFFLT+2),HL	;Set last byte used
	LD	DE,PFEND-1
	OR	A		;Clear carry flag
	SBC	HL,DE
	LD	B,H		;Move to BC
	LD	C,L
	LD	A,TABLEN	;Get table length
RLOOP	LD	L,(IX)		;Get address to change
	LD	H,(IX+1)
	LD	E,(HL)		;P/U address
	INC	HL
	LD	D,(HL)
	EX	DE,HL		;Offset it
	ADD	HL,BC
	EX	DE,HL
	LD	(HL),D		;Put it back
	DEC	HL
	LD	(HL),E
	INC	IX
	INC	IX
	DEC	A
	JR	NZ,RLOOP	;Loop till done
	POP	IX
	RET
;
;	Error exits
;
VIASET	LD	HL,VIASET$	;"Install with Set
	DB	0DDH
DCBERR	LD	HL,DCBERR$	;"Filter in use
	DB	0DDH
NOROOM	LD	HL,NOROOM$	;"Memory frozen
	@@LOGOT			;Show the error
	LD	HL,-1		;Set abort code
	RET
;
IOERR	LD	L,A		;Error # to HL
	LD	H,0
	OR	0C0H		;Abbrev, return
	LD	C,A		;Error code to C
	@@ERROR			;  for error display
	RET
;
;	Messages & Data tables
;
FF$	DB	'$FF',3
HELLO$	DB	'FORMS Filter'
*GET	CLIENT:3
;
VIASET$	DB	'Must install via SET',CR
NOROOM$	DB	'No memory space available',CR
DCBERR$	DB	'Filter already attached to *xx',CR
DCBNAM$	EQU	$-3
PFACT$	DB	'Forms filter is now resident',CR
HMEM$	DB	LF,'Note: filter installed in high memory.',CR
;
;
;	Printer Filter - PF
;	Provides hard or soft form feed, line wraparound,
;	automatic form feeds between pages, tabs, blank
;	lines, 1 byte translation table, left margins,
;	and set-top-of-form character.
;
*MOD
PFBIT	EQU	3		;Position in DFLAG
SPLBIT	EQU	0		;Position in DFLAG
LF	EQU	10
CR	EQU	13
;
PFFLT	JR	PFBGN		;Branch around header
	DW	PFEND-1		;Last byte used
	DB	3,'$FF'		;Name length/name
PFDCB	DW	$-$		;Link to DCB
	DW	0
;
;	Filter data area
;
PFDATA$	EQU	$
PMAX	EQU	$-PFDATA$
	DB	66		;Page size (max lines per page)
LCOUNT	EQU	$-PFDATA$
	DB	0		;Line counter
LMAX	EQU	$-PFDATA$
	DB	66		;Max lines to print
CCOUNT	EQU	$-PFDATA$
	DB	0		;Chars per line printed
XL1	EQU	$-PFDATA$
	DB	0		;Translate from
XL2	EQU	$-PFDATA$
	DB	0		;Translate to
INDENT	EQU	$-PFDATA$
	DB	0		;Indent after line wraparound
ADDLF	EQU	$-PFDATA$
	DB	4		;Bit-0, LF after CR; bit-1=FF
				;Bit-2, TAB expand (1)
CMAX	EQU	$-PFDATA$
	DB	0		;Max CPL before wraparound
MARGIN	EQU	$-PFDATA$
	DB	0		;Left hand margin
;
;	Start of filter
;
PFBGN	JR	Z,FFENTRY	;Go if @PUT
	DB	011H		;Ignore next inst if not
PFPUT	LD	B,2		;Init for @PUT
	PUSH	IX
	LD	IX,(PFDCB)	;Grab the DCB vector
RX01	EQU	$-2
	@@CHNIO			;  & chain to it
	POP	IX
	RET
;
;	Peform the tab function
;
DOTAB	LD	A,(IX+CCOUNT)	;How many spaces to
	AND	7		;  next tab stop?
	SUB	8
	NEG
	JR	@INDENT		;Space over to it
;
;	Filter code
;
FFENTRY	LD	IX,PFDATA$	;Base register
RX02	EQU	$-2
;
CKXLAT	LD	A,(IX+XL1)	;Get xlate in
	CP	C		;Translate this char?
	JR	NZ,CONT		;Go if not xlated char
	LD	A,(IX+XL2)	;Xlated to this
	LD	C,A
CONT	LD	A,C		;P/u char to test
	CP	0CH		;Form feed?
	JP	Z,DOTOF
RX14	EQU	$-2
	CP	6		;SET TOF?
	JP	Z,SETTOF
RX03	EQU	$-2
	CP	CR		;CR?
	JR	Z,DOCRLF
	CP	LF		;LF?
	JR	Z,DOCRLF
	LD	A,(IX+MARGIN)	;Left margin to do?
	OR	A
	JR	Z,NOMARG	;Go if not
	INC	(IX+CCOUNT)	;Check current char count
	DEC	(IX+CCOUNT)	;If at newline,
	PUSH	BC
	CALL	Z,@INDENT	;  need a margin now
RX13	EQU	$-2
	POP	BC
NOMARG	LD	A,C		;P/u character again
	BIT	2,(IX+ADDLF)	;Expand tabs?
	JR	Z,CONTA
	CP	9		;Tab?
	JR	Z,DOTAB
CONTA	CP	20H		;Other control code?
	JR	C,PFPUT		;Pass on unchanged if so
;
;	Got a character to output
;
PUTCHAR	PUSH	BC		;Save character
	CALL	SETUP		;Setup for next char
RX12	EQU	$-2
	POP	BC
	RET	NZ		;Quit on error
	CALL	Z,PFPUT		;Now put the char
RX04	EQU	$-2
	RET
;
;	Do the end of line check
;
SETUP	INC	(IX+CCOUNT)	;Inc char counter
	LD	A,(IX+CMAX)	;Wraparound needed?
	AND	A
	RET	Z		;Quit if feature is off
	CP	(IX+CCOUNT)
	JR	NC,EXITZ	;Done if not needed
	CALL	DOCRLF		;Do carriage return
RX05	EQU	$-2
	RET	NZ
	INC	(IX+CCOUNT)	;Adjust char counter
;
;	Check on indent needed
;
	LD	A,(IX+INDENT)	;P/u indent
	ADD	A,(IX+MARGIN)	;Add in the MARGIN
	OR	A
	RET	Z		;Done if none
@INDENT	PUSH	BC		;In case of recursive
	LD	B,A		;  calls
	LD	C,' '		;Print spaces
SPACES	PUSH	BC		;Save counter
	XOR	A
	CALL	PUTCHAR		;Put the character
RX06	EQU	$-2
	POP	BC		;Recover counter
	JR	NZ,$+4		;Exit on PUT error
	DJNZ	SPACES
	POP	BC
	RET
LINFEED	BIT	0,(IX+ADDLF)
	JR	Z,DOWN1		;Go if hardware auto-LF
	LD	C,CR		;Else do CR and LF
	CALL	PFPUT
RX11	EQU	$-2
	RET	NZ
	JR	DOWNLF
DOWN1	LD	A,(IX+CCOUNT)
	AND	A		;Line empty?
	LD	C,CR		;Do CR if not
	JR	NZ,DOWNCR
DOWNLF	LD	C,LF		;Do LF if so
DOWNCR	CALL	PFPUT
RX07	EQU	$-2
	LD	(IX+CCOUNT),0	;Starting new line
	RET
;
DOCRLF	CALL	LINFEED		;CRLF & check if page end
RX08	EQU	$-2
	RET	NZ
;
	INC	(IX+LCOUNT)
	LD	A,(IX+LCOUNT)	;Time to do form feed?
	CP	(IX+LMAX)
	JR	C,EXITZ		;Return if not
;
DOTOF	LD	A,(IX+PMAX)	;How many lines to feed?
	SUB	(IX+LCOUNT)
	JR	Z,SETTOF	;Skip if zero
	PUSH	BC		;In case called by DOTAB
	LD	B,A
	BIT	1,(IX+ADDLF)	;Hardware form feed?
	JR	Z,SOFTFF	;Go if not
	LD	C,0CH		;  else load up TOF char
	CALL	PFPUT		;  and send it
RX09	EQU	$-2
	JR	FFEXIT
SOFTFF	PUSH	BC
	CALL	LINFEED		;Do LF's
RX10	EQU	$-2
	POP	BC
	JR	Z,CHRGONE	;This linefeed sent OK
	POP	BC		;  else clean stack
	RET			;  and return error
CHRGONE	DJNZ	SOFTFF
FFEXIT	POP	BC
;
;	Set the top-of-form
;
SETTOF	LD	(IX+LCOUNT),0	;Reset line counter
EXITZ	CP	A
	RET
;
PFEND	EQU	$
;
RELTAB	DW	RX01,RX02,RX03,RX04,RX05,RX06,RX07,RX08
	DW	RX09,RX10,RX11,RX12,RX13,RX14
TABLEN	EQU	$-RELTAB/2
;
	END	BEGIN
