;Filter for LDOS 6.x for intnl daisy-wheel operation
;
*GET	SVCMAC
; General EQUates...
LF	EQU	10		;Linefeed character
CR	EQU	13		;Carriage return
BKSP	EQU	8		;Backspace
;
; LDOS 'SET' command handler for 6.x
;
	ORG	2600H
BEGIN	PUSH	DE		;Put DCB pointer
	POP	IX		;Into IX register
	LD	HL,SIGNON	;=>Signon message
	@@DSPLY			;Print it
	@@FLAGS			;Point IY to flag table
	BIT	3,(IY+2)	;System request?
	JP	Z,NOTSET	;Must install with SET cmd
; check if memory available
	BIT	0,(IY+2)	;HIGH$ frozen?
	JP	NZ,NOROOM	;Quit if so
	PUSH	IY
	POP	DE
	LD	HL,'I'-'A'	;Offset to IFLAG$
	ADD	HL,DE
	LD	(IFLG),HL	;Store in code
	LD	(IFLG2),HL
;Is it already in memory?
	LD	DE,FLTNAM
	@@GTMOD
	JP	Z,ISRES
; find available high memory
	LD	HL,0
	LD	B,L		;B=0
	@@HIGH$			;Find top of avaliable memory
	LD	(OLDMEM),HL	;Save in filter header
	PUSH	HL		;Save HIGH$
	LD	(DCBADD),IX	;Put DCB address in header
; relocate JP, CALL and LD addresses in filter
	LD	DE,LAST		;End of code now..
	OR	A		;Clear carry flag
	SBC	HL,DE		;Offset of move
	EX	DE,HL		;Into DE
	LD	HL,(REL1)	;Fix absolute memory
	ADD	HL,DE		;References
	LD	(REL1),HL	;In filter
	LD	HL,(REL2)
	ADD	HL,DE
	LD	(REL2),HL
	LD	HL,(REL3)
	ADD	HL,DE
	LD	(REL3),HL
	LD	HL,(REL4)
	ADD	HL,DE
	LD	(REL4),HL
; move into high memory
	LD	HL,LAST		;=>end of relocated code
	POP	DE		;Old HIGH$=destination
	LD	BC,LAST-FENTRY+1	;Length of relocated code
	LDDR			;Move it, leaving DE..
	EX	DE,HL		;=>new HIGH$
	PUSH	HL
	@@HIGH$			;Set new HIGH$
	POP	HL
	INC	HL		;Point to filter entry point
; set up new in DCB 
	LD	(IX+0),01000111B	;Filter/get/put/ctl bits
	LD	(IX+1),L	;Set new address in DCB
	LD	(IX+2),H	;For the new Device/filter
;*=*=*
	LD	HL,0		;Indicate no error
	RET
;*=*=*
;       Error handling
;*=*=*
NOROOM	LD	HL,NOROOM$
	JR	ERROUT
NOTSET	LD	HL,NTSET$
	JR	ERROUT
ISRES	LD	HL,ISRES$
ERROUT	@@LOGOT			;Display and log
	LD	HL,0FFFFH	;Indicate error
	RET
;*=*=*
;       Data area
;*=*=*
SIGNON	DB	'International Daisy Wheel printer filter.',LF
	DB	'Copyright 1983 Logical Systems, Inc.'
	DB	LF,CR
NTSET$	DB	'Must install with SET command',CR
ISRES$	DB	'Filter already loaded.',CR
NOROOM$	DB	'No memory available',CR
;
;
FLTNAM	DB	'DW',3		;Name terminated for @GTMOD
;*=*=*
;       Actual filter moved to high memory
;       LDOS style header...
;*=*=*
FENTRY	JR	START		;Branch around linkage
	DW	$-$		;Last byte used
OLDMEM	EQU	$-2		;<=previous HIGH$ value
;
	DB	2,'DW'
DCBADD	DW	$-$		;DCB using filter
SPARE	DW	0
TOGGLE	DB	0		;On/off switch
;
;*=*=*
;       Driver code
;*=*=*
START	LD	IX,(DCBADD)
REL1	EQU	$-2
	LD	A,14H		;@chnio
	JP	NZ,40H		;Go if input/ctl
;
;Check input character against tables
CKCHR	LD	HL,TABLE1-1
REL2	EQU	$-2
CKCHR1	INC	HL		;Bump to match char
	LD	A,(HL)		;Check it
	CP	C
	INC	HL		;Bump to xlate char
	JR	Z,ISCHR1	;Go if found
	OR	A		;Else test for end
	JR	NZ,CKCHR1	;Continue if not end
;HL => 2nd table
;Second table is char + two xlates
CKCHR2	LD	A,(HL)
	CP	C
	INC	HL		;Bump to 1st sub
	JR	Z,ISCHR2
	INC	HL		;2nd sub posn
	INC	HL		;Next match chr
	OR	A		;Done?
	JR	NZ,CKCHR2	;Continue if not
	LD	A,C		;No match, same chr
;
SCHR	PUSH	BC
	LD	C,A		;Character
	LD	B,2		;Output
	PUSH	HL
	PUSH	IX
	LD	HL,$-$
IFLG	EQU	$-2
	LD	A,(HL)		;Get IFLAG$
	PUSH	AF		;Save it
	RES	6,(HL)		;Turn off dvr xlates
	@@CHNIO			;Send char
	POP	AF		;Prev IFLAG$
	LD	($-$),A		; restore pr dvr state
IFLG2	EQU	$-2
	POP	IX
	POP	HL
	POP	BC
	LD	A,C		;Restore original char
	RET
;
ISCHR2	LD	A,(HL)		;Get 1st sub
	CALL	SCHR		;Print it
REL3	EQU	$-2
	LD	A,BKSP		;Then back up
	CALL	SCHR		;Printer
REL4	EQU	$-2
	INC	HL		;Get next sub char
ISCHR1	LD	A,(HL)
	JR	SCHR		;Send and return
;
; patch space for table 1:
	DB	0,0,0,0,0,0
; table 1 = match char / sub char
TABLE1	DB	0C0H,0A7H
	DB	0C1H,080H
	DB	0C2H,09CH
	DB	0C3H,0A3H
	DB	0C4H,060H
	DB	0C5H,0A5H
	DB	0C6H,0A6H
	DB	0C7H,0BEH
	DB	0C8H,0A8H
	DB	0C9H,0C0H
	DB	0CAH,0AAH
	DB	0CBH,0ABH
	DB	0CCH,0ACH
	DB	0CDH,0ADH
	DB	0CEH,0AEH
	DB	0CFH,0AFH
	DB	0D0H,0CCH
	DB	0D1H,0DBH
	DB	0D2H,0DCH
	DB	0D3H,0DDH
	DB	0D4H,0DEH
	DB	0D5H,07EH
	DB	0D6H,0FBH
	DB	0D7H,0FCH
	DB	0D8H,0FDH
	DB	0D9H,0FEH
	DB	0DAH,0A9H
	DB	0DBH,0BBH
	DB	0DCH,0BCH
	DB	0DDH,0BDH
	DB	0DEH,0BEH
	DB	0DFH,0BFH
;
	DB	0E5H,05EH
;
	DB	0F0H,041H
	DB	0F1H,061H
	DB	0F2H,041H
	DB	0F3H,061H
;
	DB	0F7H,045H
	DB	0F8H,041H
	DB	0F9H,049H
	DB	0FAH,04FH
	DB	0FBH,055H
	DB	0FCH,020H
	DB	0FDH,055H
	DB	0FEH,045H
	DB	0FFH,041H
	DB	0
;Table2: match char / sub char1 <BKSP> / sub char2
;
	DB	0E0H,061H,05EH
	DB	0E1H,065H,05EH
	DB	0E2H,069H,05EH
	DB	0E3H,06FH,05EH
	DB	0E4H,075H,05EH
;
	DB	0E6H,065H,0BEH
	DB	0E7H,069H,0BEH
	DB	0E8H,061H,0A7H
	DB	0E9H,069H,0A7H
	DB	0EAH,06FH,0A7H
	DB	0EBH,075H,0A7H
;
	DB	0EDH,06EH,07EH
	DB	0EEH,061H,07EH
	DB	0EFH,075H,07EH
;
	DB	0F4H,04FH,02FH
	DB	0F5H,06FH,02FH
	DB	0F6H,06EH,07EH
	DB	0,0,0,0,0,0,0,0,0
	DB	0
;
LAST	EQU	$-1		;Used for length calculation
;
	END	BEGIN
