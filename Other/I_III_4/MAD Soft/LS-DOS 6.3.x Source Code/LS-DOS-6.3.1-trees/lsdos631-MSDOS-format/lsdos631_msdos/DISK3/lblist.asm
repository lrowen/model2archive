;LBLIST/ASM - List Command
	TITLE	<LIST - LS-DOS 6.2>
;
*GET	BUILDVER/ASM:3
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	VALUES:3		;Misc. equates
;
@PRT	EQU	6
@DSP	EQU	2
;
	ORG	2400H
;
START
	@@CKBRKC		;Check break
	JR	Z,LISTA		;Continue if not
	LD	HL,-1		;  else abort
	RET
;
;	<BREAK> not hit, Execute Module
;
LISTA
	LD	(SAVESP+1),SP	;Save SP
	CALL	LIST		;List a file
SAVESP	LD	SP,$-$		;P/u SP address
	@@CKBRKC		;Reset if user pressed break
	RET			;Abort
;
;	I/O Error Processing - Display & Abort
;
IOERR	LD	H,0		;Set HL = Error #
	LD	L,A		;
	OR	0C0H		;Short error message
	LD	C,A		;Stuff error # in C
	@@ERROR			;Display error
	JR	SAVESP		;Abort
;
;	Internal Error Message Display Routine
;
SPCREQ	LD	HL,SPCREQ$	;File spec Required
	@@LOGOT			;Log error message
ABORT	LD	HL,-1		;Internal error = -1
	JR	SAVESP		;P/u stack & return
;
;	LIST - List a file in hex or ASCII
;
LIST	CALL	RESKFL		;Reset pause, & enter
;
;	Find parameter entries if existent
;
	PUSH	HL		;Save command ptr
FPLP	LD	A,(HL)		;P/u character
	CP	'('		;Parameter(s) ?
	JR	Z,GETPRM	;Yes - go get 'em
	CP	CR+1		;End of line ?
	JR	C,RESTPTR	;Yes - restore ptr
	INC	HL		;No - bump til end
	JR	FPLP		;Do til eol or "("
;
;	Process any parameters entered
;
GETPRM	LD	DE,PRMTBL$	;DE => Parameter table
	@@PARAM			;@PARAM
	JP	NZ,IOERR	;NZ - "Parameter Error"
RESTPTR	POP	HL		;Recover ptr
;
;	Skip command line blanks
;
IGSPC	LD	A,(HL)		;P/u character
	INC	HL		;Bump ptr
	CP	' '		;Space ?
	JR	Z,IGSPC		;Yes - ignore them
	DEC	HL		;HL => First non-space
;
;	Check if the filespec is legal in format
;
	LD	DE,FCB1		;Fetch file spec
	@@FSPEC			;Filespec legal ?
	JP	NZ,SPCREQ	;No - filespec required
;
;	If this is a device - don't LIST
;
	LD	A,(DE)		;Is this a device ?
	CP	'*'		;
	JP	Z,SPCREQ	;Yes - Filespec req
;
;	Save the original filespec
;
	EX	DE,HL		;HL => Source FCB
	LD	DE,FCB2		;DE => Duplicate FCB
	LD	BC,32		;32 bytes tm xfer
	PUSH	HL		;Save source ptr
	LDIR			;Xfer
	POP	DE		;DE => Source FCB
;
;	Stuff default extension of /TXT to source
;
	LD	HL,TXTEXT	;HL => TXT
	@@FEXT			;Stuff TXT if no ext
;
;	Open the file with LRL of 256
;
	LD	B,0		;Set LRL (B) = 256
	CALL	OPEN		;Open file with LRL=256
	JR	Z,INITLRL	;Good - LIST it
;
;	Error - Was it a "File not Found" Error ?
;
	CP	24		;"File not Found" ?
	JP	NZ,IOERR	;No - I/O Error
;
;	OPEN original filespec instead of TXT
;
	LD	C,32		;BC = 32 bytes to xfer
	PUSH	DE		;DE => FCB1
	PUSH	HL		;Save I/O buff ptr
	LD	HL,FCB2		;HL => Filespec
	LDIR			;Xfer original filespec
	POP	HL		;HL => I/O buffer
	POP	DE		;DE => unopen FCB
;
;	Open Original Filespec without extension
;
	CALL	OPEN		;Open the file
	JP	NZ,IOERR	;I/O error - abort
;
;	Pick up the DEC from the FCB
;
INITLRL	PUSH	DE		;Xfer fcb to IX
	POP	IX
	LD	B,(IX+7)	;P/u DEC
	LD	C,(IX+6)	;  & drive #
	@@DIRRD			;Read in directory record
;
;	Was the LRL parm specified ?
;
	LD	A,(LRESP)	;P/u response
	OR	A
	JR	NZ,SKIPLRL	;Go if entered
;
;	No LRL parm, get from directory record
;
	LD	A,L		;Position to DIR+4
	ADD	A,4
	LD	L,A		;HL => LRL byte (DIR+4)
;
;	Pick up LRL & stuff into LRL parameter
;
	LD	A,(HL)		;P/u LRL
	LD	(LPARM+1),A	;Set dir LRL into parm
;
;	Pick up LRL & stuff into FCB
;
SKIPLRL	LD	A,(LPARM+1)	;P/u possible new LRL
	LD	(IX+9),A	;Put into FCB
	SET	7,(IX+1)	;Mark for byte I/O
;
;	Check if TAB (T) parm is flag or numeric
;
	LD	A,(TRESP)	;P/u response byte
	AND	40H		;Flag response ?
	LD	A,(TPARM+1)	;P/u value
	JR	Z,NOTFLG	;No - numeric
;
;	Flag Response - Is it ON (T=8) or OFF (T=1)
;
	INC	A		;Tab=OFF (NZ) or ON (Z) ?
	JR	NZ,NOTFLG	;Tab = OFF ---> TABEXP=1
	LD	A,8		;Tab = ON ---> TABEXP=8
;
;	P/u TAB (T) parm value & stuff into routine
;
NOTFLG	LD	(TABEXP+1),A	;Stuff away
	DEC	A		;Range can
	CP	32		;Only be between 1-32.
	LD	A,PAR_ERR	;Greater - Parm Error
	JP	NC,IOERR
;
;	Was the P (print) parameter entered ?
;
PPARM	LD	BC,$-$		;P/u P parameter
	LD	A,B		;Was it specified ?
	OR	C
	JR	Z,HPARM		;No - use @DSP
	IF	@BLD631
	LD	(SPARM+1),BC	;<631>
	ENDIF
;
;	Stuff @PRT SVC # in output routine
;
	LD	A,@PRT		;@PRT SVC Number
	LD	(PUTOUT1+1),A	;Overwrite @DSP
;
;	Hex Parameter Entered ?
;
HPARM	LD	BC,$-$		;P/u Hex parm
	LD	A,B		;Entered ?
	OR	C
	JP	NZ,RPARM	;Yes - check out Records
;
;	Routine to LIST a file in ASCII
;
	LD	(BYTCTR),A	;Init counter to 0
	IF	@BLD631
	LD	(L26AC),A	;<631>
	LD	A,17H		;<631>
	LD	(L2690),A	;<631>
	LD	(L26AE),A	;<631>
	ENDIF
;
LINPRM	LD	BC,1		;P/u start line parm
	DEC	BC		;Count down for start
	LD	A,B		;Ready to list ?
	OR	C
	JR	Z,BGNLIN	;Go list/print if ready
	LD	DE,FCB1		;DE => FCB
;
;	Ignore all lines until specified start posn
;
FND1ST	@@GET			;Get a character
	JP	NZ,IOERR	;Error - abort
	CP	CR		;End of line?
	JR	NZ,FND1ST	;Keep reading
;
;	Finished with line - decrement LINE count
;
	DEC	BC		;Dec line counter
	LD	A,B		;Finished
	OR	C		;Ignoring lines ?
	JR	NZ,FND1ST	;No - loop until LINES=0
;
;	Start LISTing File
;
BGNLIN	LD	HL,(LINPRM+1)	;P/u original line #
	LD	BC,VARDOT	;Convert to Decimal ASCII
	CALL	CVTDEC		;  and stuff into string
;
;	Read in a character from the file
;
GETCHR	LD	DE,FCB1		;DE => FCB
	@@GET			;Get a byte
	JR	NZ,GOTERR	;Go if read error
	LD	(PUCHAR+1),A	;Hang on to char
;
;	Test if NUM parameter was entered
;
NPARM	LD	BC,$-$		;P/u N parameter
	LD	A,B		;Was it entered ?
	OR	C
	JR	Z,PUCHAR	;No - don't print line #
;
;	N parm entered - print line # & Increment it
;
	LD	HL,VARDOT	;HL => Buffer with line #
	PUSH	HL		;Save ptr
	CALL	PUTLINE		;Output line @ HL
	POP	HL		;Restore line # ptr
	CALL	INCNUM		;Increment line #
;
;	Pick up character and Check if high bit set
;
PUCHAR	LD	A,$-$		;P/u character
DLOOP	RLCA			;Get HB into Carry flag
;
;	Reset High bit unless A8 parameter entered
;
A8PARM	LD	DE,$-$		;P/u A8 parm
	INC	D		;Was it entered ?
	DEC	D
	JR	NZ,A8BIT	;Yes - don't change byte
	SRL	A		;Reset Bit 7
	DB	1EH		;LD E,nn instruction
A8BIT	RRCA			;Use all 8 bits
;
;	Is the character a Tab ?
;
	PUSH	AF		;Save C flag
	CP	TAB		;Was it a tab ?
	JR	NZ,NOTTAB	;No - don't check TAB
;
;	Character is a Tab - Was T=N specified ?
;
TPARM	LD	DE,0008H	;P/u TAB parm (Default=8)
	INC	E		;TAB = N ?
	DEC	E
	JR	Z,NOTTAB	;Yes - don't expand
;
;	P/u column # & calculate # of spaces to pad
;
	LD	A,(BYTCTR)	;P/u column number
TABEXP	LD	C,8		;P/u TAB expansion #
CLOOP	SUB	C
	JR	NC,CLOOP
	NEG			;Subtract A from Col #
;
;	Output A blank spaces for tab expansion
;
	LD	B,A		;Put # spaces in B
TP1	LD	A,' '		;Pad with a space
	CALL	PUTOUT		;Output character
	DJNZ	TP1		;B spaces to output
	JR	WASTAB		;Check byte counter
;
;	Character was not a tab, display it
;
NOTTAB	CALL	PUTOUT		;Print the character
WASTAB	LD	A,(BYTCTR)	;P/u byte counter
	OR	A		;If C/R printed
	CALL	Z,CKPAWS	;Then check for <PAUSE>
;
;	Check for <PAUSE> if hi bit set on character
;
	POP	AF		;Get back char
	CALL	C,CKPAWS	;If high bit was set
;
;	If character = C/R then read in another line
;
	CP	CR		;Was it C/R ?
	JR	Z,GETCHR	;Yes - get new line
;
;	Get another byte from file
;
	LD	DE,FCB1		;DE => FCB
	@@GET			;Get a byte
	JR	Z,DLOOP		;Good - check character
;
;	I/O Error on @GET - Output a Carriage Return
;
GOTERR	PUSH	AF		;Save error code
	LD	A,CR		;Write end of line
	CALL	PUTOUT
	POP	AF		;Rcvr error code
;
;	If End of File Error - Exit normally
;
	LD	HL,0		;Set HL = 0 (normal exit)
	CP	1CH		;EOF?
GTBK	JP	Z,SAVESP	;Exit if so
	CP	1DH		;NRN > ERN?
	JR	Z,GTBK		;Yes - leave
	JP	IOERR		;Other - Abort
;
;	LIST a file in HEX format
;
RPARM	LD	BC,$-$		;P/u starting Record #
	LD	DE,FCB1		;DE => FCB
	@@POSN			;Position to Record BC
	JP	NZ,IOERR	;Abort on position error
;
;	Reset byte counter to Zero
;
DOHEX	XOR	A		;Init byte counter to 0
	LD	(DOHEX1+1),A
;
;	Stuff Record Number in Line Number buffer
;
	LD	DE,(RPARM+1)	;P/u Record Number
	LD	HL,VARCLN+1	;HL => Hex ASCII dest
	@@HEX16			;Convert DE to ASCII
;
;	Bump Record Number & stuff into RPARM
;
	INC	DE		;Bump by one
	LD	(RPARM+1),DE	;  & store for next time
;
LPARM	LD	BC,$-$		;P/u LRL
;
;	Convert Byte counter to Hex & stuff in buff
;
DISBYTE	PUSH	BC		;Save bytes left in Rec
DOHEX1	LD	C,$-$		;P/u byte counter
	LD	HL,VAREQU	;HL => Hex ASCII dest
	@@HEX8			;Cvrt C to ASCII @ HL
	POP	BC		;BC = Bytes left in Rec
;
;	Display Record Number/Starting byte string
;
	LD	HL,VARCLN	;HL => Display buffer
	CALL	PUTLINE		;Display Rec # byte
;
;	P/u byte counter & add 16 (BPL) & stuff away
;
	LD	A,(DOHEX1+1)	;P/u byte counter
	LD	B,16		;Set B = 16 bytes
	ADD	A,B		;Add 16 to byte count
	LD	(DOHEX1+1),A	;  & stuff into LD C inst
;
	LD	HL,LINBUF	;HL => Line buffer
;
;	Get a byte from the File
;
DOHEX2	LD	DE,FCB1		;DE => FCB
	@@GET			;Get a byte
	JR	Z,DOHEX4	;Good - stuff byte
;
;	End of File Error ?
;
	PUSH	AF		;Save error code
	CP	1CH		;EOF?
	JR	Z,DOHEX3	;Yes - Okay
;
;	Past End of File Error ?
;
	CP	1DH		;NRN>ERN?
	JP	NZ,IOERR	;Another error
;
;	Recover Flags & check type of Error
;
DOHEX3	POP	AF		;Recover error code
DOHEX4	JR	NZ,DOHEX5	;Bypass if at end of file
;
;	Stuff Character in buffer & bump
;
	LD	(HL),A		;Stuff byte in buffer
	INC	HL		;Bump ptr
;
;	Output byte in Hex & follow with a space
;
	CALL	CVTHEX		;Output the byte in hex
	LD	A,' '		;  followed by a space
	CALL	PUTOUT
;
;	Output an extra space if halfway in line
;
	LD	A,B		;P/u byte counter
	CP	9		;Halfway yet?
	CALL	Z,WR1SPA	;Yes - display space
;
;	Dec Chars/Line & # of chars left in Rec
;
	DEC	B		;Count down
	DEC	C		;Count down the LRL
	JR	Z,DOHEX5	;Done - get next record
;
;	Finished with Line ?
;
	LD	A,B		;Done with line ?
	OR	A
	JR	NZ,DOHEX2	;No - do til 16 chars
;
;	Finished with Line or Logical Record
;
DOHEX5	PUSH	AF		;End the line
	LD	A,B		;P/u byte counter
	CP	16		;Done with this line ?
	JR	Z,PRTLIN2	;Yes - get another record
;
;	Display ASCII equivalent of line
;
PRTLIN	PUSH	BC		;Save counters
;
;	Multiply # of chars not printed by three
;
	LD	A,B		;P/u # chars not printed
	ADD	A,A		;X 2
	ADD	A,B		;X 3
	LD	B,A		;Stuff in B
;
;	Add two extra spaces if more than halfway
;
	CP	27		;Need extra space if
	CCF			;Not halfway
	LD	A,1		;Plus 1 more space
	ADC	A,B		;Carry set for 3 spaces
;
;	Position to ASCII portion of line
;
	LD	B,A		;Set loop counter
	CALL	WRSPA		;Output B spaces
	POP	BC		;Recover the counters
;
;	Calculate # of characters to print
;
	LD	A,16		;Get # to print
	SUB	B
	LD	B,A		;Xfer to B for DJNZ
	LD	HL,LINBUF	;HL => Line buffer
	PUSH	BC		;Save C
	LD	C,8		;Space after 8
;
;	Display ASCII part of line
;
PRTLIN1	LD	A,(HL)		;P/u character
	INC	HL		;Bump ptr
	CALL	CVTDOT		;Output each char
	DEC	C		;Space yet ?
	CALL	Z,WR1SPA	;Yes - display space
	DJNZ	PRTLIN1		;Output line
	POP	BC		;Recover C
;
;	End of Line - Output C/R & check for EOF
;
PRTLIN2	LD	A,CR		;Output C/R
	CALL	PUTOUT
	POP	AF		;Recover @GET ret code
	LD	A,1CH		;Init to EOF
	JP	NZ,GOTERR	;End of file - Abort
;
	CALL	CKPAWS		;<PAUSE> or <BREAK> ?
;
;	Are we done with the Record ?
;
	LD	A,C		;P/u # of bytes left
	OR	A		;Finished ?
	JP	NZ,DISBYTE	;No - get next line
;
;	Finished with record - Output space & C/R
;
	LD	A,' '		;Space
	CALL	PUTOUT
	LD	A,CR		;Carriage Return
	CALL	PUTOUT
;
;	Increment Line Number
;
	LD	HL,VARCLN	;HL => Line Number
	CALL	INCNUM		;Increment
	JP	DOHEX		;Loop for more
;
;	CVTDOT - Output chars & convert non-printables
;
CVTDOT	CP	' '		;Don't print controls
	JR	C,CVTDOT1
	CP	7FH		;Print X'20' thru X'7E'
	JR	C,PUTOUT
CVTDOT1	LD	A,'.'		;Otherwise change to "."
	JR	PUTOUT
;
;	CVTHEX - Convert A to Hex ASCII & Output it
;
CVTHEX	PUSH	AF		;Save Lower digit
	RRCA			;Get most sig nibble
	RRCA
	RRCA
	RRCA
	CALL	CVTH1		;Output upper nibble
	POP	AF		;Recover #
;
CVTH1	AND	0FH		;Mask off upper nibble
	ADD	A,90H		;Convert to Hex digit
	DAA
	ADC	A,40H
	DAA			;Fall into Output byte
;
;	PUTOUT - Put out a byte to *DO/*PR
;
PUTOUT	PUSH	BC		;Save BC
	LD	C,A		;Xfer char to C
;
;	Output byte to *DO or *PR
;
PUTOUT1	LD	A,@DSP		;@DSP or @PRT SVC #
	RST	28H
	JP	NZ,IOERR	;NZ - I/O Error
;
;	Increment byte counter
;
	PUSH	HL		;Save HL
	LD	HL,BYTCTR	;HL => Byte counter
	INC	(HL)		;Bump counter
	IF	@BLD631
	LD	A,(HL)		;<631>
	SUB	50H		;<631>
	JR	C,L267A		;<631>
	LD	(HL),A		;<631>
L267A:	LD	A,C		;<631>
	SUB	0AH		;<631>
	JR	Z,L2683		;<631>
	SUB	03H		;<631>
	JR	NZ,L2684	;<631>
L2683:	LD	(HL),A		;<631>
L2684:	INC	(HL)		;<631>
	DEC	(HL)		;<631>
	POP	HL		;<631>
	POP	BC		;<631>
	RET	NZ		;<631>
SPARM:	EQU	$
	LD	DE,0		;<631>
	LD	A,D		;<631>
	OR	E		;<631>
	RET	NZ		;<631>
L2690:	EQU	$+1
	LD	A,11H		;<631>
	DEC	A		;<631>
	LD	(L2690),A	;<631>
	RET	NZ		;<631>
	@@KEY			;<631>
	CP	80H		;<631>
	JP	Z,GOTBRK	;<631>
	SUB	43H		;<631>
	JR	Z,L26A6		;<631>
	SUB	' '		;<631>
	JR	NZ,L26AA	;<631>
L26A6:	LD	(SPARM+1),DE	;<631>
L26AA:	LD	A,69H		;<631>
L26AC:	RST	28H		;<631>
L26AE:	EQU	$+1
	LD	A,11H		;<631>
	LD	(L2690),A	;<631>
	RET			;<631>
	ELSE
	LD	A,C		;P/u byte
	CP	CR		;End of line ?
	JR	NZ,NOTCR	;No - rest regs & RETurn
;
	LD	(HL),0		;Reset byte counter
NOTCR	POP	HL		;Restore registers
	POP	BC
	RET			;  & RETurn
	ENDIF
;
;
;	Output B spaces to Display or Printer
;
WRSPA	CALL	WR1SPA		;Write a space
	DJNZ	WRSPA		;Do it B times
	RET			;RETurn
;
;	Output a space to Display or Printer
;
WR1SPA	LD	A,' '		;Space Character
	JR	PUTOUT		;Output byte
;
;	PUTLINE - Output a line to the video or printer
;	HL => Line of data to output
;
PUTLINE	LD	A,(HL)		;P/u byte
	INC	HL		;Prepare for next
	CP	ETX		;Check if done none
	RET	Z		;  return if so
	CALL	PUTOUT		;Char OK output it
	IF	@BLD631
	ELSE
	CP	CR		;Check for CR
	RET	Z		;  return if so
	ENDIF
	JR	PUTLINE
;
;	CKPAWS - Check for Pause (SHIFT @)
;
CKPAWS	@@FLAGS			;IY => System flags
;
;	Was the <BREAK> key pressed ?
;
	@@CKBRKC		;<BREAK> hit ?
	JR	NZ,GOTBRK	;Quit if so
;
;	Was the <SHIFT><@> pressed ?
;
	BIT	1,(IY+KFLAG$)	;Is the <PAUSE> bit set ?
	RET	Z		;Return if not <SHIFT><@>
;
;	Pause - Wait for key to continue
;
CKWAIT	@@KEY			;Wait for key press
CKWAIT1	CP	60H		;Was key a <SHIFT @>?
	JR	Z,CKWAIT	;Ignore if it was
	CP	80H		;Was key a Break?
	JR	Z,GOTBRK	;Quit if so
;
;	Reset <PAUSE> & <ENTER> bits & RETurn
;
RESKFL	@@FLAGS			;IY => Flag Table
	LD	A,(IY+KFLAG$)	;P/u KFLAG$
	AND	0F9H		;Reset Pause and Enter
	LD	(IY+KFLAG$),A	;Stuff into KFLAG$
	RET
;
;	<BREAK> hit - Display C/R & Abort
;
GOTBRK	LD	A,CR		;Send end of line
	CALL	PUTOUT		;Output byte
	JP	ABORT		;  and abort due to BREAK
;
;	CVTDEC - Convert HL to Decimal & stuff in BC
;
CVTDEC	LD	DE,10000	;Divide by 10000
	CALL	CVD1
	LD	DE,1000		;Divide by 1000
	CALL	CVD1
	LD	DE,100		;Divide by 100
	CALL	CVD1
	LD	DE,10		;Divide by 10
	CALL	CVD1
	LD	DE,1		;Divide by 1
;
;	Divide Quotient in HL by value in DE
;
CVD1	XOR	A		;Clear carry set A=0
CVD2	SBC	HL,DE		;Subtract Divisor
	JR	C,CVD3		;Done - add back divisor
	INC	A		;Bump counter
	JR	CVD2		;Subtract until a Carry
;
;	Add divisor to neg rem & cvrt A to ASCII
;
CVD3	ADD	HL,DE		;HL = New quotient
	ADD	A,'0'		;A = ASCII numeric digit
	CP	'0'		;Zero ?
	JR	NZ,CVD4		;No - stuff in buff (BC)
;
;	Char is a Zero - use space if leading zero
;
	DEC	BC		;Backspace buff ptr
	LD	A,(BC)		;P/u last char
	INC	BC		;Bump to currentt
	CP	' '		;Last char a space ?
	JR	Z,CVD4		;Yes - don't use lead 0
	LD	A,'0'		;No - use zero
;
;	Stuff Numeric ASCII character into buffer
;
CVD4	LD	(BC),A		;Stuff char in buff
	INC	BC		;Bump ptr
	RET			;RETurn
;
;	INCNUM - Increment Line number in buffer (HL)
;
INCNUM	INC	HL		;Point to lo-order digit
	INC	HL
	INC	HL
	INC	HL
;
;	Loop to Increment digit and return if done
;
INCNUM1	LD	A,(HL)		;P/u digit
	OR	'0'		;Start with possible 0
	INC	A		;Add 1
	LD	(HL),A		;Restuff
	SUB	'9'+1		;See if went to 10
	RET	C		;Ret if not
	LD	(HL),'0'	;Make it 0
	DEC	HL		;B/u one
	JR	INCNUM1		;  & loop
;
;	OPEN - Open a file
;
OPEN	@@FLAGS			;IY => System Flags
	SET	0,(IY+SFLAG$)	;P/u SFLAG$
	LD	HL,IOBUFF	;HL => I/O buffer
	@@OPEN			;Open the file
	RET			;  & RETurn with condition
;
SPCREQ$	DB	'File spec required',CR
;
;
VARDOT	DB	'     . ',ETX
VARCLN	DB	'     :'
VAREQU	DB	'XX =  ',ETX
TXTEXT	DB	'TXT'
;
;
;	PARAMETER TABLE
;
PRMTBL$	DB	80H
;
;	 ASCII8 (A8) - Flag input only 
;
	DB	FLAG!6
	DB	'ASCII8'
	DB	0
	DW	A8PARM+1
;
	DB	FLAG!2
	DB	'A8'
	DB	0
	DW	A8PARM+1
;
;	 LINE - Numeric input only 
;
	DB	NUM!4
	DB	'LINE'
	DB	0
	DW	LINPRM+1
;
	IF	@BLD631
;	 NUM (N) - Flag input only 
;
	DB	FLAG!3			;<631>
	ELSE
;	NUM (N) - Flag input only
;
	DB	FLAG!ABB!3
	ENDIF
	DB	'NUM'
	DB	0
	DW	NPARM+1
	IF	@BLD631
;
;	NS (N) - Flag input only
;
	DB	FLAG!ABB!2
	DB	'NS'
	DB	0
	DW	SPARM+1
	ENDIF
;
;	 HEX (H) - Flag input only 
;
	DB	FLAG!ABB!3
	DB	'HEX'
	DB	0
	DW	HPARM+1
;
;	 REC (R) - Numeric input only 
;
	DB	NUM!ABB!3
	DB	'REC'
	DB	0
	DW	RPARM+1
;
;	 LRL (L) - Numeric input only 
;
	DB	NUM!ABB!3
	DB	'LRL'
LRESP	DB	0
	DW	LPARM+1
;
;	 P - Flag input only 
;
	DB	FLAG!1
	DB	'P'
	DB	0
	DW	PPARM+1
;
;	 TAB (T) - Flag input only 
;
	DB	FLAG!ABB!3
	DB	'TAB'
TRESP	DB	0
	DW	TPARM+1
;
	DB	0
;
;Buffer Area
;
BYTCTR	DS	1
LINBUF	DS	16
FCB1	DS	32
FCB2	DS	32
;
	ORG	$<-8+1<+8
IOBUFF	DS	256
;
	END	START
