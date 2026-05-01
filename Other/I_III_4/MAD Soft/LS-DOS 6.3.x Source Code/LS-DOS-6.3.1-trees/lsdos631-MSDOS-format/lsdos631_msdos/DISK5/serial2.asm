;SERIAL2 - '86
;DUPE/QFB/5.1/6.x    - 11/09/83
;*=*=*=*=*=*=*=*=*=*==*=*
;(CURDRV) is offset into active drive list
;And DCT pointer table
;(CURDRV)=0 means start or end of active drives
;
;Take (CURDRV) and increment until a match is
;Found in active list
;When end reached, set (CURDRV)=0 and ret w/Z flag
GETDCT1	LD	B,0
	LD	A,(CURDRV)	;Offset into actlst
BMP	INC	A		;Move to next
	LD	C,A		;Range 1-7
	IF	DUPE
	SUB	8		;Too far?
	ELSE
	SUB	2		;QFB only has one
	ENDIF
	JR	Z,ENDRV		;End of list/set 0
	LD	HL,ACTLST-1	;Table of dest disks
	ADD	HL,BC		;Index to drv #
	LD	A,(HL)		;Is this one active now?
	OR	A
	LD	A,C
	JR	Z,BMP		;Nope, try next one
ENDRV	LD	(CURDRV),A	;Store current drive
	RET	Z		; if no more dest drvs
	PUSH	AF		;Save offset
	LD	A,(HL)		;P/u drv #
	LD	(MYDRV),A	;Save for serial error
	OR	7		;Mask
	LD	(DRVNO),A	;Store..
	LD	HL,DSTDCT-2	;Now point IY to DCT
	POP	AF
	ADD	A,A		;Double offset for address
	LD	C,A
	ADD	HL,BC		;Index to entry
GOTDCT	LD	C,(HL)		;Ld into BC
	INC	HL
	LD	B,(HL)
	PUSH	BC
	POP	IY		;Trans to IY
	RET			;Will be NZ
;
MYDRV	DB	0
;
;************
CALCSEC	LD	A,(IY+7)	;High sec/trk
	AND	00001111B	;Info
	INC	A		;Make real number
	LD	(SECTRK),A	;Save that
	BIT	5,(IY+4)	;Two sided?
	JR	Z,NTTWO		;Nope
	ADD	A,A
NTTWO	LD	(SECCYL),A
	LD	D,A		;X256 bytes per
	INC	D		;Plus space for cksums
	INC	D		;And extra ffs for trk buff
	LD	E,0
	LD	HL,TRKBUF	;Start of format buffer
	ADD	HL,DE		;Pt to last addr needed
	LD	D,H		;Xfer to reg DE
	LD	E,L
	LD	HL,(MYHIGH)	;Make sure it won't wrap
	XOR	A
	SBC	HL,DE
	LD	HL,NOMEM$	;Init "insufficient mem..
	JP	C,ABT1
; point to correct formatting table
	LD	A,(SFLAG$)	;Get FAST/SLOW
SFLAG	EQU	$-2		;Modify for mod1/6.x
	LD	C,A
	LD	A,(IY+3)	;Get disk type
	LD	HL,S5TBL	;5",sden
	BIT	5,A		;If 8" drive
	JR	Z,ISFIVE	;Go if only 5"
	LD	HL,S8TBL	;8" drives sden
	BIT	6,A
	JR	Z,SETTBL	;If SDEN
	LD	HL,D8TBL	;Else DDEN, test speed
	BIT	3,C		;FAST?
	JR	Z,SETTBL	;Go if slow
	LD	HL,D8TBLF	
	JR	SETTBL
ISFIVE	BIT	6,A		;Sden?
	JR	Z,SETTBL	;Then set it
	LD	HL,D5TBL	;Else dden
	BIT	3,C
	JR	Z,SETTBL	;Go if slow
	LD	HL,D5TBLF	;Else set for FAST
SETTBL	LD	(FMTBL),HL	;Stuff for later use
	RET
;*****
;       routine to convert (HL) to binary
;*****
CVBIN	LD	E,0
CVB1	LD	A,(HL)
	INC	HL
	SUB	30H
	LD	B,A
	CP	0AH
	LD	A,E
	RET	NC
	ADD	A,A
	ADD	A,A
	ADD	A,E
	ADD	A,A
	ADD	A,B
	LD	E,A
	JR	CVB1
;*****
STUFFDR	DEC	HL		;Start here if fm INKEY
STFDRV	INC	HL		;       
	LD	A,(HL)
	CP	'('		;Start of params?
	RET	Z
	CP	CR
	RET	Z
	CP	':'
	JR	Z,STFDRV
	CP	'0'
	JR	C,STFDRV	;Skip nonsense
	CP	'8'		;Make sure not > 7
	JP	NC,BDNMB
	LD	(DE),A		;Stuff drive #
	INC	DE
	PUSH	HL
	XOR	A
	IF	DUPE
	LD	HL,DRVLST+8	;Limit to 8 drives total
	ELSE
	LD	HL,DRVLST+2	;Only 2 for QFB!
	ENDIF
	SBC	HL,DE
	POP	HL
	JR	NZ,STFDRV
BDNMB	OR	A
	RET
; get Y/N resp - ret w a=0 for N, FFH for Y
GETYN	LD	B,1		;One char max
	PUSH	HL
	CALL	GETRESP		;Get it
	POP	HL		;Restore for possible repeat
	JP	C,EXITA		;Break pressed
	CP	'N'		;No?
	JR	NZ,CKY		;Ck for Y if not
	XOR	A		;Ret 0
	RET
CKY	CP	'Y'		;Is it yes?
	JR	NZ,GETYN	;No, ask again
	LD	A,0FFH		;Else 0FFH
	RET
;
GETRESP	PUSH	DE		;Save DE
	CALL	@DSPLY		;Print prompt =>HL
	LD	HL,INBUF
	CALL	@KEYIN		;Get ans/len fm B
	POP	DE
	RET	C		;Break pressed/ret
	LD	A,(HL)		;Get 1st char
	AND	5FH		;Make UC in A
	RET
;
SERCHK	LD	HL,ERRCNT
	LD	A,(HL)
	LD	(HL),0
	OR	A
	RET	Z
	CALL	READSOR		;Try same trk once
	LD	HL,ERRCNT
	LD	A,(HL)
	LD	(HL),0
	OR	A		;Continue if no error
	RET	Z
	LD	HL,DABT$	;Else prompt
	CALL	@DSPLY
KLP	CALL	@KEY		;Wait for response
	CP	BREAK
	JP	Z,ABT2		;Break - quit
	CP	CR
	JR	NZ,KLP
	XOR	A		;Enter -
	LD	(PASS1),A	;Re-build chsum tbl
	JP	REPEAT		;Re-log and retry
;
ERRCHK	LD	HL,ERRCNT
	LD	A,(HL)		;Get errors
	LD	(HL),0		;Clear
	OR	A		;Ret if none
	RET	Z		;Lockout if any errors
;
LOCKOUT	PUSH	HL
	PUSH	DE
	LD	HL,DRVLKD$	;Prnt msg
	CALL	@DSPLY
	LD	A,(CURDRV)	;Drive offset in
	LD	D,0
	LD	E,A
	LD	HL,ACTLST-1	;Active table
	ADD	HL,DE		;Move to posn
	LD	A,(HL)		;Get ascii #
	LD	(HL),0		;Stuff 0
	CALL	@DSP		;Show #
	LD	A,CR
	CALL	@DSP
	POP	DE
	POP	HL
	OR	0FFH		;Set NZ
	RET
;*****
;       parm error exit
;*****
NOTWP	LD	HL,SWP$
	DB	0DDH
TYPERR	LD	HL,TYPE$
	DB	0DDH
NOTHARD	LD	HL,HARD$
	CALL	@LOGOT
M3	EQU	$-2
	JP	EXITA
PRMERR	LD	HL,PRMERR$	;Only called before changing
	CALL	@DSPLY		;@RST38, DCTs etc.
	JP	@ABORT
;*****
PTABLE
	DB	'QUERY '
	DW	QPARM
	DB	'Q     '
	DW	QPARM
	DB	'ALL   '
	DW	GATP
	DB	'A     '
	DW	GATP
	DB	'V1    '
	DW	V1P
	DB	'V2    '
	DW	V2P
	NOP
;
CLEAR	LD	HL,NOPARMS	;Restore default parms
	LD	DE,GATP
	LD	BC,8
	LDIR
CLEAR2	LD	HL,GATP+8
	IF	DUPE
	LD	B,33
	ELSE
	LD	B,9
	ENDIF
CLR1	LD	(HL),0		;And clear drive entries
	INC	HL
	DJNZ	CLR1
	RET
;
NOPARMS	DW	01,0FF01H,01,0FFFFH	;Reset parms for repeat
;Storage for parms
GATP	DW	1		;Check low byte for entry test
GAT?	EQU	$-1		;Use high byte later
V1P	DW	0FF01H		;Default to ON
V1P?	EQU	$-1		;High byte
V2P	DW	0001H		;Default to OFF
V2P?	EQU	$-1		;High byte
QPARM	DW	0		;Default OFF
DRVLST	DB	0,0		;Source/dest numbers
	IF	DUPE
	DB	0,0,0,0,0,0
	ENDIF
	DB	0		;End of list
ACTLST	DB	0		;Active destinations
	IF	DUPE
	DB	0,0,0,0,0,0
	ENDIF
	DB	0		;Need spare for terminator
SORDCT	DW	0		;DCT for source disk
DSTDCT	DW	0
	IF	DUPE
	DW	0,0,0,0,0,0	;Table of DCTs for copy
	ENDIF
DCTPTR	DW	0
MYHIGH	DW	0
SVTRK0	DB	0		;Iy+3 after BOOT read
COUNT	DW	0		;Number of good disks so far
PASS1	DB	0		;First read of source disk?
READ	DB	0		;FF=read 1=ver 0=write
ERRCNT	DB	0
RETRY	DB	0
STACK	DS	2
CURCYL	DS	1
CURDRV	DS	1
TMPDCT$	DS	10*8		;Save area for DCT's
INBUF	DS	32		;To receive input
PRMERR$	DM	'Parameter error',CR
	IF	V5
	IF	DUPE
HELLO$	DM	28,31,'DISKDUPER - LDOS Disk Duplicator'
	DM	' Program - Version 5.1.g',10
	ELSE
HELLO$	DB	28,31,'QFB - LDOS Quick Format and Backup'
	DB	' Program - Version 5.1.g',10
	ENDIF
	DB	'Copyright 1983 by Logical Systems Inc. All rights reserved.',10,13
	ENDIF
	IF	V6
	IF	DUPE
HELLO$	DM	28,31,'DISKDUPE'
	ELSE
HELLO$	DB	28,31,'QFB'
	ENDIF
	DM	' - For production of LD-DOS 6.3.0 / Level "L" - 07/01/87',10
*GET	CLIENT:3
	ENDIF
	DB	'                      '	;Patch space
NOMEM$	DM	'Insufficient memory for '
	DB	'specified drive!',CR
SPRMPT$	DB	'Source drive ? ',3
DPRMPT$	DM	'Destination drive'
	IF	DUPE
	DB	'(s)'
	ENDIF
	DB	' ? ',3
NTRDY$	DM	'Source Disk not ready!',CR
PMTDST$	DM	'Load diskettes and press <ENTER>',LF,CR
HARD$	DB	'This program requires floppy disks!',CR
MATCH$	DB	'Source and destinations drives are the same!',CR
GPRMPT$	DB	'Duplicate unallocated tracks? (Y/N) ',3
VP1$	DB	'Verify on same pass? (Y/N) ',3
VP2$	DB	'Verify on second pass? (Y/N) ',3
TYPE$	DB	'Incorrect destination drive type!',CR
SWP$	DB	'Destination drive has software'
	DB	' write-protect!',CR
INVAL$	DB	'Invalid drive entry!',CR
DRVLKD$	DB	'  =========> Bad disk in drive ',3
DPRPPT$	DB	LF,LF,'Duplication complete '
DCNT	DB	'      disk'
PLURAL	DB	'  created'
	DB	' - Last Serial # used '
DSBUFF	DB	'      ',CR
RPDSK$	DB	LF,'Replace destination disk'
	IF	DUPE
	DB	's'
	ENDIF
	DB	' and press <ENTER> to repeat',LF
	DB	' ..<R> to restart with new parameters',LF
	DB	'   ...or....<BREAK> to exit program.',CR
;*=*=*
;
CKDRV1	XOR	A
	BIT	4,(IY+4)	;Alien controller?
	JR	NZ,FAKE		;Skip test if so
	CALL	RESTOR		;Load head
	LD	BC,TIME
CK1	CALL	INDEX
	JR	NZ,CK1		;Get no pulse
CK2	CALL	INDEX
	JR	Z,CK2		;Get pulse
CK3	CALL	INDEX
	JR	NZ,CK3		;Get no pulse
	RET
;
INDEX	LD	A,B		;Get time
	OR	C		;Interval expired?
	EX	(SP),HL
	EX	(SP),HL
	DEC	BC
	JR	Z,ILLG1
	CALL	RSELCT		;TSTBSY
	BIT	1,A		;Test for index pulse
	RET
;
ILLG1	POP	HL		;Fix stack
ILLEG	LD	A,32		;'illegal drv #'
FAKE	OR	A
	RET
;
;Format one cylinder
FORMCYL	LD	A,(CURCYL)	;Is this cyl..
	LD	C,A		;0? - test later..
;
NDATA	LD	DE,0		;P/u disk type table
FMTBL	EQU	$-2
	LD	A,(DE)		;P/u # of sectors to fmt
	INC	DE		;Adj for zero offset
	LD	(SECTRK),A
	LD	B,A
	BIT	5,(IY+4)	;Need twice as many
	JR	Z,NT2		;If 2-sided drive
	ADD	A,A
NT2	LD	(SECCYL),A	;Then double
;
	LD	A,(DE)		;P/u track skew (3,5,2,3)
	INC	DE
	LD	(TRKSKEW+1),A
	INC	C
	DEC	C		;Is this trk 0?
	JR	NZ,LEAVSK	;Then don't chg skew
	LD	(SECSKEW+1),DE	;Format sector skew
LEAVSK	INC	A		;Add DE -> begin of sec #
	ADD	A,B		;B -> # of sectors/side
	ADD	A,E		; A+1 -> a code byte
	LD	E,A
	ADC	A,D
	SUB	E
	LD	D,A
	LD	HL,TRKBUF
	LD	BC,SECBUF
;*****
;       create the formatting data
;*****
FMTDAT	LD	A,(DE)		;P/u table format byte
	INC	DE
	CP	0F1H		;Start of sector header
	JR	Z,CODF1
	CP	0F2H		;Start of track trailer
	JR	Z,CODF2
	CP	0F3H		;Start of track ID info
	JR	Z,CODF3
	CP	0F4H		;End of table parms?
	JR	Z,CODF4
	CP	0F5H
	PUSH	BC
	JR	NZ,CODE1
	LD	A,(DE)
	INC	DE
	LD	B,A		;Xfer header count
	LD	A,(DE)		;P/u a header byte
	INC	DE
	LD	C,A		;Xfer 1st byte
	LD	A,(DE)		;P/u 2nd byte
CODF5	LD	(HL),C		;Stuff into buf
	INC	HL
	LD	(HL),A
	INC	HL
	DJNZ	CODF5
	JR	CODRET
CODE1	LD	B,A
	LD	A,(DE)
CODE1A	LD	(HL),A		;Fill buf with byte
	INC	HL
	DJNZ	CODE1A
CODRET	POP	BC
	INC	DE
	JR	FMTDAT
CODF1	LD	A,(SECTRK)	;P/u # of sectors/side
CODF1A	PUSH	DE		;Save table pointer
	PUSH	AF		;Save value
	JR	FMTDAT
CODF2	POP	AF		;Count down the # of
	DEC	A		;Sectors to format
	JR	Z,CODF2A
	POP	DE		;Loop if not finished
	JR	CODF1A
CODF2A	POP	AF
	JR	FMTDAT
CODF3	LD	A,L		;Stuff pointer to where
	LD	(BC),A		;Track & sector info
	INC	BC		;Is to be placed
	LD	A,H
	LD	(BC),A
	INC	BC
	JR	FMTDAT
CODF4	LD	(VERSKEW+1),DE	;Verify sector skew
	XOR	A		;Stuff two X'00's to
	LD	(BC),A		;Indicate the end
	INC	BC
	LD	(BC),A
	LD	B,0		;Now give it 256 X'FF's
	LD	A,0FFH
	LD	(HL),A
	INC	HL
	DJNZ	$-2
;*=*=*
;       Begin the formatting
;*=*=*
	LD	HL,FMTCYL$	;"formatting clinder...
	CALL	@DSPLY
BGNFMT	LD	A,(IY+5)	;P/u cylinder position
	CALL	CVDEC		;Cvrt to decimal
	CALL	DSPCYL
	RES	4,(IY+3)	;Start on front side
SECSKEW	LD	BC,0		;Begin of sector table
BFMT1	LD	HL,SECBUF	;P/u ptr to memory 
BFMT2	LD	E,(HL)		;Positions having sector
	INC	HL		;& cylinder info to be
	LD	D,(HL)		;Stuffed into format data
	INC	HL
	LD	A,D		;Finished?
	OR	E
	JR	Z,BFMT4
	LD	A,(IY+5)	;P/u cylinder
	LD	(DE),A		;Cylinder # into format data
	INC	DE
	LD	A,(IY+3)	;Stuff the side-select
	AND	10H		; bit
	RRCA
	RRCA
	RRCA
	RRCA
	LD	(DE),A
	INC	DE
	LD	A,(BC)		;P/u the sector number
	OR	A
	JP	P,BFMT3		;Bypass if a sector #
	ADD	A,C		;Calculate the beginning
	LD	C,A		;Of the sector table
	JR	C,BFMT3
	DEC	B
BFMT3	LD	A,(BC)
	LD	(DE),A		;Stuff the sector #
	INC	DE
	INC	BC
	JR	BFMT2
;
BFMT4	LD	(SECSKEW+1),BC	;Save end of sector table
WRFMT	LD	A,(CURCYL)
	LD	D,A		;Be sure trk # loaded
	LD	E,0
	PUSH	DE
	BIT	4,(IY+3)	;Front side?
	JR	NZ,USESEL	;Dont SEEK on 2nd side
	CALL	SEEK		;Drive select w/head load
	JR	TSB		;Use only 1st time
USESEL	CALL	SELECT		;If on side 2
TSB	CALL	RSELCT		;Wait till ready
	PUSH	BC
	LD	BC,600		;Small delay
	CALL	@PAUSE
	POP	BC
	POP	DE
	LD	HL,TRKBUF	;Pt to format data
	CALL	WRCYL		;Cylinder write
	CALL	NZ,BMPERR
	PUSH	BC
	LD	BC,200		;Short delay after write
	CALL	@PAUSE
	POP	BC
	BIT	5,(IY+4)	;Double sided?
	JR	Z,BFMT5		;Done if not
	BIT	4,(IY+3)	;Flip bit for 2nd side
	JR	NZ,BFMT5	;If not already on it,
	SET	4,(IY+3)	;Else bypass and go to next
	INC	BC		;Bump to start side 2
	JR	BFMT1		;At different sector #
;
BFMT5	RES	4,(IY+3)	;Turn off side 2
;
TRKSKEW	LD	A,0		;P/u the track skew byte
	ADD	A,C		;Repoint to beginning
	LD	C,A		;Of sector table
	ADC	A,B		;Skew start of next track
	SUB	C
	LD	B,A
	LD	(SECSKEW+1),BC
	RET			;This cyl is formatted
;*****
;Trk 0 will never be locked out except on special disks
GATCHK	LD	A,(CURCYL)	;Get current cylinder
	LD	L,A		;Into L
	OR	A		;Trk 0?
	JR	Z,SKPGAT	;If trk 0, ignore param
	LD	A,(GAT?)	;Writing allocated only?
	CP	0FFH
	RET	NZ		;No, do them all
SKPGAT	LD	H,GATBUF<-8	;HL=>allocation byte
	PUSH	HL		;Save
	LD	A,L		;Current cyl
	ADD	A,60H		;Offset to lockout
	LD	L,A		;HL=>lockout byte
	LD	A,(HL)		;Get lockout byte
	POP	HL		;Is it the same as 
	CP	(HL)		;The allocation byte
	RET			;Z=no data there
;*****
WRTOUT	CALL	GATCHK		;Need this one?
	RET	Z		;Skip if not
	LD	HL,WRIT$
	CALL	@DSPLY
	XOR	A
	LD	(READ),A	;Flag not a read
	CALL	RWTRK
	RET
;
READCYL	LD	HL,READ$
	CALL	@DSPLY
	LD	A,0FFH		;True
	LD	(READ),A
	CALL	RWTRK
	RET
;
VERCYL	LD	HL,VERCYL$	;"verifying cylinder...
	CALL	@DSPLY
CKSOR	LD	A,01		;Flag verify
	LD	(READ),A
	CALL	RWTRK
	CALL	GATCHK		;Do we have a chksum?
	RET	Z		;If not needed
	CALL	CKTBL		;Is cksum correct?
	RET
;
RWTRK	EXX			;Clr cksum
	LD	BC,0		;For lckd out trks
	EXX
	LD	A,(CURCYL)
	LD	D,A		;Init track ptr
	ADD	A,60H		;Move to lockout
	LD	L,A
	LD	H,GATBUF<-8	;Track & bypass verify
	LD	A,(HL)		;If track not formatted
	INC	A		;FF if locked out
	RET	Z		;Skip locked out trks
	LD	A,D
	CALL	CVDEC		;Cvrt to decimal
	PUSH	DE
	CALL	DSPCYL
	POP	DE
	XOR	A		;Initialize starting
	LD	(BVER5+1),A
	LD	(BVER4+1),A
	CALL	INITTRK		;=>data/clr cksum
VERSKEW	LD	BC,0		;P/u start of sector tbl
BVER3	LD	A,(BC)		;P/u sector #
BVER4	ADD	A,0		;Add in a side's sectors
	LD	E,A		;  if on side 2
	CALL	RWSEC		;Sector read or write
	JR	NZ,BVER9	;Go on error
	INC	BC		;Bump sector table ptr
BVER5	LD	A,0		;P/u sector #
	INC	A		;Bump it up
	LD	(BVER5+1),A	;  and save new #
	LD	E,A		;Xfer to sector register
	LD	A,(SECCYL)	;Is this = a cyl?
	CP	E
	RET	Z		;Go if cyl done
	LD	A,(SECTRK)	;Is this a track's worth?
	CP	E
	JR	NZ,BVER3	;Loop if not
	LD	(BVER4+1),A	;Update the add for side2
	INC	BC
	JR	VERSKEW		;
;*=*=*
;       Got disk error
;*=*=*
BVER9	CALL	BMPERR
	RET
;*****
;Read/write/or verify a sector
RWSEC	LD	A,(READ)	;Reading or writing?
	OR	A
	JR	Z,WRT		;Go if write
	CALL	RDSEC		;Load a sector
	JR	Z,SECOK		;No error
	CP	6		;Dir sec ok
	RET	NZ		;Error?
SECOK	CALL	CKSUM		;Calc cksum/bump H(if not verf)
	XOR	A		;Good read
	RET
;
WRT	LD	A,(IY+9)	;Dir cyl
	CP	D
	JR	NZ,NOTDIR
	CALL	WRSYS
	JR	ISDIR
NOTDIR	CALL	WRSEC
ISDIR	PUSH	AF
	INC	H		;Bmp ptr for next
	POP	AF
	RET
;
	IF	.NOT.DUPE
TUFLUK	LD	HL,TUFF$	;"protected disk"
	ENDIF
;       exit procedures
;*=*=*
ABT1	CALL	@LOGOT		;Some error to abort job
M4	EQU	$-2
ABT2	LD	HL,ABT$
	CALL	@LOGOT
M5	EQU	$-2
	LD	DE,(COUNT)
	LD	A,D
	OR	E
	JR	Z,EXITA
	LD	HL,DCNT
	PUSH	HL
	CALL	HEXDEC
	POP	HL
	CALL	@LOGOT
M6	EQU	$-2
EXITA	CALL	EXIT1		;Clock back on if needed
	JP	@EXIT
;*=*=*
EXIT1	LD	A,0		;P/u orig RST38 vector
	OR	A
	JR	Z,EXIT2
	LD	(@RST38),A	;Restore
	EI
EXIT2	LD	A,CURSON	;Turn cursor on
	CALL	@DSP
	LD	HL,TMPDCT$	;Restore DCT contents
	LD	DE,(DCTPTR)
	LD	B,8
DCTRES	PUSH	DE
	POP	IY
	LD	A,(IY+5)	;Save current head posn
	PUSH	BC
	LD	BC,10
	LDIR
	POP	BC
	LD	(IY+5),A
	DJNZ	DCTRES		;Put other contents back
	LD	HL,PMTSYS$	;"load system disk...
	CALL	@DSPLY
EXIT3	CALL	@KEY		;Request a key
	CP	CR		;Must be <ENTER>
	JR	NZ,EXIT3
	LD	HL,RTCBAD$	;"RTC not accurate...
	CALL	@DSPLY
	RET
;*****
;       disk I/O requests
;*****
DRVNOP	PUSH	BC
	LD	B,0		;No operation
	JR	FMTDR1		;No DI for this one
SELECT	PUSH	BC
	LD	B,1		;Select/status
	JR	FMTDRV
RESTOR	PUSH	BC
	LD	B,4		;Restore to cyl 0
	JR	FMTDRV
STEPIN	PUSH	BC
	LD	BC,100
	CALL	@PAUSE
	LD	B,5		;Step in
	JR	FMTDRV
SEEK	PUSH	BC
	LD	B,6
	JR	FMTDRV
RSELCT	PUSH	BC
	LD	B,7		;Tstbsy
	JR	FMTDRV
WRCYL	PUSH	BC
	LD	B,15		;Write track
	JR	FMTDRV
FMTHD	PUSH	BC
	LD	B,12		;Format hard disk
	JR	FMTDRV
WRSEC	PUSH	BC
	LD	B,13		;Write data sector
	JR	FMTDRV
WRSYS	PUSH	BC
	LD	B,14		;Write system sector
	JR	FMTDRV
RDSEC	PUSH	BC
	LD	B,9		;Read data sector
	JR	FMTDRV
VERSEC	PUSH	BC
	LD	B,10		;Verify a sector
	JR	FMTDRV
;*****
FMTDRV	DI			;For speed
FMTDR1	LD	C,$-$		;P/u drive #
DRVNO	EQU	$-1
	LD	A,32		;Init to illegal drive
	OR	A
	CALL	GOIO		;Go after DCT vector
	POP	BC
	EI			;Allow mod 2 kbd to work
	RET
GOIO	JP	(IY)		;Vector to DCT
;
BMPERR	LD	A,(ERRCNT)
	INC	A
	LD	(ERRCNT),A
	RET
;*****
;       routine to convert reg A to 2 decimal digits
;*****
CVDEC	LD	C,30H
CVD1	SUB	10
	JR	C,CVD2
	INC	C
	JR	CVD1
CVD2	ADD	A,3AH
	LD	B,A
	RET
;*****
;
DSPCYL	LD	A,8		;Back up twice &
	CALL	@DSP		;Output new position
	LD	A,8
	CALL	@DSP
	LD	A,C
	CALL	@DSP
	LD	A,B
	JP	@DSP
;
;	Make ascii serial # from HL
;
*LIST ON
ASCSER
	PUSH	DE
	PUSH	BC
	LD	DE,ASCBUF
	PUSH	DE
	LD	BC,13974	; Adjust serial number
	SBC	HL,BC		; unit number in HL
	@@HEXDEC		;Expand to ascii
	POP	HL
AER	LD	A,(HL)
	CP	20H		;Make spaces '0'
	JR	NZ,AER0
	LD	(HL),'0'
	INC	HL
	JR	AER
AER0	LD	A,R		;Pick odd or even
	AND	0FH
	LD	B,A		;Save tempy
	BIT	1,A
	LD	A,'B'		;Init odd
	LD	C,'7'
	JR	NZ,AER1
	LD	A,'A'
	LD	C,'6'
AER1	LD	DE,SN$
	PUSH	DE		;Save for end
	LD	(DE),A		;Store 1st char
	INC	DE
AER2	LD	A,C
	LD	(DE),A
	INC	DE
	LD	HL,ASCBUF	;Get expanded #
	LD	B,(HL)		;digit 1
	INC	HL
	LD	A,(HL)		;Digit 2
	LD	C,A
	LD	(DE),A
	INC	DE
	LD	A,B
	LD	(DE),A
	INC	DE
	PUSH	DE		;Save serial # ptr
	INC	HL		;Pt to digit 3
	LD	B,(HL)		;Get digit 3
	INC	HL
	LD	E,(HL)		;Digit 4
	INC	HL
	LD	D,(HL)		;Digit 5
	LD	A,E
	ADD	A,D
	SUB	60H
	ADD	A,'A'
	POP	HL		;HL ot serial #
	LD	(HL),A
	INC	HL
	LD	A,C
	SUB	B		;#2-#3
	JR	NC,AER3
	NEG			;Make positive always
AER3	ADD	A,30H
	LD	(HL),A
	INC	HL
	LD	(HL),E		;Digit 4
	INC	HL
	LD	(HL),D
	INC	HL
	LD	A,B
	SUB	30H
	ADD	A,D
	CP	3AH
	JR	C,AER4		;Must be < 10
	SUB	10
AER4	LD	(HL),A
	INC	HL
	LD	(HL),B		;Whew!
	POP	HL
	LD	DE,TRKBUF+SYS0OFF
	LD	BC,10
	LDIR				;Xfer for write
	POP	BC
	POP	DE
	RET
;
ASCBUF	DC	5,20H
;
;	Make compressed serial #
;
CMPSER	PUSH	DE
	PUSH	BC
	INC	HL
	LD	(KEYBUF),HL		;Inc for next
	DEC	HL
	LD	BC,13974
;	ADD	HL,BC
	NOP
	LD	(SNCOMP$),HL
	LD	HL,SNCOMP$
	LD	A,(HL)
	INC	HL
	RRD
	RRC	(HL)
	RRC	(HL)
	RRCA
	RRCA
	LD	D,(HL)
	LD	E,A		;Result to DE
	LD	(TRKBUF+SYS3OFF),DE
	POP	BC
	POP	DE
	RET
;
*LIST OFF
