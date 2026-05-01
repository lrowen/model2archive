;<631>	This is part 2 of TED/ASM, which got so big that TED started 
;<631>	returning symbol table overflows.
;
;*=*=*
;	Routine to calculate buffer position from video position
; HL => row,col
; DE <= buffer pos
;*=*=*
CALCPOS	CALL	SETIDX
	LD	H,D
	LD	E,(IY+0)	;Get RAM position of line start
	LD	D,(IY+1)
	LD	A,D
	OR	E		;If not set, use previous
	JR	NZ,CALCP1	;  origin plus maxcol
	LD	DE,MAXCOL
	ADD	HL,DE
	LD	E,(IY-2)
	LD	D,(IY-1)
CALCP1	ADD	HL,DE
	EX	DE,HL
	RET
SETIDX	LD	E,H		;Double row count for index
	LD	D,0
	SLA	E
	LD	IY,VINDEX
	ADD	IY,DE
	RET
;*=*=*
;	Routine to check if at origin
;*=*=*
ATSTART	LD	HL,(VINDEX)	;Get origin of first row
ATBGN	LD	DE,TXTBUF
	JR	CPHLDE
;*=*=*
;	Routine to check if at end of buffer
;*=*=*
CKMEM	LD	DE,$-$		;Get end of text
ENDTXT	EQU	$-2
CKSIZE	LD	HL,$-$		;Get end of memory
MEMTOP	EQU	$-2
;*=*=*
;	Routine to compare HL to DE non-destructively
;*=*=*
CPHLDE	LD	A,H
	SUB	D
	RET	NZ
	LD	A,L
	SUB	E
	RET
;*=*=*
;	Routine to double check user request
;*=*=*
SURE	PUSH	HL
	PUSH	DE
	LD	HL,SURE$
	CALL	PROMPT
	POP	DE
	POP	HL
	SUB	CR		;Accept only CR here
	RET	Z
	POP	HL		;Pop RET to delete function
	RET			;Return to edit command
PROMPT	CALL	SETSTAT		;Display the message
	@@KEY
	CP	CR		;Check on valid character
	RET
;*=*=*
;	Routine to get input strings
;*=*=*
GETSTR	LD	HL,ASRCH$
GETINP	CALL	SETSTAT		;Display filespec prompt
	LD	HL,LINBUF	;Input buffer
	LD	B,23		;Allow up to 23 characters
	CALL	$KEYIN		;Get the filespec
	RET	NC		;Back if no break
	POP	HL		;  else pop RET & ret
	RET
;*=*=*
;	Various message output routines
;*=*=*
SETMSG	LD	HL,(IXDAT$+MSGPTR)
SETSTAT	SET	STATFLG,(IX+FLAGS)
	JR	STATUS
CSTAT	LD	HL,CSTAT$
	LD	A,(IX+FLAGS)
	AND	1.SHL.INSFLG	;Clear all but insert flag
	LD	(IX+FLAGS),A
STATUS	PUSH	DE
	PUSH	HL
	LD	HL,STATPOS
	LD	B,3
	@@VDCTL
	POP	HL
	LD	C,CLREOL
	DB	11H		;Ignore next via LD DE,nnnn
STATUS1	LD	C,(HL)
	INC	HL		;Bump to next char
	PUSH	BC
	RES	7,C
	@@DSP
	POP	BC		;P/u the char again
	BIT	7,C		;Check the high bit
	JR	Z,STATUS1
	POP	DE
	RET
;*=*=*
;	Routine to LDIR if BC <> 0
;*=*=*
MOVBLK	LD	A,B
	OR	C
	RET	Z
	LDIR
	RET
;*=*=*
;	Routine to implement "Replace string"
;*=*=*
RCMD	CALL	GETSTR		;Get the replacement string
	LD	A,B
	OR	A
	JR	Z,RCMD1		;Bypass if NULL
	LD	(IX+RPLLEN),B
	LD	DE,IXDAT$+REPLBUF
	LD	C,B
	LD	B,0
	LDIR
RCMD1	LD	HL,(BUFPOS)	;Start looking at bufpos
	DEC	HL		;Adjust for INC later
	CALL	GCMD0
	JP	NZ,NOFIND
	LD	(BUFPOS),HL	;Set found position
	LD	C,(IX+STRLEN)	;Get search length
	PUSH	HL		;Save "to"
	ADD	HL,BC		;Calc "from" [B=0]
	EX	DE,HL
	LD	HL,(ENDTXT)
	PUSH	HL
	OR	A
	SBC	HL,BC		;New endtxt
	LD	(ENDTXT),HL
	POP	HL
	CALL	SBCHLDE
	INC	BC
	EX	DE,HL		;HL = "from"
	POP	DE		;DE = "to"
	CALL	MOVBLK		;Move if not 0
	LD	DE,IXDAT$+REPLBUF-1	;Get start-1
	LD	L,(IX+RPLLEN)	;Calc end of repl string
	LD	H,B
	ADD	HL,DE
	CALL	BLKCPY1		;Copy the replacement string
	CALL	BLOCKC1		;Refresh the screen
	LD	B,(IX+RPLLEN)	;P/u the replacement string length
RCMD2	LD	HL,(WINPOS)
	CALL	$RIGHT		;Iterate the cursor right RPLLEN times
	DJNZ	RCMD2
	RET
;*=*=*
;	Routine to perform guts of block copy
;*=*=*
BLKCPY	CALL	FNDBLK		;Find the first block
	RET	NZ
	CALL	CKCIB		;Make sure cursor is NOT in block
	JP	NC,CNIBLK	;Error if inside the block
	DEC	HL		;Adjust for marker
BLKCPY1	PUSH	HL		;Save mrkend-1
	CALL	SBCHLDE		;Calc length of move_2
	PUSH	HL		;Save move_2 length
	LD	HL,(BUFPOS)
	CALL	CPHLDE		;Set CF if cursor before block
	PUSH	AF
	LD	HL,(ENDTXT)
	ADD	HL,BC		;Calc new end
	EX	DE,HL		;Move_1 "to" to DE
	CALL	NC,CKSIZE		;Is this > memtop?
	JP	C,NOMEM
	LD	HL,(ENDTXT)	;P/u current text end
	PUSH	HL
	LD	(ENDTXT),DE	;Set new end!
	LD	BC,(BUFPOS)
	SBC	HL,BC
	LD	B,H		;Len of move_1
	LD	C,L
	INC	BC
	POP	HL		;move_1 "from"
	CALL	REVBLK		;Do LDDR if BC <> 0
	POP	AF		;Get result of cursor to block
	POP	BC
	POP	HL
	JR	NC,REVBLK
	ADD	HL,BC		;mrkend got moved
REVBLK	LD	A,B
	OR	C
	RET	Z
	LDDR
	CP	A		;Set Z flag
	RET
;*=*=*
;	Routine to convert subcommands to upper case
;*=*=*
TOUPPER	CP	'a'
	RET	C
	CP	'z'+1
	RET	NC
	SUB	'a'-'A'
	RET
;*=*=*
;	Routine to find a marked block
; DE => points to starting RAM position
; HL <= pointer to begin marker
; DE <= pointer to end marker
;*=*=*
FNDBLK	LD	DE,TXTBUF	;Entry to look for 1st marked block
FNDBLK0	LD	HL,(ENDTXT)	;Calculate length of search
	CALL	ENDMDE		;(endtxt) - DE
	LD	A,BLKEND	;Search char
	EX	DE,HL		;Current pos to HL
	CPIR
	JR	NZ,MRKERR
	DEC	HL		;Back up to end marker pos
	LD	DE,TXTBUF-1	;Calculate length of compare
	PUSH	HL
	CALL	SBCHLDE
	POP	HL		;Look back from end marker
	LD	D,H
	LD	E,L		;Save end marker pos in DE
	LD	A,BLKBEG
	CPDR
	INC	HL		;Point to begin marker pos
	RET	Z
MRKERR	LD	HL,MRKERR$
	JP	STORMSG
;*=*=*
;	Routine to check if cursor is within the marked block
; HL => mrkbeg <= mrkend
; DE => mrkend <= mrkbeg
; CF <= if cursor is within the block
;*=*=*
CKCIB	PUSH	HL		;Save mrkbeg
	LD	HL,(BUFPOS)
	EX	DE,HL		;mrkend -> HL, bufpos -> DE
	CALL	CPHLDE		;mrkend-bufpos
	EX	(SP),HL		;Get HL=mrkbeg, (SP)=mrkend
	EX	DE,HL		;DE=mrkbeg, HL=bufpos
	CALL	NC,CPHLDE	;Call if bufpos is not > mrkend
	POP	HL		;Mrkend->HL, mrkbeg->DE
	RET
;*=*=*
;	Little routines for compacting
;*=*=*
ENDMDE	LD	HL,(ENDTXT)
SBCHLDE	OR	A
	SBC	HL,DE
	LD	B,H
	LD	C,L
	RET
;*=*=*
;	Internal KEYIN routine, terminats with ETX, not CR
;*=*=*
$KEYIN	LD	B,C		;move length to B
	PUSH	HL		;save buffer start
	PUSH	BC
	LD	B,4
	@@VDCTL			;obtain cursor position
	EX	DE,HL		;cursor position to DE
	POP	BC
	POP	HL
	PUSH	HL		;Save pointer to Buffer start
	LD	C,0		;init input counter
KEYIN1	PUSH	HL
	PUSH	BC
	EX	DE,HL		;cursor position to HL
	CALL	BLINK		;blink cursor
	EX	DE,HL		;cursor position back to DE
	POP	BC
	LD	HL,KEYIN1	;Set return & get HL
	EX	(SP),HL
	LD	(HL),A		;put char in buffer
	CP	BREAK
	JR	Z,K_BRK		;jump if <Break>
	CP	CR
	JR	Z,K_ENTER	;jump if <Enter>
	CP	LT$
	JR	Z,K_BKSP	;jump if <Backspace>
	CP	18H
	JR	Z,K_CLR		;jump if <Shift><Left Arrow>
	CP	128
	RET	NC		;try again
	CP	32
	RET	C		;try again
	LD	A,C		;get number input
	CP	B		; at max?
	RET	Z		;yes, then can't input any more!
	LD	A,(HL)
	INC	HL		;inc buffer pointer
	INC	C		;inc char count
	PUSH	BC
	PUSH	HL
	EX	DE,HL		;cursor position to HL
	LD	C,A
	CALL	VDPOKE		;put char on video
	INC	L
	EX	DE,HL		;cursor position back to DE
	POP	HL
	POP	BC
	RET			;to keyin1
;*=*=*
K_BRK	SCF			;Indicate BREAK
K_ENTER	LD	(HL),ETX	;terminate buffer
	LD	B,C		;move actual input to B
	POP	HL		;Pop ret to keyin1
	POP	HL		;restore buffer start
	RET
;*=*=*
K_BKSP	LD	A,C		;get number of char input
	OR	A
	RET	Z		;none input, then can't backspace!
	DEC	HL		;dec buffer pointer
	DEC	C		;dec char count
	DEC	E		;dec cursor position
	PUSH	BC
	PUSH	HL
	EX	DE,HL		;cursor to HL
	LD	C,' '
	CALL	VDPOKE
	EX	DE,HL		;cursor back to DE
	POP	HL
	POP	BC
	RET
;*=*=*
K_CLR	LD	A,C
	OR	A
	RET	Z
	CALL	K_BKSP
	JR	K_CLR
	IF	DOS5
;*=*=*
;	DOS5 VDCTL routine
;*=*=*
$CURSOR	EQU	4020H
VDCTL	DEC	B
	JR	Z,VDPEEK
	DEC	B
	JR	Z,@VDPOKE
	DEC	B
	JR	Z,SETCUR
	DEC	B
	RET	NZ
;*=*=*
;	get cursor
;*=*=*
	LD	HL,($CURSOR)
	LD	A,L
	AND	3FH		;Get column
	ADD	HL,HL		;Shift HL left by 2
	ADD	HL,HL
	LD	L,A
	LD	A,H
	AND	0FH
	LD	H,A
	RET
VDPEEK	CALL	RC2ADR
	LD	A,(DE)
	RET
@VDPOKE	CALL	RC2ADR
	LD	A,C
	LD	(DE),A
	RET
SETCUR	CALL	RC2ADR
	LD	($CURSOR),DE
	RET
RC2ADR	LD	A,H
	AND	3
	RRCA
	RRCA
	OR	L
	LD	E,A
	LD	A,H
	RRCA
	RRCA
	AND	3
	OR	3CH
	LD	D,A
	RET
	ENDIF
;*=*=*
;	Data area
;*=*=*
EXTTXT	DB	'TXT'
CSTAT$	DB	15
	IF	@@1
	DB	'OOP'
	ELSE
	DB	'TED'
	ENDIF
	IF	@BLD631
	DB	' 1.2 - (c) 1986 MISOSYS, In','c'+80H
	ELSE
	DB	' 1.1 - (c) 1986 MISOSYS, In','c'+80H
	ENDIF
EXIT$	DB	'Press <ENTER> to EXI','T'+80H
	IF	@BLD631
DRIVE$	DB	'Drive?',' '+80H	;<631>
	ENDIF
DELETE$	DB	'Delet','e'+80H
BLOCK$	DB	'Bloc','k'+80H
MRKERR$	DB	'Marker','!'+80H
NOROOM$	DB	'No room','!'+80H
CNIBLK$	DB	'Cursor','!'+80H
ASRCH$	DB	'String?',' '+80H
NOFIND$	DB	'Can''','t'+80H
	IF	@BLD631
PROMPT2	DB	'Load '				;<631>
PROMPT$	DB	'Filespec?',' '+80H		;<631>
	ELSE
PROMPT$	DB	'Filespec?',' '+80H
	ENDIF
SURE$	DB	'Press <ENTER> to confir','m'+80H
	IF	@BLD631
	ELSE
PATCH1	PUSH	HL
	LD	A,H
	ADD	A,A
	ADD	A,A
	ADD	A,H
	ADD	A,A
	LD	C,L
	LD	L,A
	LD	H,0
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	LD	B,2FH
	ADD	HL,BC
	LD	A,(DE)
	LD	(HL),A
	POP	HL
	JP	28C1H
	ENDIF
;
;End of TED2/ASM
;
	END				;<631>Return to TED/ASM
