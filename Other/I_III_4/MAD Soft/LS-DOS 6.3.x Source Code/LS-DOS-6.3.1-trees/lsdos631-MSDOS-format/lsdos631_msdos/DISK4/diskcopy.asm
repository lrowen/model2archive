;DCOPY - Diskcopy for version 6.3
;
;	01/07/87 - Corrected source to include patch #001
	TITLE <DISKCOPY>
;
CR	EQU	13
LF	EQU	10
ETX	EQU	3
BRK	EQU	80H
*GET	BUILDVER/ASM:3		;<631>
*GET SVCMAC
;
	ORG	2600H
;
DSTERR:	LD	HL,DSTERR$
	DB	0DDH
SRCERR:	LD	HL,SRCERR$
	PUSH	AF
	@@LOGOT
	POP	AF
;
IOERR:	OR	0C0H		;Short error
	PUSH	AF
	CALL	SYSTEM		;Get a system disk in
	POP	AF
	LD	C,A
	LD	H,0
	LD	L,A
	@@ERROR
	LD	SP,(SAVSTK)
	JR	EXIT2
ABORT:	LD	HL,-1
	JR	EXIT1
EXIT:	LD	HL,0
EXIT1	LD	SP,$-$
SAVSTK	EQU	$-2
	CALL	SYSTEM		;Get a system disk
EXIT2:	@@CKBRKC
	RET
;
NOMEM:	LD	HL,NOMEM$	;"Out of memory
	DB	0DDH
NOTCMD:	LD	HL,NOTCMD$	;"Not while doing cmndr...
	DB	0DDH
DRVMIS	LD	HL,DRVMIS$	;"Missing drive number...
	DB	0DDH
DUPDRV	LD	HL,DUPDRV$	;"Dest=Source...
	DB	0DDH
NOTIN	LD	HL,NOTIN$
	@@LOGOT
	LD	HL,-1
	LD	SP,(SAVSTK)
	JR	EXIT2
;
ILLEG:	LD	HL,ILLEG$	;"Illegal drive type...
	DB	0DDH
DRVERR:	LD	HL,DRVERR$	;"Drive not ready...
	DB	0DDH
WPERR:	LD	HL,WPERR$	;"Dest is WP...
	DB	0DDH
ABORT1:	LD	HL,ABORT$
	@@LOGOT
	JR	ABORT
;
;
SIGNON$	DB	'DISKCOPY '
*GET CLIENT:3
;
NOMEM$	DB	'Not enough memory to Diskcopy',CR
NOTCMD$	DB	'Diskcopy only valid at DOS level',CR
DRVMIS$	DB	'Missing drive number(s)',CR
DUPDRV$	DB	'Single drive Diskcopy invalid',CR
NOTIN$	DB	'Drive not enabled',CR
ABORT$	DB	LF,LF,'Diskcopy aborted',CR
ILLEG$	DB	'Diskcopy is for 5 inch, double density floppy disks only',CR
DRVERR$	DB	'Drive not ready',CR
WPERR$	DB	'Destination drive is write protected',CR
MOUNT$	DB	'Mount source and destination disks, press'
	DB	' ENTER when ready ',CR
DSTERR$	DB	LF,LF,'Destination disk error',CR
SRCERR$	DB	LF,LF,'Source disk error',CR
DONE$	DB	LF,LF,'Disk copy complete, copy another (Y/N) ? ',LF,CR
SYSTEM$	DB	LF,'Mount SYSTEM disk, press ENTER when ready ',CR
;
;
BEGIN:	@@CKBRKC		;No break down
	JR	Z,BEGINA
	LD	HL,-1
	RET
BEGINA:	LD	(SAVSTK),SP	;Save entry stack
	PUSH	HL
	LD	HL,SIGNON$
	@@DSPLY
	@@FLAGS			;Get the flag table
	LD	A,(IY+'C'-'A')	;Get C flag
	BIT	1,A		;CMNDR?
	JP	NZ,NOTCMD	;Go if it is
	LD	HL,0		;Get high$
	IF	@BLD631
	LD	B,L		;<631>L==0
	ELSE
	LD	B,0
	ENDIF
	@@HIGH$
	LD	DE,ENDLOC	;Get mem needed
	OR	A
	SBC	HL,DE		;See if enuf
	IF	@BLD631
	POP	HL		;<631>Cmdline ptr
	JP	C,NOMEM		;<631>
	ELSE
	JP	C,NOMEM
	POP	HL		;Cmdline ptr
	ENDIF
	CALL	SKPSPC
	CP	':'		;Got a drive spec?
	JP	NZ,DRVMIS	;Bad if not
	LD	A,(HL)		;Get a drive #
	INC	HL
	SUB	30H		;Make binary and ck
	IF	@BLD631
	ELSE
	JP	C,DRVMIS	; range
	ENDIF
	CP	8
	JP	NC,DRVMIS
	LD	(SRCDRV),A	;Save drive #
	LD	C,A
	@@GTDCT
	LD	A,(IY)		;Be sure drive is enabled
	CP	0C9H
	JP	Z,NOTIN
	CALL	SKPSPC
	CP	':'		;Now get 2nd #
	JP	NZ,DRVMIS
	LD	A,(HL)		;Get drive #
	SUB	30H
	IF	@BLD631
	ELSE
	JP	C,DRVMIS
	ENDIF
	CP	8
	JP	NC,DRVMIS
	CP	C		;Same as source?
	JP	Z,DUPDRV	;No can do
	LD	(DSTDRV),A
	LD	C,A
	@@GTDCT
	LD	A,(IY)
	CP	0C9H
	JP	Z,NOTIN
	CALL	GETSYS2		;Be sure ckdrv is resident
;
;	Come here for next disk
;
RESTRT:	CALL	MOUNT		;Have disks mounted
	LD	A,(SRCDRV)	;Now ck drive types
	LD	C,A
	@@GTDCT			;Get the DCT
	LD	(SRCDCT),IY	;Save source
	LD	A,(IY+3)	;Get dct byte
	AND	01101000B	;Hard, 8"
	XOR	40H		;Sden
	JP	NZ,ILLEG	;Was sden, 8", or hard
	BIT	4,(IY+4)	;Alien?
	IF	@BLD631
	NOP			;<631>
	NOP			;<631>
	NOP			;<631>
	ELSE
	JP	NZ,ILLEG
	ENDIF
	PUSH	IY
	LD	A,(IY+9)	;Read in source GAT
	LD	D,A
	IF	@BLD631
	LD	HL,GATBUF	;<631>
	LD	E,L		;<631>L==0
	ELSE
	LD	E,0
	LD	HL,GATBUF
	ENDIF
	@@RDSSC
	JP	NZ,IOERR
	LD	A,(DSTDRV)
	LD	C,A
	@@GTDCT
	LD	(DSTDCT),IY	;Save dest dct
	LD	A,(IY+3)	;Save step and delay
	AND	7
	LD	B,A		; in B
	LD	A,(IY+4)	;Save select
	AND	0FH
	LD	C,A		; in C
	PUSH	IY
	POP	DE		;Pt DE to dct+3
	INC	DE
	INC	DE
	INC	DE
	POP	HL		;Source DCT
	INC	HL
	INC	HL
	INC	HL
	PUSH	BC		;Save dest stuff
	PUSH	DE		;Save dst dct
	LD	BC,7
	LDIR
	POP	DE
	POP	BC
	LD	A,(DE)		;Merge in DST stuf
	AND	078H
	OR	B
	LD	(DE),A
	INC	DE
	LD	A,(DE)
	IF	@BLD631
	AND	060H		;<631>
	ELSE
	AND	070H
	ENDIF
	OR	C
	LD	(DE),A		;Now, dst matches src
	INC	DE
	XOR	A		;Always track 0
	LD	(DE),A
;
;	Set to start
;
	LD	IY,(DSTDCT)
	CALL	SETFMT		;Init the format info
	EXX			;Init alts
	LD	HL,GATBUF	;Used info
	LD	DE,GATBUF+60H	;Lock out table
	EXX
	LD	A,(SECCYL)
	LD	(RDCNT),A	;Set up sector count
	LD	(WRCNT),A
	LD	(VERCNT),A
	LD	B,4		;Get cursor posn
	@@VDCTL
	LD	(CURSOR),HL	;Save for dsply
;
MAINLP:	CALL	BGNFMT		;Format a cyl
	EXX			;Alts in
	LD	A,(DE)		;Ck for lockout on src
	LD	(WASLOK),A	;Show was locked
	INC	DE		;Next track
	CP	0FFH		;If it is, then
	JR	NZ,NOLOCK
	INC	HL		;Must skip this also
	EXX
	JP	DOVER		;Just verify
NOLOCK:	CP	(HL)		;See if in use
	INC	HL
	EXX
	JP	Z,DOVER		;Go if empty
;
;	Not empty or locked, dupe it
;
	LD	HL,RDCYL$
	CALL	MSGOUT
	LD	A,(SRCDRV)
	LD	C,A		;Drive to C
	LD	D,(IY+5)	;Cyl to D
	LD	E,0
	LD	B,$-$
RDCNT	EQU	$-1
	LD	HL,RDBUF	;Where to put it
	LD	A,(IY+9)	;Ck for dir trk
	CP	D
	JR	Z,RDSYS		;Go if dir
RDREG:	@@RDSEC
	JP	NZ,SRCERR
	INC	H
	INC	E
	DJNZ	RDREG
	JR	RDDUN
RDSYS:	@@RDSSC
	JP	NZ,SRCERR
	INC	H
	INC	E
	DJNZ	RDSYS
;
RDDUN:	LD	HL,WRCYL$
	CALL	MSGOUT
	LD	A,(DSTDRV)
	LD	C,A		;Drive to C
	LD	D,(IY+5)	;Cyl
	LD	E,0
	LD	B,$-$		;Sector count
WRCNT	EQU	$-1
	LD	HL,RDBUF	;Pt to data
	LD	A,(IY+9)	;See if dir.
	CP	D
	JR	Z,WRDIR		;Go if it is
WRREG:	@@WRSEC
	JP	NZ,DSTERR
	INC	H
	INC	E
	DJNZ	WRREG
	JR	DOVER
WRDIR:	@@WRSSC
	JP	NZ,DSTERR
	INC	H
	INC	E
	DJNZ	WRDIR
;
DOVER:	LD	HL,VERCYL$
	CALL	MSGOUT
	LD	A,(DSTDRV)
	LD	C,A
	LD	D,(IY+5)	;Get cyl
	LD	E,0
	LD	B,$-$
VERCNT	EQU	$-1
VERLP:	@@VRSEC
	JR	Z,VER1		;Go if ok
	CP	6		;Sys sec?
	JP	Z,VER1		;Is dir, ok
	LD	E,A		;Ok - real error, is src
	LD	A,(WASLOK)	; tracked locked?
	CP	0FFH
	LD	A,E		;Error code back to A
	JR	Z,VER2		;If so, error is ok
	JP	DSTERR		;Else abort
VER1:	INC	E		;Next sector
	DJNZ	VERLP
;
VER2:	LD	A,(IY+6)	;See if at end
	CP	(IY+5)		;Are we??
	JR	Z,ALLDUN	;Go if so
	RES	4,(IY+3)	;Always start on side 1
	CALL	STEPIN		;Next track
	CALL	RSELCT		;Wait for FDC
	JP	NZ,IOERR
	LD	BC,3000/15
	@@PAUSE
	JP	MAINLP
;
ALLDUN:	CALL	RESTOR		;Restore the drive
	LD	HL,DONE$	;Show completed
	@@DSPLY
ALLD1:	@@KEY			;Get a key
	CP	BRK		;If break, done
	JP	Z,EXIT
	OR	20H
	CP	'y'		;Do another?
	JP	Z,RESTRT
	CP	'n'
	JR	NZ,ALLD1
	JP	EXIT
;
;
;
SKPSPC:
	LD	A,(HL)		;Get a char
	INC	HL
	CP	CR+1		;End of line?
	JP	C,DRVMIS	;Bad if so
	CP	' '
	JR	Z,SKPSPC
	RET
;
;	Check and be sure two disks are mounted
;
MOUNT:	LD	HL,MOUNT$	;"Mount disks...
	@@DSPLY
MNT1:	@@KEY			;Get a key
	CP	80H
	JP	Z,ABORT1
	CP	CR
	JR	NZ,MNT1
	LD	A,$-$		;Get source drive
SRCDRV	EQU	$-1
	LD	C,A
	@@CKDRV
	IF	@BLD631
	JR	NZ,MOUNT	;<631>
	ELSE
	JP	NZ,MOUNT
	ENDIF
	LD	A,$-$		;Dest. drive #
DSTDRV	EQU	$-1
	LD	C,A
	IF	@BLD631
	LD	(SETDRV+1),A	;<631>Save in i/o routine
	ELSE
	LD	(FMTDRV+1),A	;Save in i/o routine
	ENDIF
	@@GTDCT
	LD	A,(IY)		;Drive enabled?
	CP	0C9H		;Disabled?
	JP	Z,DRVERR
	BIT	3,(IY+3)	;Hard?
	JP	NZ,ILLEG
	BIT	4,(IY+4)	;Alien?
	JP	NZ,ILLEG
	CALL	RESTOR		;Restore the drive
	JP	NZ,IOERR
	CALL	RSELCT		;Reselect drive
	JP	NZ,IOERR
	BIT	7,A
	JP	NZ,DRVERR	;Go if FDC not rdy
	BIT	2,A
	JP	Z,DRVERR	;Go if not at trk 0
	CALL	CKDRV		;Be sure disk mounted
	JR	NZ,MOUNT	;Disk not mounted
	RLCA
	OR	(IY+3)		;Ck for wp
	AND	80H
	JP	NZ,WPERR	;Go if write prot.
	LD	C,CR		;Bump down a line
	@@DSP
	RET
;
;	Prompt for a system disk
;
SYSTEM:	PUSH	HL
	IF	@BLD631
	JR	SYS9		;<631>
	ENDIF
SYS2:	LD	HL,SYSTEM$
	@@DSPLY			;Show the message
SYS1:	@@KEY			;Wait for an answer
	CP	CR		;Is it a CR?
	JR	NZ,SYS1		;Redo if not
	IF	@BLD631
SYS9:				;<631>
	ENDIF
	LD	HL,BUFF		;Read 0,0
	LD	DE,0
	IF	@BLD631
	LD	C,D		;<631>Drive to C (D==0)
	ELSE
	LD	C,0		;Drive to C
	ENDIF
	@@CKDRV
	JR	NZ,SYS2
	@@RDSEC
	JR	NZ,SYS2
	IF	@BLD631
	LD	A,(BUFF+2)	;<631>Get dir cyl
	ELSE
	LD	A,(BUFF+3)	;Get dir cyl
	ENDIF
	LD	D,A		;Put in D
	@@RDSSC			;Read the GAT
	JR	NZ,SYS2		;Redo on error
	LD	A,(BUFF+0CDH)	;Get the type byte
	AND	80H		;Is it system?
	JR	NZ,SYS2		;Redo if not
	LD	C,CR
	@@DSP
	POP	HL
	RET			; else all ok, quit
;
;	Disk I/O requests
;
	IF	@BLD631
DRVNOP:	XOR	A		;<631>
	JR	FMTDRV		;<631>
SELECT:	LD	A,1		;<631>
	JR	FMTDRV		;<631>
RESTOR:	LD	A,4		;<631>
	JR	FMTDRV		;<631>
STEPIN:	LD	A,5		;<631>
	JR	FMTDRV		;<631>
RSELCT:	LD	A,7		;<631>
	JR	FMTDRV		;<631>
WRCYL:	LD	A,15		;<631>
	JR	FMTDRV		;<631>
FMTHD:	LD	A,12		;<631>
	JR	FMTDRV		;<631>
WRSEC:	LD	A,13		;<631>
	JR	FMTDRV		;<631>
WRSYS:	LD	A,14		;<631>
	JR	FMTDRV		;<631>
RDSEC:	LD	A,9		;<631>
	JR	FMTDRV		;<631>
VERSEC:	LD	A,10		;<631>
FMTDRV:	PUSH	BC		;<631>
SETDRV:	LD	C,-1		;<631>P/u drive #
	ELSE
DRVNOP	PUSH	BC
	XOR	A
	JR	FMTDRV
SELECT	PUSH	BC
	LD	A,1
	JR	FMTDRV
RESTOR	PUSH	BC
	LD	A,4
	JR	FMTDRV
STEPIN	PUSH	BC
	LD	A,5
	JR	FMTDRV
RSELCT	PUSH	BC
	LD	A,7
	JR	FMTDRV
WRCYL	PUSH	BC
	LD	A,15
	JR	FMTDRV
FMTHD	PUSH	BC
	LD	A,12
	JR	FMTDRV
WRSEC	PUSH	BC
	LD	A,13
	JR	FMTDRV
WRSYS	PUSH	BC
	LD	A,14
	JR	FMTDRV
RDSEC	PUSH	BC
	LD	A,9
	JR	FMTDRV
VERSEC	PUSH	BC
	LD	A,10
FMTDRV	LD	C,-1		;P/u drive #
	ENDIF
	ADD	A,40		;Adjust SVC #
	RST	40
	POP	BC
	RET
;
;	Brief routine to check a drive for availability
;
CKDRV	LD	HL,BUFF
	@@TIME			;P/u the timer pointer
	EX	DE,HL		;TIME$ to HL
	DEC	HL		;TIMER$ to HL
	LD	A,(HL)		;P/u current timer value
	ADD	A,15		;Set timeout to 500ms
	LD	D,A		;Save for test later
;
;	Test for diskette in drive & rotating
;
CKDR1	CALL	CKDR6		;Test index pulse
	JR	NZ,CKDR1	;Jump on index
CKDR2	CALL	CKDR6		;Test index pulse
	JR	Z,CKDR2		;Jump on no index
CKDR2A	CALL	CKDR6
	JR	NZ,CKDR2A	;Jump on index
	RET
CKDR6	EI			;Make sure they're ON
	LD	A,(HL)		;P/u latest TIMER$ value
	SUB	D		;500ms passed?
	JR	Z,CKDR7
	CALL	RSELCT		;Select & wait not busy
	BIT	1,A		;Test index
	RET
CKDR7	POP	DE		;Pop the ret address
	OR	1		;Set "Illegal drive #
	RET			;With NZ
;
GETSYS2:	LD	A,84H		;Load sys2
	RST	40
;
;
;DCOPY1
;
SETFMT:	LD	DE,D5TBL	;P/u table pointer
	LD	A,(DE)		;P/u # of sectors to fmt
	INC	DE		;Adj for zero offset
	LD	(SECTRK),A
	LD	B,A
	BIT	5,(IY+4)	;Need twice as many
	JR	Z,$+3		;  if 2-sided drive
	RLCA
	LD	(SECCYL),A
	LD	A,(DE)		;P/u track skew
	INC	DE
	LD	(TRKSKEW+1),A
	LD	(SECSKEW+1),DE	;Format sector skew
;
;	Index past sector info
;
	INC	A		;Add DE -> begin of sec #
	ADD	A,B		;B -> # of sectors/side
	ADD	A,E		; A+1 -> a code byte
	LD	E,A
	ADC	A,D
	SUB	E
	LD	D,A
	LD	HL,BUFF		;Buffer for format data
	LD	BC,HITBUF	;Tempy ptrs to trk,sect info
;
;	Create the formatting data without trk,sect info
;
FMTDAT	LD	A,(DE)		;P/u table format byte
	INC	DE		;Bump table ptr
	CP	0F1H		;Start of cylinder?
	JR	Z,CODF1
	CP	0F2H		;Start of track trailer?
	JR	Z,CODF2
	CP	0F3H		;Start of track ID info?
	JR	Z,CODF3
	CP	0F4H		;End of table parms?
	JR	Z,CODF4
	CP	0F5H		;Start of data?
	PUSH	BC
	JR	NZ,CODE1	;Go if not
;
;	Write 2 byte data pattern to format buffer
;
	LD	A,(DE)		;P/u length to write
	INC	DE		;Bump to 1st data byte
	LD	B,A		;Xfer length to B
	LD	A,(DE)		;P/u a data byte
	INC	DE		;Bump again for 2nd byte
	LD	C,A		;Xfer 1st byte
	LD	A,(DE)		;P/u 2nd byte
CODF5	LD	(HL),C		;Stuff into buf
	INC	HL
	LD	(HL),A
	INC	HL
	DJNZ	CODF5		;Loop til xfered
	JR	CODRET
;
;	Xfer bytes to the format buffer area
;	A => count to move
;	DE=> data byte to duplicate
;
CODE1	LD	B,A		;Count to B
	LD	A,(DE)		;P/u data byte to move
CODE1A	LD	(HL),A		;Fill buf with byte
	INC	HL
	DJNZ	CODE1A		;Loop til done
CODRET	POP	BC
	INC	DE		;Bump table ptr
	JR	FMTDAT		;Back for more
;
;	Save the current table posn and the number of
;	sectors per cylinder on the stack.
;
CODF1	LD	A,(SECTRK)	;P/u # of sectors/side
CODF1A	PUSH	DE		;Save table pointer
	PUSH	AF		;Save value
	JR	FMTDAT
;
;	Done with a sector. Are there more on this cyl?
;
CODF2	POP	AF		;Count down the # of
	DEC	A		;  sectors to format
	JR	Z,CODF2A	;Go if last one done
	POP	DE		;Recover table ptr
	JR	CODF1A		;Loop for more
;
CODF2A	POP	AF		;Clean the stack
	JR	FMTDAT		;  and finish off the cyl
;
;	Build a table of the location in the format buffer of
;	the track and sector ID bytes, to be filled in during
;	the actual formatting.
;
CODF3	LD	A,L		;Stuff pointer to where
	LD	(BC),A		;  track & sector info
	INC	BC		;  is to be placed
	LD	A,H
	LD	(BC),A
	INC	BC
	JR	FMTDAT
;
;	Finished building format cyl info. Terminate the ID table
;	with an extra 256 bytes in case of overrun.
;
CODF4:
	XOR	A		;Stuff two X'00's to
	LD	(BC),A		;  indicate the end
	INC	BC		;  of the ID posn table
	LD	(BC),A
	LD	B,0		;Stuff 256 FF's into the
	LD	A,0FFH		;  format buffer
	LD	(HL),A
	INC	HL
	DJNZ	$-2
	RET
;
;	Begin the formatting
;
BGNFMT:	LD	HL,FMTCYL$	;"Formatting...
	CALL	MSGOUT
SECSKEW	LD	BC,0		;Begin of sector table
BFMT1	LD	HL,HITBUF	;P/u ptr to ID posn table
;
BFMT2
	@@CKBRKC		;Check for break
	JP	NZ,ABORT1	;Go if so
;
	LD	E,(HL)		;P/u positions having
	INC	HL		;  sector & cylinder
	LD	D,(HL)		;  info to be stuffed
	INC	HL		;  into format data
	LD	A,D		;Finished?
	OR	E
	JR	Z,BFMT4
	LD	A,(IY+5)	;P/u cylinder # & stuff
	LD	(DE),A		;  into format data
	INC	DE
	LD	A,(IY+3)	;Stuff the side-select
	AND	10H		;  bit
	RRCA
	RRCA
	RRCA
	RRCA
	LD	(DE),A		;  into the format data
	INC	DE
	LD	A,(BC)		;P/u the sector number
	OR	A
	JP	P,BFMT3		;Go if a good number
	ADD	A,C		;  else off the end,
	LD	C,A		;  calculate the beginning
	JR	C,BFMT3		;  of the sector table
	DEC	B
BFMT3	LD	A,(BC)		;P/u the next sector #
	LD	(DE),A		;  and stuff in format data
	INC	DE
	INC	BC
	JR	BFMT2		;Loop until cylinder done
;
BFMT4	LD	(SECSKEW+1),BC	;Save end of sector table
	LD	D,(IY+5)	;P/u current cylinder
	LD	HL,BUFF		;Pt to format data
	CALL	SELECT		;Drive select
	JP	NZ,IOERR	;Go on error
	CALL	WRCYL		;Cylinder write
	JP	NZ,IOERR
	BIT	5,(IY+4)	;Double sided?
	JR	Z,BFMT5
	BIT	4,(IY+3)	;Flip bit for 2nd side
	JR	NZ,BFMT5	;  if not already on it,
	SET	4,(IY+3)	;  else go to next
	INC	BC		;Bump to start side 2
	JR	BFMT1		;  at different sector #
BFMT5	RES	4,(IY+3)	;Turn off side 2
TRKSKEW	LD	A,0		;P/u the track skew byte
	ADD	A,C		;Repoint to beginning
	LD	C,A		;  of sector table
	ADC	A,B		;Skew start of next track
	SUB	C
	LD	B,A
	LD	(SECSKEW+1),BC
	RET
;
;
;	Formatting data and tables
;
SECCYL	DS	1		;# of sectors per cyl
SECTRK	DS	1		;# of sectors per trk
;
;
;	Double density 5" format table
;
D5TBL	DB	18,10
	DB	0,9,1,10,2,11,3,12,4
	DB	13,5,14,6,15,7,16,8,17
	DC	11,-18
	DB	32,4EH
	DB	0F1H,12,0,3,0F5H,1,0FEH
	DB	0F3H,3,0,1,1,1,0F7H,22,4EH,12,0,3,0F5H
	DB	1,0FBH,0F5H,128,6DH,0B6H
	DB	1,0F7H,1,4EH,23,04EH
	DB	0F2H,182,4EH,0F4H
	DB	0,1,2,3,4,5,6,7,8,9
	DB	10,11,12,13,14,15,16,17
;
;	Routine to convert reg A to 2 decimal digits
;
CVDEC	LD	C,30H		;Init msd to 0
CVD1	SUB	10		;Sub 10 until underflow
	JR	C,CVD2
	INC	C		;Inc the count
	JR	CVD1
CVD2	ADD	A,3AH		;Add back 10 + '0'
	LD	B,A		;Lsd to B
	RET
;
;	Show what's happening
;
MSGOUT:	PUSH	HL		;Save msg
	LD	HL,$-$		;Set cursor
CURSOR	EQU	$-2
	LD	B,3
	@@VDCTL
	POP	HL
	@@DSPLY
	LD	A,(IY+5)	;Get syl #
	CALL	CVDEC
	@@DSP			;Show cyl #
	LD	C,B
	@@DSP
	RET
;
;
SRCDCT	DW	0
DSTDCT	DW	0
WASLOK	DB	0
;
FMTCYL$	DB	'Formatting  ',3
RDCYL$	DB	'Reading     ',3
WRCYL$	DB	'Writing     ',3
VERCYL$	DB	'Verifying   ',3
;
	ORG	$<-8+1<8
HITBUF	DS	256
GATBUF	DS	256
RDBUF	DS	36*256
BUFF	EQU	$
;
ENDLOC	EQU	$+2B00H		;for free mem check
	END	BEGIN
