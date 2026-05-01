;CMDFIL/ASM - 08/16/82
	TITLE	'<CMDFILE - Version 1.5>'
DOS6	EQU	-1
NOTTAPE	EQU	-1
NOTDISK	EQU	.NOT.NOTTAPE
LDOS	EQU	-1
EDAS	EQU	0
SIMUTEK	EQU	0
MOD1	EQU	0
MOD3	EQU	.NOT.MOD1
EXPAND	DEFL	-1
	IF	EDAS!SIMUTEK!LDOS
EXPAND	DEFL	0
	ENDIF
;*=*=*
;	COMMAND FILE UTILITY PROGRAM
;
;	Copyright (C) 1979
;	MISOSYS
;	5904 Edgehill Drive
;	Alexandria, VA. 22303
;*=*=*
;
;	Change Log
;
; 12-11-79 >ADDED OFFSET DRIVERS
; 12-11-79 >ADDED YESNO ROUTINE
; 12-12-79 >ADDED SUPPRESSION OF KBD DBNC DRVR OFFSET
; 12-15-79 >RECYCLE TAPE OUTPUT TO ITSELF ON ANOTHER
; 12-15-79 >SHIFTED INIT OF LO & HI TO AFTER 'NOPRT'
; 12-20-79 >ADD BYPASS TO OUTPUT LO/HI IF INPUT FROM TAPE
; 12-21-79 >ADDED PRINT & DSPLY ROUTINES FOR NON-DOS USER
; 12-22-79 >ADDED LO/HI DETECTION FOR TAPE INPUT
; 12-25-79 >ADDED PATCH TO 'SYSTEM' DOS HOOK AT 41E2H
; 12-27-79 >CORRECTED TRAADR WHEN OFFSET OR USER CHANGE
; 07-09-80 >Converted messages to lower case
; 07-26-80 >Added test to <Q>uery, added default CMD
;	   >added FSPEC & FEXT, suppresses offset
;	   >if blkadr < 4200H
; 09-21-80 >added wrret after cas prompt
; 09-26-80 >added offset restriction option
; 09-28-80 -> added routine to read VTOS ISAM file
; 01/19/81 -> added EOF correction in close & modified
;		for LDOS directory function
; 02/01/81 -> Corrected offset ORG if keyboard debounce
; 02/07/81 -> corrected EOF & offset e/w kbd dbnc
; 06/15/81 -> Model III conversion
; 06/18/81 -> Modified Query for /EXT option
; 09/16/81 - Added CMDFILEA/FX3
; 10/16/81 - Updated to latest - couldn't find deck
;	& added PATCH1 to correct offsetting if <4200
; 10/26/81 - Convert tape FILNAM to U/C
; 10-30-81 - Added patch2 for l/c -> U/C tape filename
; 11/04/81 - Adapted to one version, improved disk driver
;	& altered YESNO to reprompt
; 12/11/81 - Corrected TAPERD clobbering HL memory ptr
; 01/14/82 - Corrected read of SYS6/SYS7
; 01/27/82 - Corrected EOF+1 due to BUFPTR handling
; 08/15/82 - Corrected CHKMEM to RET NZ
;*****
LF	EQU	10
CR	EQU	13
CTOFF	EQU	01F8H
CTON	EQU	0212H
CSTAR	EQU	022CH
RDBYT	EQU	0235H
WRBYT	EQU	0264H
WRLDR	EQU	0287H
RDLDR	EQU	0296H
TAPADR	EQU	0314H
SETCAS	EQU	3042H
SELECT	EQU	37E1H
KDCB$	EQU	4015H
DDCB$	EQU	401DH
CURSOR$	EQU	4020H
PDCB$	EQU	4025H
@EXIT	EQU	402DH
LVLFLG	EQU	402FH
BASIC1	EQU	6CCH
BASIC3	EQU	1A19H
HIGH1	EQU	4049H
HIGH3	EQU	4411H
FEXT1	EQU	4473H
FEXT3	EQU	444BH
KIADR1	EQU	3E3H
KIADR3	EQU	3024H
;
CKDRV1	EQU	44B8H
CKDRV3	EQU	4209H
DODIR1	EQU	4463H		;LDOS Model I
DODIR3	EQU	4419H		;Model III only
;
	PAGE
;
	IF	NOTDISK
	ORG	41E2H
	JP	5400H
	ENDIF
;
	IF	DOS6
*GET	SVCMAC
	ORG	2600H
BUFFER$	DS	256
STACK	DS	256
START	LD	SP,$
	LD	HL,0
	LD	B,L
	@@HIGH$
	LD	(HIGHEST+1),HL
	LD	HL,RST24
	LD	A,0C3H
	LD	(24),A
	LD	(25),HL
	ELSE
*GET	SVCMAC13
	ORG	5200H
BUFFER$	DS	256
STACK	DS	256
START	LD	SP,$
	LD	A,(125H)	;Ck Mod I or III
	CP	'I'		;Is it a III?
	JR	Z,MODEL3	;Go if Model III
	LD	A,3
	LD	(CASMSG+24),A	;Strip <H,L> from prompt
	LD	HL,@KEY
	LD	(PRMPT+1),HL	;Chg SETCAS to get KEY
	LD	HL,HIGH1	;Reset HIGH$ pointer
	LD	(HIGHEST+1),HL
	LD	HL,FEXT1	;Reset FEXT call
	LD	(FEXT+1),HL
;
	IF	.NOT.LDOS
	LD	HL,BASIC1	;Reset BASIX exit vector
	LD	(BASIC+1),HL
	ENDIF
;
	LD	HL,KIADR1	;Reset debounce inhibit
	LD	(KIHOOK),HL
;
	IF	LDOS
	LD	HL,DODIR1
	LD	(DODIR+1),HL
	LD	HL,CKDRV1
	LD	(NOEXT+1),HL
	ENDIF
;
MODEL3
	ENDIF
	LD	HL,HELLO$
	CALL	DSPLY
	XOR	A
	LD	(PRTFLG),A
	LD	HL,PRTREQ
	CALL	YESNO
	JR	C,NOPRT
	LD	(PRTFLG),A
NOPRT	LD	HL,MEMBUF+3
	LD	(MEMPTR),HL
	XOR	A
	LD	(HLDFLG),A	;Zero DBNC hold flag
	LD	H,A
	LD	L,A
	LD	(OFFSET),HL
	LD	(HIADR),HL	;Init hi and lo
	DEC	HL
	LD	(LOADR),HL
;
BEGIN	LD	SP,START
	LD	HL,INPMPT
	CALL	GETARG
	JR	Z,OUTPUT
	LD	A,(HL)
	AND	5FH		;Strip lower case
;
	IF	EXPAND!LDOS
	CP	'Q'
	JP	Z,QUERY
	ENDIF
;
	LD	HL,(MEMPTR)
	DEC	HL		;Backup over TRAADR
	DEC	HL
	DEC	HL
	DEC	HL
	CP	'C'
	JR	Z,START
	CP	'E'
	JP	Z,DOS
	IF	.NOT.DOS6
	CP	'T'		;Tape?
	JR	Z,TAPE
	ENDIF
	CP	'D'		;Disk?
	JR	NZ,BEGIN
DISK	PUSH	HL
	LD	HL,FIL1PR
	CALL	PROMPT
	CALL	OPNFIL
	POP	HL
	CALL	RDPROG
INPFIN	LD	(MEMPTR),HL	;Update where we left off
	JR	BEGIN
	IF	.NOT.DOS6
TAPE	CALL	RDTAPE
	JR	INPFIN
	ENDIF
;*****
;	Routine to process output request
;*****
OUTPUT	LD	HL,MEMBUF+3	;Ck for file input
	LD	DE,(MEMPTR)
	RST	24
	JR	NZ,OUTA
	LD	HL,NOINP
	CALL	DSPLY
	JP	NOPRT
OUTA	LD	HL,LOADR+1	;Insert load address
	LD	DE,PGML1	;Into loader message
	CALL	WRBLK
	LD	HL,HIADR+1
	LD	DE,PGML2
	CALL	WRBLK
	LD	HL,PGMLOD
	CALL	DSPLY
	LD	HL,MOVREQ	;Offset file?
	CALL	GETARG
	JP	Z,OUT0		;Don't add loader
;*****
;	Routine to add offset loader
;*****
	EX	DE,HL		;Pt to 1st char
	LD	A,(DE)
	CALL	GETVAL
	JR	C,OUTA
	PUSH	HL
	LD	HL,41FFH	;ck for <4200H
	LD	DE,(LOADR)
	RST	24
	JR	C,NOPROB	;not below
LOCK1	LD	HL,LOMSG	;user want to restrict?
	CALL	PATCH1
	JR	Z,NOPROB	;no, if no entry
	EX	DE,HL
	LD	A,(DE)		;grab 1st byte
	CALL	GETVAL		;grab & convert
	JR	C,LOCK1		;again if bad char
	LD	(LOADR),HL	;stuff lower limit
	EX	DE,HL
NOPROB	POP	HL		;calc offset
	XOR	A
	SBC	HL,DE
	LD	(OFFSET),HL
	RL	H		;Test offset for +,-
	JR	C,NEGMOV
	LD	A,0B0H		;Init for LDIR
	LD	(LDMOV+1),A
	RR	H
	EX	DE,HL		;Offset -> DE
	LD	HL,(LOADR)
	LD	(LDDE+1),HL
	ADD	HL,DE
	LD	(LDHL+1),HL
	JR	ALLMOV
NEGMOV	LD	A,0B8H		;Init for LDDR
	LD	(LDMOV+1),A
	RR	H
	EX	DE,HL		;Offset -> DE
	LD	HL,(HIADR)
	LD	(LDDE+1),HL
	ADD	HL,DE
	LD	(LDHL+1),HL
ALLMOV	LD	HL,(TRAADR)
	LD	(LDJP+1),HL
	LD	HL,(HIADR)	;Ins new xfer addr
	INC	HL
	LD	(LDADR),HL
	PUSH	HL		;Save for xfer addr upd
	LD	DE,(LOADR)	;Calc move length
	XOR	A
	SBC	HL,DE
	LD	(LDBC+1),HL
	LD	HL,DVRMSG	;User want offset driver?
	CALL	YESNO
	POP	HL		;Pop xfer addr upd
	JR	C,OUT0		;Jump if not
	LD	DE,(OFFSET)	;Add offset here
	ADD	HL,DE		;This is a traadr
	LD	(TRAADR),HL	;Pt TRAADR to routine
	LD	HL,DIMSG	;Interrupt req?
	CALL	YESNO
	JR	NC,PUTDI
	XOR	A
	DEFB	1		;Ignore next 2 bytes
PUTDI	LD	A,0F3H		;Ins DI
	LD	(DINOP),A
	LD	HL,KBCREQ	;Keep debounce?
	CALL	YESNO
	LD	HL,(MEMPTR)	;Reset memory pointer
	DEC	HL
	DEC	HL
	DEC	HL
	DEC	HL
	JR	C,LVDBNC
	LD	DE,BNCOFF	;Move stripper
	LD	B,6
BNCL1	LD	A,(DE)
	PUSH	DE
	CALL	CHKMEM
	POP	DE
	INC	DE
	DJNZ	BNCL1
LVDBNC	LD	DE,LOADER	;Move loader
	LD	B,19
BNCL2	LD	A,(DE)
	PUSH	DE
	CALL	CHKMEM
	POP	DE
	INC	DE
	DJNZ	BNCL2
	CALL	PUTTRA
	LD	(MEMPTR),HL	;Reset pointer
	JR	SAMTRA		;User can't update TRAADR
OUT0	LD	HL,TRAADR+1
	LD	DE,NEWT1
	CALL	WRBLK
OUT1	LD	HL,NEWTRA
	CALL	GETARG
	JR	Z,SAMTRA
	EX	DE,HL
	LD	A,(DE)
	CALL	GETVAL
	JR	C,OUT1
	EX	DE,HL		;New TRA -> DE
	LD	HL,(MEMPTR)
	DEC	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
SAMTRA	LD	HL,OUTDT
	CALL	GETARG
	JP	Z,START
	LD	A,(HL)
	AND	5FH		;Strip LC
	CP	'E'
	JP	Z,DOS
	CP	'C'
	JP	Z,START
	IF	.NOT.DOS6
	CP	'T'		;Tape?
	JP	Z,TAPOUT
	ENDIF
	CP	'D'		;Disk?
	JR	NZ,SAMTRA
;*****
;	Routine to write command files
;*****
	LD	HL,OUTSPC
	CALL	PROMPT
	LD	HL,BUFFER$
	LD	(BUFPTR),HL
	LD	B,0
	@@INIT
	JP	NZ,GOTERR
	LD	HL,MEMBUF-1
WRLP	INC	HL
	LD	A,(HL)
	CP	1
	JR	Z,DSKBLK
	CP	2
	JR	Z,DSKTRA
	CP	3
	JR	Z,SPCL1
	CALL	WRDBYT		;Write comment header
	INC	HL
	LD	A,(HL)
	LD	B,A
	CALL	WRDBYT		;Write comment length
WRLP1	INC	HL
	LD	A,(HL)
	CALL	WRDBYT
	DJNZ	WRLP1
	JR	WRLP
SPCL1	LD	A,1		;Turn off the
	LD	(HLDFLG),A	;  block offset
DSKBLK	CALL	WRDBYT		;Write block header
	INC	HL
	LD	A,(HL)
	LD	B,A
	CALL	WRDBYT		;Write block length
	CALL	CHKADR
	LD	A,E
	PUSH	DE
	CALL	WRDBYT
	POP	DE
	LD	A,D
	CALL	WRDBYT
	DEC	B		;Reduce length for addr
	DEC	B
WRLP2	INC	HL
	LD	A,(HL)
	CALL	WRDBYT
	DJNZ	WRLP2
	JR	WRLP
DSKTRA	LD	B,4
	CALL	WRDBYT
	INC	HL
	LD	A,(HL)
	DJNZ	DSKTRA+2
CLSFIL	LD	A,(BUFPTR)	;P/u eof byte
	OR	A		;Write last buffer?
	LD	(DCB+8),A	;Stuff EOF offset
	CALL	NZ,LASTWR	;Write if BUFPTR <> 0
	CALL	RWEND
	LD	HL,FINMSG
	CALL	YESNO
	JP	NC,SAMTRA
	JP	NOPRT
WRDBYT	PUSH	HL
	CALL	DISKWR
	POP	HL
	RET
;*****
;	Routine to check load or xfer addr for offset
;*****
CHKADR	INC	HL
	LD	E,(HL)		;Get load address into DE
	INC	HL
	LD	D,(HL)
	PUSH	HL
	LD	HL,HLDFLG	;Test hold flag
	INC	(HL)		;  for suppression
	DEC	(HL)		;  of offset
	JR	Z,DOOFF
	DEC	(HL)		;Turn off the flag
	JR	NOTMVD
DOOFF	LD	HL,(LOADR)	;Don't offset <bottom
	RST	24
	JR	Z,MOVED
	JR	NC,NOTMVD
MOVED	LD	HL,(OFFSET)
	LD	A,H
	OR	L
	JR	Z,NOTMVD
	ADD	HL,DE		;Add in the offset
	EX	DE,HL
NOTMVD	POP	HL
	RET
	IF	.NOT.DOS6
;*****
;	Routine to write SYSTEM tape file
;*****
TAPOUT	LD	HL,FILMSG
	CALL	DSPLY
	LD	HL,FILNAM
	LD	B,6
	CALL	GETNAME
	JR	Z,TAPOUT
	LD	(NAMLEN),A	;Set length for recycle
TAPAGN	LD	A,6
	SUB	B
	LD	C,A
	PUSH	BC
	CALL	RDYCAS		;Ready cassette prompt
	DI			;Interrupts off
	XOR	A		;Point to 1st cassette
	CALL	CTON		;Turn cassette on
	CALL	WRLDR		;Write the tape leader
	LD	A,55H
	CALL	WRBYT		;Write the start byte
	POP	BC
	LD	HL,FILNAM
TPO1	LD	A,(HL)
	INC	HL
	CALL	PATCH2		;Output name in UC only
	DJNZ	TPO1
	XOR	A
	OR	C		;How many spaces?
	JR	Z,TPO3		;Jump if none
	LD	B,A
TPO2	LD	A,' '		;Spaces out to 6
	CALL	WRBYT
	DJNZ	TPO2
TPO3	LD	HL,MEMBUF-1	;Pt to 1st buffer byte
TPO4	INC	HL
	LD	A,(HL)
	CP	1		;Block begin?
	JR	Z,TPBLK
	CP	2
	JR	Z,TPTRA
	CP	3
	JR	Z,SPCL2
	INC	HL		;Pt to comment length
	LD	C,(HL)
	LD	B,0		;Bypass comments
	ADD	HL,BC
	JR	TPO4
SPCL2	LD	A,1		;Set hold flag to
	LD	(HLDFLG),A	;  ignore block offset
TPBLK	CALL	CSTAR		;Put asterisk
	LD	A,3CH		;Tape mark
	CALL	WRBYT
	INC	HL
	LD	B,(HL)		;Block length
	DEC	B
	DEC	B		;Reduce for tape
	LD	A,B
	CALL	WRBYT
	CALL	CHKADR
	LD	A,E
	CALL	WRBYT		;Lo order load addr
	LD	A,D
	CALL	WRBYT		;Hi order load addr
	ADD	A,E		;Accum checksum
	LD	C,A
TPB1	INC	HL
	LD	A,(HL)		;Get block bytes
	CALL	WRBYT
	ADD	A,C		;Accum checksum
	LD	C,A
	DJNZ	TPB1
	LD	A,C
	CALL	WRBYT		;Write checksum
	JR	TPO4
TPTRA	LD	A,78H		;End mark
	CALL	WRBYT
	INC	HL		;Bypass 2nd X'02'
	INC	HL
	LD	A,(HL)
	CALL	WRBYT		;Tra lo order
	INC	HL
	LD	A,(HL)
	CALL	WRBYT		;Tra hi order
	CALL	CTOFF
	LD	HL,FINMSG	;Adv CAO & request
	CALL	YESNO		; another copy?
	JP	C,NOPRT
	LD	A,(NAMLEN)
	LD	B,A
	JP	TAPAGN
	ENDIF
;*****
;	Routine to process CMD file reads
;*****
RDPROG	XOR	A
	LD	(OVRFLG),A
GETPRG	CALL	RDBYTE
	CALL	CHKMEM
	CP	1		;Begin of block?
	JR	Z,NEWBLK
	CP	2		;End of program?
	JP	Z,ENDPGM
	CP	4
	JP	Z,OVRTRA
	CP	8		;Overlay field pointer?
	JP	Z,TESTOVR
	CP	10
	JP	Z,ENDMAP
GET0	CALL	RDBYTE		;Get comment length
	CALL	CHKMEM
	LD	B,A		;Set length
BLKLP	PUSH	BC
	CALL	RDBYTE
	CALL	CHKMEM
	POP	BC
	DJNZ	BLKLP
	JR	GETPRG
NEWBLK	CALL	RDBYTE		;Get block length
	CALL	CHKMEM
	LD	B,A		;Set counter
	DEC	B
	DEC	B		;Reduce for load addr
	CALL	GETADR		;Get load address
	LD	(BLKADR),DE
	PUSH	HL		;Test for new lo
	LD	HL,(LOADR)
	RST	24
	JR	C,NOLOW
	LD	(LOADR),DE
NOLOW	LD	HL,BLKADR+1
	LD	DE,BLKM1
	CALL	WRBLK
	LD	HL,(BLKADR)
	PUSH	BC
	XOR	A
	OR	B
	JR	Z,BUMPH
	LD	A,L
	ADD	A,B
	LD	L,A
	JR	NC,$+3
BUMPH	INC	H
	DEC	HL
	LD	(BLKEND),HL
	LD	DE,(HIADR)	;Test for new hi
	RST	24
	JR	C,NOTHI
	LD	(HIADR),HL
NOTHI	LD	HL,BLKEND+1
	LD	DE,BLKM2
	CALL	WRBLK
	LD	HL,BLKMSG
	CALL	DSPLY
	LD	HL,PRTFLG
	INC	(HL)
	DEC	(HL)
	LD	HL,BLKMSG
	CALL	NZ,PRINT
	POP	BC
	POP	HL
	JR	BLKLP
ENDMAP	LD	A,(OVRFLG)
	INC	A
	JP	NZ,LODERR
	JR	GET0		;Ignore as comment
TESTOVR	DEC	HL		;Backup memory pointer
	PUSH	HL		;Save mem ptr
	LD	A,(OVRFLG)	;Need overlay prompt?
	OR	A
	JR	NZ,NOPMPT
REPMPT	LD	HL,ISAM$
	CALL	GETARG		;Get overlay nbr
	JR	Z,REPMPT
	EX	DE,HL
	LD	A,(DE)
	CALL	GETVAL
	JR	C,REPMPT
	LD	A,L
	LD	(OVRFLG),A
NOPMPT	CALL	RDBYTE		;Get field length
	LD	B,A
	CALL	RDBYTE		;Get overlay #
	DEC	B		;Adjust length
	DB	0FEH
OVRFLG	NOP
	JR	NZ,BYPASS
	CALL	RDBYTE		;P/u the transfer address
	LD	L,A
	CALL	RDBYTE
	LD	H,A
	LD	(TRAADR),HL
	CALL	RDBYTE		;P/u to NRN pointer
	LD	L,A
	CALL	RDBYTE
	LD	H,A
	CALL	RDBYTE
	LD	C,A		;P/u the offset byte
	PUSH	BC
	LD	B,H
	LD	C,L
	LD	DE,DCB
	@@POSN		;Point to record start
	POP	BC
	LD	HL,NOISAM$
	JP	NZ,LODERR+3
	LD	H,BUFFER$<-8	;P/u hi order buf ptr	*
	LD	L,C		;Pt next read
	DEC	HL		;Adj for next byte
	CALL	RDNXT1		;			*
GOBACK	POP	HL
	JP	GETPRG
BYPASS	CALL	RDBYTE
	DJNZ	BYPASS
	JP	GOBACK
OVRTRA	LD	A,(OVRFLG)	;Test if overlay req
	INC	A
	JP	Z,GET0
	DEC	HL		;Adj for "4" load
	LD	A,2
	CALL	CHKMEM
	LD	A,2
	CALL	CHKMEM
	LD	A,(TRAADR)
	CALL	CHKMEM
	LD	A,(TRAADR+1)
	CALL	CHKMEM
	JR	WRTTRA
ENDPGM	CALL	RDBYTE
	CALL	CHKMEM
	CP	2
	JP	NZ,LODERR
	CALL	GETADR
	LD	(TRAADR),DE
WRTTRA	PUSH	HL
	LD	HL,TRAADR+1
	LD	DE,TRAM1
	CALL	WRBLK
	LD	HL,TRAMSG
	CALL	DSPLY
	LD	HL,PRTFLG
	INC	(HL)
	DEC	(HL)
	LD	HL,TRAMSG
	CALL	NZ,PRINT
NOTRAM	POP	HL
	RET
	IF	.NOT.DOS6
;*****
;	Routine to perform SYSTEM tape read
;*****
RDTAPE	DI			;Interrupts off
	PUSH	HL
	CALL	RDYCAS
	XOR	A
	CALL	CTON
	CALL	RDLDR
SYS1	CALL	RDBYT		;Look for header
	CP	55H
	JR	NZ,SYS1
	LD	A,5
	POP	HL
	CALL	CHKMEM
	LD	A,6
	CALL	CHKMEM
	LD	B,A
	LD	IX,STAMSG	;Pointer to NAME save
SYS2	CALL	RDBYT
	LD	(IX),A		;Save file name
	INC	IX
	CALL	CHKMEM
	DJNZ	SYS2
SYS3	CALL	CSTAR
	CALL	RDBYT
	CP	78H		;TRAADR?
	JR	Z,SYS5
	CP	3CH		;Block begin?
	JR	NZ,CASERR
	LD	A,1		;SOB
	CALL	CHKMEM
	CALL	RDBYT		;Length
	LD	B,A
	INC	A		;Inc for addr in file
	INC	A
	CALL	CHKMEM		;Load block length
	CALL	RDBYT		;Get load addr low order
	INC	HL
	LD	(HL),A		;Insert w/o ckg mem
	LD	E,A		;Set up to test new low
	CALL	RDBYT		;Get load addr hi order
	INC	HL
	LD	(HL),A		;Insert w/o ckg mem
	LD	D,A
	ADD	A,E		;Begin calc of checksum
	LD	C,A		;Start checksum
	PUSH	HL		;Check if this addr
	LD	HL,(LOADR)	;  is a new low
	RST	24
	JR	C,TPLOW		;Go if not
	LD	(LOADR),DE	;  else update parm
	POP	HL
	JR	SYS4
TPLOW	EX	DE,HL		;If not new low, test
	PUSH	BC		;  if new high
	XOR	A		;Calc end of block
	OR	B
	JR	Z,BUMPHT
	LD	A,L
	ADD	A,B
	LD	L,A
	JR	NC,$+3
BUMPHT	INC	H
	DEC	HL
	LD	DE,(HIADR)	;Is it a new hi?
	RST	24
	JR	C,TPHI		;Go if not
	LD	(HIADR),HL	;  else update parm
TPHI	POP	BC
	POP	HL
SYS4	CALL	RDBYT		;Loop to read block
	CALL	CHKMEM
	ADD	A,C
	LD	C,A
	DJNZ	SYS4
	CALL	RDBYT
	CP	C		;Check checksum
	JR	Z,SYS3
CASERR	CALL	CTOFF
	LD	HL,CHKSUM
	JP	DSPMSG		;			*
	NOP			;Slack
SYS5	PUSH	HL		;Save memory pointer
	CALL	TAPADR		;Grab the transfer adr
	LD	(TRAADR),HL	;Stuff it
	CALL	CTOFF		;Turn off the cassette
	POP	HL		;Rcvr the memory pointer
	CALL	PUTTRA		;Put TRAADR into memory
	PUSH	HL		;Save memory pointer
	LD	HL,STAMSG	;Display tape file name
	CALL	DSPLY
	POP	HL		;Rcvr memory pointer
	JP	WRTTRA
	ENDIF
;*****
;	Routine to stuff transfer address in memory
;*****
PUTTRA	LD	B,2
	LD	A,B
STUF2	CALL	CHKMEM
	DJNZ	STUF2
	LD	A,(TRAADR)
	CALL	CHKMEM
	LD	A,(TRAADR+1)
	CALL	CHKMEM
	RET
;*****
;	Routine to get an address
;*****
GETADR	CALL	RDBYTE
	CALL	CHKMEM
	LD	E,A
	PUSH	DE
	CALL	RDBYTE
	CALL	CHKMEM
	POP	DE
	LD	D,A
	RET
;*****
;	Routine to put address in message
;*****
WRBLK	CALL	WR2
WR2	LD	A,(HL)
	SRL	A
	SRL	A
	SRL	A
	SRL	A
	CALL	PUTDIG
	LD	A,(HL)		;Get byte again
	AND	0FH
	DEC	HL
PUTDIG	ADD	A,90H
	DAA
	ADC	A,40H
	DAA
	LD	(DE),A
	INC	DE
	RET
;*****
;	Routine to check for out of memory
;*****
CHKMEM	INC	HL		;Bump to next location
	LD	(HL),A		;Insert into memory
	EX	DE,HL		;Check if this is last
HIGHEST	LD	HL,(HIGH3)	;  address usable
	OR	A		;Reset carry flag
	SBC	HL,DE		;At the end yet?
	EX	DE,HL
	RET	NZ		;Back if OK
	LD	HL,MEMMSG	;  else out of memory!
DSPMSG	CALL	DSPLY
	JP	BEGIN
	IF	.NOT.DOS6
;*****
;	Cassette prompting routine
;*****
RDYCAS	LD	HL,CASMSG	;Display prompting msg
	CALL	DSPLY
PRMPT	CALL	SETCAS
	LD	A,CR
	JP	@DSP
	ENDIF
;*****
;	Routine to read in a file spec (or response)
;*****
PROMPT	CALL	DSPLY
	LD	HL,IOBUF
GETSPC
	IF	DOS6
	ELSE
	LD	B,32
	ENDIF
	LD	BC,32.SHL.8
	@@KEYIN
	JP	C,DOS
	XOR	A
	OR	B
	RET	Z
	PUSH	AF		;Save the flags
	LD	DE,DCB
	@@FSPEC
	LD	HL,DFTEXT
FEXT	@@FEXT
	POP	AF
	RET
GETARG	CALL	DSPLY
	IF	DOS6
	LD	BC,6.SHL.8
	ELSE
	LD	B,6
	ENDIF
	LD	HL,IOBUF
GETNAME	@@KEYIN
	JP	C,DOS
	XOR	A
	OR	B
	RET
;*****
;	Routine to open a file
;*****
OPNFIL	LD	HL,BUFFER$+255
	LD	(BUFPTR),HL
	INC	L		;Set buffer to start
	LD	B,0		;Set LRL = 256
	@@OPEN
	RET	Z
	IF	DOS6
	CP	42		;LRL open fault?
	RET	Z
	CP	41		;File already open?
	RET	Z
	ENDIF
GOTERR	OR	0C0H
	IF	DOS6
	LD	C,A
	ENDIF
	@@ERROR
	JP	BEGIN
;*****
;	Routine to perform disk reads
;*****
RDBYTE	PUSH	HL
	CALL	RDNXT		;Get next byte
	POP	HL
	RET	NC		;Back if no eof
LODERR	LD	HL,LODMSG
	CALL	DSPLY
	JP	BEGIN
RDNXT	LD	HL,(BUFPTR)	;P/u current pointer
	INC	L		;Bump low order pos
RDNXT1	LD	(BUFPTR),HL	;			*
	JR	Z,DR0		;Go if buffer empty
RESET	XOR	A		;Show OK read
	LD	A,(HL)		;P/u next byte
	RET
DR0	LD	DE,DCB
	@@READ
	JR	Z,RESET		;Go if error on I/O
DR1	CP	1DH		;NRF?
	JR	Z,RWEND
	CP	1CH		;EOF?
	JR	NZ,GOTERR
RWEND	@@CLOSE
	SCF			;Indicate closed
TESTRC	RET	Z
	JR	GOTERR
;*****
;	Disk write routine
;*****
DISKWR	LD	HL,(BUFPTR)	;Get pointer for next pos
	LD	(HL),A		;Insert byte first
	INC	L		;Bump low-order pointer
	LD	(BUFPTR),HL	;  and reset pointer
	RET	NZ		;Back if buffer not full
LASTWR	LD	DE,DCB		;Point to DCB & write
	@@VER			;  out the buffer
	JR	TESTRC
;
	IF	LDOS
BAD	LD	A,32
	JP	GOTERR
QUERY	INC	HL		;User input?
	LD	A,(HL)
	INC	HL
	CP	CR
	JR	NZ,NODFLT	;Bypass default if so
	LD	A,30H		;Default to drive 0
NODFLT	SUB	30H		;Cvrt to binary
	JR	C,BAD		;Error if < 0
	CP	8
	JR	NC,BAD		;Error if > 3
	LD	C,A
	LD	B,0
	LD	A,(HL)
	CP	'/'
	JR	NZ,NOEXT
	LD	(HL),0		;Clear for next query
	INC	HL		;Bump to EXT
	LD	B,2
NOEXT	@@CKDRV			;Drive available?
	JR	NZ,BAD
DODIR	@@DODIR
	JP	BEGIN
	ENDIF
;
;*****
;	Routine to convert input (hex) to 2-byte value
;*****
GETVAL	LD	HL,0
GETV1	CP	'a'		;Cvrt to U/C if needed
	JR	C,$+4
	RES	5,A
	CALL	CVB
	RET	C
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	OR	L		;Insert the 0-15 into
	LD	L,A		;  low order nybble
	INC	DE		;Get next char
	LD	A,(DE)
	CP	0DH		;Ck for last char
	JR	NZ,GETV1
	XOR	A		;Valid input
	RET
CVB	SUB	30H
	RET	C
	ADD	A,0E9H
	RET	C
	ADD	A,6
	JR	C,ATOF
	ADD	A,7
	RET	C
ATOF	ADD	A,10
	OR	A
	RET
;*****
;	Response yes/no routine
;*****
YESNO	CALL	DSPLY		;Display prompt
	PUSH	HL		;Save messge ptr
	LD	HL,ANSWER
	LD	B,1
	@@KEYIN
	XOR	A
	OR	B
	LD	A,(HL)		;P/u the response
	POP	HL		;Rcvr message ptr
	JR	Z,YESNO
	AND	5FH		;STRIP LC
	CP	'C'
	JP	Z,START
	CP	'E'
	JP	Z,DOS
	CP	'N'		;N?
	JR	Z,NO
	CP	'Y'
	JR	NZ,YESNO
YES	RET
NO	CCF
	RET
;*****
;	Output routines for the non-DOS user
;*****
;
	IF	DOS6
DSPLY	@@DSPLY
	RET
PRINT	@@PRINT
	RET
DOS	LD	A,0C9H
	LD	(24),A
	LD	HL,0
	@@EXIT
RST24	LD	A,H
	CP	D
	RET	NZ
	LD	A,L
	CP	E
	RET
	ELSE
	IF	LDOS
DSPLY	EQU	@DSPLY
PRINT	EQU	@PRINT
DOS	EQU	@EXIT
	ENDIF
;
	IF	.NOT.LDOS
DSPLY	LD	DE,DDCB$
D1	PUSH	HL
D2	LD	A,(HL)
	CP	3
	JR	Z,D3
	PUSH	AF
	CALL	@PUT
	POP	AF
	INC	HL
	CP	0DH
	JR	NZ,D2
D3	POP	HL
	RET
PRINT	LD	DE,PDCB$
	JR	D1
DOS	LD	A,(LVLFLG)
	CP	50H
BASIC	JP	Z,BASIC3
	JP	@EXIT
	ENDIF
	ENDIF
;
;*****
;	Reserved space for patch code
;*****
PATCH1	PUSH	DE
	CALL	GETARG
	POP	DE
	RET
PATCH2	CP	'a'
	JR	C,PATCH2A
	CP	'z'+1
	JR	NC,PATCH2A
	RES	5,A
PATCH2A	JP	WRBYT
	DS	13
;*****
;	Loader routines
;*****
BNCOFF	DEFB	3
	DEFB	4
	DEFW	KDCB$+1
KIHOOK	DEFW	KIADR3
LOADER	DEFB	1		;Start of block
	DEFB	17		;Block length
LDADR	DEFW	0		;Load address
DINOP	NOP			;Possible DI
LDHL	LD	HL,0		;Relocator routine
LDDE	LD	DE,0
LDBC	LD	BC,0
LDMOV	LDIR			;LDIR or LDDR
LDJP	JP	0
	PAGE
;*****
;	DATA AREA
;*****
HELLO$	DM	28,31,'MISOSYS Command File Utility '
;
	IF	EXPAND
	DB	'- Version 1.5',LF
	ENDIF
;
	IF	EDAS
	DB	'- EDAS Version 1.5',LF
	ENDIF
;
	IF	LDOS
	DB	'- LDOS Version 5.1',LF
	ENDIF
;
	IF	SIMUTEK
	DB	'- SIMUTEK Version 1.5',LF
	ENDIF
;
	DB	'Copyright (C) 1979 by Roy Soltoff, '
	DB	'All rights reserved',LF,CR
FIL1PR	DM	'Enter input file filespec >',3
BLKMSG	DM	'Block loads from '
BLKM1	DM	'XXXX to '
BLKM2	DM	'XXXX',CR
STAMSG	DB	'FILNAM: ',3
TRAMSG	DM	'Transfer address (entry point) is '
TRAM1	DM	'XXXX',CR
MEMMSG	DM	'Out of memory!',CR
LODMSG	DM	'Requested file is not a Command '
	DB	'or System file!',CR
PRTREQ	DM 'Address load log to printer (Y,N,E)? >',3
NEWTRA	DM 'Enter new transfer address or <ENTER> to use '
NEWT1	DM	'XXXX >',3
OUTSPC	DM	'Enter filespec to write output >',3
FINMSG	DM	'Module write is complete - '
	DB	'write another (Y,N,E,C)? >',3
NOINP	DM	'*** No file input *** '
	DB	'No file to output ***',CR
CHKSUM	DM	'Tape checksum error detected - '
	DB	'reread tape!',CR
CASMSG	DB	'Ready cassette and enter <H,L>',3
INPMPT	DM	'Input disk or tape (D,T,E,C'
;
	IF	EXPAND!LDOS
	DB	',Q'
	ENDIF
;
	DB	') or <ENTER> to end reads? >',3
FILMSG	DM	'Enter tape file name >',3
OUTDT	DM	'Output to disk or tape (D,T,E,C) or '
	DB	'<ENTER> to restart? >',3
PGMLOD	DM	'Program loads from base address '
PGML1	DM	'XXXX to '
PGML2	DM	'XXXX',CR
MOVREQ	DM	'Enter new base address or <ENTER> >',3
DIMSG	DM	'Do you want to disable the interrupts '
	DB	'(Y,N,E,C)? >',3
KBCREQ	DM	'Do you want to disable the keyboard '
	DB	'debounce (Y,N,E,C)? >',3
DVRMSG	DM	'Do you want to add the offset driver '
	DB	'routine (Y,N,E,C)? >',3
LOMSG	DM	'Program loads below 4200H',LF
	DB	'     Enter address to restrict '
	DM	 'offset or <ENTER> >',3
ISAM$	DM	'File has ISAM overlays - enter # >',3
NOISAM$	DM	'Overlay beyond end of file!',CR
DFTEXT	DM	'CMD'
DCB	DS	32
IOBUF	DS	32
FILNAM	DS	6
BUFPTR	DS	2
MEMPTR	DS	2
BLKADR	DS	2
BLKEND	DS	2
TRAADR	DS	2
HIADR	DS	2
LOADR	DS	2
OFFSET	DS	2
ANSWER	DS	2
DIRPTR	DS	2
PRTFLG	DS	1
NAMLEN	DS	1
HLDFLG	DS	1
	ORG	$<-8+1<8
MEMBUF	EQU	$
	END	START
