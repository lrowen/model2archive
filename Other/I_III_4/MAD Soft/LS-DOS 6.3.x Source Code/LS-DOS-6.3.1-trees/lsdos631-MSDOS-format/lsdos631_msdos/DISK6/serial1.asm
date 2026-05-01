;SERIAL1 - '87
;DUPE / QFB / 5.1 / 6.x    - 08/30/83
;
;DUPE/ASM - LDOS 5.1.1 - 06/22/83
;QFB    - LDOS 5.1 - 07/14/83
	IF	V5
BREAK	EQU	1
	IF	DUPE
	TITLE	'<DUPE - LDOS 5.1>'
	ELSE
	TITLE	'<QFB - LDOS 5.1>'
	ENDIF
	ENDIF
	IF	V6
BREAK	EQU	80H
	IF	DUPE
	TITLE	'<DUPE - 6.X>'
	ELSE
	TITLE	'<QFB - 6.X>'
	ENDIF
	ENDIF
;*=*=*
LF	EQU	10
CR	EQU	13
CUROFF	EQU	15
CURSON	EQU	14
;*=*=*
TIME	EQU	01000H		;Timeout for CKDRV1
;*****
START	LD	(STACK),SP	;Save current stack
	PUSH	HL
	CALL	MODEL		;Adjust for version
	LD	HL,HELLO$
	CALL	@DSPLY		;Logon now
REDOSER	LD	HL,SERIAL$
	CALL	@DSPLY
	LD	HL,KEYBUF
	PUSH	HL
	LD	B,5
	CALL	@KEYIN
	JP	C,@ABORT
	@@DECHEX
	POP	HL
	LD	A,B
	OR	C
	JP	Z,@ABORT
	LD	HL,13974
	SBC	HL,BC		;Check that > 13975
	JP	NC,REDOSER
	LD	(KEYBUF),BC	;Save binary keybuf
	POP	HL
	DEC	HL		;Set up for scan loop
;Get params fm cmd line
	PUSH	HL
PSCN	INC	HL		;Scan for parms first
	LD	A,(HL)
	CP	CR+1
	JR	C,CMD2		;No params
	CP	'('
	JR	NZ,PSCN
	LD	DE,PTABLE
	CALL	@PARAM
M1	EQU	$-2
	JP	NZ,PRMERR
;
;Get drive numbers fm cmd line
CMD2	POP	HL		;Cmd line again
	LD	DE,DRVLST	;Storage for drv #s
	CALL	STFDRV		;Parse cmd line for #s
	JP	NZ,PRMERR	;Bad entry
	JR	DRVDUN		;Skip logon unless repeat
;Renter here after clearing parms
RESTART	LD	HL,HELLO$	;Hello message
	CALL	@DSPLY
;If drive not entered, prompt for it
DRVDUN	LD	DE,DRVLST	;Look at drive #'s entered
	LD	A,(DE)		;1st is source
	OR	A
	JR	NZ,CKDST	;Go if source entered
;Ask for source drive
GTSOR	LD	B,1
	LD	HL,SPRMPT$	;Otherwise ask
	CALL	GETRESP
	JP	C,EXITA
	CALL	STUFFDR
	JR	DRVDUN		;Make sure one is entered
CKDST	INC	DE		;Check for at least one 
	LD	B,A		;Save source #
	LD	A,(DE)		;Destination drive
	OR	A
	JR	Z,ASKDST	;Get at least one
SMDR	CP	B		;Cant match source!
	JR	NZ,NSLOT	
	LD	HL,MATCH$
	CALL	@DSPLY
	CALL	CLEAR2
	JP	DRVDUN		;Start over
NSLOT	INC	DE		;More dest disks?
	LD	A,(DE)
	OR	A
	JR	NZ,SMDR		;Test them also
	JR	GOTDST		;Go at end of list
ASKDST	PUSH	DE
;Ask for destination
	LD	B,10
	LD	HL,DPRMPT$	;Otherwise ask
	CALL	GETRESP
	JP	C,EXITA
	CALL	STUFFDR		;Put in list
	POP	DE		;Restore DRVLST+1
	JP	Z,DRVDUN	;If resp OK,check for entries
	XOR	A		;Bad entry
	LD	(DE),A		;So clear it
	LD	HL,INVAL$	;Tell operator
	CALL	@DSPLY
	JP	DRVDUN		;And re-prompt
;
;Get other info unless (Q=N)
GOTDST	LD	HL,(QPARM)	;Prompts? Default=off
	LD	A,L
	OR	H
	JR	Z,SET1
	LD	A,(GATP)
	DEC	A		;Is is 1?
	JR	NZ,GNTRD	;Parm was entered
	LD	HL,GPRMPT$	;Otherwise prompt
	CALL	GETYN
	LD	(GAT?),A	;Save for later
GNTRD	LD	A,(V1P)
	DEC	A
	JR	NZ,V1NTD	;Already entered
	LD	HL,VP1$
	CALL	GETYN
	LD	(V1P?),A
V1NTD	LD	A,(V2P)
	DEC	A
	JR	NZ,SET1
	LD	HL,VP2$
	CALL	GETYN
	LD	(V2P?),A
SET1	LD	A,(GAT?)	;Reverse GAT? flag so the
	CPL			;Parameter can be ALL
	LD	(GAT?),A	;ALL means GAT=N
; wait for disk insertion
WTDS1	LD	HL,PMTDST$	;"load disks...
	CALL	@DSPLY
PREPDUP	CALL	@KEY
	CP	BREAK
	JP	Z,EXITA
	CP	CR
	JR	NZ,PREPDUP
	LD	A,(DRVLST)	;Get source drive
	LD	(SYSPEC+16),A	;Insert drive spec
	SUB	30H
	LD	C,A
	LD	(SDRVX),A
	@@GTDCT
	LD	A,'0'		;Start with sys0
	LD	(SYSPEC+3),A
	LD	DE,GATBUF
	LD	HL,SYSPEC
	PUSH	HL
	@@FSPEC
	LD	HL,SECBUF
	LD	B,0
	@@OPEN
	JR	Z,SYS1
SYSMIS	LD	HL,MISSYS$
	@@LOGOT
	JP	@ABORT
SYS1	LD	C,SYS0SEC
	@@POSN
	@@READ
	JR	NZ,SYSMIS	;Quit on read error
;	LD	A,(IY+5)	;Get current cyl
	LD 	A,SYS0TRK
	LD	(CYL1),A
	LD	(GET0),A
	LD	A,(SECBUF+SYS0OFF-2)	;Check for serial #
	CP	'#'
	JR	NZ,SYSMIS
	LD	A,'3'
	LD	(SYSPEC+3),A
	LD	DE,GATBUF+32
	POP	HL
	@@FSPEC
	LD	HL,TRKBUF
	LD	B,0
	@@OPEN
	JR	NZ,SYSMIS
	LD	C,4
	@@POSN
	@@READ
	JR	NZ,SYSMIS	;Quit on read error
;	LD	A,(IY+5)	;Get cyl #
	LD	A,SYS3TRK
	LD	(CYL2),A	;Save for sys3 update
	LD	HL,GATBUF+47
	LD	A,(HL)		;Get starting gran
	AND	0E0H
	RLCA
	RLCA
	RLCA
	LD	B,A		;Save gran number
	OR	A
	LD	A,SYS3SEC
	JR	Z,SYS2
SYS2A	ADD	A,6
	DJNZ	SYS2A
SYS2	LD	(OFX2),A	;Save sector offset
	LD	D,$-$		;Track for sys0
GET0	EQU	$-1
	LD	A,18
	BIT	5,(IY+4)	;Two sided?
	JR	Z,SYS3
	ADD	A,A		;Double sector count
SYS3	LD	B,A		;Sectors to search
	LD	E,0
	LD	C,$-$
SDRVX	EQU	$-1		;Drive #
	LD	HL,TRKBUF
SYS5	@@RDSEC			;Search for this sector
	JP	NZ,SYSMIS	;Quit on read error
	CALL	CPSER		; containing serial #
	JR	Z,SYS4
	INC	E
	DJNZ	SYS5
	JP	SYSMIS
SYS4	LD	A,E		;Offset for sys0
	LD	(OFX1),A
;
REPEAT	LD	SP,(STACK)	;For re-entry
;Log in source disk
	LD	A,(DRVLST)	;Get source drv
	SUB	30H		;Remove ASCII
	LD	C,A
	PUSH	BC
	CALL	GETDCT
	BIT	3,(IY+3)	;Hard drive?
	JP	NZ,NOTHARD
	LD	(SORDCT),IY	;Save source
	POP	BC
	CALL	CKDRV1		;Test for disk
	JR	Z,SREADY
SERR	LD	HL,NTRDY$	;Load source disk
	CALL	@DSPLY
	JP	WTDS1		;Wait again
SREADY	LD	DE,0		;Rd boot sec
	LD	HL,GATBUF
	CALL	RDSEC
	JR	NZ,SERR
	LD	A,(IY+3)
	LD	(SVTRK0),A	;Keep DENSITY for later
	INC	HL
	INC	HL
	LD	A,(HL)
	AND	7FH
	DEC	HL
	DEC	HL
	LD	(IY+9),A	;DIR cyl
	LD	D,A
	CALL	RDSEC		;Load GAT
	CP	6		;Must be SYS sector
	JR	NZ,SERR
;
;       IF      @MOD2.OR.@MOD4
;
;       LD      A,(GATBUF+0CDH) ;Check if mod II SYS Disk
;       RLCA                    ; test it
;       JR      C,NOTSYS        ;go if not
;       PUSH    IY
;       LD      A,101           ;Get flags
;       RST     40
;       LD      A,(IY+'T'-'A')  ;Get the TFALG
;       POP     IY
;       CP      12              ;Check for a 12/2
;       JR      Z,ABT212        ;if so abort
;       CP      2
;       JR      NZ,NOTSYS       ;if ok to do
;ABT212
;       LD      HL,ABT212$      ;point to message
;       LD      A,12            ; LOGOT
;       RST     40              ; do it
;       JP      EXITA
;ABT212$ DB      LF,'Cannot "QFB" Mod 2/12 System Disks',CR
;       ENDIF
;
NOTSYS
	LD	HL,(GATBUF+0CCH)	;P/u disk type
	IF	.NOT.DUPE	;QFB checks for protected
	BIT	4,H		;Via bit in GAT
	JP	NZ,TUFLUK	;Quit if set
	ENDIF
	LD	A,22H		;Trk offset fm 35
	ADD	A,L
	LD	(IY+6),A
	RES	5,(IY+4)	;Set single side
	BIT	5,H		;Unless disk is
	JR	Z,LG1
	SET	5,(IY+4)	;Double sided
LG1	CALL	CALCSEC
;
;Init max of 7 dest drives
	LD	SP,(STACK)	;Rentry point
	LD	DE,DRVLST+1	;Dest drives
	LD	BC,ACTLST	;Move to working list
	LD	HL,DSTDCT	;And store DCT pointers
SETDCT	LD	A,(DE)		;P/u ASCII number
	LD	(BC),A		;Move to active list
	SUB	30H		;Remove ASCII
	JP	C,SETDUN	;Hit zero byte
	PUSH	HL
	CALL	MAKEDCT		;Dup source dct entry to dest
	POP	HL
	JP	NZ,TYPERR	;Incorrect disk type for dup
	PUSH	BC
	PUSH	IY
	POP	BC		;DCT ptr to BC
	LD	(HL),C		;Store in DSTDCT list
	INC	HL
	LD	(HL),B
	INC	HL
	POP	BC
	INC	BC
	INC	DE		;Move to next
	JR	SETDCT		;Loop through dest disks
MAKEDCT	PUSH	BC
	CALL	GETDCT		;IY=>dct for drive
	BIT	7,(IY+3)	;WP?
	JP	NZ,NOTWP	;Can't..
	BIT	3,(IY+3)
	JP	NZ,NOTHARD	;Can't -hard disk
	LD	HL,(SORDCT)
	INC	HL		;Skip over drvr address
	INC	HL
	INC	HL
	LD	C,(HL)		;Fm source
	LD	A,00101000B	;Size/type
	AND	C
	LD	B,A
	LD	A,(IY+3)
	AND	00101000B
	XOR	B		;Must match
	JR	NZ,BDTYP1
	LD	A,01111000B	;Bits fm source
	AND	C
	LD	B,A
	LD	A,00000111B	;Bits fm dest
	AND	(IY+3)
	OR	B		;Merge
	LD	(IY+3),A	;Replace
	INC	HL
	BIT	6,C		;DDEN disk?
	JR	Z,SDE1
	BIT	6,(IY+4)	;Can dest handle DDEN?
	JR	Z,BDTYPE	;Error if not
SDE1	RES	5,(IY+4)	;Set Single sided
	BIT	5,(HL)		;Dbl sided?
	JR	Z,SDE2
	SET	5,(IY+4)	;Set DS (hope drive is!)
SDE2	INC	HL		;Skp +5
	INC	HL		;+6
	PUSH	DE		;Move next 4 bytes
	LD	B,6
	PUSH	IY
	POP	DE
MVP	INC	DE
	DJNZ	MVP
	LD	BC,4
	LDIR
	POP	DE
	OR	0FFH		;Set NZ
	CALL	DRVNOP		;Be sure driver exists
BDTYPE	POP	BC
	RET
BDTYP1	OR	0FFH
	JR	BDTYPE
; *=*=* ready to start *=*=*
SETDUN	XOR	A		;Init values
	LD	(CURDRV),A	;Store current dest offset
	LD	(CURCYL),A	;And trk posn
	LD	(ERRCNT),A	;Reset errors
	IF	DUPE.OR.@MOD2
	CPL			;Set 0FF default
	LD	(WRTFLG),A	;Spcl fmt flag
	ENDIF
	LD	A,0C9H		;Block interrupt processor
	LD	(@RST38),A
	LD	A,CUROFF
	CALL	@DSP		;Cursor off
; *=*=* format one cyl on all dest drives *=*=*
FMTONE	CALL	CKPAWS		;Look for break pressed
	CALL	GETDCT1		;IY=>dest dct
	JR	Z,READIN	;All done w/dest track
	LD	A,(CURCYL)
	OR	A
	JR	NZ,DISKIN	;If first access to disk
	CALL	CKDRV1		;Then RESTORE & check first
	JR	NZ,LCT1		;Not ready....
	CALL	RSELCT		;Be sure RESTORE has settled
	LD	BC,0A8EH	;40ms... shld be max
	CALL	@PAUSE
	IF	DUPE.OR.@MOD2
	LD	A,(SVTRK0)	;Is source disk..
	AND	01100000B	;8" DISK?
	CP	00100000B	;SDEN trk 0?
	JR	NZ,DISKIN	;No, then continue
	LD	A,(GATBUF+60H)	;Check for Mod 2/12 system
	INC	A		;Via locked out boot trk
	JR	NZ,DISKIN	;Continue if not
	CALL	FORMCYL		;Do normal format first
	JP	SPCL0		;Then re-do front side
	ELSE
	JR	DISKIN		;Skip for mod 4 QFB
	ENDIF
;
LCT1	LD	HL,NODSK$
	CALL	@DSPLY
	CALL	LOCKOUT		;No disk in drive
	JR	FMTONE		;So skip to next
;
DISKIN	CALL	FORMCYL		;Format this drive track
	CALL	ERRCHK		;Lockout if wrt prot etc.
	JR	FMTONE		;Do all dest disks
; *=*=* read a source cyl *=*=*
READIN
	IF	DUPE.OR.@MOD2
	CALL	ISSPL?		;Is this cyl 0?
	JR	Z,WRLP1		;Skip if special
	ENDIF
	CALL	READSOR		;Load trk fm source disk
	CALL	SERCHK		;Check if bad read
;*=*=* write the cyl to dest drives allowing one retry *=*=*
WRLP1	CALL	GETDCT1		;Next dest disk
	JR	Z,BMPCYL	;Move to next trk if done
	IF	DUPE.OR.@MOD2
	CALL	ISSPL?		;Spcl trk?
	JR	Z,DOSTP		;Skip if spcl trk 0
	ENDIF
	XOR	A
	LD	(RETRY),A
RTLP	CALL	WRTOUT		;Write the track
	CALL	ERRCHK		;Lock out if write error
	JR	NZ,STP1		;Skip verify if locked
	LD	A,(V1P?)	;Verify on same pass?
	OR	A
	JR	Z,STP1		;If no verify, step
	CALL	VERCYL
	LD	A,(ERRCNT)	;Any errors?
	OR	A
	JR	Z,STP1		;No, continue
	LD	A,(RETRY)
	INC	A
	LD	(RETRY),A
	CP	2
	JR	C,RTLP		;One retry on verify error
	CALL	ERRCHK
STP1	LD	A,(CURCYL)
	CP	(IY+6)		;Is this the last trk?
	JR	NZ,DOSTP	;No, move in now..
	LD	A,(V2P?)	;End, are we verifying?
	OR	A
	CALL	Z,RESTOR	;Move out if not
	JR	WRLP1		;Next drive
DOSTP	CALL	STEPIN		;Move this drive head
	JR	WRLP1		;On to next drive
;*=*=* move to next cyl till done *=*=*
BMPCYL	LD	A,(CURCYL)
	CP	(IY+6)		;High trk #
	JR	Z,DONWRT	;Then this batch is done
	INC	A		;Otherwise bump cyl
	LD	(CURCYL),A
	JP	FMTONE		;And do next one  
; *=*=* verify stepping out if wanted *=*=*
DONWRT	LD	A,(V2P?)	;Verify on 2nd pass?
	OR	A
	JR	Z,PASSDON	;Skip if not on
VRLP1	CALL	GETDCT1
	JR	Z,PASSDON
	LD	A,(IY+6)	;Last trk
	LD	(CURCYL),A	;Reset
VRLP2	CALL	VERCYL
	JR	NZ,VRLP1	;Skip if bad
	LD	A,(CURCYL)
	OR	A
	JR	Z,VRLP1		;If trk 0 complete-next drv
	DEC	A
	LD	(CURCYL),A
	IF	DUPE.OR.@MOD2
	CALL	ISSPL?		;At special trk 0?
	JR	Z,VRLP1		;Then ignore it
	ENDIF
	JR	VRLP2
;
NOSER	LD	HL,SERROR$
	@@DSPLY
	JR	SUP2
;
; *=*=* bump count of disks completed *=*=*
;
PASSDON	LD	HL,(COUNT)	;P/u disk counter
CLP1	PUSH	HL
	CALL	GETDCT1
	JR	Z,SUP1		;No more drives
	LD	A,(MYDRV)	;Get drive
	AND	7
	LD	C,A
	ADD	A,30H
	LD	(SERROR),A	;Save in case of error
	LD	D,$-$
CYL1	EQU	$-1
	LD	E,$-$
OFX1	EQU	$-1
	LD	HL,TRKBUF
	@@RDSEC			;Get sys0 sector
	JR	NZ,NOSER
	PUSH	HL
	LD	HL,(KEYBUF)	;P/u serial #
	CALL	ASCSER		;Install in ascii
	POP	HL
	@@WRSEC
	JR	NZ,NOSER
	LD	D,$-$		;Now do sys3
CYL2	EQU	$-1
	LD	E,$-$
OFX2	EQU	$-1
	@@RDSEC
	JR	NZ,NOSER
	PUSH	HL
	LD	HL,(KEYBUF)	;Get serial #
	CALL	CMPSER		;Install compressed and inc
	POP	HL
	@@WRSEC
	JR	NZ,NOSER
SUP2	OR	1
SUP1	POP	HL
	JR	Z,CSET
	INC	HL
	JR	CLP1
CSET	LD	(COUNT),HL	;Store total so far
	LD	A,H		;Flag cksum table done
	OR	L		;If a complete pass is done
	JR	Z,NUNDUN
	LD	(PASS1),A
	LD	E,A
	LD	A,1
	CP	E
	JR	NC,CS1
	LD	A,'s'		;If more than one
	LD	(PLURAL),A	;Correct message
CS1	EX	DE,HL		;Count to DE
	LD	HL,DCNT		;Put in ascii
	CALL	HEXDEC
	LD	HL,(KEYBUF)	;display last SER# used
	DEC	HL
	EX	DE,HL
	LD	HL,DSBUFF
	CALL	HEXDEC
	LD	HL,DPRPPT$	;Copy complete 
	CALL	@DSPLY
; *=*=* prompt for next disk *=*=*
NUNDUN	LD	HL,RPDSK$	;Replace disks
	CALL	@DSPLY
   	LD	B,00001111B	;Set tone cycle
TONE	LD	A,104		;sound SVC
	RST	28H
	DEC	B
	JR	NZ,TONE
WATE	CALL	@KEY
	CP	BREAK		;BREAK?
	JP	Z,EXITA		;Then quit
	CP	CR		;ENTER?
	JR	NZ,CKR
	LD	HL,HELLO$	;Then repeat
	CALL	@DSPLY
	JP	REPEAT
CKR	AND	5FH
	CP	'R'		;R?
	JR	NZ,WATE
	CALL	CLEAR		;Then get new parms
	JP	RESTART		;For repeat
;
;
	IF	DUPE.OR.@MOD2	;Skip for most QFB's
; skip track? NZ=no, copy it
ISSPL?	LD	A,(CURCYL)	;Is this cyl 0?
	OR	A
	RET	NZ
	LD	A,(WRTFLG)	;Is trk 0 special fmt?
	OR	A		;Z=spcl trk 0 done already
	RET			;W/condition
;
; if mod 2/12 system disk must have sden 128 byte sectors
; on track 0..
SPCL0:	LD	HL,SYSTRK$
	CALL	@DSPLY
	XOR	A
	LD	(WRTFLG),A	;Skip normal read/write
	LD	A,(IY+3)	;Get I/O flags
	LD	(RESW3),A	;Save for restore
	AND	10101111B	;Single den, single side
	LD	(IY+3),A	;Update DCT
	LD	A,(IY+4)	;Get flag
	LD	(RESW4),A	;Save for restore
	RES	5,(IY+4)	;Set single sided!
	CALL	FORM0		;Format side 0
	IF	V6
	LD	HL,(RFLAG)	;Force just one retry
	LD	A,(HL)
	LD	(HL),1
	LD	(RSAV),A
	ENDIF
	JP	NZ,W0ERR
	PUSH	IY
;
	LD	IY,(SORDCT)
	LD	A,(IY+7)
	LD	(SAVSEC),A	;Save old # sectors
	LD	DE,0		;Init cyl/sector
	LD	HL,TRKBUF	;Buffer start
	LD	B,3
READ0L	LD	(IY+7),26	;Reset # sectors
	RES	6,(IY+3)	;Force sden
	CALL	RDSEC		;Read sector
	LD	A,(SAVSEC)
	LD	(IY+7),A
	JR	NZ,RTRY		;Retry if read error
	BIT	4,(IY+3)	;Did back side get selected?
	JR	Z,BPCNT		;No, still on front..
RTRY	DJNZ	READ0L		;Some re-tries here
	JR	R0ERR		;Go on error
BPCNT	LD	BC,80H		;Offset to next
	ADD	HL,BC		;HL => next buffer
	INC	E		;Bump sector
	LD	A,E		;Get result
	SUB	27		;At end?
	JR	NZ,READ0L	;Go for count
	POP	IY		;Back to dest disk..
;
	LD	HL,TRKBUF	;Buffer start
	LD	DE,0
	LD	A,(IY+7)
	LD	(SAVSEC),A
WRIT0L	LD	(IY+7),26
	RES	6,(IY+3)
	CALL	WRSEC		;Write sector
	LD	A,(SAVSEC)
	LD	(IY+7),A
	JR	NZ,W0ERR	;Go on error
	LD	BC,80H		;Offset to next
	ADD	HL,BC		;HL => next buffer
	INC	E		;Bump sector
	LD	A,E		;Get result
	SUB	27		;At end?
	JR	NZ,WRIT0L	;Go for count
;
	LD	HL,TRKBUF	;Buffer start
	LD	DE,0
VER0L	LD	(IY+7),26
	RES	6,(IY+3)
	CALL	VERSEC		;Verify sector
	LD	A,(SAVSEC)
	LD	(IY+7),A
	JR	NZ,W0ERR	;Go on error
	INC	E		;Bump sector
	LD	A,E		;Get result
	SUB	27		;At end?
	JR	NZ,VER0L	;Go for count
	CALL	RESDCT
	JP	FMTONE
;
; bad source disk..
R0ERR	POP	IY
;Bad dest disk
W0ERR	CALL	RESDCT
	CALL	LOCKOUT		;Lock drive out
	JP	FMTONE		;Back to loop
;
RESDCT	LD	DE,0		;Get config data
RESW3	EQU	$-2
RESW4	EQU	$-1
	LD	(IY+3),E	;Update DCT
	LD	(IY+4),D
	IF	V6
	LD	A,(RSAV)
	LD	HL,(RFLAG)
	LD	(HL),A
	ENDIF
	RET			;Done
;
;       format cylinder 0
;
FORM0	LD	HL,TRKBUF
	CALL	BUILD0		;Create track image
	CALL	RESTOR		;Select drive
	CALL	RSELCT		;Wait till ready
	LD	BC,600		;And a little more
	CALL	@PAUSE
	LD	DE,0		;Init location
	LD	HL,TRKBUF
	CALL	WRCYL		;Format it!
	RET			;Return with status
;
BUILD0:	PUSH	HL		;Save buffer
	PUSH	HL		;Save buffer
	LD	HL,SECTBL	;Sector table
	EX	(SP),HL		;HL => buffer
	LD	DE,FMTTBL	;Format table
	CALL	SETF0		;Post index gap
	LD	(TBLPOS),DE	;Save table position
	LD	C,27		;Secs/cyl 0
BUILDLP	LD	DE,0		;Fetch table
TBLPOS	EQU	$-2
	CALL	SETF0		;Pre-ID sync
	LD	(HL),0FEH	;ID header
	INC	HL		;Bump
	LD	(HL),0		;Cylinder #
	INC	HL		;Bump
	LD	(HL),0		;Side 0
	INC	HL		;Bump
	EX	(SP),HL		;Get sector table
	LD	A,(HL)		;Get sector
	INC	HL		;Next sector
	EX	(SP),HL		;Leave, get buffer
	LD	(HL),A		;Sector
	INC	HL		;Bump
	LD	(HL),0		;Length = 128
	INC	HL		;Bump
	LD	(HL),0F7H	;Load CRC bytes
	INC	HL		;Bump
;
	CALL	SETF0		;Pre data gap
	CALL	SETF0		;Pre data sync
	LD	(HL),0FBH	;Data header
	INC	HL		;Bump
	LD	B,128		;Sector length
FILSEC	LD	(HL),0E5H	;Data
	INC	HL		;Bump
	DJNZ	FILSEC		;Go for count
	LD	(HL),0F7H	;CRC
	INC	HL		;Bump
	CALL	SETF0		;Post data gap
	DEC	C		;Less sector/cyl 0
	JR	NZ,BUILDLP	;Go for count
	CALL	SETF0		;Filler
	CALL	SETF0		;Filler
;
	POP	HL		;Remove sec table
	POP	HL		;Get I/O buffer back
	RET			;Done!
;
;       move table data into buffer
;
SETF0	LD	A,(DE)		;Get table entry
	INC	DE		;Bump
	LD	B,A		;Pass data count
	LD	A,(DE)		;Get table entry
	INC	DE		;Bump
SET01	LD	(HL),A		;Load data to buffer
	INC	HL		;Bump buffer
	DJNZ	SET01		;Go for data count
	RET			;Filled!
;
CPSER	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	B,0
	LD	DE,SECBUF
CPSER1	LD	A,(DE)
	CP	(HL)
	JR	NZ,CPSERD	;Quit on mismatch
	INC	HL
	INC	DE
	DJNZ	CPSER1
CPSERD	POP	HL
	POP	DE
	POP	BC
	RET
;
;
;       sector order table for cylinder 0
;
SECTBL	DB	0,9,18,1,10,19,2,11,20,3,12,21,4,13
	DB	22,5,14,23,6,15,24,7,16,25,8,17,26
;
;       gap table for single density
;
FMTTBL	DB	32,0FFH		;Post index gap
	DB	6,00H		;Pre ID sync
	DB	11,0FFH		;Pre data gap
	DB	6,00H		;Pre data sync
	DB	11,0FFH		;Post data gap
	DB	0,0FFH		;Filler
	DB	0,0FFH		;Filler
	DB	0,0FFH		;Filler
SYSTRK$	DB	29,'Creating BOOT track           ',03
WRTFLG	DB	0FFH		;0=skip normal read/write on trk 0
;STYP0   DB      0       ;source type
SAVSEC	DB	0
RSAV	DB	0		;Save retry counter
	ENDIF
;
