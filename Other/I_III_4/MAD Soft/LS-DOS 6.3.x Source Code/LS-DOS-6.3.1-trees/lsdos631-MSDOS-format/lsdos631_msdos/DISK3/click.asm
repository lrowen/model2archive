;CLICK/ASM - Device Click Filter
	TITLE	<CLICK/FLT - LS-DOS 6.3>
;
;
	IF	@MOD4
TONE	EQU	48H
LEN	EQU	18H
SNDPORT	EQU	90H
	ENDIF
	IF	@MOD2
LEN	EQU	180H		;Length
SNDPORT	EQU	0A0H
	ENDIF
;
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	VALUES:3		;Misc. equates
*GET	BUILDVER:3		;<631>
*GET	COPYCOM:3		;Copyright messages
;
	ORG	2400H
;
START
	@@CKBRKC
	JR	Z,STARTA	;Continue if no BREAK
	LD	HL,-1		; set up abort RET
	RET
;
STARTA	LD	(EXIT+1),SP	;Save stack for error exit
	CALL	DOINIT		;Do initialization
	CALL	INSTFLT		;Relocate/install filter
NORMEX	LD	HL,0		;Good exit
	RET
;
;	Xfer DCB ptr to IX & stuff addrs' in driver
;
DOINIT	PUSH	DE		;DE => DCB+0
	POP	IX		;Xfer to IX
	LD	(DCB),DE	;Xfer into header
;
;	Sign-on 
;
	PUSH	HL
	LD	HL,HELLO$	;Sign on message
	CALL	DSPLY
;
;	Check PARMS and if entry from SET command
;
	LD	DE,PRMTBL	;Point to parms
	POP	HL		;Recover cmdline posn
	@@PARAM			;Parse the parms
	JP	NZ,IOERR	;Exit on parm error
;
	@@FLAGS			;IY => System Flags Base
	BIT	3,(IY+'C'-'A')	;System request?
	JP	Z,VIASET	;"Install with SET
;
;	Before anything - Make sure hi-mem is avail
;
	BIT	0,(IY+CFLAG$)	;High memory available ?
	JP	NZ,CANT		;No - display error
;
;	Set up filter for CHAR if entered
;
CHARPRM	LD	DE,00		;Char parm lands here
	LD	A,D		;Check if entered and
	CP	E		;  is normal character
	RET	Z		;Done if not entered
	CP	0		;Check is MSB is altered
	LD	A,44		;Init "Parameter error
	JP	NZ,IOERR	;Bad if so
;
	LD	D,E		;Set up CP nn
	LD	E,0FEH		;Reverse it and 
	LD	(CKCHAR),DE	; put it in the filter
	RET
;*=*=*
;	Actual CLICK filter Code
;*=*=*
HEADER	JR	FILTER
OLDHI	DW	0		;HIGH$ before CLICK
	DB	5,'CLICK'
DCB	DW	$-$		;DCB pointing to CLICK
SPARE	DW	0		;System wants it
;
;	Is there a character here?
;
FILTER	LD	IX,(DCB)	;P/u DCB address
	JR	C,NOTCTL	;Go if Get
	JR	Z,NOTCTL	;  or Put
IS_CTL	@@CHNIO			;Pass the CTL call
	RET
NOTCTL	@@CHNIO			;Go to next in line
	RET	NZ		;None - RETurn NZ
;
;	Generate short Click
;
SOUND	PUSH	AF		;Save registers
CKCHAR	DW	00		;Space for a CP instruct
	JR	NZ,POPAF	; exit if CP above fails
SNDNOW	PUSH	BC
	PUSH	DE
	IF	@MOD2
	LD	BC,LEN		;Duration
	LD	A,-1		;ON value
	OUT	(SNDPORT),A	;Turn on sound
	LD	A,16		;Svc @PAUSE
	RST	28H		;Delay
	XOR	A		;OFF value
	OUT	(SNDPORT),A	;Turn off sound
	ENDIF
;
	IF	@MOD4
;
STFVALS	LD	DE,TONE<8!LEN	;D = Tone, E = Length
	LD	A,0		;Init on/off toggle
	LD	C,SNDPORT	;Point to port
;
;	ON portion
;
DURLP	INC	A		;Hold output high
	OUT	(C),A		;  for count of (B)
	LD	B,D		;Play tone
	DJNZ	$
;
;OFF portion
;
	DEC	A		;  for count of (B)
	OUT	(C),A
	LD	B,D		;Hold output low for
	DJNZ	$
;
	DEC	E		;Dec the duration
	JR	NZ,DURLP
	DJNZ	$		;Hold for 256 count
	ENDIF
;
	POP	DE		;Restore regs
	POP	BC
POPAF	POP	AF
	RET			;And RETurn
;
LENGTH	EQU	$-HEADER	;Length of Filter
;
;	INSTFLT - Relocate & Install Filter
;
INSTFLT	LD	(IX+0),47H	;Set Filter,Ctl,Get,Put
;
;	Pick up Old HIGH$ and save in driver
;
	LD	HL,0		;Get HIGH$
	LD	B,L
	@@HIGH$
	LD	(OLDHI),HL	;Stuff into header
;
;	Calculate New HIGH$ & stuff into DCB
;
	LD	BC,LENGTH	;Length of driver
	PUSH	BC		;Save length
	OR	A
	SBC	HL,BC		;HL => New HIGH$
	@@HIGH$			;(B=0) set new HIGH$
	INC	HL		;Pt to driver
	LD	(IX+1),L	;Stuff driver address
	LD	(IX+2),H	;  into DCB
;
;	Calc offset between source & dest for relo
;
	LD	DE,HEADER	;Start of driver
	PUSH	HL		;Save Source & Dest ptrs
	PUSH	DE
	OR	A		;Clear carry
	SBC	HL,DE		;Get offset
;
;	Relocate internal references in driver
;
	LD	IX,RELTBL	;Point to relocation tbl
	LD	B,H		;Move to BC
	LD	C,L
RLOOP	LD	L,(IX)		;Get address to change
	LD	H,(IX+1)
	LD	A,H
	OR	L
	JR	Z,RELDUN
	LD	E,(HL)		;P/U address
	INC	HL
	LD	D,(HL)
	EX	DE,HL		;Offset it
	ADD	HL,BC
	EX	DE,HL
	LD	(HL),D		;Put it back
	DEC	HL
	LD	(HL),E
	INC	IX
	INC	IX
	JR	RLOOP		;Loop till done
;
;	Relocation Table for Driver
;
RELTBL	DW	FILTER+2,0,0,0,0
;
;	Transfer Filter code to high memory
;
RELDUN	POP	HL		;HL => Source DE => Dest
	POP	DE
	POP	BC		;BC = length of filter
	LDIR			;Block move
	RET			;RETurn
;
;	DSPLY - Display a string
;
DSPLY	PUSH	DE		;Save DE
	@@DSPLY			;Display it
	POP	DE		;
	RET	Z		;Return if good
;
;	IOERR - Any fatal Errors come here
;
IOERR	LD	L,A		;Xfer error # to HL
	LD	H,0		;
	OR	0C0H		;Short msg & RETurn
	LD	C,A
	@@ERROR			;Display error
	JR	EXIT		;Go to exit routine
;
;	Error Handler
;
VIASET	LD	HL,VIASET$	;"Install with Set
	DB	0DDH
CANT	LD	HL,CANT$	;"No memory space
;
	@@LOGOT			;Log error
	LD	HL,-1		;Set abort code
;
EXIT	LD	SP,$-$		;P/u original SP
	@@CKBRKC		;Clear out break
	RET			;  and RETurn
;
PRMTBL	DB	'CHAR  '
	DW	CHARPRM+1
	DB	'C     '
	DW	CHARPRM+1
	NOP			;End of table
;
;
CANT$	DB	'No memory space available',CR
VIASET$	DB	'Must install via SET',CR
;
HELLO$	DB	'CLICK'
*GET	CLIENT:3
;
	END	START
