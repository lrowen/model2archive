;TED/ASM	05/11/87 - WDS - Patch #1 and #2 installed
		;06/09/87 - WDS - PATCH FOR LOAD DURING INSERT
	TITLE	'<TED - CMD file>
;*=*=*
; 07/02/86 - Added TED *
; 09/23/86 - Added command-line filespec
; 09/25/86 - Switched to use ECM for DOS5
; 10/24/86 - Re-fixed bug in CALCBOL and erroneous exit
;	if <ENTER> on ^F
;*=*=*
DOS6	EQU	-1
DOS5	EQU	0
ETX	EQU	3
CR	EQU	0DH
CLREOL	EQU	1EH
BLKBEG	EQU	0FEH		;Marker for block begin
VIDBEG	EQU	0B7H
BLKEND	EQU	0FFH		;Marker for block end
VIDEND	EQU	0BBH
VIDCR	EQU	84H		;CR screen char
	IF	DOS6
MOD1	EQU	0
MOD3	EQU	0
LT$	EQU	08H
RT$	EQU	09H
DN$	EQU	0AH
UP$	EQU	0BH
SLT$	EQU	18H
SRT$	EQU	19H
SDN$	EQU	1AH
SUP$	EQU	1BH
BREAK	EQU	80H
STATPOS	EQU	23.SHL.8+0
MAXROW	EQU	22
MAXCOL	EQU	80
SWAPBUF	EQU	2400H
IOBUF	EQU	SWAPBUF
LINBUF	EQU	SWAPBUF
	ORG	2600H
*GET	BUILDVER/ASM:3		;<631>
*GET	SVCMAC
	ENDIF
	IF	DOS5
LT$	EQU	81H
RT$	EQU	84H
DN$	EQU	88H
UP$	EQU	82H
SLT$	EQU	91H
SRT$	EQU	94H
SDN$	EQU	1AH
SUP$	EQU	92H
BREAK	EQU	01H
STATPOS	EQU	15.SHL.8+0
MAXROW	EQU	14
MAXCOL	EQU	64
*LIST	OFF
*GET	VERSION
	IF	MOD1
*GET	MOD1/EQU
	ENDIF
	IF	MOD3
*GET	MOD3/EQU
	ENDIF
@@ERROR	MACRO
	CALL	@ERROR
	ENDM
@@DSP	MACRO
	LD	A,C
	CALL	@DSP
	ENDM
@@HIGH$ MACRO
	LD	HL,(HIGH$)
	ENDM
@@VDCTL	MACRO
	CALL	VDCTL
	ENDM
@@CLS	MACRO
	CALL	@CLS
	ENDM
@@FSPEC	MACRO
	CALL	@FSPEC
	ENDM
@@FEXT	MACRO
	CALL	@FEXT
	ENDM
@@INIT	MACRO
	CALL	@INIT
	ENDM
@@WRITE	MACRO
	CALL	@WRITE
	ENDM
@@CLOSE	MACRO
	CALL	@CLOSE
	ENDM
@@FLAGS	MACRO
	ENDM
@@OPEN	MACRO
	CALL	@OPEN
	ENDM
@@READ	MACRO
	CALL	@READ
	ENDM
@@KBD	MACRO
	CALL	@KBD
	ENDM
@@DIV16	MACRO
	CALL	@DIV16
	ENDM
@@KEY	MACRO
	CALL	@KEY
	ENDM
*LIST	ON
	ORG	5200H
	ENDIF
;*=*=*
INSFLG	EQU	0		;Set if in insert mode
DELFLG	EQU	1		;Set if in delete mode
BLKFLG	EQU	2		;Set if in block mode
MSGFLG	EQU	6		;Set if message to display
STATFLG	EQU	7		;Set if status line to be cleared
IXDAT$	EQU	$
;*=*=*
;	Indexed Data storage
;*=*=*
	DS	9
OLDBNK	EQU	00H		; 00 = current bank installed
RAMBNK	EQU	01H		; 01 = RAM bank used for swap
SWPCNT	EQU	02H		; 02 = memory block swap count
SWPMAX	EQU	03H		; 03 = maximum blocks to swap
FLAGS	EQU	04H		; 04 = 
CURSOR	EQU	05H		; 05 = 
STRLEN	EQU	06H		; 06 = search string length
RPLLEN	EQU	07H		; 07 = replace string length
MSGPTR	EQU	08H		; 08/09 = pointer to message
	DS	32
FCB	EQU	0AH		;FCB offset [32]
	DS	24
SRCHBUF	EQU	FCB+32		;Search string buffer [23+1]
	DS	24
REPLBUF	EQU	SRCHBUF+24	;Replace string buffer [23+1]
	COM	'<Copyright (c) 1986 MISOSYS, Inc., All rights reserved>'
;*=*=*
START	JR	BEGIN
;*=*=*
;	Table of command keys
;*=*=*
CMD	MACRO	#KEYCHAR,#VECTOR
	DB	#KEYCHAR
	DW	#VECTOR
	ENDM
CURCHAR	DB	5FH,0BFH		;overstrike,insert
KEYTAB	CMD	LT$,LEFT		;<LEFT> move cursor left
	CMD	RT$,RIGHT		;<RIGHT> move cursor right
	CMD	DN$,DOWN		;<Down arrow> move cursor down
	CMD	UP$,UP			;<Up arrow> move cursor up
	CMD	0DH,ENTER		;<Enter> - treat as entry
	CMD	SLT$,FARLEFT		;<Shift><LEFT> move far left
	CMD	SRT$,FARRITE		;<Shift><RIGHT> move far right
	CMD	SDN$,FARDOWN		;<Shift-DN> move to bottom
	CMD	SUP$,FARUP		;<Shift-UP> move to top
	CMD	'A'&1FH,ADDCMD		;^A - insert mode
	CMD	'B'&1FH,BCMD		;^B - block...
	CMD	'D'&1FH,DELCHAR		;^D - delete mode
	CMD	'F'&1FH,DOSAVE		;^F - file buffer
	CMD	'G'&1FH,GCMD		;^G - go to next match
CMDL	CMD	'L'&1FH,DOLOAD		;^L - Load a file
	CMD	'N'&1FH,NEXTPG		;^N - next page
	IF	@BLD631
	CMD	'P'&1FH,PCMD		;<631>^P - 
	CMD	'Q'&1FH,QCMD		;<631>^Q -
	ENDIF
	CMD	'R'&1FH,RCMD		;^R - replace string
	CMD	'S'&1FH,SCMD		;^S - search for string
	CMD	'U'&1FH,PREVPG		;^U - previous page
	CMD	'='+80H,XCMD		;<Clear Shift => - exit
NKEYS	EQU	$-KEYTAB/3
BEGIN
	IF	DOS5
	LD	A,(DFLAG$)
	BIT	4,A
	JR	NZ,BEGIN1
	LD	HL,REQKI$
	CALL	@LOGOT
	JP	@ABORT
REQKI$	DB	'TED requires KI/DVR!',CR
BEGIN1	EQU	$
	ENDIF
	LD	IX,IXDAT$	;Set data pointer
	PUSH	HL		;Save command line pointer
	IF	DOS5
	LD	HL,KFLAG$
	SET	6,(HL)		;Turn on ECM
	ENDIF
	LD	HL,0		;Get current HIGH$
	LD	(IXDAT$+STRLEN),HL ;Clear search & replace lengths
	LD	B,L
	@@HIGH$
	LD	(MEMTOP),HL
	LD	HL,MAXROW*MAXCOL+VIDBUF
	LD	BC,MAXCOL.SHL.8+'_'
$$1	LD	(HL),C
	INC	HL
	DJNZ	$$1
	LD	BC,MAXCOL.SHL.8+' '
$$2	LD	(HL),C
	INC	HL
	DJNZ	$$2
	POP	HL		;Recover command line pointer
	LD	A,(HL)		;Check on TED * to inhibit clear
	EX	DE,HL		;Command line pointer to DE
	LD	HL,TXTBUF
	CP	'*'
	JR	Z,$$3
	LD	(HL),B		;Clear buffer
$$3	LD	(IX+FLAGS),81H	;Clear flag bits
	CALL	ADDCMD		;Set overstrike cursor
	EX	DE,HL		;Get command line pointer
	LD	A,(HL)
	CP	'A'
	JR	C,$$4		;Go if not a filespec
	LD	DE,LINBUF
	LD	BC,24
	LDIR
	LD	A,(CMDL)	;Get load command letter
	LD	(SAVCMD),A
$$4	CALL	$EDIT
	@@CLS
	IF	DOS5
	LD	HL,KFLAG$
	RES	6,(HL)
	ENDIF
	LD	HL,0
	RET
XCMD	LD	A,(TXTBUF)	;If no text in buffer,
	OR	A		;  don't prompt
	LD	HL,EXIT$
	CALL	NZ,PROMPT
	RET	NZ		;Back if no CR
	POP	HL		;Pop the RET address to EDIT
	RET
;*=*=*
;	Commands and subcommands of "block"
;*=*=*
BCMD	SET	BLKFLG,(IX+FLAGS) ;Indicate block mode
	LD	HL,BLOCK$
	DB	0FDH
CNIBLK	LD	HL,CNIBLK$
	DB	0FDH
NOFIND	LD	HL,NOFIND$
STORMSG	LD	(IXDAT$+MSGPTR),HL
	SET	MSGFLG,(IX+FLAGS)
	RES	STATFLG,(IX+FLAGS) ;Inhibit clear of status
	INC	H		;Set NZ condition
	RET
;*=*=*
;	Routine to move a block
;*=*=*
BLOCKM	CALL	BLKCPY		;Copy the block, first
	RET	NZ		;Back on error
	CALL	FNDBLK		;Find the block again
	PUSH	HL
	CALL	SBCHLDE
	LD	HL,(BUFPOS)	;Is the deleted block
	CALL	CPHLDE		;  before or after the cursor?
	JR	C,BLOCKM1
	ADD	HL,BC		;Reduce pointer by length of block
	DEC	HL		;Readjust because BC not adjusted by 1
BLOCKM1	EX	(SP),HL		;Reget block marker pointer
	JR	BLOCKD1		;Now delete it
;*=*=*
;	Routine to delete a marked block
;*=*=*
BLOCKD	CALL	FNDBLK0
	RET	NZ		;Back if marker error
	CALL	CKCIB		;Check if cursor is in the block
	JR	C,CNIBLK	;Error if not in the block
	CALL	SURE		;Check on it!
	EX	DE,HL		;Re-correct marker pointers
	DB	0F6H		;Make OR n for entry NZ
BLOCKD1	XOR	A		;Make entry Z
	PUSH	AF
	PUSH	HL		;Save "to"
	CALL	ENDMDE		;(endtxt) - DE
	POP	HL
	INC	DE		;Adjust "from" to pos after marker
	EX	DE,HL		;"from" to HL; "to" to DE
	PUSH	DE		;Save "to"
	LDIR
	DEC	DE
	LD	(ENDTXT),DE	;Reduce (ENDTXT)
	POP	HL		;Recover "to" & see if it's at start
	POP	AF		;Recover entry state
	JR	NZ,BLOCKC2	;Go if block delete
	POP	HL		;Old bufpos
	JR	BLOCKC2
CKBLK	CALL	TOUPPER
	IF	@BLD631
	CP	'P'		;<631>
	JR	Z,L2790		;<631>
	ENDIF
	CP	'M'		;Move block?
	JR	Z,BLOCKM
	SUB	'B'		;Begin block?
	JR	Z,BLOCKB
	DEC	A		;<C> Copy block?
	JR	Z,BLOCKC
	DEC	A		;<D> Delete block?
	JR	Z,BLOCKD
	DEC	A		;<E> End block?
	RET	NZ
;*=*=*
;	Block end
;*=*=*
BLOCKE	LD	A,BLKEND
	DB	1		;Ignore next inst via LD BC,nnnn
;*=*=*
;	Block begin
;*=*=*
BLOCKB	LD	A,BLKBEG	;Set compare to block begin
	LD	B,(IX+FLAGS)	;Save old flag state
	PUSH	BC
	SET	INSFLG,(IX+FLAGS) ;Force EDIT3 to insert the marker
	CALL	EDIT3
	POP	AF		;Get old flag state into reg_A
	SET	STATFLG,A	;Indicate clear status
	JP	SETFLAG
;*=*=*
;	Routine to copy a block
;*=*=*
BLOCKC	CALL	BLKCPY
BLOCKC1	RET	NZ		;Back if error
	LD	HL,(BUFPOS)
BLOCKC2	JP	REF@HL		;Go refresh the screen
	IF	@BLD631
L2790:	CALL	FNDBLK		;<631>
	RET	NZ		;<631>
	INC	HL		;<631>
	EX	DE,HL		;<631>
	CALL	SBCHLDE		;<631>
	JR	L27A1		;<631>
PCMD:	LD	DE,TXTBUF	;<631>
	CALL	ENDMDE		;<631>
L27A1:	EX	DE,HL		;<631>
L27A2:	LD	A,B		;<631>
	OR	C		;<631>
	RET	Z		;<631>
	PUSH	BC		;<631>
	LD	C,(HL)		;<631>
	INC	HL		;<631>
	@@PRT			;<631>
	POP	BC		;<631>
	JP	NZ,IOERR	;<631>
	@@CKBRKC		;<631>
	RET	NZ		;<631>
	DEC	BC		;<631>
	JR	L27A2		;<631>
	ENDIF
;*=*=*
;	Low level edit
;*=*=*
$EDIT	LD	(SPEDIT),SP
FARUP	BIT	DELFLG,(IX+FLAGS)
	JR	Z,TOTOP
	LD	HL,TXTBUF	;Init "to"
	CALL	CPHLDE		;If at TOP, ignore
	RET	Z
	CALL	SURE
	LD	(BUFPOS),HL
	LD	A,(DE)		;If at end, clear the buffer
	OR	A
	JR	Z,FARUP2
	PUSH	DE		;Save "from"
	PUSH	HL		;Save "to"
	CALL	ENDMDE		;(endtxt) - DE
	INC	BC
	POP	DE
	POP	HL
	LDIR
FARUP2	LD	(HL),A
TOTOP	LD	HL,TXTBUF	;From text origin
NEWPAGE	LD	(BUFPOS),HL
	CALL	REFRESH
	LD	HL,0
	LD	(WINPOS),HL	;Set cursor to 0,0
EDIT	LD	SP,$-$
SPEDIT	EQU	$-2
	IF	@BLD631
	@@CKBRKC		;<631>
	ENDIF
	BIT	STATFLG,(IX+FLAGS)
	CALL	NZ,CSTAT	;Clear the status line
	BIT	MSGFLG,(IX+FLAGS)
	CALL	NZ,SETMSG	;Show "Message" if flag set
	LD	HL,$-$		;get screen position
WINPOS	EQU	$-2
	PUSH	HL
	LD	A,0
SAVCMD	EQU	$-1
	OR	A
	JR	NZ,EDITA
	LD	B,3
	@@VDCTL
	CALL	KEYIN		;Get input character
EDITA	LD	HL,EDIT		;Set return address
	EX	(SP),HL
	RET	Z		;Ignore BREAK
	LD	DE,$-$		;P/u buffer position
BUFPOS	EQU	$-2
	BIT	BLKFLG,(IX+FLAGS)
	JP	NZ,CKBLK
	BIT	7,A		;Non-ASCII, test for command
	JR	NZ,EDIT0
	CP	' '
	JR	NC,EDIT3
EDIT0	PUSH	HL
	LD	HL,KEYTAB
	LD	B,NKEYS
EDIT1	CP	(HL)
	INC	HL
	JR	Z,EDIT2
	INC	HL
	INC	HL
	DJNZ	EDIT1
	POP	HL
	RET
NOMEM	LD	HL,NOROOM$
	CALL	STORMSG
	JR	EDIT
EDIT2	LD	A,(HL)		;Get command jump vector low
	INC	HL
	LD	H,(HL)		;Ditto for high
	LD	L,A
	EX	(SP),HL		;Get WINPOS->HL, stack vector
	RET			;Go to command's routine
;*=*=*
;	Routine to overstrike or insert characters
;*=*=*
ENTER	LD	A,CR		;Reset char to CR
EDIT3	LD	C,A		;Xfer entered character
	PUSH	BC
	BIT	INSFLG,(IX+FLAGS)
	JR	NZ,INSER1	;Go if insert
	LD	A,(DE)		;Get old char
	OR	A		;If old was not end_of_text,
	JR	NZ,EDIT3A	;  then overstrike
INSER1	PUSH	HL
	PUSH	DE
	CALL	CKMEM
	JR	Z,NOMEM		;No more memory!
	LD	HL,(ENDTXT)	;Move text down one position
	INC	HL
	LD	(ENDTXT),HL
	POP	DE		;Get buffer pos
	PUSH	HL
	CALL	ENDMDE		;(endtxt) - DE
	EX	DE,HL
	EX	(SP),HL		;Get ENDTXT+1 into DE
	LD	D,H
	LD	E,L
	DEC	HL		;Get ENDTXT into HL
	LDDR
	POP	DE		;Get buffer position
	POP	HL		;Get cursor position
	LD	A,C		;Force A .NE. CR
EDIT3A	POP	BC
	CP	CR		;Was old char a CR?
	LD	A,C		;Get new char
	LD	(DE),A		;put new char into buffer
	JR	Z,EDIT3C	;Refresh row if overstrike old CR
	BIT	INSFLG,(IX+FLAGS)
	JR	NZ,EDIT3E	;If insert mode, then refresh
	CP	CR		;  or if new char is a CR
	JR	Z,EDIT3D
	CALL	VDPOKE		;display char on screen
	IF	@BLD631
	PUSH	HL		;<631>
	LD	A,H		;<631>
	ADD	A,A		;<631>
	ADD	A,A		;<631>	
	ADD	A,H		;<631>
	ADD	A,A		;<631>
	LD	C,L		;<631>
	LD	L,A		;<631>
	LD	H,0		;<631>
	ADD	HL,HL		;<631>
	ADD	HL,HL		;<631>
	ADD	HL,HL		;<631>
	LD	B,30H		;<631>
	ADD	HL,BC		;<631>
	LD	A,(DE)		;<631>
	LD	(HL),A		;<631>
	POP	HL		;<631>
	JP	$RIGHT		;<631>
	ELSE
	JP	PATCH1		;  then move right
	ENDIF
;*=*=*
FARRITE	BIT	DELFLG,(IX+FLAGS)
	JR	Z,TOEOL
	LD	A,(DE)		;Ignore if at end of text
	OR	A
	RET	Z
	CALL	SURE		;Double check
	PUSH	DE		;Save "to"
	CALL	FINDEOL		;Calc end of line
	LD	A,(DE)		;If EOL is NULL, don't move
	OR	A
	JR	NZ,FARR1
	POP	HL
	LD	(HL),A		;Set NULL
	JR	DELBLK2		;Set ENDTXT & refresh
FARR1	LD	H,D
	LD	L,E		;Save EOL for length calc
	INC	HL
	PUSH	HL		;Save "from"
	CALL	ENDMDE		;(endtxt) - DE
	POP	HL		;Get "from"
	POP	DE		;Get "to"
	JR	DELBLK
FARLEFT	BIT	DELFLG,(IX+FLAGS)
	JR	Z,TOBOL
	LD	A,L		;Ignore if already at far left
	OR	A
	RET	Z
	CALL	SURE		;Sure returns with A=0
	LD	L,A		;Set new cursor pos'n to 00
	LD	(WINPOS),HL	;Save new winpos
	PUSH	DE		;Save "from"
	CALL	ENDMDE		;(endtxt) - DE
	INC	BC
	CALL	SETWIN		;Get buffer address of line start into DE
	POP	HL		;Get "from"
DELBLK	CALL	MOVBLK
DELBLK1	LD	HL,TXTBUF
	XOR	A		;Find the NULL
	CPIR
	DEC	HL
DELBLK2	LD	(ENDTXT),HL
	JP	WDOROW		;Refresh the screen
TOEOL	CALL	FINDEOL		;find end_of_line position
	DB	06H		;mask next instruction (LD B,nn)
TOBOL	XOR	A
	JR	SETCOL
;*=*=*
;	Piece of overstrike/insert
;*=*=*
EDIT3C	CP	CR		;If new also CR,
EDIT3E	CALL	NZ,DOROW	;  just advance
	JR	RIGHT
EDIT3D	CALL	DOROW
	JR	RIGHT0		;Set L=0 then DOWN
SETROW	LD	(WINPOS+1),A
SETWIN	LD	HL,(WINPOS)
SETWIN1	CALL	CALCPOS		;calc buffer position
	LD	(BUFPOS),DE
	RET
;*=*=*
;	Routine to move cursor right
;*=*=*
$RIGHT	LD	A,L
	CP	MAXCOL-1
	JR	NZ,RIGHT
RIGHT0	INC	DE		;Set VINDEX, in case
	PUSH	DE
	CALL	SETIDX
	POP	DE
	LD	(IY+2),E
	LD	(IY+3),D
RIGHT1	LD	L,0		;zero column
;*=*=*
;	Routine to move cursor down
;*=*=*
DOWN	CALL	FINDEOL		;Find column of EOL
	LD	A,(DE)
	OR	A		;If NULL, then last row
	RET	Z
	LD	A,H
	CP	MAXROW-1	;On bottom of screen?
	JR	NZ,DOWN1
	PUSH	HL
	CALL	SCRUP		;Scroll one row
	POP	HL
	DEC	H		;Go to UP2 with H unchanged
DOWN1	INC	H		;Advance to next row
	JR	UP2
;*=*=*
;	Continue routine to move right
;*=*=*
RIGHT	LD	A,(DE)
	OR	A		;Do nothing if on NULL
	RET	Z
	CP	CR		;If on CR, go to next line
	JR	Z,RIGHT1
	LD	A,L
	INC	A
	CP	MAXCOL
	JR	Z,RIGHT1
SETCOL	LD	(WINPOS),A
	JR	SETWIN
;*=*=*
;	Routine to move the cursor left
;*=*=*
LEFT	DEC	L		;If not at col_0, then do it
	JP	P,SETRC		;  else up one row to end
;*=*=*
;	Routine to move the cursor up
;*=*=*
UP	DEC	H
	JP	P,UP2		;Go if not on top row
	CALL	ATSTART
	RET	Z		;Nothing if at top row
	CALL	SCRDN		;Scroll down a row
	LD	HL,(WINPOS)
UP2	CALL	FINDEOL
	CP	L		;Is colpos > EOL?
	JR	NC,SETRC	;Go set row & col
	LD	L,A
SETRC	LD	(WINPOS),HL
	JR	SETWIN1
;*=*=*
;	Routine to move or delete to bottom or
;*=*=*
FARDOWN	BIT	DELFLG,(IX+FLAGS)
	JR	Z,TOBOT
	CALL	SURE		;Sure returns with A=0
	EX	DE,HL		;Current buffer position to HL
	LD	(HL),A		;Add the NULL
	JP	DELBLK2		;Set ENDTXT & refresh
TOBOT	LD	DE,(ENDTXT)	;Get address of last character
	CALL	BOLEX		;Calculate start of line
	CALL	REFRESH		;Refresh the screen
	LD	H,0		;Find end of line
	CALL	FINDEOL
	LD	L,A
SETRC1	JR	SETRC
;*=*=*
;	Routine to find an ASCII string
;*=*=*
SCMD	CALL	GETSTR		;Max of 23 chars
	LD	A,B
	OR	A
	JR	Z,GCMD		;Use old search string on NULL
	LD	(IX+STRLEN),B	;Set string length
	LD	DE,IXDAT$+SRCHBUF
	LD	C,B
	LD	B,0
	LDIR
;*=*=*
;	Routine to find the next ocurrence of the search string
;*=*=*
GCMD	LD	HL,(BUFPOS)	;Start looking from next position
	CALL	GCMD0		;Check for match
	JP	NZ,NOFIND	;Go if not found
REF@HL	CALL	ATBGN		;If at beginning, from the top
	LD	D,H
	LD	E,L
	CALL	NZ,CALCBOL	;Get beginning of this line
	OR	A		;  if not at start
	SBC	HL,DE		;Calc new cursor pos
	PUSH	HL		;Save new cursor pos
	EX	DE,HL
	CALL	REFRESH		;Refresh the screen
	POP	HL
	JR	SETRC1		;Set positions
GCMD0	LD	A,(IX+STRLEN)	;Check on NULL string
	OR	A
GCMD0A	RET	Z
GCMD1	LD	A,(HL)		;At end of text?
	OR	A
	JR	NZ,GCMD2
	OR	H		;Set NZ return
	RET
GCMD2	INC	HL
	PUSH	HL		;Save text pointer
	CALL	GCMD3		;Compare
	POP	HL		;Recover text pointer
	JR	GCMD0A		;Did we find it?
;*=*=*
;	Routine to insert a blank
;*=*=*
ADDCMD	LD	A,(IX+FLAGS)	;Toggle "add" mode
	XOR	1.SHL.INSFLG
ADDCMDA	LD	HL,CURCHAR
	BIT	0,A		;Check mode
	JR	Z,$+3		;Use overstrike cursor
	INC	HL		;  else use insert cursor
	LD	C,(HL)
	LD	(IX+CURSOR),C	;Set cursor character
SETFLAG	LD	(IX+FLAGS),A
	RET
;*=*=*
;	Routine to replace keyin
;	   A contains 1st char in buffer
;	   CF set if <Break>
;*=*=*
KEYIN	LD	B,4
	@@VDCTL			;obtain cursor position
	CALL	BLINK		;blink cursor, get key
	IF	DOS5
	RET	C		;Back if CTL key
	ENDIF
	CP	BREAK
	RET	NZ		;Back with key & NZ if not BREAK
	IF	DOS5
	LD	A,80H
	ENDIF
	JR	ADDCMDA		;Clear flags with 80H <===*****
;*=*=*
;	Routine to delete a character
;*=*=*
DELCHAR	SET	DELFLG,(IX+FLAGS) ;Indicate delete mode
	LD	HL,DELETE$
	CALL	STORMSG
	LD	A,(DE)		;Get char to delete
	OR	A
	RET	Z		;Ignore if end of text
	PUSH	DE		;Save "to"
	PUSH	DE		;Save "from-1"
	CALL	ENDMDE		;(endtxt) - DE
	LD	HL,(ENDTXT)
	DEC	HL
	LD	(ENDTXT),HL	;Update end of text pointer
	POP	HL		;Get "to-1" & adjust to "to"
	INC	HL
	POP	DE
	LDIR
WDOROW	LD	HL,(WINPOS)
;*=*=*
;	Routine to refresh the screen starting at this row
;*=*=*
DOROW	PUSH	HL		;Save cursor position
	PUSH	DE
	CALL	SETIDX		;Point IY to row index
	LD	A,H		;Set starting row
	LD	L,(IY)		;Set HL to RAM start of row
	LD	H,(IY+1)
	CALL	REFROW
	POP	DE
	POP	HL
	RET
;*=*=*
;	Routine to advance to previous page
;*=*=*
PREVPG	LD	B,MAXROW-1	;Up this many rows
	LD	HL,(VINDEX)	;Get buffer address of screen start
PREVPG1	CALL	ATBGN		;End of loop at TXTBUF
	JR	Z,PREVPG2
	PUSH	BC
	EX	DE,HL		;RAM address to DE
	CALL	PREVROW		;Find start of previous row
	POP	BC
	DJNZ	PREVPG1
	DB	0FDH		;Ignore next via LD IY,(nnnn)
;*=*=*
;	Routine to advance to next page
;*=*=*
NEXTPG	LD	HL,(MAXROW-1*2+VINDEX)
	LD	A,H		;If address of last row is
	OR	L		;  zero, then do nothing,
	RET	Z		;  else use it for new page
PREVPG2	JP	NEWPAGE
;*=*=*
;	Routine to load in a text file
;*=*=*
DOLOAD	DB	3EH		;LD A,N
DOSAVE	XOR	A
	LD	(SAVLRL),A	;Save LRL code
	IF	@BLD631
	LD	C,A		;<631>
	ENDIF
;*=*=*
;	Prompt for filespec
;*=*=*
	LD	HL,SAVCMD	;Is entry from command line?
	LD	A,(HL)
	LD	(HL),0
	OR	A
	LD	HL,LINBUF
	JR	NZ,DOL1
	LD	HL,PROMPT$	;Filespec prompt
	IF	@BLD631
	INC	C		;<631>
	DEC	C		;<631>
	JR	Z,L2A4C		;<631>
	LD	HL,PROMPT2	;<631>
	ENDIF
L2A4C:	CALL	GETINP		;Returns if <Break> depressed
;*=*=*
;	Check the filespec and open the file
;*=*=*
DOL1	LD	DE,IXDAT$+FCB	;File control block
	@@FSPEC			;Check the filespec
	LD	HL,EXTTXT
	@@FEXT
	LD	HL,TXTBUF	;Use TXTBUF for file
	LD	B,0		;Set LRL == 256
SAVLRL	EQU	$-1
	INC	B
	DEC	B
	LD	B,0		;Always use LRL=256
	JR	NZ,LOAD
	@@INIT			;Open/init the file
	JR	NZ,IOERR	;Ret
;*=*=*
;	Write the contents of the text buffer to the file
;*=*=*
	PUSH	DE
	LD	DE,TXTBUF
	CALL	ENDMDE		;Calculate length of save
	POP	DE
	JR	Z,CLSFIL
	LD	C,L
	INC	C
	DEC	C		;Calculate full sectors
	JR	Z,$+3
	INC	B
SAVE1	@@WRITE
	JR	NZ,IOERR
	INC	(IX+FCB+4)	;Bump hi-order pointer
	DJNZ	SAVE1
	LD	(IX+FCB+8),C	;Stuff NRN offset
;*=*=*
;	Close the file and return
;*=*=*
CLSFIL	@@CLOSE			;Close the file
	RET
;*=*=*
;	Routine to load a text file
;*=*=*
LOAD
	IF	DOS6
	@@FLAGS
	SET	0,(IY+'s'-'a')
	ENDIF
	LD	HL,(ENDTXT)	;Start reading into (ENDTXT)
	@@OPEN			;Open the file
	JR	Z,OPENOK	;Back if error
IOERR	PUSH	DE		;10/24/86 - moved IOERR from next inst
	LD	DE,IOERR$	;  need to save for both ^L & ^F
	PUSH	DE
	OR	0C0H
	IF	DOS6
	PUSH	AF
	@@FLAGS
	SET	7,(IY+'C'-'A')
	POP	AF
	LD	C,A
	ENDIF
	IF	DOS5
	LD	HL,CFLAG$
	SET	7,(HL)
	ENDIF
	@@ERROR
	POP	HL
	LD	A,CR
	LD	BC,256
	CPIR
	DEC	HL
	DEC	HL		;Backup to last char
	SET	7,(HL)		;  and indicate it's last
	POP	DE
	JR	DOSERR
;*=*=*
;	Check for sufficient buffer room
;*=*=*
OPENOK	LD	HL,(MEMTOP)
	LD	BC,(ENDTXT)
	SBC	HL,BC		;Length of buffer
	LD	C,(IX+FCB+8)	;Get ERN offset
	LD	B,(IX+FCB+12)	;Get ERN lo-order
	SBC	HL,BC		;Zero leaves no room for NULL
	JR	C,NOROOM	;CF ditto
	JR	NZ,LOAD1
NOROOM	LD	HL,NOROOM$
	DB	0FDH
DOSERR	LD	HL,IOERR$
	CALL	STORMSG
	LD	A,(DE)
	RLCA
	JR	C,CLSFIL
	RET
;*=*=*
;	Read the file into the text buffer
;*=*=*
LOAD1	@@READ			;Read buffer contents from file
	JR	NZ,LOAD3	;Return if error during read
	LD	H,(IX+FCB+4)	;Get pointer
	INC	(IX+FCB+4)	;Bump buffer pointer
	DJNZ	LOAD1
	LD	A,C		;Get ERN offset
	OR	A		;If offset is zero,
	JR	NZ,$+3		;  adjust to next page
	INC	H
	LD	A,(ENDTXT)	;p/u prev end lo-order
	ADD	A,C		;Add new offset
	LD	L,A
	JR	NC,$+3
	INC	H
LOAD2	LD	(HL),0
	LD	(ENDTXT),HL
	@@CLOSE			;Close the file
	JP	TOTOP
LOAD3	CALL	IOERR
	LD	HL,(IXDAT$+FCB+3)
	DEC	H
	JR	LOAD2
	IF	@BLD631
QCMD:	LD	HL,DRIVE$	;<631>
	CALL	GETINP		;<631>
	LD	B,0		;<631>
	LD	A,(HL)		;<631>
	CP	'/'		;<631>
	JR	NZ,L2B26	;<631>
	INC	HL		;<631>
	LD	B,2		;<631>
	LD	DE,3		;<631>
	EX	DE,HL		;<631>
	ADD	HL,DE		;<631>
	LD	A,(HL)		;<631>
L2B26:	EX	DE,HL		;<631>
	CP	':'		;<631>
	INC	DE		;<631>
	JR	NZ,L2B2D	;<631>
	LD	A,(DE)		;<631>
L2B2D:	SUB	'0'		;<631>
	CP	7+1		;<631>
	RET	NC		;<631>
	LD	C,A		;<631>
	PUSH	HL		;<631>
	PUSH	BC		;<631>
	LD	A,69H		;<631>
	RST	28H		;<631>
	POP	BC		;<631>
	POP	HL		;<631>
	@@DODIR			;<631>
	LD	HL,1700H	;<631>
	CALL	BLINK		;<631>
	JP	REFRE6		;<631>
	ENDIF
;*=*=*
;	Routine to blink a cursor and wait for a char
;	on entry : HL = cursor position in row/column format
;	on exit  : A contains character
;		   NZ if error
;*=*=*
BLINK	CALL	PEEKSAV		;get character at cursor
	LD	C,A		; into C
BLINK1	LD	A,(IX+CURSOR)	;Flash cursor character
	CALL	$BLNK
	LD	A,C		;Restore old char
	CALL	$BLNK
	JR	BLINK1		;loop
;*=*=*
$BLNK	PUSH	BC		;save BC - orig char in C
	LD	C,A
	CALL	VDPOKE		;put character on screen
	LD	B,180		;flash count
$BLNK2	PUSH	DE
	@@KBD			;scan keyboard
	POP	DE
	IF	DOS6
	JR	Z,$BLNK3	;char found
	OR	A
	ENDIF
	JR	NZ,$BLNK3	;jump if error
	DJNZ	$BLNK2
	POP	BC
	RET
$BLNK3	POP	BC		;restore old character
	POP	DE		;pop off return address
VDPOKE	PUSH	AF		;save character
	LD	A,C
	CALL	VIDCHAR
	CALL	POKESAV		;put char on video
	POP	AF		;restore character
	RET
PEEKSAV	LD	B,1
	JR	BLINK3
POKESAV	LD	B,2
BLINK3	PUSH	DE
	@@VDCTL
	POP	DE
	RET
;*=*=*
;	Routine to convert char to video appearance
;*=*=*
VIDCHAR	LD	C,VIDCR
	CP	CR
	SCF			;Set for Z, CF to denote CR
	RET	Z
	LD	C,VIDBEG
	CP	BLKBEG
	RET	Z
	LD	C,VIDEND
	CP	BLKEND
	RET	Z
	LD	C,A
	RET
;*=*=*
;	Part of "go to next string match
;*=*=*
GCMD3	LD	B,(IX+STRLEN)
	LD	DE,IXDAT$+SRCHBUF
GCMD4	LD	A,(DE)
	CP	(HL)
	RET	NZ
	INC	HL
	INC	DE
	DJNZ	GCMD4
	RET
;*=*=*
;	Routine to scroll down one line
;*=*=*
SCRDN	LD	DE,(VINDEX)	;Get buffer pos of old first row
	CALL	PREVROW		;Get HL=address of previous row
	DB	0FDH		;Ignore next via LD IY,(nnnn)
;*=*=*
;	Routine to scroll up one line
;*=*=*
SCRUP	LD	HL,(VINDEX+2)
;*=*=*
;	Routine to refresh the entire screen
; HL => buffer position for generating MAXROW rows
;*=*=*
REFRESH	XOR	A		;Start with row 0
REFROW	PUSH	HL
	LD	DE,MAXCOL
	LD	HL,VIDBUF-MAXCOL	;Point to video buffer
	LD	IY,VINDEX-2
	LD	C,MAXROW+1	;Number of video lines to do
REFRE0	ADD	HL,DE		;Index VIDBUF pointer
	INC	IY		;Adjust VINDEX pointer
	INC	IY
	DEC	C		;Calc # of rows to do
	DEC	A
	JP	P,REFRE0
	EX	DE,HL		;VIDBUF pointer to DE
	POP	HL		;Recover RAM buffer pointer
REFRE1	LD	(IY),L		;Stuff RAM address of row
	INC	IY
	LD	(IY),H
	INC	IY
	CALL	REFLINE		;Refresh a line
	OR	A
	JR	Z,REFRE7	;End of text?
REFRE5	DEC	C		;Count down another row
	JR	NZ,REFRE1	;Go until all rows complete
REFRE6	LD	HL,VIDBUF
	LD	B,5
	JR	BLINK3		;Move video buffer to screen
REFRE7	LD	(IY),B		;Zero out remainder of index
	INC	IY
	LD	(IY),B
	INC	IY
	DEC	C
	JR	NZ,REFRE7
	LD	HL,MAXCOL*MAXROW+VIDBUF
	CALL	SBCHLDE		;Xfer count
	EX	DE,HL
	JR	Z,REFRE6	;Go if none to stuff
	LD	(HL),' '	;Stuff blanks to end
	DEC	BC		;Adjust
	LD	D,H
	LD	E,L
	INC	DE
	LDIR
	JR	REFRE6
;*=*=*
;	Routine to refresh a video line
; HL => RAM text buffer
; DE => video screen buffer
; CF <= set if line buffered with blanks
;*=*=*
REFLINE	LD	B,MAXCOL	;Init for # of columns to do
REFL0	LD	A,(HL)
	OR	A		;End of text?
	JR	Z,REFL2
	INC	HL		;Bump RAM pointer
	PUSH	BC
	CALL	VIDCHAR		;Special case?
	LD	A,C
	POP	BC
	JR	NZ,REFL4
	JR	NC,REFL4	;Xlate CR to vidcr
	LD	(DE),A		;Stuff the char
	INC	DE
	DEC	B		;Decrement column count
	RET	Z
REFL2	PUSH	AF
	LD	A,' '		;Buffer trailing line with spaces
REFL3	LD	(DE),A
	INC	DE
	DJNZ	REFL3
	POP	AF		;Let know that there is more room
	RET	NZ		;Back if no NULL
	LD	(ENDTXT),HL	;  else reset the text end
	RET
REFL4	LD	(DE),A		;Stuff next char
	INC	DE
	DJNZ	REFL0		;Loop for full row
	RET
CALCRC	PUSH	DE
	PUSH	BC
	LD	HL,VIDBUF
	EX	DE,HL		;Calculate offset from video start
	SBC	HL,DE
	LD	C,MAXCOL	;Calculate row and column
	@@DIV16
	LD	H,L		;Row to reg_H
	LD	L,A		;Col to reg_L
	INC	L		;Adjust for cut & paste
	POP	BC
	POP	DE
	RET
;*=*=*
;	Routine to calculate buffer address of previous row
; DE => start of this row
; HL <= start of previous row
;*=*=*
PREVROW	LD	HL,-MAXCOL	;Calc 80 back in case row wrap
	ADD	HL,DE
	DEC	DE		;Backup to previous char
	LD	A,(DE)		;If prev char is CR,
	CP	CR		;  then need to find start of line,
	RET	NZ
BOLEX	CALL	CALCBOL
	EX	DE,HL		;RAM pos to HL
	RET
;*=*=*
;	Routine to calculate the RAM position for the beginning of a line
; DE => RAM pos of a CR or NULL to start looking back
; DE <= RAM pos to use
;*=*=*
CALCBOL	PUSH	HL		;Don't effect HL
	PUSH	DE		;Save where we are
	LD	BC,-1		;Init the count
CALCB1	LD	HL,TXTBUF	;Start of text
	OR	A
	SBC	HL,DE
	JR	Z,CALCB2	;Exit if at start of text
	DEC	DE		;Look for preceding CR or start of text
	LD	A,(DE)
	CP	CR
	JR	Z,CALCB2	;Go if found preceding CR
	DEC	BC		;Bump the count
	JR	CALCB1
CALCB2	LD	H,B		;Get modulo maxcol
	LD	L,C
	LD	BC,MAXCOL
CALCB3	ADD	HL,BC
	JR	NC,CALCB3
	OR	A
	SBC	HL,BC
	POP	DE		;Recover start
	INC	DE		;Adjust for "-1" init
	ADD	HL,DE		;Reduce by needed line length
	EX	DE,HL
	POP	HL
	RET
;*=*=*
;	Routine to find the last character {CR,NULL,80th} of the line
; H => line number
; A <= column number
;*=*=*
FINDEOL	PUSH	HL
	LD	L,0		;Set to col 0
	CALL	CALCPOS
	LD	C,MAXCOL-1	;Maximum of 80 chars
FINDE1	LD	A,(DE)		;Get RAM character
	OR	A
	JR	Z,FINDE2	;Exit on end of text
	CP	CR
	JR	Z,FINDE2	;Exit on carriage return
FINDE3	INC	DE
	DEC	C
	JR	NZ,FINDE1	;loop until 80th character
FINDE2	LD	A,MAXCOL-1	;Calculate column of "end"
	SUB	C
	POP	HL
	RET
;
;
*GET	TED2/ASM:3
;

	IF	@BLD631
	DC	32,0		;<631>Patch area
	ELSE
	DC	10,0
	ENDIF
VINDEX	DS	MAXROW*2+2
	IF	DOS5
LINBUF	DS	24
	ENDIF
IOERR$	DS	64
CORE$	DEFL	$
	ORG	$<-8+1<8
	IF	DOS6
VIDBUF	DS	80*25
	ENDIF
	IF	DOS5
VIDBUF	EQU	3C00H
	ENDIF
TXTBUF	EQU	$
	END	BEGIN
