;TAPE100A/ASM - Tape I/O routines
;	CASSON - Turn Cassette Motor On
;
CASSON	DI			;Disable interrupts
	CALL	SWAP38		;Grab RST 38H vector
	IN	A,(PORTE0)	;Clear any latches
	IN	A,(MODOUT)	;Clear any latches
	LD	A,2		;Motor on, slow speed
	OUT	(MODOUT),A	;Turn on motor
	LD	A,3		;Disable other interrupts
	OUT	(PORTE0),A
	RET
;
;	CASSOFF - Turn off Cassette Motor
;
CASSOFF	LD	A,(IY+WRMASK)	;P/u original
	OUT	(PORTE0),A	;Set up R/F interrupt
	IN	A,(PORTFF)	;Clear 1500 bd interrupts
	LD	A,(IY+MODMASK)	;Turn off motor
	OUT	(MODOUT),A
	CALL	SWAP38		;Restore RST 38H vector
	RET
;
;	PRTAPE - Prompt for "Tape Ready" & turn motor on
;
PRTAPE	LD	HL,TREADY	;"Ready cassette & <ENTER>
	CALL	DSPLY
NOTENT	LD	B,1		;Just 1 char
	CALL	INPUT		;<BREAK> or <ENTER>
	JP	CURSOFF		;Turn off Cursor & RETurn
;
;	RDDAT - Read in a tape file
;
RDDAT	LD	HL,MEM-100H	;HL => Start of file
RDDAT2	INC	H		;Bump hi-byte
	CALL	RDDATA		;Read a block
	RET	Z		;Eof ?
EOTF	LD	A,$-$		;At top of memory ?
	CP	H
	JR	NZ,RDDAT2	;No
	OR	A		;Top of mem - 
	RET			;RETurn NZ
;
;	RDDATA - Read in a block of Data
;	HL => Destination of Block
;
RDDATA	CALL	RDSYNC		;Read sync field
	CALL	RDBYTE		;Read a byte
	CP	8DH		;Legal ?
	JP	NZ,ILLEGAL	;No - bad news
	LD	DE,0		;D=EOF flag, E = checksum
;
RDLP1	CALL	RDBYTE		;Read a byte
	LD	(HL),A		;Stuff into buffer
;
;	Check for End of File byte X'1A'
;
	CP	1AH		;Eof ?
	JR	NZ,AFTER	;No
	CP	D		;Been here before ?
	JR	Z,AFTER		;First time ?
	LD	D,A		;Set D = 1AH
	LD	B,L		;Yes - set B = pos
;
;	Add byte to checksum
;
AFTER	ADD	A,E		;Add checksum
	LD	E,A		;Xfer back to E
	INC	L		;Bump
	JR	NZ,RDLP1
	NEG			;Negate checksum
	LD	E,A		;Stuff back in E
;
;	Verify Checksum byte
;
	CALL	RDBYTE		;Read in byte
	CP	E		;Checksums match ?
	CALL	NZ,CHKERR	;No - checksum error
;
;	Stuff EOF offset byte into WRTDEST routine
;
	LD	A,H		;P/u eom
	LD	(EOTF2+1),A	;Stuff into WRTDEST
	LD	A,B		;P/u byte
	INC	A		;Bump
	LD	(OFFSET+1),A
;
;	Read past 20 dummy zeroes
;
	LD	B,20
RDLP2	CALL	RDBYTE
	DJNZ	RDLP2
;
;	Set Z flag if at EOF
;
	LD	A,D		;Eof ?
	CP	1AH
	RET			;Done
;
;	RDBIT - Read a Bit from Cassette
;
RDBIT	LD	C,0		;Init count = 0
	EI			;Back on
RBLP	INC	C		;Bump count
	LD	A,(BREAKLC)	;<BREAK> hit ?
	AND	4
	JR	Z,RBLP		;No - wait for interrupt
;
;	<BREAK> key hit - Abort
;
	DI			;Cancel next interrupt
	CALL	DISDOKI		;Put *DO & *KI back
	CALL	CASSOFF		;Turn off cassette
	LD	C,CR		;End line
	CALL	DSP
	JP	ABORT		;Go to abort routine
;
;	Interrupt Handler - Comes from RST 38
;
RST38V	JP	$+3		;Wait
	PUSH	AF		;Save status
	IN	A,(PORTE0)	;Read port
	RRA			;Bit 0 low ?
	JP	NC,BIT0LOW
	RRA			;Bit 1 low ?
	JP	NC,BIT1LOW
	POP	AF		;Recover status
	EI			;Back on
	RET			;RETurn
;
;	Set E = bit image - bit 0 or 1
;
BIT0LOW	LD	E,1		;High
	JR	BIT1LOW+2	;Add interrupt offset
BIT1LOW	LD	E,0		;Low
	LD	A,ROUTOFF	;Add interrupt routine
	ADD	A,C		;Offset to C
	LD	C,A
;
;	Is the Head on a valid pulse ?
;
	IN	A,(PORTFF)	;Read cassette level
	AND	1		;Mask off all but bit 0
	CP	E		;Same as given level ?
	JR	NZ,WAITINT	;No - wait for next inter
;
;	Valid pulse - Get out of interrupt routine
;
	POP	AF		;Remove RST 38 RET addr
	POP	AF
	RET
;
;	Not the right interrupt - wait for next
;
WAITINT	POP	AF		;Recover status
	EI			;  and wait for next
	RET			;  interrupt
;
;	RDHEAD - Read a TAPE100 header
;
RDHEAD	LD	HL,(CURPOS)	;P/u cursor position
	LD	DE,BUFFER	;Buffer
	CALL	RDSYNC		;Read in SYNC
;
;	Read in Header Type byte
;
	CALL	RDBYTE		;Read type byte
	CP	9CH		;Text type ?
	JR	NZ,RDHEAD	;No - try again
;
	LD	BC,600H		;B=6 bytes, Checksum = 0
;
RFNLP	CALL	RDBYTEC		;Read byte
	LD	(HL),A		;Save byte
	LD	(DE),A		;Stuff in buffer
	INC	HL		;Bump cursor pos
	INC	DE		;Bump buffer ptr
	DJNZ	RFNLP
;
;	Next ten bytes are unused
;
	LD	B,10
BOGUSLP	CALL	RDBYTEC		;Read byte & checksum
	DJNZ	BOGUSLP
;
;	Negate checksum
;
	LD	A,C		;P/u checksum
	NEG			;Negate it
	LD	C,A
	CALL	RDBYTE		;Read in Checksum byte
	CP	C		;Match ?
	CALL	NZ,CHKERR	;No - checksum error
;
;	Read in twenty zeros
;
	LD	B,20
DUMBYT	CALL	RDBYTE
	DJNZ	DUMBYT
;
;	Check if this is the correct filename
;
CORRECT	NOP			;X'C9' if first filename
	LD	DE,BUFFER	;Is this the one ?
	LD	HL,FILENM
	LD	B,6		;6 chars in filename
;
;	Loop to compare (HL) to (DE)
;
CKFILE	LD	A,(DE)		;P/u header byte
	CALL	CONV_UC		;Convert to U/C
	CP	(HL)		;Match ?
	INC	HL
	INC	DE
	JP	NZ,RDHEAD	;No - try again
	DJNZ	CKFILE
	RET			;Yes - RETurn
;
;	Checksum error - Either ignore it or "C"
;
CHKERR	NOP			;RETurn or NOP
	DI			;Disable interrupts
	LD	A,'C'		;<C>hecksum error
CHKERR2	LD	(VIDEO+79),A
	CALL	DISDOKI		;Bring back RAM
	CALL	CASSOFF		;Turn off motor
	LD	HL,READERR	;"Tape Read Error!"
	CALL	DSPLY
	JP	ABORT		;Good bye
;
;	RDSYNC - Read Cassette SYNC byte field
;
;	Save Registers
;
RDSYNC	PUSH	HL		;Save regs
	PUSH	DE
	PUSH	BC
	LD	A,1		;Set interrupt vector
	OUT	(PORTE0),A
;
;	Read in 128 bits (16 bytes) initially
;
RDSYNC2	LD	B,80H		;Read 128 bits (16 bytes)
RBTLP	CALL	RDBIT		;Read bit
	LD	A,C		;P/u count value
	CP	TOOSHRT		;Is this a bit ?
	JR	C,RDSYNC2	;No - didn't find a bit
	CP	TOOLONG		;Is this a bit ?
	JR	NC,RDSYNC2	;No - wait for bit
	DJNZ	RBTLP		;Legal bit - dec count
;
;	Now check parity of next 128 bits
;
RESCNT	LD	HL,0		;H = 0's count, L = 1's
	LD	B,40H
;
;	Read in 3 bits
;
LOOP	CALL	RDBIT		;Read bit
	CALL	RDBIT		;Read bit
	LD	D,C		;Save count
	CALL	RDBIT		;Read bit
;
;	Calculate Difference between last 2 bits
;
	LD	A,D		;P/u last bit
	SUB	C		;Subtract current bit
	JR	NC,ABSVAL
	NEG			;Change to ABS value
;
;	If Value < DIFFER then Bit = 1, else Bit = 0
;
ABSVAL	CP	DIFFER		;Bit = 1 ?
	JR	C,BIT1		;Yes - bump Bit 1 count
	INC	H		;No - bump Bit 0 count
	JR	DODJ		;Back to loop
BIT1	INC	L		;Bump Bit 1 count
DODJ	DJNZ	LOOP		;Dec count - go to loop
;
;	Check if H (0's count) & L (1's count) = 40
;
	LD	A,40H		;Is H = 64 ?
	CP	H
	JR	Z,CHKMARK	;Yes - check for marker
	CP	L		;Is L = 64 ?
	JR	NZ,RESCNT	;No - Reset count
;
;	Set interrupt Vector & discard 1 bit
;
	LD	A,2		;Set interrupt vector
	OUT	(PORTE0),A
	CALL	RDBIT		;Read bit
;
;	Rotate each bit read in D & check if = X'7F'
;
CHKMARK	LD	D,0		;Set byte = 0
GETBIT	CALL	RDBIT		;Read next bit
	CALL	ROTBYTE		;Rotate into Byte (D)
	LD	A,D		;P/u byte
	CP	7FH		;Marker byte ?
	JR	NZ,GETBIT	;No - get another bit
;
;	Found marker byte - Restore Regs & RETurn
;
	POP	BC		;Restore Registers
	POP	DE
	POP	HL
	RET			;Done
;
;	ROTBYTE - Rotate bit through D & check if error
;
ROTBYTE	LD	A,C		;P/u count
	CP	WHICH1		;Bit = 0 or 1 ?
	RL	D		;Set bit if Carry set
	CP	TOOSHRT		;Too quick ?
	JP	C,CIOERR	;Yes - I/O Error
	CP	TOOLONG		;Too long
	RET	C		;No - RETurn
;
;	Cassette I/O Error - Display Error
;
CIOERR	DI			;Interrupts off
	LD	A,'D'		;Data Error
	JP	CHKERR2
;
;	RDBYTEC - Read byte & Add byte to Check Sum
;
RDBYTEC	CALL	RDBYTE		;Read byte
	ADD	A,C		;Add to checksum
	RET			;Done
;
;	RDBYTE - Read a byte
;	A <= Byte
;
RDBYTE:	PUSH	DE		;Save regs
	PUSH	BC
	CALL	RDBIT		;Get bogus bit
	LD	D,0		;Init byte = 0
	LD	B,8		;8 bits to read
;
RDBLP	CALL	RDBIT		;Read a bit
	CALL	ROTBYTE		;Rotate into D
	DJNZ	RDBLP
;
;	Add to Byte count
;
	LD	A,(COUNT)	;P/u count
	INC	A		;  & inc it
	AND	3FH		;Ck if the 64th
	LD	(COUNT),A	;Save the count
	JR	NZ,NOTBLNK
;
	LD	A,(VIDEO+79)	;Blink every 64
	XOR	0AH
	LD	(VIDEO+79),A
;
NOTBLNK	LD	A,D		;Xfer byte to A
	JR	NEXTINS		;Timing
;
NEXTINS	POP	BC		;Restore BC & DE
	POP	DE
	RET			;Done
;
;	WRBIT - Write a bit to Cassette
;
;	Set DE = Delay Count for bit
;
WRBIT	RLC	C		;Get bit
	JR	NC,NOPULS	;NC - bit 0
BT1	LD	DE,DELAY1	;Delay for bit 1
	JR	DEL_LP		;Go to delay
NOPULS	LD	DE,DELAY0	;Delay for bit=0
;
;	Delay 18 counts for 1, 43 counts for 0
;
DEL_LP	DEC	D		;Dec count
	JR	NZ,DEL_LP
	LD	A,2		;0 Volts to tape
	OUT	(PORTFF),A
DEL_LP2	DEC	E		;Secondary delay
	JR	NZ,DEL_LP2
	LD	A,1		;0.85 volts to tape
	OUT	(PORTFF),A
	RET			;Done
;
;	WRHEAD - Write a cassette header
;
WRHEAD	CALL	WRSYNC		;Write SYNC pattern
;
;	Write Text header type byte X'9C'
;
	LD	D,0		;Init checksum = 0
	LD	C,9CH		;Text header type byte
	CALL	WRBYTE		;Write type byte
;
;	Write Filename in header block
;
	LD	B,6		;B = 6 chars
	LD	HL,FILENM	;HL => Filename
FILELP	LD	C,(HL)		;P/u filename character
	CALL	WRBYTEC		;  and write it
	INC	HL		;Bump count
	DJNZ	FILELP
;
;	Write 10 filler bytes
;
	LD	B,10
BOGUS	CALL	WRBYTEC
	DJNZ	BOGUS
;
;	Write checksum byte & 20 dummy X'00' bytes
;
	LD	A,D		;P/u checksum
	NEG
	LD	C,A		;  & xfer to C
	CALL	WRBYTE		;Write Checksum byte
	LD	BC,1400H	;B = 20 bytes, C = 0
DUMMY	CALL	WRBYTE		;Write byte
	DJNZ	DUMMY
	RET			;Get back quick
;
;	WRDAT - Write a chunk of data to cassette
;
WRDAT	LD	HL,MEM		;HL => Mem start
WRDAT2	CALL	WRDATA		;Write Block
	INC	H
	LD	A,(FCB1+4)	;Finished ?
	CP	H
	JR	NZ,WRDAT2	;No - write another
	RET			;Yes - RETurn
;
;	WRDATA - Write a data Block
;	HL => 256 byte block of data (page boundary)
;
WRDATA	CALL	WRSYNC		;Write sync pattern
	LD	C,8DH		;Write X'8D' type byte
	CALL	WRBYTE
;
;	Write 256 byte block of data
;
	XOR	A		;Set checksum = 0
WBLP	LD	C,(HL)		;P/u byte
	ADD	A,C		;Add checksum
	PUSH	AF		;Save A
	CALL	WRBYTE		;Write byte
	POP	AF		;Recover checksum
	INC	L		;Bump count
	JR	NZ,WBLP
;
;	Write checksum byte
;
	NEG			;Negate checksum
	LD	C,A		;Write checksum byte
	CALL	WRBYTE
;
;	Write 20 dummy bytes - X'00'
;
	LD	B,20		;Write 20 dummy zeroes
WDLP	LD	C,0
	CALL	WRBYTE
	DJNZ	WDLP
	RET			;Done
;
;	WRBYTEC - Write a byte & add checksum
;
WRBYTEC	CALL	WRBYTE		;Write byte
	LD	A,C		;P/u byte
	ADD	A,D		;Add checksum
	LD	D,A		;New checksum
	RET			;And RETurn
;
;	WRBYTE - Write a byte to Cassette
;	C => Byte to Output
;
WRBYTE:	PUSH	BC		;Save regs
	PUSH	DE
	CALL	NOPULS		;Write dummy pulse
	LD	B,8		;8 bits to write
WRBTLP	CALL	WRBIT		;Write bit
	DJNZ	WRBTLP
	POP	DE		;Restore regs
	POP	BC
	RET
;
;	WRSYNC - Write a SYNC pattern to Cassette
;
WRSYNC	DI			;Disable interrupts
	PUSH	BC		;Save BC
	LD	B,80H		;Delay
	@@PAUSE
	LD	BC,0055H	;B = 256, C = X'55'
;
;	Write SYNC bytes - X'55'
;
WR55LP	CALL	WRBYTE8		;Write 8 bit byte
	DJNZ	WR55LP
;
;	Write Marker byte - X'7F'
;
	LD	C,7FH		;Write marker byte X'7F'
	CALL	WRBYTE8
	POP	BC		;Recover BC
	RET			;Done
;
WRBYTE8	PUSH	BC		;Save B
	LD	B,8		;8 bits long
WB8LP	CALL	WRBIT		;Write bit
	DJNZ	WB8LP
	POP	BC
	RET
