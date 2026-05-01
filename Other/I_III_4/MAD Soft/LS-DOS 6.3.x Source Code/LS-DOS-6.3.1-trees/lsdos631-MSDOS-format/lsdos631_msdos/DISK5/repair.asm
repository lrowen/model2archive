;REPAIR/ASM - Directory Track Repair Program
	TITLE	<REPAIR - LS-DOS 6.2>
;
LF	EQU	10
CR	EQU	13
BLNKMPW	EQU	4296H
FLAG	EQU	01000000B
ABB	EQU	00010000B
;
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	COPYCOM:3		;Copyright message
;
	ORG	2600H
BEGIN
	@@CKBRKC		;Check for break
	JR	Z,BEGINA	;Continue if not
	LD	HL,-1		;  else abort
	RET
;
BEGINA
	LD	(STACK),SP	;Save entry stack
	PUSH	HL		;Save ptr to CMD buffer
	LD	HL,HELLO$	;Display the signon
	CALL	$DSPLY
	POP	HL
	CALL	PGRM		;Normal exit is via RET
;
;	Set exit condition..
;
$EXIT	LD	HL,0		;Init for no error
QUIT$	LD	SP,$-$		;P/u original stack
STACK	EQU	$-2
	@@CKBRKC		;Clear break before exit
	RET
;
PGRM	LD	A,(HL)		;Ck for drive entered
	CP	':'		;Colon indicator?
	JP	NZ,PRMERR	;Quit if not
	INC	HL		;Point to drive #
	LD	A,(HL)		;P/u drive
	SUB	'0'		;Cvrt to binary
	CP	8		;Bigger than 7?
	JP	NC,ILLEG	;Quit if so
;
	OR	A		;Can't be drive 0
	JP	Z,NOT0
	LD	(DRIVE),A	;Stuff for later
	INC	HL		;Bump past the drive
	LD	C,A
	@@GTDCT			;What's its DCT$
;
;	Get any parameters
;
	LD	DE,PRMTBL$	;Pt to parm table
	@@PARAM
	JP	NZ,PRMERR	;Exit on parm error
	LD	A,(MRSP)	;MPW parameter entered?
	OR	A
	JP	NZ,MPARM	;Go if so
	BIT	3,(IY+3)	;Can't "repair" a hard drive
	JP	NZ,NIXHARD	;  except for MPW parm
	BIT	4,(IY+4)	;If not alien controller
	CALL	Z,CKDRV		;  make sure disk present
	LD	DE,0		;Read BOOT to get dir cyl
	CALL	RDSEC
	XOR	A
	LD	(BUF1),A	;Set 1st byte to zero
	LD	A,(BUF1+2)	;P/u the dir cyl
	AND	7FH		;Strip bit 7
	LD	(BUF1+2),A	;Put it back
	PUSH	AF		;Save dir cyl
	CALL	WRSEC		;Rewrite the BOOT
	INC	E
	CALL	RDSEC		;Get sect 1 also
	POP	AF
	LD	(BUF1+2),A	;Update dir cyl
	PUSH	AF
	CALL	WRSEC		;Write back
	POP	AF		;Dir cyl again
;
	LD	D,A
	LD	E,0
	LD	(IY+9),A	;Set as dir cyl
	CALL	RDSEC		;Read the GAT
;
	RES	5,(IY+4)	;Show single sided
	LD	L,0CBH		;Pt to version # byte
	LD	A,(HL)		;Pick it up
	CP	40H		;Earlier than a 4.0?
	JR	C,LC		;Bypass 2 sided ck if so
	CP	70H		;"Later" than 6.x?
	JR	NC,LC		;Again, no sides ck
	LD	L,0CDH		;Point to CONFIG byte
	BIT	5,(HL)		;Check 2-sided
	JR	Z,LC		;Go if not
	SET	5,(IY+4)	;  else update DCT
;
LC	LD	L,0BFH		;Pt to end of lockout
	LD	B,96		;Max cylinder count
ALIEN1	LD	A,(HL)		;P/u a lockout byte
	INC	A		;Locked out?
	JR	NZ,ALIEN2	;Exit when in use
	DEC	L		;Backup by 1
	DJNZ	ALIEN1
ALIEN2	LD	A,-35		;What's in use?
	ADD	A,B		;Convert to excess
	LD	L,0CCH
	LD	(HL),A		;Stuff into GAT
;
;	Construct config byte
;
	LD	A,(IY+4)	;P/u # sides
	AND	80H!20H
	LD	B,A		;Save tempy
	LD	A,(IY+3)	;P/u density
	AND	40H
	OR	B		;Merge with previous
	LD	B,A
	LD	A,(IY+8)	;P/u # grans/track
	RLCA
	RLCA			;  to bits 0-2
	RLCA
	AND	7		;Mask off the rest
	OR	B		;Merge with previous
	INC	L		;Pt to config byte in GAT
	LD	B,A		;Save for a moment
	LD	A,(HL)		;P/u present config byte
	AND	80H		;Keep only bit 7
	OR	B		;Pick up the rest
	LD	(HL),A		;  & stuff
	LD	L,0
	CALL	WRSYS		;Write the GAT
;
;	Operate on the HIT
;
	INC	E		;Bump sector ptr to 1
	CALL	RDSEC		;Read the HIT
	INC	L		;Pt to DIR/SYS dec
	LD	(HL),0C4H	;"correct" DEC code
	DEC	L
	CALL	WRSYS		;Write out the HIT
	LD	B,8		;Init for 8 sectors
ALIEN3	INC	E		;Bump to next sector
	CALL	RDSEC		;Get the sector
	CALL	UNOPEN		;Reset file open bit
	LD	A,E		;If DIR/SYS sector,
	CP	3		;  then update count & it
	JR	NZ,ALIEN4
	PUSH	HL
	LD	HL,BLNKMPW	;Set DIR/SYS password
	LD	(BUF1+12H),HL	;To blanks
	LD	A,(BUF1+20)	;P/u ERN of DIR/SYS
	SUB	3		;Account for 1st 3 done
	LD	B,A		;Update loop counter
	POP	HL
ALIEN4	CALL	WRSYS		;Write back the sector
	DJNZ	ALIEN3
;
	@@LOGOT	ALCAO$		;Advise complete - now readable
	RET			;Done
;
;	MPW parameter to change disk password on hard drive
;
MPARM	LD	DE,0		;P/u MPW string address
	BIT	5,A		;If not string, then error
	JP	Z,PRMERR
	BIT	3,(IY+3)	;Can't do if not hard
	JP	Z,PRMERR
	CALL	GETMPW		;Get and hash the entry
	JP	NZ,IOERR
	LD	C,0		;Init to drive requested
DRIVE	EQU	$-1
	CALL	GATRD		;Read GAT into BUF1
	JP	NZ,IOERR	;Back on error
	LD	(BUF1+0CEH),HL	;Stuff PW
	CALL	GATWR		;Write sector 0 from buf
	JP	NZ,IOERR	;Jump on write error
	RET			;Finished with Repair
;
;	Enter SYS2 & hash the password
;
GETMPW	CALL	GMPW1		;Get MPW into buffer
	RET	NZ
	LD	A,0E4H		;Hash password (DE) to HL
	RST	28H		;Ret to what called
;
;	Place entered password into buffer
;
GMPW1	LD	HL,PSWDBUF	;Point to buffer
	PUSH	HL
	LD	B,8		;Init for 8 chars
GMPW2	LD	A,(DE)		;P/u a char
	CP	CR		;End of line?
	JR	Z,GMPW4
	CP	','		;Comma separator?
	JR	Z,GMPW4
	CP	'"'		;Closing quote?
	JR	Z,GMPW4
	INC	DE		;Bump input pointer
	LD	(HL),A		;Transfer character
	INC	HL		;Bump output pointer
	DJNZ	GMPW2		;Loop until done
	JR	CKMPW
GMPW4	LD	(HL),' '	;Buffer with
	INC	HL		;  trailing spaces
	DJNZ	GMPW4
;
;	Convert to upper case and check validity
;
CKMPW	POP	HL		;Recover buffer start
	PUSH	HL
	LD	B,8
	LD	A,(HL)		;P/u 1st char
	JR	CKMPW2		;  & check <A-Z>
CKMPW1	INC	HL
	LD	A,(HL)
	CP	' '		;Got to a space?
	JR	Z,CKMPW7
	CP	'0'		;Less than '0' is error
	JR	C,INVMPW
	CP	'9'+1		;<0-9> is okay for 2-n
	JR	C,CKMPW3
CKMPW2	CP	'A'		;Less than "A" is error
	JR	C,INVMPW
	CP	'Z'+1		;<A-Z> is okay
	JR	C,CKMPW3
	CP	'a'		;<a-z> convert to
	JR	C,INVMPW
	CP	'z'+1
	JR	NC,INVMPW
	RES	5,(HL)		;  upper case
CKMPW3	DJNZ	CKMPW1
CKMPW4	POP	DE		;Point to buffer start
	XOR	A
	RET
CKMPW5	INC	HL
	CP	(HL)		;No imbedded spaces
	JR	NZ,INVMPW
CKMPW7	DJNZ	CKMPW5
	JR	CKMPW4
INVMPW	LD	HL,BADMPW$	;Init "Invalid PW
	LD	A,63		;Set extended error
	OR	A		;Set NZ condition
	POP	DE		;Clean up stack
	RET
;
;	Reset any file open bits
;
UNOPEN	PUSH	HL		;Save buffer posn
	PUSH	BC
	LD	B,8		;8 entries
	INC	L		;Dir + 1
ZAP	RES	5,(HL)		;Clear file open bit
	LD	A,32
	ADD	A,L		;Pt to next Dir+1
	LD	L,A
	DJNZ	ZAP		;Do 8 entries per direc
	POP	BC
	POP	HL
	RET
;
$DSPLY	@@DSPLY			;Display a line
	RET	Z
	JR	IOERR
;
WRSYS	@@WRSSC			;Write the sector
	JR	NZ,IOERR
	@@VRSEC			;Verify it
	CP	6		;Must be SYSTEM sector
	RET	Z
	JR	IOERR
;
WRSEC	@@WRSEC			;Write normal sector
	RET	Z
	JR	IOERR
;
;	Sector read routine
;
RDSEC	LD	HL,BUF1		;Read sector
	@@RDSEC	
	RET	Z
	CP	6
	RET	Z		;Fall thru to error?
;
;	Error exits
;
IOERR	CP	63		;Extended error?
	JR	Z,EXTERR	;Log it and quit
	LD	H,0		;Error to HL
	LD	L,A
	PUSH	HL		;Save error code
	OR	0C0H		;Set short, return
	LD	C,A		;Error to C for
	@@ERROR			;  display
;
	LD	HL,ABTJOB$	;Init"Job aborted
;
	@@LOGOT			;Log the msg
	POP	HL		;Recover error code
	JR	QUIT$$
;
;	Internal error handler
;
NIXHARD	LD	HL,NIXHARD$	;"Can't to hard drive
	DB	0DDH
NOT0	LD	HL,NOT0$	;"Can't do drive 0
	DB	0DDH
PRMERR	LD	HL,PRMERR$	;"Parm error
	DB	0DDH
EXTERR	@@LOGOT			;Display the error
	LD	HL,-1		;Set abort code
QUIT$$	JP	QUIT$
;
;	Read the granule allocation table
;
GATRD	DB	0F6H		;Set NZ for test
GATWR	XOR	A		;Set Z for test
	PUSH	HL
	PUSH	AF
	LD	D,(IY+9)	;Dir cylinder
	LD	HL,BUF1
	LD	E,L		;Set to sector 0
	POP	AF
	JR	Z,GATRW1	;Go if write
	@@RDSSC
	LD	A,14H
	JR	GATRW3
GATRW1	@@WRSSC
	JR	NZ,GATRW2	;Skip verify if error
	@@VRSEC			;Verify the write
GATRW2	CP	6		;Expect error 6
	LD	A,15H		;Init "Gat error
GATRW3	POP	HL
	RET
;
;	Routine to check on floppy present
;
CKDRV	LD	A,40		;@DCSTAT
	RST	28H
	JR	NZ,ILLEG
	LD	A,44		;@RSTORE
	RST	28H
	LD	HL,BUF1		;Set up for
	PUSH	BC		;  mini ckdrv
	@@TIME			;P/u timer ptr
	POP	BC
	EX	DE,HL		;Pt HL to
	DEC	HL		;  heartbeat counter
	LD	A,47		;@RSLCT
	RST	28H		;Wait till ready
	LD	A,(HL)		;Get heartbeat count
	ADD	A,20		;Init to + 500ms
	LD	D,A		;Store for timeout check
CK1	CALL	INDEX
	JR	NZ,CK1		;Get no pulse
CK2	CALL	INDEX
	JR	Z,CK2		;Get pulse
CK3	CALL	INDEX
	JR	NZ,CK3		;Get no pulse
	RET
;
INDEX	LD	A,(HL)		;Get time
	CP	D		;Interval expired?
	JR	Z,ILLG1
	LD	A,47		;@RSLCT
	RST	28H
	BIT	1,A		;Test for index pulse
	RET
;
ILLG1	POP	HL		;Fix stack
ILLEG	LD	A,32		;'illegal drv #'
	JP	IOERR
;
;
;	Messages
;
HELLO$	DB	'REPAIR'
*GET	CLIENT:3
;
ALCAO$	DB	'Repair function complete',CR
ABTJOB$	DB	'REPAIR aborted',CR
NOT0$	DB	'Can''t REPAIR drive 0',CR
PRMERR$	DB	'Parameter error',CR
BADMPW$	DB	'Invalid master password',CR
NIXHARD$	DB	'Can''t repair a hard drive',CR
;
PRMTBL$	DB	80H
STR	EQU	20H
	DB	STR!3,'MPW'
MRSP	DB	0
	DW	MPARM+1
	NOP
;
PSWDBUF	DS	8		;Password buffer
HASHBUF	DS	4		;Owner & user hashes
FCB	DS	32
	ORG	$<-8+1<+8
BUF1	DS	256
;
	END	BEGIN
