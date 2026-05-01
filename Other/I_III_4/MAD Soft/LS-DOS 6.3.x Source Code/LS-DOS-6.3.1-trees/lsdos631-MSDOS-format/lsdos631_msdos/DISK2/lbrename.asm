;LBRENAME/ASM - RENAME Command
	TITLE	<RENAME - LS-DOS 6.2>
;
*GET	BUILDVER/ASM:3
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	VALUES:3		;Misc. equates
;
INH	EQU	0		;Inhibit LRL Fault
;
	ORG	2400H
;
RENAME
	IF	@BLD631
	LD	(SAVESP+1),SP	;<631>Save SP
	ENDIF
	@@CKBRKC		;Break key down?
	IF	@BLD631
	JR	NZ,ABORT	;<631>abort
	ELSE
	JR	Z,BEGINA	;Ok if not
	LD	HL,-1		;  else abort
	RET
;
BEGINA	LD	(SAVESP+1),SP	;Save SP
	ENDIF
	CALL	RENAM		;Rename File/Device
	LD	HL,0		;Init successful
	JR	Z,SAVESP	;Z - successful rename
;
;	I/O Error Processing
;
IOERR	LD	L,A		;Error # to HL
	LD	H,0
	OR	0C0H		;Set to brief & return
	LD	C,A		;Xfer error code
	@@ERROR
	JR	SAVESP		;Restore stack & RET
;
;	Internal Message Error Processing
;
SPCERR	LD	HL,SPCERR$
	DB	0DDH
DUPNAM	LD	HL,DUPNAM$
	DB	0DDH
TOWHAT	LD	HL,TOWHAT$
	@@LOGOT
	IF	@BLD631
ABORT
	ENDIF
	LD	HL,-1
;
;	Clean up stack & clear any pending <BREAK>s
;
SAVESP	LD	SP,$-$		;P/u original SP
	@@CKBRKC		;Clear any <BREAK>
	RET
;
;	RENAM - Rename a filespec or devspec
;
RENAM	PUSH	HL		;Save cmd line ptr
	LD	DE,TEMPFCB	;Xfer Filespec to buffer
	@@FSPEC
	POP	HL		;Ignore error
	@@FLAGS			;IY => Flag Table
	LD	DE,OLDFCB	;Get filespec
	@@FSPEC
	JR	NZ,SPCERR	;Quit if bad source name
	LD	DE,NEWFCB	;Get new name
	@@FSPEC
	CALL	NZ,CVRTUC	;Cvrt partial spec to UC
REN1	LD	A,(NEWFCB)	;If new name starts out
	CP	CR+2		;  with something less
	JP	C,TOWHAT	;  than X'0E', to what ?
	LD	HL,OLDFCB
	LD	DE,NEWFCB
	LD	A,(HL)		;Check on device rename
	CP	'*'
	JP	Z,DEVREN
	LD	A,(DE)		;Old is file, new must
	CP	'*'		;  be also
	JR	Z,SPCERR
;
;	Renaming Files - Can we OPEN old file ?
;
	LD	DE,TEMPFCB	;Can we OPEN it ?
	SET	INH,(IY+SFLAG$)	;Inhibit open bit set
	@@OPEN
	RET	NZ		;NZ - "File not Found"
	LD	BC,(TEMPFCB+6)	;P/u drive #/DEC
;
;	Good Open - Is there a drivespec in string ?
;
	PUSH	HL		;Save ptr
FLOOP	LD	A,(HL)		;P/u char
	CP	CR+1		;End of Filespec ?
	JR	NC,CHKDSPC
;
;	Drivespec wasn't specified - put it on
;
	LD	(HL),':'	;Append drivespec onto
	INC	HL		;  end of filespec
	LD	A,C		;Xfer drive # to A
	ADD	A,'0'		;Convert to ASCII
	LD	(HL),A
	LD	(OLD_DRV+1),A	;Self-modify NEW FCB
	INC	HL		;Bump
	LD	(HL),CR		;End of filespec
	JR	DOMATCH		;Get defaults
;
;	Stop when ":" hit or terminator
;
CHKDSPC	CP	':'		;Already have one ?
	INC	HL
	JR	NZ,FLOOP
	LD	A,(HL)		;P/u drive #
	LD	(OLD_DRV+1),A	;Self-modify NEW FCB
DOMATCH	POP	HL		;HL => Old FCB
	LD	DE,NEWFCB	;DE => New FCB
	CALL	MATCH
;
;	Make sure NEW drivespec is same as OLD one
;
	PUSH	DE		;Save New
F2LOOP	LD	A,(DE)		;Go until ":"
	INC	DE
	CP	':'
	JR	NZ,F2LOOP
OLD_DRV	LD	A,$-$		;P/u OLD drivespec
	LD	(DE),A		;Overwrite
	POP	DE		;Restore DE
;
;	Does the NEW filename already exist ?
;
	PUSH	HL		;Save OLD ptr
	PUSH	DE		;Save NEW ptr
	EX	DE,HL
	LD	DE,TEMPFCB	;DE => Temp buffer
	SET	INH,(IY+SFLAG$)
	@@FSPEC			;Xfer filespec
	@@OPEN			;File already exist ?
	JP	Z,DUPNAM	;Error if so
	POP	DE		;Restore ptrs
	POP	HL
REN2	PUSH	HL		;OLD Filename/Device
	PUSH	DE		;NEW Filename/Device
;
;	Xfer the OLD & NEW specs to SPEC$ minus PASSWORD
;
	LD	DE,SPECS$
	CALL	MOVSPC		;Move the OLD spec
	LD	HL,TO$
	LD	BC,4
	LDIR			;Move ' to '
	POP	HL		;Recover NEW spec
	PUSH	HL
	CALL	MOVSPC		;Move the NEW spec
	LD	A,CR
	LD	(DE),A		;Terminate with CR
	@@LOGOT	RENAM$		;Send names to video
	POP	HL		;Recover new
	POP	DE		;Recover old
	@@RENAM			;Rename file
	RET			;Return with condition
;
;	MOVSPC - Create Secondary Spec
;
MOVSPC	LD	A,(HL)		;P/u a spec character
	CP	'/'		;Extension ?
	JR	NZ,CKSPACE	;No - check if space
	INC	HL		;Is the next character
	LD	A,(HL)		;  valid ?
	CP	'A'
	JR	C,CKSPACE	;No - don't output it
	DEC	HL		;Back one
	LD	A,(HL)		;P/u slash
CKSPACE	CP	' '
	RET	C		;Exit on terminator
	CP	'.'		;If password, ignore it
	JR	NZ,MOVSPC1
SKIPPW	INC	HL
	LD	A,(HL)
	CP	' '
	RET	C		;Back on terminator
	CP	':'
	JR	NZ,SKIPPW
MOVSPC1	LDI			;Move the char
	JR	MOVSPC
;
;	Routine to rename a device
;
DEVREN	LD	A,(DE)		;Old was device, new must
	CP	'*'		;  also be a device spec
	JP	NZ,SPCERR	;Abort if bad
;
;	Does the Source Devspec exist ?
;
	PUSH	HL		;Save Old Device name
	PUSH	DE		;Save New Device name
	INC	HL		;Bump past "*"
	LD	E,(HL)		;Set DE = Device name
	INC	HL
	LD	D,(HL)
	@@GTDCB			;Does it exist ?
	JP	NZ,IOERR	;NZ - "Dev not Available"
;
;	P/u the Job Log DCB Address (last DCB)
;
	LD	B,H		;Save DCB ptr in BC
	LD	C,L
	LD	DE,'LJ'		;Find *JL
	@@GTDCB
	INC	HL		;Pt HL => Past Protected
	OR	A		;  system Device table.
	SBC	HL,BC		;Protected Device ?
	LD	A,40		;Init errcode
	JP	NC,IOERR	;Jump on error
;
;	Does the destination device already exist ?
;
	POP	HL		;HL => New Devspec
	PUSH	HL
	INC	HL		;Bump past "*"
	LD	E,(HL)		;Set DE = Device name
	INC	HL
	LD	D,(HL)
	@@GTDCB			;Already Exist ?
	LD	A,39		;Yes - Device in use
	JP	Z,IOERR
	POP	DE		;Restore NEW & OLD ptrs
	POP	HL
	JP	REN2
;
;	Routine xfers partial filespec & cvrts to UC
;
CVRTUC	LD	A,(HL)
	CP	CR
	RET	Z		;Ret if no new name
	DEC	HL		;Backup to 1st separator
COP0	LD	A,(HL)
	INC	HL
	CP	' '		;Skip past spaces
	JR	Z,COP0
	DEC	HL
	LD	B,32		;Max 32 chars
COP1	LD	A,(HL)		;Transfer the partial
COP2	CP	'a'		;Cvrt lc <a-z> to uc
	JR	C,COP3
	CP	'z'+1
	JR	NC,COP3
	SUB	20H
COP3	LD	(DE),A		;Filespec until paren
	CP	CR		;  or <ENTER>
	RET	Z
	CP	'('
	RET	Z
	INC	HL		;  or end-of-line
	INC	DE		;  or 32 chars max
	DJNZ	COP1
	RET
;
;	Match source & destination for defaults
;
MATCH	PUSH	DE		;Save NEW spec
	PUSH	HL		;Save OLD spec
	LD	A,(DE)		;P/u a dest character
	CP	'A'
	CALL	C,MATCH7	;Match if not a filename
	LD	B,'/'
	CALL	MATCH2
	LD	B,':'
	CALL	MATCH2
	LD	B,'.'
	CALL	MATCH2
	POP	HL
	POP	DE
	RET
;
MATCH1	INC	DE
MATCH2	LD	A,(DE)		;Scan destination until
	CP	B		;  the test character is
	JR	Z,MATCH3	;  found or until some
	CP	'A'		;  other special char
	JR	NC,MATCH1	;  is reached
	CP	'0'		;Loop on <0-9>
	JR	C,MATCH4
	CP	'9'+1
	JR	C,MATCH1
	JR	MATCH4
MATCH3	INC	DE
	RET
;
;	Found some other special char - Need the field
;
MATCH4	PUSH	HL		;Save pointer to source
MATCH5	LD	A,(HL)		;Scan source until the
	INC	HL		;  desired field is
	CP	ETX		;  found (if it is
	JR	Z,MATCH6	;  supplied by the user)
	CP	CR
	JR	Z,MATCH6
	CP	B
	JR	NZ,MATCH5
	CALL	MATCH9		;Move source field
MATCH6	POP	HL
	RET
;
;	Routines to move a source field to destination
;
MATCH7	LD	A,(HL)		;P/u source character
	CP	'0'		;Back when out of range
	RET	C
	CP	'9'+1
	JR	C,MATCH8
	CP	'A'
	RET	C
MATCH8	INC	HL		;Advance source ptr
MATCH9	PUSH	HL		;Save HL and make it
	LD	H,D		;  the destination ptr
	LD	L,E
MATCH10	LD	C,(HL)		;Get char at destination
	LD	(HL),A		;  and put in new one
	INC	HL		;Next dest loc.
	LD	A,C		;What was there?
	CP	ETX		;Go until ETX
	JR	Z,MATCH11
	CP	CR		;  or end of line
	JR	NZ,MATCH10
MATCH11	LD	(HL),A
	POP	HL
	INC	DE
	JR	MATCH7
;
SPCERR$	DB	'Specification error',CR
DUPNAM$	DB	'Duplicate file name',CR
TOWHAT$	DB	'Rename it to what?',CR
TO$	DB	' to ',ETX
NEWFCB	DB	CR		;Init to cr
	DS	31
OLDFCB	DS	32
RENAM$	DB	'Renaming: '
SPECS$	DS	40
TEMPFCB	DS	32
OLD_FIL	DW	0
LAST	EQU	$
;
	END	RENAME
