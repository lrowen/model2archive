;LCOMMA/ASM - COMM Initialization Code
;
;	Entry point to LCOMM
;
LCOMM
	@@CKBRKC		;Check for break
	JR	Z,LCOMMA	;Continue if not
	LD	HL,-1		;  else ABORT
	RET
;
LCOMMA	DI
	LD	(STACK),SP	;Save for exit
	PUSH	HL		;Save ptr to CMD buffer
	LD	HL,0
	@@BREAK			;Disable break vectoring
	EI
	LD	HL,HELLO$	;Issue the copyright
	@@DSPLY
	POP	HL
	LD	DE,CLDCB	;Point to FCB
	@@FSPEC			;Get the *CL spec
	JP	NZ,BADCL	;Go error if none
	LD	A,(DE)
	CP	'*'		;Ck for device spec
	JP	NZ,BADCL	;Go if not a device
	LD	DE,PRMTBL$
	@@PARAM			;Parse the parms
	PUSH	AF		;Save status
	CALL	NZ,$ERROR	;Display any error
	POP	AF
	JP	NZ,$ABORT	;  and then quit
;
	LD	B,0
	LD	DE,CLDCB	;Open the comm line
	@@OPEN
	PUSH	AF
	CALL	NZ,$ERROR	;Show any open error
	POP	AF
	JP	NZ,$ABORT	;  and then quit
	LD	C,2		;INIT function for hardware
	@@CTL			;Just in case
	LD	HL,GETMNU$	;How the user gets menu
	@@DSPLY
	XOR	A
	LD	(FS_FCB),A	;Init FCB's to OFF
	LD	(FR_FCB),A
	LD	DE,(PRNAME)	;Load 'PR' backwards
	@@GTDCB	
	LD	(PRDCB),HL	;Store address for @CTL
	@@FLAGS			;Set up IY
	PUSH	IY
	POP	DE
	LD	HL,'S'-'A'	;Offset to SFLAG$
	ADD	HL,DE
	LD	(SFLG),HL	;Store for later
	LD	HL,'K'-'A'	;Offset to KFLAG$
	ADD	HL,DE
	RES	0,(HL)		;Be sure BREAK bit is off
	LD	HL,'C'-'A'	;CFLAG$
	ADD	HL,DE
	LD	(CFLAG),HL
	BIT	1,(HL)		;Doing CMNDR?
	LD	HL,0
	LD	B,L
	JR	Z,$+3		;Use LOW$ if CMNDR
	INC	B
	@@HIGH$
	INC	HL		;Available for use
	DEC	H		;  by page buffers
	LD	B,H		;Set B to highest usable
	LD	HL,LINKS
	LD	A,LCOMM<-8	;Establish 1st usable
	LD	(HL),A		;Init to 1st available
	INC	L		;  page buffer
	LD	(HL),B		;Init to highest page
	INC	L		;  buffer available
	LD	(HL),A		;Init to begin & highest
	INC	L
	LD	(HL),B
;
;	Establish page buffer linkage table
;
DOLINKS	LD	L,A		;Init memory begin to
	INC	A		;  high bytes for as many
	LD	(HL),A		;  bytes as pages to top
	CP	B
	JR	NZ,DOLINKS
	LD	L,A
	LD	(HL),0		;Close out with zero
;
;	Establish starting page buffers for devices
;
	LD	H,4		;Init 1st at links+4
	LD	IX,KIVCTR
	CALL	INITBUF		;Init *KI page buffer
	LD	IX,PRVCTR
	CALL	INITBUF		;Init *PR page buffer
	LD	IX,CLREC
	CALL	INITBUF		;Init *CL-R page buffer
	LD	IX,CLSEND
	CALL	INITBUF		;Init *CL-S page buffer
	LD	IX,FSVCTR
	CALL	INITBUF		;Init *FS page buffer
	LD	IX,FRVCTR
	CALL	INITBUF		;Init *FR page buffer
;
;	Calculate free buffer space
;
	LD	H,LINKS<-8	;P/u hi-order link table
	LD	B,0		;Init count to zero
	LD	A,(LINKS)	;Find pointer to 1st spr
	LD	L,A
FBS1	LD	A,(HL)		;P/u pointer to next
	OR	A		;  spare & test if last
	JR	Z,FBS2		;Exit if no more
	INC	B		;Bump counter
	LD	L,A		;Show new pointer
	JR	FBS1
FBS2	LD	A,B		;Transfer the count
	LD	(FREEPG),A	;  and save it
	JR	SETUPT
;
;	Routine to establish starting page buffers
;
INITBUF	LD	(IX),0		;Show low-order PUT/GET
	LD	(IX+2),0	;  start at 0 reference
	PUSH	HL
	CALL	NEXTAP		;Find next available page
	JP	Z,NOBUFS	;Go if insufficient pages
	POP	HL
	LD	(IX+1),A	;Set high-order PUT/GET
	LD	(IX+3),A	;  page index pointers
	INC	H		;Bump to next entry in
	RET			;  link table & return
;
;	Routine to set up the task processor
;
SETUPT
	IF	.NOT.BUFFRD
	LD	DE,TCB8		;CL task process
	LD	C,8
	@@ADTSK
	LD	DE,TCB9		;Printer output task
	LD	C,9		;Only if RS232 does
	@@ADTSK			;  not interrupt
	ENDIF
;
	IF	BUFFRD
	LD	DE,CLDCB	;Turn on wakeup feature
	LD	IY,TASK8A	;Wakeup driver address
	LD	C,4		;Set addr CTL value
	DI
	@@CTL			;Send to Com driver
	EI
	LD	(OLDVEC),IY	;Save previous state
	ENDIF
;
	LD	HL,LFEEDS	;Clear most of screen
	@@DSPLY
;
;	Transfer any translation characters
;
	LD	A,(XLATES+1)	;Transfer the output
	LD	(XLTS1+1),A	;  translation character
	LD	A,(XLATES)
	LD	(XLTS2+1),A
;
	LD	A,(XLATER+1)	;Transfer the input
	LD	(XLTR1+1),A	;  translation character
	LD	A,(XLATER)
	LD	(XLTR2+1),A
;
	LD	A,(NULLPRM)	;Transfer the null parm
	LD	(ACCNUL+1),A
	LD	A,(XONP)	;Transfer the XON/XOFF
	LD	(XONP1),A	;  parms
	LD	A,(XOFFP)
	LD	(XOFFP1),A
	LD	(XOFFP2),A
	JP	MAINLP
;
;	Error handling on initialization
;
NOBUFS	LD	HL,NOBUFS$	;"Not enuf mem for buffers
	DB	0DDH
BADCL	LD	HL,BADCL$	;"Need RS-232 device name
	@@LOGOT
	JP	$ABORT
;
;	Messages
;
HELLO$	DB	'COMM'
*GET	CLIENT:3
	IF	@MOD4
GETMNU$	DB	'Use <CLEAR-8> for menu',LF,CR
	ENDIF
	IF	@MOD2
GETMNU$	DB	'Use <ESC-8> for menu',LF,CR
	ENDIF
LFEEDS	DB	LF,LF,LF,LF,LF,LF,LF
	DB	LF,LF,LF,LF,LF,LF,LF,LF,LF,LF,LF,14,3
;
	DC	32,0		;Patch space
;
BADCL$	DB	'Comm Line driver not specified',CR
NOBUFS$	DB	'Insufficient memory to establish buffers',CR
DEVICE$	DB	' KI  PR CL-RCL-S FS  FR ????'
OVRRUN$	DB	'** xxxx Buffer overrun **',3
PRNAME	DB	'PR'
;
PRMTBL$	DB	'XLATES'
	DW	XLATES
	DB	'XS    '
	DW	XLATES
	DB	'XLATER'
	DW	XLATER
	DB	'XR    '
	DW	XLATER
	DB	'NULL  '
	DW	NULLPRM
	DB	'N     '
	DW	NULLPRM
	DB	'XON   '
	DW	XONP
	DB	'XOFF  '
	DW	XOFFP
	NOP
;
NULLPRM	DW	-1		;Default to accept nulls
XONP	DW	'Q'-40H		;Ctl-Q
XOFFP	DW	'S'-40H		;Ctl-S
XLATES	DW	0
XLATER	DW	0
