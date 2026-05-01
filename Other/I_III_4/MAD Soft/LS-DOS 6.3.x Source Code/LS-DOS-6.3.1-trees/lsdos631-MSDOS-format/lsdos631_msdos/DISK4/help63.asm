;HELP62/ASM - Help display system - 02/16/84
CLS	EQU	-1
	IF	CLS
	TITLE	<'Help 6.2 Source'>
	ELSE
	TITLE	<'Help 6.1 Source'>
	ENDIF
*GET	COPYCOM:3
;---------------------------------------------
;IOFLAG key
;7=print on/off
;6=video restore
;5=reverse
;4=search
;3=global
;2=filespec
;1=keyword
;0=video in RAM
;(IY+1) :
;4=reverse video in progress
;3=wrap occurred on last screen zone
;2=8D in last line
;1=space expansion in progress
;0=part 1 of space expnsion passed
;(IY+2) :
;transient directory count
;CLS = -1 for @CLS V 6.2: CLS = 0 for V 6.1
;************************
*GET	SVCMAC/ASM:3
;
;equates for @@vdct
GETCHA	EQU	1	;get (HL) to A
PUTCHA	EQU	2	;put C (HL)
PUTCUR	EQU	3	;set cursor to HL
GETCUR	EQU	4	;get cursor to HL
PUTVID	EQU	5	;move HL block to video
GETVID	EQU	6	;move video to HL vlock
SCROLL	EQU	7	;scroll protect
CURSCH	EQU	8	;cusor char
OPREG@	EQU	84H
@@VDCT	MACRO	#BREG=0,#CREG=0,#HREG,#LREG,#HLREG
	IFGT	#BREG,0
	LD	B,#BREG
	ENDIF
	IFGT	#CREG,0
	LD	C,#CREG
	ENDIF
	IFEQ	%#HLREG,0
	IFGT	%#HREG,0
	LD	H,#HREG
	ENDIF
	IFGT	%#LREG,0
	LD	L,#LREG
	ENDIF
	ENDIF
	IFGT	%#HLREG,0
	LD	HL,#HLREG
	ENDIF
	LD	A,15
	RST	40
	ENDM
;********************
;
	ORG	2600H
;
BEGIN
	@@CKBRKC		;check for break
	JR	Z,BEGINA	; if not continue
	LD	HL,-1
	RET			;else abort
;
BEGINA	@@FLAGS			;get system flag
	LD	A,(IY+'O'-'A')	;video status
	LD	(@OPREG),A
	LD	A,(IY+'T'-'A')	;get 'type' flag
	LD	C,47H		;mod 2/12/16 cursor
	CP	2		;yes?
	JR	Z,MODCUR	;yes, go!
	CP	12		;yes?
	JR	Z,MODCUR	;yes, go!
	CP	16		;yes?
	JR	Z,MODCUR	;yes, go!
	LD	C,5FH		;else mod 4 cursor
MODCUR	LD	B,8		;@VDCTL command
	LD	A,15		;SVC @VDCTL
	RST	28H		;set cursor, get old
;
	LD	(CCHAR),A	;store user's cursor
	LD	IY,IOFLAG	;point to IO status
	LD	BC,0		;set counter
PARSER	LD	A,(HL)		;check for cr
	CP	0DH
	JR	Z,PARS1
	INC	C
	INC	HL
	JR	PARSER
PARS1	LD	A,C		;test for CR first
	PUSH	HL		;save pointer
	CP	0
	JP	Z,HELPDIR
	POP	HL
	XOR	A		;clear carry
	SBC	HL,BC		;point hl to start
	LD	DE,CBUFFER
	LDIR			;xfer to start
	LD	A,13
	LD	(DE),A
RETRY2	LD	HL,CBUFFER
REMSP	LD	A,(HL)
	CP	20H		;get 1st non space
	JR	NZ,CHECKP
	INC	HL
	JR	REMSP
CHECKP	CP	0DH		;1st char = CR?
	PUSH	HL
	JP	Z,HELPDIR	;then get directory
	CP	'*'		;global search flag
	JP	Z,HELPDIR
	POP	HL		;preservation aborted
	CP	'('		;parms start
	JR	NZ,FILES	;next is FSPEC
PARMS	INC	HL		;point to first parm
	LD	A,(HL)
	CP	0DH		;parms are over
	JP	Z,HELPDIR1
	CP	')'
	JP	Z,HELPDIR1
	RES	5,A		;upper case forced
	CP	'P'		;test valid P parm
	JR	NZ,VPARM
	CALL	VALIDP
	JP	NZ,PARMERR	;not valid
	PUSH	HL		;save that quy
	LD	DE,'RP'		; find the PR DCB
	@@GTDCB
	EX	DE,HL		;Get DCB in DE
	POP	HL
	JP	NZ,ERREXIT	;go on error
	LD	C,0		;And get the PR status
	@@CTL			; through @CTL
	LD	A,8		;Init device not avail
	JP	NZ,ERREXIT	; and exit on error
	SET	7,(IY)		;print flag established
VPARM	CP	'V'		;test valid V parm
	JR	NZ,SPARM
	CALL	VALIDP
	JP	NZ,PARMERR
	RES	6,(IY)
SPARM	CP	'S'		;test valid S parm
	JR	NZ,BPARM
	CALL	VALIDP
	JP	NZ,PARMERR	;not valid
	SET	4,(IY)		;search flag established
BPARM	CP	'R'		;test valid B parm
	JR	NZ,PARMS
	CALL	VALIDP
	JP	NZ,PARMERR
	RES	5,(IY)
	JR	PARMS
FILES	LD	DE,FCB		;point to file buffer
	@@FSPEC			;move name to buffer
	JP	NZ,HELPDIR1	;if no valid fspec
	SET	2,(IY)		;flag valid filespec
	PUSH	HL		;save buffer position
	PUSH	DE		;save fcb pointer
	LD	BC,CBUFFER
	XOR	A
	SBC	HL,BC
	PUSH	HL
	POP	BC
	LD	A,8
	CP	C
	JR	NC,XFRFS
	LD	BC,8
XFRFS	LD	HL,FSPEC
	EX	DE,HL
	LDIR
	LD	A,13
	LD	(DE),A
	POP	DE
	POP	HL
	BIT	3,(IY)		;global in progress?
	JR	Z,FILOVR
	LD	HL,KEYWORD	;key already in buffer
	JR	FILE1
FILOVR	LD	A,(HL)
	CP	13		;end of comman?
	JP	Z,HELPDIR	;dsplay file
	CP	'('		;start of parms?
	JP	Z,PARMS		;parse 'em
	CP	20H		;stop at 1st non space
	JR	NZ,FILE1
	INC	HL
	JR	FILOVR
FILE1	PUSH	HL		;find buffer len
	POP	DE
	LD	BC,0		;go till parms or end
KEYS	LD	A,(DE)
	CP	61H		;convert to upper case
	JR	C,NOUPPER
	CP	7BH
	JR	NC,NOUPPER
	RES	5,A		;remove offending bit
	LD	(DE),A		;and stuff back
NOUPPER	CP	13		;increase count
	JR	Z,KEYEND
	CP	'('
	JR	Z,KEYEND
	INC	C
	INC	DE
	JR	KEYS
KEYEND	LD	DE,KEYWORD
	LDIR			;transfer keyword to buf
	DEC	DE		;check last char
	LD	A,(DE)		;could be a space if parm
	CP	20H
	JR	Z,KEYEND2
	INC	DE
KEYEND2	LD	A,13		;& mark it
	LD	(DE),A
	SET	1,(IY)		;flag keyword
KEYEND1	LD	A,(HL)		;check for command over
	CP	13
	JR	Z,HELPDIR	;go if no
	CP	'('
	JP	Z,PARMS		;parse parms
	INC	HL
	JR	KEYEND1
;--------------------------------
;Store video and determine vector
;---------------------------------
HELPDIR1	BIT 2,(IY)	;test for no/invalid fs
	JR	NZ,HELPDIR
	PUSH	HL
HELPDIR:
	IF	@BLD631
	ELSE
	PUSH	IY
	@@FLAGS
;	SET	0,(IY+18)	;stop lrl & read only
	POP	IY
	ENDIF
	BIT	6,(IY)		;test if video is on
	JR	Z,NOVID		;or skip it
	BIT	0,(IY)		;screen saved once?
	JR	NZ,NOVID
	@@VDCT GETVID,,,,VIDBUFF;save video to buffer
	@@VDCT GETCUR
	LD	(CURSOR),HL	;cursor safe
	SET	0,(IY)		;screen saved flag
NOVID	BIT	2,(IY)		;do we have a filename?
	JP	Z,DIRECT	;go get em a scan
	LD	HL,DEXT		;point to /HLP
	LD	DE,FCB		;FCB
	@@FEXT
	LD	B,1		;LRL of 1
	LD	HL,SYSBUFF	;give the OS a path
	PUSH	IY		;save
	@@FLAGS			;system flags
	SET	0,(IY+'S'-'A')	;set LRL fault ignore
	POP	IY		;restore
	@@OPEN			;open file
	JP	NZ,DIRECT
RETRY	@@PEOF			;point to last record
	CP	1CH		;success?
ERROR1	JP	NZ,FILERR	;something's wrong
	@@BKSP
	@@BKSP
	JR	NZ,ERROR1
	CALL	SETUP		;position alternates
	CALL	POSN		;position file
	BIT	1,(IY)		;is there a key?
	JP	Z,FILEDIR	;if no display file
	BIT	4,(IY)		;has a search been called
	JP	NZ,FILEDIR
;-------------------------------
;test for keyword match
;-------------------------------
	LD	HL,KEYWORD	;convert key to upper
CLOOP	LD	A,(HL)
	CP	13		;last char in key
	JR	Z,TESTCH1
	CP	'a'		;if A < a no need
	JR	C,INCBUF
	CP	'z'+1		;if A > z ditto
	JR	NC,INCBUF
	RES	5,(HL)		;strip lower case bit
INCBUF	INC	HL
	JR	CLOOP
TESTCH1	LD	HL,KEYWORD	;point to keyword
	LD	C,0		;flag key start
TESTCH	CALL	GETCHAR		;first char of indx
	CP	80H		;end of index?
	JR	C,CHRS
	XOR	80H		;wipe it
	LD	C,1		;flag end of key
CHRS	CP	(HL)		;match
	JR	NZ,MORWD		;seek further
	INC	HL		;next char
	LD	A,(HL)		;end of key?
	CP	13
	JR	Z,MATCH		;we found it!
	INC	C		;test if key is over
	DEC	C		;if C nz then last char
	JR	NZ,TWOMOR
	JR	TESTCH
MORWD	JP	NC,FILEDIR	;past possible match
	INC	C		;test if key is over
	DEC	C		;if C nz then last char
	JR	NZ,TWOMOR
SKIPWD	CALL	GETCHAR		;find end of parm
	CP	1CH		;eof?
	JP	Z,FILEDIR
	CP	80H
	JR	C,SKIPWD
TWOMOR	CALL	GETCHAR
	CALL	GETCHAR
	JR	TESTCH1
;---------------------------------
;Display data on screen & printer
;----------------------------------
MATCH	INC	C		;test gor key end
	DEC	C
	JR	Z,SKIPWD	;faked out! try again
	CALL	POSN		;position file
	IF	CLS
	@@CLS
	ELSE
	@@DSPLY CLEAR
	ENDIF
	@@DSPLY KEYWORD		;& write it
	BIT	7,(IY)		;print option?
	JR	Z,DSPHEL
	@@PRINT KEYWORD
DSPHEL	CALL	GETCHAR		;get character
	LD	C,A
	@@VDCT GETCUR		;obtain cursor position
	CALL	RANGE		;check for room
	LD	A,C
	CP	0CH		;end of display?
	JP	Z,WAIT
	CP	07FH		;is it to reverse?
	JR	NZ,HIREV
	BIT	5,(IY)		;blink allowed?
	CALL	NZ,REVERSE	;reverse video on or off
	RES	0,(IY+1)
	JR	DSPHEL		;DO NOT display
HIREV	CP	0FFH		;reverse with high bit?
	JR	NZ,PRT2
	BIT	5,(IY)
	CALL	NZ,REVERSE
	SET	0,(IY+1)
	JR	SSPACE
PRT2	CP	80H		;chk space compression
	JR	C,NOSTRIP
	XOR	80H		;kaboom
	BIT	0,(IY+1)	;is this second one?
	JR	NZ,EXPAND	;inflate it
	SET	0,(IY+1)	;mark 1st one
	LD	C,A
	@@DSP			;print it
	CALL	CHKPRT
SSPACE	LD	C,20H		;put a space
	INC	HL
	CALL	RANGE
	@@DSP
	CALL	CHKPRT
	JR	DSPHEL
CHKPRT	BIT	7,(IY)
	RET	Z
	PUSH	BC		;save char
	LD	A,(PWIDE)	;test for video width
	CP	81		;if less skip it
	JR	NZ,CHKP1
	LD	C,13		;force a CR
	@@PRT
	LD	A,1		;reset	pwide
	LD	(PWIDE),A
CHKP1	POP	BC
	PUSH	BC
	@@PRT
	POP	BC
	LD	A,C
	CP	13		;did we pass CR?
	LD	A,1		;if yes reset
	JR	Z,CHKP2
	LD	A,(PWIDE)	;increase count
	INC	A
CHKP2	LD	(PWIDE),A
	RET
NOSTRIP	BIT	1,(IY+1)
	CALL	NZ,ADDSP
	@@DSP
	RES	0,(IY+1)	;scounce flag
	CALL	CHKPRT
	JP	DSPHEL
EXPAND	LD	B,A		;number of spaces
	BIT	1,(IY+1)	;space abort at EOL?
	JR	Z,EXPAND1
	RES	1,(IY+1)	;reset flag
	INC	B
EXPAND1	LD	C,20H
	INC	HL		;cursor updated
	CALL	RANGE
	@@DSP
	CALL	CHKPRT
	DJNZ	EXPAND1
	RES	0,(IY+1)
	JP	DSPHEL
RANGE	LD	A,L
	SUB	79
	JR	C,RANGE3
	LD	L,A
	INC	H
RANGE3	LD	DE,164FH		;last line?
	OR	A		;clear flags
	PUSH	HL		;save posit
	SBC	HL,DE
	POP	HL
	RET	C		;it's OK
	LD	A,C
	CP	0DH		;CR?
	JR	Z,PAUSE1	;do not print CR in last
	CP	0AH		;LF?
	JR	Z,PAUSE1
	CP	8DH		;compressed CR?
	JR	NZ,RANGE2
	BIT	0,(IY+1)	;is it real 8D?
	JR	NZ,RANGE2
	SET	0,(IY+1)	;1st high
	SET	1,(IY+1)	;flag expand space
	JR	PAUSE
RANGE2	LD	A,L		;test EOL
	CP	79
	LD	A,C
	JR	Z,WAIT		;stop scroll
	RET
PAUSE1	LD	A,C
	RES	0,(IY+1)	;CR interrupts compress
PAUSE	XOR	A		;zero char
WAIT	LD	(STRCHAR),A	;char to mem
	BIT	7,(IY)		;are we printing
	JR	NZ,BOVER	;if yes no stopping
	@@VDCT GETCUR
	XOR	A		;test for screen not full
	LD	DE,164FH
	SBC	HL,DE
	JR	C,BOVER
	@@KEY
BOVER	CP	80H		;Break?
	JP	Z,EXIT
	LD	C,13		;deliver a kiss to lp
	CALL	CHKPRT
	RES	2,(IY+1)	;flag file directory
	LD	A,(STRCHAR)	;get calling char
	LD	C,A
	CP	0		;see if nothing
	JR	Z,ABORTCH	;blow charcter
	CP	0CH		;last?
	JP	Z,PEXIT
CLS1	LD	C,1CH
	@@DSP
	LD	C,1FH
	@@DSP
	LD	A,(STRCHAR)
	LD	C,A
	RET
ABORTCH:
	IF	@BLD631
	LD	HL,DSPHEL	;<631>
	EX	(SP),HL		;<631>
	ELSE
	POP	HL		;steal return address
	LD	HL,DSPHEL	;& replace it
	PUSH	HL
	ENDIF
	JR	CLS1
;---------------------------------
;directory of a given file
;---------------------------------
FILEDIR	BIT	3,(IY)		;global in progress?
	JP	NZ,GLOBAL5
	@@DSPLY SIGNON		;greet the masses
	@@DSPLY FILMESS
	BIT	7,(IY)		;print toggled?
	JR	Z,NOPRNT
	@@PRINT
NOPRNT	LD	HL,FSPEC	;point to filespec
PRTNAME	LD	A,(HL)		;look for end char
	CP	0DH
	JR	Z,EON		;end of name
	LD	C,A
	@@DSP
	CALL	CHKPRT
	INC	HL
	JR	PRTNAME
EON	LD	C,13		;stuff CR?
	@@DSP
	CALL	CHKPRT
;------------------------------
;posn file to directory
;------------------------------
	EXX			;the alts
	@@PEOF
	CP	1CH
	JP	NZ,FILERR
	@@BKSP
	@@BKSP
	JP	NZ,FILERR
	EXX			;return condition
	LD	DE,CBUFFER
	CALL	POSN		;point to directory org
	LD	C,0		;establish count
ROLL1	CALL	GETCHAR
	CP	1CH		;EOF?
	JP	Z,PEXIT
NEXTD	CP	80H		;last char?
	JR	C,ROLL2		;else no end
	XOR	80H		;reset 7
	JR	PRTDIR		;end it
ROLL2	INC	C		;1 more char
	LD	(DE),A		;install it
	INC	DE
	JR	ROLL1
PRTDIR	PUSH	AF		;save character
	CALL	GETCHAR		;EOF test to stop
	JR	Z,NOEND		;successful get
	CP	1CH		;printing garbage
	JR	NZ,NOEND	;for last key
	POP	AF		;restore stack & blow
	JP	PEXIT
NOEND	EXX			;restore file
	@@BKSP
	EXX
	INC	C		;place last char
	@@VDCT GETCUR
	POP	AF
	LD	(DE),A
	BIT	4,(IY)		;is this a search
	CALL	NZ,SEARCH
	JR	C,NXTDIR	;skip it if no cmat
	LD	A,19		;buffer < 20
	SUB	C
	LD	(IY+2),C
	JR	C,CHKLIN
	INC	A		;fill space out
	LD	B,A		;& store result
	LD	A,20H		;& puff up buffer
ROLLSP	INC	DE
	LD	(DE),A
	DJNZ	ROLLSP
	LD	C,20		;update cursor
	ADD	HL,BC
	LD	A,H		;check for 22-79
	CP	22
	JR	NZ,CDSP		;all is ok
	LD	A,L
	CP	79
	JR	C,CDSP		;still ok
	SET	2,(IY+1)	;inform exit routine
	LD	B,(IY+2)
	LD	HL,CBUFFER	;reset poiinter
DSP3	LD	C,(HL)
	@@DSP
	CALL	CHKPRT
	INC	HL
	DJNZ	DSP3
	LD	C,0FFH		;set a flag
	JP	HALTVID
CDSP	LD	B,20		;buffer len
	LD	HL,CBUFFER
ROLL3	LD	C,(HL)		;normal path
	@@DSP
	CALL	CHKPRT
	INC	HL
	DJNZ	ROLL3
NXTDIR	LD	B,3
SLIDE	CALL	GETCHAR
	DJNZ	SLIDE
	CP	1CH
	JP	Z,PEXIT
	CP	80H
	JP	NC,PEXIT
	LD	DE,CBUFFER
	LD	C,0
	JP	NEXTD
CHKLIN	LD	A,L		;lsb cursor
	ADD	A,(IY+2)	;current len + cursor
	CP	80		;chk for line wrap
	JR	NC,WRAP
	LD	B,A		;save tab
	XOR	A
ADDTAB	ADD	A,20		;inc till A > B
	CP	B
	JR	C,ADDTAB
	JR	Z,ADDTAB
	SUB	B		;compute spaces needed
	LD	B,A
	ADD	A,(IY+2)
	LD	(IY+2),A
	LD	A,20H
PAD2	INC	DE
	LD	(DE),A
	DJNZ	PAD2
	@@VDCT	GETCUR
	ADD	HL,BC		;POSITION
	LD	A,H		;check for 22/79
	CP	22
	JR	NZ,CDSP1
	LD	A,L
	CP	79
	JR	C,CDSP1		;still ok
	SET	2,(IY+1)	;inform exit routine
	JR	HALTVID
CDSP1	LD	HL,CBUFFER
	LD	B,(IY+2)
DSP2	LD	C,(HL)
	@@DSP
	CALL	CHKPRT
	INC	HL
	DJNZ	DSP2
	JR	NXTDIR
WRAP	@@VDCT GETCUR
	LD	B,0
	LD	C,(IY+2)
	ADD	HL,BC
	LD	A,H		;check for 22/79
	CP	22
	JR	NZ,CDSP2
	LD	A,L
	CP	79
	JR	C,CDSP2		;still ok
	SET	2,(IY+1)	;inform exit routine
	SET	3,(IY+1)	;flag wrap in last video
	PUSH	DE
	PUSH	BC
	JR	HALTVID
CDSP2	LD	C,0DH		;end the line
	PUSH	DE
	@@DSP
	CALL	CHKPRT
	POP	DE
	@@VDCT GETCUR
	JR	CHKLIN
HALTVID	LD	A,C
	CP	0FFH
	JR	NZ,PEXIT
	LD	HL,ABNORM
	LD	(NORM+1),HL
	BIT	7,(IY)		;are we printing?
	JP	NZ,CLEARGO
PEXIT	LD	C,13
	CALL	CHKPRT		;liberate dir
	BIT	3,(IY)		;global in progress?
	JP	NZ,GLOBAL4
	@@DSPLY SELMESS		;ask if it's wanted
	RES	4,(IY)
	LD	BC,2000H	;allow 32 chars
	LD	HL,KEYWORD
PEXIT2	@@KEYIN			;leap out brk or ent
	JR	C,EXIT		;break pressed
	INC	B		;test zero chars
	DEC	B
	JP	Z,TESTHALT	;re-direct or cont?
	LD	A,L		;point to last char
	ADD	A,B
	JR	NC,ADDOVER
	INC	H
ADDOVER	LD	L,A
	LD	A,13
	LD	(HL),A
	BIT	3,(IY+1)	;stacked?
	JR	Z,NSTK
	POP	DE
	POP	DE
NSTK	LD	DE,FCB
	RES	3,(IY+1)	;reset stack flag
	BIT	2,(IY)		;came from direct?
	JP	Z,RETRY2
	SET	1,(IY)		;flag key
	JP	RETRY
ERREXIT
	LD	L,A		;save error number
	OR	0C0H		; Set for short ERROR
	LD	C,A		;Put error in C
	@@ERROR			;show it
	LD	H,0
	@@EXIT
;
EXIT
	IF	CLS
	@@CLS
	ELSE
	@@DSPLY CLEAR
	ENDIF
EXNCLS	LD	A,(@OPREG)	;restore video???
	BIT	3,A		;test for REV
	JR	NZ,REVON
	LD	C,17		;turn off RV
	JR	@EXIT3
REVON	LD	C,16
@EXIT3	@@DSP			;turn on RV
	LD	A,(CCHAR)	;restore user's cursor
	LD	C,A
	@@VDCT CURSCH
	PUSH	IY
	@@FLAGS
	POP	HL
	BIT	6,(HL)		;video active
	JP	Z,DONE
	@@VDCT PUTVID,,,,VIDBUFF;restore video
	LD	HL,(CURSOR)	;curs buffer
	BIT	1,(IY+2)	;CMDR function on
	JR	NZ,NOHLDEC	;skip hl DEC
	DEC	H
	DEC	H
	DEC	H
	DEC	H
NOHLDEC	@@VDCT PUTCUR		;replace cursor
DONE	LD	C,13		;clear printer if necc
	CALL	CHKPRT
	@@CKBRKC
	LD	HL,0
	@@EXIT
TESTHALT	BIT 2,(IY+1)	;middle of directory?
	JP	Z,FILEDIR
CLEARGO
	IF	CLS
	@@CLS
	ELSE
	LD	C,1CH		;@cls
	@@DSP
	LD	C,1FH
	@@DSP
	ENDIF
	LD	C,13
	CALL	CHKPRT
	LD	B,(IY+2)
	LD	HL,CBUFFER
	RES	2,(IY+1)	;reset flag
	BIT	3,(IY+1)	;test for wrap
	JR	NZ,WRAP2	;sigh
NORM	JP	DSP2
ABNORM	LD	HL,DSP2
	LD	(NORM+1),HL		;restore code
	LD	HL,0
	JP	NXTDIR
WRAP2	RES	3,(IY+1)	;waste 4 more bytes
	POP	BC		;recover count in C
	POP	DE		;recover buffer pointer
	JP	CHKLIN
;-------------------------------------
;print all help files in system or search globally
;-------------------------------------
DIRECT	LD	HL,DIRBUFF	;get relavant files
	CALL	SETDIR
	LD	B,8		;read drives 0-7
DRLOOP	LD	A,8		;current loop
	SUB	B		;calc drive #
	LD	C,A		;drive into C
	PUSH	BC		;save iteration
	@@CKDRV
 	JR	NZ,NOTHIM	;don't do him
	LD	B,3		;dodir function
	@@DODIR
	CALL	PNTHL		;locate end of buffer
	CALL	SETDIR
NOTHIM	POP	BC		;recover iteration
	DJNZ	DRLOOP		;and do next drive
	LD	(HL),255
	POP	HL		;recover command buffer
	LD	A,(HL)		;vector if necessary
	CP	'*'		;global call?
	JR	Z,GLOBAL
	@@DSPLY SIGNON		;greet the masses
	@@DSPLY DIRMESS
	LD	HL,DIRBUFF	;point to files
DIRECT1	LD	A,(HL)		;end of buffer?
	CP	0FFH
	JR	Z,ENDDIR	;done
	LD	BC,5
	ADD	HL,BC		;point HL to FSPEC
	LD	B,8		;print it in loop
DRLOOP2	LD	C,(HL)
	@@DSP
	INC	HL		;next char
	DJNZ	DRLOOP2
	PUSH	HL
	@@VDCT GETCUR
	LD	BC,8		;tab over 8
	ADD	HL,BC
	LD	A,L		;test for poo
	CP	80
	JR	C,TABOK		;no wrap this time
	LD	L,0
	INC	H
TABOK	@@VDCT PUTCUR
	POP	HL		;restore pointer
	LD	BC,5
	ADD	HL,BC		;point to end of entry
	JR	DIRECT1
ENDDIR	LD	HL,CATMESS	;ask if wanted
	@@DSPLY
	LD	HL,CBUFFER	;point to parm getter
	LD	BC,2000H	;Allow 32 CHARS
	@@KEYIN
	JP	C,EXIT
	INC	B
	DEC	B
	JP	Z,EXIT
	RES	2,(IY)		;turn off file flag
	JP	RETRY2
GLOBAL	SET	3,(IY)		;establish global flag
	LD	DE,KEYWORD
GLOBAL1	INC	HL		;point past *
	LD	A,(HL)		;xfer to key buffer
	CP	13		;end of key
	JR	Z,GLOBAL2
	LD	(DE),A
	INC	DE
	JR	GLOBAL1
GLOBAL2	LD	(DE),A		;plant CR
	LD	HL,DIRBUFF	;point to buffer
GLOBAL3	PUSH	HL
	LD	HL,GLOBMES
	@@DSPLY		;global search signon
	POP	HL
	LD	A,(HL)		;seek eob marker
	CP	0FFH
	JR	Z,ENDGLOB	;exit
	LD	BC,5
	ADD	HL,BC		;point to fspec
	PUSH	HL		;save pointer
	PUSH	HL
	LD	HL,24		;place to file
	@@VDCT PUTCUR
	POP	HL
	LD	B,8
GLLOOP	LD	C,(HL)		;prt fspec
	@@DSP
	INC	HL
	DJNZ	GLLOOP
	POP	HL
	LD	BC,13
	ADD	HL,BC
	PUSH	HL
	XOR	A		;reset hl
	SBC	HL,BC
	LD	C,13
	@@DSP
	LD	BC,8		;set xfer of fspec to
	LD	DE,CBUFFER
	LDIR
	LD	HL,CBUFFER
	JP	FILES
GLOBAL4	LD	HL,GPROMPT
	@@DSPLY
	@@KEY
	CP	80H
	JP	Z,EXIT		;leve if break
	CP	13
	JR	NZ,GLOBAL4
GLOBAL5	POP	HL
	JR	GLOBAL3
ENDGLOB	LD	HL,ENDG
	@@DSPLY
	RES	3,(IY)
	LD	HL,GLEXIT$
	@@DSPLY
	RES	2,(IY)
	RES	1,(IY)
	@@KEY
	JP	EXIT
;-----------------------------------------
;major subrroutines
;--------------------------------------------
ADDSP	PUSH	BC
	INC	HL
	LD	C,20H
	@@DSP
	CALL	CHKPRT
	RES	1,(IY+1)
	POP	BC
	RET
REVERSE	PUSH	BC
	BIT	4,(IY+1)	;in progress?
	JR	NZ,RVOFF	;turn off reverse
	LD	C,16		;turn on reverse
	SET	4,(IY+1)	;set flag
RVGO	@@DSP
	POP	BC
	RET
RVOFF	LD	C,17		;reset reverse
	RES	4,(IY+1)	;reset flag
	JR	RVGO
SETDIR	LD	DE,DEXT		;point to default ext
	LD	B,3		;set up xfer to HL buffer
SDLOOP	LD	A,(DE)
	LD	(HL),A
	INC	HL
	INC	DE
	DJNZ SDLOOP
	DEC	HL
	DEC	HL
	DEC	HL
	RET
PNTHL	LD	A,0FFH		;buffer end marker
PNTHL1	CP	(HL)
	RET	Z
	INC	HL
	JR	PNTHL1
VALIDP	INC	HL		;point to char after matc
	LD	A,(HL)		;test for allowable chars
	CP	13		;CR ok
	JR	Z,PARMOK
	CP	')'
	JR	Z,PARMOK
	CP	','
	JR	Z,PARMOK
	LD	A,1
	JR	LEAVE
PARMOK	DEC	HL
	XOR	A
LEAVE	INC	A
	DEC	A
	RET
SETUP	EXX			;filework in alts
	LD	DE,FCB
	LD	HL,UREC
	EXX
	RET
POSN	CALL	GETCHAR		;getchar
	LD	C,A		;lsb of desired
	CALL	GETCHAR
	LD	B,A		;msb
	PUSH	BC		;send to alts
	EXX
	POP	BC
	@@POSN
	EXX
	RET	Z		;operation successful
	JP	FILERR
GETCHAR	EXX			;read, check, store in A
	@@READ
	JR	Z,GETOK
	CP	1CH		;if eof return
	JR	NZ,GETOK
	OR	A		;reset zero flag
	JR	BACK
GETOK	LD	A,(HL)
BACK	EXX
	RET
SEARCH	PUSH	HL
	PUSH	DE
	LD	DE,CBUFFER
	LD	HL,KEYWORD	;see if key meets spec
SEEK	LD	A,(HL)		;char form pattern
	CP	13		;if we get this far match
	JR	Z,NCARRY	;ok to print
	LD	B,A		;check against proposed
	LD	A,(DE)
	CP	B
	JR	NZ,CARRY	;blowit
	INC	HL
	INC	DE
	JR	SEEK
NCARRY	POP	DE
	POP	HL
	RET	NC
	CCF
	RET
CARRY	POP	DE
	POP	HL
	RET	C
	CCF
	RET
PARMERR	LD	HL,PARMESS
ERROR2	@@LOGOT
	LD	(IY),0
	JP	EXNCLS
FILERR	LD	HL,FILERMES
	JR	ERROR2
;----------------------------------
;message prompts etc
;----------------------------------
SIGNON	DB	1CH,1FH,'HELP System'
*GET	CLIENT:3
DIRMESS	DB	'   ',16,' HELP [category] [*] [keyword] [(parameter)] '
	DB	17,10,10
	DB	'Possible syntax combinations:',10,10
	DB	16,' HELP category ',17,' Displays list of '
	DB	'keywords available in category.',10
	DB	16,' HELP category keyword ',17,' Displays information '
	DB	'in category about keyword.',10
	DB	16,' HELP *keyword ',17,' Displays information '
	DB	'in each available category about keyword.',10,10
	DB	'Parameters are:',10
	DB	'   P - Sends output to printer',10
	DB	'   V - Cancels video restoration',10
	DB	'   R - Cancels reverse video',10
	DB	'   S - Lets you enter a partial keyword name. '
	DB	'HELP displays a list of all',10
	DB	'       keywords that begin with the partial name',10,10
	DB	'HELP categories presently on line are:',13
FILMESS	DB	'Directory for HELP file : ',3
SELMESS	DB	0AH,'Enter keyword or press <BREAK> to exit: ',3
CATMESS	DB	10,10,'Enter category or press <ENTER> to exit: ',3
GLEXIT$	DB	10,'Press <ENTER> to exit: ',3
PARMESS	DB	0AH,'Parameter Error - System Aborted',0DH
FILERMES	DB	0AH,'Source File Read Error',0DH
GLOBMES	DB	1CH,1FH,'Global Search in File: ',3
GPROMPT	DB	0AH,'Press <BREAK> to exit or <ENTER> to continue '
	DB	'Global Scan',13
ENDG	DB	0AH,'End of Global Scan',13
	IF	.NOT.CLS
CLEAR	DB	1CH,1FH,3
	ENDIF
;-----------------------------
;buffers etc
;-----------------------------
IOFLAG	DB	60H,00H,0
DEXT	DB	'HLP'
@OPREG	DB	0
CCHAR	DB	0
CURSOR	DW	0
PWIDE	DB	1
STRCHAR	DB	0
FCB	DS	32
FSPEC	DS	8
	DB	13
CBUFFER	DS	80
	DB	13
KEYWORD	DS	66
	DB	13
SYSBUFF	DS	256
UREC	DB	0
	DB	13
VIDBUFF	DS	2048
DIRBUFF	DW	0
	END	BEGIN
