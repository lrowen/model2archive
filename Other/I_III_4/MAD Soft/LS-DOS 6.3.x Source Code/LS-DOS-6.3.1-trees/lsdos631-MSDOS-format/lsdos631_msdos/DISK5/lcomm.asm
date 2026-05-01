;LCOMM/ASM - COMM Communications Program
	TITLE	<COMM/CMD - LS-DOS 6,2>
	SUBTTL	'<Program Code Section>'
;
BUFFRD	EQU	-1		;Set true
BREAK	EQU	80H		;Char fm keyboard
LF	EQU	10
CR	EQU	13
XOFF	EQU	'S'&1FH
;
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	COPYCOM:3		;Copyright messages
;
BASE	EQU	3000H
	ORG	BASE	
;
$EXIT	LD	HL,0		;Init no error
QUIT$	LD	SP,$-$		;P/u original stack
STACK	EQU	$-2
	@@CKBRKC		;Clear break bit
	RET
;
$ABORT	LD	HL,-1		;Set abort code
	JR	QUIT$
;
$OPEN	PUSH	HL
	LD	HL,$-$		;Address of SFLAG$ 
SFLG	EQU	$-2
	SET	0,(HL)		;Set open inhibit bit
	POP	HL
	@@OPEN			;Do the open
	RET			;Return with status
;
$ERROR	PUSH	BC
	OR	0C0H		;Set short,return
	LD	C,A		;Error code to C
	@@ERROR			;  for error display
	POP	BC
	RET
;
MAINLP	LD	A,0		;Test warning flag set
	OR	A		;  by OUTPUT on NEXTAP
	JR	Z,ENUFPG	;Go if > 2K of space
	LD	HL,LILPG$	;Display warning
	@@DSPLY
	LD	A,XOFF		;Schedule a forced PUT
XOFFP2	EQU	$-1
	LD	(FRCPUT+1),A
	XOR	A
	LD	(MAINLP+1),A	;Inhibit until next page
ENUFPG	LD	IX,KIVCTR	;Get key from buffer if
	CALL	PGMGET		;  available
	JR	NZ,SENDIT	;Bypass if got one
FSSW	LD	A,0		;FS On/Off (XMIT File)
	OR	A
	JR	Z,FSOFF		;Bypass if not XMTG
CKFREPG	LD	A,(FREEPG)	;Don't get from file
	CP	12		;  if < 3K buffer space
	JP	C,FSOFF		;Go if less
	LD	DE,FS_FCB	;Get sending FCB
FSSWGO	@@GET			;Get a byte to XMIT
	JR	Z,SENDIT	;Bypass if got byte
	CP	1CH		;EOF encountered?
	JR	Z,EOFFS		;Bypass if EOF
	CALL	$ERROR		;Output error message
EOFFS	CALL	FS_OFF		;Turn off XMIT
	JP	SKIPREC		;  and ignore this round
SENDIT	LD	C,A		;Xfer byte
XLTS1	CP	0		;Single character send
	JR	NZ,DPLXSW	;  translate table
XLTS2	LD	C,0
DPLXSW	LD	B,0		;Duplex On/Off
	INC	B
	DEC	B		;Display on our devices
	CALL	NZ,DEVOUT	;  if duplex on (half)
LCMON	LD	A,(TASK8A+2)	;Ck CL on
	OR	A
	CALL	NZ,SNDOUT	;Send char if ON
FSOFF	LD	A,(TASK8A+2)	;Test for CL ON
	OR	A
	JP	Z,SKIPREC	;Go if not
	LD	IX,CLREC
	CALL	PGMGET		;Ck for char avail
	JP	Z,SKIPREC	;Go if no char
DSPCTRL	LD	B,0		;Ck if display of control
	INC	B		;  codes is in effect
	DEC	B
	JR	Z,SAVCHR	;Go if no ctrl display
	CP	20H
	JR	NC,SAVCHR	;Go if not ctrl
	PUSH	AF		;Save the char
	LD	HL,BRAKET+1	;Pt to control char msg
	LD	C,A
	@@HEX8			;Cvrt char & stuff in buf
	LD	HL,BRAKET	;Start of msg string
	@@DSPLY			;Display ASCII control value
	POP	AF		;Rcvr char
SAVCHR	LD	C,A		;Save char
SHAKE	LD	B,0		;Handshake On/Off
	INC	B
	DEC	B
	JR	Z,ECHOSW	;Go if off
	CP	'Q'&1FH		;Ctrl-Q?
XONP1	EQU	$-1		;Modify if PARM
	JR	Z,CTLQ		;Go if so
	CP	'S'&1FH		;Ctrl-S?
XOFFP1	EQU	$-1		;Modify if parm entered
	JR	NZ,NOSQ		;Go if neither
	LD	B,0		;Turn off
CTLQ	LD	A,B		;  or on
	LD	(TASK8B+1),A	;*CL send task
	JR	SKIPREC		;Discard ctrl code
NOSQ	CP	'R'&1FH		;Ctrl-R?
	JR	Z,CTLR		;Go if so
	CP	'T'&1FH		;Ctrl-T?
	JR	NZ,ECHOSW	;Go if neither
	LD	B,0		;Turn off
CTLR	LD	A,B		;  or on
	LD	(FRSW+1),A	;FR device
	JR	SKIPREC		;Discard ctrl code
;
;	Test for ECHO after checking for handshake chars
;
ECHOSW	LD	B,0		;Echo On/Off?
	INC	B
	DEC	B
	CALL	NZ,CLOUT	;Send char back if ON
	LD	A,C
	CP	CR		;Was it a CR?
	JR	NZ,NOTCR
	CALL	ECLF1		;Send LF back if needed
	LD	HL,CRSW+1	;Flag for CR recvd
;
;	Move state of ACCEPT LF switch into CRSW+1 when CR recv'd
;
ACCLFSW	LD	A,0		;Show CR found if accept
	LD	(HL),A		;  LF switch is off
	JR	TAKEREC		;Dsp CR
;
;	When LF rcv'd, delete if ACCLFSW is off & last char was CR
;
NOTCR	LD	A,C		;Check char
CRSW	LD	B,0FFH		;P/u del LF switch
	LD	HL,CRSW+1	;Pt to switch
	LD	(HL),0FFH	; (flip off switch -not CR)
	CP	LF		;Is line feed the char?
	JR	NZ,TAKEREC	;Go if not LF
	LD	A,(EIGHT+1)	;Also skip if 8 bit
	OR	B		;  switch is off
	JR	Z,SKIPREC	;Skip LF if so
;
TAKEREC	CALL	DEVOUT		;Out to active devices
SKIPREC	CALL	TASKS		;Do 3 tasks (incl kbd)
	JP	MAINLP		;  & FRIO test then loop
;
CLOUT	LD	A,C		;Get char
	LD	IX,CLSEND	;Set buffer pointers
	JP	OUTPGM		;Put in output buffer
;
SNDOUT	CALL	CLOUT		;Send this character
	LD	A,C		;Is it CR?
	CP	CR
	RET	NZ		;Done if not
;
ECLF1	LD	A,$-$		;Is echo linefeed on?
ECOLF	EQU	$-1
	OR	A
	RET	Z		;Done if not
	LD	A,LF		;Otherwise load a LF
	LD	IX,CLSEND
	JP	OUTPGM		;Add to buffer/ret to caller
;
;	Output to video
;
DEVOUT	LD	A,0FFH		;Is *DO On/Off?
	OR	A
	JR	Z,FRSW		;Bypass if off
	LD	A,C
	CP	0CH		;If formfeed,
	LD	C,A
	PUSH	BC
	JR	NZ,NOTCLS	;  clear the screen
	LD	C,1CH		;Cursor home
	@@DSP
	LD	C,1FH		;Clear to end-of-frame
NOTCLS	@@DSP
	POP	BC
;
;	Send char to our disk if FR on
;
FRSW	LD	A,0		;FR On/Off - receive file
	OR	A
	JR	Z,PUTPR		;Bypass if FR off
	LD	A,C
	LD	IX,FRVCTR	;Put away into the
	CALL	OUTPGM		;  FR buffer
;
;	Place char into printer buffer if PR on
;
PUTPR	LD	A,0		;PR On/Off?
	OR	A
	JR	Z,FRIOSW	;Go if off
	LD	A,C
	LD	IX,PRVCTR	;Place the char in
	CALL	OUTPGM		;  the printer buffer
;
;	Check if FR to disk is engaged
;
FRIOSW	LD	A,-1		;Ck if FR-to-disk is on
	OR	A
	RET	Z		;Go if not engaged
	LD	IX,FRVCTR	;Is a char available
	CALL	PGMGET		;  for the disk?
	RET	Z		;Go if none for disk
	LD	HL,FR_FCB	;Put char to disk
	BIT	7,(HL)		;OPEN FCB?
	RET	Z		;Skip if not
	EX	DE,HL
	LD	C,A		;Place char in "C"
	@@PUT			;  and do the write
	RET	Z		;Back if good
	CALL	$ERROR
	CALL	FRIO_OFF	;Turn FRIO to disk off
	JP	FR_OFF		;Turn FR off and return
;
;	<CLEAR> command function entered - decode it
;
CMDKEY	LD	BC,0		;Init no device vector
	LD	DE,0		;Init no File FCB
	LD	HL,DSPCTRL+1	;Pt to ctrl char dsply parm
	IF	@MOD4
	CP	27H!80H		;Display control chars?
	ENDIF
	IF	@MOD2
	CP	'&'+80H
	ENDIF
	JP	Z,QFUNC
;
	LD	HL,DPLXSW+1
	CP	'!'+80H		;Ck duplex
	JP	Z,QFUNC
;
	LD	HL,ECHOSW+1
	IF	@MOD4
	CP	'"'+80H		;Ck echo
	ENDIF
	IF	@MOD2
	CP	'@'+80H
	ENDIF
	JP	Z,QFUNC
;
	LD	HL,SHAKE+1	;Check handshake
	IF	@MOD4
	CP	'*'+80H
	ENDIF
	IF	@MOD2
	CP	'_'+80H
	ENDIF
	JP	Z,QSHAKE
;
	LD	HL,ECOLF
	CP	'#'+80H		;Echo line feed?
	JP	Z,QFUNC
;
	LD	HL,ACCLFSW+1	;Check accept-LF
	CP	'$'+80H
	JP	Z,QFUNC
;
	LD	HL,EIGHT+1	;Check 8-bit
	IF	@MOD4
	CP	')'+80H
	ENDIF
	IF	@MOD2
	CP	'('+80H
	ENDIF
	JP	Z,QFUNC
;
	LD	BC,KIVCTR	;Init *KI put/get index
	LD	HL,KISW+1
	CP	'1'+80H		;CK *KI
	JP	Z,QFUNC
;
	LD	BC,0		;No *DO put/get index
	LD	HL,DEVOUT+1
	CP	'2'+80H		;CK *DO
	JR	Z,QFUNC
;
	LD	BC,PRVCTR	;Init *PR put/get index
	LD	HL,PUTPR+1
	CP	'3'+80H		;CK *PR
	JR	Z,QFUNC
;
	LD	BC,CLSEND	;Init *CL-S put/get index
	LD	HL,TASK8A+2
	CP	'4'+80H		;CK *CL
	JR	Z,QCL
;
	LD	BC,FSVCTR	;Init *FS put/get index
	LD	DE,FS_FCB	;Init *FS FCB
	LD	IX,XMTBUF	;Point to buffer
	LD	HL,FSSW+1
	CP	'5'+80H		;CK FS
	JR	Z,QFUNC
;
	LD	BC,FRVCTR	;P/u *FR put/get index
	LD	DE,FR_FCB	;P/u *FR FCB
	LD	IX,RCVBUF	;Pt to buffer
	LD	HL,FRSW+1
	CP	'6'+80H		;CK FR
	JR	Z,QFUNC
;
	LD	HL,FRIOSW+1
	LD	DE,0		;No FCB here
	CP	'7'!80H		;Check FR IO to disk?
	JR	Z,QFUNC
;
	CP	'8'!80H		;Menu request?
	JP	Z,MENU
;
	IF	@MOD4
	CP	'('!80H		;Local clear screen?
	ENDIF
	IF	@MOD2
	CP	'*'+80H
	ENDIF
	JP	Z,CLS
;
	IF	@MOD4
	CP	20H!80H		;Clr-shf-0?
	ENDIF
	IF	@MOD2
	CP	')'+80H
	ENDIF
	JP	Z,DOSCMD	;Do CMDR
;
	IF	@MOD4
	CP	'='+80H		;CK LDOS exit
	ENDIF
	IF	@MOD2
	CP	'+'+80H
	ENDIF
	JP	NZ,CMDERR
;
;
;	Exit from LCOMM - Remove task vectors
;
EXIT
	IF	.NOT.BUFFRD
	LD	C,8		;Remove comm line scan task
	@@RMTSK
;
	LD	C,9		;Rmv printer task if used
	@@RMTSK
	ENDIF
;
	IF	BUFFRD
	LD	DE,CLDCB	;Turn off wakeup feature
	LD	IY,$-$
OLDVEC	EQU	$-2		;Restoring previous state
	LD	C,4
	@@CTL
	ENDIF
;
	CALL	FR_OFF		;Turn off any receive file
	LD	DE,FR_FCB
	LD	A,(DE)
	BIT	7,A		;Is it an open file?
	JP	Z,$EXIT		;Exit if not else
	@@CLOSE			;  make sure it's closed
	JP	Z,$EXIT		;Exit if no error
	CALL	$ERROR
	JP	$ABORT		;Terminate
;
;	Query function ON or OFF
;
QFUNC	CALL	QONOFF		;Get On or Off response
	LD	(HL),A		;Save which one
	RET
;
;	Query *CL on or off
;
QCL	CALL	QONOFF
	LD	(HL),A
	OR	A		;On or off?
	RET	Z		;Quit if off
	LD	(TASK8B+1),A	;Force CL-send on as well
	RET
;
;	Query handshake on or off
;
QSHAKE	PUSH	DE
	@@KEY			;Get one key
	POP	DE
	AND	A		;Be sure flags are set
	JP	M,QSHAKE1	;Go if PF key
	LD	(AUTXOFF+1),A	;Save key as auto XOFF
	LD	(HL),0FFH	;Turn on handshake
	RET
QSHAKE1	CALL	QONOFF1		;Parse ON or OFF
	LD	(HL),A		;Turn on or off
	XOR	A		;Turn off auto XOFF
	LD	(AUTXOFF+1),A
	RET
QONOFF	PUSH	DE		;Hang on to register
	@@KEY			;Get the operand key
	POP	DE		;Restore the register
QONOFF1	EQU	$
	IF	@MOD4
	CP	'-'+80H		;Ck OFF
	ENDIF
	IF	@MOD2
	CP	'='+80H
	ENDIF
	JR	Z,TURNOF	;  and go if off
	IF	@MOD4
	CP	':'+80H		;Ck ON
	ENDIF
	IF	@MOD2
	CP	'-'+80H
	ENDIF
	JR	Z,TURNON	;  and go if on
POPERR	EX	(SP),HL		;Discard ret address
	POP	HL
	CP	'9'+80H		;Ck ID
	JP	Z,FILID
;
	CP	'0'+80H		;Ck RESET
	JP	Z,FILRES
;
	CP	'%'+80H		;Ck REWIND
	JP	Z,FILREW
;
	IF	@MOD4
	CP	'&'+80H		;Ck PEOF
	ENDIF
	IF	@MOD2
	CP	'^'+80H
	ENDIF
	JP	Z,FILEOF
;
CMDERR	LD	HL,CMDERR$	;None of above, dsply
	@@DSPLY			;  "Unacceptable command...
	RET	
;
;	Process OFF
;
TURNOF	XOR	A		;Off = 0
	RET
;
;	Process ON
;
TURNON	EX	DE,HL		;Shift "FCB" to HL
	BIT	7,(HL)		;FCB on or non-file?
	EX	DE,HL		;If non-file, HL now
	LD	A,0FFH		;  points to X'0000'
	RET	NZ		;  which contains X'F3'
	JR	POPERR		;Is an error
;
;	Process Clear Screen
;
CLS	LD	C,1CH		;Cursor home
	@@DSP
	LD	C,1FH		;Clear to end-of-frame
	@@DSP
	RET
;
;	Process MENU
;
MENU	EQU	$
	LD	HL,STAT1	;Clear top row status
	LD	DE,STAT1+1	;1st char always a space
	LD	BC,66
	LDIR
	LD	HL,STAT2	;Clear bottom row status
	LD	DE,STAT2+1
	LD	C,38
	LDIR
	LD	B,15		;Init loop count
	LD	HL,STATAB	;Words where status stored
STATLP1	LD	E,(HL)		;P/u lo-switch
	INC	HL
	LD	D,(HL)		;P/u hi-switch
	INC	HL
	LD	A,(HL)		;P/u lo-stuff
	INC	HL
	PUSH	HL		;Save pointer
	LD	H,(HL)		;P/u hi-stuff
	LD	L,A		;Xfer lo-stuff
	LD	A,(DE)		;Get status
	OR	A		;Active or not?
	JR	Z,$+4		;Go if not
	LD	(HL),'*'	;  else stuf an '*'
	POP	HL		;Rcvr pointer
	INC	HL		;Bump to next pos
	DJNZ	STATLP1
	LD	A,(DE)		;P/u shake again
	OR	A
	JR	Z,STATLP2	;Go if off
	LD	A,(AUTXOFF+1)	;Check if xoff char set
	OR	A
	JR	Z,STATLP2	;Skip if not special char
	LD	HL,STAT1+63	;Auto x-off char posn
	LD	C,A
	@@HEX8			;Cvrt to ASCII for display
STATLP2	LD	HL,MNUMSG	;Ptr to Comm menu
	@@DSPLY			;Display prelim status
	LD	HL,FS_FCB	;FS file open?
	BIT	7,(HL)
	JR	Z,STATLP3	;Go if closed
	LD	DE,DUMMY	;Recover its name w/o
	PUSH	DE		;   changing the FCB
	LD	BC,32
	LDIR			;  by creating a duplicate
	POP	DE		;  open FCB
	LD	BC,(DUMMY+6)	;Get drive and DEC
	PUSH	DE
	@@FNAME			;Call for name recover
	LD	HL,FSNAME$	;Output "FS-SPEC: "
	@@DSPLY
	POP	HL		;Rcvr fcb pointer and
	@@DSPLY			;  display the filespec
STATLP3	LD	HL,FR_FCB	;Is the FR file open?
	BIT	7,(HL)
	JR	Z,STATLP4	;Go if closed
	LD	DE,DUMMY	;Similar to above
	PUSH	DE
	LD	BC,32
	LDIR			;Create a duplicate FCB
	POP	DE
	LD	BC,(DUMMY+6)	;P/u Drive & DEC
	PUSH	DE
	@@FNAME			;Call for name recover
	LD	HL,FRNAME$	;"FR-SPEC:"
	@@DSPLY
	POP	HL		;P/u name start
	@@DSPLY			;  and dsply it
STATLP4	LD	A,(FREEPG)	;How much buffer left
	RRCA			;Divide by 4 to show
	RRCA			;  in K
	AND	3FH		;No bit 7 nor 6
	LD	HL,PAGSPR$+10	;Where to stuff
	LD	B,-1		;Init to count 10's
CVD1	INC	B
	SUB	10		;How many tens?
	JR	NC,CVD1		;Go if no more
CVD2	PUSH	AF		;Save remainder
	LD	A,B		;P/u tens
	OR	A		;Was it zero tens?
	LD	B,' '		;Init for space
	JR	Z,$+4		;Go if no tens
	LD	B,'0'		;Init for ASCII
	ADD	A,B		;Convert to ASCII
	LD	(HL),A		;Stuff & bump
	INC	HL
	POP	AF		;Get remainder
	ADD	A,3AH		;Adjust units place
	LD	(HL),A
	LD	HL,PAGSPR$	;"Memory:   K"
	@@DSPLY
	RET
;
;	Process RESET of a "device"
;
FILRES	LD	A,B		;Check if a device vector
	OR	C		;  was passed
	JP	Z,CMDERR	;Go if not - is error
	LD	A,D		;Check for a possible
	OR	E		;  FCB for disk
	JR	NZ,FILR4	;Go if disk else device
;
;	Reset the page buffer(s) for the device
;
FILR1	DI			;No interrupts until done
	LD	H,B		;Xfer vector table entry
	LD	L,C		;  to grab put/get index
	LD	C,(HL)		;P/u the PUT pointer
	INC	HL		;  and make the GET
	LD	B,(HL)		;  pointer equal so
	INC	HL		;  buffer contents show
	LD	(HL),C		;  as empty
	INC	HL
	LD	A,(HL)		;P/u the GET pointer to
	LD	(HL),B		;  check if in same page
FILR2	CP	B		;Is put/get in same page?
	JR	Z,FILR3		;Go if it is
	LD	H,A		;  else set up to free this
	CALL	FNPIU		;  page by finding next
	JR	FILR2		;Loop until next = 1st
FILR3	EI			;Interrupts back on
	RET
;
;	Reset a file device
;
FILR4	LD	HL,FR_FCB	;Turn off the FR or FS
	XOR	A
	SBC	HL,DE		;Is this the FR?
	LD	HL,FSSW+1
	JR	NZ,OFFS
	LD	(FRIOSW+1),A	;Turn off FR IO to disk
	LD	HL,FRSW+1	;Turn off FR to buffer
OFFS	LD	(HL),A		;Turn off FR or FS
	@@CLOSE			;Close the file
	CALL	NZ,$ERROR	;Show any close error
	RET
;
;	Process REWIND
;
FILREW	LD	A,D		;Rewind the specified
	OR	E		;  file (FCB given) if
	JP	Z,CMDERR	;  it is in use
	@@REW
	RET
;
;	Process PEOF
;
FILEOF	LD	A,D		;Check if a file device
	OR	E		;  was specified
	JP	Z,CMDERR	;Go if not - is error
	@@PEOF			;  else position to end
	RET
;
;	Process ID request
;
FILID	LD	A,D		;Bad command if not
	OR	E		;  FS or FR specified
	JP	Z,CMDERR	;Go on error
	LD	A,(DE)		;Make sure that it is
	RLCA			;  not already open
	JR	C,NOTNOW	;CF=already open
	PUSH	DE
	PUSH	IX		;Save buffer pointer
	LD	HL,FILEPMT	;Prompt for filespec
	@@DSPLY
	POP	HL		;Take file name
	LD	BC,31<8		;31 chars max
	@@KEYIN			;Get the filespec
	PUSH	AF		;Save flag state
	LD	C,0EH		;Turn the cursor back on
	@@DSP
	POP	AF		;Rcvr KEYIN exit state
	POP	DE
	RET	C		;Ret if BREAK from KEYIN
	PUSH	HL		;Save ptr to buffer
	@@FSPEC			;Fetch & parse filespec
	LD	HL,FS_FCB	;Ck if FILID req from
	XOR	A		;  FS or FR
	SBC	HL,DE		;What's the FCB?
	POP	HL		;Recover buffer
	LD	B,0		;LRL=256
	JR	NZ,FILFR	;Go if req from FR
	CALL	$OPEN		;Only OPEN a FS
	JR	$+5		;Branch around INIT
FILFR	@@INIT			;Open the receive file
	CALL	NZ,$ERROR	;Show any open error
	RET
;
NOTNOW	LD	HL,OPENMSG	;"File already open"
	@@DSPLY			;Show why ID failed
	RET
;
;	Routines to turn off file devices
;
FS_OFF	XOR	A		;File send
	LD	(FSSW+1),A
	RET
FR_OFF	XOR	A		;File receive
	LD	(FRSW+1),A
	RET
FRIO_OFF	XOR	A	;Dump to disk
	LD	(FRIOSW+1),A
	RET
;
;	Call various tasks (on each main loop)
;
TASKS	DI
;
	IF	.NOT.BUFFRD	;W fcn does this if bfrd
	CALL	TASK8A		;Try to receive from *CL
	ENDIF
;
	CALL	TASK8B		;Try to send to *CL
	EI
	CALL	TASKK		;Allow interrupts here
	IF	.NOT.BUFFRD
	DI			;If RS232 does not interrupt
	ENDIF			;Printer must be task
	CALL	TASK9
	EI
	JP	FRIOSW		;Check on dump to disk
;
;	INTERRUPT TASK 8
; WO/buffer    A is done once per main loop + int rate
;              B is done once per main loop + int rate
; W/buffer     A is done by wakeup feature + int rate
;              B is done once per main loop + int rate
;
	IF	.NOT.BUFFRD
TCB8	DW	TASK8
TASK8	CALL	TASK8A
	JP	TASK8B
	ENDIF
;
TASK8A	DI
	LD	A,0FFH		;CL recv On/Off
	OR	A
	RET	Z		;Done if CL recv off
;
;	@GET handler to keep interrupts off if possible
;
	LD	DE,CLDCB	;=> OPEN DCB
FNDDVR	LD	H,D		;Xfer to HL
	LD	L,E
	LD	A,(HL)		;Get DCB type
	BIT	5,A		;Is it linked?
	JR	NZ,LNKD		;Need CHNIO if so
	INC	HL		;=>address field of DCB
	LD	E,(HL)		;If routed, address is
	INC	HL		;  next DCB to use
	LD	D,(HL)		;  else EP of driver
	BIT	4,A		;Z = not routed
	JR	NZ,FNDDVR	;Loop till not routed
	AND	00001000B	;Can't talk to NIL device
	RET	NZ
	EX	DE,HL		;Address to HL
	LD	DE,RETADD	;Put RET address on stack
	PUSH	DE		;
	CP	2		;Set C,NZ for input request
	JP	(HL)		;Go to driver
;
LNKD	@@GET			;Use SVC if LINKED
RETADD	RET	NZ		;NZ means no char rcv'd
;
EIGHT	LD	B,0		;Eight bit mode switch
	INC	B
	DEC	B
	JR	NZ,XLTR1	;Go if 8 bit
	AND	7FH		;Strip bit 7
	RET	Z		;Always ignore nulls
	CP	7FH		;  & DELETE if not 8-bit
	RET	Z
;
;	Do XLATER after stripping high bit
;
XLTR1	CP	$-$		;Character to translate?
	JR	NZ,TSTNUL	;Go if not a match
XLTR2	LD	A,$-$		;Replace with xlated char
;
;	NULL Parm now only affects 8-bit mode
;
TSTNUL	OR	A		;Is char a null?
	JR	NZ,KEEPCH	;Go if not
ACCNUL	LD	B,0FFH		;Default to accept nulls
	INC	B		;NZ=nulls wanted
	DEC	B		;Z=don't accept nulls
	RET	Z
;
KEEPCH	PUSH	IX		;Place in CL input buf
	LD	IX,CLREC
	CALL	OUTPUT		;Out to the buffer if
	POP	IX		;  non-null or want nulls
	RET
;
TASK8B	LD	A,0FFH		;CL send On/Off for
	OR	A		;  handshaking
	RET	Z
	LD	C,0		;Now xmit a CTL0 to
	LD	DE,CLDCB	;Ck the status of the
	@@CTL			;  CL
	RET	NZ		;Indicates not ready
FRCPUT	LD	C,$-$		;Force a char out?
	XOR	A		;Clear it after p/u
	LD	(FRCPUT+1),A
	OR	C		;Check original status
	JR	NZ,FRCIT	;Go if force on
	PUSH	IX
	LD	IX,CLSEND	;Do we have a char to
	CALL	BUFGET		;  send to the CL?
	POP	IX
	RET	Z		;RET if not
	LD	C,A		;Save character
FRCIT	@@PUT			;Put it out
;
AUTXOFF	LD	A,0		;Check for auto XOFF
	OR	A		;On?
	RET	Z		;Quit if not
	SUB	C		;Matched char?
	RET	NZ		;Quit if not
	LD	(TASK8B+1),A	;Pause xmit (XOFF)
	RET
;
TASKK	@@KBD			;Scan the keyboard
	RET	NZ		;Error (or no key depressed)
	CP	BREAK		;Ck for brk 1st
	JR	Z,ISBRK		;Go on a Break
	OR	A		;Then for high bit set
	JP	M,CMDKEY	;Go if FN key
KISW	LD	B,0FFH		;KI On/Off
	INC	B
	DEC	B
	RET	Z		;Ret if KI is off
NOTBRK	PUSH	IX
	LD	IX,KIVCTR	;  else put key into
	CALL	OUTPGM		;  the output buffer
	POP	IX
	RET
;
ISBRK
	DI
	LD	DE,CLDCB	;Pt to *CL
	LD	C,1		;Send CTL 1, a
	@@CTL			;  Break request
	EI
	LD	BC,CLSEND
	CALL	FILR1		;Reset the CL buffer
	CALL	FS_OFF		;Turn off the *FS
	LD	BC,2000H	;Time delay
	@@PAUSE
	@@CKBRKC		;Reset the break bit
	LD	C,0		;Init the character
	LD	DE,CLDCB	;P/u the CL DCB
	DI
	@@PUT			;Send the 0
	EI
	RET
;
;	INTERRUPT TASK 9
;	Only if RS232 does not interrupt
;
	IF	.NOT.BUFFRD
TCB9	DW	TASK9		;Task ept
	ENDIF
TASK9	LD	B,3		;Max chars/pass
PRLOOP	LD	C,0		;Test printer status
	LD	DE,$-$		;PDCB$
PRDCB	EQU	$-2
	@@CTL			;Check the status
	RET	NZ		;Ret if unavailable
	PUSH	IX
	LD	IX,PRVCTR	;Get char from printer
	IF	BUFFRD
	CALL	PGMGET
	ELSE
	CALL	BUFGET		;Buffer if available
	ENDIF
	POP	IX
	RET	Z		;None to get, back
	LD	C,A
	@@PRT			;Output to printer
	DJNZ	PRLOOP		;Loop if more
	RET
;
;	Common routine to stuff various buffers
;
OUTPUT	LD	L,(IX)		;P/u pointer to
	LD	H,(IX+1)	;  buffer PUT
	LD	(HL),A		;Write char into buffer
	INC	(IX)		;Bump buffer pointer
	RET	NZ		;Go if still in same page
	CALL	NEXTAP		;Find next avail page
	JR	Z,DUMPCHR	;Go if no pages available
	LD	(IX+1),A	;Set index to new page
	LD	HL,FREEPG	;Reduce the amount of
	DEC	(HL)		;  free pages
	LD	A,7		;Less than 2K available?
	CP	(HL)
	RET	C		;  & return with NZ
	LD	(MAINLP+1),A	;Set flag for warning
	OR	A		;Ensure NZ return
	RET
;
;	No more pages available - keep last page
;
DUMPCHR	DEC	(IX)		;Dump character and
	XOR	A		;  return
	RET
;
;	The following code is not executed, as it is too
;	 slow at rates >= 1200 baud because interuppts are on.
;	DE must be loaded with KIVCTR.
;
	DB	0
	PUSH	IX		;Dev requesting the output
	POP	HL
	XOR	A		;The difference will be
	SBC	HL,DE		;  the offset into the
	LD	DE,DEVICE$	;  name table
	ADD	HL,DE
	LD	BC,4
	LD	DE,OVRRUN$+3
	LDIR
	LD	HL,OVRRUN$	;Display the buffer
	@@DSPLY			;  overrun error
	XOR	A		;  reuse current page
	RET
;
;	Check for character available in dynamic buffer
;
BUFGET	LD	L,(IX+2)	;P/u pointer to next
	LD	H,(IX+3)	;  buffer GET
	LD	A,L		;Check on in=out lo-order
	CP	(IX)
	JR	NZ,INNEOUT	;Go if in not equal out
	LD	A,H		;Check on in=out hi-order
	CP	(IX+1)
	RET	Z		;Ret if none to i/o
;
;	Buffer is not empty - Get next character
;
INNEOUT	LD	A,(HL)		;Get a char from buffer
	INC	(IX+2)		;Advance lo-order pointer
	RET	NZ		;Ret if still same page
	PUSH	AF		;Save the character
	CALL	FNPIU		;Find next page in use
	LD	(IX+3),A	;Stuff new page index
	POP	AF		;Recover the character
	DEC	H		;Set NZ return for rcvd
	RET
;
;	Routine to find next available page buffer
;
NEXTAP	LD	L,H		;Point to page buffer
	LD	H,LINKS<-8	;  index
	LD	A,(LINKS)	;Get next empty link
	PUSH	HL		;Save this index pointer
	LD	L,A		;Point to new link
	LD	A,(HL)		;Get what it links to
	OR	A		;Test if none left
	JR	NZ,GOTNAP	;Go if still more
	POP	HL		;Restore reg & return
	RET			;  with Z-flag for error
;
;	Found the next available page - set the links
;
GOTNAP	LD	(LINKS),A	;Update new next avail
	LD	A,L		;Xfer index of new page
	POP	HL		;Rcvr pointer to index
	LD	(HL),A		;  of old & link to new
	LD	L,A		;Repoint to new page's
	LD	(HL),0		;  index & show it is
	RET			;  the last one
;
;	Find next page in use
;
FNPIU	LD	A,(FREEPG)	;Show one additional
	INC	A		;  page is free
	LD	(FREEPG),A
	LD	A,(HIPAGE)	;P/u highest page avail
	LD	L,A		;Set HL to its index
	LD	A,H
	LD	H,LINKS<-8	;Show that page links to
	LD	(HL),A		; the one we just emptied
	LD	(HIPAGE),A	;Now update the new end
	LD	L,A		;Set HL to the emptied
	LD	A,(HL)		;  page, p/u what it
	LD	(HL),0		;  linked to, & show old
	RET			;  is end. Ret A=link
;
;	Execute a DOS command
;
DOSCMD	LD	HL,BASE-1
	LD	B,1		;Set LOW$
	@@HIGH$
	LD	HL,CMDPMT	;Issue prompt
	@@DSPLY
	LD	BC,80<8		;Max characters
	LD	HL,DUMMY	;=>input buffer
	@@KEYIN			;Get command request
	RET	C		;Back on Break
	INC	B
	DEC	B
	RET	Z		;  or CR only
	EX	DE,HL
	LD	HL,$-$		;Pt to CFLAG$
CFLAG	EQU	$-2
	BIT	0,(HL)		;Get current status
	PUSH	HL
	PUSH	AF		;Save memory freeze status
	SET	0,(HL)		;Freeze memory
	EX	DE,HL
	@@CMNDR			;Do the command
	LD	HL,CMPLTD	;Show cmd finished
	@@DSPLY
	POP	AF		;Get the previous status
	POP	HL		;  and CFLAG$ location
	RET	NZ		;Back if was set before
	RES	0,(HL)		;  else restore it
	RET
CMDPMT	DB	LF,LF,'Enter command:',CR
CMPLTD	DB	LF,'Command completed',CR
;
;	Messages
;
BRAKET	DB	'{  }',3	;Brackets around hex byte
FILEPMT	DB	29,10,'File name: ',3
OPENMSG	DB	29,10,'File already open',CR
MNUMSG	DB	LF
STAT1	DB	'                                    '
	DB	'                                   ',LF
	DB	'DUPLX ECHO  ECOLF ACCLF REWND PEOF  '
	DB	' DCC   CLS   8-B   CMD  HNDSH  EXIT',LF
	DB	'==1== ==2== ==3== ==4== ==5== ==6== '
	DB	'==7== ==8== ==9== ==0== '
	IF	@MOD4
	DB	'==:== ==-=='
	ENDIF
	IF	@MOD2
	DB	'==-== ====='
	ENDIF
	DB	LF
	DB	' *KI   *DO   *PR   *CL   *FS   *FR  '
	DB	' DTD   ???   ID    RES   ON    OFF',LF
STAT2	DB	'                                     '
	DB	'  ',CR
STATAB	DW	KISW+1,STAT2+2,DEVOUT+1,STAT2+8
	DW	PUTPR+1,STAT2+14,TASK8B+1,STAT2+19
	DW	TASK8A+2,STAT2+21,FSSW+1,STAT2+26
	DW	FRSW+1,STAT2+32,FRIOSW+1,STAT2+38
	DW	DPLXSW+1,STAT1+2,ECHOSW+1,STAT1+8
	DW	ECOLF,STAT1+14,ACCLFSW+1,STAT1+20
	DW	DSPCTRL+1,STAT1+38,EIGHT+1,STAT1+50
	DW	SHAKE+1,STAT1+61
FSNAME$	DB	'FS-Spec: ',3
FRNAME$	DB	'  FR-Spec: ',3
PAGSPR$	DB	'  Memory:   K',CR
CMDERR$	DB	'** Invalid command sequence **',CR
LILPG$	DB	'Warning! Less than 2K of buffer left '
	DB	' X-OFF transmitted',CR
;
;	File control blocks
;
CLDCB	DS	32
FS_FCB	DS	32
FR_FCB	DS	32
DUMMY	DS	81		;Used for dos cmd buffer also
;
;	Put/Get index pointers
;
KIVCTR	DW	0,0
PRVCTR	DW	0,0
CLREC	DW	0,0
CLSEND	DW	0,0
FSVCTR	DW	0,0
FRVCTR	DW	0,0
FREEPG	DS	1
;
;	Routines  to buffer I/O in pgm loop
;
OUTPGM	DI
	CALL	OUTPUT
	EI
	RET
PGMGET	DI
	CALL	BUFGET
	EI
	RET
;
;	Page buffer Link table
;
	ORG	$<-8+1<+8
LINKS	DS	1		;Link to next available
HIPAGE	DS	1		;Link to last available
	DS	1		;Init to 1st avail
	DS	1		;Init to last avail
	DS	252		;Space for linkage tables
;
;	Transmit and Receive File buffers
;
XMTBUF	DS	256
RCVBUF	DS	256
;
	SUBTTL	<'COMM initialization code'>
	PAGE OFF
*GET	LCOMMA:3		;Initialization code
;
	END	LCOMM
