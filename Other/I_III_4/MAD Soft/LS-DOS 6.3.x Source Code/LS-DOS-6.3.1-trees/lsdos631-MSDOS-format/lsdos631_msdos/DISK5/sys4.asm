;SYS4/ASM - LS-DOS 6.2
	TITLE	<SYS4 - LS-DOS 6.2>
LF	EQU	10
CR	EQU	13
*LIST	OFF			;Get SYS0/EQU
*GET	SYS0/EQU:2
*LIST	ON
*GET	COPYCOM:3		;Copyright message
;
	ORG	1E00H
;
SYS4	JP	BEGIN
;
;	Sentence table - Must be totally within one page
;
MSG0	DB	1,2+80H
;		no error
MSG1	DB	4,2,5,6,9+80H
;		parity error during header read
MSG2	DB	8,2,5,9+80H
;		seek error during read
MSG3	DB	11,7,5,9+80H
;		lost data during read
MSG4	DB	4,2,5,9+80H
;		parity error during read
MSG5	DB	7,27,12,44,5,9+80H
;		data record not found during read
MSG6	DB	13,9,15,7,27+80H
;		attempted to read system data record
MSG7	DB	13,9,14,7,27+80H
;		attempted to read locked/deleted data record
MSG8	DB	42,12,51+0C0H
;		device not available
MSG9	DB	4,2,5,6,10+80H
;		parity error during header write
MSG10	DB	8,2,5,10+80H
;		seek error during write
MSG11	DB	11,7,5,10+80H
;		lost data during write
MSG12	DB	4,2,5,10+80H
;		parity error during write
MSG13	DB	7,27,12,44,5,10+80H
;		data record not found during write
MSG14	DB	10,21,18,19,48+80H
;		write fault on disk drive
MSG15	DB	10,22,19+80H
;		write protected disk
MSG16	DB	23,24,26,25+80H
;		illegal logical file number
MSG17	DB	16,9,2+80H
;		directory read error
MSG18	DB	16,10,2+80H
;		directory write error
MSG19	DB	23,26,41+0C0H
;		illegal file name
MSG20	DB	34,9,2+80H
;		gat read error
MSG21	DB	34,10,2+80H
;		gat write error
MSG22	DB	35,9,2+80H
;		hit read error
MSG23	DB	35,10,2+80H
;		hit write error
MSG24	DB	26,12,45,16+0C0H
;		file not in directory
MSG25	DB	26,46,49+0C0H
;		file access denied
MSG26	DB	1,16,39,51+0C0H
;		directory space full
MSG27	DB	19,39,47+80H
;		disk space full
MSG28	DB	28,29,26,32+80H
;		end of file encountered
MSG29	DB	27,25,30,29,31+80H
;		record number out of range
MSG30	DB	16,47,52,26+80H
;		directory full - can't extend file
MSG31	DB	50,12,44+0C0H
;		program not found
MSG32	DB	23,48,25+0C0H
;		illegal drive number
MSG33	DB	1,42,39,51+0C0H
;		no device space available
MSG34	DB	38,26,43,2+80H
;		load file format error
MSG35	DB	17,21+80H
;		memory fault
MSG36	DB	13,38,9,40,17+80H
;		attempted to load read only memory
MSG37	DB	23,46,13,22,26+80H
;		illegal access attempted to protected file
MSG38	DB	26,12,53+0C0H
;		file not open
MSG39	DB	42,45,54+80H
;		device in use
MSG40	DB	22,15,42+80H
;		protected system device
MSG41	DB	26,57,53!0C0H
;		file already open
MSG42	DB	24,27,58,53,21!0C0H
;		logical record length open fault
MSG43	DB	56,20,2!80H
;		SVC parameter error
MSG44	DB	20,2!80H
;		Parameter error
MSG45	DB	37,2,33+80H
;		unknown error code
BEGIN	AND	70H		;What's the entry?
	RET	Z		;Back on zero
	PUSH	AF
	LD	A,(LSVC$)	;Grab the last SVC
	LD	(SVSVC+1),A	;  and store for later
	POP	AF
	LD	(EXTEND+1),HL	;Value if extended error
	EX	(SP),HL		;Grab return address
	LD	(ERR7+1),HL	;  & stuff it
	POP	HL
	POP	AF		;Pop off the error code
	EX	(SP),HL		;Get user ret address
	LD	(USRET+1),HL	;  for long dsply
	EX	(SP),HL
	PUSH	HL		;Save regs
	PUSH	DE
	PUSH	BC
	LD	HL,(SVCRET$)	;Grab last SVC return
	LD	(SVRET+1),HL	;  and save for dsply
	LD	B,A
	LD	A,(SFLAG$)	;Test expanded-error
	AND	40H		;  flag bit in system flag
	XOR	B
	AND	B
	LD	B,A		;Xfer the result to B
	PUSH	AF		;  & save for later
	AND	3FH		;Strip all but error #
	LD	C,A		;Place error code -> C
	LD	HL,CFLAG$	;If system error suppress
	BIT	6,(HL)		;  flag is set, don't
	JP	NZ,ERR6A	;  display error message.
	BIT	7,(HL)		;If error-to-buffer is
	JR	NZ,ERR0		;  set, put to user buf
	LD	DE,SBUFF$
	JR	ERR0A		;Branch around force
ERR0	SET	6,B		;Force buffer to abbrev
	POP	AF
	SET	6,A
	PUSH	AF
ERR0A	BIT	6,B		;Expanded error display?
	LD	B,0
	JR	NZ,ERR2		;Jump if abbreviated
	PUSH	BC
	LD	HL,ERRMSG	;Pt to "< ERRCOD =...
	LD	C,MLEN		;  & move to buffer
	LDIR
	POP	BC
	EX	DE,HL		;Buffer ptr to HL
	LD	A,C		;Error code to A
	LD	(HL),2FH	;Init for digit conv
ERR1	INC	(HL)		;Bump ASCII digit
	SUB	10		;  count by 10
	JR	NC,ERR1		;Keep bumping 10's digit
	INC	L		;Bump buffer ptr
	ADD	A,3AH		;Convert rmndr to unit's
	LD	(HL),A		;  & place in buffer
	INC	L		;Bump to next pos
	LD	(HL),','	;Stuff a comma & bump
	INC	L
	LD	(HL),' '	;  & a space
	INC	L
	EX	DE,HL		;Buffer ptr back to DE
	PUSH	BC
	LD	HL,ERRMSG1	;"Returns to X'"
	LD	BC,M1LEN
	LDIR
	EX	DE,HL		;HL back to buffer
USRET	LD	DE,$-$		;User ret address
	CALL	@HEX16
	LD	A,27H		;"'"
	LD	(HL),A
	INC	HL
	LD	(HL),LF		;End the line
	INC	HL
	POP	BC
	BIT	6,C		;Extended error?
	JR	NZ,ERR6		;Go if not
	LD	(HL),'*'	;Make long msg look nice
	INC	HL
	LD	(HL),'*'
	INC	HL
	LD	(HL),' '
	INC	HL
ERR6	EX	DE,HL		;DE back to nxt buff line
ERR2	LD	A,C
	CP	63		;"Extended error"?
	JR	NZ,ERR2A
;
;	Do extended error only
;
	PUSH	DE		;Save buffer ptr
EXTEND	LD	DE,$-$		;Ext. error value fm HL
	LD	HL,EXT$ERR+26
	CALL	@HEX16
	LD	HL,EXT$ERR	;Point to error msg
	POP	DE		;Recvr buffer
	PUSH	HL		;Save msg start
	PUSH	BC
	LD	BC,M2LEN	;Len of error
	LDIR			;Move into buffer
	POP	BC
	LD	HL,CFLAG$	;See if to user buffer
	BIT	7,(HL)
	RES	7,(HL)		;Don't logot if so
	POP	HL
	CALL	Z,@LOGOT
	JR	ERR6A		;  and exit
;
;	Do regular (non-extended) error
;
ERR2A	LD	A,45		;If error code is > 43,
	CP	C		;  then set to 44 (max)
	PUSH	DE		;Save ptr to 1st char
	JR	NC,ERR3
	LD	C,A
ERR3	LD	HL,CODTAB	;Pt to start of code
	ADD	HL,BC		;  address table & index
	LD	L,(HL)		;P/u lo-order vector
	LD	H,MSG0<-8	;Set hi-order vector
;
;	HL now points to sentence table
;
ERR5	LD	A,(HL)		;P/u word offset
	AND	3FH		;  & strip any flags
	LD	B,A		;Xfer word # to reg B
	PUSH	HL		;Save sentence pointer
	LD	HL,WORDS	;Dictionary start
LP1	LD	A,(HL)		;Scan through the table
	RLCA			;  counting words (bit 7
	INC	HL		;  denotes word end)
	JR	NC,LP1		;  until requested word
	DEC	B		;  is reached
	JR	NZ,LP1
;
;	Found the start of the desired word
;
LP2	LD	A,(HL)		;Transfer the word until
	RLCA			;  bit 7 set (last char)
	SRL	A		;  while resetting bit-7
	LD	(DE),A		;Stuff letter of word
	INC	HL		;  & bump pointers
	INC	DE
	JR	NC,LP2
	LD	A,' '		;Move a space into buffer
	LD	(DE),A
	INC	DE
	POP	HL		;Rcvr ptr to sentence
	LD	A,(HL)		;P/u this word byte
	INC	HL
	RLCA			;Was this the last word?
	JR	NC,ERR5		;Loop if still more to go
	EX	(SP),HL		;Get ptr to 1st char
	LD	A,(HL)
	RES	5,A		;Set it to UC
	LD	(HL),A
	POP	HL		;Get back sentence ptr
	POP	AF		;Rcvr error code
	PUSH	AF
	PUSH	HL		;Save sentence ptr
	LD	A,CR
	LD	(DE),A		;Stuff end-of-line
	LD	HL,CFLAG$	;If to user buffer,
	BIT	7,(HL)		;  then don't LOGOT
	RES	7,(HL)
	LD	HL,SBUFF$	;Display the line
	CALL	Z,@LOGOT
	POP	HL
	POP	AF		;Rcvr word index
	PUSH	AF
	BIT	6,A		;Test if a disk error
	CALL	Z,DSPSPEC	;Get filespec if it is
ERR6A	POP	AF
	POP	BC
	POP	DE
	POP	HL
	OR	A		;Ret to user if bit 7
ERR7	JP	M,0		;  of error code is set
	JP	@ABORT		;  else abort
;
;	Routine to display the filespec
;
DSPSPEC	PUSH	IX
	LD	IX,(JDCB$)	;P/u FCB vector
	DEC	HL
	BIT	6,(HL)
	JR	NZ,DSPC2
	LD	C,(IX+6)	;Device 1st char or drive
	LD	B,(IX+7)	;Device 2nd char or DEC
	BIT	7,(IX+0)	;Test if file or device
	JR	NZ,RCVSPEC	;Jump if it is a file
	LD	HL,OPN$DCB
DSPC1	LD	A,C		;Possible devspec, 1st char
	CP	'A'
	JR	C,DCBUNK	;C=do unknown
	CP	'Z'+1
	JR	NC,DCBUNK	;Again, go if bad
	LD	A,B		;Check 2nd character
	CP	'0'
	JR	C,DCBUNK
	CP	'Z'+1
	JR	NC,DCBUNK
	LD	(OPN$DCB+18),BC	;Stuff the device name
DSPC1A	EQU	$-2
	POP	IX
	JR	RSPC6		;Go display it
;
DCBUNK	LD	HL,UNK$TYP
	POP	IX
	JR	RSPC6
;
DSPC2	LD	C,(IX+1)	;P/u 1st char or vector
	LD	B,(IX+2)	;P/u 2nd char or vector
	LD	A,(IX+0)
	LD	HL,DEV$NAM
	LD	(DSPC1A),HL	;Change dsply message
	LD	HL,DEV$EQ
	CP	'*'		;If '*', go to device
	JR	Z,DSPC1
	PUSH	IX		;  else assume file
	POP	HL
	LD	DE,FILE$EQ+7	;Init "<file=...
	LD	B,24		;Max filespec
DSPC3	LD	A,(HL)		;P/u file spec char
	CP	3		;ETX?
	JR	Z,DSPC3A
	CP	CR		;EOL?
	JR	Z,DSPC3A
	OR	A
	JR	Z,DSPC3A	;Zero ok terminator, too.
	CALL	CHKASC		;Check if an ASCII char
	JR	C,DCBUNK	;  and abort if not
	LD	(DE),A
	INC	DE
	INC	HL
	DJNZ	DSPC3		;Loop until end
DSPC3A	LD	HL,FILE$EQ
	JR	RSPC5
;
;	Routine to get recover the filespec
;
RCVSPEC	LD	A,C
	ADD	A,30H		;Conv drive # to decimal
	CP	'0'		;Valid drive?
	JR	C,DCBUNK
	CP	'8'
	JR	NC,DCBUNK
	LD	(OPN$FCB+16),A
	LD	A,B		;Dec into A
	LD	HL,OPN$FCB+23	;Pt into msg string
	CALL	@HEX8		;  and convert it.
	EX	DE,HL		;DE back to buff end
	LD	HL,OPN$FCB
	INC	DE
RSPC5	LD	A,CR		;Close with EOL
	LD	(DE),A
	POP	IX
RSPC6	CALL	@LOGOT		;Log it
;
;	Build the SVC info line
;
	LD	DE,LILBUF	;Tempy for hexdec
SVSVC	LD	A,$-$		;P/u the stored last svc
	LD	L,A
	LD	H,0		;  into HL for conv
	CALL	@HEXDEC
	LD	DE,SVC$NUM+11
	CALL	EDEC
	LD	A,3		;Then put in ETX
	LD	(DE),A
;
	LD	HL,SVC$RET+16	;Now, do last svc return
SVRET	LD	DE,$-$
	CALL	@HEX16
	LD	HL,SVC$NUM
	CALL	@LOGOT
	LD	HL,SVC$RET
	JP	@LOGOT		;Log it 
;
;	Routine to check for valid chars
;
CHKASC	LD	A,(HL)		;Xfer until 1st space
	CP	'.'
	RET	C		;CF on ret = bad char
	CP	':'+1
	JR	NC,CKASC1
	JR	CKASC2
CKASC1	CP	'A'
	RET	C
	CP	'Z'+1
CKASC2	CCF
	RET
;
EDEC	LD	HL,LILBUF	;Pt to conved decimal num.
ED1	LD	A,(HL)
	OR	A
	RET	Z
	CP	' '
	INC	HL
	JR	Z,ED1
	LD	(DE),A		;Store valid digit
	INC	DE
	JR	ED1
;
;
;
EXT$ERR	DB	'** Extended error, HL = X',27H,'xxxx',27H,CR
M2LEN	EQU	$-EXT$ERR
ERRMSG	DB	LF,'** Error code = '
MLEN	EQU	$-ERRMSG
ERRMSG1	DB	'Returns to X',27H
M1LEN	EQU	$-ERRMSG1
DEV$EQ	DB	'Device = *'
DEV$NAM	DB	'XX',CR
FILE$EQ	DB	'File = NNNNNNNN/EEE.PPPPPPPP:D',CR
OPN$FCB	DB	'Open FCB, Drive=n, DEC=   ',CR
OPN$DCB	DB	'Open DCB, Device=*xx',CR
UNK$TYP	DB	'Unknown FCB/DCB',CR
SVC$NUM	DB	'Last SVC = nnn',3
SVC$RET	DB	', Returned to X',27H,'xxxx',27H,CR
;
LILBUF	DS	5
	DB	0
;
;	Table points to low-order bytes of messages
;
CODTAB	DB	MSG0&0FFH,MSG1&0FFH,MSG2&0FFH,MSG3&0FFH
	DB	MSG4&0FFH,MSG5&0FFH,MSG6&0FFH
	DB	MSG7&0FFH,MSG8&0FFH,MSG9&0FFH
	DB	MSG10&0FFH,MSG11&0FFH,MSG12&0FFH,MSG13&0FFH
	DB	MSG14&0FFH,MSG15&0FFH,MSG16&0FFH,MSG17&0FFH
	DB	MSG18&0FFH,MSG19&0FFH,MSG20&0FFH,MSG21&0FFH
	DB	MSG22&0FFH,MSG23&0FFH,MSG24&0FFH,MSG25&0FFH
	DB	MSG26&0FFH,MSG27&0FFH,MSG28&0FFH,MSG29&0FFH
	DB	MSG30&0FFH,MSG31&0FFH,MSG32&0FFH,MSG33&0FFH
	DB	MSG34&0FFH,MSG35&0FFH,MSG36&0FFH,MSG37&0FFH
	DB	MSG38&0FFH,MSG39&0FFH,MSG40&0FFH,MSG41&0FFH
	DB	MSG42&0FFH,MSG43&0FFH,MSG44&0FFH,MSG45&0FFH
;
;	Word dictionary
;
WORDS	DB	'R'!80H			;Start table with bit 7
	DB	'n','o'!80H		;1
	DB	'erro','r'!80H		;2
	DB	'o'!80H			;3 extra word
	DB	'parit','y'!80H		;4
	DB	'durin','g'!80H		;5
	DB	'heade','r'!80H		;6
	DB	'dat','a'!80H		;7
	DB	'see','k'!80H		;8
	DB	'rea','d'!80H		;9
	DB	'writ','e'!80H		;10
	DB	'los','t'!80H		;11
	DB	'no','t'!80H		;12
	DB	'attempted t','o'!80H	;13
	DB	'locked/delete','d'!80H	;14
	DB	'syste','m'!80H		;15
	DB	'director','y'!80H	;16
	DB	'memor','y'!80H		;17
	DB	'o','n'!80H		;18
	DB	'dis','k'!80H		;19
	DB	'paramete','r'!80H	;20
	DB	'faul','t'!80H		;21
	DB	'protecte','d'!80H	;22
	DB	'illega','l'!80H	;23
	DB	'logica','l'!80H	;24
	DB	'numbe','r'!80H		;25
	DB	'fil','e'!80H		;26
	DB	'recor','d'!80H		;27
	DB	'en','d'!80H		;28
	DB	'o','f'!80H		;29
	DB	'ou','t'!80H		;30
	DB	'rang','e'!80H		;31
	DB	'encountere','d'!80H	;32
	DB	'cod','e'!80H		;33
	DB	'GA','T'!80H		;34
	DB	'HI','T'!80H		;35
	DB	'y'!80H			;36
	DB	'unknow','n'!80H	;37
	DB	'loa','d'!80H		;38
	DB	'spac','e'!80H		;39
	DB	'onl','y'!80H		;40
	DB	'nam','e'!80H		;41
	DB	'devic','e'!80H		;42
	DB	'forma','t'!80H		;43
	DB	'foun','d'!80H		;44
	DB	'i','n'!80H		;45
	DB	'acces','s'!80H		;46
	DB	'ful','l'!80H		;47
	DB	'driv','e'!80H		;48
	DB	'denie','d'!80H		;499
	DB	'progra','m'!80H	;50
	DB	'availabl','e'!80H	;51
	DB	'- can''t exten','d'!80H	;52
	DB	'ope','n'!80H		;53
	DB	'us','e'!80H		;54
	DB	'o','r'!80H		;55
	DB	'SV','C'!80H		;56
	DB	'alread','y'!80H	;57
	DB	'lengt','h'!80H		;58
LAST	EQU	$
	IFGT	$,DIRBUF$
	ERR	'Module too big'
	ENDIF
	ORG	MAXCOR$-2
	DW	LAST-SYS4	;Overlay length
;
	END	SYS4
