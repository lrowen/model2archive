;HDWD5B - Mod 1,3 TRS HD driver part 2 - 06/10/84
	SUBTTL	'<Driver Initialization Routines>'
;
;*=*=*
;Entry point after initial tests
;Set IY=>correct DCT type
;*=*=*
USER	LD	IY,DCTAB
;*=*=*
;       Request physical drive slot first
;*=*=*
	JR	PRMPT4
GETDRV	CALL	ABTJCL
PRMPT4	LD	HL,DRIVE$	;Request physical drive#
	CALL	GETARG		;Display & get argument
	SUB	'1'		;Convert to binary (0-3)
	JR	C,GETDRV	;Re-request if bad range
	CP	3+1		;Check max value
	JR	NC,GETDRV	;Re-request if bad range
;*=*=*
;       Stuff the drive select address into DCT
;*=*=*
;       Merge the drive address
	OR	(IY+DRVSEL)	;  into the standard
	LD	(IY+DRVSEL),A	;  DCT parameters
;*=*=*
; see if drive type has been established
;*=*=*
	CALL	FNDOLD
	JR	NZ,PRMPT1	;1st installation of drive
	LD	A,(IX+5)	;IX=> existing DCT
	LD	(IY+5),A	;Move into this one
	AND	00000111B	;Valid field
	CALL	LDMAX		;Use it
	LD	A,(IX+6)	;P/u cyls
	LD	(IY+6),A
	SRL	A		;/2
	LD	(IY+9),A	;Dir cyl
	BIT	5,(IX+4)	;Double?
	JP	Z,STMP
	SET	5,(IY+4)	;Set
	JP	STMP		;Now map heads
;*=*=*
;       Request drive type information
;*=*=*
GTMAXHD	CALL	ABTJCL		;Unless re-prompt
PRMPT1	LD	HL,HDS$
	CALL	GETARG		;Prmpt/get 1 char
	SUB	'1'
	JR	C,GTMAXHD	;Must be at least 1
	CP	8		;Not over 8
	JR	NC,GTMAXHD
	LD	(IY+5),A	;Store total entry
	CALL	LDMAX
;*=*=*
; request total tracks on drive
;*=*=*
	JR	PRMPT2
GTTRKS	CALL	ABTJCL
PRMPT2	LD	HL,TRK$		;Prompt
	LD	B,3
	CALL	GETARGX		;Get b chars
	CALL	DECHEX		;Make decimal in BC
	PUSH	BC
	LD	HL,9		;Add some for round off
	ADD	HL,BC
	LD	C,8
	CALL	DIV16		;Divide HL by C
	LD	A,L
	LD	(PCPTRK+1),A	;Store precomp setup
	POP	BC		;Restore trk #
	LD	HL,MINTRK-1
	OR	A
	SBC	HL,BC
	JR	NC,GTTRKS	;If too small
	LD	HL,MAXTRK
	OR	A
	SBC	HL,BC
	JR	C,GTTRKS
	LD	HL,203		;Max w/o double trking
	OR	A
	SBC	HL,BC
	JR	NC,SETTRK
	SET	5,(IY+4)	;Set double bit
	SRA	B		;Divide by 2
	RR	C
SETTRK	LD	A,C
	DEC	A		;Offset fm 0
	LD	(IY+6),A	;Store high Trk #
	XOR	A		;Clear carry
	RR	C		;Div by 2
	LD	(IY+9),C	;Dir cyl in center
;
	LD	A,(RESNUM)	;Driver resident?
	OR	A
	JR	NZ,STMP		;Skip step rate if loaded
;*=*=*
;Request drive step rate
;*=*=*
	JR	PRMPT3
GTSTP	CALL	ABTJCL
PRMPT3	LD	HL,STP$
	LD	B,3
	CALL	GETARGX
	CALL	PARSENM		;Conv to step rate bits
	JR	NZ,GTSTP	;If bad entry
	LD	C,A
	CP	00000110	; 3.0 mS?
	JR	NC,FASTOK	;If 3 or less leave 1st cmd
	LD	A,(STP1)	;Chg if >3.0
	AND	11110000B	;Leave command
	OR	C		;Merge step rate bits
	LD	(STP1),A
FASTOK	LD	A,(STP2)
	AND	11110000B	;P/u command
	OR	C		;Merge step
	LD	(STP2),A
;*=*=*
STMP	CALL	SETMAP		; map out heads in use
;*=*=*
;Request heads for partition
;*=*=*
	JR	PRMPT5
REQHD	CALL	ABTJCL
PRMPT5	LD	HL,HEADMP$
	CALL	@DSPLY
	LD	HL,HEADS$	;Get user input
	CALL	GETARG
	SUB	'1'		;Adjust to binary
	JR	C,REQHD		;Must be > 0
	CP	(IY+0)		;Free heads left
	JR	NC,REQHD	;User exceed max?
	INC	A		;Make real
	LD	C,A
	LD	(NUMHDS),A	;Store number for later
	DEC	A		;Offset fm 0
	RRCA			;Shift to 5-7
	RRCA
	RRCA
	LD	B,A		;Save # of heads
	LD	A,(IY+7)	;P/u # of heads in tab
	AND	1FH		;Strip what's there
	OR	B		;Merge # of heads
	LD	(IY+7),A	;Update DCT$+7 init
;*=*=*
;       Calculate proper Sectors Per Granule (SPG)
;       and Grans per cylinder
;*=*=*
	LD	A,C		;Number of heads
	ADD	A,A		;Double # for GPC
	LD	D,15		;Sec/gran (-1)
	LD	E,8+1		;Use 16 sec/gran w/4 heads
	BIT	5,(IY+4)	;Unless dbl bit is set
	JR	Z,UPTO4
	LD	E,4+1		;Then 2 is max
UPTO4	CP	E		;More than max heads (x2)?
	JR	C,G1		;16 sec grans OK if less
	LD	D,31		;Else 32 sec/gran
	LD	A,C		;And GPC will be = # heads
;D=sec/gran A=#heads*2 if 2 grans/trk or # if 1 gran/trk
G1	DEC	A		;GPC offset fm 0
	RRCA
	RRCA
	RRCA			; roll to bits 5-7
	OR	D		; merge sec/gran
	LD	(IY+8),A	; put in DCT
;
	LD	A,(MAXHDS)	;All heads?
	SUB	C		;ALL requested?
	JR	Z,PUTRHD	;0 is starting posn
;*=*=*
;       If not all heads requested, get starting head
;*=*=*
	JR	PRMPT6
REQSHD	CALL	ABTJCL		;Quit if JCL
PRMPT6	LD	HL,STRTHD$
	CALL	GETARG
	SUB	'1'		;In range?
	JR	C,REQSHD
	LD	C,A		;Save start head
	PUSH	BC
	CALL	FREE		;Are these heads in use
	POP	BC
	JR	NZ,REQSHD	;Get again if bad
;*=*=*
;
	LD	A,C		;P/u starting head
PUTRHD	OR	(IY+4)		;Merge user's start
	LD	(IY+4),A	;Update init DCT$+4
;*=*=*
	CALL	INSTALL
	JP	@EXIT
;*=*=*
;Convert ASCII step rate entry to WD bit field
;*=*=*
PARSENM	LD	D,0		;Clear for ans
CHAR	LD	A,(HL)		;Read one
	INC	HL		;=>next
	CP	'.'		;Decimal
	JR	Z,POINT		;Go if found
	CP	CR
	JR	Z,ISCR		;End of line
	SUB	'0'		;Make BCD 0-7
	RET	C		;Out of range
	CP	7+1		;7.5 is high number except 10
	JR	NC,RNGERR
	LD	E,A		;Save BCD
	LD	A,D		;Take D*10
	ADD	A,A		;X2
	ADD	A,A		;X4
	ADD	A,D		;X5
	ADD	A,A		;X10
	ADD	A,E		;+this one to catch 10.0
	JR	CHAR		;Get next char
;
POINT	LD	A,(HL)
ISCR	SLA	D		;Number x2
	CP	'5'
	JR	NZ,NT5
	INC	D
	JR	IS0
NT5	CP	'0'
	JR	Z,IS0
	CP	CR
	RET	NZ
;D=number fm 0 to 20 (2*entry)
;20 = 10 = 0000
;Otherwise range fm 1 to 15 = bit setting for WD step
;Test range
IS0	LD	A,D
	CP	20
	JR	NZ,RNG
	XOR	A
	RET			;Set 0 if 10 was entered
RNG	CP	15+1
	JR	NC,RNGERR	;Bad entry if >15
	CP	A		;Set Z
	RET
RNGERR	OR	0FFH		;Set NZ
	RET
;*=*=*
; stuff max heads on drive  A=# offset fm 0
;*=*=*
LDMAX	RRCA			;Roll to bits 7-5
	RRCA
	RRCA
	LD	C,A
	LD	A,(IY+7)	;Merge
	AND	00011111B
	OR	C
	LD	(IY+7),A	;Store max heads
	RET
;*=*=*
;Driver dependent strings
HELLO$	DB	LF
	DB	'TRSHD5 - WD 1000/1010 - '
	DB	'Driver - Version 5.1.4/d',LF
	DB	'(C) 1982/83/84 by Logical Systems, '
	DB	'Inc.',LF,CR
HDS$	DB	'Enter total number of heads'
	DB	' on drive <1-8> ',3
TRK$	DB	'Enter physical tracks per surface: ',3
STP$	DB	'Enter step rate for drive: ',3
DRIVE$	DB	'Enter drive select address <'
	DB	'1-4> ',3
;
;******************************************
;Common subroutines for hard disk drivers
;*******************************************
;*=*=*
;       Routine to set a bit in head map
;*=*=*
SETBIT	RLCA			;Shift to "b" field
	RLCA
	RLCA
	OR	0C3H		;Establish as SET b,E
	LD	(SBIT1+1),A	;Alter the OP code
SBIT1	SET	0,E		;Map the head bit
	RET
;*=*=*
;       Routine to test if bit is set in head map
;*=*=*
BITBIT	RLCA
	RLCA
	RLCA
	OR	43H		;Construct BIT b,E
	LD	(BBIT1+1),A
BBIT1	BIT	0,E
	RET
;
;*=*=*
; get total heads and cyl count if an existing driver is
; found for this drive select address
FNDOLD	LD	A,(RESNUM)	;Get number of DCTs
	OR	A		;Using this driver
	JR	Z,NTHERE	;If none, prompt
	LD	B,A		;Number to B
	LD	HL,DCTPTR	;=>list of addresses
OLDLP	LD	E,(HL)		;P/u DCT address
	INC	HL
	LD	D,(HL)		;DE=>DCT
	INC	HL		;=>next pointer
	PUSH	DE
	POP	IX		;IX=>DCT
	LD	A,(IX)		;Don't use any drive
	CP	0C9H		;  that's disabled
	JR	Z,SKPTHS
	LD	A,(IX+DRVSEL)	;Check if this matches
	AND	3		;  the drive #
	LD	C,A		;P/u drive requested
	LD	A,(IY+DRVSEL)
	AND	3		;Check if same
	CP	C		;Match up yet?
	RET	Z		;IX=>DCT for same disk
SKPTHS	DJNZ	OLDLP		;Check the rest
NTHERE	OR	0FFH		;Force NZ
	RET
;
;*=*=*
;SETMAP
;IY=>New DCT containing Drive address in bits 0-2 of IY+3
;IY+7 = max heads possible in bits 5-7
;Sets up Heads in use message
;Sets IY+1&2 to existing driver address if found
;Sets used bits in (BITMAP)
;Sets (MAXHDS) = total heads
;Sets IY+0 = free heads
;*=*=*
;       P/u # of heads on the drive & init checks
;*=*=*
SETMAP	LD	A,(IY+7)	;P/u Maximum heads
	RLCA			;Shift into 0-2
	RLCA
	RLCA
	AND	7		;Mask off Max sector #
	INC	A		;Adjust for zero offset
	LD	(MAXHDS),A	;Save for later
	LD	B,A
;*=*=*
;       Adjust heads in use message
;*=*=*
	LD	HL,INUSE$
	LD	A,8
	SUB	B		;Calc index into msg
	JR	Z,GOT8HDS
	LD	B,A
	PUSH	HL		;Save start of message
BLP	INC	HL		;Bump msg pointer 2
	INC	HL		;  bytes per head loss
	DJNZ	BLP
	POP	DE		;Recover start of msg
	LD	BC,HEADS$-INUSE$
	LDIR			;Reposition message
;*=*=*
GOT8HDS	LD	DE,0		;Init count & bitmap
	LD	A,(RESNUM)	;How many active
	OR	A
	JR	Z,NORES
	LD	B,A
	LD	HL,DCTPTR	;=>saved addresses
HCLP	PUSH	BC		;Save loop counter
	LD	C,(HL)
	INC	HL
	LD	B,(HL)		;P/u DCT address
	INC	HL
	PUSH	HL		;Save ptr to next entry
	PUSH	BC
	POP	IX		;Xfer to IX
	LD	A,(IX+1)	;Move address of driver
	LD	(IY+1),A	;To new DCT
	LD	A,(IX+2)
	LD	(IY+2),A
	CALL	CNTHDS		;Add 'em up
	POP	HL
	POP	BC
	DJNZ	HCLP
	LD	A,E
	LD	(BITMAP),A
;*=*=*
;  check for heads in use past entered total
;*=*=*
	LD	A,(MAXHDS)	;Entered #
	DEC	A		;Offset fm 0
TSTHGH	CP	7		;Max of 8
	JR	Z,NORES		;All OK
	INC	A		;Check each past total
	LD	C,A
	CALL	BITBIT		;For in-use
	JP	NZ,BADTOT	;Abort if any
	LD	A,C
	JR	TSTHGH		;Check up to 8
;
NORES	LD	A,(MAXHDS)	;P/u maximum
	LD	L,A		;Save
	SUB	D		;Calculate the quantity
	JP	Z,NOHEAD	;Go if none remaining
;Find largest group of contiguous heads
	LD	BC,0		;Init count
	XOR	A		;Start w/0
CNTH1	LD	H,A		;Save hd posn
	CALL	BITBIT		;Head available?
	JR	Z,CNTH3		;Yes, count it
	LD	C,0		;Reset for hd in use
CNTH2	LD	A,H		;Head posn
	INC	A		;Bits are offset fm 0
	CP	L		;So matching w/maxhds
	JR	NZ,CNTH1	;Means we are done
	LD	A,B		;Get max count
	JR	GOTMX
CNTH3	INC	C		;Count free head
	LD	A,C
	CP	B		;Move highest contiguous
	JR	C,CNTH2		;Count into B
	LD	B,C		;If B was less
	JR	CNTH2
;Max of 4 heads if double tracking...
GOTMX	CP	4+1
	JR	C,SETMX		;OK if 4 or less
	BIT	5,(IY+4)	;Is double bit set?
	JR	Z,SETMX		;8 OK if not
	LD	A,4		;Else set max 4 for partition
SETMX	LD	(IY+0),A	;Save user limit
	ADD	A,'0'		;Adjust to ASCII
	LD	(HEADS1$),A	;Update the message
;*=*=*
;       Adjust heads in use message
;*=*=*
	LD	HL,INUSE$
	LD	A,'1'		;Init to head '1'
	LD	B,8
MODHD	RRC	E		;If bit set, stuff msg
	JR	NC,$+3
	LD	(HL),A		;Show head in use
	INC	HL
	INC	HL		;Bump to next pos
	INC	A		;Bump ASCII head #
	DJNZ	MODHD
	RET
;
CNTHDS	LD	A,(IX)		;Don't use any drive
	CP	0C9H		;  that's disabled
	RET	Z
	LD	A,(IX+DRVSEL)	;Check if this matches
	AND	3		;  the drive #
	LD	C,A		;P/u drive requested
	LD	A,(IY+DRVSEL)
	AND	3		;Check if same
	CP	C		;Match up yet?
	RET	NZ		;Skip if different unit
;
;       IF      ARM!ARMM
;       LD      A,(IX+5)        ;P/u the controller
;       CP      (IY+5-3)        ;  address & check
;       RET     NZ              ;  for a match
;       ENDIF
;
	LD	A,(IX+7)	;Accumulate the number
	RLCA			;  of heads already
	RLCA			;  in use
	RLCA
	AND	7
	INC	A		;Adjust for zero offset
	LD	B,A		;Set new head set loop
	ADD	A,D
	LD	D,A		;Set new total heads
;*=*=*
;       Merge bit map into E reg
;*=*=*
	LD	A,(IX+4)	;P/u starting head
	AND	0FH		;Remove other junk
SETHDS	PUSH	AF		;Save head number
	CALL	SETBIT		;Turn on reg E bit
	POP	AF		;  corresponding to #
	INC	A		;Bump head number
	DJNZ	SETHDS		;Loop for all heads used
	RET
;*=*=*
;       Test if user entry conflicts with head map
;       A=starting head #
;*=*=*
FREE	LD	C,A		;Starting # (-1)
	LD	A,(NUMHDS)	;P/u # of heads
	ADD	A,C		;Add to start posn
	LD	B,A		;Ending head #
	LD	A,(MAXHDS)	;P/u max heads
	CP	B		;Will last head be OK?
	JR	C,BDHD		;Go if bad entry
	LD	A,C		;Retrieve number-1
	LD	E,0		;P/u in-use head map
BITMAP	EQU	$-1
	LD	B,0		;P/u # of heads user req
NUMHDS	EQU	$-1
TSTHDS	LD	C,A		;Save for test
	CALL	BITBIT		;Head bit in use?
	LD	A,C
	JR	NZ,ISUSED	;Go if already used
	INC	A		;Bump head pointer
	DJNZ	TSTHDS		;Loop for # of heads
	XOR	A
	RET			;Z=no conflict
ISUSED	LD	HL,HDBAD$	;Show conflict
	CALL	@DSPLY
BDHD	OR	0FFH
	RET			;W/NZ for error
;
;*=*=*
;INSTALL - move driver if necessary 
; put JP into (IY)
;  move DCT=>IY into address fm (DCTADD)
;*=*=*
INSTALL	LD	(IY),0C3H	;Stuff JP
	LD	A,(RESNUM)
	OR	A		;Is a copy loaded?
	JR	NZ,ISRES	;Then don't re-load
;*=*=*
	IFDEF	LINK		;If driver has LINK defined...
	CALL	INIT		;Init drv before moving driver
;       Move @ICNFG vector into driver next
;*=*=*
	LD	A,(@ICNFG)	;Get opcode
	LD	(LINK),A
	LD	HL,(@ICNFG+1)	;Get address
	LD	(LINK+1),HL
	ENDIF
;
;*=*=*
;       Relocate internal references in driver
;*=*=*
	LD	IX,RELTAB	;Point to relocation tbl
	LD	HL,(HIGH$)	;Find distance to move
	PUSH	HL		;Save HIGH$
	LD	(DISK+2),HL	;Set last byte used
	LD	DE,DISKEND-1	;Current location
	PUSH	DE
	OR	A		;Clear carry flag
	SBC	HL,DE		;Offset to HL
	LD	B,H		;Move to BC
	LD	C,L
	LD	A,TABLEN	;Get table length
RLOOP	LD	L,(IX)		;Get address to change
	LD	H,(IX+1)
	LD	E,(HL)		;P/U address
	INC	HL
	LD	D,(HL)
	EX	DE,HL		;Offset it
	ADD	HL,BC
	EX	DE,HL
	LD	(HL),D		;And put back
	DEC	HL
	LD	(HL),E
	INC	IX
	INC	IX
	DEC	A
	JR	NZ,RLOOP	;Loop till done
;*=*=*
	IFDEF	LINK
;       Set up @ICNFG
;*=*=*
	LD	HL,INIT		;Get entry pt
	ADD	HL,BC		;Relocate it
	LD	(@ICNFG+1),HL	;Init address
	LD	A,0C3H
	LD	(@ICNFG),A	;Stuff JP instruction
	ENDIF
;
;*=*=*
;       Move driver
;*=*=*
	POP	HL		;Current posn
	POP	DE		;HIGH$
	LD	BC,DISKEND-DISK	;Calc driver length
	LDDR			;Move it
	LD	(HIGH$),DE	;Reset HIGH$
	INC	DE		;Move to entry pt
	LD	(IY+1),E	;Driver LSB
	LD	(IY+2),D	;Driver MSB
;
ISRES	PUSH	IY
	POP	HL		;Prepare to move DCT
	LD	DE,(DCTADD)	;To requested position
	PUSH	DE		;%
	LD	BC,10
	LDIR
	POP	IY		; IY=>real DCT
;*=*=*
; log in correct dir cyl if possible
;*=*=*
	LD	DE,0		;Read BOOT
	LD	HL,SECBUF
	CALL	READS		;Get if formatted
	JR	NZ,NOFMT
	LD	A,(SECBUF+2)	;Get possible dir cyl
	CP	(IY+6)
	JR	NC,NOFMT
	LD	D,A		;Dir cyl
	CALL	READS
	JR	NZ,NOFMT
	LD	A,'/'
	LD	HL,SECBUF+0DAH	;Date field
	CP	(HL)
	JR	NZ,NOFMT
	LD	HL,SECBUF+0DDH	;Second slash
	CP	(HL)
	JR	NZ,NOFMT
	LD	(IY+9),D	;Stuff correct DIR cyl..
	RET
READS	LD	B,9		;READ command
	CALL	DOIO
	RET	Z		;Normal status
	CP	6		; or DIR cyl OK
	RET
DOIO	JP	(IY)		;Do it
NOFMT	LD	HL,NOFMT$
	CALL	@LOGOT
	RET			;%
;
;*=*=*
;       Routine to convert ascii =>HL to number in BC
;*=*=*
DECHEX	LD	DE,0		;Clear to start
CVDEC	LD	A,(HL)		;P/u char
	SUB	30H		;To BCD
	CP	10		;Must be less
	JR	NC,DONECON	;End if not digit
	PUSH	HL		;Save ascii ptr
	LD	H,D
	LD	L,E		;Merge digit
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,DE
	ADD	HL,HL
	EX	DE,HL
	ADD	A,E
	LD	E,A
	LD	A,0
	ADC	A,D
	LD	D,A
	POP	HL
	INC	HL		;Next char
	JR	CVDEC
DONECON	PUSH	DE
	POP	BC		;Put answer in BC
	RET
;*=*=*
;       Routine to divide HL by C
DIV16	LD	A,C
	CALL	@DIV
	RET
;*=*=*
;       Routine to parse user input parameter
;*=*=*
GETARG	LD	B,1
GETARGX	CALL	@DSPLY		;Display message
KEYIN	LD	HL,KEYBUF$
	CALL	@KEYIN		;Fetch user response
	JP	C,ABTJOB	;Break?
	LD	A,(HL)		;Load value
	RET
;*=*=*
BEGIN
	LD	(DCTADD),DE	;Save passed DCT ptr
	PUSH	DE		;Save DCT address
	LD	HL,HELLO$
	CALL	@DSPLY		;Welcome the user
;*=*=*
;       Check if requested drive slot is available
;*=*=*
	POP	DE
	LD	A,(DE)		;P/u vector OP
	CP	0C9H		;RET = disabled
	JP	NZ,CANTDO	;No good if not RET
;*=*=*
;Look for existing driver
;*=*=*
	LD	IY,DCT$		;Start of DCT$
	LD	IX,DCTPTR	;Save matching DCTs
	LD	B,8		;# of DCTs
TSTDCT	LD	L,(IY+1)
	LD	H,(IY+2)	;Point to driver vector
	PUSH	BC
	INC	HL		;  in DCT & see if res
	INC	HL		;Point to name length
	INC	HL
	INC	HL
	LD	DE,DISK+4	;Point to this namlen
	LD	A,(DE)		;P/u length & match
	CP	(HL)		;  with resident driver
	JR	NZ,NOTRES	;Go if dif lengths
	INC	HL		;Advance to name field
	INC	DE
	LD	B,A		;Set compare length
TSTNAM	LD	A,(DE)		;Match this driver to
	CP	(HL)		;  resident vector
	JR	NZ,NOTRES
	INC	DE		;Bump to next char
	INC	HL
	DJNZ	TSTNAM		;Loop for name length
;Count and save DCT posns w/same driver
	LD	A,(RESNUM)	;Get count so far
	INC	A
	LD	(RESNUM),A
	PUSH	IY
	POP	HL		;DCT address
	LD	(IX),L
	INC	IX
	LD	(IX),H
	INC	IX
;
NOTRES	LD	BC,10
	ADD	IY,BC		;Move to next DCT posn
	POP	BC		;Recover count
	DJNZ	TSTDCT		;Do all 8
;
	JP	USER		;Go get input
;*=*=*
;       Error exits
;*=*=*
CANTDO	LD	HL,CANTDO$
	DB	0DDH
ABTJOB	LD	HL,ABTJOB$
	DB	0DDH
NOHEAD	LD	HL,NOHEAD$
	DB	0DDH
BADTOT	LD	HL,BADTOT$
ABORTL	CALL	@LOGOT
	JP	@ABORT
; abort instead or re-prompt if JCL running
ABTJCL	PUSH	AF
	PUSH	HL
	LD	A,(SFLAG$)
	BIT	5,A		;JCL active?
	LD	HL,JCLAB$	;=>msg
	JR	NZ,ABORTL	;Log out
	POP	HL		;Else restore regs
	POP	AF
	RET
;*=*=*
;       Messages & Data tables
;*=*=*
;
NOFMT$	DB	LF,'Note: Drive appears to be unformatted.',CR	;%
JCLAB$	DB	LF,'Incorrect entry from JCL.',CR
HEADMP$	DB	'Heads already in use <'
INUSE$	DB	'.-.-.-.-.-.-.-.>',CR
HEADS$	DB	'Enter number of heads for partition <1-'
HEADS1$	DB	'X> ',3
STRTHD$	DB	'Enter starting head: ',3
HDBAD$	DB	'Heads requested conflict with '
	DB	'heads in-use.',CR
NOHEAD$	DB	'No heads available on that drive.',CR
BADTOT$	DB	'Drive has heads in use higher'
	DB	' than entered total.',CR
ABTJOB$	DB	'Manual abort - Job terminated.',CR
CANTDO$	DB	'Requested drive slot already in use.',CR
MAXHDS	DB	0		;Total heads on drive
RESNUM	DB	0		;Count of DCT's using this driver
DCTPTR	DW	0,0,0,0,0,0,0	;Addresses
LCPTR	DW	0		;Save area for low mem ptr address
DCTADD	DW	0		;Address for this DCT
SECBUF	DS	256		;Use to log drive
KEYBUF$	EQU	$
;*=*=*
	END	BEGIN
