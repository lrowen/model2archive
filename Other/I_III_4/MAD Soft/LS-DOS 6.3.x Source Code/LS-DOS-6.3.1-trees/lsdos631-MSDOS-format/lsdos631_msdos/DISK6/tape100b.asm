;TAPE100B/ASM - Disk I/O & other routines
;
;	DISPSTR - Display String
;
DISPSTR	PUSH	DE		;Save DE
	LD	DE,(CURPOS)	;P/u cursor position
DSLP	LD	A,(HL)		;P/u source char
	CP	ETX		;Done ?
	JR	Z,EXIT1		;Yes - exit
	CP	CR		;Done ?
	JR	Z,EXIT2		;Yes - exit
	CP	LF		;Line feed ?
	JR	NZ,STUFCHR	;No - stuff character
	CALL	NEXTLIN		;Get next line
	JR	BUMPIT
STUFCHR	LD	(DE),A		;Output to video
	INC	DE
BUMPIT	INC	HL		;No - bump count
	JR	DSLP
EXIT2	CALL	NEXTLIN		;Next one down
EXIT1	LD	(CURPOS),DE	;Save cursor position
	POP	DE		;Restore DE
	RET
;
;	NEXTLIN - Position to next line on video
;	DE => RAM location
;
NEXTLIN	PUSH	HL		;Save regs
	EX	DE,HL		;Xfer # to HL
	CALL	GETCRS		;Calculate X,Y
	INC	H		;Bump row #
	LD	L,0		;  and start @ beginning
	CALL	GETPOS2		;Convert to RAM location
	EX	DE,HL		;Stuff into DE
	POP	HL
	RET
;
;	CONV_UC - Convert A to upper case
;
CONV_UC	CP	'a'		;Lower case ?
	RET	C		;No
	CP	'z'+1		;Lower case ?
	RET	NC		;No
	RES	5,A		;Convert to Upper Case
	RET
;
;	CURSOFF - Turn off Cursor
;
CURSOFF	PUSH	AF		;Save regs
	PUSH	DE
	PUSH	BC
	LD	C,CUROFF	;Cursor off Character
	@@DSP
	JP	NZ,IOERR
	POP	BC		;Restore regs
	POP	DE
	POP	AF
	RET
;
;	INIT - Init a file
;
INIT	LD	A,@INIT		;SVC #
	JR	DOSVC		;INIT file
;
;	OPEN - Open Source File
;
OPEN	SET	0,(IY+SFLAG$)	;Inhibit file-open bit
	LD	A,@OPEN		;OPEN SVC #
;
DOSVC	PUSH	AF
	PUSH	DE
	LD	HL,DFBUF	;HL => Disk filename buf
TLP	LD	A,(DE)		;P/u byte from FCB
	LD	(HL),A		;Xfer to TEMBUF
	INC	HL
	INC	DE
	CP	CR+1		;Done ?
	JR	C,DUN
	CP	':'
	JR	Z,DUN
	CP	'.'
	JR	NZ,TLP
;
;	Found valid terminator - Is this a device ?
;
DUN	DEC	HL		;Back up to term
	POP	DE		;DE => FCB+0
	LD	A,(DE)		;Device ?
	CP	'*'
	JR	Z,DUN2		;Yes - done
	LD	(HL),':'	;No - overwrite with ":"
	INC	HL		;Bump
	LD	(DSPEC+1),HL	;Save drivespec location
	INC	HL		;Bump
DUN2	LD	(HL),ETX	;End with X'03'
	POP	AF		;A = SVC #
	LD	(SVCNUM+1),A	;Save SVC #
	LD	HL,IOBUFF	;HL => I/O Buffer
	LD	B,0		;LRL = 256
	RST	28H		;OPEN or INIT file
CHECK	JR	Z,CHKPROT	;Check PROTection status
;
;	Ignore Error #42 - "LRL Open Fault"
;
	CP	42		;Ignore this error
	RET	NZ		;NZ - Abort
;
;	Stuff Drive # into Buffer
;
CHKPROT	PUSH	DE		;P/u drivespec
	POP	IX		;  from FCB+6
	LD	A,(IX+6)
	ADD	A,'0'		;Convert to ASCII
DSPEC	LD	($-$),A
;
;	Check if File has proper Access
;
	BIT	7,(IX)		;Is FCB open?
	JR	Z,ILLFILE	;No - Illegal Filename
	LD	A,(IX+1)	;P/u protection byte
	AND	7
	LD	B,A		;Xfer to B
;
SVCNUM	LD	A,$-$		;P/u SVC #
	CP	@INIT		;@INIT ?
	LD	A,B		;P/u protection level
	JR	Z,INIT1		;Z - Must be < 5
	CP	6		;Read Access ?
	JR	C,OKYDOKY	;Yes - set Z & RETurn
;
;	Illegal Access to protected file
;
ILLACC	@@CLOSE			;Close File
	LD	A,25		;File Access Denied
	JP	IOERR		;Error - Regardless
;
INIT1	CP	5		;Update Access ?
	JR	NC,ILLACC	;No - Illegal Access
OKYDOKY	XOR	A		;RETurn Z
	RET
;
ILLFILE	LD	A,19		;Illegal Filename
	OR	A		;Set NZ
	RET			;
;
;	CLOSE - Close the Destination File
;
CLOSE	LD	DE,FCB2		;DE => FCB
	@@CLOSE			;Close File
	RET	Z		;Good - RETurn
	JP	IOERR		;Bad - Quit
;
;	WRITESC - Write a Sector to Destination file
;
WRITESC	LD	DE,FCB2		;DE => FCB
	@@WRITE			;Write Sector
	JP	NZ,IOERR	;Bad - quit
	RET			;Good - RETurn
;
;	WRTDEST - Write Destination File
;
WRTDEST	LD	DE,FCB2		;DE => Destination FCB
WRTDES	LD	HL,FCB2+4	;HL => msb of I/O buffer
	INC	(HL)		;Bump
	CALL	WRITESC		;Write Sector
EOTF2	LD	A,$-$		;P/u # of sectors
	CP	(HL)		;Finished ?
	JR	NZ,WRTDES	;No - back to loop
;
;	Finished Writing - Set EOF offset byte
;
OFFSET	LD	A,$-$		;P/u offset byte
	LD	(FCB2+8),A	;  & stuff into FCB
	CALL	CLOSE		;Close the File
	RET
;
;	READSRC - Read in chunk of Source Disk file
;
READSRC	LD	HL,FCB1+4	;HL => Hi byte of I/O buf
	LD	(HL),MEM<-8-1	;Init FCB I/O buffer
;
;	Read in Source file
;
READSR2	LD	DE,FCB1		;Pt DE to FCB
	INC	(HL)		;Bump I/O buffer
	@@READ			;Read a sector
	JR	Z,READSR2
;
;	Fill remainder of sector w/ X'1A's
;
	PUSH	AF		;Save Error code
NOMORE	LD	A,(FCB1+8)	;P/u EOF offset byte
	NEG
	LD	B,A		;Xfer to B for DJNZ
	LD	H,(HL)		;P/u I/O buffer msb
	LD	L,0FFH		;End of sector
	JR	Z,NULBUF	;Z - keep HL here
	DEC	H		;Sector boundary
NULBUF	LD	(HL),1AH	;Fill remainder of buffer
	DEC	HL		;  with zeroes
	DJNZ	NULBUF
;
;	Add a sector of 1As
;
	INC	H		;Pt to next sector
	LD	L,0
XTR1AS	LD	(HL),01AH	;EOF indicator
	INC	HL		;Bump
	DJNZ	XTR1AS
DONTFIL	POP	AF		;Recover error code
;
;	I/O Error - Better be EOF error
;
	CP	1CH		;EOF ?
	RET	Z		;Yes - RETurn
	CP	1DH		;NRN > ERN
	RET	Z		;Yes - RETurn
	JP	IOERR		;No - Disk Error
;
;	ENDOKI - Enable Video & Keyboard
;
ENDOKI	PUSH	AF
	PUSH	HL
	LD	A,(OPREG$)	;P/u port mask
	LD	(SVOPREG+1),A	;  and save it for DISDOKI
	RES	0,A		;Reset bit 0
	SET	1,A		;Set bit 1
	JR	DOOPREG		;Set new assignment
;
;	DISDOKI - Disable Video & Keyboard
;
DISDOKI	PUSH	AF
	PUSH	HL
;
SVOPREG	LD	A,$-$		;Restore original mask
DOOPREG	LD	(OPREG$),A
	OUT	(@OPREG),A	;  and disable video
;
	POP	HL		;Restore regs & RETurn
	POP	AF
	RET
;
;	SWAP38 - Swap 38H - 3AH with save area
;
SWAP38	LD	B,3		;3 bytes to exchange
	LD	HL,SWAREA	;HL => Swap Area
	LD	DE,38H		;DE => Restart Xfer addr
SWAPLP	LD	C,(HL)		;P/u source
	LD	A,(DE)
	EX	DE,HL		;Swap ptrs
	LD	(HL),C		;Stuff in dest
	LD	(DE),A
	INC	HL		;Bump ptrs
	INC	DE
	DJNZ	SWAPLP		;3 bytes to swap
	RET
;
SWAREA	JP	RST38V		;JP vector
;
;	GETPOS - Get current cursor position in video
;
GETPOS	LD	B,4		;P/u current cursor pos
	@@VDCTL
GETPOS2	LD	C,L		;Save column #
	LD	L,H
	LD	H,0		;HL => Row #
	LD	D,H		;Set DE = HL
	LD	E,L
	ADD	HL,HL		;X 2
	ADD	HL,HL		;X 4
	ADD	HL,DE		;X 5
	ADD	HL,HL		;X 10
	ADD	HL,HL		;X 20
	ADD	HL,HL		;X 40
	ADD	HL,HL		;X 80
	LD	B,VIDEO<-8	;D = high byte of video
	ADD	HL,BC		;HL => Cursor location
	LD	(CURPOS),HL	;Save cursor position
	RET
;
;	GETCRS - Calculate row x column cursor pos
;	HL => Cursor position in RAM
;	HL <= Cursor position in Row (H) Column (L)
;
GETCRS	LD	DE,VIDEO	;Get offset
	OR	A
	SBC	HL,DE
	LD	C,80		;Calculate row #
	@@DIV16
	LD	H,L		;Set H = Row
	LD	L,A		;Set L = Column
	RET
