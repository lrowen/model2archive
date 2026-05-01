;MEMDISKA/ASM - Memdisk Initialization
	SUBTTL	'<MEMDISKA - Installation>'
	PAGE
;
INSTMEM	PUSH	AF		;Save # cyls
	PUSH	BC		;Save Bank #
;
;	Is there a MemDISK driver trapped ?
;
	LD	DE,MD$		;"$MD"
	@@GTMOD			;MemDISK in ?
	JR	NZ,NOT__IN	;No
;
;	There is a driver trapped - use that area
;
	LD	(OLDRVR+1),HL	;Save old driver addr
	EX	DE,HL		;Pt DE => Destination
	LD	HL,RE_USE	;Set re-use flag
	INC	(HL)
	LD	HL,LENGTH-1	;Set HL = last used
	ADD	HL,DE		;  address of driver
	LD	(OLDHIGH),HL	;Xfer into driver
	JR	DO_INST		;Install driver
;
;	Driver is not in memory - is there room ?
;
NOT__IN	CALL	GTDRV		;P/u low driver ptr
	LD	(OLDRVR+1),DE	;Save it
	LD	HL,LENGTH-1	;HL = length of driver
	LD	BC,HIDRVR	;BC = 1 + highest avail
	ADD	HL,DE		;HL => Last used by Mem
	LD	(OLDHIGH),HL
	INC	HL
	OR	A
	PUSH	HL		;Will MemDisk fit ?
	SBC	HL,BC
	POP	HL
	JR	C,OKTOGO	;Yes - let's do it
;
;	Insufficient Driver space
;
	LD	HL,NOMEM	;Alter exit message
	LD	($NOT+1),HL
	JR	OLDRVR		;Reclaim hi mem if bank 0
;
;	Save next avail mem addr & set Memdisk bit
;
OKTOGO	LD	(IX),H		;Stuff msb
	LD	(IX-1),L	;Stuff lsb
;
;	Install MemDISK driver & set up DCT
;
DO_INST	CALL	INSTDRV		;Relocate, install driver
	POP	BC		;C = Bank # requests
	POP	AF		;A = # cylinders
	CALL	SETDCT		;Set up DCT
;
;	Prompt for Format
;
	CALL	FORMTIT		;Format this ?
	JR	Z,DOFORM1	;Yes - do it
;
;	Format = No, Is there a MemDISK here ?
;
MEMIN1	LD	A,$-$		;0 = not active
	OR	A		;
	JR	NZ,SHOWINU	;MemDisk previously in
;
;	Abort installation - stuff X'C9' in DCT
;
OLDRVR	LD	HL,$-$		;P/u original driver addr
	LD	A,(RE_USE)	;Have we re-used driver
	OR	A		;  area that was trapped ?
	JR	NZ,DONTRES	;Yes - don't reset memptr
KIDCB$	LD	($-$),HL	;Stuff ptr used
DONTRES	LD	HL,(SAVEDCT)	;P/u DCT address
	LD	(HL),0C9H	;Disable it
	RES	4,(IY+DFLAG$)	;Reset MemDISK bit
	LD	A,(SETBANK+1)	;P/u bank request
	OR	A		;If alternate bank(s),
	JR	NZ,$NOT		;  don't reset high$
	LD	HL,(MDDATA+2)	;Pu old high$
	LD	B,A
	@@HIGH$			;Reset high$
$NOT	JP	NOTACT		;Show not installed
;
;	Format mem, init GAT & HIT, & BOOT-DIR entries
;
DOFORM1	CALL	FORMAT		;Format
	CALL	WRBOOT		;Write BOOT/SYS
	CALL	WRGAT		;Initialize GAT
	CALL	WRHIT		;Initialize HIT
	CALL	WRENT		;Put DIR & BOOT entries
SHOWINU	CALL	SETBANK		;Show Banks in use
	SET	4,(IY+DFLAG$)	;Set MemDisk flag
	LD	HL,INSTALD	;Init"MemDisk Installed
	@@LOGOT			;Display the msg
	RET			;Done - GO TO EXIT
;
;	WRBOOT - Write BOOT/SYS information
;
WRBOOT	XOR	A		;Fill byte
	LD	HL,IOBUFF	;HL => I/O buffer
;
;	Fill BOOT/SYS with Zeroes
;
FILBUF	LD	(HL),A		;Stuff in byte
	INC	L		;One sector to
	JR	NZ,FILBUF	;  fill
;
;	Write # of Sectors in BOOT
;
	LD	D,A		;Cylinder 0
	LD	E,A		;Sector 0
BTSECS	LD	B,6		;P/u Sec cnt - 5,6, or 18
BTLP	CALL	WRSEC		;Write sector
	INC	E		;Bump
	DJNZ	BTLP
;
;	Write Directory Cylinder byte in Sector Zero
;
	LD	L,2		;Byte 2
	LD	(HL),1		;Directory cyl = 1
;
;	Write Sector 0 of Cylinder 0
;
	LD	DE,0		;Cylinder 0, Sector 0
	CALL	WRSEC		;Write Sector
;
;	Make a duplicate of sector 0 in sector 1
;
	INC	E		;Sector 1
	CALL	WRSEC		;Write sector
;
;	Write C/R in Auto Buffer in Sector 2
;
	LD	E,2		;Sector 2
	LD	L,20H		;Byte X'20'
	LD	(HL),CR		;No auto
	CALL	WRSEC		;Write sector
	RET			;RETurn for now
;
;	WRGAT - Write Granule Allocation Table
;
;
WRGAT	LD	HL,IOBUFF	;HL => I/O buffer
GAT0	LD	(HL),0F9H	;DD - X'F9', SD - X'FD'
	INC	HL		;Bump
;
;	Lock out next X'CA' bytes in GAT
;
	LD	B,0CAH		;Lock out the bytes
LOCKOUT	LD	(HL),0FFH	;GAT + X'01' through
	INC	HL		;GAT + X'CA'
	DJNZ	LOCKOUT
;
;	GAT + X'CB'
;
	LD	(HL),63H	;GAT + X'CB'= Version 6.2
;
;	GAT + X'CC'
;
CYLS	LD	A,$-$		;P/u cylinder count
	PUSH	AF		;Save Cylinder count
	SUB	35		;Tracks in excess of 35
	INC	HL		;HL => next GAT byte
	LD	(HL),A		;GAT + X'CC'= tracks - 35
;
;	GAT + X'CD'
;
	INC	HL		;GAT + X'CD' =
GATCD	LD	(HL),4AH	;DDEN, 1 side, 3 gran/cyl
;
;	GAT + X'CE' & X'CF'
;
	INC	HL		;GAT + X'CE' & X'CF' =
	LD	(HL),0E0H	;16-bit Hash code of
	INC	HL		;"PASSWORD"
	LD	(HL),42H	;Hash = X'42E0'
;
;	GAT + X'D0' - X'D7'
;
	INC	HL		;HL => next GAT byte
	LD	DE,MEMDISK	;"MEMDISK " is Pack name
	LD	C,8		;Eight bytes
	EX	DE,HL		;Swap 'em for LDIR
	LDIR			;Stuff in ID
	EX	DE,HL		;HL => GAT + X'D8'
;
;	GAT + X'D8' - X'DF'
;
	@@DATE			;Stuff date in GAT
;
;	Stuff GAT tracks in use with either X'F8' or X'FC'
;
GPC	LD	A,0F8H		;3 gran/cyl
	LD	HL,IOBUFF+2	;HL => GAT + X'02'
	POP	BC		;B = # cylinders
	DEC	B		;Subtract 2 to account
	DEC	B		;For BOOT and DIR
;
;	Stuff open cylinder bytes into GAT
;
FREETRK	LD	(HL),A		;Free track
	INC	HL		;Next GAT byte
	DJNZ	FREETRK		;Do it B times
;
;	Put 2 free Cyl bytes in lockout - BOOT & DIR
;
	LD	L,60H		;HL => Lockout
	LD	(HL),A
	INC	L
	LD	(HL),A
;
;	GAT + X'62' - GAT + X'BF'
;
	LD	L,2		;HL => GAT + X'02'
	LD	D,H		;Xfer to DE
	LD	E,L
	LD	C,60H		;Of X'60' for the
	ADD	HL,BC		;  duplicate of top
	DEC	C		;Only duplicate X'5E'
	DEC	C		;  bytes
	EX	DE,HL		;Prepare for LDIR
	LDIR			;HL => GAT, DE => Lockout
;
	LD	DE,IOBUFF+255-10	;6.2 Media Data Block
	LD	HL,LSIID	;Point to header
	LD	BC,04		;Set length
	LDIR			;Move it
	LD	HL,(SAVEDCT)	;The data to move
	INC	HL
	INC	HL
	INC	HL
	LD	C,7		;Bytes to move
	LDIR			;Move it in
	JR	WRGAT1		;Skip around string
	IF	@BLD631
LSIID	DB	03,'631'	;<631>
	ELSE
LSIID	DB	03,'LSI'
	ENDIF
;
WRGAT1	LD	DE,100H		;D = Cyl 1, E = Sector 0
;
;	WRSEC - Write A sector to MemDISK drive
;
WRSEC	LD	HL,IOBUFF	;I/O buffer
DRIVE	LD	C,$-$		;P/u drive #
	@@WRSEC			;Write Sector
	RET			;  and RETurn
;
;	RDSEC - Read A sector of MemDISK drive
;
RDSEC	LD	HL,IOBUFF	;HL => I/O Buffer
	LD	A,(DRIVE+1)	;P/u drive #
	LD	C,A		;Xfer to C
	@@RDSEC			;Read sector
	RET			;  and RETurn
;
;	WRHIT - Write HIT sector in directory
;
WRHIT	XOR	A		;Set A = 0
ZEROHIT	LD	(HL),A		;Zero HIT position
	INC	L		;Bump HIT pointer
	JR	NZ,ZEROHIT	;256 positions
	LD	(HL),0A2H	;Hash for BOOT/SYS
	INC	L		;HL => HIT + X'01'
	LD	(HL),0C4H	;Hash for DIR/SYS
	INC	E		;D = Cyl 1, Sector 1
	JR	WRSEC		;Write Sector & RETurn
;
;	WRENT - Write DIR/SYS & BOOT/SYS entries
;
WRENT	LD	DE,BOOT		;BOOT/SYS byte field
	EX	DE,HL		;Swap for LDIR
	LD	BC,32		;32 bytes in entry
	LDIR			;Block move
	LD	DE,102H		;D = Cyl 1, E = Sector 2
	CALL	WRSEC		;Write Sector
;
	LD	BC,32
	EX	DE,HL		;Xfer buffer ptr to DE
	LD	HL,DIR		;HL => DIR/SYS bytes
	LDIR			;Xfer to MemDISK
	LD	DE,103H		;D = Cyl 1, E = Sector 3
	JR	WRSEC		;Write sector & RETurn
;
;	BOOT/SYS directory entry data
;
BOOT	DB	01011110B	;No access,inv,sys,FPDE
	DW	0		;Date = 00/00/00
	DW	0		;EOF offset = 0, LRL=256
	DB	'BOOT    '	;Name field
	DB	'SYS'		;Extension
	IF	@BLD631E
	DW	071F4H		;<631E>Owner password hash
	ELSE
	DW	037F6H		;Owner password hash
	ENDIF
	DW	0		;User password hash
BOOTERN	DW	6		;ERN = 6 or 5
	DB	0		;First extent = Cyl 0
BOOTGRN	DB	0		;St gran = 0, 1 cont gran
	DW	0FFFFH		;No more extents
	DW	0FFFFH
	DW	0FFFFH
	DW	0FFFFH
;
;	DIR/SYS directory entry data
;
DIR	DB	01011101B	;Read only,inv,sys,FPDE
	DW	0		;Date= 00/00/00
	DW	0		;EOF offset=0, LRL=256
	DB	'DIR     '	;Name field
	DB	'SYS'		;Extension
	IF	@BLD631E
	DW	071F4H		;<631E>Owner password hash
	ELSE
	DW	037F6H		;Owner password hash
	ENDIF
	DW	04296H		;User password hash
DIRERN	DW	18		;ERN+1 = 10 or 18
	DB	1		;Starts on cylinder 1
SDENI	DB	00000010B	;St. gran=0, 3 cont grans
	DW	0FFFFH		;No Second Extent
	DW	0FFFFH		;No Third Extent
	DW	0FFFFH		;No Fourth Extent
	DB	0FFH		;No further records
	DB	0FFH
;
;	DOMEM - Issue Prompts & take inputs for type
;
DOMEM	LD	HL,HELLO$	;Display message
	@@DSPLY
;
;	Check if entry from SYSTEM (DRIVER= command
;
	@@FLAGS
	BIT	3,(IY+'C'-'A')	;System request?
	JP	Z,VIASET	;Quit if not
;
;	Input MemDISK type - A,B,C,D or E to disable
;
GETYPE	LD	HL,BANKS	;Display prompt
	@@DSPLY
	LD	B,1		;# of chars to input
	CALL	INPUT		;Input byte
	JR	Z,GETYPE	;<ENTER> ? - re-input
;
;	Convert input A-E to 0-4
;
	LD	A,(HL)		;P/u first character
	RES	5,A		;Convert to U/C
	SUB	'A'		;<A> - Bank 0 ?
	LD	(SETBANK+1),A	;Save type of MemDISK
	LD	C,A		;Xfer to C for @BANK
;
;	If input is illegal then re-input
;
	JR	C,GETYPE	;Less - re-input
	CP	4		;<E> - Disable MemDISK
	JP	Z,DISMEM	;Yes - take it out
	JR	NC,GETYPE	;>4 - Re-input
;
;	Check if MemDISK is already active
;
	BIT	4,(IY+DFLAG$)	;MemDISK already active ?
	JP	NZ,MEMIN	;Yes - abort
;
;	If Type A,B,C - Check Bk, D - Check bks 1&2
;
	PUSH	BC		;Save Bank #
	CP	3		;Type "D" ?
	JR	NZ,A_B_C	;No - "A", "B", or "C"
;
;	Type "D" - See if both banks 1 & 2 are avail
;
TYPED	LD	C,1		;Bank #1 active ?
	CALL	CKBANK
	INC	C		;Bank #2 active ?
A_B_C	CALL	CKBANK
	POP	BC		;C = Bank # (0,1,2,3)
;
;	Stuff Default Bank # and offset into driver
;
	LD	A,C		;P/u bank #
	DEC	A		;If bank 0 requested,
	JP	M,WAS0		;  then keep as -1
	INC	A		;  for driver bank test
	LD	(BANKIM),A	;Save bank # in driver
	CP	2		;Instruction if
	JR	NZ,NOT2		;Just bank #2 active
	LD	HL,OFFSET+1	;Stuff X'80' in ADD
	LD	(HL),80H
NOT2	LD	A,1		;Always init to bank 1
				;  if type B, C or D
WAS0	LD	(DEFBANK+1),A	;Stuff in driver
;
;	Input Density (Single or Double)
;
INPDENS	LD	HL,DENSITY	;"Density"
	@@DSPLY
	LD	B,1		;Input an "S" or "D"
	CALL	INPUT
	JR	Z,DEFAULT	;<ENTER> - use default
;
;	<D>ouble Density input ?
;
	LD	A,(HL)		;P/u first char
	RES	5,A		;Convert to U/C
	CP	'D'		;<D>ouble Density ?
	JR	Z,DEFAULT	;Yes - use 6 sectors/gran
;
;	<S>ingle Density input ?
;
	CP	'S'		;<S>ingle Density ?
	JR	NZ,INPDENS	;No - input density again
;
;	Single Density - Change driver math
;
	LD	A,82H		;ADD A,D instruction
	LD	(SDENB),A
	LD	A,87H		;ADD A,A instruction
	LD	(SDENC),A
	LD	A,9
	LD	(SDENF+3),A	;DCT + 7
	LD	(SPC+1),A	;Save in CALCSIZ routine
	INC	A		;SDEN BOOT ERN = 10
	LD	(DIRERN),A	;SDEN DIR/SYS ERN = 10
	LD	A,24H
	LD	(SDENG+3),A	;DCT + 8
	LD	A,'2'		;Change size to 2.50K
	LD	(FRTRK1),A	;Space per cylinder
	LD	A,0FDH		;1 Gran Free
	LD	(GAT0+1),A	;Stuff in WRGAT routine
	DEC	A		;2 Grans/Cyl - X'FC'
	LD	(GPC+1),A
	XOR	A		;NOP instruction
	LD	(SDENA),A
	LD	(SDEND+3),A	;DCT + 3
	INC	A		;Set A = 1
	LD	(SDENI),A	;2 contiguous granules
	LD	A,9
	LD	(GATCD+1),A
	LD	A,5		;Set Boot ERN = 5
	LD	(BOOTERN),A
	LD	A,10H		;Alien Disk Controller
	LD	(SDENE+3),A
	LD	HL,BTSECS+1	;HL => # BOOT sectors
	DEC	(HL)		;Use 5 instead of 6
	LD	HL,SDBPC	;Change GETCYL routine
	LD	(BPC+1),HL
;
;	Calculate # of possible cylinders
;
DEFAULT	LD	A,(SETBANK+1)	;P/u type of memdisk
	LD	C,A		;Save in C
	OR	A		;Bank 0 ?
	JR	Z,PIKUPHI	;Yes - use HIGH$
;
;	Bank #1, #2, or #1 & #2
;
	LD	HL,7FFFH	;HL = # bytes in 1 bank
	CP	3		;Bank 1 & 2 ?
	JR	NZ,CALCYL	;No - use X'7FFF'
	LD	H,L		;Set HL = X'FFFF'
	JR	CALCYL
;
;	Bank Zero request - calculate free mem avail
;
PIKUPHI	XOR	A		;Set A = 0
	SBC	HL,HL		;HL = 0
	LD	B,A		;B = 0
	@@HIGH$			;P/u HIGH$
	LD	(MDDATA+2),HL	;Save HIGH$
	LD	(OLD_HI),HL	;Save HIGH$ in driver
	INC	HL		;Set HL = last page
	DEC	H
	LD	L,A
	LD	(SAVPAGE+1),HL	;Save page boundary
	LD	DE,LOWEST	;DE = lowest
	XOR	A
	SBC	HL,DE		;HL = amount free
	JP	C,NOMEM		;Carry - not enough mem
;
;	Calculate # of cylinders available
;
CALCYL	CALL	GETCYL		;Get # of poss cyls
	JP	NZ,NOMEM	;NZ - Not enough mem
;
;	Convert A to ASCII & stuff into string
;
	INC	A		;Bump one
	LD	(MAXCYL+1),A	;Save max # of cyls
	DEC	A
	LD	(CYLS+1),A	;Stuff in WRGAT routine
	PUSH	AF		;Save Max # of cyls
	CALL	DECASC		;Convert to ASCII in HL
	POP	AF		;A = # cyls
	EX	DE,HL		;DE = #
	LD	HL,FRTRK2	;HL => Destination
	LD	(HL),D		;Msb
	INC	HL
	LD	(HL),E		;Lsb
;
;	A = # of Cyls poss, put in string if bank 0
;
	INC	C		;Bank Zero request ?
	DEC	C
	RET	NZ		;No - done prompting
;
;	Display Cylinders string & input # of cyls
;
REDO	LD	HL,FRTRACK	;How many cylinders
	@@DSPLY
	LD	B,2		;Input # of cyls
	CALL	INPUT
	JR	Z,REDO		;Reinput it
;
;	Check if input legal
;
	CALL	DECHEX		;Convert # to Hex
	JR	NZ,REDO		;Illegal - Re-input
	CP	MINCYL		;Less than minimum?
	JR	C,REDO
MAXCYL	CP	$-$		;P/u max # of cyls
	JR	NC,REDO		;Too many - reinput
	LD	(CYLS+1),A	;New # of cylinders
;
;	CALCSIZ - Calculate Size of Cyl request
;
CALCSIZ	CALL	SAVEREG		;Save Registers
	LD	C,A		;Xfer # cyls to C
SPC	LD	B,17		;P/u Sectors/Cyl
;
;	Multiply Sectors per Cylinder x # Cylinders
;
MLOOP	ADD	A,C		;Multiply B x C
	DJNZ	MLOOP
;
;	Set HL = New HIGH$
;
SAVPAGE	LD	HL,$-$		;P/u page boundary
	NEG			;Set H = H - A
	ADD	A,H
	LD	H,A		;HL = New HIGH$, B = 0
	LD	(OFFSET+1),A	;Stuff into driver
;
;	Stuff a Memory Header on front of MemDISK
;
	DEC	HL		;Pt 1 byte before
	EX	DE,HL		;  Memdisk himem area
	LD	HL,MDDATA+16	;Pt to header block
	LD	BC,17
	LDDR			;  and move it to himem
	EX	DE,HL
	LD	(MEMHIGH),HL
	@@HIGH$			;Install new HIGH$
	RET			;Restore Regs & RETurn
;
;	DISMEM - Disable MemDISK if in memory
;
DISMEM	BIT	4,(IY+DFLAG$)	;MemDISK active ?
	JP	Z,NOTPRS	;No - display error mess
;
;	Pick up Driver address of drive
;
	LD	HL,(SAVEDCT)	;P/u DCT address
	PUSH	HL		;Save DCT ptr
	INC	HL		;P/u driver address
	LD	E,(HL)		;Lsb
	INC	HL
	LD	D,(HL)		;Msb
	PUSH	DE		;Save Driver Address
;
;	Calculate end of driver & Posn to ID
;
	EX	DE,HL		;Pt HL to driver
	PUSH	HL		;Save driver start
	LD	BC,LENGTH	;Add length of driver
	ADD	HL,BC		;  to start of driver.
	LD	(DREND+1),HL	;Save next available
	POP	HL		;HL => driver add start
	INC	HL		;Pos'n to length byte
	INC	HL
	INC	HL
	INC	HL
;
;	P/u length byte & pt to driver name
;
	LD	B,(HL)		;P/u length byte
	INC	HL		;HL => Driver Name
	LD	DE,MD$		;DE => MEMDISK
;
;	Is this REALLY a certified MemDISK ??
;
MEMLP	LD	A,(DE)		;P/u MemDISK byte
	CP	(HL)		;Match ?
	INC	HL		;Bump driver ptr
	INC	DE		;Bump string ptr
	JP	NZ,NOTMEM	;No - isn't a MemDISK
	DJNZ	MEMLP		;Yes - check all posns
;
;	Pick up Old HIGH$ address & stuff for later
;
	LD	E,(HL)		;P/u old HIGH$
	INC	HL
	LD	D,(HL)
	LD	(SAVEOLD+1),DE	;Stuff into LD HL inst
;
;	P/u BANK information
;
	RES	4,(IY+DFLAG$)	;Reset MemDISK bit
	INC	HL		;HL => Bank image
	LD	A,(HL)		;P/u bank image
	LD	C,A		;Xfer to C
	CP	3		;Both banks 1 & 2 ?
	JR	C,FRBANK	;No - free up bank
	DEC	C		;Set C = 2
	CALL	FREBANK		;Free bank #2
	DEC	C		;Set C = 1
FRBANK	CALL	FREBANK		;Free Bank in C
;
;	Is this a Bank Zero MemDISK ?
;
	LD	IY,TYPEDIS	;IY => Disable Type
	INC	C		;Is C = 0 ?
	DEC	C
	JR	NZ,GTDRV2	;No - check out driver
;
;	Bank 0 - p/u last HIGH$ from Driver storage
;
	DEC	(IY)		;Change type
	INC	HL		;Pos to HI$ val after
	INC	HL		;  MemDISK installation.
	INC	HL
	LD	E,(HL)		;P/u address
	INC	HL
	LD	D,(HL)
;
;	Pick up Current HIGH$ & compare with other
;
	LD	H,B		;Set HL = 0
	LD	L,B
	@@HIGH$			;(B=0), p/u HIGH$
	OR	A		;Same ?
	SBC	HL,DE
	JR	NZ,GTDRV2	;NZ - Can't do it
;
;	Reset HIGH$ = original HIGH$
;
SAVEOLD	LD	HL,$-$		;P/u old HIGH$
	@@HIGH$			;Re-allocate space
	INC	(IY)		;Change Type
;
;	Can the Driver area be re-allocated ?
;
GTDRV2	CALL	GTDRV		;Get driver area
DREND	LD	HL,$-$		;P/u driver address
	OR	A
	SBC	HL,DE		;Same ?
	POP	HL		;HL => Driver Address
	JR	NZ,NORECLM	;No - can't Reclaim
;
;	Stuff original Address into low driver ptr
;
	LD	(IX),H		;Msb
	LD	(IX-1),L	;Lsb
	INC	(IY)		;Change type
	INC	(IY)
;
;	Clear out Driver
;
	LD	BC,LENGTH-1	;BC = # of bytes clr
	LD	(HL),0		;Null byte
	LD	D,H		;Set DE = HL+1
	LD	E,L
	INC	DE
	LDIR			;Clear area
;
;	Disable DCT slot
;
NORECLM	POP	HL		;HL => DCT + 0
	LD	(HL),0C9H	;Disable it
;
;	Calculate Start of Disable string
;
	PUSH	IY		;Xfer to HL
	POP	HL
	LD	C,(HL)		;P/u type
	SLA	C		;Multiply by 2
	LD	B,0		;BC = offset in table
	INC	HL		;HL => Address Table
	ADD	HL,BC		;HL => Add of mess string
	LD	E,(HL)		;P/u Address
	INC	HL
	LD	D,(HL)
	EX	DE,HL		;HL => Disable message
	@@LOGOT			;Log message
	JP	EXIT		;Go to exit routine
;
;	FORMAT - Format Memory
;
FORMAT	LD	HL,VERIFY	;"Verifying RAM ..."
	@@DSPLY			;Display it
	LD	D,00		;Track counter
;
;	Display Current Cylinder Formatting
;
WIPELP	LD	A,D		;Get track counter
	CALL	DECASC2		;Display Dec ASCII equiv.
;
;	Run 4 different bit tests on each cylinder
;
	LD	A,11111111B	;All bits on
	CALL	VERCYL		;Verify track w/ bits on
	LD	A,01010101B	;Next pattern
	CALL	VERCYL
	LD	A,10101010B	;Last pattern
	CALL	VERCYL
	LD	A,00000000B	;All bits off
	CALL	VERCYL		;Verify track w/ bits off
;
;	Finished Formatting yet ?
;
	INC	D		;Bump cylinder #
	LD	A,D
	CP	(IX+6)		;Finished ?
	JR	NZ,WIPELP	;No - stop when max cyl
;
;	Finished Formatting - Display message
;
	LD	HL,FORMCOM	;"Formatting Complete"
	@@DSPLY			;Print it
	RET			;Done formatting
;
;	VERCYL - Verify a cylinder of RAM
;
VERCYL	LD	HL,IOBUFF	;HL => I/O buffer
	LD	E,0		;Init to sector 0
;
;	Fill buffer with specified byte
;
STUFLP	LD	(HL),A		;Stuff into buffer
	INC	L		;Bump
	JR	NZ,STUFLP	;256 bytes to fill
;
;	Write the sector & read it back
;
CYLP	PUSH	AF		;Save fill byte
	CALL	WRSEC		;Write Sector
	CALL	RDSEC		;Read into other buff
	POP	AF		;A = Fill byte
;
;	Check if sector read back has correct byte
;
CKLP	CP	(HL)		;Match ?
	JP	NZ,ERROR	;No  - error
	INC	L		;Done with sector ?
	JR	NZ,CKLP		;256 bytes to check
;
;	Advance to next sector
;
	LD	A,E		;P/u sector #
	CP	(IX+7)		;Finished ?
	LD	A,(HL)		;P/u cylinder byte
	INC	DE		;Bump E
	JR	NZ,CYLP		;DCT+8 sectors to check
	RET			;Done - RETurn
;
;	FORMTIT - Check if MemDISK has data on it
;
FORMTIT	LD	DE,100H		;D = Cyl 1, Sec 0 (GAT)
	CALL	RDSEC		;Read BOOT sector
;
;	Check GAT ID
;
	LD	L,0D0H		;MemDISK pack name
	LD	DE,MEMDISK	;What it should be
	LD	B,8		;# of characters
;
CKMLP	LD	A,(DE)		;P/u should be char
	CP	(HL)		;Match ?
	INC	HL		;Bump
	INC	DE
	JR	NZ,NOMTCH	;No - must format
	DJNZ	CKMLP		;Yes - loop for more
;
;	Already a MemDISK - Sure about formatting ?
;
	LD	HL,DOFORM	;Destination ...
	LD	A,1		;Set MemDISK in flag
	LD	(MEMIN1+1),A
	JR	DISMES		;Display it
;
;	Not a MemDISK - Do normal Prompt
;
NOMTCH	LD	HL,STILLFM	;Do you wish to format ?
DISMES	@@DSPLY			;Display message
;
;	Input Response
;
	LD	B,1		;Input 1 character
	PUSH	HL		;Save message start
	CALL	INPUT
	LD	A,(HL)		;P/u character
	POP	HL		;Recover message start
	DEC	B		;Anything entered ?
	RET	NZ		;No - RETurn NZ
;
;	Set Z flag if "Y" & Reset Z if "N" entered
;
	RES	5,A		;Cvt to U/C
	CP	'N'		;<N>o ?
	JR	Z,RESZF		;RETurn NZ
	CP	'Y'		;<Y>es ?
	RET	Z		;RETurn Z set
	JR	DISMES		;No - reprompt
RESZF	OR	A		;Reset Z flag
	RET			;  and RETurn
;
;	Variables used
SAVEDE	DW	0
SAVEDCT	DW	0
DRADD	DW	0
;
;	Informative Error Display & Abort Routine
;
NODRV	LD	HL,NODRV$
	DB	0DDH
BADDRV	LD	HL,BADDRV$
	DB	0DDH
VIASET	LD	HL,VIASET$	;Not via SYSTEM
	DB	0DDH
MEMIN	LD	HL,MEMIN$	;Already installed
	DB	0DDH
NOTMEM	LD	HL,NOTMEM$	;Not a MemDISK
	DB	0DDH
NOMEM	LD	HL,NOMEM$	;Insufficient Memory
	DB	0DDH
NOTPRS	LD	HL,NOTPRS$	;Not Present
	DB	0DDH
BNKUSE	LD	HL,BNKUSE$	;Bank in use
	DB	0DDH
NOTACT	LD	HL,NOTACT$	;Cant Install
;
;	Log Error Message & Abort
;
	@@LOGOT			;Log error message
	JP	ABORT		;Go to exit routine
;
HELLO$	DB	'MEMDISK'
*GET	CLIENT:3
;
BANKS	DB	LF,'<A>  Bank 0 (Primary Memory)',LF
	DB	'<B>  Bank 1',LF
	DB	'<C>  Bank 2',LF
	DB	'<D>  Banks 1 and 2',LF
	DB	'<E>  Disable MemDISK',LF,LF
	DB	'Which type of allocation - '
	DB	'<A>, <B>, <C>, <D>, or <E> ? ',ETX
;
FRTRACK	DB	'Note: Each Cylinder equals '
FRTRK1	DB	'4.50K of space.',LF
	DB	'Number of free Cylinders: ',MINCYL+'0'&0FFH,'-'
FRTRK2	DB	'00 ? ',ETX
;
DENSITY	DB	'Single or Double Density <S,D> ? ',ETX
;
DOFORM	DB	'Destination MemDISK contains Data',LF
;
STILLFM	DB	'Do you wish to Format it <Y/N> ? ',ETX
;
MEMDISK	DB	'MEMDISK '
MD$	DB	'$MD',ETX
MDDATA	DB	18H,17,0,0,8,'MemDISKD',0,0,0,0
;
NODRV$	DB	'Logical drive number required',CR
BADDRV$	DB	'Can''t specify SYSTEM drive slot',CR
INSTALD	DB	'MemDISK Successfully Installed',CR
;
NOTMEM$	DB	'Target Drive not a MemDISK',CR
;
NOMEM$	DB	'Insufficient Memory ',CR
;
NOTPRS$	DB	'MemDISK not present',CR
;
NOTACT$	DB	'MemDISK not present, installation '
	DB	'aborted',CR
;
DISABE1	DB	'MemDISK disabled, memory now avail'
	DB	'able',CR
;
DISABE2	DB	'MemDISK disabled, Unable to reclaim '
	DB	'high memory',CR
;
DISABE3	DB	'MemDISK disabled, Unable to reclaim '
	DB	'driver area',CR
;
DISABE4	DB	'MemDISK disabled, Unable to reclaim '
	DB	'high memory and driver area',CR
;
BNKUSE$	DB	'Unable to install MemDISK, '
	DB	'requested bank in use.',CR
;
MEMIN$	DB	'MemDISK already Active',CR
;
VERIFY	DB	'Verifying RAM cylinder 00',ETX
;
FORMCOM	DB	LF,'Verifying Complete, RAM good',LF
	DB	'Directory has been placed on Cylinder 1',CR
;
VIASET$	DB	'Must install via SYSTEM (DRIVER=',CR
;
BADRAM	DB	LF,'Verify Error in Bank '
VBANK	DB	'n at location X',AP
VLOC	DB	'nnnn',AP,LF,CR
;
TYPEDIS	DB	1		;Type of disable
DISTAB	DW	DISABE4,DISABE3,DISABE2,DISABE1
RE_USE	DB	0		;Re-use trapped driver area.
;
;	Buffers Used
;
	ORG	$<-8+1<+8
;
IOBUFF	DS	256
BUFFER	DS	256
DUPDCT	DS	10
;
