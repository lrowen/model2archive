;LBBUILD/ASM - BUILD Command
	TITLE	<BUILD - LS-DOS 6.2>
;
;
CPL	EQU	80		;Characters per line
;
*GET	BUILDVER/ASM:3
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	VALUES:3		;Misc. equates
;
	ORG	2400H
;
;	Was the <BREAK> key hit ?
;
START
	IF	@BLD631
	LD	(SAVESP+1),SP	;<631>Save SP address
	@@CKBRKC		;<631>Break key down?
	JR	NZ,ABORT	;<631>
	ELSE
	@@CKBRKC		;Break key down?
	JR	Z,$+6		;Go if not
	LD	HL,-1		;  else abort
	RET
;
;	<BREAK> not hit - execute module
;
	LD	(SAVESP+1),SP	;Save SP address
	ENDIF
	CALL	BUILD		;Build a file
	LD	HL,0		;Set no error
SAVESP	LD	SP,$-$		;P/u original SP addr.
	@@CKBRKC
	RET			;Exit with retcode
;
;	I/O Error Handler
;
IOERR	LD	H,0		;Set HL = Error #
	LD	L,A		;
	OR	0C0H		;Short error mess & RET
	LD	C,A		;Stuff in C
	@@ERROR			;Display error
	JR	SAVESP		;ABORT
;
;	Internal Error Message Handling
;
BADIGS	LD	HL,BADIGS$	;"Bad Hex digit"
	DB	0DDH
ODDIGS	LD	HL,ODDIGS$	;"Odd # of hex digits"
	DB	0DDH
SPCREQ	LD	HL,SPCREQ$	;"Filespec Required"
	DB	0DDH
EXISTS	LD	HL,EXISTS$	;"File already exists"
	@@LOGOT			;Log error message
ABORT	LD	HL,-1		;Set abort code
	JR	SAVESP		;Exit
;
;	BUILD - Build A file
;
BUILD	LD	DE,FCB1		;DE => FCB
	@@FSPEC			;Legal Filespec ?
	JR	NZ,SPCREQ	;No - "Filespec req"
;
;	Legal Filespec - Stuff default /ext of JCL
;
	PUSH	HL		;Save cmd buf ptr
	LD	HL,JCLEXT	;HL => "JCL"
	@@FEXT			;Fetch extension
	POP	HL		;Rcvr command ptr
;
;	Pick up parameters if any
;
	LD	DE,PRMTBL$	;DE => Parameter table
	@@PARAM			;Get any parameters
	JR	NZ,IOERR	;Quit on parm error
;
;	Position to Extension
;
	LD	HL,FCB1		;Point to start of FCB
SLASH?	LD	A,(HL)		;P/u a char
	INC	HL		;  & bump pointer
	CP	CR		;End of line?
	JR	Z,NOTKSM	;Yes - not a KSM file
	CP	'/'		;Start of EXT?
	JR	NZ,SLASH?	;Loop if not
;
;	Is the extension KSM ?
;
	PUSH	HL		;HL => Extension
	LD	A,(HL)		;P/u character
	INC	HL		;Bump ptr
	CP	'K'		;Match K?
	JR	NZ,NOTKSM
	LD	A,(HL)
	INC	HL
	CP	'S'		;Match S?
	JR	NZ,NOTKSM
	LD	A,(HL)
	CP	'M'		;Match M?
	JR	NZ,NOTKSM
;
;	Extension is /KSM - stuff 0FFH in indicator
;
	LD	A,0FFH
	LD	(KSM?+1),A	;Stuff KSM indicator
;
;	Is the extension /JCL ?
;
NOTKSM	POP	HL		;HL => Extension field
	LD	A,(HL)		;Ck if EXT is JCL
	INC	HL
	CP	'J'		;Match J?
	JR	NZ,INIT
	LD	A,(HL)
	INC	HL
	CP	'C'		;Match C?
	JR	NZ,INIT
	LD	A,(HL)
	CP	'L'		;Match L?
	JR	NZ,INIT
	LD	A,CPL-1		;Max 79 cpl on JCL
	LD	(LINLEN+2),A
;
;	Init the file with LRL of 256
;
INIT	LD	HL,IOBUF	;HL => I/O buffer
	LD	DE,FCB1		;DE => FCB
	LD	B,0		;B = LRL = 256
	@@INIT			;Init the file
	JR	NZ,IOERRA	;Jump on error
;
;	Stuff Filespec into Buffer
;
	PUSH	AF		;Save Carry
	LD	DE,FILEBUF	;DE => Filespec
	LD	BC,(FCB1+6)	;B = DEC, C = Drive #
	LD	A,(FCB1)	;P/u to test device/file
	CALL	$FNAME
	JR	NZ,IOERRA
	POP	AF		;F = Status from @INIT
;
	LD	HL,BMESS1	;Default "Building :"
	JR	C,SETBUF	;Jump if New file
;
;	File already exists - Was APPEND specified ?
;
APPEND	LD	BC,$-$		;P/u APPEND parameter
	LD	DE,FCB1		;DE => FCB
	INC	C		;Specified ?
	JR	Z,APP1		;Go if so
	@@CLOSE			;Close to reset open bit
	JP	Z,EXISTS	;Quit with "file exists...
IOERRA	JP	IOERR		;  or if error on close
;
;	Position to end of file for append
;
APP1	@@PEOF			;Position to EOF
	LD	HL,BMESS2	;"Appending *KI to "
;
;	Display Building/Appending Message
;
SETBUF	CALL	DSPLY		;Display message
	LD	HL,FILEBUF	;Filename buffer
	CALL	DSPLY
	LD	C,CR		;End line
	@@DSP
	JR	NZ,IOERRA
	LD	HL,BUFFER	;HL => Input buffer
;
;	Is this a KSM File ?
;
KSM?	LD	A,$-$		;Not zero if KSM
	OR	A
	JR	Z,LINLEN	;Z - not a KSM
;
;	KSM loop - p/u current letter & increment
;
KSM1	PUSH	HL		;Save text pointer
	LD	HL,LETBUF	;"A=> "
	INC	(HL)		;Increment letter
	LD	A,(HL)		;P/u letter
;
;	Finished with all the KSM keys ?
;
	CP	'Z'+1		;Go past Z?
	JR	NZ,DISSTR	;No - display string
	POP	HL		;Recover text ptr
	JR	GOTEND		;Finished
;
;	Display letter & "=> "
;
DISSTR	CALL	DSPLY		;Display string
	POP	HL		;Recover text ptr
;
;	Input line with either 255 or 79 characters
;
LINLEN	LD	BC,255<8	;255 or 79 (JCL)
	@@KEYIN			;Input line
	JR	C,GOTBRK	;Exit on <BREAK>
	JR	NZ,TSTEOF	;Ck if EOF key used
;
;	Got a line of input, check if HEX parameter
;
HPARM	LD	DE,$-$		;P/u HEX parameter
	INC	E		;Specified ?
	JR	NZ,NOTHEX	;No - ASCII input
;
;	HEX parm was entered - convert input to hex
;
	LD	D,H		;Point DE => Input
	LD	E,L
;
HP1	CALL	CVRTHEX		;Convert char @ DE
	DEC	B		;Decrement count
	JP	Z,ODDIGS	;Done ? - odd # of digits
;
;	Stuff first digit into high order nibble
;
	RLCA			;Shift to hi-order nybble
	RLCA
	RLCA
	RLCA
	LD	C,A		;Save in C
;
;	P/u low-order digit & OR with high order
;
	CALL	CVRTHEX		;Convert char @ DE
	OR	C		;OR with hi-order nibble
	LD	(HL),A		;Stuff in buffer
;
;	Increment converted input ptr & count down
;
	INC	HL		;Bump conv input ptr
	DJNZ	HP1		;B hex digits
	JR	KSM?		;Done conv, back to loop
;
;	ASCII input, point HL to next free location
;
NOTHEX	LD	C,B		;Advance memory buffer
	LD	B,0		;To end of this line
	ADD	HL,BC		;HL => End of line
	INC	HL		;Bump to 1st free posn
	JR	KSM?		;Loop for input
;
;	EOF or BREAK hit - Test Number of chars entered
;	If not at line start, convert to CR and continue
;
TSTEOF	CP	1CH		;EOF?
	JP	NZ,IOERR	;Real error if not
GOTBRK	LD	A,B		;Any characters ?
	OR	A
	JR	NZ,HPARM	;Yes - continue Build
;
;	Save input pointer address
;
GOTEND	LD	(ENDTXT+1),HL	;Save buffer posn
	LD	HL,BUFFER	;HL => Start of input
ENDTXT	LD	DE,$-$		;DE => Last used address
;
;	Is there any more text to write out ?
;
	EX	DE,HL		;Swap for math
	XOR	A		;Clear carry
	SBC	HL,DE		;Any more text to write ?
	JR	Z,ATEND		;No - don't write any
;
;	Write a byte to the file
;
	EX	DE,HL		;HL => Byte to output
	LD	DE,FCB1		;DE => FCB
	LD	C,(HL)		;P/u a char
	INC	HL		;Bump ptr
	@@PUT			;Output char
	JR	Z,ENDTXT	;Loop for more if i/o OK
;
;	Done writing - either end of text or error
;
ATEND	PUSH	AF		;Save error code if any
;
;	Close the file
;
	LD	DE,FCB1		;DE => FCB
	@@CLOSE			;Close the file
	JP	NZ,IOERR	;Can't - I/O error
;
;	Make sure @PUT didn't RETurn any I/O error
;
	POP	AF		;Recover error code
	RET	Z		;Ok - Return
	JP	IOERR		;NZ - I/O Error
;
;	DSPLY - Display Line & HL
;
;
DSPLY	@@DSPLY			;Display line
	RET	Z		;Back if good
	JP	IOERR		;  else abort
;
;	CVRTHEX - Convert character at DE to hex
;
CVRTHEX	LD	A,(DE)		;Get a char
	INC	DE		;Bump ptr
	SUB	'0'		;Convert to binary
	JR	C,BADIGSA	;Can't be < '0'
	CP	10		;Numeric character ?
	RET	C		;Yes - return
	RES	5,A		;No - convert to U/C
	SUB	7		;Adjust A-F to be 10-15
	CP	16		;Legal hex digit ?
	RET	C		;Yes - return
BADIGSA	JP	BADIGS		;No - Bad Hex Digit
;
;	Routine to pick up device/file name
;
$FNAME	BIT	7,A		;Test device/file
	JR	Z,FNAME1	;Go if device
	@@FNAME
	RET
FNAME1	LD	A,'*'		;Stuff device indicator
	LD	(DE),A
	INC	DE
	LD	A,C		;Stuff 1st character
	LD	(DE),A
	INC	DE
	LD	A,B		;Stuff 2nd character
	LD	(DE),A
	INC	DE
	LD	A,3		;Stuff ETX
	LD	(DE),A
	RET
;
;	ERROR Messages
;
ODDIGS$	DB	'Odd # of hex digits',CR
BADIGS$	DB	'Bad hex digit encountered',CR
SPCREQ$	DB	'File spec required',CR
EXISTS$	DB	'File already exists',CR
;
FILEBUF	DS	15
BMESS1	DB	'Building: ',ETX
BMESS2	DB	'Appending: *KI to ',ETX
;
JCLEXT	DB	'JCL'
;
LETBUF	DB	'A'-1,'=> ',ETX
;
;	PARAMETER TABLE
;
PRMTBL$	DB	80H		;6.x Parameter table
;
;	HEX (H) parameter - Flag input only
;
	DB	FLAG!ABB!3
	DB	'HEX'
	DB	0
	DW	HPARM+1
;
;	APPEND (A) parameter - Flag input only
;
	DB	FLAG!ABB!6
	DB	'APPEND'
	DB	0
	DW	APPEND+1
;
	DB	0
;
;	Buffer Area
;
FCB1	DB	0
	DS	31
	ORG	$<-8+1<8
IOBUF	DS	256
BUFFER	DS	256
;
	END	START
