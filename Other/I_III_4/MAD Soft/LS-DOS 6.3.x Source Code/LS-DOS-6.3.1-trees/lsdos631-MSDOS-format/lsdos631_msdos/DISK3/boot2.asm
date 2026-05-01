; BOOT2/ASM - LDOS 6.2 - Model II BOOT sector - 09/28/83
;
;	revised 09/28/83 for Mod II	- kjw
;
;	boot diskette structure
;
;	@0E00 - sec 01 - +0=00, +1=FE, +2=dir, +3=step
;			 +4=secs/cyl, +5=density
;	@0E80 - sec 02 - unused
;	@0F00 - sec 03 - unused
;	@0F80 - sec 04 - unused
;	@1000 - sec 05 - boot stub
;	@1080 - sec 05 - start actual sys loading code
;	@1100 - sec 06 - continue boot
;	@1180 - sec 07 - continue boot
;	@1200 - sec 08 - continue boot (512 bytes)
;
;	code from 0E00H > 12FFH moved to 2300H > 27FFH
;
;	module equates
;
SPCYL	EQU	30		;sectors/cylinder
$HDIO	EQU	0C1H		;hard disk init port
$FDCCMD	EQU	0E4H		;FDC command
$FDCSTA	EQU	0E4H		;FDC status
$FDCTRK	EQU	0E5H		;FDC track
$FDCSEC	EQU	0E6H		;FDC sector
$FDCDAT	EQU	0E7H		;FDC data
$FDCSEL	EQU	0EFH		;FDC select
$DMA	EQU	0F8H		;DMA command/status
$ROME	EQU	0F9H		;rom enable
$CRTC	EQU	0FCH		;CRTC controller (output)
$BSEL	EQU	0FFH		;bank/video select port
;
$DMAON	EQU	087H		;DMA ON command
$DMAOFF	EQU	083H		;DMA OFF command
$FREAD	EQU	082H		;floppy read command
$FWRIT	EQU	0A0H		;floppy write command
$FFMT	EQU	0F0H		;floppy format command
$FSEEK	EQU	01CH		;floppy seek, H,V,10ms
$FCLER	EQU	0D0H		;floppy force clear
BUFFER	EQU	1D00H		;system buffer
;
;*=*=*
;       Boot loader routine
;	following code located on cyl 0, sector 2
;
;*=*=*
;
	ORG	1000H		;at sector 2, cyl 0
	LORG	1000H		;will load here also
;
BOOT1	DB	'BOOT'		;rom will find this
ENTRY1	XOR	A		;load zero
	OUT	($ROME),A	;disable boot rom
	LD	HL,0E00H	;rom loads from here
	LD	DE,2300H	;move up here
	LD	BC,500H		;length to move
	LDIR			;move program upwards
	JP	2600H		;continue with load
;
;	actual LOWCORE and SYSRES loader code
;	must reside at cyl 0, sectors 3-6
;	program will load at 0F00H and execute at 4400H
;
	ORG	2600H		;for correct assembly
	LORG	1100H		;will load here
;
;*=*=*
;       Read the first 16 sectors of track 0
;*=*=*
ENTRY2	LD	SP,ENTRY2	;set stack just below
	LD	A,(2304H)	;get secs/cyl
	LD	(SECS),A	;pass to I/O driver
	LD	A,(2305H)	;get density
	LD	(DENSITY),A	;pass to I/O driver
	LD	HL,200H		;point to page 2
	LD	DE,1<8+0	;boot location!
;
RDBOOT	CALL	RDSEQ		;Read a sector
	INC	H		;Bump to next page
	INC	E		;Bump to next
	LD	A,18		;msb # buffers
	CP	E		;Loop if more
	JR	NZ,RDBOOT
;*=*=*
;       Now load SYSRES
;*=*=*
	LD	DE,(2301H)	;get directory track
	LD	E,0		;Init to read the GAT
	CALL	RDSECT		;  into BUFFER
	LD	HL,(BUFFER+0CCH) ;get GAT data for DCT$
	LD	(2304H),HL	;pass to sysres init
	LD	A,80H		;set double den
	BIT	6,H		;double?
	JR	NZ,$+3		;go if yes
	XOR	A		;set single den
	LD	(DENSITY),A	;save density
	LD	A,16		;sec/track single den
	JR	Z,$+4		;go if single
	LD	A,30		;sec/track double den
	LD	(SECS),A	;save track count
	BIT	5,H		;double sided?
	JR	Z,$+3		;go if not
	ADD	A,A		;sec/cyl double side
	LD	(HISEC),A	;save high sector
;
;	read directory entry for sys0 to locate
;
	LD	E,4		;Pt to SYS0 dir sector
	CALL	RDSECT		;Read the SYS0 dir sec
	LD	A,(BUFFER)	;Test if system disk
	CPL			;invert
	AND	50H		;active/system?
	JR	NZ,SERROR	;Go if not
;
	LD	HL,(BUFFER+16H)	;Pt to SYS0 cylinder data
	LD	D,L		;Xfer starting cylinder
	LD	A,H		;Get starting relative
	RLCA			;  granule into reg H
	RLCA
	RLCA
	AND	7
	LD	H,A
	LD	A,(DENSITY)	;get density flag
	OR	A		;single?
	LD	B,8		;sec/gran single
	JR	Z,$+4		;go if single
	LD	B,10		;sec/gran double
	XOR	A		;init sector #
CMPST	ADD	A,H		;add gran
	DJNZ	CMPST		;compute start sector
	LD	E,A
	LD	HL,BUFFER+255	;Init to buffer end
	EXX
;
;	load program and jump!
;
	CALL	LOAD		;Load SYSRES
	JP	(HL)		;go sysres init!
;*****
;       routine to read a sector
;*****
RDSECT	LD	HL,BUFFER	;Set buffer
RDSEQ	LD	B,5		;Init retry counter
RDS1	PUSH	BC		;Save counter
	PUSH	DE		;save cyl/sec
	PUSH	HL		;Save for retries
	CALL	READ		;Attempt read
	POP	HL
	POP	DE
	POP	BC
	RET	Z		;Return if no error
	DJNZ	RDS1		;Loop for retry
;
;	error vectors
;
DERROR	LD	HL,DSKMSG	;"Disk error"
	LD	A,DSKMSGL	;length
	JR	ERROR		;go common
;
MERROR	LD	HL,MEMMSG	;'memory error'
	LD	A,MEMMSGL	;length
	JR	ERROR		;continue
;
SERROR	LD	HL,SYSMSG	;"No system"
	LD	A,SYSMSGL	;length
;
;	display error to video
;
ERROR	LD	C,A		;pass text length
	LD	B,0		;BC = length
	LD	DE,80*11+0F800H+35	;middle of screen
	LDIR
	LD	A,4FH		;no drives
	OUT	($FDCSEL),A	;de-select
HALTS	JR	HALTS		;Wait for RESET
;
LOAD	CALL	RDBYTE		;Get type code
	DEC	A
	JR	NZ,LOAD2	;Bypass if not type 1
	CALL	BGETADR		;Get blk len & load adr
LOAD1	CALL	RDBYTE		;Start reading the block
	LD	(HL),A		;Stuff into memory
	CP	(HL)		;still there?
	JR	NZ,MERROR	;nope, memory error!
	INC	HL		;Bump memory pointer
	DJNZ	LOAD1		;Loop for entire block
	JR	LOAD		;Restart the process
LOAD2	DEC	A		;Test if type 2 (traadr)
	JR	Z,BGETADR	;Ah, go if transfer addr
	CALL	RDBYTE		;Assume comment,
	LD	B,A		;  get comment length
LOAD3	CALL	RDBYTE		;  & ignore it
	DJNZ	LOAD3
	JR	LOAD		;Continue to read
;*****
;       got the transfer address type code
;*****
BGETADR	CALL	RDBYTE		;Get block length
	SUB	2		;less address length
	LD	B,A
	CALL	RDBYTE		;Get lo-order load addr
	LD	L,A
	CALL	RDBYTE		;Get hi-order load addr
	LD	H,A
	RET
;*****
;       routine to read a byte
;*****
RDBYTE	EXX			;Switch memory/buf ptrs
	INC	L		;Bump buf pointer
	JR	NZ,RDB1		;Bypass disk i/o if more
	CALL	RDSECT		;Grab another sector
	INC	E		;Bump sector counter
	LD	A,0		;sectors/cyl
HISEC	EQU	$-1
	SUB	E		;Is this the last sector
	JR	NZ,RDB1		;  on the cylinder?
	LD	E,A		;Yes, restart at 0
	INC	D		;  & bump the cylinder up
RDB1	LD	A,(HL)		;P/u a byte
	EXX			;Exc mem/buf pointers
	RET			;return with byte
;
READ	LD	(DMARD+9),HL	;pass dma buffer
	LD	HL,DMARD	;start data table
	LD	BC,15<8+$DMA	;length + dma port
	OTIR			;setup DMA
;
;	seek track and select side
;
	CALL	SEEK		;seek cylinder
	RET	NZ		;go if error
;
;	transfer sector data
;
	CALL	DCLEAR		;clear FDC
	BIT	5,A		;head loaded?
	LD	A,$FREAD	;floppy read command
	JR	NZ,$+4		;go if yes
	OR	4		;set head load bit
	OR	0		;set side compare bit
SIDEB	EQU	$-1
	OUT	($FDCCMD),A	;issue FDC command
	LD	A,$DMAON	;dma ON command
	OUT	($DMA),A	;enable DMA
	CALL	BWAIT		;wait for done
	LD	A,$DMAOFF	;dma OFF command
	OUT	($DMA),A	;disable DMA
	IN	A,($FDCSTA)	;read status
	AND	9DH		;set error bits
	RET			;return with status
;
;	seek cylinder
;
SEEK	PUSH	DE		;save cyl/sect
	XOR	A		;load zero
	LD	(SIDEB),A	;side compare bit
	LD	A,80H		;get density
DENSITY	EQU	$-1
	OR	7EH		;set select mode
	LD	D,A		;save mode
	LD	A,30		;get sectors/track
SECS	EQU	$-1
	DEC	A		;A = highest sector
	SUB	E		;on side 1?
	JR	NC,SEEK1	;go if on side 0
	RES	6,D		;set side 1
	CPL			;minus sect
	LD	E,A		;update sector
	LD	A,8		;side compare bit
	LD	(SIDEB),A	;save it
SEEK1	LD	A,E		;get sector
	OUT	($FDCSEC),A	;load sector register
	LD	A,D		;get select mask
	OUT	($FDCSEL),A	;select drive and mode
	POP	DE		;restore
;
	IN	A,($FDCTRK)	;read track register
	SUB	D		;at track?
	RET	Z		;yes, no need to seek
;
	LD	A,D		;get cylinder
	OUT	($FDCDAT),A	;set track needed
	LD	A,(2303H)	;get speed byte
	AND	3		;2 bits only
	OR	$FSEEK		;create seek command
	OUT	($FDCCMD),A	;issue seek command
	CALL	BWAIT		;wait for done
	IN	A,($FDCSTA)	;read status
	AND	98H		;check for seek error
	RET			;return with status
;
;	wait for FDC completion
;
BWAIT	CALL	DELAY		;delay 140 us
BWAIT1	IN	A,($FDCSTA)	;read status
	AND	81H		;ready/busy
	DEC	A		;busy?
	JR	Z,BWAIT1	;yes, wait
	RET			;else done
;
;	clear FDC and get status
;
DCLEAR	LD	A,$FCLER	;forced clear
	OUT	($FDCCMD),A	;to FDC
	CALL	DELAY		;wait for status
	IN	A,($FDCSTA)	;read status
	RET			;return with status
;
;	delay 140 us for valid status register
;
DELAY	PUSH	BC		;save
	LD	B,14		;140 us
	DJNZ	$		;wait
	POP	BC		;restore
	RET			;done
;
;	DMA read initialization table
;
DMARD	DB	0C3H		;WR6 - reset
	DB	08BH		;WR6 - clear status
	DB	069H		;WR0 - portA follows
	DB	$FDCDAT		;fdc data register
	DW	256		;block length
	DB	03CH		;WR1 - portA fixed, I/O
	DB	010H		;WR2 - portB inc, mem
	DB	08DH		;WR4 - byte, portB follow
	DW	0000H		;buffer address
	DB	08AH		;WR5 - stop, ready, high
	DB	0CFH		;WR6 - load start, clear
	DB	005H		;WR0 - portA => portB
	DB	0CFH		;WR6 - load start, clear
;
DSKMSG	DB	'Disk Error'
DSKMSGL	EQU	$-DSKMSG
;
SYSMSG	DB	'No System'
SYSMSGL	EQU	$-SYSMSG
;
MEMMSG	DB	'Memory Fault'
MEMMSGL	EQU	$-MEMMSG
;
EBOOT	EQU	$
;
	IFGT	EBOOT,27FFH
	ERR	'Boot Information Too Long'
	ENDIF
;
	END
