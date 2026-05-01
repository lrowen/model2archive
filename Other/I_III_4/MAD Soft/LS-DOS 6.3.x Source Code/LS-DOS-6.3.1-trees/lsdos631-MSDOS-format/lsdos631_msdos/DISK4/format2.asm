;FORMAT2/ASM - Format Initialization Code
;
;	FORMAT routine entry point
;
FORMAT
	@@CKBRKC		;Check for break
	JR	Z,FORMATA	;Continue if no break
	LD	HL,-1		;  else abort
	RET
;
FORMATA	LD	(SPSAV+1),SP	;Save the stack pointer
	PUSH	HL		;Save cmdline ptr
	@@DSPLY	HELLO$		;Hello message
	CALL	GETSYS2		;Load SYS2 overlay
;
;	Read config sector & extract DCT # cyls
;
	IF	@MOD4
	LD	DE,2		;Track 0, sector 2
	LD	C,D		;Drive 0
	ENDIF
;
	IF	@MOD2
	LD	C,0		;Drive 0
	@@GTDCT			;Fetch DCT
	LD	A,(IY+3)	;Get dct data
	AND	28H		;Bit 5/3
	CP	20H		;8" floppy?
	JR	NZ,SETSYS1	;Go if not
	LD	A,(IY+4)	;Get data
	AND	50H		;Bit 6/4
	CP	40H		;DD not alien?
	JR	NZ,SETSYS1	;Go if not
	LD	HL,HITBUF	;Init buffer
	LD	D,(IY+9)	;Get dir cyl
	LD	E,0		;Init GAT table
	@@RDSEC			;Read GAT table
	CP	6		;Directory read?
	JP	NZ,IOERR	;Go on disk error
	LD	A,(HITBUF+0CDH)	;Get data byte
	BIT	7,A		;System disk?
SETSYS1	LD	DE,0<8+2	;Init cyl 0
	JR	NZ,$+3		;Go if not system
	INC	D		;Else on cyl 1
	LD	C,0		;Drive 0
	ENDIF
;
	LD	HL,HITBUF	;Set disk buffer
	@@RDSEC			;Read sysinfo sector
	JP	NZ,IOERR	;Quit on read error
	LD	L,70H+6		;Pt to default DCTs
;
;	Establish the default BOOT step rate
;
	PUSH	HL		;Pt IY to the
	POP	IY		;  start of the DCTs
	LD	A,(IY+3-6)	;P/u DCT$ default step
	AND	3		;  & strip off
	LD	(STEPARM+1),A	;Keep for Step parm
;
;	Keep cyl count on all 8 drives
;
	LD	B,8
	LD	IX,DCTCYL	;Pt to where to stuff
	LD	DE,10		;  10-byte increments
DCTLP1	LD	A,(HL)		;P/u default # CYL
	LD	(IX),A		;Save in table
	INC	IX
	ADD	HL,DE
	DJNZ	DCTLP1		;Loop for 8 DCTs
;
	POP	HL		;Rcvr ptr to cmdline
FMT1	LD	A,(HL)		;Ignore spaces
	INC	HL
	CP	' '
	JR	Z,FMT1
	CP	':'		;Colon drive indicator?
	JR	Z,FMT2		;Go on drive entry
;
;	Drive not entered, prompt for it
;
	DEC	HL		;Backspace command line
	DEC	HL		;  & adjust for next INC
	PUSH	HL		;Save pointer
WHDRV	@@DSPLY	WHDRV$		;"which drive...
	LD	HL,HITBUF	;Input buffer for now
	LD	BC,1<8		;Max 1 char
	@@KEYIN			;Get a 1-char line
	JP	C,FMTABT	;Quit on Break
	LD	A,(HL)		;P/u the entry
	SUB	'0'		;Cvrt to binary
	CP	8		;Error if > 7
	JR	NC,WHDRV
	POP	HL		;Rcvr command pointer
	JR	FMT2A
;
;	Drive entered
;
FMT2	LD	A,(HL)		;P/u drive #
	SUB	'0'		;Cvrt to ASCII
	CP	8		;Make sure not > 7
	JP	NC,PRMERR
FMT2A	LD	(FMTDRV+1),A	;Stuff drive
	INC	HL		;Bump cmdline ptr
	LD	DE,PRMTBL$	;Parse any parameters
	@@PARAM
	JP	NZ,PRMERR	;Jump on parm error
;
;	Test if any other parm was entered
;
SDPARM	LD	DE,0		;Single density parm
	LD	A,D
	OR	E		;Merge all theses parms
DDPARM	LD	DE,0		;Double density parm
	OR	D
	OR	E
SIDES	LD	DE,0		;Sides parm
	OR	D
	OR	E
CPARM	LD	DE,0		;Cylinder parm
	OR	D
	OR	E
STEPARM	LD	DE,0FF00H	;Init to show if entry
	INC	D		;Did user enter it?
	OR	D		;0=no user entry
	LD	(PRMMRG+1),A	;Set to non-zero if any
;
;	If Q-parm, then set NAME & MPW if not entered
;
	LD	DE,(QPARM+1)	;P/u Query parm
	LD	HL,(NPARM+1)	;P/u Name parm
	LD	A,H
	OR	L
	JR	NZ,$+6		;Go if user entered name
	LD	(NPARM+1),DE	;  else use Q-parm value
	LD	HL,(MPARM+1)	;P/u Password parm
	LD	A,H
	OR	L
	JR	NZ,$+6		;Go if user entered password
	LD	(MPARM+1),DE	;Set to Q-parm entry
;
	LD	A,(FMTDRV+1)	;P/u drive
	LD	C,A		;Set in drive register
	LD	HL,DCTCYL	;Find default # cyls
	ADD	A,L		;Index the DCTCYL table
	LD	L,A		;  according to drive #
	ADC	A,H
	SUB	L
	LD	H,A
	LD	A,(HL)		;P/u cylinder count
	INC	A		;Offset from 1
	LD	(PCYL2+1),A	;Stuff default for 5"
	@@GTDCT			;Find the DCT pointer
	PUSH	IY
	POP	HL		;Xfer DCT to HL
	LD	DE,SYSDCT	;Save the system's DCT
	LD	BC,10		;  for the drive since
	LDIR			;  we are altering it
	LD	A,(SYSPRM+1)	;Check if "SYSTEM" parm
	INC	A		; entered
	JR	NZ,FMT2B	;Go if not
	BIT	3,(IY+3)	;Check if hard drive
	JP	Z,NOTHARD	;Can't "SYSTEM" floppy
FMT2B	CALL	DRVNOP		;Test if drive enabled
	JP	NZ,IOERR
NPARM	LD	HL,0		;NAME parm entered?
	LD	A,H
	OR	L
	INC	A		;Was it just NAME?
	JR	Z,DSKNAM	;Prompt if so
	DEC	A		;If entered, use it
	JR	NZ,$+5
DFTNAM	LD	HL,PAKNAM$
	LD	DE,GATBUF+0D0H	;Yes, move name to field
	LD	B,8		;8-chars max
MOVNAM	LD	A,(HL)		;P/u a char
	CP	'"'		;Closing "
	JR	Z,CKNAME	;Exit if end of parm
	CP	20H		;Permit all but controls
	JP	C,CKNAME
	CP	'a'		;If char is lower case,
	JR	C,MOVNAM1
	CP	'z'+1
	JR	NC,MOVNAM1
	XOR	20H		;  make it UC
MOVNAM1	LD	(DE),A		;Put char in buffer
	INC	HL		;Bump both ptrs
	INC	DE
	DJNZ	MOVNAM		;Loop til complete
	JR	CKNAME		;Check if valid name
;
;	Prompt user for name parameter
;
DSKNAM	@@DSPLY	DSKNAM$		;"diskette name?
	CALL	GET8		;Get 8 chars, make UC
	JR	Z,DFTNAM	;Use default if no entry
	LD	C,B		;Only move to name field
	LD	B,0		;  how many were entered
	LD	DE,GATBUF+0D0H
	LDIR
CKNAME	LD	DE,GATBUF+0D0H	;Now check if illegal
	CALL	CKMPW0		;  chars in name
	JP	NZ,BADNAM	;  & quit if so
GETDAT	LD	HL,GATBUF+0D8H	;Get today's date & stuff
	@@DATE
;
;	Master Password handling
;
MPARM	LD	HL,0		;Did user enter the MPW?
	LD	A,H
	OR	L
	INC	A		;If only MPW, then prompt
	JR	Z,MPW		;Go prompt if not
	DEC	A
	JR	NZ,$+5		;If entered, use it
DFTMPW	LD	HL,PAKMPW$	;  else use ours
	LD	DE,MPWBUF	;Shift to pswd field
	LD	B,8
MOVMPW	LD	A,(HL)
	CP	30H		;No spaces permitted
	JR	C,PRSMPW	;End also on closing "
	CP	'a'		;Need cvrt to UC?
	JR	C,MOVMPW1
	CP	'z'+1
	JR	NC,MOVMPW1
	XOR	20H		;Cvrt to UC
MOVMPW1	LD	(DE),A		;Store the char and
	INC	DE		;  bump the buffer ptrs
	INC	HL
	DJNZ	MOVMPW
	JR	PRSMPW		;Check if valid password
;
;	Prompt for master password
;
MPW	LD	HL,MPW$		;"master...
	CALL	INPMPW
	JR	NC,DFTMPW	;Use default on <ENTER>
;
;	Parse the password & stuff into GAT sector buffer
;
PRSMPW	LD	DE,MPWBUF
	CALL	CKMPW		;Check for valid MPW
	JP	NZ,IOERR
	LD	(GATBUF+0CEH),HL	;Stuff it
	BIT	4,(IY+4)	;Jump if alien controller
	JP	NZ,CALCGPC
	LD	HL,TBLDATA	;Pt to config tables
	LD	DE,6		;Index the table
	BIT	5,(IY+3)	;8" drive?
	JR	Z,INITDEN	;Bypass if not
	ADD	HL,DE		;  else move to 8" configs
	ADD	HL,DE
INITDEN	LD	(SETSDEN+1),HL	;  & stuff for SDEN option
	EX	DE,HL		;6->HL, SDEN->DE
	ADD	HL,DE		;Pt to DDEN index table
	LD	(SETDDEN+1),HL	;Stuff DDEN config ptr
	EX	DE,HL		;HL=SDEN, DE=DDEN
	RES	6,(IY+3)	;Set DCT to SDEN
	BIT	6,(IY+4)	;Test if DDEN capability
	JR	Z,SETSTD	;Go if single
	EX	DE,HL		;HL->DDEN table
	SET	6,(IY+3)	;Set DCT to DDEN
SETSTD	CALL	SETUP		;Init to std config
	RES	4,(IY+3)	;Set i/o to front side
	RES	5,(IY+4)	;Set to 1-sided
PRMMRG	LD	A,0		;<>0 if config parms
	OR	A		;  in command line
	JR	NZ,GETDEN
QPARM	LD	DE,-1		;Prompts? Default=Y
	LD	A,D
	OR	E
	JP	Z,PSTEP1	;Go if no prompting
GETDEN	BIT	6,(IY+4)	;Bypass DDEN request msg
	JR	Z,PMTSIDE	;  if no DDEN capability
	LD	A,(PRMMRG+1)	;Also, don't prompt if
	OR	A		;  any config parm was
	JR	NZ,GDDEN1	;  entered with command
	LD	HL,DEN?$	;Density <S,D>...
	CALL	GET3
	JR	Z,PMTSIDE	;Go on <ENTER>
	LD	A,(HL)		;P/u respsonse
	CP	'S'		;Single Density?
	JR	Z,SETSDEN
	CP	'D'		;Double density?
	JR	Z,SETDDEN
	JR	GETDEN		;Redo if bad response
GDDEN1	LD	A,(DDPARM+1)	;Not prompted, was DDEN
	XOR	-1		;  set in command line?
	JR	NZ,GSDEN1	;Bypass if not
SETDDEN	LD	HL,$-$		;P/u DDEN index table
	SET	6,(IY+3)	;Set DCT to DDEN
	JR	CHGDEN
GSDEN1	LD	A,(SDPARM+1)	;Was SDEN parm
	XOR	-1		;  on command line?
	JR	NZ,PMTSIDE	;Go if not
SETSDEN	LD	HL,$-$		;P/u SDEN index table
	RES	6,(IY+3)	;Set DCT to SDEN
CHGDEN	CALL	SETUP		;Init #CYLs & alloc
PMTSIDE	LD	A,(PRMMRG+1)	;Config parms entered
	OR	A		;On command line?
	JR	NZ,PMTS1	;Bypass if yes
	PUSH	IY		;P/u flag table
	@@FLAGS			;  and check if
	BIT	5,(IY+'L'-'A')	;  2-side inhibit?
	POP	IY
	JR	NZ,PMTS1	;If set, use 1 side
	LD	HL,SIDES$	;"double sided...?
	CALL	GET3		;Get # sides wanted
	JR	Z,PMTCYL	;Go on <ENTER>
	LD	A,(HL)		;P/u response char
	CP	'1'		;1 is ok
	JR	Z,PMTCYL
	CP	'2'		;  and so is 2
	JR	NZ,PMTSIDE	;  but redo on anything else
	JR	TSTSID
;
;	Check side parm from command line
;
PMTS1	LD	A,(SIDES+1)	;How many sides?
	CP	2
TSTSID	JR	NZ,PMTCYL	;DCT ok if not 2
	SET	5,(IY+4)	;Set 2-sided drive
PMTCYL	LD	A,(IY+3)	;No cylinder request
	AND	28H		;  if either hard drive
	JR	NZ,PMTSTEP	;  or 8" drive
PCYL1	LD	A,(PRMMRG+1)	;P/u config test byte &
	OR	A		;  bypass cyl req if user
	JR	NZ,PCYL4	;  entered cmd line parms
	LD	HL,NUMCYL$	;"number of cyls..?
	CALL	GET3
PCYL2	LD	A,0		;P/u default # cyls
	CALL	NZ,CVBIN	;Get # of cyls on CR
	IF	@BLD631
	CALL	CHKCNT		;<631>
	JR	C,PCYL1		;<631>Anything out of range
	JR	PMTSTEP		;<631>
CHKCNT:	CP	96+1		;<631>System cannot support
	CCF			;<631>  anything over 96 (95)
	RET	C		;<631>
	CP	35		;<631>Must be 35 or more
	RET	C		;<631>
	DEC	A		;<631>Adjust to zero offset
	LD	(IY+6),A	;<631> & stuff in DCT
	RET			;<631>
	ELSE
PCYL3	CP	96+1		;System cannot support
	JR	NC,PCYL1	;  anything over 96 (95)
	CP	35
	JR	C,PCYL1		;Must be 35 or more
	DEC	A		;Adjust to zero offset
	LD	(IY+6),A	;  & stuff in DCT
	JR	PMTSTEP
	ENDIF
;
;	User entered config parms with command line
;
PCYL4	LD	A,(CPARM+1)	;Was cyl= one of them?
	OR	A
	IF	@BLD631
	CALL	NZ,CHKCNT	;<631>Check for valid range
	JP	C,PRMERR	;<631>Parm error if too big
PMTSTEP:BIT	4,(IY+4)	;<631>Alien controller?
	JR	NZ,CALCGPC	;<631>No adjustable rate if so
	ELSE
	JR	Z,PMTSTEP	;Bypass if not
	CP	96+1
	JP	NC,PRMERR	;Parm error if too big
	CP	35
	JP	C,PRMERR	;  or too small
	DEC	A		;Adjust to zero offset
	LD	(IY+6),A	;  & stuff into DCT
PMTSTEP	BIT	4,(IY+4)	;Alien controller?
	JR	NZ,PMTSIDE	;No adjustable step rate if so
	ENDIF
;
;	If step rate parm wasn't entered, prompt
;	for it but first determine 8" or 5" drive
;
	LD	A,(PRMMRG+1)	;Did user enter config
	OR	A		;Parms on command line?
	JR	NZ,PSTEP1	;Go to step prompt if yes
;
	PUSH	IY		;P/u flag table and
	@@FLAGS			;  check if
	BIT	0,(IY+'L'-'A')	;  step prompt inhibited
	POP	IY
	JR	NZ,PSTEP1	;Bypass if set
;
	BIT	5,(IY+3)	;Need prompt, 8"?
	JR	NZ,STEP8	;Jump if 8"
;
;	5" drive step rate parsing
;
STEP5	LD	HL,STEP5$	;"...step rate - 5"
	IF	@BLD631
	LD	DE,L3574	;<631>
	CALL	DOITALL		;<631>
	JR	NZ,STEP5	;<631>
	JR	C,PSTEP1	;<631>
	JR	GOTSTEP		;<631>
	ELSE
	CALL	GET3
	CALL	CVBIN		;Get 5" step rate
	OR	A		;Use default?
	JR	Z,PSTEP1	;Go if parm not entered
	LD	B,0		;Init key to 0
	CP	6
	JR	Z,GOTSTEP
	LD	B,1		;Init key to 1
	CP	12
	JR	Z,GOTSTEP
	LD	B,2		;Init key to 2
	CP	20
	JR	Z,GOTSTEP
	LD	B,3		;Init key to 3
	CP	30
	JR	Z,GOTSTEP
	CP	40
	JR	Z,GOTSTEP
	JR	STEP5		;Re-request, bad value
	ENDIF
;
;	8" drive step rate parsing
;
STEP8	LD	HL,STEP8$	;"step rate - 8"...
	IF	@BLD631
	LD	DE,L3579	;<631>
	CALL	DOITALL		;<631>
	JR	NZ,STEP8	;<631>
	JR	NC,GOTSTEP	;<631>
	ELSE
	CALL	GET3
	CALL	CVBIN		;Get 8" step rate
	OR	A		;Use default?
	JR	Z,PSTEP1	;Go if not entered
	LD	B,0		;Init key to 0
	CP	3
	JR	Z,GOTSTEP
	LD	B,1		;Init key to 1
	CP	6
	JR	Z,GOTSTEP
	LD	B,2		;Init key to 2
	CP	10
	JR	Z,GOTSTEP
	LD	B,3		;Init key to 3
	CP	15
	JR	Z,GOTSTEP
	CP	20
	JR	Z,GOTSTEP
	JR	STEP8		;Bad entry, re-request
	ENDIF
PSTEP1	LD	A,(STEPARM+1)	;P/u step parm entry
	AND	3		;Keep 2 lo-order bits
	JR	$+3
GOTSTEP	LD	A,B		;Stuff boot step rate key
	LD	(STEPDFT),A
;
;	Routine to calculate the # of grans per logical
;	cylinder so that the GAT byte can be constructed
;
CALCGPC	LD	A,(IY+8)	;P/u # of grans per cyl
	RLCA			;Rotate to bits 0-2
	RLCA
	RLCA
	AND	7		;Strip off other data
	INC	A		;Adj for zero offset
;
;	If double siding (cylindering), double the count
;
	BIT	5,(IY+4)	;Test if 2-sided drive
	JR	Z,$+3		;Bypass if only 1-sided
	ADD	A,A		;Double the grans/cyl
	LD	BC,0FFFFH	;Init GAT byte to ones
CGPC1	SLA	B		;Now keep removing low
	DEC	A		;  order bits , 1 bit for
	JR	NZ,CGPC1	;  each available granule
	LD	HL,GATBUF	;Pt to GAT buffer area
	LD	A,(IY+6)	;P/u highest # cylinder
CGPC2	LD	(HL),B		;Stuff the GAT byte into
	INC	L		;Each position of the GAT
	CP	L		;One byte per cylinder
	JR	NC,CGPC2
;
;	Test if we are at 202 first by ignoring the
;	first two instructions with LD DE,xxxx
;
	LD	A,0CBH		;Continue to stuff GAT
	DB	11H		;  until cyl 202
CGPC3	LD	(HL),C		;Use FFH to show unused
	INC	L
	CP	L		;First test here for
	JR	NZ,CGPC3	;  match against 202
;
;	Prompt for destination disk & prepare it
;
	LD	A,(FMTDRV+1)	;P/u drive
	OR	A
	JR	NZ,PFMT1	;Bypass if other than 0
PMTDST	@@DSPLY	PMTDST$		;"load dest disk...
	PUSH	IY		;Save DCT pointer
	@@FLAGS			;Point to flags
	BIT	5,(IY+'S'-'A')	;Check for JCL active
	POP	IY		;Restore pointer
	JP	NZ,FMTABT	;Abort if in JCL
	LD	HL,HITBUF
	LD	BC,0		;Zero characters means
	@@KEYIN			;Enter or Break only
	JP	C,FMTABT	;Abort if Break
PFMT1	PUSH	IY		;Xfer DCT ptr to HL
	POP	HL		;  & move DCT again
	LD	DE,TMPDCT	;  to store tempy
	LD	BC,10
	LDIR
	IF	@MOD2
	CALL	SELECT
	JP	NZ,IOERR	;Go on error
	ENDIF
	CALL	RESTOR		;Restore to cyl 0
	JP	NZ,IOERR	;Go on error
	CALL	RSELCT		;Reselect drive
	JP	NZ,IOERR	;Go on error
	BIT	4,(IY+4)	;Jump if alien controller
	JR	NZ,PFMT3
	LD	HL,NOTRDY$	;Init "drive not ready
	BIT	7,A		;Test FDC status for READY
	JP	NZ,EXTERR	;Quit if not ready
	LD	HL,NODRV$	;Init "drive not in...
	BIT	2,A		;Test FDC status for TRACK-0
	JP	Z,EXTERR	;  & error if not at track 0
	CALL	CKDRV		;Ck if floppy not present
	JR	NZ,PMTDST
	LD	HL,CANTWR$	;Init "write protected..
	RLCA			;Align to bit 7
	OR	(IY+3)		;Combine with soft WP
	AND	80H		;WP error?
	JP	NZ,EXTERR	;Can't format over WP
	LD	A,(SYSPRM+1)	;Don't check space needed
	OR	A		;  if SYSTEM info only
	JR	NZ,PFMT3
	LD	HL,FORMAT	;Start of format buffer
PFMT2	LD	DE,0		;P/u format space needed
	ADD	HL,DE		;Pt to last addr needed
	LD	D,H		;Xfer to reg DE
	LD	E,L
	LD	HL,0		;Set up for HIGH$ fetch
	LD	B,L
	@@HIGH$			;Make sure it won't wrap
	XOR	A
	SBC	HL,DE		;  into protected memory
	LD	HL,NOMEM$	;Init "insufficient mem..
	JP	C,EXTERR	;Quit if no memory available
PFMT3	LD	DE,0		;Init to cyl 0, sect 0
	CALL	VERSEC		;Verify BOOT
	JP	NZ,PFMT6	;Assume unformated if err
;
;	Appears formatted, is there SYSTEM information?
;
	LD	A,(SYSPRM+1)	;Ignore data if SYSTEM
	OR	A		;  info only
	JP	NZ,PFMT6
	LD	HL,HITBUF	;Pt to i/o buffer
	CALL	RDSEC		;Now try to read BOOT
	JP	NZ,IOERR	;Jump on error
	@@LOGOT	HASDAT$		;Show "disk contains data
	LD	HL,NOFMT$	;Init "non-std format
;
;	BOOT was read, is there a valid directory pointer
;
	LD	A,(HITBUF+2)	;P/u dir cyl # (possible)
	CP	(IY+6)		;Check against max cyl #
	JR	NC,PFMT5	;Go if bigger (or =)
;
;	Read the assumed GAT & test it
;
	LD	HL,HITBUF
	LD	E,L
	LD	D,A		;Pt to assumed GAT sector
	LD	HL,HITBUF	;Pt to buffer
	CALL	RDSEC		;Read the sector
	CP	6		;Dir errcod returned?
	JR	Z,PFMT4		;Jump if yes & grab data
	LD	HL,CANTRD$	;Init "unreadable dir...
	JR	PFMT5
PFMT4	LD	HL,NODIR$	;Init "non-init dir
	LD	A,(HITBUF+0DAH)	;Check if date field
	CP	'/'		;  is present
	JR	NZ,PFMT5	;Jump if no
;
;	The directory is readable - request its MPW
;
	LD	HL,HITBUF+0D0H
	LD	DE,PACKID$+5	;Move name & date into
	LD	BC,8		;  display message field
	LDIR
	LD	DE,PACKID$+14H
	LD	C,8
	LDIR
;
;	If MPW = "PASSWORD", just ck ABS
;
	LD	HL,(HITBUF+0CEH)	;P/u disk MPW
	LD	DE,PASSWORD	;Password=PASSWORD
	XOR	A
	SBC	HL,DE		;Is it password?
	LD	HL,PACKID$	;Init"Name=, Date=
	JR	Z,PFMT5		;If match, go check ABS
	IF	@BLD631
	PUSH	IY		;<631>
	@@FLAGS			;<631>
	BIT	7,(IY+0DH)	;<631>
	POP	IY		;<631>
	JR	NZ,PFMT5	;<631>
	ENDIF
	@@LOGOT			;Log the ID field
	PUSH	IY		;Abort if in JCL
	@@FLAGS
	BIT	5,(IY+'S'-'A')	;Test if "DOing"
	POP	IY
	JP	NZ,FMTABT	;Can't get PW if in JCL
;
;	User must enter Current Pack's MPW to proceed
;
OLDMPW	LD	HL,OLDMPW$	;"What's the old MPW?
	CALL	INPMPW		;Grab user input to match
	JR	NC,OLDMPW
	LD	DE,MPWBUF
	CALL	HASHMPW		;Hash user entry
;
;	Routine to test master password for match
;
	EX	DE,HL		;Xfer hashed MPW to DE
	LD	HL,(HITBUF+0CEH)	;Else grab pack MPW
	XOR	A		;Clear carry flag
	SBC	HL,DE		;Did user enter pack MPW?
	JP	NZ,BADMPW	;Abort if no match
	JR	PFMT6
;
;	The directory was not readable - req assurance
;
PFMT5	@@LOGOT
APARM	LD	DE,0		;ABS parameter
	INC	E
	JR	Z,PFMT6		;Go if ABS used
	PUSH	IY
	@@FLAGS
	BIT	5,(IY+'S'-'A')	;Test if "DOing"
	POP	IY
	JP	NZ,FMTABT	;Abort if JCL but no ABS
	LD	HL,SURE?$	;"are you sure...?
	CALL	GET3		;Get response
	LD	A,(HL)
	CP	'Y'		;If not Yes, abort
	JP	NZ,FMTABT
PFMT6	PUSH	IY		;Move drive code table
	POP	DE		;  back into place
	LD	HL,TMPDCT	;  into system slot
	LD	BC,10
	LDIR
	CALL	RESTOR		;Restore to cylinder 0
	JP	NZ,IOERR	;Go on error
	JP	GOFMT		;Go and format it
;
;	Routine to set up the DCT for format
;
SETUP	LD	A,(PCYL2+1)	;P/u the highest # cyl
	BIT	5,(IY+3)	;If 8" drive, use 77
	JR	Z,$+4		;Go if only 5"
	LD	A,77		;8" drives are 77 cyls
	DEC	A
	LD	(IY+6),A	;Stuff in our DCT
	LD	E,(HL)		;Grab address to
	INC	HL		;  master formatting table
	LD	D,(HL)
	INC	HL
	LD	(FMTTBL+1),DE	;Stuff for later use
	LD	E,(HL)		;P/u DCT+7 data
	INC	HL		;Max sector, # of heads
	LD	D,(HL)		;P/u DCT+8 data, # of
	INC	HL		;  sectors/gran & grans/cyl
	LD	(IY+7),E	;Stuff these values into
	LD	(IY+8),D	;  our DCT
	LD	E,(HL)		;P/u space needed for
	INC	HL		;  the formatting buffer
	LD	D,(HL)
	LD	(PFMT2+1),DE	;  & stuff that for later
	RET
	IF	@BLD631
DOITALL:PUSH	DE		;<631>
	CALL	GET3		;<631>
	CALL	CVBIN		;<631>
	POP	HL		;<631>
	OR	A		;<631>
	SCF			;<631>
	RET	Z		;<631>
	LD	B,0		;<631>
	CP	(HL)		;<631>
	RET	Z		;<631>
	INC	HL		;<631>
	INC	B		;<631>
	CP	(HL)		;<631>
	RET	Z		;<631>
	INC	B		;<631>
	INC	HL		;<631>
	CP	(HL)		;<631>
	RET	Z		;<631>
	INC	HL		;<631>
	INC	B		;<631>
	CP	(HL)		;<631>
	RET	Z		;<631>
	INC	HL		;<631>
	CP	(HL)		;<631>
	RET			;<631>

L3574:	DB	06H,0CH,14H,1EH,28H	;<631>
L3579:	DB	03H,06H,0AH,0FH,14H	;<631>
	ENDIF
;
;	Convert decimal ASCII to binary
;
CVBIN	LD	E,0		;Init value to 0
CVB1	LD	A,(HL)		;Get a character
	INC	HL		;Bump buff ptr
	SUB	30H		;Make binary
	LD	B,A
	CP	0AH		;Was it a decimal digit?
	LD	A,E
	RET	NC		;Return if not
	ADD	A,A		;Mult previous value X 10
	ADD	A,A
	ADD	A,E
	ADD	A,A
	ADD	A,B		;Add in new digit
	LD	E,A		;Put results in E
	JR	CVB1		;Loop
;
INPMPW	@@DSPLY
	LD	HL,MPWBUF	;Use this buffer
	LD	B,8		;8 chars max
	CALL	GET8A		;Input the pswd
	RET	Z		;Go if Enter only
	EX	DE,HL
	ADD	A,E		;Find where the X'0D' was
	LD	L,A		;  stuffed & cover it
	LD	A,D
	ADC	A,0
	LD	H,A
	LD	A,8		;If 8 chars entered,
	SUB	B
	SCF			;  done
	RET	Z
	LD	B,A		;  else pad the buffer
FILLBLK	LD	(HL),' '	;  w/spaces
	INC	HL
	DJNZ	FILLBLK
	SCF
	RET
;
CKMPW	CALL	CKMPW0
	RET	NZ
;
;	Hash a diskette password
;
HASHMPW	LD	A,0E4H		;Use SYS2 routine
	RST	40
;
CKMPW0	LD	B,8		;8 char to check
	PUSH	DE		;Xfer start of PW
	POP	HL		;  to HL
	LD	A,(HL)		;P/u 1st char
	JR	CKMPW2		;  & check <A-Z>
CKMPW1	INC	HL		;Advance to next char
	LD	A,(HL)		;P/u the char
	CP	' '
	JR	Z,CKMPW7	;Go on space
	CP	'0'
	JR	C,INVMPW	;Bad if less than o
	CP	'9'+1		;  or greater than 9
	JR	C,CKMPW3
CKMPW2	CP	'A'
	JR	C,INVMPW	;  but less than A
	CP	'Z'+1
	JR	NC,INVMPW	;More than Z also bad
CKMPW3	DJNZ	CKMPW1		;Char ok, do another
	XOR	A		;Set Z, PW good
	RET
;
CKMPW5	INC	HL		;Next char position
	CP	(HL)		;No imbedded spaces
	JR	NZ,INVMPW
CKMPW7	DJNZ	CKMPW5		;Loop til 8 checked
	XOR	A		;Set Z = PW good
	RET
;
INVMPW	LD	HL,INVMPW$	;Init "Invalid PW
	LD	A,63		;Indicate extended error
	OR	A		;Set NZ condition
	RET
;
;	Brief routine to check a drive for availability
;
CKDRV	LD	HL,HITBUF
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
;	Temporary storage space for format drive DCT
;
TMPDCT	DS	10
DCTCYL	DS	8		;Default # cyls
;
;	Config table for single density 5"
;
TBLDATA	EQU	$
	DW	S5TBL,2409H,3381
;
;	Config table for double density 5"
;
	DW	D5TBL,4511H,6506
;
;	Config table for single density 8"
;
	DW	S8TBL,270FH,5464
;
;	Config table for double density 8"
;
	DW	D8TBL,491DH,10673
;
;	Parm error exit
;
BADNAM	LD	HL,BADNAM$
	DB	0DDH
BADMPW	LD	HL,INVMPW$
	DB	0DDH
NOTHARD	LD	HL,HARD$
	JP	EXTERR
PRMERR	LD	A,44		;Init Parm ERROR
	JP	IOERR
;
;	Load SYS2 overlay
;
GETSYS2	LD	A,84H
	RST	28H
;
MPWBUF	DB	'         '
PRMTBL$
VAL	EQU	80H
SW	EQU	40H
STR	EQU	20H
SGL	EQU	10H
	DB	80H
	DB	SW!STR!SGL!4,'NAME',0
NRESP	EQU	$-1
	DW	NPARM+1
	DB	SW!STR!SGL!3,'MPW',0
MRESP	EQU	$-1
	DW	MPARM+1
	DB	SW!4,'SDEN',0
	DW	SDPARM+1
	DB	SW!4,'DDEN',0
	DW	DDPARM+1
	DB	VAL!5,'SIDES',0
	DW	SIDES+1
	DB	VAL!SGL!3,'CYL',0
	DW	CPARM+1
	DB	VAL!4,'STEP',0
	DW	STEPARM+1
	DB	SW!SGL!3,'ABS',0
	DW	APARM+1
	DB	SW!SGL!5,'QUERY',0
	DW	QPARM+1
	DB	SW!6,'SYSTEM',0
	DW	SYSPRM+1
	DB	VAL!SGL!4,'WAIT',0
	DW	WAITPRM+1
	DB	VAL!SGL!3,'DIR',0
	DW	DIRPARM+1
	NOP
;
HELLO$	DB	'FORMAT'
*GET	CLIENT:3
HARD$	DB	'Cannot "SYSTEM" a floppy',CR
	IF	@BLD631
NOMEM$	DB	'Out of memory',CR	;<631>
	ELSE
NOMEM$	DB	'Insufficient memory for '
	DB	'specified format',CR
	ENDIF
WHDRV$	DB	'Which drive is to be used ? ',3
DSKNAM$	DB	'Diskette name ? ',3
MPW$	DB	'Master password ? ',3
NUMCYL$	DB	'Number of cylinders ? ',3
	IF	@BLD631
STEP5$	DB	'Boot strap step rate '	;<631>
	ELSE
STEP5$	DB	'Boot strap stepping rate '
	ENDIF
	DB	'<6, 12, 20, 30 msecs> ? ',3
	IF	@BLD631
STEP8$	DB	'Bootstrap step rate '	;<631>
	ELSE
STEP8$	DB	'Bootstrap stepping rate '
	ENDIF
	DB	'<3, 6, 10, 15/20 msecs> ? ',3
SIDES$	DB	'Enter number of sides <1,2> ? ',3
DEN?$	DB	'Single or Double density <S,D> ? ',3
NOTRDY$	DB	'Drive not ready',CR
CANTWR$	DB	'Write protected disk',CR
NODRV$	DB	'Drive not in system',CR
PMTDST$	DB	'Load destination diskette  <ENTER>',CR
HASDAT$	DB	'Disk contains data -- ',3
NOFMT$	DB	'Non-standard format',CR
CANTRD$	DB	'Unreadable directory',CR
NODIR$	DB	'Non-initialized directory',CR
PACKID$	DB	'Name=XXXXXXXX  Date=MM/DD/YY',CR
OLDMPW$	DB	'  Enter its Master Password'
	DB	' or <BREAK> to abort: ',3
LASTMSG	DB	'*** The target drive is a hard disk ***',LF
SURE?$	DB	'Are you sure you want to format it ? ',3
INVMPW$	DB	LF,'Invalid Master Password',LF,CR
BADNAM$	DB	'Invalid Disk Name',CR
PAKNAM$	DB	'DATADISK'
PAKMPW$	DB	'PASSWORD'
