;TASKER/ASM - LS-DOS 6.2
;
;	Interrupt task table, IM 1
;
CORE$	DEFL	$
	ORG	TCB$
	DW	NOTASK,NOTASK,NOTASK,NOTASK
	DW	NOTASK,NOTASK,NOTASK,NOTASK
	DW	NOTASK,NOTASK,TYPTSK$,NOTASK
	ORG	CORE$
;
;	Model IV task processor
;
RST38@
	EX	(SP),HL
	LD	(PCSAVE$),HL	;Save for TRACE
	EX	(SP),HL
	PUSH	HL		;Save HL for now
	PUSH	AF		;Save AF for now
	LD	HL,NFLAG$	;Show the system we
	SET	6,(HL)		;  are in the TASKER
	LD	HL,LBANK$	;P/U & save the current
	LD	A,(HL)		;  logical bank #
	LD	(HL),0
	PUSH	AF
	LD	HL,OPREG$	;Get current memory
	LD	A,(HL)
	PUSH	AF		;  config & save
	AND	8CH		;Strip bits 0, 1, 4-6
	OR	3		;Bring up regular 64K
	LD	(HL),A
	OUT	(@OPREG),A
INTLAT	EQU	0E0H
	IN	A,(INTLAT)	;Get interrupt latch
	CPL			;Mod IV is reverse
	LD	HL,INTIM$	;Store state of int
	LD	(HL),A
	INC	L		;Advance to int mask
	AND	(HL)		;Mask the latch bits
	JR	Z,TSTBRK	;Go if nothing interptd
NXTVCT	INC	L		;Ck on INTVC$
	RRA			;Ck if device interrupted
	JR	C,ACTVTSK
NXTMSK	INC	L		;Ck all 8 bits of mask
	OR	A		;When fin, ck overhead
	JR	NZ,NXTVCT	;  task routine
;
TSTBRK	CALL	KCK@		;Test <BREAK>, <SHIFT>
	JR	NZ,BREAK?	;Go if break
TSKEXIT	POP	AF		;Get previous mem config
	LD	(OPREG$),A	;  & restore to it
	OUT	(@OPREG),A
	POP	AF
	LD	(LBANK$),A
	LD	HL,NFLAG$	;Now leaving the TASKER
	RES	6,(HL)		; show the system
	POP	AF		;Restore previous regs
	POP	HL
	EI
RETINST	RET
;
;
;	Found active INTVC$
;
ACTVTSK	PUSH	AF		;Save the regs
	PUSH	BC
	PUSH	DE
	PUSH	HL
	PUSH	IX
	LD	DE,POPREGS	;Stack return vector
	PUSH	DE
	LD	E,(HL)		;P/u INTVC pointer vector
	INC	L
	LD	D,(HL)
	EX	DE,HL		;Shift it to HL
	JP	(HL)		;Go to service routine
;
;	Register restoral after service routine
;
POPREGS	POP	IX
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	JR	NXTMSK		;Loop to next mask bit
;
;	BREAK key detected
;
BREAK?	JR	NC,GOTBRK	;Go if <BREAK> only
	PUSH	BC		;Was <SHIFT-BREAK>
	DI
	CALL	TAPDRV		;Reselect drive
	POP	BC
	JR	TSKEXIT
;
;	BREAK during tasking - enter DEBUG? - user BREAK?
;
GOTBRK	LD	A,(SFLAG$)	;Check if BREAK key is
	AND	10H		;  disabled to inhibit
	JR	NZ,TSKEXIT	;  DEBUG or BREAK vector
	LD	HL,@DBGHK	;Merge DEBUG flag &
	OR	(HL)		;  hook (X'00' or X'C9')
	LD	(HL),0C9H	;Turn off DEBUG
	INC	HL		;Point to @DEBUG vector &
	JR	Z,EXITBRK	;  go if DEBUG is active
;
	LD	A,(PCSAVE$+1)	;Don't allow vectored break
	CP	MAXCOR$<-8	; if old PC is in SYSRES
	JR	C,TSKEXIT
	LD	HL,HIGH$+1	; or if old PC is
	CP	(HL)		; above HIGH$
	JR	NC,TSKEXIT
	LD	HL,0		;  else ck if BREAK is
BRKVEC$	EQU	$-2
	LD	A,H		;  to be trapped by user
	OR	L
	JR	Z,TSKEXIT
EXITBRK	POP	AF		;Discard old mem config
	POP	AF		;Restore reg AF
	POP	AF
	EX	(SP),HL		;P/u HL & stack vector
	EI
	RET			;To DEBUG or BREAK vector
;
;	Real Time Clock interrupt processor
;
RTCPROC	EQU	$
	IN	A,(0ECH)	;Clear the RTC interrupt
	LD	A,11		;Task 11 executes every
	CALL	RTCTASK		;  RTC interrupt
	LD	HL,TIMSL$
	RLC	(HL)		;Ck on time slice
	RET	NC		;Ignore if nothing
	LD	DE,TIMTSK$	;  on this interrupt
	PUSH	DE		;  else init for clocker
	LD	A,8		;Task 8 at INT/2 if fast
	CALL	RTCTASK
	LD	A,9		;Task 9 at INT/2 if fast
	CALL	RTCTASK
	LD	A,10		;Task 10 at INT/2 if fast
	CALL	RTCTASK
	LD	HL,TIMER$	;Bump the timer at INT/2
	INC	(HL)
	LD	A,(HL)		;P/u the heart beat
	AND	7		;For this interrupt,
RTCTASK	RLCA			;  consider 0-7 only
	ADD	A,TCB$&0FFH	;Add offset to table
	LD	L,A
	LD	H,TCB$<-8
	LD	(@RPTSK+1),HL
	LD	E,(HL)		;P/u task vector addr
	INC	L
	LD	D,(HL)
	PUSH	DE
	POP	IX		;Also to IX
	EX	DE,HL
	LD	E,(HL)		;P/u task entry point
	INC	HL
	LD	D,(HL)
	EX	DE,HL
	JP	(HL)		;Go to task
;
@KLTSK	POP	DE		;Remove ret
	LD	A,(@RPTSK+1)	;Pt to task tbl entry
	SUB	TCB$&0FFH
	RRCA			;  of last task
;
@RMTSK	LD	DE,NOTASK	;Remove entry
;
@ADTSK	CP	12		;Too large a task?
	RET	NC		;Ret if too big else
	RLCA			;  add to task table
	ADD	A,TCB$&0FFH	;Add the offset
	LD	L,A		;Estab ptr to vector
	LD	H,TCB$<-8
CHGTASK	DI
	LD	(HL),E		;Vector adr to ptr tbl
	INC	L
	LD	(HL),D
	EI
	RET
;
NOTASK	DW	$-1		;Current task vector
;
@RPTSK	LD	HL,0		;P/u last task done
	LD	E,(HL)		;P/u task vector addr
	INC	HL
	LD	D,(HL)
	EX	DE,HL
	POP	DE		;Pop ret addr
	JR	CHGTASK
;
;	Routine to check if task slot active
;
@CKTSK	RLCA			;Task number * 2
	ADD	A,TCB$&0FFH+1	;Index into task table
	LD	L,A
	LD	H,TCB$<-8
	LD	A,NOTASK<-8	;Check match of high
	CP	(HL)		;  order only
	RET			; Z or NZ result
