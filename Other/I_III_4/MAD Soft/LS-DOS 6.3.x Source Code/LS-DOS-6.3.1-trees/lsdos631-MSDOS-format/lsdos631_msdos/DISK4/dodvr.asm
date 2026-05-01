;DODVR/ASM - LS-DOS 6.2
	SUBTTL	'<Video Driver>'
	PAGE	OFF
*MOD
@OPREG	EQU	84H		;Mem mgt & video control
CRTCADD	EQU	88H		;CRTC address port
CRTCDAT	EQU	89H		;CRTC data port
LINESIZ	EQU	80
NUMROWS	EQU	24
NEGLINE	EQU	-LINESIZ
CRTSIZE	EQU	LINESIZ*NUMROWS
RAMSIZE	EQU	2048
CRTBGN$	EQU	0F800H
CRTEND	EQU	CRTBGN$+CRTSIZE-1
;
;	Driver entry point
;
DODVR	JR	DOBGN		;Branch around linkage
	DW	DOEND		;Last memory location used
	DB	3,'$DO'
	DW	DODCB$		;DCB used
	DW	0		;Reserved
DODATA$	EQU	$
DO_MASK	EQU	$-DODATA$
SCRPROT	EQU	7		;Bits 0-2: scroll protect
TABS	EQU	3		;Bit 3: 0=tabs, 1=chars
CTL	EQU	4		;Bit 4, display controls
	IF	@USA
	DB	0		;Tab/Spec, Scroll protect
	ENDIF
	IF	@INTL
	DB	08		;Space compression off
	ENDIF
CURSOR	DW	CRTBGN$
CRSAVE	DB	20H		;Character under cursor
CRSCHAR	DB	'_'		;Cursor character
;
;	Entry from SVC 15, @VDCTL
;
@VDCTL	JP	@_VDCTL
;
;	Continue regular driver functions
;
DOBGN	LD	IX,DODATA$
	CALL	ENADIS_DO_RAM	;Bring up the video RAM
	JP	C,$?0		;Go on 'GET' request
	CALL	$?0		;Handle cursor
	PUSH	BC		;Need to save C
	LD	A,C		;Get char to display
	BIT	CTL,(IX+DO_MASK) ;Display controls set?
	JR	NZ,$?1A		;Go if so
	OR	A		;Char a 0?
	JP	Z,TGGLCTL	;Switch Bit CTL if so
	CP	20H		;Video control char?
	JP	C,DO_CONTROL	;Go if so
$?1A	CP	0C0H		;Tab or special?
	JR	C,DONORM	;Go on normal characters
;
;	Character is => 0C0H
;
	BIT	TABS,(IX+DO_MASK) ;Tabs or spec chars
	JR	Z,DO_TABS	;Go if video tabs
;
;	Character is not tab expansion - do it
;
DONORM	CALL	DO_DSPCHAR	;Display the char
	RES	CTL,(IX+DO_MASK) ;Turn off CTL bit
DO_RET	POP	BC		;Get orig char
DO_RET1	DI			;Disable intr
	LD	A,(CRSAVE)	;If a cursor is on, then
	OR	A		;  we need to save the
	JR	Z,$?1		;  current char & display
	LD	A,(DE)		;  the cursor character
	LD	(CRSAVE),A	;Save current char
	LD	A,(VFLAG$)	;Allow tasker to blink
	RES	7,A
	LD	(VFLAG$),A
	LD	A,(CRSCHAR)	;P/u cusor character
	LD	(DE),A		;Put it on the screen
$?1	LD	(CURSOR),DE	;Update cursor position
	CP	A		;Clear status
	LD	A,C		;Restore the char
	RET
;
;	Perform a tab expansion {C0H-FFH}
;
DO_TABS
	SUB	0C0H		;Compute spaces
	JR	Z,DO_RET	;Forget it if TAB(0)
	LD	B,A		;Display requested
$?2	LD	C,' '		;  number of spaces
	CALL	DO_DSPCHAR
	DJNZ	$?2
	JR	DO_RET
;
;	Routine to move the cursor to begin of line {29}
;
CRSBOL
	EX	DE,HL		;Cursor addr to HL
	CALL	ADDR1		;Find row,col
	LD	L,A		;Set col to start
	JP	ROWCOL_2_ADDR	;Calc address of BOL
;
;	Routines to turn on/off the cursor {14/15}
;
CRSON	LD	A,(DE)		;Get screen character
CRSOFF	LD	(CRSAVE),A	;Save zero or CRT char
	RET
;
;	Routine moves cursor to start of video page {28}
;	 set to 80 column, and turns off inverse video
;
CRSHOME
	LD	DE,CRTBGN$	;Home the cursor
	LD	A,(MODOUT$)	;P/u the mask &
	AND	0FBH		;  set to 80 cpl
	CALL	SETMOD
	JR	DO_INVERT_DIS	;Set to normal video
;
;	Routine to backspace & erase cursor {08}
;
BACKSPA
	CALL	CRSBKSP		;Backspace the cursor
	RET	Z		;If not at start,
	LD	C,' '		;  put a space at
	JP	PUT_@		;  at the new loc'n
;
;	Routine to backspace the cursor {24}
;
CRSBKSP
	LD	A,(MODOUT$)	;If double width chars,
	AND	4		;  need to do twice
	CALL	NZ,$+3
	LD	HL,CRTBGN$	;See if at home position
	SBC	HL,DE		;  prior to adjusting
	RET	Z
	DEC	DE		;Decrement the cursor pos
	RET
;
;	Routine to move the cursor up one line {27}
;
CRSUP
	LD	HL,NEGLINE	;Move up one line
	JR	MOVCRS
;
;	Routine to move the cursor down one line {26}
;
CRSDOWN
	LD	HL,LINESIZ	;Add the line length
MOVCRS	ADD	HL,DE		;  to the current pos
	LD	A,H		;Make sure we did not
	CP	CRTBGN$<-8	;  go over the top
	RET	C
	EX	DE,HL		;  & switch back to DE
	DEC	DE		;Adjust for fall thru
	JP	CRSFRW0
;
;	Set to 40 cpl mode {23}
;
SET40	LD	A,(MODOUT$)	;Get image of the port
	OR	04H		;Merge in 40 cpl bit
	JR	SETMOD
;
;	Routines to parse control functions
;
DO_CONTROL
	LD	HL,DO_RET	;Establish RET
	PUSH	HL
	CP	08H		;Backspace?
	JR	Z,BACKSPA
	CP	0AH		;Line feed?
	JR	Z,$+4		;  is same as <ENTER>
	SUB	0DH		;Carriage return?
	JP	Z,LINFEED
	DEC	A		;Cursor on?
	JR	Z,CRSON
	DEC	A		;Cursor off?
	JR	Z,CRSOFF
	DEC	A		;Reverse video?
	JR	Z,DO_INVERT_ENA
	DEC	A
	JR	Z,DO_INVERT_OFF
	SUB	4		;Swap tab/alternate?
	JR	Z,TGGLTAB
	DEC	A		;Special/alternate?
	JR	Z,TGGLALT
	DEC	A		;40 cpl?
	JR	Z,SET40
	DEC	A		;Cursor backspace?
	JR	Z,CRSBKSP
	DEC	A		;Cursor forward?
	JR	Z,CRSFRWD
	DEC	A		;Cursor down?
	JR	Z,CRSDOWN
	DEC	A		;Cursor up?
	JR	Z,CRSUP
	DEC	A		;Cursor home?
	JP	Z,CRSHOME
	DEC	A		;Cursor BOL?
	JP	Z,CRSBOL
	DEC	A		;Clear to EOL?
	JP	Z,CLREOL
	DEC	A
	JP	Z,CLREOF	;Clear to end-of-frame?
	XOR	A		;Clear A reg.
	RET
;
;	Routine to enable inverse video
;
DO_INVERT_ENA
	LD	B,8		;Set for enable
	DB	21H		;Ignore next load
DO_INVERT_DIS
	LD	B,0
	LD	HL,(OPREG_SV_PTR)	;Real OPREG$
	LD	A,(HL)		;P/u OPREG mask
	AND	0F7H		;Strip bit 3
	OR	B		;Set/reset invideo bit
	LD	(HL),A		;  and restuff
	LD	A,B		;Get mode mask byte
	RLCA			;Rotate left 4 times to
	RLCA			;  make an 8 into 80H
	RLCA			;  for inverse on
	RLCA			;Inverse off remains 0
DO_INVERT_OFF
	LD	(INVIDEO),A	;Set the mask byte
	RET
;
;	Routine to toggle display of controls
;
TGGLCTL	LD	HL,DO_RET	;Establish ret addr
	PUSH	HL
	LD	A,10H		;Toggle bit 4
	DB	21H		;Ignore next
;
;	Toggle tabs & alternate character set
;
TGGLTAB
	LD	A,8		;Toggle bit 3
	XOR	(IX+DO_MASK)	;P/u mask value
	JR	SETMASK
;
;	Toggle special & alternate character set
;
TGGLALT
	LD	A,(MODOUT$)	;P/u port mask
	XOR	8		;Flip the bit
SETMOD	LD	(MODOUT$),A	;Resave port mask
	OUT	(0ECH),A	;  and send the byte
	RET
;
;	Display character <C> at current cursor position
;
DO_DSPCHAR
	CALL	PUT_@		;Display the char
;
;	Routine to perform cursor forward {25}
;
CRSFRWD
	LD	A,(MODOUT$)	;If double width chars,
	AND	4		;  need to do twice
	JR	Z,CRSFRW0
	INC	DE		;Move cursor forward
CRSFRW0	INC	DE
	LD	HL,CRTEND	;Off the screen?
	SBC	HL,DE
	RET	NC		;Back if not
	CALL	CRSUP		;Put cursor back on
	PUSH	DE		;Save cursor position
DO_SCROLL
	LD	A,(IX+DO_MASK)	;Get scroll protect
	AND	SCRPROT
	LD	HL,CRTBGN$	;Point to CRT start
	LD	DE,CRTSIZE	;P/u CRT size
	PUSH	BC
	LD	BC,LINESIZ	;Set line size
	INC	A		;Adjust scroll protect
$?4	ADD	HL,BC		;Move logical start
	EX	DE,HL		;  down one line
	OR	A		;  and subtract one line
	SBC	HL,BC		;  from the CRTSIZE for
	EX	DE,HL		;  each protected line
	DEC	A		;Dec scroll protect
	JR	NZ,$?4		;Loop until done
	PUSH	DE		;Save the move length
	PUSH	HL		;Save the move-from
	SBC	HL,BC		;Move start back one
	EX	DE,HL		;  line, Source =
	POP	HL		;  start + one
	POP	BC		;Get back dest locn
	LDIR			;Scroll unprotected
	POP	BC		;Recover line size
	JR	CLREOF1		;Clear to EOF from DE
;
;	Set scroll protect value
;		C = scroll protect <0-7>
;		B = 7
;		SVC = 15, @VDCTL
;
SET_SCROLL
	LD	A,C		;Get user value
	AND	7		;Make modulo 8
	LD	C,A
	LD	A,(DODATA$)	;P/u current mask
	AND	0F8H		;Remove current scroll
	OR	C		;Merge in the new value
SETMASK	LD	(DODATA$),A	;  & reload mask
	XOR	A		;Z-flag return
	RET
;
;	Routine to move down one line {10/13}
;
LINFEED	CALL	CRSBOL		;Move to BOL
	PUSH	DE		;Save cursor position
	CALL	CRSDOWN		;Move down one line
	OR	A		;Reset the carry flag
	LD	HL,CRTEND+1	;  & check if off of
	SBC	HL,DE		;  the screen
	JR	Z,DO_SCROLL	;Scroll if so
	POP	HL		;Discard old position
CLREOL	PUSH	DE		;Save new cursor pos
	CALL	CRSBOL		;Get start of line
	LD	HL,79		;Calculate end of line
	ADD	HL,DE		;HL = end of line
	POP	DE		;DE = current position
	PUSH	DE
	JR	CLREOF2		;Clear the line
;
;	Clear to the end of the frame
;
CLREOF	PUSH	DE		;Save current cursor pos
CLREOF1	LD	HL,CRTEND	;Point to last RAM byte
CLREOF2	LD	A,(INVIDEO)	;P/u normal/reverse
	SET	5,A		;  & make it a space
	LD	(DE),A		;Stuff the "space"
	OR	A		;Reset carry for subtract
	SBC	HL,DE		;Calculate length
	JR	Z,CLREOF3	;Back if at end already
	PUSH	BC
	LD	B,H		;Xfer length to BC
	LD	C,L
	LD	H,D		;Xfer start to HL
	LD	L,E
	INC	DE		;Bump up by one
	LDIR			;Propagate the space
	POP	BC
CLREOF3	POP	DE
	RET
;
;	Routine to stuff the video cursor RAM address
;
@VDCTL3	CALL	ROWCOL_2_ADDR	;Calculate video address
	RET	NZ		;Back on error
	DI			;Disable any video tasks
	LD	(CURSOR),DE	;  until cursor is updated
	RET
;
;	Video control SVC processor
;
@_VDCTL
	CALL	ENADIS_DO_RAM	;Bring up the video RAM
;
;	Test if in Task processor
;
	LD	A,(NFLAG$)	;P/u NFLAG$
	BIT	6,A		;Test for task process
	JR	NZ,VDCTL	;If so skip setup
;
;	HANDLES @VDCTL screen set up for normal use
;
	PUSH	DE
	CALL	$?0		;Normalize character at cursor
	POP	DE		;Recover value
	PUSH	DE
	CALL	VDCTL		;Do function request
	PUSH 	AF		;Save the error status
	DI			;Stop video tasks tempy
	LD	DE,(CURSOR)
	CALL	DO_RET1		;Normalize screen and cursor
	POP	AF
	POP	DE
	RET
;
VDCTL	LD	A,9		;Check for VIDLINE,
	CP	B		;  function 9
	JR	Z,VIDLIN
	LD	A,43		;Prepare for user ERROR
	DEC	B
	JR	Z,GET_@_ROWCOL	;<C> from row-H, col-L
	DEC	B
	JR	Z,PUT_@_ROWCOL	;<C> to row-H, col-L
	DEC	B
	JR	Z,@VDCTL3	;Set cursor to H,L
	DEC	B
	JR	Z,ADDR_2_ROWCOL	;Cursor row,col to H,L
	LD	DE,CRTBGN$	;Init to start of video
	DEC	B
	JR	Z,VIDMOV1	;User RAM to video
	DEC	B
	JR	Z,VIDMOVE	;Video RAM to user
	DEC	B
	JP	Z,SET_SCROLL	;Set scroll protect
	DEC	B
	RET	NZ		;Return if bad request
;
;	Establish cursor character
;
	PUSH	HL
	LD	HL,CRSCHAR	;Point to cursor char storage
	LD	A,(HL)		;P/u current cursor character
	LD	(HL),C		;  & update with new one
	POP	HL
	RET
;
;	VIDLIN routine function - 9 in register B
;
VIDLIN	LD	L,0		;Always starts at col 0
	PUSH	DE		;Save user buffer
	CALL	ROWCOL_2_ADDR	;Get address to DE
	POP	HL		;Recover user buffer
	RET	NZ		;Quit on bad address
	INC	C		;Check direction
	DEC	C		;If Z then to screen
	JR	Z,MOVLIN	;Set to go
	EX	DE,HL		;Reverse direction
MOVLIN	LD	BC,LINESIZ	;Set line size
	LDIR			;Move it
	XOR	A		;Z on RET
	RET
;
;	Routine to move video RAM
;
VIDMOVE	LD	A,H		;Check on user buffer
	ADD	A,8		;  not above X'F800' &
	CP	24H+8		;  not below X'2400'
	JR	C,PERR
	EX	DE,HL		;Xchng user buffer,screen
VIDMOV1	LD	BC,CRTSIZE	;Set for full screen xfer
	LDIR
	CP	A		;Set Z flag
	RET
;
;	Routine to get the character at row,col
;
GET_@_ROWCOL
	CALL	ROWCOL_2_ADDR	;Get Address of req
	LD	A,(DE)		;P/u the character
	RET			;Back on error or no error
;
;	Routine to halt blinking cursor & restore char
;
$?0	PUSH	HL
	LD	HL,VFLAG$
	SET	7,(HL)		;Disable blinking cursor
	POP	HL
	LD	DE,(CURSOR)	;Get cursor pos in DE
	LD	A,(CRSAVE)	;P/u saved character
	OR	A		;If one is saved, put
				;  it on screen, else
	JR	NZ,PUTA@DE	;  ignore it
	LD	A,(DE)		;Cursor not ON but get
	RET			;  character anyway
;
;	Routine to put a character at row,col
;
PUT_@_ROWCOL
	CALL	ROWCOL_2_ADDR	;Get address of req
	RET	NZ		;Back on error
PUT_@	LD	A,0		;Merge in reverse video
INVIDEO	EQU	$-1
	OR	C
PUTA@DE	LD	(DE),A		;Put the character
	CP	A		;Set Z-flag for return
	RET
;
;	Routine to calculate cursor position from row,col
;
ROWCOL_2_ADDR
	LD	A,79
	CP	L
	JR	C,PERR		;Error if > 79
	LD	A,H		;P/u row number
	CP	24
	JR	NC,PERR		;Error if > 23
	PUSH	HL
	PUSH	BC
	LD	C,L		;Save column
	LD	B,CRTBGN$<-8	;Set to start of DO RAM
	LD	HL,LINESIZ
	CALL	@MUL16		;Rows * line size
	LD	H,L		;Shift to HL
	LD	L,A
	ADD	HL,BC		;Add in col & RAM start
	EX	DE,HL		;Address to DE
	POP	BC
	POP	HL
	XOR	A		;Set Z flag
	RET
PERR	LD	A,43		;SVC parameter error
	OR	A		;Set NZ condition
	RET
;
;	Routine to get row,col of video cursor
;
ADDR_2_ROWCOL
	LD	HL,(CURSOR)	;Get addr in HL
ADDR1	LD	A,H		;Make address relative
	AND	7		;  to origin 0
	LD	H,A
	LD	A,LINESIZ	;Set divisor
	CALL	@DIV16
	LD	H,L		;Row to register H
	LD	L,A		;Column to register L
	XOR	A		;Set zero return code
	RET
DOEND	EQU	$-1
	END
