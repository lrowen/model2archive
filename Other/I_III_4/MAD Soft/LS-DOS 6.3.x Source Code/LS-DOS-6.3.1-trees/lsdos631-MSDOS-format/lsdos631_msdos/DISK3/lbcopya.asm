;LBCOPYA/ASM - Copy/Append commands
	SUBTTL	'<LBCOPYA - APPEND Mainline>'
	PAGE
;
;	Jump to COPY Entry Point
;
COPY	JP	COPYST		;Go to COPY
;
;	APPEND Entry Point - Was the <BREAK> hit ?
;
APPEND
	IF	@BLD631
	LD	(SAVESP+1),SP	;<631>Save SP address
	ENDIF
	@@CKBRKC		;Check for break
	IF	@BLD631
	JR	NZ,ABORT	;<631>Abort
	ELSE
	JR	Z,APPENDA	;Continue if not
	LD	HL,-1		;  else abort
	RET
;
;	<BREAK> not hit - Execute Module
;
APPENDA
	LD	(SAVESP+1),SP	;Save SP address
	ENDIF
	CALL	APCODE		;Call Append code
EXIT	LD	HL,0		;Good exit
	JR	SAVESP
;
;	I/O Error Display & Abort Routine
;
IOERR	PUSH	AF		;Save error code
	CALL	PMTSYS		;Prompt SYSTEM Disk
	POP	AF		;Rcvr error code
	LD	L,A		;Xfer any error to HL
	LD	H,0
	OR	0C0H		;Set for abbrev error msg
	LD	C,A		;Save Error # in C
	@@ERROR			;Display & abort
	IF	@BLD631
;
;	P/u Stack, clear any <BREAK> & return
;
SAVESP	LD	SP,$-$		;<631>P/u stack
	@@CKBRKC		;<631>Clear any <BREAK>
	RET			;<631>  and RETurn
	ELSE
	JR	SAVESP		;Good bye
	ENDIF
;
;	Load HL with error message string to display
;
SAMERR	LD	HL,SAMERR$	;"Source & Dest same"
	DB	0DDH
SPCREQ	LD	HL,SPCREQ$	;"File spec required"
	DB	0DDH
NOINDO	LD	HL,NOINDO$	;"Invalid during <DO>"
	DB	0DDH
DIFLRL	LD	HL,DIFLRL$	;"Files have diff LRLs"
	DB	0DDH
DSTREQ	LD	HL,DSTREQ$	;"Dest spec Required"
	@@LOGOT			;Log error message
;
;	Attempt to close any OPEN destination file
;
	LD	DE,FCB2		;Point to dest FCB
	LD	A,(DE)		;Is the file OPEN?
	RLCA
	JR	NC,ABORT	;No - abort
	@@CLOSE
ABORT	LD	HL,-1		;Abort code to HL
	IF	@BLD631
	JR	SAVESP		;<631>
	ELSE
;
;	P/u Stack, clear any <BREAK> & return
;
SAVESP	LD	SP,$-$		;P/u stack
	@@CKBRKC		;Clear any <BREAK>
	RET			;  and RETurn
	ENDIF
;
;	APCODE - Append spec to spec
;
APCODE
	XOR	A		;Turn off CLONE parm
	LD	(CPARM+1),A
	LD	(CPARM+2),A
	LD	(APPFLAG+1),A	;We're in APPEND not COPY
;
	CALL	DOINIT		;Set High memory
;
;	Check if Filespec/Devspec #1 is legal
;
	LD	DE,FCB1		;DE => File #1 FCB
	@@FSPEC			;Check out filespec
	JP	NZ,SPCREQ	;NZ - Filespec Required
;
;	Check if Filespec/Devspec #2 is legal
;
	LD	DE,FCB2		;DE => File #2 FCB
	@@FSPEC			;Check if legal
	CALL	NZ,CVRTUC	;Convert line to U/C
;
;	Is the second FCB a device ?
;
APND1	LD	A,(FCB2)	;P/u byte 0 of FCB2
	CP	'*'		;Is this a devspec ?
	JP	Z,SPCREQ	;Z - Filespec required
;
;	Parse any parameters entered
;
	LD	DE,APPTBL	;DE => Parameter Table
	@@PARAM			;Check out parameters
	JP	NZ,IOERR	;NZ - Parameter Error
;
	CALL	PRSPC		;P/u FCB ptr in DE
;
;	Open Filespec #2 with LRL of 256
;
	CALL	OPENSR2		;Open Filespec #2
	CALL	PUTDEST		;Xfer Dest filespec
	CALL	GETLRL		;Get LRL from DIR entry
;
	LD	(LRL2+1),A	;Set dir LRL into parm
	LD	(GEOF1+1),A	;Also stuff for later
;
;	Open Filespec #1 with LRL of 256
;
	CALL	OPENSRC		;Open Filespec #1
	CALL	PUTSOUR		;Xfer source filespec
;
;	Is the Source a Device ?
;
	EX	DE,HL
	BIT	7,(HL)		;P/u FCB+0 of source
	EX	DE,HL		;Device ?
	CALL	Z,CPYFILE	;Display "Appending ..."
	JR	Z,APND2		;Yes - don't check LRLs
;
;	File Source - Check if LRLs are different
;
	CALL	GETLRL		;P/u LRL of Filespec #1
LRL2	LD	B,$-$		;P/u LRL of Filespec #2
	XOR	B		;Same ?
	JP	NZ,DIFLRL	;No - Different LRLs
	CALL	CPYFILE		;"Appending : "
;
;	Files have same LRLs, check STRIP parameter
;
SPARM	LD	DE,$-$		;P/u strip parameter
	LD	A,D		;If STRIP, then must do
	OR	E		;  byte I/O
	JR	NZ,APND2	;Go if STRIP
;
;	Pick up End of File offset byte from FCB
;
	LD	A,(FCB2+8)	;Get eof mark
	OR	A		;If full sectors, use
	JR	Z,APND3		;Sector I/O
;
;	EOF not on page boundary - use byte I/O
;
APND2	LD	DE,FCB2
	@@PEOF			;Position to end of file
;
;	If STRIP, then backspace the dest by 1 byte
;
	LD	A,(SPARM+1)	;P/u SPARM
	OR	A		;Specified ?
	JR	Z,APND2A	;No - don't backspace
;
;	SPARM specified - Backspace one byte
;
	LD	HL,FCB2+9	;HL => LRL of FCB #2
	LD	B,(HL)		;P/u current dest LRL
	LD	(HL),1		;Reset LRL=1
	@@BKSP			;Backspace 1 byte
	LD	(HL),B		;Reset LRL back
;
;	Replace the I/O buffer in FCB #2
;
APND2A	LD	HL,BUF2		;HL => New buffer addr
	LD	(FCB2+3),HL	;Stuff in FCB
	JP	BYTIO0		;
;
;	EOF on page boundary, use sector I/O
;
APND3	LD	BC,(FCB1+12)	;P/u ERN of source
	LD	A,B		;If source is a null
	OR	C		;  file, don't do any
	JP	Z,GEOF3		;  appending, just close
;
;	Write Ending Record Number
;
	LD	HL,(FCB2+12)	;P/u ERN of dest
	PUSH	HL		;Save it for later
	ADD	HL,BC		;Add the two to find new
	LD	B,H		;  ERN & Xfer new ERN to BC
	LD	C,L
	CALL	WRERN		;Write a data sector
	POP	HL		;Recover original ERN
	LD	(FCB2+12),HL	;  & reset FCB to it
	@@PEOF			;Position to end of file
	JP	XFER5
	SUBTTL	'<LBCOPYA - COPY Mainline>'
	PAGE
;
;	COPY Entry Point - was <BREAK> hit ?
;
COPYST
	IF	@BLD631
	LD	(SAVESP+1),SP	;<631>Save SP address
	ENDIF
	@@CKBRKC		;Check for break
	IF	@BLD631
	JP	NZ,ABORT	;<631>
	ELSE
	JR	Z,COPYSTA	;Continue if not
	LD	HL,-1		;  else abort
	RET
;
;	<BREAK> not hit - execute module
;
COPYSTA	LD	(SAVESP+1),SP	;Save SP address
	ENDIF
	CALL	COPYCD		;Execute Copy code
	JP	EXIT		;Go to common exit
;
;	COPYCD - Copy spec to spec
;
COPYCD
	CALL	DOINIT		;Set high mem test byte
;
;	Check if Source Filespec is legal
;
	LD	DE,FCB1		;DE => Source FCB
	@@FSPEC			;Check out filespec
	JP	NZ,SPCREQ	;NZ - Filespec required
;
;	Check if Destination Filespec is legal
;
	LD	DE,FCB2		;DE => Destination FCB
	@@FSPEC			;Check out filespec
	CALL	NZ,CVRTUC	;Convert line to U/C
;
;	Process any parameters entered
;
COPY1	LD	DE,COPYTBL	;DE => Parameter Table
	@@PARAM			;Check out parameters
	JP	NZ,IOERR	;NZ - Parameter Error
;
;	Test if X parameter was entered
;
XPARM	LD	DE,$-$		;P/u (X) parm - We don't
	LD	A,D		;  XFER devices
	OR	E		;
	JR	NZ,XFER		;
;
;	Is the Source or Destination a device ?
;
	CALL	CKDEV		;Device ?
	JP	Z,BYTEIO	;Yes - use byte I/O
;
;	Pick up Defaults for source and destination
;
	CALL	PRSPC		;P/u defaults
	JR	OPNSRC
;
;	XFER initialization code
;
XFER	@@FLAGS			;Position IY to flags
	BIT	5,(IY+SFLAG$)	;DO in Effect ?
	JP	NZ,NOINDO	;Yes - abort
;
;	If the Source or Dest is a Device - abort
;
	CALL	CKDEV		;Device ?
	JP	Z,SPCREQ	;Yes - Filespecs required
;
;	P/u Drivespec of Source Filespec if entered
;
	LD	HL,FCB1		;HL => FCB #1
	LD	C,0		;Init to drive zero
;
;	Loop to Pick up Drive # or terminator
;
XFER1	LD	A,(HL)		;Look for drive spec
	INC	HL
	CP	':'		;Colon indicator?
	JR	Z,XFER2		;Jump if found
	CP	' '		;Jump on end
	JR	C,XFER3
	JR	XFER1		;Loop
;
;	Colon indicator present - p/u drive #
;
XFER2	LD	A,(HL)		;P/u user drive
	SUB	'0'		;Cvrt to binary
	LD	C,A		;  & stuff in C
;
;	Save Source drive number
;
XFER3	LD	HL,XFRDRV+1	;HL => Drive #
	LD	(HL),C		;Save drive # for later
;
;	Stuff drive # into Prompt strings
;
	LD	A,'0'		;Cvt drive # to ASCII
	ADD	A,C
	LD	(SRC_DR),A	;Source Drive #
	LD	(DEST_DR),A	;Destination Drive #
;
;	Transfer source FCB to destination FCB
;
	LD	HL,FCB1		;HL => Source FCB
	LD	DE,FCB2		;DE => Destination FCB
	LD	BC,32		;32 bytes to Xfer
	LDIR			;Xfer
;
	CALL	GETSYS2		;Load SYS2 for OPEN
;
;	Flash "Insert Source Disk" Message
;
	LD	HL,PMTSRC$	;Prompt for source
	CALL	FLASH		;  and wait for <ENTER>
;
;	Read in the GAT of the source disk
;
	LD	A,(XFRDRV+1)	;P/u source drive
	LD	C,A		;Stuff in C
	CALL	RDGAT		;Read in GAT
	JP	NZ,IOERR	;Abort on GAT error
;
;	Xfer Password, Name, & Date to destination
;
	LD	HL,GAT+0CEH	;Disk pw, name, date
	LD	DE,SRCSTR	;DE => Destination
	LD	BC,18
	LDIR			;Xfer
;
;	OPEN the Source File with LRL of 256
;
OPNSRC	CALL	OPENSRC		;Open source file
	CALL	PUTSOUR		;Xfer source filespec
	CALL	GETCLON		;Get clone data
	LD	A,(FCB1+6)	;Get source drive
	AND	7
	CALL	WHATBIT		;Make into bit instr.
	LD	(SRCBIT),A
	LD	A,($-$)		;See if new type year
YFLAG1	EQU	$-2
	DB	0CBH		;Bit x,A
SRCBIT	DB	0
	JR	NZ,NEWD1	;Source is new, done
	LD	A,-1		;Else mark old source
	LD	(CKTYP),A
;
;	Pick up Source LRL
;
NEWD1	LD	A,L		;Pt back to LRL of source
	SUB	16
	LD	L,A
	LD	A,(HL)		;P/u source LRL
;
;	Save LRL from source FCB or LRL Parameter
;
LPARM	LD	BC,0FF00H	;P/u LRL
	INC	B
	JR	NZ,USEREGC	;If parm entered, use it
	LD	C,A
USEREGC	LD	HL,GEOF1+1	;HL => stuff LRL here
	LD	(HL),C		;Stuff LRL for close here
;
;	Ignore this if not COPY (X)
;
	LD	A,(XPARM+1)	;Bypass if not (X)
	OR	A
	JR	Z,OPNDST
;
;	Flash "Insert Destination Disk" message
;
	LD	HL,PMTDST$	;Prompt destination
	CALL	FLASH		;Flash until loaded
;
;	Read in GAT of Destination Disk
;
	LD	A,(XFRDRV+1)	;P/u drive
	LD	C,A		;Read GAT from dest
	CALL	RDGAT
	JP	NZ,IOERR	;Jump on GAT read error
;
;	Xfer Name, Password & Date to destination
;
	LD	HL,GAT+0CEH	;HL => GAT + X'CE'
	LD	DE,DSTSTR	;DE => Destination
	LD	BC,18		;To match up when
	PUSH	DE
	LDIR			;  swapping disks
	POP	DE		;Restore Dest ptr
;
;	Check if Source ID = Destination ID
;
	LD	HL,SRCSTR	;Compare source & dest
	LD	B,18		;CANNOT be same
	CALL	CPRHLDE		;Ck MPW, PackID, Date
	JR	NZ,OPNDST	;Bypass if different
;
;	Display "Source & Dest. Disks Identical"
;
	CALL	PMTSYS		;Prompt for SYSTEM
	JP	SAMERR		;Disk packs are identical
;
;	OPEN the destination File
;
OPNDST	LD	DE,FCB2		;DE => FCB #2
	LD	HL,BUF1		;HL => I/O buffer #1
	CALL	INITDES		;Init the file
	CALL	PUTDEST		;Xfer Dest filespec
	LD	A,(FCB2+6)	;Get dest drive
	AND	7
	CALL	WHATBIT		;Get bit instr.
	LD	(DSTBIT),A
	LD	A,($-$)		;Get date type flag
YFLAG2	EQU	$-2
	DB	0CBH		;Bit x,A
DSTBIT	DB	0
	JR	Z,NEWD2		;Go if dest old
	LD	HL,CKTYP	;Else indicate dest new
	INC	(HL)
;
;	Check if X parm entered
;
NEWD2	LD	A,(XPARM+1)	;If (X), then source &
	OR	A		;  dest can be same file
	JR	NZ,XF2		;Bypass if (X)
;
;	Does Source & Dest. have same DEC & drive #
;
	LD	HL,(FCB1+6)	;If SRC & DST have same
	LD	DE,(FCB2+6)	;  DEC & drive, they are
	XOR	A		;  identical, abort if so
	SBC	HL,DE
	JP	Z,DSTREQ	;Same - dest spec needed
;
;	Write revised ERN for space check
;
XF2	CALL	CPYFILE		;"Copying : ..."
	LD	BC,(FCB1+12)	;P/u ESN
	CALL	WRERN		;Write a FORMAT sector
;
;	Reset Destination ESN to Zero
;
	LD	HL,0		;Rewind file
	LD	(FCB2+12),HL	;
	@@REW			;Rewind the file
;
XFER5	CALL	PMTSRC		;Display "Insert source"
;
;	Stuff Correct Buffer Address in Source FCB
;
	LD	HL,BUF1		;Stuff in FCB
RDREC1	LD	(FCB1+3),HL	;Set buffer addr
;
;	Read in a Source Sector
;
	LD	DE,FCB1		;DE => Source FCB
	@@READ			;Read a sector
	JR	Z,RDREC2	;Bypass if no error
;
;	Some sort of I/O Error - Check it out
;
	CP	1CH		;EOF?
	JR	Z,GOTEOF
	CP	1DH		;NRN>ERN?
	JR	Z,GOTEOF
	JP	IOERR		;Abort
;
;	Successful READ - is there enough memory ?
;
RDREC2	INC	H		;Bump memory pointer
	LD	A,H		;Go past top?
RDREC3	CP	$-$
	JR	NZ,RDREC1	;Loop if not
;
;	Read in all we could - display "Insert Dest"
;
	CALL	PMTDST		;Get destination
;
;	Stuff Source FCB buffer into Destination FCB
;
	LD	HL,BUF1		;Set buffer start
RDREC4	LD	(FCB2+3),HL
;
;	Loop to WRITE Destination file
;
	LD	DE,FCB2		;DE => Destination FCB
	@@WRITE			;Write a sector
	JP	NZ,IOERR	;Jump on write error
;
;	Bump memory ptr & check if finished
;
	INC	H		;Else bump memory pointer
	LD	A,H		;At top?
RDREC5	CP	$-$
	JR	NZ,RDREC4	;Loop if not
	JR	XFER5		;Else go back to source
;
;	Got EOF error from source - Write out EOF
;
GOTEOF	CALL	GEOF5		;Write any memory left
	LD	HL,(FCB1+8)	;P/u EOF & LRL
	LD	(FCB2+8),HL	;Xfer to FCB2
;
;	Get @CLOSE module if needed
;
	CALL	PMTSYS		;Prompt SYSTEM if needed
	CALL	GETSYS3		;Load SYS3 for CLOSE
	LD	A,(XFRDRV+1)	;P/u drive #
	OR	A		;Is it zero ?
	CALL	Z,PMTDST	;Get dest if drive 0
;
;	Close the destination file
;
	LD	BC,(FCB2+6)	;P/u drive # & DEC
	LD	DE,FCB2		;DE => Destin file FCB
	@@CLOSE			;Close the dest file
	JP	NZ,IOERR	;Jump on error
;
;	Get the destination file directory record
;
	@@DIRRD			;Get destin dir entry
	JP	NZ,IOERR	;I/O error - abort
;
;	Stuff New LRL into directory entry
;
	PUSH	BC		;Save drive & DEC
;
	PUSH	HL		;HL => DIR+0 of dest
	LD	A,4		;Posn to LRL byte
	ADD	A,L		;
	LD	L,A		;HL => DIR+4 (LRL)
GEOF1	LD	(HL),$-$	;GEOF1+1 contains LRL
	POP	HL		;Restore HL
;
;	Pick up the Clone Parameter
;
CPARM	LD	DE,-1		;Default = ON
	LD	A,D		;Was it changed ?
	OR	E
	JR	Z,GEOF2		;CLONE = N
;
;	CLONE = Yes, Transfer Attributes & Date
;
	PUSH	HL		;Save DIR+0
	EX	DE,HL
	LD	HL,CLONSAV	;HL => Attr, DE => DIR+0
	LD	BC,3		;Move in prot/date, etc
	LDIR
;
;	Transfer Password fields to entry
;
	LD	A,13		;Pt to dir pswd fields
	ADD	A,E
	LD	E,A		;DE => DIR+16
	LD	C,4		;BC = 4 bytes to xfer
	LDIR
	DEC	DE		;Pt at new year, DIR+19
	POP	HL		;Get back DIR+0
	LD	A,0FEH		;Ck if old type to new
CKTYP	EQU	$-1
	OR	A
	JR	NZ,GEOF2	;Was not old to new
	INC	HL		;Was old to new, change
	INC	HL		; date/time
	LD	A,(HL)		;Get old year
	AND	7
	LD	(DE),A		;Year to DIR+19
	DEC	DE
	XOR	A		;Make time 0
	LD	(DE),A		;Store in DIR+18
;
;	Write out Directory entry
;
GEOF2	POP	BC		;Rcvr drive & DEC
	@@DIRWR			;Write Sector with entry
	JR	GEOF4		;Go to Error check
;
;	CLOSE the destination file
;
GEOF3A	LD	HL,-1		;Abort JCL
	LD	(RETCOD+1),HL	;  if <BREAK> hit
GEOF3	LD	DE,FCB2		;DE => Destination FCB
	@@CLOSE			;Close the file
GEOF4	JP	NZ,IOERR	;I/O Error - Abort
;
;	Flash "Insert SYSTEM disk" & exit
;
GOHOME	CALL	PMTSYS		;Prompt SYSTEM if needed
RETCOD	LD	HL,$-$		;P/u return code 0=good
	JP	SAVESP		;Finished
;
;	WRERN - Write a format sector on FILE #2
;
WRERN	LD	DE,FCB2		;DE => File #2 FCB
	LD	A,B		;Don't bother to write
	OR	C		;  a sector if source
	RET	Z		;  is empty
;
;	Position to ERN of File #2
;
	DEC	BC		;Adj for ERN
	@@POSN			;Position to ERN
	PUSH	DE		;Save FCB ptr
;
;	Fill a buffer of X'E5's
;
	LD	HL,BUF1		;HL => I/O buffer
	LD	DE,BUF1+1	;DE => I/O buffer+1
	LD	BC,255		;255+1 bytes to fill
	LD	(HL),0E5H	;Format byte = X'E5'
	LDIR			;Fill buffer
;
;	Write ERN of File #2
;
	POP	DE		;DE => FCB #2
	@@WRITE			;Write sector
	RET	Z		;RETurn if no error
	JP	IOERR		;Error - abort
;
;	BYTEIO - OPEN Source or dest using byte I/O
;
BYTEIO	CALL	OPENSRC		;OPEN source file
	CALL	PUTSOUR		;Get source filespec
;
;	INIT the dest device with LRL from parm
;
	LD	A,(LPARM+1)	;P/u LRL from Parm
	LD	B,A		;Open destination
	LD	DE,FCB2		;DE => FCB #2
	LD	HL,BUF2		;Different buffer
	LD	A,@INIT		;@INIT SVC #
	CALL	GETFILE		;Issue it
	CALL	PUTDEST		;Get dest devspec
	CALL	CPYFILE		;"Copying/Appending : .."
	XOR	A		;Reset LRL = 0
	LD	(FCB2+9),A	;For sector I/O
;
;	Turn on cursor
;
BYTIO0	LD	C,14		;Turn cursor on
	CALL	DISPB		;Display byte
;
;	BYTIO1 Loop - File - Dev, Dev - File, Dev - Dev
;	Was the <BREAK> key hit ?
;
BYTIO1
	CALL	CKBRK		;Was the <BREAK> key
E_O_F	JP	NZ,GEOF3A	;  hit ????
;
;	The <BREAK> was not hit - get a character
;
	LD	DE,FCB1		;DE => Source FCB
	@@GET			;Get a byte
	JR	Z,BYTIO4	;Good - stuff it
;
;	If Error # = 0, then try @GET again
;
	OR	A		;Error # = 0 ?
	JR	Z,BYTIO1	;Yes - @GET again
;
;	Is the Error an "End of File" error ?
;
	CP	1CH		;EOF?
	JP	Z,GEOF3		;Yes - finished
	JP	IOERR		;I/O error - abort
;
;	Was the source character a <BREAK> ?
;
BYTIO4	CP	BREAK		;<BREAK> character ?
	JR	NZ,BYTIO4A	;No - @PUT it
;
;	Source = <BREAK> --- is the BREAK bit set ?
;
	CALL	CKBRK		;<BREAK> bit set ?
	JR	NZ,E_O_F	;Yes - stop
	LD	A,BREAK		;Restore A
;
;	Output byte to destination
;
BYTIO4A	LD	DE,FCB2		;DE => Dest. Device/File
	LD	C,A		;Stuff byte in C for @PUT
	@@PUT			;Output byte
	JP	NZ,IOERR	;NZ - I/O Error
;
;	Echo byte if parameter set
;
EPARM	LD	DE,$-$		;P/u ECHO parm
	INC	D		;Specified ?
	CALL	Z,DISPB		;Echo byte
	JR	BYTIO1		;Go til EOF or BREAK
;
