;KIDVR2/ASM - LDOS Keyboard driver Model II - 12/29/83
;
*MOD
;*=*=*
;	Change Log
;05/14/83 - Reduced typbuf to 64 chars.
;09/30/83 - reset to 80 chars - kjw
;10/20/83 - move type buffer to excess video memory
;*=*=*
ETX	EQU	03
LF	EQU	10
CR	EQU	13
TYPBUF	EQU	80*24+0F800H	;buffer start
TYPBUFL	EQU	80		;buffer length
;
KIDVR	JR	KIBGN		;Branch around linkage
	DW	KILAST		;Last byte used
	DB	3,'$KI'
	DW	KIDCB$		;Pointer to DCB
	DW	0		;Spare
KIDATA$	DB	0		;Last key entered
	DB	0		;Repeat time check
	DB	22		;22 * 33.3ms = .733 sec
	DB	2		;2 x RTC rate
;
;	keyboard type ahead buffer block
;
KIBLOK	DW	TYPBUF		;type buffer
	DB	TYPBUFL		;buffer length
	DB	0		;add offset
	DB	0		;take offset
	DB	0		;FF = ESC lead in code
;*****
;	Entry to keyboard driver
;*****
KIBGN	LD	A,C		;get that character
	PUSH	AF		;Save flags
	CALL	@KITSK		;Hook for KI task
	POP	AF
;*****
;	Screen print (Control-*) processing
;*****
	CALL	TYPAHD		;Chain downstream
	RET	NZ		;go on EOF or no char
	PUSH	AF		;Save flag state
	CP	';'+80H		;ESC ';'?
	JR	Z,$?1		;Go if screen print
	POP	AF
	RET
;*=*=*
;	Perform a screen print
;*=*=*
$?1	POP	AF		;Clean the stack
	LD	A,(DFLAG$)	;Check on Graphic bit
	RLCA
	LD	A,3EH		;init for LD a,'.'
	JR	NC,$+4		;Go if not Graphic
	LD	A,0FEH		;Change to CPR n
	LD	($?4),A		;Stuff cpr or ld
	LD	HL,KFLAG$	;Reset the BREAK bit
	RES	0,(HL)
	PUSH	HL		;Save on stack
	LD	HL,0		;Init for row,col
$?2	LD	B,1		;Get a character at the
	CALL	@VDCTL		;  row-H, col-L
	JR	NZ,$?6		;Go on error
	CP	20H
	JR	NC,$+4		;convert control codes
	ADD	A,40H		;  to cap A-Z, +
	CP	80H		;cvrt anything from X'80'
	JR	C,$?5		;thru X'FF' to a '.'
$?4	LD	A,'.'
$?5	CALL	@PRT		;print the char & loop
	JR	NZ,$?6
	INC	L		;Bump column counter
	LD	A,L		;Check for end-of-line
	LD	BC,(CRTD1)	;get # video columns
	SUB	C		;check for end line
	JR	NZ,$?2		;Loop if not EOL
	LD	L,A		;Reset to column 0
	DEC	L		;Adj for CR force
	EX	(SP),HL		;Get KFLAG$
	BIT	0,(HL)		;Exit with A=0 on
	EX	(SP),HL		;  entrance of BREAK
	JR	NZ,$?6
	INC	H		;Bump row counter
	LD	A,H		;Test for end of screen
	CP	24
	LD	A,CR
	JR	NZ,$?5		;Put the CR & loop
$?6	LD	A,CR		;close out with CR if
	CALL	@PRT		;  BREAK key detected
	POP	HL		;Pop the KFLAG
	RES	0,(HL)		;  & reset BREAK bit
NOCHAR	OR	-1		;set no key
	CPL			;NZ and A=0
	RET			;done
;*=*=*
;	Check the type ahead buffer for any character
;*=*=*
*MOD
TYPAHD	CALL	ENADIS_DO_RAM	;enable video
	LD	IX,KIBLOK	;keyboard block
	JR	C,$?1		;Go on @GET
	JR	Z,KBCAN		;what, no put???
	CP	3
	JR	Z,KYFLUSH	;Clear buffer if so
KBCAN	XOR	A		;Nothing done, No error
	RET			;done
;
;	fetch character from type buffer
;
$?1	CALL	BUFFTAK		;any chars here?
	JR	NC,KBDEMP	;nope, empty!
	LD	(IX+4),A	;update ring
	LD	A,(HL)		;get char
	INC	A		;FF = 1CH+NZ?
	JR	Z,$?1AA		;go if yes
	DEC	A		;correct char
	CP	A		;set Z flag
	RET			;return with char
;
;	generate special EOF error condition
;
$?1AA	LD	A,1CH		;generate EOF error
	OR	A		;set NZ
	RET			;done!
;
KYFLUSH	CALL	KBFLUSH		;clear type ahead
KBDEMP	LD	HL,KFLAG$	;keyboard flag
	RES	7,(HL)		;set buffer empty
	OR	-1		;set NZ flag
	CPL			;but return 0
KBDRET	RET			;done
;*****
;	mode 2 interrupt vector
;*****
*MOD
KIINT$	EX	(SP),HL		;get caller address
	LD	(KIINTP),HL	;save PC
	EX	(SP),HL		;swap back
;
	PUSH	AF		;save 'em
	PUSH	BC
	PUSH	DE
	PUSH	HL
	PUSH	IX
	LD	HL,KBDRET	;normal return vector
	LD	(KIINTV),HL	;pass normal vector
;
	IN	A,($RDKBD)	;clear key interrupt
	AND	7FH		;remove high bit
	LD	C,A		;save char
	LD	A,(MODOUT$)	;get memory image
	PUSH	AF		;save it
	CALL	VIDON		;enable video memory
	LD	A,C		;get char
	CALL	KBTASK1		;add char to buffer
	POP	AF		;restore memory image
	CALL	SET_MOD		;set from interrupt
	POP	IX		;unstack all
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	CALL	ENAINT		;enable interrupts
	JP	KBDRET		;return or go vector
KIINTV	EQU	$-2
;
;	add character to type ahead buffer
;
KBTASK1	LD	IX,KIBLOK	;init key block
;
;	check if lead in ESC entered
;
	INC	(IX+5)		;check if FF ESC pending
	JR	Z,ESCPEND	;yes, go!
	DEC	(IX+5)		;reset to normal (00)
	CP	1BH		;escape key now?
	JR	NZ,NOTESC	;nope, go!
	DEC	(IX+5)		;set to FF (pending)
	RET			;exit no key
;
;	escape key pending, check for special keys
;
ESCPEND	CP	1BH		;ESC ESC?
	LD	B,A		;pass key
	JR	C,$?1AB		;nope, go!
	CP	20H		;in range?
	JR	C,ADDKEY	;keep escape arrows+ESC
$?1AB	LD	B,0		;init ascii 00
	OR	A		;ESC HOLD?
	JR	Z,ADDKEY	;yes, go!
	DEC	B		;init EOF error generator
	CP	0DH		;ESC ENTER?
	JR	Z,ADDKEY	;yes, go!
	LD	B,03H		;init control C
	CP	B		;ESC BREAK?
	JR	Z,ADDKEY	;yes, go!
	LD	B,60H		;init `
	CP	' '		;ESC space?
	JR	Z,ADDKEY	;yes, go!
	CP	9		;clear type?
	JR	Z,KBFLUSH	;flush type buffer
;
	CALL	UCASE		;make upper case
	OR	80H		;set high bit
	LD	B,A		;pass key
	JR	ADDKEY		;add to buffer
;
NOTESC	CP	03H		;break key?
	JR	NZ,NOTBRK	;nope, continue
	LD	HL,SFLAG$	;keyboard flag
	BIT	4,(HL)		;break disabled?
	RET	NZ		;yes, discard
	LD	HL,KFLAG$	;keyboard flag
	SET	0,(HL)		;set BREAK pressed
	LD	HL,@DBGHK	;debug hook
	LD	A,(HL)		;get data
	LD	(HL),0C9H	;disable debug
	INC	HL		;point to vector
	OR	A		;was on?
	JR	Z,GODEB		;yes, go!
	LD	HL,0		;get break vector
BRKVEC$	EQU	$-2
	LD	A,H		;anything?
	OR	L
	JR	NZ,GODEB0	;yes, go to it
	LD	HL,DFLAG$	;system flag
	BIT	1,(HL)		;type on?
	JR	Z,SETBRK	;no type, add char
	CALL	BUFFTAK		;any chars in buffer?
	JR	C,KBFLUSH	;chars in buff, flush
;
;	add break key to buffer and flag as there
;
SETBRK	LD	A,80H		;altered break char
;
NOTBRK	CALL	KICONV		;convert arrow keys
	LD	B,A		;pass key
	OR	A		;HOLD key?
	LD	HL,KFLAG$	;keyboard flag
	JR	NZ,NOTHOL	;nope, continue
	SET	1,(HL)		;set HOLD flag
	RET			;exit
;
NOTHOL	CP	CR		;carriage return?
	JR	NZ,ADDKEY	;nope, go
	SET	2,(HL)		;set CR in buffer
;
ADDKEY	LD	HL,DFLAG$	;system flag
	BIT	1,(HL)		;type ahead on?
	CALL	Z,KBFLUSH	;flush buffer if not
;
;	stuff key into type buffer
;
KBSTUFF	CALL	BUFFADD		;attempt to add to buffer
	RET	NC		;go if no more room!
	LD	(HL),B		;load char to buffer
	LD	HL,KFLAG$	;system flag
	SET	7,(HL)		;set char in buffer!
	RET			;key added!
;
KBFLUSH	XOR	A		;load zero
	LD	(IX+3),A	;clear add offset
	LD	(IX+4),A	;clear take offset
	LD	(IX+5),A	;clear ESC pending
	LD	HL,KFLAG$	;keyboard flag
	RES	7,(HL)		;set buffer empty
	RET			;done
;
;	enter user vector
;
GODEB0	PUSH	HL		;save vector
	CALL	KBFLUSH		;flush type buffer
	LD	B,80H		;break key char
	CALL	KBSTUFF		;stuff into buffer!
	POP	HL		;restore
;
	LD	A,(KIINTP+1)	;get msb int address
	CP	24H		;in system?
	RET	C		;yes, ignore!
	PUSH	HL		;save
	LD	HL,HIGH$+1	;msb high memory
	CP	(HL)		;in there?
	POP	HL		;restore
	RET	NC		;yes, ignore!
;
;	check if DMA is active, and ignore vect if ON
;
GODEB	LD	A,(LCKFLG$)	;get lockout flag
	ADD	A,A		;bit 7 set?
	RET	C		;yes, ignore vector!
	LD	(KIINTV),HL	;save new vector
	RET			;return
KIINTP	DW	0
;
@DBGHK	RET			;init debug off
@DEBUG	PUSH	AF		;save
	LD	A,97H		;enter debugger
	RST	40		;go!
EXTDBG$	DW	ORARET@		;hook for extended debug
ORARET@	OR	A		;clear
	RET			;go!
;
;	convert special input keys
;
KICONV	LD	HL,KICTBL	;keyboard convert table
;
;	$LOOKUP - search table
;
@LOOKUP	INC	(HL)		;FF terminator?
	JR	Z,LOOKNOT	;yes, not found!
	DEC	(HL)		;correct
	CP	(HL)		;matching entry?
	INC	HL		;bump pointer
	JR	Z,$GETHL	;found, fetch vector
	INC	HL		;else bump past
	INC	HL		;2 byte vector
	JR	@LOOKUP		;go next entry
;
LOOKNOT	DEC	(HL)		;correct table
	RET			;done
;
;	load HL with (HL)
;
$GETHL	LD	A,(HL)		;get lsb
	INC	HL		;bump
	LD	H,(HL)		;get msb
	LD	L,A		;HL = vector
RSRET	RET			;return with it
;
;	convert table for arrow keys normal
;
KICTBL	DB	1CH		;left arrow
	DW	08H
	DB	1DH		;right arrow
	DW	09H
	DB	1EH		;up arrow
	DW	0BH
	DB	1FH		;down arrow
	DW	0AH
	DB	-1		;terminator
;
;	convert A to upper case
;
UCASE	CP	'a'		;in lower range?
	RET	C		;nope, go!
	CP	'z'+1		;in lower?
	RET	NC		;nope, go!
	SUB	20H		;make upper!
	RET			;new char
;
KILAST	EQU	$-1
;
