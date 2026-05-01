;LOADER/ASM - LS-DOS 6.2
CORE$	DEFL	$
	ORG	SVCTAB$
;
;	Supervisor Call table - Page 5
;
	DW	@IPL,@KEY,@DSP,@GET		;0-3
	DW	@PUT,@CTL,@PRT,@WHERE		;4-7
	DW	@KBD,@KEYIN,@DSPLY,@LOGER	;8-11
	DW	@LOGOT,@MSG,@PRINT,@VDCTL	;12-15
	DW	@PAUSE,@PARAM,@DATE,@TIME	;16-19
	DW	@CHNIO,@ABORT,@EXIT,SVCERR	;20-23
	DW	@CMNDI,@CMNDR,@ERROR,@DEBUG	;24-27
	DW	@CKTSK,@ADTSK,@RMTSK,@RPTSK	;28-31
	DW	@KLTSK,@CKDRV,@DODIR,@RAMDIR	;32-35
	DW	SVCERR,SVCERR,SVCERR,SVCERR	;36-39
	DW	@DCSTAT,@SLCT,@DCINIT,@DCRES	;40-43
	DW	@RSTOR,@STEPI,@SEEK,@RSLCT	;44-47
	DW	@RDHDR,@RDSEC,@VRSEC,@RDTRK	;48-51
	DW	@HDFMT,@WRSEC,@WRSSC,@WRTRK	;52-55
	DW	@RENAME,@REMOVE,@INIT,@OPEN	;56-59
	DW	@CLOSE,@BKSP,@CKEOF,@LOC	;60-63
	DW	@LOF,@PEOF,@POSN,@READ		;64-67
	DW	@REW,@RREAD,@RWRIT,@SEEKSC	;68-71
	DW	@SKIP,@VER,@WEOF,@WRITE		;72-75
	DW	@LOAD,@RUN,@FSPEC,@FEXT		;76-79
	DW	@FNAME,@GTDCT,@GTDCB,@GTMOD	;80-83
	DW	SVCERR,@RDSSC,@GATRD,@DIRRD	;84-87
	DW	@DIRWR,@GATWR,@MUL8,@MUL16	;88-91
	DW	SVCERR,@DIV8,@DIV16,@HEXD	;92-95
	DW	@DECHEX,@HEXDEC,@HEX8,@HEX16	;96-99
	DW	@HIGH$,@FLAGS,@BANK,@BREAK	;100-103
	DW	@SOUND,@CLS,@CKBRKC,@VDPRT	;104-107
	DW	SVCERR,SVCERR,SVCERR,SVCERR	;108-111
	DW	SVCERR,SVCERR,SVCERR,SVCERR	;112-115
	DW	SVCERR,SVCERR,SVCERR,SVCERR	;116-119
	DW	SVCERR,SVCERR,SVCERR,SVCERR	;120-123
	DW	SVCERR,SVCERR,SVCERR,SVCERR	;124-127
	ORG	CORE$
;
;	Routine to set or retrieve HIGH$/LOW$
;
@HIGH$	LD	A,H		;Test if put or get
	OR	L
	JR	Z,GETHILO	;Go if get
	LD	A,(CFLAG$)	;Is HIGH$ changeable?
	RRCA
	LD	A,43		;Init SVC parm error
	RET	C		;Back with NZ
	INC	B		;Test for HIGH$/LOW$
	DEC	B
	JR	NZ,PUTLO	;Go if LOW$
	LD	(HIGH$),HL	;Set new HIGH$
GETHI	LD	HL,(HIGH$)	;P/u the value &
	RET			;  ret with Z-flag
GETHILO	INC	B		;Test for HIGH$/LOW$
	DEC	B
	JR	Z,GETHI
	LD	HL,(LOW$)	;P/u LOW$
PUTLO	LD	(LOW$),HL	;Get LOW$
	XOR	A		;Set Z-flag
	RET
;
@FLAGS	LD	IY,FLGTAB$
	RET
;
@BREAK	PUSH	HL		;Save user vector
	LD	HL,(BRKVEC$)	;P/u current vector
	EX	(SP),HL		;Save current & get user
	LD	(BRKVEC$),HL	;Stuff new vector
	POP	HL		;Recover old vector
	RET
;
@WHERE	POP	HL
	JP	(HL)
;
;	Code for these SVCs is in system overlays
;
@CMNDR	LD	A,0A3H		;Interpret command & RET
	RST	40
@CMNDI	LD	A,0B3H		;Interpret a command
	RST	40
@FSPEC	LD	A,0C3H		;Parse a filespec
	RST	40
@FEXT	LD	A,0D3H		;Optional default EXT
	RST	40
@PARAM	LD	A,0E3H		;Parameter scanner
	RST	40
@OPEN	LD	A,94H		;Open a file
	RST	40
@INIT	LD	A,0A4H		;Initialize a file
	RST	40
@GTDCB	LD	A,0B4H		;Get a DCB vector
	RST	40
@CKDRV	LD	A,0C4H		;Drive available?
	RST	40
@RENAME	LD	A,0F4H		;Rename a file
	RST	40
@CLOSE	LD	A,95H		;Close a file
	RST	40
@FNAME	LD	A,0A5H		;Recover filespec
	RST	40
@DBGHK	RET			;Init DEBUG off (NOP=on)
@DEBUG	PUSH	AF
	LD	A,97H		;Enter system Debugger
	RST	40
EXTDBG$	DW	ORARET@		;Hook for extended DEBUG
@REMOVE	LD	A,9CH		;Remove a file/device
	RST	40
@DOKEY	LD	A,0CDH		;DO execution
	RST	40
@RAMDIR	LD	A,09EH		;Directory data
	RST	40
@DODIR	LD	A,0AEH		;Directory data
	RST	40
@GTMOD	LD	A,0BEH		;Get module address
	RST	40
;
;	These SVCs handle the disk primitive requests
;
@DCSTAT	XOR	A		;FDC status
	JR	IOFUNC
TAPDRV	LD	A,(LDRV$)	;P/u drive #
	LD	C,A
@SLCT	LD	A,1		;Select drive
	JR	IOFUNC
@DCINIT	LD	A,2		;FDC init
	JR	IOFUNC
@DCRES	LD	A,3		;FDC reset
	JR	IOFUNC
@RSTOR	LD	A,4		;Restore to cyl 0
	JR	IOFUNC
@STEPI	LD	A,5		;Step in 1 cyl
	JR	IOFUNC
@SEEK	LD	A,6		;Seek a track/sector
	JR	IOFUNC
@RSLCT	LD	A,7		;Re-select drive
	JR	IOFUNC
@RDHDR	LD	A,8
	JR	IOFUNC
@VRSEC	LD	A,10		;Verify a sector
	JR	IOFUNC
@RDTRK	LD	A,11
	JR	IOFUNC
@HDFMT	LD	A,12
	JR	IOFUNC
@WRSEC	LD	A,13		;Write standard sector
	JR	IOFUNC
@WRSSC	LD	A,14		;Write a system sector
	JR	IOFUNC
@WRTRK	LD	A,15		;Write a track
	JR	IOFUNC
@RDSEC	LD	A,9		;Read a sector
;
IOFUNC	PUSH	BC		;Save reg pair
	LD	B,A		;Xfer the function code
;
;	Bring up bank 0
;
	PUSH	BC
	XOR	A
	LD	B,A		;Set bank function 0,
	LD	C,A		;  bank number 0
	CALL	@BANK		;Bring up bank
	POP	AF		;Perform EX (SP),BC
	PUSH	BC
	PUSH	AF
	POP	BC
;
;	Continue disk I/O setup
;
	LD	A,C		;Xfer the drive code
	LD	(LDRV$),A
	PUSH	IY
	CALL	@GTDCT		;Get DCT address in IY
	LD	A,20H		;Set illegal drive #
	OR	A		;  if drive disabled
	CALL	GODOIO
	POP	IY
;
;	Bring back the old bank
;
	POP	BC
	PUSH	AF		;Save disk I/O retcod
	LD	A,102		;Set for @BANK
	RST	40		;No need to ck for error
				;  from @BANK
	POP	AF
	POP	BC
	RET
;
GODOIO	JP	(IY)
;
@GTDCT	PUSH	HL		;Get i/o routine addr
	CALL	DCTFLD@		;  into IY
	EX	(SP),HL
	POP	IY
	RET
;
;	Entry to get DCT+8 of FCB (IX) drive spec
;
D@FBYT8	LD	C,(IX+6)	;P/u drive
;
;	Entry to get DCT+8 of Reg C drive spec
;
DCTBYT8@
	LD	A,8
;
;	Entry to get byte (Reg A) from DCT of Reg C drive
;	 C => logical drive specification
;	 A => relative byte requested from DCT
;	 A <= data at position requested
;
@DCTBYT	PUSH	HL		;Save the register pair
	LD	H,A		;Xfer relative position
	CALL	DCTFLD@		;Get HL pointing to
	LD	L,A		;  DCT position
	LD	A,(HL)		;Get the byte
	POP	HL
	RET
;
;	Entry to get HL pointing to DCT byte Reg C, Reg A
;	 C => logical drive number
;	 A => relative byte in DCT requested
;	HL <= start of requested DCT for the drive
;	 A <= low order pointer to relative byte request
;
DCTFLD@	LD	A,C		;Get drive spec &
	AND	7		;  strip excess data
	ADD	A,A		;Times 2
	LD	L,A		;  & saved
	ADD	A,A		;Times 4
	ADD	A,A		;Times 8
	ADD	A,L		;Times 10
	ADD	A,70H		;Add DCT offset from 0
	LD	L,A		;Point L to DCT low order
	ADD	A,H		;Add in rel pos desired
	LD	H,DCT$<-8	;Point H to DCT hi-order
	RET
;
;	Process supervisory calls <0-127>
;
SVCUSER	CP	26		;Check for @ERROR
	JR	Z,ERRSVC	;Skip next if so
	LD	(LSVC$),A	;Store SVC request
	EX	(SP),HL		;P/u RET address
	LD	(SVCRET$),HL	;  and save it
	EX	(SP),HL		;Restore RET address
ERRSVC	PUSH	HL		;Save HL
	RLCA			;Multiply by two
	LD	H,SVCTAB$<-8	;Base of table
	LD	L,A		;Set up the low order
	LD	A,(HL)		;P/u table entry
	INC	L
	LD	H,(HL)
	LD	L,A
	EX	(SP),HL		;P/u HL & stuff vector
	LD	A,C		;Xfer for PUT type ops
	RET
;
;	RST 28 vector - System & user SVCs
;
RST28	OR	A		;Test if bit 7 set
	JP	P,SVCUSER	;Jump on user SVC attempt
	EX	(SP),HL		;Discard return addr &
	PUSH	AF		;  save HL, AF
	LD	HL,@DBGHK	;Set up DEBUG linkage
	LD	A,(HL)
	LD	(SET@EXEC),A
	LD	(HL),0C9H
	POP	AF		;Restore AF, HL
	POP	HL
HKRES$	CALL	CKMOD@		;Get overlay if needed
	LD	A,0		;P/u new overlay #
OVRLYOLD	EQU	$-1
	LD	(OVRLY$),A	;  & update current
TRANSFR	CALL	0		;Traadr of SYSx
	PUSH	AF
	LD	A,0		;Set to C9 if EXEC only
SET@EXEC	EQU	$-1
	LD	(@DBGHK),A
	POP	AF
	RET
;
;	DOS command overlay request
;
CKMOD@	PUSH	HL
	LD	H,A		;Save command value
	LD	A,B
	LD	(EXOVR2+1),A	;Set overlay #
	LD	A,H
	OR	1		;Set for SYS6 & SYS7
	CP	89H		;Is it either?
	LD	A,H		;Get back the correct #
	JR	Z,EXOVR		;Sys6/7 req? Use ISAM!
	CP	8AH		;Sys8 also ISAM
	JR	Z,EXOVR
	LD	A,(OVRLY$)	;P/u current overlay
	XOR	H		;Ck if it's the one
	AND	0FH		;  we need to execute
	LD	A,H
	LD	(OVRLYOLD),A	;Update current tempy
	LD	HL,OVERLAY	;Init to SYSx entry
	JR	Z,EXOVR3	;Go exec if resident
;
;	Execute a system overlay
;
EXOVR	PUSH	DE
	PUSH	BC
	AND	0FH		;Get right nybble
	BIT	3,A		;Check for SYS0-7
	JR	Z,EXOVR1	;  w/o changing carry
	ADD	A,18H		;Adjust for sys8-15
EXOVR1	LD	(SFCB$+7),A
	LD	B,A		;Set DEC for directory
	LD	A,20H		;Set bit 5 of FCB+1
	LD	(SFCB$+1),A
	SBC	HL,HL		;Carry is clear here
	LD	(SFCB$+10),HL	;Zero NRN
	LD	C,H		;Init for drive 0
	CALL	@DIRRD		;Read dir entry
	JR	NZ,EXERR	;Go if error
	LD	A,(HL)		;Was overlay purged?
	AND	50H		;  or is it non-system?
	XOR	50H
	LD	A,7		;Init "deleted error
	JR	NZ,EXERR
	LD	A,L
	ADD	A,22		;Point to 1st extent
	LD	L,A
	LD	DE,SFCB$+14	;Extent field in FCB
	CALL	PAT1		;Stuff 1st two extents
EXOVR2	LD	B,0		;P/u ISAM # or zero
	LD	E,SFCB$&0FFH
	CALL	LOADER		;Read system overlay
EXERR	POP	BC
	POP	DE
EXOVR3	LD	(TRANSFR+1),HL	;Stuff overlay entry pt
	POP	HL
	RET	Z
	JR	SYSERR		;Go if I/O error on read
;
;	Routine to calculate 1st two extents of SYS file
;
PAT1	CALL	PAT1A		;Move first extent
	AND	1FH		;Compute # of granules
	INC	A
	LD	(DE),A		;And store in FCB
	INC	DE
	XOR	A
	LD	(DE),A
	INC	DE
PAT1A	CALL	PAT1B		;Move second extent
PAT1B	LD	A,(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	RET
;
;	System error display routine
;	The NOP is provided so an intercept routine vector
;	 may be patched in during program development
;
SVCERR	LD	A,43		;SVC error
	NOP
SYSERR	AND	3FH		;Strip excess bits
	LD	HL,ERRNUM	;Pack error number
	CALL	@HEX8		;  into message
	LD	HL,SYSERR$
	CALL	@LOGOT		;Log the error & ABORT
	LD	SP,STACK$	;reset stack
@ABORT	LD	HL,-1
@EXIT	LD	A,93H		;Exit to DOS
	RST	40
;
POPERR	POP	HL		;Pop extended error
@ERROR	PUSH	AF		;Save the error code
	LD	A,96H		;Display the error number
	RST	40
;
SYSERR$	DM	'Error '
ERRNUM	DM	'xxH',CR
;
;	Routine to RUN a program
;
@RUN	PUSH	HL		;Save register pair
	LD	HL,SFLAG$
	SET	2,(HL)		;Turn on RUN flag bit
	CALL	@LOAD		;Load the program module
	EX	(SP),HL		;Put traadr on the stack
;
;	Note: The error code is set to NOT abort. Errors
;	 will be passed back to the calling module after
;	 @ERROR. Note that HL will contain the error #.
;
	JR	NZ,POPERR
;
;	Place the INBUF$ pointer in register pair BC
;
	LD	BC,INBUF$	;Reflect buffer pointer
;
;	Get TRAADR then test if we need to go to DEBUG
;
	LD	A,(SFLAG$)
	BIT	1,A		;Go to the program if
	RET	NZ		;  its EXEC only access
	BIT	7,A		;  else test if DEBUG
	JP	NZ,@RST30	;  is on & go to it
	RET			;  else go to program
;
;	This routine LOADs a Load Module Format file
;
@LOAD	LD	B,0		;LRL=256
	LD	HL,SFLAG$
	SET	0,(HL)		;Don't set "file open"
	LD	HL,SBUFF$	;Set buffer to system
	CALL	@OPEN		;Open the file
	PUSH	DE		;Save FCB pointer
	CALL	Z,LOADER	;Load if no OPEN error
	POP	DE		;Restore FCB pointer
	RET	Z		;Back if no error
	LD	L,A		;Xfer the error code
	LD	H,0
	OR	0C0H		;Set RETurn & abbrev
	CP	0D8H		;Change "file not in dir"
	RET	NZ		;  to "program not found"
	ADD	A,7
	RET
;
;	System command file loader
;
LOADER	LD	A,B		;Set overlay # (0 on non
	LD	(LDR14+1),A	;  SYStem file)
	PUSH	DE		;Save IX & xfer FCB to IX
	EX	(SP),IX
	LD	DE,SBUFF$+255	;Init to end of buffer
	CALL	LDR01		;Do the load
	POP	IX		;Recover IX
	RET
;
;	Routine to ignore the LMF record
;
LDR05	CALL	LDR15		;Get length of "comment"
	LD	B,A
LDR06	CALL	LDR15		;Read & ignore that many
	DJNZ	LDR06		;  bytes then fall thru
;
;	Routine to parse LMF record types
;
LDR01	CALL	LDR15		;Get record type
LDR02	CP	1		;Start of block?
	JR	Z,LDR08
	CP	2		;Start of TRAADR?
LDR03	JR	Z,LDR07
	CP	4		;End of LIB member?
	JR	Z,LDR12
	CP	8		;Begin ISAM table entry?
	JR	Z,LDR13
	CP	10		;End of ISAM map?
	JR	Z,LDR04
	CP	20H		;Ignore all other control
	JR	C,LDR05
LDR04	LD	A,22H		;Load file format err
	OR	A
	RET
;
;	Grab transfer address
;
LDR07	CALL	LDR15		;Bypass 2nd X'02'
	CALL	GETADR		;P/u transfer address
	RET			;Ret Z or NZ
;
;	Grab load block
;
LDR08	CALL	LDR15		;P/u block len
	LD	B,A
	CALL	GETADR		;P/u load address
	RET	NZ
	DEC	B		;Adj length for adr
	DEC	B
LDR09	CALL	LDR15		;P/u block byte
	LD	(HL),A
	INC	HL
	DJNZ	LDR09		;Loop until block end
	JR	LDR01
;
LDR12	POP	HL
	RET
;
;	Routine to check ISAM table match
;
LDR13	CALL	LDR15		;Get record length
	LD	B,A
	CALL	LDR15		;Get ISAM number
	DEC	B		;  & decrement counter
LDR14	CP	0		;Either ISAM# or 0
	JR	NZ,LDR06	;Go if not a match
	CALL	GETADR		;  else get the TRAADR
	PUSH	HL		;  & save it
	CALL	Z,GETADR	;Get the NRN for member
	JR	NZ,LODERR
	CALL	LDR15		;Get the sector offset
	LD	E,A		;Update pointer offset
	PUSH	BC
	LD	B,H		;Xfer NRN position needed
	LD	C,L
	PUSH	DE		;Save buffer ptr offset
	PUSH	IX
	POP	DE		;P/u FCB into DE
	CALL	@POSN		;Position to ISAM rec
	POP	DE		;Rcvr buffer ptr offset
	POP	BC
	JR	NZ,LODERR
	CALL	LDR17		;Read the sector
	JR	LDR02		;Now go read the member
;
;	Routine to get the next file byte
;
LDR15	INC	E		;Bump buf pointer
	JR	Z,LDR17		;Read sector if needed
LDR16	LD	A,(DE)		;P/U byte from buffer
	RET
LDR17	PUSH	HL		;Save regs
	PUSH	DE
	PUSH	BC
	CALL	NXTSECT		;Read next record
	POP	BC		;Restore regs
	POP	DE
	POP	HL
	JR	Z,LDR16		;Bypass if no error
LODERR	POP	BC		;Pop return address
	RET
;
;	Routine to get an address field
;
GETADR	CALL	LDR15		;Get low order byte
	LD	L,A
	CALL	LDR15		;Get hi order byte
	LD	H,A
	CP	A
	RET
;
;	BOOT code brings back the ROM
;
MOD3BUF	EQU	4300H
@IPL	LD	HL,BOOTCOD	;Code to toggle in ROM
	LD	DE,MOD3BUF	;Buffer used by ROM
	PUSH	DE		;This is return address
	LD	BC,BOOTLEN
	LDIR			;Transfer boot code and
	RET			;  jump to it
;
;	End of loader module
;
