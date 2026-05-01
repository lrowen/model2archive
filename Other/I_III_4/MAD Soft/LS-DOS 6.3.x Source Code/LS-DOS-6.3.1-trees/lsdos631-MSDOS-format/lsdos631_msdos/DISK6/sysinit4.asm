;SYSINIT4/ASM - LS-DOS 6.3
;
;	This is the initialization part of SYSRES
;
TRKREG	EQU	0F1H		;FDC track register
KB1	EQU	0F401H		;Keyboard row 1
KB67	EQU	0F460H		;Keyboard rows 6&7
KB7	EQU	0F440H		;Keyboard row 7
BOL	EQU	1DH		;Beginning of line
;
	ORG	1E00H+START$
;
	DI
	LD	HL,@RSTNMI	;Reset NMI vector to
	LD	(@NMI+1),HL	;  SYSRES's needs
	LD	HL,PAKNAM$	;Pt to pack name
	LD	DE,2*80+CRTBGN$+30
	LD	BC,8
	LDIR			;move pack name to crt
	LD	C,8		;B contains 0 already
	INC	DE		;Leave 2 spaces
	INC	DE
	LDIR			;Move pack date to crt
	INC	DE
	INC	DE
	LD	C,18
	LD	HL,SERIAL$
	IF	@BLD631
	NOP			;<631>
	NOP			;<631>
	ELSE
	LDIR
	ENDIF
;
;	Initialization routines
;
	XOR	A		;Clear out stack area
	LD	HL,STACK$+1	;Stack start +1
CLRLOOP	DEC	L		;Move down a byte
	LD	(HL),A		;Now loop and fill
	JR	NZ,CLRLOOP	;  and fill with 0's
;
	IM	1
	LD	SP,STACK$	;Set the stack area
	XOR	A
	LD	(LBANK$),A	;Set logical bank #
	OUT	(0E4H),A	;Disable INTRQ & DRQ
;
	LD	HL,S1DCB$
ZERDCB	LD	(HL),A		;Zero spare dcb area
	INC	L
	JR	NZ,ZERDCB
;
	LD	A,(MODOUT$)	;Set hi-speed
	OUT	(0ECH),A	;  and external bus
	LD	A,(WRINT$)
	OUT	(0E0H),A	;Enable RTC interrupts
	LD	A,(OPREG$)	;Set memory configuration
	LD	B,A
	LD	A,0A7H		;Value for AUX/RAM
	LD	C,@OPREG	;Set the memory mgt port
	OUT	(C),B		;Bring up reg RAM
	LD	HL,-1		;Ck for extended RAM
	LD	(HIGH$),HL
	LD	(PHIGH$),HL
;	Check the BANKS
	LD	D,(HL)		;Save what's in RAM
	LD	(HL),55H	;Stuff in reg RAM
	OUT	(C),A		;Switch in alt RAM
	LD	E,(HL)		;Save the byte there
	LD	(HL),A		;Stuff alt RAM
	OUT	(C),B		;Switch to reg RAM
	CP	(HL)		;See what's there now
	LD	(HL),D		;Restore original value
	OUT	(C),A		;Back to alt RAM
	LD	(HL),E		;Restore original byte
	OUT	(C),B		;Back to reg RAM
	LD	A,0FEH		;Init BAR$ for bank-0
	JR	Z,$+4		;Bypass if only 64K
	LD	A,0F8H		;Init BAR$ for bank 0-2
	LD	(BAR$),A	;Load Bank Avail RAM
	LD	(BUR$),A	;Load Bank Used RAM
	LD	A,(FEMSK$)	;P/u port FE mask
	OUT	(0FEH),A	;  & set it
	DC	3,0		;Space for a JUMP
;
;	Update DCT$ info for SYSTEM drive
;
	LD	A,(BOOTST$)	;P/u Boot Step rate
	AND	3		;Strip all but it
	LD	B,A		;Save tempy
	LD	HL,DCT$+3	;Pt to DCT step
	LD	A,(HL)		;P/u DCT Step
	AND	0FCH		;Strip step rate
	OR	B		;Merge in Boot step
	LD	(HL),A		;Update DCT
	IN	A,(TRKREG)	;Update DCT with current
	LD	(DCT$+5),A	;  track posn of head
;
	LD	DE,KIDCB$	;Flush type,init ptrs.
	LD	A,3
	CALL	@CTL
	EI			;Interrupts on
;
;	P/u CONFIG status & set ZERO byte
;
	LD	HL,ZERO$
	LD	A,(HL)		;set to NOP if SYSGEN'd
	LD	(HL),0		;Make always zero byte
	PUSH	AF		;save SYSGEN flag
;
;	Check if date prompt is to be suppressed
;
	LD	A,(DTPMT$)	;No prompt for date?
	OR	A
;
;	Check on currency of date
;
	LD	HL,DATE$	;Point to Year
	LD	C,(HL)		;  & save in reg C
	LD	(HL),0		;  while resetting to zero
	INC	HL		;Bump to day
	LD	B,(HL)		;  & save in reg B
	LD	(HL),0		;  while resetting to zero
	INC	HL		;Bump to Month
	LD	A,(HL)		;  & save in Reg A
	LD	(HL),0		;  while resetting to zero
	JP	NZ,TIMIN	;Ck time if DATE=OFF
	LD	L,CFGFCB$+31&0FFH	;Reset pointer
;
	IF	@INTL
	LD	(HL),B		;Stuff day
	DEC	HL
	LD	(HL),A		;Stuff month
	ELSE
	LD	(HL),A		;Stuff month
	DEC	HL
	LD	(HL),B		;Stuff day
	ENDIF
;
	DEC	HL
	LD	(HL),C		;Stuff Year
	EX	DE,HL		;  & point DE to CFGFCB$+29
	DEC	A		;Check for month range <1-12>
	CP	12		;OK if 0-11 now
	JR	C,DATIN1
;
DATIN	LD	HL,21<8!27	;Set video row,col
	LD	DE,DATEPR	;DATE? question
	LD	BC,8<+8!'0'	;Set buf len & char
	CALL	GETPARM		;Get response
	JR	NC,DATIN	;Jump on format error
DATIN1	LD	A,(DE)		;Is year a leap year?
	IF	@BLD631
	CP	0CH		;<631>
	JR	NC,1ED7H	;<631>
	ADD	A,64H		;<631>
	LD	(DE),A		;<631>
	ENDIF
	LD	C,A		;Save year for later
	SUB	80		;Reduce for range test
	CP	' '
	JR	NC,DATIN
	AND	3
	LD	A,28		;Init February
	JR	NZ,NOTLEAP
	LD	HL,DATE$+3+1	;Set leap flag
	SET	7,(HL)
	INC	A		;Feb to 29 days
NOTLEAP	LD	HL,MAXDAY$+2	;Set Feb max day #
	LD	(HL),A
;
	IF	@INTL
	NOP			;Keep same length
	ELSE
	INC	DE		;Bump to DAY
	ENDIF
	INC	DE		;Bump to month & get it
	LD	A,(DE)
	LD	B,A		;Save month in reg B
	DEC	A		;Range check
	CP	12
	JR	NC,DATIN	;Go if 0 or >12
	DEC	HL		;Point to Jan entry
	ADD	A,L		;Index the month
	LD	L,A
;
	IF	@INTL
	INC	DE		;Point to day
	ELSE
	DEC	DE		;Point to day
	ENDIF
;
	LD	A,(DE)		;P/u day entry
	DEC	A		;Reduce for test (0->FF)
	CP	(HL)
	JR	NC,DATIN	;Go if too large (or 0)
;
;	Range checks OK - move into DATE$
;
	LD	HL,DATE$+2
	INC	A		;Compensate for DEC A
	LD	(HL),B		;Stuff month
	DEC	L
	LD	(HL),A		;Stuff day
	DEC	L
	LD	(HL),C		;Stuff year
;
;	Date is in DATE$ - display it
;
	LD	A,C
	PUSH	AF		;  & save it for later
	AND	3		;Check on leap year
	LD	HL,MAXDAY$+2	;Init and adjust Feb
	LD	(HL),28		;  as required
	JR	NZ,$+3
	INC	(HL)		;Bump to 29
	LD	A,(DATE$+2)	;P/u month & xfer to B
	LD	B,A
	LD	A,(DATE$+1)	;P/u day of month
;
;	Compute day of year and day of week
;
	LD	L,A		;Start off with days
	LD	H,0		;  in this month
	LD	DE,MAXDAY$
DAYLP	LD	A,(DE)
	ADD	A,L		;8 bit add to 16 bit
	LD	L,A
	ADC	A,H		;Add in hi order & carry
	SUB	L		;Subtract off lo order
	LD	H,A		;Update hi order
	INC	DE
	DJNZ	DAYLP
	EX	DE,HL		;Move day of year to DE
	LD	HL,DATE$+3	;  and store
	LD	(HL),E
	INC	HL
	LD	A,D		;Get bit "8"
	OR	(HL)		;  and OR it in
	LD	(HL),A		;Then put it back
	EX	DE,HL		;Get DOY back to HL
	POP	AF		;Pop the year & mask
	SUB	80		;Compute day of week
	LD	E,A		;  offset
	ADD	A,3		;offset, get # of leaps first
	RRCA
	RRCA
	IF	@BLD631
	AND	0FH		;<631>
	ELSE
	AND	7		;can be 0-5
	ENDIF
	ADD	A,E
	LD	E,A		;And add it in
	LD	D,0		;Add into HL
	ADD	HL,DE
	INC	HL		;To start in right place
	LD	A,7		;Now divide by 7 
DIV7	CALL	@DIV16		;Call lowcore divide
	INC	A		; adjust to 1-7
	LD	B,A		;Save in reg B
	RLCA			;Shift to bits 1-3
	LD	C,A		;Save tempy
	LD	HL,DATE$+3+1
	LD	A,(HL)		;Pack into field
	AND	0F1H
	OR	C
	LD	(HL),A
	PUSH	BC
	LD	HL,21<8!27	;Set video row,col
	LD	B,3		;Set function code 3
	CALL	@VDCTL		;  to position cursor
	POP	BC
	LD	HL,DAYTBL$
	CALL	SPACE4		;Write out the DAY
	LD	A,','
	CALL	@DSP
	LD	A,' '
	CALL	@DSP
	LD	A,(DATE$+2)	;P/u month number
	LD	B,A
	LD	L,MONTBL$&0FFH	;Reset HL for month table
	CALL	DSPMDY		;Write out the month name
	LD	A,' '
	CALL	@DSP
	LD	A,(DATE$+1)	;P/u day
	DEC	B		;From 0 to X'FF'
DIV10	INC	B		;Divide by 10
	SUB	10		;  with quotient in B
	JR	NC,DIV10
	PUSH	AF		;Save remainder (-10)
	LD	A,B		;P/u quotient
	ADD	A,'0'		;Change to ASCII
	CP	'0'		;Zero?
	CALL	NZ,@DSP		;Display if not
	POP	AF		;Get back remainder
	ADD	A,3AH		;Change to ASCII
	CALL	@DSP
	LD	A,(DATE$)	;Get year
	IF	@BLD631
	LD	HL,76CH		;<631>
	ADD	A,L		;<631>
	LD	L,A		;<631>
	ADC	A,H		;<631>
	SUB	L		;<631>
	LD	H,A		;<631>
	LD	DE,PARTYR+1	;<631>
	CALL	@HEXDEC		;<631>
	LD	HL,PARTYR	;<631>
	CALL	@DSPLY		;<631>
	ELSE
	SUB	80-'0'		;Offset only and convert to ascii
	LD	L,'8'		;init to 198x
	CP	10+'0'		;In 1980's?
	JR	C,WAS80		;Go if so
	INC	L		;change to 199x
	SUB	10		;Sub off decade
WAS80	LD	H,A		;set ones digit
	LD	(PARTYR+4),HL	;stuff into dsplay string
	LD	HL,PARTYR
	CALL	@DSPLY
	ENDIF
;
;	Prompt for time
;
TIMIN	LD	A,(TMPMT$)	;Time to be prompted
	OR	A
	JR	NZ,SELDCT	;Skip if not
TIMIN0	LD	B,3
	LD	HL,CFGFCB$+31	;Init time string
TIMINIT	LD	(HL),0		;Init 00:00:00
	DEC	HL
	DJNZ	TIMINIT
	LD	A,-1		;Make non-zero
	LD	(ISTIM),A
	LD	HL,22<8!27
	LD	DE,TIMEPR	;Set prompt message
	LD	BC,8<+8!'0'	;Set len & separ char
	CALL	GETPARM
	JR	NC,TIMIN0	;Loop on format error
	LD	HL,CFGFCB$+31
	LD	A,23
	CP	(HL)		;Test hour range
	JR	C,TIMIN0
	DEC	HL
	LD	A,59
	CP	(HL)		;Test minute range
	JR	C,TIMIN0
	DEC	HL
	CP	(HL)		;Test the second range
	JR	C,TIMIN0
	LD	DE,TIME$	;Move the time value
	LD	BC,3		;  into the TIME$ field
	LDIR
;
;	Check on any AUTO command
;
SELDCT	LD	B,80H
	CALL	@PAUSE
	LD	HL,INBUF$
	LD	A,(HL)		;Pt to 1st byte of AUTO
	CP	'*'		;BREAK disable?
	JR	NZ,CKDCR
	INC	HL
	LD	A,0E6H		;Set BREAK bit in flag by
	LD	(STUB1+1),A	;  changing RES 4,(SFLAG$)
				;  to SET 4,(SFLAG$)
	JR	AUTO?
GETKB17	CALL	ENADIS_DO_RAM
	LD	A,(KB1!KB7)	;scan row 1 & 7
	RET
CKDCR	CALL	GETKB17		;Strobe keyboard
	BIT	4,A		;Is 'D' depressed?
	PUSH	HL		;Save auto command pt
	LD	HL,@ABORT	;P/u abort address
	EX	(SP),HL		;Swap them around
	JP	NZ,@DEBUG	;DEBUG on <D>
	POP	DE		;Stack integrity
	CPL
	AND	1		;No AUTO if <ENTER>
	JR	Z,NOAUT1
AUTO?	LD	A,(HL)		;Any AUTO command?
	CP	CR		;None if equal
NOAUT1	POP	DE		;Get back SYSGEN flag
	LD	A,D		;  & move into reg A
	LD	DE,@EXIT	;Where to go after boot
	LD	BC,0		;Init BC(HL)=0 for @EXIT
	JR	Z,NOAUT		;Go if no AUTO
	PUSH	HL		;Save buffer pointer
	LD	HL,CURSET	;Point to cusor setting
	INC	(HL)		;Bump it down a line
	POP	HL		;Recover INBUF$ pointer
	LD	DE,@CMNDI	;Lo order of @CMNDI
	PUSH	DE		;Put on stack for RET
	LD	B,H		;Put INBUF$ pointer on
	LD	C,L		;  stack for @CMNDI
	LD	DE,@DSPLY	;But do this first
NOAUT	PUSH	DE		;Put on stack for RET
	PUSH	BC		;Either INBUF$ or 0
	LD	HL,STUB
	LD	DE,MOD3BUF+80	;Must move out of way
	LD	BC,STUBLEN	;  amount to move
	PUSH	DE		;Add ret vector to stack
	LDIR			;Move stub up
	CALL	GETKB67
	LD	DE,DCT$		;Set up to move DCT's
	LD	HL,MOD3BUF	;  from configed area
	LD	BC,80		;Count for DCTs (8*10)
	EXX			;Keep in alternate set
	AND	82H		;Load config if zero
	RET	NZ		;No config > Go back
	LD	HL,21<8		;Set to line 21
	LD	B,3		;Position cursor
	CALL	@VDCTL
	LD	HL,CONFIG$	;Show sysgen message
	CALL	@DSPLY
	LD	DE,CFGFCB$	;Set up to load config
	JP	@LOAD		;Go to load config
;
CONFIG$	DB	'** SYSGEN **',03	; Config DSP
;
GETKB67	LD	HL,KB67		;Check <CLEAR> key
	LD	C,A
	CALL	ENADIS_DO_RAM
	LD	A,C
	OR	(HL)		;Key down OR not SYSGENed
	RET
;
;	Final initialization code
;
STUB	LD	HL,SFLAG$
STUB1	RES	4,(HL)		;Test or SET Break bit
				;  without changing Z/NZ
	JR	NZ,NOTSG	;Go if no SYSGEN found
	LD	HL,MODOUT$	;P/u ptr to port mask
	LD	A,(HL)		;P/u mask byte
	OUT	(0ECH),A	;Speed it up
	EXX			;Set to move DCT's
	LDIR			;Move 'em
	CALL	@ICNFG		;Init config
NOTSG
	LD	C,7
SETCYL0
	CALL	@GTDCT
	BIT	3,(IY+3)	;If hard drive, don't stuff FF
	JR	NZ,NOFF		;  & don't restore
	LD	(IY+5),0FFH	;Set in case no restore
	LD	A,(RSTOR$)	;Do we restore the drives?
	OR	A
	CALL	Z,@RSTOR	;Restore drives 1-7
NOFF	DEC	C
	JR	NZ,SETCYL0
	LD	HL,21<8		;Set cursor
CURSET	EQU	$-1
	LD	B,3
	CALL	@VDCTL
;
;	Detect Model 4 or 4P and adjust TFLAG$
;	Look at 'MODEL' at 4018H. If so MOD-4P (5)
;
;
	LD	DE,'OM'
	LD	HL,(4018H)	;P/u 4P rom leftover
	SBC	HL,DE		;Check if it's 'MO'
	LD	A,4		;Init for MOD 4 REG.
	JR	NZ,MOD4REG
	LD	A,5		;Change to MOD 4P
MOD4REG	LD	(TFLAG$),A
;
	LD	HL,@RST38
	LD	(HL),0C3H	;Activate task processor
	POP	HL		;Pop INBUF$
	RET			;To @CMD or @DSPLY,@CMNDI
	DC	12,0		;Space for more code
STUBEND	EQU	$
STUBLEN	EQU	STUBEND-STUB
;
;	Date & Time prompting
;
GETPARM	PUSH	BC		;Save separator char
	PUSH	DE		;Save message pointer
	LD	B,3
	CALL	@VDCTL		;Position the cursor
	POP	HL		;Recover message pointer
	CALL	@DSPLY		;  & display the message
	LD	HL,OVERLAY	;Buffer for reply
	POP	BC
	PUSH	BC
	CALL	@KEYIN		;Get reply & wait a bit
	XOR	A		;  disable test
	OR	B
	POP	BC		;  of key prior to AUTO
	JR	NZ,GETP1	;Go if some chars
	LD	A,$-$
ISTIM	EQU	$-1		;See if time prompt
	OR	A
	RET	Z		;Back if date, bad
	SCF
	RET			;If time, good return
GETP1	PUSH	BC
	LD	B,40H
	CALL	@PAUSE		;  to let finger off
	POP	BC
;
;	Routine to parse DATE entry
;
PARSDAT	LD	DE,CFGFCB$+31	;Point to buf end
	LD	B,3		;Process 3 fields
PRSD1	PUSH	DE		;Save pointer
;
;	Routine to parse a digit pair
;
	CALL	PRSD3		;Get a digit
	JR	NC,PRSD2	;Jump if bad digit
	LD	E,A		;Multiply by ten
	RLCA
	RLCA
	ADD	A,E
	RLCA
	LD	E,A
	CALL	PRSD3		;Get another digit
	JR	NC,PRSD2	;Jump on bad digit
	ADD	A,E		;Accumulate new digit
	LD	E,A		;Save 2-digit value
	SCF			;Show valid
	LD	A,E		;Xfer field value
PRSD2	POP	DE		;Recover pointer
	RET	NC		;Ret if bad digit pair
	LD	(DE),A		;Else stuff the value
	DEC	B		;Loop countdown
	SCF
	RET	Z		;Ret when through
	DEC	DE		;Backup the pointer
	LD	A,(HL)		;Ck for valid separator
	INC	HL		;Bump pointer
	CP	':'		;Check for colon ':'
	JR	Z,PRSD1		;  loop if match
	CP	C		;Separator char required
	JR	NC,PRSD4	;Exit if bad char
	CP	CR		;Is it a CR?
	JR	NZ,PRSD1	;Go if not
	LD	A,B
	DEC	A		;Was B one?
	JR	NZ,PRSD1
	LD	A,(ISTIM)	;Are we doing time?
	OR	A
	JR	Z,PRSD1		;Go if not
	SCF
	RET			;Back, good time
PRSD3	LD	A,(HL)		;P/u a digit &
	INC	HL		;  convert to binary
	SUB	30H
PRSD4	CP	10
	RET
;
;	Routine to display month or day of week
;
SPACE4	PUSH	HL		;Print 4 SPACES
	LD	HL,SPACE4$	;  point to string
	CALL	@DSPLY
	POP	HL
DSPMDY	DEC	B		;Point to Bth entry
	LD	A,L		;  in table
	ADD	A,B
	ADD	A,B
	ADD	A,B
	LD	L,A
	LD	B,3		;Print 3 characters
DSPM1	LD	A,(HL)
	INC	HL
	CALL	@DSP
	DJNZ	DSPM1
	RET
PARTYR	DB	', 198 ',30,3
;
	IF	@INTL
DATEPR	DB	30,'Date DD/MM/YY ? ',3
	ELSE
DATEPR	DB	30,'Date MM/DD/YY ? ',3
	ENDIF
;
TIMEPR	DB	30,'Time HH:MM:SS ? ',3
SPACE4$	DB	'   ',03,03	;3 or 4 space string
	IF	@BLD631
SERIAL$	DC	21,00		;<631>What was used for Serial # field in 630
	ELSE
SERIAL$	DB	'Serial# A400B00110',3EH,99H,0C9H
	ENDIF
	DC	32,00		;Space for message, or??
