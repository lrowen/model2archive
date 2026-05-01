;SERIAL3/ASM  -  '86
;*****
;       formatting data and tables
; track skew offsets
S5OFF	EQU	8
S8OFF	EQU	2
D5OFF	EQU	15
D5OFFF	EQU	10
D8OFF	EQU	20
D8OFFF	EQU	12
;*****
SECCYL	DS	1		;# of sectors per cyl
SECTRK	DS	1		;# of sectors per trk
;*****
;       single density 5" format table
;*****
S5TBL	DB	10,S5OFF
	DB	0,5,1,6,2,7,3,8,4,9
	DC	S5OFF+1,-10	;Fill w/neg num of sectors
	DB	14,0FFH
	DB	0F1H,6,0,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,1,0FFH,11,0FFH
	DB	6,0,1,0FBH,0,0E5H,1,0F7H,1,0FFH,13,0FFH
	DB	0F2H,47H,0FFH,0F4H
	DB	0,1,2,3,4,5,6,7,8,9
;*****
; double density 5" format table - interleave for SLOW system
;*****
D5TBL	DB	18,D5OFF
	DB	0,6,12,1,7,13,2,8,14
	DB	3,9,15,4,10,16,5,11,17
	DC	D5OFF+1,-18
	DB	32,4EH
	DB	0F1H,12,0,3,0F5H,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,22,4EH,12,0,3,0F5H
	DB	1,0FBH,0F5H,128,6DH,0B6H
	DB	1,0F7H,1,0FFH,23,04EH
	DB	0F2H,182,4EH,0F4H
	DB	0,1,2,3,4,5,6,7,8,9,10
	DB	11,12,13,14,15,16,17
;*****
;       single density 8" format table
;*****
S8TBL	DB	16,S8OFF
	DB	10,5,0,11,6,1,12,7,2,13,8,3,14,9,4,15
	DC	S8OFF+1,-16
	DB	28H,0FFH
	DB	0F1H,6,0,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,11,0FFH,6,0,1,0FBH
	DB	0,0E5H,1,0F7H,1,0FFH,20,0FFH
	DB	0F2H,208,0FFH,0F4H
	DB	10,0,6,12,2,8,14,4,5,11,1,7,13,3,9,15
;*****
; double density 8" format table - interleave for SLOW system
;*****
D8TBL	DB	30,D8OFF
	DB	0,6,12,18,24,1,7,13,19,25,2,8,14,20,26
	DB	3,9,15,21,27,4,10,16,22,28,5,11,17,23,29
	DC	D8OFF+1,-30
	DB	20,4EH
	DB	0F1H,0CH,0,3,0F5H,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,22,4EH,12,0,3,0F5H
	DB	1,0FBH,0F5H,128,6DH,0B6H
	DB	1,0F7H,1,0FFH,17,4EH
	DB	0F2H,0,4EH,61,4EH,0F4H
	DB	0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
	DB	17,18,19,20,21,22,23,24,25,26,27,28,29
	DB	0,0,0,0,0	;Slack                  *
;*****
; double density 5" format table - interleave for FAST system
;*****
D5TBLF	DB	18,D5OFFF
	DB	0,9,1,10,2,11,3,12,4
	DB	13,5,14,6,15,7,16,8,17
	DC	D5OFFF+1,-18
	DB	32,4EH
	DB	0F1H,12,0,3,0F5H,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,22,4EH,12,0,3,0F5H
	DB	1,0FBH,0F5H,128,6DH,0B6H
	DB	1,0F7H,1,0FFH,23,04EH
	DB	0F2H,182,4EH,0F4H
	DB	0,1,2,3,4,5,6,7,8,9
	DB	10,11,12,13,14,15,16,17
;*****
; double density 8" format table - interleave for FAST system
;*****
D8TBLF	DB	30,D8OFFF
	DB	0,10,20,1,11,21,2,12,22,3,13,23,4,14,24
	DB	5,15,25,6,16,26,7,17,27,8,18,28,9,19,29
	DC	D8OFFF+1,-30
	DB	20,4EH
	DB	0F1H,0CH,0,3,0F5H,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,22,4EH,12,0,3,0F5H
	DB	1,0FBH,0F5H,128,6DH,0B6H
	DB	1,0F7H,1,0FFH,17,4EH
	DB	0F2H,0,4EH,61,4EH,0F4H
	DB	0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
	DB	16,17,18,19,20,21,22,23,24,25,26,27,28,29
	DB	0,0,0,0,0	;Slack                  *
;**
FMTCYL$	DM	29,'Formatting cylinder   ',3
VERCYL$	DM	29,'Verifying  cylinder   ',3
WRIT$	DB	29,'Writing    cylinder   ',3
READ$	DB	29,'Reading    cylinder   ',3
NODSK$	DB	29,'Disk not ready        ',3
BABT$	DB	29,'BREAK pressed         ',3
PMTSYS$	DM	LF,'Load SYSTEM diskette and press <ENTER>',CR
RTCBAD$	DM	LF,'Note: Realtime clock'
	DB	' no longer accurate',CR
MEM$	DB	LF,'MEMORY FAULT -',3
DABT2$	DB	LF,'Source READ error -',3
DABT$	DB	'  =======> Source disk error',LF
	DB	LF,'Press <ENTER> to restart program'
	DB	' or <BREAK> to exit.',CR
ABT$	DB	' Program aborted!',CR
MISSYS$	DB	'Missing or defective SYS overlay. Can''t serialize',CR
SERROR$	DB	'Bad disk - can''t serialize drive '
SERROR	DB	'0',CR
SERIAL$	DB	'Enter starting serial # ',3
KEYBUF	DS	8
SN$	DS	10		;Serial in ascii
SNCOMP$	DW	0		;Serial in compressed
;
SYSPEC	DB	'SYS0/SYS.LSIDOS: ',3
	IF	.NOT.DUPE
TUFF$	DB	'Cannot duplicate disk with protected files.',CR
	ENDIF
;*=*=*
;
;Convert (A) to 2 ascii digits =>(HL)
ASCII:	PUSH	AF		;Save char
	RRA
	RRA			;Look at high nibble
	RRA
	RRA
	CALL	ASC1		;Conv to char
	POP	AF		;Restore byte
ASC1:	AND	0FH		;Make high nibble
	ADD	A,90H		;Make ASCII
	DAA
	ADC	A,40H
	DAA
	LD	(HL),A		;Stuff into =>HL
	INC	HL
	RET
;
READSOR	LD	IY,(SORDCT)	;Get DCT ptr
	IF	DUPE
	LD	B,7		;First be sure there is
	XOR	A
	LD	HL,ACTLST	;At least one
DC1	OR	(HL)		;Dest drive active
	INC	HL
	DJNZ	DC1
	RET	Z		;Nowhere to write, so skip
	ELSE
;QFB has only one dest drv
	LD	A,(ACTLST)
	OR	A
	RET	Z
	ENDIF
;
	CALL	GATCHK		;Need this trk?
	RET	Z		;Skip if not wanted
	LD	A,(DRVLST)	;Set drv # for C reg
	AND	7
	LD	(DRVNO),A	;In dvr setup
	CALL	READCYL		;Read in a track/calc cksum
	CALL	NZ,BMPERR	;Flag error
	IF	DUPE
	LD	A,(PASS1)	;Is this the 1st round?
	OR	A
	JR	NZ,PS2
	ENDIF
	CALL	ENTER1		;Store cksum in table
	IF	DUPE
	CALL	CKSOR		;Verify the checksum
	CALL	NZ,BMPERR
	ENDIF
PS2	CALL	CKTBL
	RET
;
;Set buffer ptr / clear chksum
INITTRK	LD	A,(READ)	;Will be 1 if verify
	LD	HL,TRKBUF	; start here
	DEC	A
	JR	NZ,SPTR		;If not verify
	LD	HL,SECBUF	;If verify
SPTR	PUSH	HL
	EXX
	POP	HL		;Init data pointer
	LD	BC,0		;Init chksum
	EXX
	RET
;
CKSUM:	EXX			;Alt regs
ADLP:	LD	A,(HL)		;Get a byte
	ADD	A,C		;Add in
	LD	C,A		;Save
	JR	NC,DNN		;W/carry
	INC	B
DNN:	INC	L		;=>next
	JR	NZ,ADLP		;For a sector
	LD	A,(READ)	;Doing verify?
	DEC	A		;A 1 if so..
	JR	Z,VERC		;Not loading
	INC	H		;Set for next
	EXX			;Swap back
	INC	H		;Bump alt also
	RET
VERC	EXX			;Ret with HL the same
	RET
;
;Put an entry in the checksum table
ENTER1:	LD	A,(CURCYL)	;Trk posn
	ADD	A,A		;Double for table entry
	EXX
	PUSH	HL		;Save buffer ptr posn
	LD	HL,TABLE	;Calc entry posn
	LD	L,A
	LD	(HL),C		;Store low byte
	INC	H		;In two places
	LD	(HL),C
	DEC	H
	INC	L
	LD	(HL),B		;Then high byte
	INC	H
	LD	(HL),B
	POP	HL
	EXX
	RET
;
;Verify checksum against table entry
CKTBL:	LD	A,(CURCYL)	;Trk #
	ADD	A,A		;X2 for table posn
	EXX
	PUSH	HL
	LD	HL,TABLE	;Find entry posn
	LD	L,A
	LD	A,(HL)		;P/u 1st entry
	INC	H
	CP	(HL)		;Memory OK?
	JP	NZ,MEMFLT	;Abort any time
	DEC	H		;The tables disagree..
	INC	L
	CP	C
	JP	NZ,DSKFLT
	LD	A,(HL)
	INC	H
	CP	(HL)
	JP	NZ,MEMFLT
	CP	B
DSKFLT	POP	HL
	EXX
	CALL	NZ,BMPERR
	RET
;
MEMFLT:	POP	HL
	EXX
	LD	HL,MEM$		;MEMORY msg
	JP	ABT1		;Panic..
;
;*=*=* Set C = Drive #, IY => DCT address *=*=*
;
GETDCT	PUSH	DE
	LD	C,A		;Logical drive number
	ADD	A,A		;Multiply the logical
	ADD	A,A		;Drive number by ten
	ADD	A,C		;And add to the start
	ADD	A,A		;Of the DCT
	LD	DE,(DCTPTR)	;DE => DCT for drive 0
	ADD	A,E		;Add offset
	LD	E,A		;DE=> DCT for drive
	PUSH	DE		;Save
	POP	IY		;IY => DCT
	POP	DE
	RET	
;
;*** DE =  16-bit Hexadecimal number to convert       ***
;*** HL => Destination of Decimal ASCII characters    ***
HEXDEC	PUSH	BC		;Save all registers
	PUSH	DE		;Used in this
	PUSH	IX		;Routine
	PUSH	IY		;
;
	LD	C,00H		;C=0 >> leading zero
	PUSH	HL		;C=1 > non-zero digit hit
	POP	IX		;IX => String destination
	EX	DE,HL		;HL =  Number to convert
	LD	IY,CTBL		;IY => Subtraction table
HEXDEC2	XOR	A		;Clear carry, count = 0
	LD	D,(IY+1)	;P/u lsb & msb from table
	LD	E,(IY)		;DE => Power of 10
;
DCO2	OR	A		;Clear carry
	SBC	HL,DE		;Successive subtracts
	JR	C,LDEC		;Until a carry, and
	INC	A		;Keep bumping the
	JR	DCO2		;Counter until carry.
;
LDEC	ADD	HL,DE		;HL = remainder
	ADD	A,30H		;A = ASCII digit
	LD	(IX),A		;Stuff into buffer
	INC	IY		;Point IY to
	INC	IY		;Next table entry
	LD	A,E		;If the last Power
	DEC	A		;Was 0 (DE = 1)
	JR	Z,WEREDUN	;Then we're done.
;
	BIT	0,C		;Have we hit a non-zero
	JR	NZ,COOL		;Digit yet - yes -- cool
;
	LD	A,(IX)		;Is this digit a "0"
	CP	30H		;If it is, then change
	JR	NZ,COOL		;It to a blank space
	LD	(IX),20H	;And put into buffer.
	JR	COOL1		;Spaces to LEFT!
;
COOL	LD	C,1		;Set lead zero flag
COOL1	INC	IX		;Bump destination ptr.
	JR	HEXDEC2		;Do til done.
;
;
WEREDUN	POP	IY		;Restore every
	POP	IX		;Single register
	POP	DE		;Except A
	POP	BC		;Cleaned up
	RET			;All done - return
;
;
CTBL	DW	10000		;Digit 5
	DW	1000		;Digit 4
	DW	100		;Digit 3
	DW	10		;Digit 2
	DW	1		;Digit 1
;
;
;Interrupts are off, so can't use KFLAG$
CKPAWS
	IF	V5
	LD	A,(3840H)
	BIT	2,A		;Break pressed?
	JR	NZ,BABORT
	LD	A,(3880H)	;Shift?
	AND	3		;Lft or rght
	RET	Z		;No
	LD	A,(3801H)	;@
	RRCA			;Test bit 0
	RET	NC		;No
; shift-@ pressed
CKPS2:	PUSH	DE
	CALL	@KEY		;Wait for char
	POP	DE
	CP	60H
	JR	Z,CKPS2		;Not sh-@
	RET	
	ENDIF
;
	IF	V6
	PUSH	DE
	CALL	@KBD		;Chk keyboard
	POP	DE
	CP	BREAK		;For break
	RET	NZ
	ENDIF
;
BABORT	XOR	A
	LD	(CURDRV),A	;Start at beginning
BLP	CALL	GETDCT1
	JR	Z,BLP2	
	LD	HL,BABT$	;Break pressed..
	CALL	@DSPLY
	CALL	LOCKOUT
	JR	BLP		;Lockout all drives
;
BLP2
	IF	V5
	LD	A,(3840H)	;Is break still down?
	BIT	2,A
	JR	NZ,BLP2		;Wait for key release
	LD	BC,200		;And debounce
	CALL	@PAUSE
	ENDIF
	JP	PASSDON		;Prmpt for retry
;
TABLE	EQU	$-1<-8+1<8	;Force mem page boundary
; init code that can be overwritten
	IF	V5
; check for model 1 and adjust addresses
MODEL	LD	A,(125H)
	CP	'I'
	JR	Z,SET2
	LD	HL,4476H	;@param
	LD	(M1),HL
	LD	HL,4049H	;HIGH$
	LD	(M2),HL
	LD	HL,447BH	;@logot
	LD	(M3),HL
	LD	(M4),HL
	LD	(M5),HL
	LD	(M6),HL
	LD	HL,430FH	;SFLAG$
	LD	(SFLAG),HL
; store DCTPTR and HIGH$ values for later
SET2	LD	HL,DCT$		;Set up DCTPTR for 5.1
	LD	(DCTPTR),HL
	LD	HL,(HIGH$)
M2	EQU	$-2
	LD	(MYHIGH),HL	;Save HIGH$ for later
	ENDIF
;
; save current environment for restore later
	IF	V6
MODEL	EQU	$
	ENDIF
;*=*=*
	LD	A,(@RST38)	;Save JP inst if there
	LD	(EXIT1+1),A	;To restore later
;Save all 8 DCTs to restore later
	LD	HL,(DCTPTR)
	LD	DE,TMPDCT$
	LD	BC,8*10
	LDIR
	RET
;
	ORG	TABLE+200H
GATBUF	DS	256		;GAT sector buffer
SECBUF	DS	256
TRKBUF	EQU	$
