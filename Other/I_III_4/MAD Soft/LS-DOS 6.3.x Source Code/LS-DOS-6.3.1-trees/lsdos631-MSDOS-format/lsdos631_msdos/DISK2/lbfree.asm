;LBFREE/ASM - FREE Command
	TITLE	<FREE - LS-DOS 6.2>
;
TPL	EQU	8		;Tracks per Line = 8
@DSP	EQU	2		;@DSP SVC #
@PRT	EQU	6		;@PRT SVC #
@DSPLY	EQU	10		;@DSPLY SVC #
@PRINT	EQU	14		;@PRINT SVC #
@KEY	EQU	1		;@KEY SVC #
;
*GET	BUILDVER/ASM:3
*GET	SVCMAC:3		;SVC Macro equivalents
*GET	VALUES:3		;Misc. equates
;
	ORG	2400H
;
FREEMAP	EQU	$
	IF	@BLD631
	LD	(SAVESP+1),SP	;<631>Save SP address for exit
	@@CKBRKC		;<631>See if break down
	SCF			;<631>
	JR	NZ,ABORT1	;<631>Abort

	CALL	FREE		;<631>Show Free Space
EXIT:	XOR	A		;<631>Clear Cflag

ABORT1:	SBC	HL,HL		;<631>Depending on Cflag, exit 0000 or FFFF
SAVESP:	LD	SP,$-$		;<631>P/u old SP address
	@@CKBRKC		;<631>Clear <BREAK>
	RET			;<631>
	ELSE
;
	@@CKBRKC		;See if break down
	JR	Z,BEGINA	;Ok if not,
	LD	HL,-1		;  else abort
	RET
;
;	<BREAK> not hit - execute module
;
BEGINA
	LD	(SAVESP+1),SP	;Save SP address for exit
	CALL	FREE		;Show Free Space
;
;	Finished - Clear out <BREAK> & return
;
EXIT	LD	HL,0		;HL = 0 (normal exit)
SAVESP	LD	SP,$-$		;P/u old SP address
	@@CKBRKC		;Clear <BREAK>
	RET
	ENDIF
;
;	Error Handler - Display message & Abort
;
IOERR	LD	L,A		;Set HL = Error #
	LD	H,0
	OR	0C0H		;Short error - & RETurn
	LD	C,A		;Stuff error # in C
	@@ERROR			;Display error
	JR	SAVESP		;Exit
;
;	FREE - Display Free Disk Space
;
FREE
	@@FLAGS			;IY => System Flags
;
;	Stuff Address of SFLAG$ into routine
;
	LD	DE,SFLAG$	;DE => Offset to SFLAG$
	ADD	IY,DE		;IY => SFLAG$
	LD	(SFLAG1+1),IY	;Save for later test
;
;	Position to parameters or end of line
;
	PUSH	HL		;Save command ptr
SKPLP	LD	A,(HL)		;P/u char
	CP	'('		;Parameter(s) ?
	JR	Z,GETPRMS	;Yes - get parameters
	CP	CR		;End of line ?
	JR	Z,GETHL		;Recover command ptr
	INC	HL		;Bump ptr
	JR	SKPLP		;No - go til terminator
;
;	Process any parameters if entered
;
GETPRMS	LD	DE,PRMTBL$	;DE => Parameter table
	@@PARAM			;@PARAM
GETHL	POP	HL		;Recover cmdline ptr
	JP	NZ,IOERR	;NZ - parameter error
;
;	Anything after FREE command entered ?
;
	LD	A,(HL)		;P/u first character
	CP	'('+1		;End of line ?
	JR	C,FREE0		;Display lines
;
;	P/u next character if character is a colon
;
	CP	':'		;Drivspec ?
	JR	NZ,CKIFDRV	;No - check if numeric
	INC	HL		;Yes - p/u next char
	LD	A,(HL)
;
;	Convert drive # to binary (if legal) & save
;
CKIFDRV	SUB	'0'		;Legal drive Number ?
	IF	@BLD631
	ELSE
	JR	C,ILDRNUM	;No - illegal drive #
	ENDIF
	CP	7+1
	JR	C,MAP		;Less than 8 - good
;
;	Illegal Drive Number - display & Abort
;
ILDRNUM	LD	A,32		;"Illegal Drive Number"
	JP	IOERR		;Display & Abort
;
;	Output a C/R to *PR if output is to *PR
;
FREE0	LD	HL,(PPARM+1)	;P/u P parm
	INC	L		;Specified ?
	JR	NZ,FREE0A	;No - don't PRINT
	LD	C,' '		;Output space
	CALL	PRT		;  to printer
	LD	C,CR		;Output C/R
	CALL	PRT		;  to printer
FREE0A	LD	C,0		;Init drive # to 0
;
;	Is there a disk in the drive ?
;
FREE1	PUSH	BC		;Save drive #
	@@GTDCT			;IY => DCT
	LD	A,(IY)		;Drive on line ?
	CP	0C3H
	JR	NZ,NXTDRV	;No - get next drive
	@@CKDRV			;Disk in drive ?
;
;	Check if the <BREAK> was hit
;
	PUSH	AF		;Save @CKDRV condition
	CALL	CKBREAK		;Check <BREAK>
	POP	AF		;Recover @CKDRV cond
;
;	Display <No Disk> if @CKDRV fails
;
	JR	Z,DOINF		;Disk in - use header
	CALL	NO_DISK		;No - display <No Disk>
	JR	NXTDRV		;Get next drive
;
;	Create Header String & display if successful
;
DOINF	CALL	GETINFO		;Display Header string
;
;	Get next drive number
;
NXTDRV	POP	BC		;C = Drive #
	INC	C		;Inc it
	BIT	3,C		;Finished ?
	JR	Z,FREE1		;No - get next drive
	RET			;Finished - RETurn
;
;	MAP - Display Free Space Map
;
;	Log in diskette if possible
;
MAP	LD	C,A		;Xfer drive # to C
	@@GTDCT			;IY => DCT + 0
	LD	A,(IY)		;P/u enable/disable
	CP	0C3H		;Drive enabled ?
	JP	NZ,ILDRNUM	;No - Illegal Drive #
	@@CKDRV			;Disk in drive ?
	JR	Z,DISKIN	;Good - Disk in Drive
;
;	No Disk in Drive - Display message & Abort
;
	CALL	NO_DISK		;Display <No Disk>
	JP	EXIT		;Go to exit routine
;
;	Create header/footer strings & output header
;
DISKIN	CALL	CKBREAK		;Check for <BREAK>
	CALL	GETINFO		;Get GAT, create header
	CALL	DISPUND		;Display underline
	CALL	CLRLN		;Clear Line buffer
;
;	Transfer "  0-  7" string to line buffer
;
	LD	HL,MTRK		;Initial track #s
	LD	DE,LINBUF
	LD	BC,7		;Len track # display
	LDIR
;
;	Pt HL => GAT+0, C = cylinder -1 (gets INCed)
;
	LD	HL,GAT		;Pt to stored GAT
	DEC	C		;Init Cyl = -1
;
;	Loop to Display each line of Cylinders
;
NEXTLIN	LD	B,TPL		;Max track per line count
	LD	IX,LINBUF+8	;Pt to display buffer
;
;	Bump cylinder number & display Gran info
;
DSPSC	INC	C		;Current cylinder
	CALL	DFRE		;Display Free grans
	INC	HL		;Pt to next track
;
;	Finished Displaying all the cylinders ?
;
	LD	A,(IY+6)	;P/u max cylinder
	CP	C		;Finished ?
	JR	Z,ENDRET	;Yes - display footer
;
;	Calculate offset (9-Grans/cyl) to next track
;
	LD	A,(GRANS+1)	;P/u Grans/Cyl
	NEG
	ADD	A,TPL+1		;A = offset to next
;
;	Add offset to Line buffer pointer (IX)
;
	LD	D,0		;Stuff in DE
	LD	E,A
	ADD	IX,DE		;Where to dsp next track
	DJNZ	DSPSC		;Loop current 6 trks
;
;	Finished 8 cylinders - display line
;
	PUSH	HL		;Save buffer loc'n
	PUSH	BC		;Save current cyl
	CALL	DSPLINE		;Display current line
;
;	Clear granule display line buffer
;
	CALL	CLRLN		;Clear Line buffer
	POP	BC		;Recover cylinder # in C
;
;	Change cylinder numbers in line buffer
;
	CALL	DSPTRK		;Calc new track #'s
	POP	HL		;Restore GAT pointer
	JR	NEXTLIN		;Get next line
;
;	Finished with drive - Display current line
;
ENDRET	CALL	DSPLINE		;Display tracks in buffer
	CALL	DISPUND		;Display underline
;
;	Display Footer Message
;
	LD	HL,FOOTER	;HL => Footer Message
	CALL	DSPMSG		;Display footer string
;
;	If footer will cause a scroll - wait for key
;
	LD	A,(CKPAGE+1)	;P/u # of lines left
	CP	2		;At least 2 lines left?
	JR	NC,FRET		;Lprint, free to return
	CALL	KEY		;Wait for char
FRET	LD	(HL),CR		;Scroll
	CALL	DSPMSG		;Display line
	JP	EXIT		;Go to normal exit
;
;	Stuff Drive Number into String Header
;
GETINFO	LD	A,C		;P/u drive #
	ADD	A,'0'		;Convert to ASCII
	LD	(HDRIVE),A	;Stuff into header string
;
;	Read in the diskette's GAT
;
	@@GTDCT			;IY => DCT+0
	LD	D,(IY+9)	;P/u Directory cylinder
	LD	E,0		;Sector Zero
	LD	HL,GAT		;HL => GAT I/O buffer
	@@RDSSC			;Read System Sector
	LD	A,14H		;Init to "GAT Read Error"
DERR	JP	NZ,IOERR	;Jump on GAT read error
	CALL	CKBREAK		;Check for <BREAK>
;
;	Read in the diskette's HIT
;
	INC	E		;Sector 1
	INC	H		;HL => HIT I/O buffer
	@@RDSSC			;Read System Sector
	LD	A,16H		;Init to "HIT Read Error"
	JR	NZ,DERR		;Go to Error handler
	CALL	CKBREAK		;Check for <BREAK>
;
;	Pick up quantity of Sectors/Granule
;
	LD	A,(IY+8)	;Bits 4-0 contain #
	AND	1FH		;  of Sectors/Granule.
	INC	A		;Adjust for zero offset
;
;	Convert Sectors/Gran to K & stuff in string
;
	PUSH	AF		;Save Sectors/Granule
	LD	HL,0		;Set HLA = # Sec/Gran
	LD	DE,FGRAN	;DE => Destination
	LD	BC,CVT2D	;Only 2 digits possible
	CALL	CALCK2		;Convert to K
	POP	AF		;A = Sectors/Granule
	LD	E,A		;Xfer to E
;
;	Pick up number of cylinders in HL
;
	LD	L,(IY+6)	;P/u # of cylinders
	LD	H,0		;Msb = 0
	INC	HL		;Relative to zero
;
;	Calculate quantity of Granules/Cylinder
;
	PUSH	AF		;Save # of sectors/gran
	LD	A,(IY+8)	;Bits 7-5 contain
	AND	0E0H		;  # of Granules/cylinder.
	RLCA			;& shift to bits 0-2
	RLCA
	RLCA
	INC	A		;Adjust for zero offset
	BIT	5,(IY+4)	;Double sided?
	JR	Z,FREE2		;Bypass if one-sided
	ADD	A,A		;Else double the count
FREE2	LD	(GRANS+1),A	;Save # Grans/Cyl
	LD	C,A		;Save in C for @MULT8
;
;	Calculate quantity of Sectors/Cylinder
;
	@@MUL8			;Mult E x C
;
;	A = quantity of Sectors per cylinder
;
	PUSH	AF		;Save # Sectors/Cyl
	PUSH	HL		;Save # Cylinders
;
;	File slots avail = 256 if more than 32 secs
;
	LD	HL,256		;256 files maximum
	SUB	2		;Set A = # secs in dir
	CP	20H		;  Greater than 32 ?
	JR	NC,FREE3	;Yes - use default of 256
;
;	Calculate number of directory entries avail
;
	ADD	A,A		;Multiply # of Sectors
	ADD	A,A		;  in directory by 8
	ADD	A,A		;  to get # of slots.
	LD	L,A		;Stuff in HL
	LD	H,0
FREE3	LD	(FREE7+1),HL	;File slots to test later
;
;	Stuff # of entries (HL) into header string
;
	LD	DE,HPOSSF	;DE => Destination
	CALL	CVT3D		;Cvt HL to ASCII @ DE
	POP	HL		;Recover # of cylinders
	POP	AF		;Rcvr # of sectors/cyl
;
;	Calculate total # of sectors HL x A
;
	LD	C,A		;Set C = Sec/cyl
	OR	A
	JR	Z,SKIPMUL	;Don't multiply if zero
	@@MUL16			;Multiply HL x C
;
;	Convert # of sectors to K & stuff in string
;
SKIPMUL	LD	DE,HPOSSK	;DE => Destination
	CALL	CALCK		;Stuff into string
;
;	Transfer Diskette Name from GAT into string
;
	LD	HL,GAT+0D0H	;HL => Pack Name
	LD	DE,HNAME	;DE => String destination
	LD	C,8		;8 chars to xfer
	LDIR			;Xfer into string
;
;	Transfer Diskette Date from GAT into string
;
	LD	DE,HDATE	;DE => Destination
	LD	C,8		;8 chars to xfer
	LDIR			;Xfer to string
;
;	Pt HL => GAT, DE = Free Gran cnt, B = cyls
;
	LD	HL,GAT		;Pt to start of GAT
	IF	@BLD631
	LD	D,B		;<631>Init gran counter (B=0)
	LD	E,B		;<631>(B=0)
	ELSE
	LD	DE,0		;Init gran counter
	ENDIF
	LD	A,(GAT+0CCH)	;P/u cyl excess
	ADD	A,35		;Add base
	LD	B,A		;Set loop counter
;
;	Calculate quantity of Free granules left
;
FREE4	LD	A,(HL)		;P/u GAT byte & set
FREE5	SCF			;  carry so bit 7 stays 1
;
;	Is the granule in use ?
;
	RRA			;Slide gran bit to carry
	JR	C,FREE6		;Ignore if in use
;
;	Free Granule - Bump Free Granule count
;
	INC	DE		;Free, bump gran counter
FREE6	CP	0FFH		;End of byte?
	JR	NZ,FREE5	;Loop if not
;
;	Finished with one cylinder, advance to next
;
	INC	L		;Bump GAT byte pointer
	DJNZ	FREE4		;Loop for # cyls
;
;	Multiply # Grans (DE) by Sectors/Gran
;
	EX	DE,HL		;Xfer # Grans to HL
	POP	AF		;Rcvr # of sectors/gran
	LD	C,A		;Put in C for @MUL16
	@@MUL16			;Multiply HL x C
;
;	Cvt # of Free Grans to K & stuff in string
;
	LD	DE,HFREEK	;Cvrt to decimal
	CALL	CALCK		;Cvrt to ASCII & stuff
;
;	Build Footer String in case of map
;
	LD	A,'5'		;Init 5"/8" media
	BIT	5,(IY+3)	;Test DCT for size
	JR	Z,FIVEIN	;Go if 5"
	LD	A,'8'		;Else reset to 8"
FIVEIN	LD	(FSIZE),A	;Stuff size into header
;
;	P/u # of heads from DCT & stuff into footer
;
	LD	A,(IY+7)	;Bits 7-5 = # heads
	RLCA			;Shift to 0-2
	RLCA
	RLCA
	AND	7		;Mask off other junk
	INC	A		;Relative to zero
	OR	'0'		;Make it ASCII
	LD	(FHEADS),A	;Stuff into header
;
;	If this is a hard drive - ignore sides check
;
	BIT	3,(IY+3)	;Check if hard
	JR	Z,DOSIDES	;Not hard - check sides
;
;	Hard Drive - overwrite Floppy in footer
;
	LD	HL,HARD		;HL => "Hard  "
	LD	DE,FTYPE	;DE => Dest in footer
	LD	BC,6		;BC = 6 chars to xfer
	LDIR			;Transfer to footer
	LD	HL,RIGID	;HL => "RIGID"
	JR	D3		;Xfer "RIGID" to footer
;
;	Floppy disk - Stuff # of sides into footer
;
DOSIDES	LD	A,'1'		;Init # of sides
	BIT	5,(IY+4)	;Test DCT for sides
	JR	Z,ONESIDE	;Go if 1-sides
	INC	A		;Else bump to 2
ONESIDE	LD	(FHEADS),A	;Stuff into header
;
;	If floppy is double density pt HL to string
;
	BIT	6,(IY+3)	;Test SDEN/DDEN
	JR	Z,FREE7		;Single - that's default
	LD	HL,MDDEN	;Density MSG - Double
;
;	Xfer "Single, Double, or Rigid" to footer
;
D3	LD	DE,FDENS	;Density MSG dsp pos
	LD	BC,6		;6 chars to xfer
	LDIR			;Move Double to cover
;
;	Calculate # of Free HIT positions available
;
FREE7	LD	DE,$-$		;P/u # of poss entries
	LD	HL,HIT		;HL => HIT + 0
FREE8	DEC	DE		;Dec count in case of SYS
;
;	Check SYS slots if this is a data disk
;
	LD	A,(GAT+0CDH)	;Bit 7 set if Data disk
	RLCA
	JR	C,DATDISK	;Set - ignore SYS check
;
;	Is this a SYS slot - 00-07 or 20-27 ?
;
	LD	A,L		;P/u HIT offset
	AND	0D8H		;Reserved slot ?
	JR	Z,FREE9		;Yes - can't use it
;
;	Not reserved - is the HIT posn in use ?
;
DATDISK	LD	A,(HL)		;File in use?
	OR	A
	JR	NZ,FREE9	;Yes - don't bump count
;
;	Slot not in use - bump free slot count
;
	INC	DE		;Bump free count
FREE9	INC	L		;Bump HIT pointer
	JR	NZ,FREE8	;Loop if not through
;
;	Stuff available files into string
;
	EX	DE,HL		;Available files to HL
	LD	DE,HFREEF	;Cvrt to ASCII into msg
	CALL	CVT3D		;Convert & RETurn
;
;	Display Header String & RETurn
;
	LD	HL,HEADER	;HL => Header string
	JR	DSPMSG		;Display header & RETurn
;
DSPLINE	LD	HL,LINBUF	;Fall into Display & RET
;
;	DSPMSG - Display a message pointed to by HL 
;
DSPMSG	CALL	CKBREAK		;Check for <BREAK>
	CALL	DSPLY		;Display message to video
PPARM	LD	DE,$-$		;P/u P parm
	INC	E		;Was it entered ?
	JR	NZ,CKPAGE	;No - Check page pause
	JP	PRINT		;Output line to *PR
;
NO_DISK	LD	A,C		;P/u drive #
	ADD	A,'0'		;Cvt to ASCII
	LD	(NODISKN),A	;Stuff in string
	LD	HL,NODISK	;HL => Message
	JP	DSPMSG		;Display Mess & RETurn
;
;	Decrement Lines printed count
;
CKPAGE	LD	A,22		;Ck for display pause
	DEC	A		;Count down
	LD	(CKPAGE+1),A	;Update
	RET	NZ		;Ret if not yet full
;
;	Printed a full page - Reset to count to max
;
	LD	A,23		;Max lines to print
	LD	(CKPAGE+1),A	;Reset to max
;
;	Do not stop if a <DO> is in effect
;
SFLAG1	LD	A,($-$)		;P/u SFLAG$
	AND	20H		;Do in effect ?
	RET	NZ		;Yes - RETurn
;
;	Wait for key - then clear screen
;
	CALL	KEY		;Wait for key entry
DISPHDR:
;
;	Display Map header
;
;	LD	HL,HEADER	;Point to the header
;	CALL	DSPMSG		;  & display it
;	CALL	DISPUND		;Display underline
;
;	CLRLN - Clear line buffer
;
CLRLN	LD	A,' '		;Clear buffer
BUFSTUF	LD	HL,LINBUF	;Point to buffer
	LD	B,79		;Length of buffer
CLRLN1	LD	(HL),A		;Stuff with char given
	INC	HL
	DJNZ	CLRLN1
	LD	(HL),CR		;End line with C/R
	RET
;
;	CKBREAK - Check if the <BREAK> was pressed
;
CKBREAK	EQU	$
	@@CKBRKC		;<BREAK> hit ?
	RET	Z		;No - RETurn
	IF	@BLD631
ABORT	SCF			;<631><BREAK> hit - abort
	JP	ABORT1		;<631>Make HL = -1
	ELSE
ABORT	LD	HL,-1		;<BREAK> hit - abort
	JP	SAVESP
	ENDIF
;
;
;	CVTDEC - Convert Hex Number to Decimal ASCII
;	CVD2D - CVD4D  - Convert to 2,3, or 4 digits
;
;	HL => Hex Number to Convert
;	DE => Buffer to receive characters
;
	IF	@BLD631
CVT2D	LD	B,2		;<631>
	JR	CVTDEC		;<631>
CVT3D	LD	B,3		;<631>
	JR	CVTDEC		;<631>
CVT4D	LD	B,4		;<631>
	JR	CVTDEC		;<631>
CVT5D	LD	B,5		;<631>
CVTDEC	LD	A,5FH		;<631>HEXD
	RST	28H		;<631>
	RET			;<631>
	ELSE
CVT2D	LD	A,' '
	JR	CVT10
CVT3D	LD	A,' '
	JR	CVT100
CVD4D	LD	A,' '
	JR	CVT1000
CVTDEC	LD	A,' '
;
	LD	BC,10000
	CALL	CVD1
CVT1000	LD	BC,1000
	CALL	CVD1
CVT100	LD	BC,100
	CALL	CVD1
CVT10	LD	BC,10
	CALL	CVD1
	LD	A,L
	ADD	A,'0'
	LD	(DE),A
	INC	DE
	RET
;
CVD1	PUSH	DE
	LD	E,A
	LD	D,0FFH
	XOR	A
CVD2	INC	D
	SBC	HL,BC
	JR	NC,CVD2
	ADD	HL,BC
	LD	A,E
	LD	B,D
	POP	DE
	LD	(DE),A
	INC	B
	DEC	B
	JR	Z,CVD3
	LD	A,B
	ADD	A,'0'
	LD	(DE),A
	LD	A,'0'
CVD3	INC	DE
	RET
	ENDIF
;
;	DFRE - Stuff a cylinder's Gran symbols in buffer
;
;	IX => Buffer to receive characters
;	HL => GAT cylinder byte to use
;
DFRE	PUSH	BC		;Save C, cur cyl loc
GRANS	LD	B,$-$		;P/u Grans/Cylinder
;
;	Is this cylinder the directory ?
;
	LD	A,(IY+9)	;P/u dir cyl from DCT
	CP	C		;Directory ?
	JR	Z,DDIR		;Yes - use "D"'s
;
;	Not the directory cyl - use "x", "." & "*"
;
	PUSH	IX		;Save buffer pointer
	PUSH	BC		;Save Grans/Cyl
;
;	Is the Granule in use ?
;
DF1	RRC	(HL)		;P/u next Granule
	LD	A,'x'		;Init "in use"
	JR	C,DF2		;Set - use "x"
;
;	Granule isn't in use - stuff a "." in buffer
;
	LD	A,'.'		;Else free
DF2	LD	(IX+0),A	;Stuff char
;
;	Bump buffer pointer & decrement G/C count
;
	INC	IX		;Next display loc
	DJNZ	DF1		;Loop thru all grans
;
;	Recover Buff ptr, Grans/Cyl
;
	POP	BC		;B = Grans per Cyl
	POP	IX		;IX to start of track
;
;	Position HL to Lockout table
;
	PUSH	HL		;Save Cyl ptr
	LD	DE,60H		;Offset to lockout table
	ADD	HL,DE		;Point to lockout
;
;	Go through lockout & overwrite if locked out
;
LO1	BIT	3,(IY+3)	;If hard drive, there's
	JR	NZ,LO2		;  no lockout
;
;	Diskette is a floppy - Is gran locked out ?
;
	RRC	(HL)		;Gran locked out ?
	JR	NC,LO2		;No - bump buff ptr
	LD	(IX+0),'*'	;Asterisk = lockout
;
;	Bump buffer pointer & loop til done
;
LO2	INC	IX		;Next gran dsp loc
	DJNZ	LO1		;B grans/cyl
;
;	Recover ptrs & RETurn
;
	POP	HL
	POP	BC
	RET
;
;	DDIR - Use "D"'s for Directory instead of "x"
;
DDIR	LD	(IX+0),'D'	;Stuff "D" char
	INC	IX		;Loop thru all DIR grans
	DJNZ	DDIR
	POP	BC
	RET
;
;	DISPUND - Display a line of "-"
;
DISPUND	LD	A,'-'		;Character to underline
	CALL	BUFSTUF		;Stuff line & display
	JP	DSPLINE		;Display line
;
;	DSPTRK - Stuff cylinder numbers in line buffer
;
DSPTRK	PUSH	DE		;Save registers used
	PUSH	BC
;
;	Stuff starting cylinder # in line buffer
;
	LD	DE,LINBUF	;Display buffer
	INC	C		;Bump to next cylinder
	CALL	DSPTK4		;Display cylinder number
;
;	Is this the only cylinder in the line ?
;
	LD	A,(IY+6)	;P/u maximum # cyls
	CP	C		;Are we at the top?
	JR	Z,DSPTK3	;Go if yes
;
;	More than 1 cyl - stuff "-" in line buffer
;
	PUSH	AF		;Save max cylinder
	LD	A,'-'		;Stuff dash in buffer
	LD	(DE),A
	POP	AF		;Recover max cylinder
;
;	Get ending cylinder # for this line in C
;
	INC	DE		;Position to next avail
	LD	B,TPL-1		;Need 7 more on a line
;
DSPTK1	INC	C		;Bump until 7 or max
	CP	C
	JR	Z,DSPTK2
	DJNZ	DSPTK1
;
;	Stuff ending cylinder # into line buffer
;
DSPTK2	CALL	DSPTK4		;Stuff ending cyl on line
DSPTK3	POP	BC		;Recover registers
	POP	DE
	RET			;RETurn
;
;	Convert cylinder # (C) to ASCII at DE
;
DSPTK4	LD	L,C		;Xfer cylinder # to HL
	LD	H,0
	PUSH	BC		;Save cylinder #
	CALL	CVT3D		;Convert cyl# to ASCII
	POP	BC		;C = cylinder #
	RET			;RETurn
;
;	CALCK - Calculate Number of K & stuff in string
;	HLA => Total # of Sectors
;	DE => Destination of String
;
	IF	@BLD631
CALCK	LD	BC,CVT5D	;<631>Select 5 digit
	ELSE
CALCK	LD	BC,CVTDEC	;4 digit default
	ENDIF
CALCK2	LD	(CONVERT+1),BC
DIVHLA	LD	H,L		;Per disk pack
	LD	L,A
	SRL	H		;Divide total sectors
	RR	L		;  by 4 to calculate
	SRL	H		;  space in K
	RR	L
;
;	Convert K free (HL) to ASCII & put in string
;
	PUSH	AF		;Save offset
CONVERT	CALL	$-$		;Cvt HL to ASCII @ DE
	POP	AF		;Recover offset
;
;	Stuff hundredths value into string
;
	INC	DE		;Go past decimal point
	AND	3		;Modulo 4
	ADD	A,A		;Multiply by 2
	LD	B,0		;  to position to
	LD	C,A		;  hundredths string
	LD	HL,HUNDTAB	;HL => Table base
	ADD	HL,BC		;HL => Hundredths string
	LD	C,2		;2 chars to xfer
	LDIR			;Stuff in string
	RET			;RETurn
;
;	KEY/DSP/DSPLY/PRT/PRINT - SVC routines
;
KEY	LD	A,@KEY		;Wait for key
	DB	11H
;
DSP	LD	A,@DSP		;Display byte
	DB	11H		;LD DE,nnnn
;
DSPLY	LD	A,@DSPLY	;Display line
	DB	11H
;
PRINT	LD	A,@PRINT	;Print line
	DB	11H
;
PRT	LD	A,@PRT		;Print byte
;
DO_OUT	RST	40		;Do SVC & check error
	RET	Z		;RETurn if good
	JP	IOERR		;NZ - I/O Error
;
MDDEN	DB	'DOUBLE'
RIGID	DB	'RIGID '
HARD	DB	'Hard  '
;
MTRK	DB	'  0-  7'
;
HEADER	DB	'Drive :'
HDRIVE	DB	'd  '
HNAME	DB	'diskname  '
HDATE	DB	'dd/mm/yy   Free Space ='
HFREEK	DB	'nnnnn.nnK/'
HPOSSK	DB	'nnnnn.nnK  Files = '
HFREEF	DB	'ddd/'
HPOSSF	DB	'ddd',CR
;
FOOTER	DB	'Type =>  '
FSIZE	DB	's" '
FTYPE	DB	'Floppy    Heads = '
FHEADS	DB	'n   Density = '
FDENS	DB	'SINGLE   Note - 1 Position = '
FGRAN	DB	'nn.nnK'
ENDFOOT	DB	CR
;
NODISK	DB	'Drive :'
NODISKN	DB	'd  [No  Disk]',CR
;
HUNDTAB	DB	'00255075'
;
;	Parameter Table
;
PRMTBL$	DB	80H
	DB	FLAG!1
	DB	'P'
	DB	0
	DW	PPARM+1
	NOP
;
	ORG	$<-8+1<+8
GAT	DS	256
HIT	DS	256
LINBUF	EQU	$
;
	END	FREEMAP
