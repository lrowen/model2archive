;SOUND2/ASM : Includes - Sound, Puase, Dechex - 12/14/83
;
;	revised 09/28/83 for Mod II	- kjw
;
*MOD
SNDPORT	EQU	0A0H		;sound port
SNDON	EQU	0FFH		;sound ON
SNDOFF	EQU	000H		;sound OFF
	ORG	STACK$
	DW	00		;Stack gaurd
;*=*=*
;	Pause routine
;*=*=*
@PAUSE	PUSH	BC		;Save the count
	LD	A,(SFLAG$)	;If system (FAST)
	BIT	3,A		; then double it
	CALL	CDLOOP		;Call if fast
	POP	BC		;Restore the count
CDLOOP	DEC	BC		;Count down routine
	LD	A,B
	OR	C
	JR	NZ,CDLOOP
	RET
;*=*=*
;	@SOUND SVC-104 - Operates sound generator
;	B => sound function
;	bits 0-2 <0-7> = note # (0 highest)
;	bits 3-7 <0-31> = relative sound duration
;	All regs except A left unchanged
;	Z-flag set on exit
;*=*=*
@SOUND	PUSH	BC		;Save registers
	PUSH	HL
;
;	locate available time slot
;
SOUND1	LD	A,11		;max slot #
	CALL	@CKTSK		;check if available
	JR	NZ,SOUND3	;no slots available!
;
;	have slot # in C register to use
;
SOUND2	LD	A,B		;get user input
	RRCA			;align duration
	RRCA
	RRCA
	AND	00011111B	;significant bits
	INC	A		;force non-zero
	LD	($SOTASK+2),A	;setup data
	LD	DE,$SOTASK	;sound task
	LD	A,11		;slot #
	CALL	@ADTSK		;add the task
;
SOUND3	POP	HL		;restore stack
	POP	BC
	XOR	A		;set no error
	RET			;return OK
;
;	sound interrupt processor
;
$SOTASK	DW	SOTASK		;task address
	DB	0		;counter
SOTASK	LD	A,SNDON		;sound ON data
	OUT	(SNDPORT),A	;issue a 'beep'
	DEC	(IX+2)		;less count
	RET	NZ		;go if not done
	LD	A,SNDOFF	;sound OFF data
	OUT	(SNDPORT),A	;turn off 'beep'
	JP	@KLTSK		;else remove itself
;*****
;	process decimal assignment
;*****
@DECHEX	LD	BC,0		;init value to zero
DEC1	LD	A,(HL)		;p/u a char
	SUB	30H		;cvrt to binary
	RET	C		;return if < "0"
	CP	10		;ck for bad decimal
	RET	NC		;ret if not 0-9
	PUSH	BC		;exchange BC & HL
	EX	(SP),HL		;& save HL on stack
	ADD	HL,HL		;multiply by 10
	ADD	HL,HL
	ADD	HL,BC
	ADD	HL,HL
	LD	B,0		;merge in new digit
	LD	C,A		;new digit to C
	ADD	HL,BC		;& add it in
	LD	B,H		;current value to BC
	LD	C,L
	POP	HL		;recover HL pointer
	INC	HL
	JR	DEC1		;loop
;******
; 	End of special low modules
;******
