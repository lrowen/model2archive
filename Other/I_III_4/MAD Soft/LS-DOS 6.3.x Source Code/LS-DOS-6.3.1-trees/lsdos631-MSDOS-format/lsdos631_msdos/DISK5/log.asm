;LOG/ASM - Optional Disk Log Program
	TITLE	<LOG - LS-DOS 6.2>
;
CR	EQU	13
LF	EQU	10
CRSON	EQU	14
;
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	COPYCOM:3		;Copyright message
;
	ORG	2600H
;
LOG
	@@CKBRKC		;Check for break
	JR	Z,LOGA		;Go if not
	LD	HL,-1		;  else abort
	RET
;
LOGA
	LD	(STACK),SP	;Save entry SP
	PUSH	HL		;Save cmdline ptr
	@@DSPLY	HELLO$		;Display the signon msg
	POP	HL		;Recover cmdline ptr
;
; Start of main module code
;
START	LD	C,0		;Default drive 0
SKIPSP	LD	A,(HL)		;Scan command line
	INC	HL
	CP	' '		;Skip spaces
	JR	Z,SKIPSP
	CP	':'		;Look for colon
	JR	NZ,DEFALT	;End of line if not found
	LD	A,(HL)		;Get drive #
	SUB	30H		;Make a number
	JP	C,ILLDRV	;# too low
	CP	7+1
	JP	NC,ILLDRV	;# too hi
	LD	C,A		;Save in C
DEFALT	LD	A,C		;Drive 0?
	AND	A
	JR	NZ,NOWAIT	;Go if not
	@@DSPLY	WAIT$		;Display "Switch disks
	JR	NZ,IOERR
	@@KEY			;Wait for a key
	JR	NZ,IOERR
	PUSH	BC		;Save the drive #
	LD	C,CR		;Output a new line
	@@DSP
	POP	BC		;Recover drive #
	JR	NZ,IOERR
	JR	NOCHK		;Can't call CKDRV if :0
;
NOWAIT	@@CKDRV			;Drive ready?
	LD	A,32		;"Illegal drive number"
	JR	NZ,IOERR	;Go if not ready
NOCHK	LD	HL,BUFFER	;Sector buffer
	LD	DE,0		;Read boot sector
	@@RDSEC
	JR	NZ,IOERR	;Go if error
	@@GTDCT			;Point IY to DCT
	INC	HL		;Point HL to byte 2
	INC	HL
	LD	A,(HL)		;Get dir cyl #
	LD	(IY+9),A	;  and put in DCT
;
	LD	D,A		;Now read GAT
	LD	HL,BUFFER	;Disk sector buffer
	LD	E,L		;Set to 0
	@@RDSEC
	CP	6		;Must be sys sector
	JR	NZ,IOERR	;Go if error
;
	LD	L,0CDH		;Offset to disk type
	LD	A,(HL)		;P/U disk type
	AND	20H		;Check # of sides bit
	LD	B,A		;Save in B
	LD	A,(IY+4)	;P/U byte in DCT
	AND	0DFH		;Mask out old value
	OR	B		;Put in new value
	LD	(IY+4),A	;Put back in DCT
;
	LD	HL,0		;Set no error
$QUIT	LD	SP,$-$		;P/u original stack
STACK	EQU	$-2
	@@CKBRKC		;Clear any break
	RET			;Back to the user
;
ILLDRV	LD	A,32		;Init "illegal drv"
IOERR	LD	L,A		;Put error # into HL
	LD	H,0
	OR	0C0H		;Abbrev, return
	LD	C,A		;Error code to C
	@@ERROR			;  for error display
	JR	$QUIT
;
HELLO$	DB	'LOG Drive'
*GET	CLIENT:3
WAIT$	DB	'Exchange disks and depress <ENTER> ',3
	ORG	$<-8+1<8
BUFFER	EQU	$
;
	END	LOG	
