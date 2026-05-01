;LBDIRA/ASM - DIR main processing loop
	SUBTTL	'<LBDIRA - Mainline Program>'
	PAGE
;
;	error processing
;
NOMEM	LD	HL,NOMEM$
	DB	0DDH
BADFMT	LD	HL,BADFMT$
	@@LOGOT
;
ABORT	LD	HL,-1		;Set HL = -1
	JR	SAVESP		;Abort
;
;	I/O Error Routine
;
ERR32	LD	A,32		;"Illegal Drive Number"
IOERR	LD	L,A		;Set HL = Error #
	LD	H,0
	OR	0C0H		;Set short error
	LD	C,A		;Stuff in C
	@@ERROR			;Display error
	IF	@BLD631
	DB	0DDH		;<631>Make LD	IX,0000 for fall-thru HL NZ
	ELSE
	JR	SAVESP		;Abort
	ENDIF
;
;	Clear stack & Exit
;
EXIT	LD	HL,0		;Good exit
SAVESP	LD	SP,$-$		;P/u old SP address
ABORT3	@@CKBRKC		;Clear break
	RET			;Go home now
;
;	Init to 4 files/line & Drive # in string
;
DIR4	PUSH	BC		;Save drive #
	LD	A,4		;4 filespecs/line
	LD	(DONAM9+1),A	;Save
	LD	B,C		;Set for drive date type
	INC	B		;Always do once
	LD	A,47H-8		;Bit x,A opcode
DVTLP	ADD	A,8
	DJNZ	DVTLP
	LD	(DVTEST),A	;Save for unpack routine
	LD	(DVTEST1),A	; and display code
	LD	A,C		;P/u drive #
	ADD	A,'0'		;Convert to ASCII
	LD	(DRIVE),A	;  & stuff in message
	LD	(NDRIVE),A	;Also stuff in No Disk
;
;	Is the starting Drive available ?
;
	@@GTDCT			;IY => DCT+0
	@@CKDRV			;Drive alive ?
	PUSH	AF		;Save RETurn condition
	CALL	CKPAWS		;<BREAK> hit ?
	POP	AF		;NZ - couldn't log drive
	JR	Z,GDCKDRV	;Z - Logged drive succ
;
;	Is this Drive enabled ?
;
	LD	A,(IY)		;P/u Enable/Disable byte
	CP	0C3H		;Enabled ?
	JR	Z,NO_DISK	;Yes - display No Disk
;
;	If this is not global - Illegal Drive #
;
	LD	A,(SPECIF+1)	;Specific drive # ?
	OR	A		;
	JP	Z,ERR32		;Yes - illegal drive #
	JR	NEXTDRV		;No - get next drive
;
;	Enabled Drive - Display "No Disk" string
;
NO_DISK	LD	(NOTITLE+1),A	;Turn off title
	CALL	CKPAGE		;Check for scroll
	LD	HL,NODISK	;HL => "No Disk" string
	CALL	LINOUT		;Display line
	CALL	CKPAGE		;Check for scroll
	XOR	A		;Turn on Title
	LD	(NOTITLE+1),A	;
;
NEXTDRV	JP	CKHIT4		;Get next drive
;
;	Calculate quantity of Sectors/Gran
;
GDCKDRV	PUSH	BC		;Save Drive #
	LD	A,(IY+8)	;P/u # Sectors/Gran
	AND	1FH		;Mask off junk
	INC	A		;Bump for zero offset
	LD	(CALCK1+1),A	;Stuff it
;
;	P/u # Cylinders from DCT & stuff in string
;
	LD	L,(IY+6)	;P/u cyl count
	INC	L		;Offset from 0
	LD	H,0		;Stuff in HL
	LD	DE,CYLCNT-2	;DE => Destination
	@@HEXDEC
;
;	Create "DDEN" String or "HARD" string
;
	LD	DE,DENSITY	;Destination
	LD	HL,DEN
	LD	A,'D'
	BIT	6,(IY+3)	;Ck density
	JR	NZ,DUBDEN
	LD	A,'S'
DUBDEN	LD	(HL),A
	LD	BC,4		;4 chars to Xfer
	BIT	3,(IY+3)	;Hard Drive ?
	JR	Z,DOLDIR
	LD	HL,HARD		;HL => "HARD"
DOLDIR	LDIR			;Xfer string
;
;	Drive logged in - Read in GAT
;
	POP	BC		;Recover Drive #
	LD	HL,GAT		;HL => GAT buffer
	LD	D,(IY+9)	;D = Directory Cyl
	IF	@BLD631
	LD	E,L		;<631>E = L = 0 = GAT Sector
	ELSE
	LD	E,0		;E = Gat Sector
	ENDIF
	@@RDSSC			;Read Sector
	LD	A,20		;Init "GAT Read Error"
	JP	NZ,IOERR
	CALL	CKPAWS		;<BREAK> hit ?
;
;
;	Calculate the FREE space on the disk
;
;
	LD	DE,0		;DE = Gran count
	LD	L,0CCH		;HL => GAT + X'CC'
	LD	A,(HL)		;P/u excess cyl byte
	ADD	A,35		;Cyl excess of 35
	LD	B,A		;Set loop counter
	LD	L,D		;HL => GAT + X'00'
	PUSH	BC		;Save cyl count in B
;
;	HL => GAT, B = # of cyls, DE = Gran count
;
FS1	LD	A,(HL)		;P/u a GAT byte & set
FS2	SCF			;Carry so bit 7 stays 1
;
;	Is the granule in use ?
;
	RRA			;Shift gran bit -> carry
	JR	C,FS3		;Don't inc if in use
;
;	Free Granule - bump Free Granule Count
;
	INC	DE		;Another spare gran
FS3	CP	0FFH		;Fin with this GAT byte?
	JR	NZ,FS2		;Loop if not
;
;	Finished with GAT byte, advance to next
;
	INC	L		;Advance to next byte
	DJNZ	FS1		;B cylinders to check
;
;	DE = Free Grans, Calculate # Grans/cyl
;
	POP	BC		;B = # of cylinders
	LD	A,(IY+8)	;P/u DCT+8
	RLCA			;Move Grans/Cyl into
	RLCA			;Bits 0-2
	RLCA
	AND	7
	INC	A		;A = Grans/Cylinder
	BIT	5,(IY+4)	;Double-bit set ?
	JR	Z,NOTDUB	;No - don't double
	ADD	A,A		;Double grans/cylinder
;
;	A = # Grans/Cyl, Calculate Total # of Grans
;
NOTDUB	LD	HL,0		;Init HL = 0
	PUSH	DE		;Save Free Grans
	LD	D,H		;Set DE = # cyls
	LD	E,B
	LD	B,A		;B = Grans/Cyl
;
;	Multiply Grans/Cyl (B) x # Cyls (DE)
;
GPCLOOP	ADD	HL,DE		;Add cylinder count
	DJNZ	GPCLOOP		;Grans/cyl times
;
;	HL = # of grans/disk, Is this a hard drive ?
;
	BIT	3,(IY+3)	;Hard Drive ?
	JR	NZ,SKIPLOC	;Yes-don't check lockout
;
;	Floppy disk - check for locked out cylinders
;
	LD	B,E		;B = cylinder count
	EX	DE,HL		;Save total cnt in DE
	LD	HL,GAT+60H	;HL => Lockout table
	LD	C,0		;C = Locked out cyl count
	PUSH	AF		;Save Grans/Cyl in A
;
;	Loop to count up Locked out cylinders in C
;
LKLOOP	LD	A,1		;Init cyl checker
	AND	(HL)		;Locked out ?
	JR	Z,GOODCYL	;No - good cylinder
	INC	C		;Bump locked out count
GOODCYL	INC	L		;Bump ptr
	DJNZ	LKLOOP		;B cylinders
;
;	Multiply Cylinders (BC) x Grans/Cyl
;
	POP	AF		;A = Grans/Cyl
	PUSH	AF		;Save it
	LD	H,B		;Init HL = 0
	LD	L,B
;
GTUSED	ADD	HL,BC		;Add cylinder count
	DEC	A		;Grans/cyl times
	JR	NZ,GTUSED
	POP	AF		;A = Grans/Cyl
;
;	Subtract # of Grans locked out from total
;
	OR	A		;Clear carry
	EX	DE,HL
	SBC	HL,DE		;HL = Grans possible
SKIPLOC	POP	DE		;Rcvr # of Free Grans
;
;	HL = # Grans possible, DE = # Grans Free
;
	PUSH	HL		;Save Grans used
	LD	HL,KFREE	;Convert Grans Free
	CALL	CALCK		;  to ASCII K & stuff
	POP	DE		;  into string.
;
;	Calculate # of K used & stuff into header
;
	LD	HL,KPOSS	;Pt to where to stuff
	CALL	CALCK		;Calculate K & stuff
;
;	Transfer Diskette Name into string buffer
;
	LD	HL,GAT+0D0H	;HL => Diskette Name
	LD	DE,NAME		;Move pack name -> header
	LD	C,8		;BC = 8 chars to xfer
	LDIR			;Xfer into buff
;
;	Clear out Date buffer
;
	LD	DE,DATBUF	;DE => Start of buffer
	LD	A,' '		;Space
	LD	B,9		;9 chars to clear
CLRLP	LD	(DE),A		;Stuff in space
	INC	DE		;Bump
	DJNZ	CLRLP
;
;	HL => Date in mm/dd/yy format - p/u month
;
	LD	A,(HL)		;P/u month
	SUB	'0'		;Convert tens to binary
	LD	C,A		;Save in C
;
;	Multiply first digit of month x 10
;
	ADD	A,A		;X 2
	ADD	A,A		;X 4
	ADD	A,C		;X 5
	ADD	A,A		;X 10
	LD	C,A		;Stuff in C
;
;	Pick up second digit of month & add to 10's
;
	INC	HL		;Bump to ones
	LD	A,(HL)		;P/u ones of month
	IF	@BLD631
	SUB	'1'		;<631>Convert to binary
	ELSE
	SUB	'0'		;Convert to binary
	ENDIF
	ADD	A,C		;A = Month (1-12)
	IF	@BLD631
	CP	12		;<631>Legal Month ?
	ELSE
	JR	Z,ILLDATE	;Abort if NO DATE
	CP	13		;Legal Month ?
	ENDIF
	JR	NC,ILLDATE	;No - illegal date
;
;	Legal Month - Mult x 3 & pt to month string
;
	LD	C,A		;Xfer month to C
	ADD	A,A		;X 2
	ADD	A,C		;X 3
	LD	C,A		;BC = offset
	PUSH	HL		;Save date pointer
	IF	@BLD631
	LD	HL,MONTBL	;<631>HL => Month String table
	ELSE
	LD	HL,MONTBL-3	;HL => Month String table
	ENDIF
	ADD	HL,BC		;HL => Month String
;
;	HL => Month String, Stuff into Buffer
;
	LD	A,'-'		;Init separator
	LD	DE,DATBUF+3	;DE => Destination
	LD	C,3		;BC = 3 chars to xfer
	LDIR			;Xfer date to buffer
	LD	(DE),A
;
;	Transfer Day (00-31) into date buffer
;
	POP	HL		;Recover ptr
	INC	HL		;Bump
	INC	HL		;HL => Day of month
	LD	DE,DATBUF	;DE => date buffer
	LD	C,2		;Xfer into buffer
	LDIR
	LD	(DE),A
;
;	Transfer Year into buffer
;
	INC	HL		;HL => Year (80-87)
	LD	C,2		;2 chars to xfer
	LD	DE,DATBUF+7	;DE => Destination
	LDIR			;Xfer into buffer
;
;	Display the files in the directory
;	Init DIR rec ptr = mem start, count = 0
;
	IF	@BLD631G
ILLDATE:LD	A,D		;<631G>Set flag
	ELSE
ILLDATE	INC	A		;Set flag
	ENDIF
	LD	(FILFLAG),A	;Set file alr disp flag
	LD	HL,MEMORY	;Init DIRPTR to start
	LD	(DIRPTR),HL	;  of available memory
	XOR	A		;Set File display
	SBC	HL,HL		;Set HL = 0
	LD	(TFILES+1),HL	;Total Files = 0
	LD	(COUNT+1),HL	;Count = 0
	LD	(TOTGRNS+1),HL	;Total Grans = 0
;
;	Read in the HIT of the disk
;
	POP	BC		;Recover Drive # in C
	LD	D,(IY+9)	;P/u directory cylinder
	LD	E,1		;Pt to HIT sector
	LD	HL,HIT		;HL => I/O buffer
	@@RDSSC			;Read System Sector
	LD	A,16H		;"HIT read error"?
	JP	NZ,IOERR	;Jump if read error
	CALL	CKPAWS		;<BREAK> hit ?
$JP0	JP	CKHIT5		;Jump into middle of loop
;
;	Loop to Process HIT entries
;
CKHIT	POP	HL
CKHIT1	POP	BC		;Recover HIT pointer lo
;
;	Point HL => Last HIT entry
;
	LD	H,HIT<-8	;Set H = hi byte of HIT
	LD	L,B		;HL => Last HIT entry
;
;	Position to next entry of the Record
;
CKHIT2	LD	A,L		;P/u current entry
	ADD	A,32		;Add 32 (bytes/entry)
	LD	L,A		;HL => Next entry
	JR	NC,$JP0		;Go to next record ?
;
;	Position to entry zero of next record
;
	INC	L		;Posn to next record
	BIT	5,L		;Done with drive ?
	JR	Z,$JP0		;No - process entry
;
;	Finished with drive - Sort data unless (O=N)
;
	LD	A,(SORTPRM+1)	;If sort requested,
	OR	A		;  then need to output
	CALL	NZ,SORTIT	;  the sorted data
;
;	Were there any files displayed ?
;
	LD	HL,(COUNT+1)	;P/u displayed file count
	LD	A,H		;Any entered ?
	OR	L
	JR	NZ,FILES	;Yes - dsp under if (A)
;
;	Display Title & line feed
;
	LD	HL,DSTRING	;HL => Title
	CALL	LINOUT		;Display title
	CALL	CKPAGE		;Check for scroll
	JR	NOTAP		;Get next drive
;
;	Get next drive # if the A parm was specified
;
FILES	LD	A,(APARM+1)	;Don't display if A
	OR	A
	JR	Z,NOTAP		;Not A - Output C/R
;
;	Were there any files shown in directory ?
;
COUNT	LD	HL,$-$		;P/u count
	LD	A,H		;Any files shown ?
	OR	L
	JR	Z,TERMDRV	;No - get next drive
;
;	Display Line of equal signs "="
;
	LD	B,79		;Output 79 "="
D79EQ	LD	A,'='
	CALL	BYTOUT		;Output "="
	DJNZ	D79EQ
;
;	End line & check for scroll
;
	IF	@BLD631
	CALL	CKPAGE1		;<631>
	ELSE
	LD	A,CR		;End line with C/R
	CALL	BYTOUT
	CALL	CKPAGE
	ENDIF
;
;	Stuff # of files used into footer string
;
	PUSH	BC		;Save Drive #
	LD	B,3		;Max digits to dsp
	LD	DE,FDISP	;DE => Destination
	@@HEXD
;
;	Pick up # of used files & stuff in string
;
TFILES	LD	HL,$-$		;P/u total files used
	LD	DE,FUSED+1	;DE => Destination
	LD	B,3
	@@HEXD
;
;	P/u Total # of Grans & stuff into string
;
TOTGRNS	LD	DE,$-$		;P/u total # of Grans
	LD	HL,SPUSED	;HL => Destination
	CALL	CALCK		;Stuff into string
	LD	B,19
	CALL	OUTSPC
	POP	BC		;C = drive #
;
;	Display Footer String
;
	LD	HL,FDISP	;HL => Files disp string
	CALL	LINOUT		;Display line
	CALL	CKPAGE		;Check for title
	CALL	CKPAGE
	JR	TERMDRV		;Get next drive
;
;	A parm not spec'd, was a header displayed ?
;
NOTAP	LD	A,(FILFLAG)	;Was a header displayed ?
	OR	A
	JR	NZ,TERMDRV	;No - get next drive
;
;	Output a C/R if a full line wasn't displayed
;
	LD	A,(DONAM9+1)	;Full line ?
	CP	4
	CALL	NZ,ENDLINE	;End line
	CALL	ENDLINE		;Do a blank line
;
;	Position to next drive - or exit if finished
;
TERMDRV	LD	A,$-$		;P/u term drive
	INC	C		;Bump current drive #
	CP	C		;Done ?
	IF	@BLD631E
TODIR4:				;<631E>
	ENDIF
	JP	NC,DIR4		;Loop if in range
	JP	EXIT		;Exit if NZ
;
;	Get next drive unless drivespec specified
;
CKHIT4	POP	BC		;Get drive # in C
SPECIF	LD	A,$-$		;P/u specific flag
	OR	A
	IF	@BLD631
	IF	@BLD631E
	LD	HL,0		;<631E>Put it back the way it was B4 631
	ELSE
	LD	H,A		;<631>Init in case exit
	LD	L,A		;<631>A will equal zero in this case so HL=0
	ENDIF			;<631E>
	ELSE
	LD	HL,0		;Init in case exit
	ENDIF
	RET	Z		;Not global
;
;	Bump Drive number
;
	LD	A,(TERMDRV+1)	;P/u term drive #
	INC	C		;Bump
	CP	C		;Finished ?
	IF	@BLD631E
	JR	NC,TODIR4	;<631>Loop if more
	ELSE
	JP	NC,DIR4		;Loop if more
	ENDIF
	RET			;  else return
;
;	Is the HIT entry in use ?
;
CKHIT5	LD	A,(HL)		;P/u HIT entry
	OR	A		;In use ?
	JP	Z,CKHIT2	;No - get next entry
;
;	HIT entry in use - Point HL to that entry
;
	LD	B,L		;Save DEC in B
	PUSH	BC		;  & to stack
	LD	A,L		;Point L to Entry posn
	AND	0E0H
	LD	L,A
;
;	Do we need to Read in another sector ?
;
	XOR	B		;Done with 8 entries ?
CKHIT6	CP	0FFH
	JR	Z,CKDIR1	;No - check out entry
;
;	Read in the next directory sector
;
	LD	(CKHIT6+1),A	;Stuff in last entry posn
	@@DIRRD			;  & read it into buffer
	JP	NZ,IOERR	;Jump on read error
	LD	A,H		;P/u high byte
	LD	(CKDIR1+1),A	;  and save
	LD	(SBUFFER+1),A	;  for later
;
;	Valid File (Alive & FPDE) ?
;
CKDIR1	LD	H,$-$		;P/u high byte
	BIT	4,(HL)		;Alive ?
	JP	Z,CKHIT1	;No - get next entry
	BIT	7,(HL)		;FPDE ?
	JP	NZ,CKHIT1	;No - get next entry
;
;	Alive FPDE - Bump Total File counter
;
	PUSH	HL		;Save ptr
	LD	HL,(TFILES+1)	;HL => Total Files
	INC	HL		;Bump total files
	LD	(TFILES+1),HL
	POP	HL
;
;	Is this a SYStem File ?
;
	BIT	6,(HL)		;SYS file ?
	JR	Z,CKDIR3	;No - continue
;
;	SYS file - don't check unless S parm entered
;
SPARM	LD	DE,$-$		;P/u S-parm
	LD	A,D		;Specified ?
	OR	E
	JP	Z,CKHIT1	;No - don't check it
	JR	CKMOD		;Skip INV check
;
;	Non-SYS file - Is the file Visible ?
;
CKDIR3	BIT	3,(HL)		;Visible ?
	JR	Z,CKMOD		;Yes - skip I check
;
;	File is invisible - was INV (I) specified ?
;
IPARM	LD	DE,$-$		;I-parm
	LD	A,D		;Ignore if I-parm not
	OR	E		;  entered as this file
	JP	Z,CKHIT1	;  is invisible
;
;	Was the MOD parm entered ?
;
CKMOD	LD	DE,$-$		;P/u mod parm
	LD	A,D		;Was it entered ?
	OR	E
	JR	Z,CKNAM		;Go if MOD not entered
;
;	MOD parm entered - was this file modified ?
;
	INC	L		;HL => DIR + 1
	BIT	6,(HL)		;Was the file modified ?
	JP	Z,CKHIT1	;No - get next entry
	DEC	L		;Adjust back to start
;
;	Attributes match - check if filespec matches
;
CKNAM	PUSH	HL		;Save ptr to record
	LD	A,L		;Pt to filename in dir
	ADD	A,5
	LD	L,A		;HL => DIR filename
	LD	DE,BLANKS	;DE => Partspec input
	LD	B,11		;Ck name/ext (11-chars)
;
;	Loop to check if partspec matches dir name
;
CKNAM1	LD	A,(DE)		;P/u partspec
	CP	'$'		;Wild char?
	JR	Z,CKNAM2	;Yes - match
;
;	Does Directory char match partspec char ?
;
	CP	(HL)		;Not global, char match?
	JR	Z,CKNAM2	;Ck more if match
;
;	Chars don't match - Dir char a space ?
;
	CP	' '		;Blank = end of ck
	JR	NZ,MFLG		;If not blank, no match
;
;	Bump Dir ptr & Partspec ptr & continue loop
;
CKNAM2	INC	HL		;Bump pointers
	INC	DE
	DJNZ	CKNAM1		;Loop for 11 chars
;
;	Entries Match - Was the "-" Exclude given ?
;
	LD	A,(MFLG+1)	;P/u flag
	CP	'-'		; - exclude given ?
	JR	CK2HIT		;Yes - get next entry
;
;	Entries Don't match - Was exclude given ?
;
MFLG	LD	A,$-$		;P/u Exclude flag
	OR	A		;If no exclude given
CK2HIT	JP	Z,CKHIT		;  get next entry
;
;	Recover DIR+0 pointer
;
CKNAM2A	POP	HL		;Rcvr ptr to DIR+0
	PUSH	HL		;Save
;
;	Unpack Date of Directory entry
;
	INC	HL		;HL => DIR+1
	CALL	UNPACK		;Unpack date
;
;	Use Dates before user-specified date ?
;
	LD	A,(FTFLG)	;P/u From/To flag
	RLCA			;Tst fm bit
	JR	NC,CKNAM2B	;No - check to
;
;	"FROM" flag set - does file have a date ?
;
	LD	A,D		;Ignore if no date
	OR	E		;  in DIR for file
	JP	Z,CKHIT		;No date - get next entry
;
;	Is the Specified date >= the file's date ?
;
	LD	HL,(FMPAKD)	;P/u user date entry
	EX	DE,HL
	CALL	CPHLDE		;Compare HL to DE
	EX	DE,HL		;File date < User date ?
	JR	C,$JP1		;Yes - get next entry
;
;	Use Dates after user-specified Date ?
;
CKNAM2B	LD	A,(FTFLG)	;P/u FROM/TO flag
	RRCA			;Test TO bit
	JR	NC,SORTPRM	;Go if no TOPARM
;
;	"TO" Flag set - Does file have a date ?
;
	LD	A,D		;File have a valid date ?
	OR	E
	JP	Z,CKHIT		;No - get next entry
;
;	File has a date - Is spec'd date less ?
;
	LD	HL,(TOPAKD)	;P/u user's packed date
	CALL	CPHLDE		;User date < File date ?
$JP1	JP	C,CKHIT		;Yes - get next entry
;
;	Was the Sort Parameter turned off ?
;
SORTPRM	LD	DE,-1		;P/u default parm
	POP	HL		;HL => DIR+0
	LD	A,D		;Default to SORT=ON
	OR	E
	JR	Z,DODSP		;Go display if no sort
;
;	SORT = ON --- Calculate allocation & extents
;
	PUSH	HL		;Save DIR + 0 ptr
	CALL	ALL09A		;Calc alloc & extents
	POP	HL		;Recover DIR+0 ptr
;
;	Overwrite FPDE's 22-25 with # Grans & # exts
;
	PUSH	HL		;Point IX = DIR+22
	POP	IX
	LD	(IX+22),E	;Stuff in # Grans
	LD	(IX+23),D
	LD	(IX+24),C	;Stuff in # Extents
	LD	(IX+25),B
;
;	Transfer Record into Memory For Sort
;
	LD	DE,(DIRPTR)	;P/u last used mem addr
	PUSH	HL		;Save current DIR ptr
	LD	BC,32		;Move record to buffer
	LDIR			;Xfer
	LD	(DIRPTR),DE	;Update the pointer
;
;	Is there an overflow of available memory ?
;
	LD	HL,(MAXMEM)	;P/u approximate hi-mem
	SBC	HL,DE		;Did it overflow ?
	JP	NC,CKHIT	;No - get next entry
	JP	NOMEM		;Insuf mem for sort buff
;
;	Display A Filename
;
DODSP	CALL	MATCH		;Display entry
	JP	CKHIT1		;Loop to next DIR entry
