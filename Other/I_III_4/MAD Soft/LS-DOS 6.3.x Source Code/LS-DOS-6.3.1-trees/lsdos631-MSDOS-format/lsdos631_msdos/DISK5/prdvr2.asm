;PRDVR2/ASM  -  VERSION 6.2  - 10/20/83
*MOD
;*=*=*
;       PR driver entry point
;       Driver is 100% transparent to characters.
;       It passes X'00'-X'FF'
;       Unless INTL version..06/06/83
;*=*=*
PRDVR	JR	PRBGN		;Branch around linkage
	DW	PREND		;Last byte used
	DB	3,'$PR'
	DW	PRDCB$		;Pointer to its DCB
	DW	0		;Reserved
;*=*=*
;       Driver code
;*=*=*
PRBGN	JR	Z,$?2		;Go if output
	JR	C,$?1		;Go if input req
;*=*=*
;       Character CTL request
;*=*=*
	LD	A,C		;Check for @CTL-0
	OR	A
	JR	Z,$?4		;Go get status if CTL-0
;*=*=*
;       Character GET request
;*=*=*
$?1	OR	0FFH		;Set nz
	CPL			; & A=0
	RET
;*=*=*
;       Character PUT request
;*=*=*
$?2	LD	DE,2000		;Check status 2000 times
$?2A	CALL	$?4		;PR ready?
	JR	Z,$?3		;Go if so
;*=*=*
;       Ten second timout delay loop
;*=*=*
	PUSH	BC		;  in the alloted time
	LD	BC,340
	CALL	PAUSE@
	POP	BC
	DEC	DE		;Time up?
	LD	A,D
	OR	E
	JR	NZ,$?2A		;Nope, continue check
	LD	A,8		;Device not avail...
	OR	A
	RET
$?3	EQU	$
	IF	@INTL
	LD	A,(IFLAG$)
	BIT	6,A		;special DMP PR?
	ENDIF
	LD	A,C
	IF	@INTL
	JR	Z,PVAL3
	CP	0C0H		;Values C0-FF (-20H)
	JR	C,PVAL2		;Go if less
	SUB	20H		;Shift to European chars
	JR	PVAL3
PVAL2	CP	0A0H		;A0-BF (+40H)
	JR	C,PVAL3		;Go if less
	ADD	A,40H		;Shift to graphics
	ENDIF
PVAL3	OUT	($PIOO),A	;Put out char
	IF	@INTL
	LD	A,C		;Restore original
	CP	A		;Set Z
	ENDIF
	RET
;
$?4	IN	A,($PIOI)	;Scan PR status
	AND	0F0H		;Mask unused positions
	RET			;Return with answer
PREND	EQU	$-1
