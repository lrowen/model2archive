;LBLINK/ASM - LINK Command
	TITLE	<LINK - LS-DOS 6.2>
;
CR	EQU	13
*GET	SVCMAC:3		;SVC Macro equivalents
;
	ORG	2400H
;
LINK	LD	DE,FCB1		;Fetch source spec
	@@FSPEC
	JR	NZ,SPCERR1	;Exit if bad name
	LD	A,(DE)		;Must be a device
	CP	'*'
	JR	NZ,SPCERR
;
;	Fetch the second device spec
;
	LD	DE,FCB2		;Fetch destination spec
	@@FSPEC
	JR	NZ,SPCERR	;Exit if bad name
	LD	A,(DE)
	CP	'*'		;Must also be a device
SPCERR1	JR	NZ,SPCERR
;
;	Make sure source <> destination
;
	LD	HL,(FCB1+1)	;If devices are the same,
	LD	DE,(FCB2+1)	;  then quit
	SBC	HL,DE
	JR	Z,SPCERR
;
;	Locate a spare DCB for the link
;
	LD	DE,0
	@@GTDCB
	LD	A,33		;Init "No device space...
	JR	NZ,IOERR
	LD	(LINKDCB+1),HL	;Save pointer
;
;	Locate destination DCB address
;
	LD	DE,(FCB2+1)	;Grab DCB name
	@@GTDCB			;Locate its address
	JR	NZ,IOERR	;Jump if not found
	LD	(DSTDCB+1),HL	;Save destination
;
;	Locate source DCB address
;
	LD	DE,(FCB1+1)	;Get 1st DCB name
	@@GTDCB			;Locate in device tables
	JR	NZ,IOERR	;Jump if not found
	PUSH	HL		;Save pointer we used
	DI			;Can't interrupt
;
;	Save the old device vector while stuffing new
;
LINKDCB	LD	BC,$-$		;P/u link DCB address
	INC	L		;Bump to vector
	LD	A,(HL)		;Save what's there
	LD	(HL),C		;Stuff link address
	LD	C,A		;  into DCB of source
	INC	L		;  while saving old
	LD	A,(HL)		;  vector for storage
	LD	(HL),B		;  (could be a FCB)
	LD	B,A
;
;	Now set LINK bit and rest of LINK DCB block
;
	POP	HL		;Rcvr ptr to source DCB+0
	LD	A,(HL)		;Init the LINK bit
	PUSH	AF		;Save old TYPE byte
	AND	7		;Strip flags
	OR	20H		;Set Link bit
	LD	(HL),A		;Show source is linked
	LD	HL,(LINKDCB+1)	;P/u link DCB address
	POP	AF		;Rcvr source TYPE
	LD	(HL),A		;New LINK TYPE
	INC	L
	LD	(HL),C		;Stuff source vector
	INC	L
	LD	(HL),B
	INC	L		;Bypass dest TYPE
	INC	L
DSTDCB	LD	BC,$-$		;P/u destination DCB addr
	LD	(HL),C		;  & stuff into link DCB
	INC	L
	LD	(HL),B
	INC	L
	PUSH	HL		;Save name field pointer
	LD	DE,'/L'		;Let's find a link name
NAMLP	INC	D		;Bump "2nd" character
	@@GTDCB			;If we find this name
	JR	Z,NAMLP		;  look for another
	POP	HL		;Get name pointer
	LD	(HL),E		;  & stuff in the
	INC	L		;  selected link name
	LD	(HL),D
	EI			;Start tasks again
	LD	HL,0		;Show no error
	RET
;
;	Error processing
;
IOERR	LD	L,A		;Move error # into HL
	LD	H,0
	OR	0C0H		;Abbrev & return
	LD	C,A
	@@ERROR
	RET
SPCERR	LD	HL,SPCERR$	;Bad devspec found
	@@LOGOT
	LD	HL,-1
	RET
SPCERR$	DB	'Device spec required',CR
FCB1	DS	3		;Only 3-bytes needed
FCB2	DS	32
	END	LINK
