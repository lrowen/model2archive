;SETCOM/ASM - 01/08/83
;
        TITLE  <SETCOM- LDOS 6.2>
	COM '<Copyright 1982/83 by Logical Systems Inc.>'
OFFSET	EQU	4 ;bytes from end of name to data area
MSMASK         EQU    OFFSET+0
UCIMAGE        EQU    OFFSET+1
BAUDRT         EQU    OFFSET+2
BRK            EQU    OFFSET+3
;
INIT    EQU     2       ;ctl value to init driver
ETX     EQU    03H
CR      EQU    0DH
LF      EQU     0AH
;
FLAG    EQU     01000000B
ABB     EQU     00010000B
NUM     EQU     10000000B
*LIST  OFF
*GET    SVCMAC
*LIST  ON
;
        ORG     2400H
BEGIN   DI
        LD      (STACK),SP
        PUSH    HL              ;Save ptr to CMD buffer
        LD      HL,0
        @@BREAK                 ;Disable break vectoring
        EI
        POP     HL
        CALL    PGRM            ;DO IT!
; clean it up now.....
$EXIT   LD      HL,0
        XOR     A
QUIT$   LD      SP,$-$
STACK   EQU     $-2
        RET
$ABORT  LD      HL,-1
        JR      QUIT$
;
$DSP    @@DSP
        RET Z
        JR  IOERR
$DSPLY  @@DSPLY
        RET Z
IOERR   OR  0C0H
        LD  C,A 
        @@ERROR
        JR $ABORT
;
PGRM    PUSH    HL
        LD      DE,MDNAME
        @@GTMOD                 ;find module header
        JP NZ,BADMOD            ;exit if not found
        PUSH DE 
        POP  IX                 ;IX=>next byte after mod name
;
        POP     HL              ;=>cmd line
        DEC  HL
SPLP    INC  HL
        LD   A,(HL)             ;char fm cmd line
        CP   ' '
        JR   Z,SPLP   ;skip over spaces
        CP   '('      ;any params?
        JP   NZ,SHOWIT ;no, show settings 
;
        LD  DE,PTABLE
        @@PARAM
        JP NZ,PERROR
        LD DE,$-$
QPARM   EQU $-2                 ;QUERY?
        LD A,D
        OR E
        JP Z,CKPARM
        LD  HL,CPYMSG           ;logon for Q
        CALL $DSPLY
;
PROMPT  LD      HL,PBAUD
        LD      DE,BTYP 
        CALL    GETIT
        XOR     A
        LD      (BRESP),A       ;clear for re-try
        CALL    GETBD
        JR      NZ,PROMPT       ;bad entry - retry
;
BOK     LD      HL,PWORD
        LD      DE,WTYP
        CALL    GETIT
        XOR     A
        LD      (WRESP),A
        LD      A,(WORDP)
        CP      5
        JR      C,BOK           ;bad entry
        CP      8+1
        JR      NC,BOK
;
PS      LD      HL,PSTOP        ;=>prompt
        LD      DE,STYP         ;=>type byte
        CALL    GETIT
        XOR     A
        LD      (SRESP),A
        LD      A,(STOPP)       ;chk range
        OR      A
        JR      Z,PS 
        CP      2+1
        JR      NC,PS 
;
PP      LD      HL,PPAR         ;prompt fro Parity
        LD      DE,PTYP
        CALL    GETIT
        LD      A,(PARITYP)
        OR      A
        JR      Z,PB           ;if OFF, skip to Break
;
        LD      HL,STMSGE       ;prompt for EVEN
        LD      DE,ETYP
        CALL    GETIT
        LD      A,(EVENP)       ;p/u parm
        CPL                     ;flip value
        LD      (ODDP),A        ;set ODD
;
PB      LD      HL,STMSG2
        LD      DE,BRTYP
        CALL    GETIT
;
        LD      HL,PDTR
        LD      DE,DTYP
        CALL    GETIT
;
        LD      HL,PRTS
        LD      DE,RTYP
        CALL    GETIT
;
        LD      HL,PRI
        LD      DE,RITYP
        CALL    GETIT
;
        LD      HL,PDSR
        LD      DE,DSTYP
        CALL    GETIT
;
        LD      HL,PCD
        LD      DE,CDTYP
        CALL    GETIT
;
        LD      HL,PCTS
        LD      DE,CTTYP
        CALL    GETIT
;
        CALL    CKPARM
        LD      HL,CLS$
        @@DSPLY
        JP      SHOWIT
;
CKPARM  CALL    SETVAL
        LD      E,(IX)
        INC     HL
        LD      D,(IX+1)        ;p/u DCB address
        LD      C,INIT          ;initialize new values
        @@CTL
        RET
;
GETIT   PUSH    HL      ;save prompt
        PUSH    DE      ;save type byte
        EX      DE,HL   ;type byte to HL
        CALL    CKRSP
        POP     DE      ;restore type byte
        POP     HL      ;restore prompt
        RET     NZ      ;already have this one
        PUSH    HL
        PUSH    DE
        CALL    GETRSP
        POP     DE
        POP     HL
        JR      NZ,GETIT ;check for valid parm
        RET
;
;*****
BADMOD  LD      HL,BADDCB
        DB      0DDH            ;fake IX instruction
PERROR  LD      HL,PRMERR$
        @@LOGOT
        JP      $ABORT
;
MDNAME  DB      '$CL',ETX
CPYMSG  DB     'SETCOM - Version 6.2.0  Copyright 1982/83 by'
        DB     ' Logical Systems, Inc.',LF,CR
PRMERR$ DB     'Parameter error!',CR
BADDCB  DB      'Comm Line Driver Module not found!',CR
;
;length of string followed by ascii numbers
ASCTBL  DB      2,'50',2,'75',3,'110',3,'135',3,'150'
        DB      3,'300',3,'600',4,'1200',4,'1800',4,'2000'
        DB      4,'2400',4,'3600',4,'4800'
        DB      4,'7200',4,'9600',5,'19200'
;
AOFF    DB      3,'OFF'
AON     DB      3,'ON '
AIGNOR  DB      6,'IGNORE'
;
BTABLE  DW     50,75,110,135,150,300,600,1200,1800,2000
        DW     2400,3600,4800,7200,9600,19200
;
EVENP   DW      0FFFFH      ;ignored
;
MSTABLE EQU    $
RIP     DW     1             ;All default to no check
CDP     DW     1
DSRP    DW     1
CTSP    DW     1
;
CLS$    DB      1CH,1FH,ETX
STMSG1  DB      LF,'RS232 parameters:',LF
PBAUD   DB      'Baud        = '
DBAUD   DB      '      ',LF
PWORD   DB      'Word Length = '
DWORD   DB      '7',LF
PSTOP   DB      'Stop Bits   = '
DSTOP   DB      '2',LF
PPAR    DB      'Parity      = '
DPARIT  DB      'OFF',CR
STMSGO  DB      'Odd         = ON',CR
STMSGE  DB      'Even        = ON',CR
STMSG2  DB      'Allow System BREAK = '
DBRK    DB      'ON ',LF
        DB      LF,'Output control line status:',LF
PDTR    DB      'DTR = '
DDTR    DB      'ON ',LF
PRTS    DB      'RTS = '
DRTS    DB      'ON ',LF,LF
        DB      'Input control line conditions observed:',LF
PRI     DB      'RI  = '
DRI     DB      'ON    ',LF
PDSR    DB      'DSR = '
DDSR    DB      'ON    ',LF
PCD     DB      'CD  = '
DCD     DB      'ON    ',LF
PCTS    DB      'CTS = '
DCTS    DB      'ON    ',CR
;
;*****
PTABLE  DB      80H
        DB      5!ABB!FLAG
        DB      'QUERY'
QRESP   DB      0
        DW      QPARM
BTYP    DB      4!ABB!NUM
        DB     'BAUD'
BRESP   DB      0
        DW     BAUDP
WTYP    DB     4!ABB!NUM
        DB     'WORD'
WRESP   DB      0
        DW     WORDP
STYP    DB      4!ABB!NUM
        DB     'STOP'
SRESP   DB      0
        DW     STOPP
PTYP    DB      6!ABB!FLAG
        DB     'PARITY'
PRESP   DB      0
        DW     PARITYP
ETYP    DB      4!ABB!FLAG
        DB     'EVEN'
ERESP   DB      0
        DW     EVENP
        DB      3!ABB!FLAG
        DB     'ODD'
ORESP   DB      0
        DW     ODDP
DTYP    DB      3!FLAG
        DB     'DTR'
DTRESP  DB      0
        DW     DTRP
RTYP    DB      3!FLAG
        DB     'RTS'
RTRESP  DB      0
        DW     RTSP
DSTYP   DB      3!FLAG
        DB     'DSR'
DSRESP  DB      0
        DW     DSRP
CDTYP   DB      2!FLAG
        DB     'CD'
CDRESP  DB      0
        DW     CDP
CTTYP   DB      3!FLAG
        DB     'CTS'
CTRESP  DB      0
        DW     CTSP
RITYP   DB      2!FLAG
        DB     'RI'
RIRESP  DB      0
        DW      RIP
BRTYP   DB      5!FLAG
        DB     'BREAK'
BRRESP  DB      0
        DW     BREAKP
        DB     0
;
;
SETVAL
        CALL  GETBD          ;get baud setting
        JP    NZ,PERROR      ;didn't match any
        LD     (IX+BAUDRT),A  ;Save in Data area
        LD     C,0           ;Construct UART ctrl byte
        LD     DE,0          ;Default is EVEN
ODDP    EQU     $-2
        LD     A,D
        OR     E
        JR     NZ,WORD1      ;Go if ODD
        SET    7,C
WORD1   LD     DE,7          ;Default is 7 bits
WORDP   EQU     $-2
        LD     A,D           ;Range check
        AND    A
        JP     NZ,PERROR
        LD     A,E
        SUB    5             ;Convert to 2 bits
        LD     B,A
        AND    3
        CP     B             ;Range check
        JP     NZ,PERROR
        RRA                  ;Bit 1 to bit 7
        RRCA
        RR     B             ;Bit 0 from B to carry
        RRA                  ;Bit 0 to bit 6 and
        RRA                  ;  bit 1 to bit 5
        OR     C             ;Combine into C reg
        LD     C,A
;
;*=*=*
        LD     DE,1          ;Default is 1 stop bit
STOPP   EQU     $-2
        LD     A,D
        AND    A
        JP     NZ,PERROR      ;Range check
        LD     A,E
        SUB    1
        CP     2             ;Range check
        JP     NC,PERROR
        RLCA                 ;Shift to bit 4
        RLCA
        RLCA
        RLCA
        OR     C             ;OR into byte
        LD     C,A
;
        LD     DE,-1         ;Default is ON
PARITYP EQU     $-2
        LD     A,D
        OR     E
        JR     NZ,YESPTY      ;Go if PARITY=ON
        SET    3,C           ;Disable parity
YESPTY  SET    2,C           ;Disable BREAK
;
        LD     DE,-1         ;Default is ON 
DTRP    EQU     $-2
        LD     A,D
        OR     E
        JR     NZ,GRTS       ;Go if on
        SET    1,C           ;Bit is inverted
;
GRTS    LD     DE,0          ;Default is OFF
RTSP    EQU     $-2
        LD     A,D
        OR     E
        JR     NZ,UCDONE      ;Go if on
        SET    0,C           ;Bit is inverted
;
UCDONE  LD     (IX+UCIMAGE),C ;Save in Data area
;
        LD     B,4           ;Check RI,CD,DSR,CTS
        LD     HL,MSTABLE
        LD     C,0
MLOOP   RRC    C
        LD     A,(HL)        ;Check parm
        INC    HL
        OR     (HL)
        INC    HL
        JP     PO,PARMNO      ;Go if not entered
        SET    3,C           ;Show parm is checked
        JR     NZ,PARMNO      ;Go if checking for true
        SET    7,C           ;Show parm is inverted
PARMNO  DJNZ   MLOOP
        LD     (IX+MSMASK),C  ;Put mask in Data Area
;
        LD      A,(BRRESP)
        AND     FLAG
        JR      Z,SBRK
        LD     DE,0          ;Default is OFF
BREAKP  EQU     $-2
        LD     A,D
        OR     E
SBRK    LD     (IX+BRK),A    ;put in data area
        RET
;
GETBD   LD     DE,300        ;Baud parm (default 300)
BAUDP   EQU     $-2
        LD     HL,BTABLE     ;Point to baud table
        LD     B,16          ;Sixteen baud rates
        LD     C,0           ;Count from zero
BLOOP   LD     A,(HL)        ;Scan through baud table
        INC    HL
        CP     E
        JR     NZ,NOMATB      ;Go if no match
        LD     A,(HL)
        CP     D
        JR     Z,MATCHB       ;Go if match
NOMATB  INC    HL
        INC    C
        DJNZ   BLOOP         ;Try next rate
        RET                  ;Parm error if NZ
;
MATCHB  LD     A,C           ;Pick up baud rate code
        RLCA
        RLCA
        RLCA
        RLCA
        OR     C             ;Use for xmit and rcv
        CP     A             ;Z=good value
        RET
;
;  display values
SHOWIT  LD      A,(IX+BAUDRT) ;p/u current value
        AND     0FH           ;look at one nibble
        INC     A            ;set up for loop
        LD      HL,ASCTBL     ;ascii numbs
ALOOP   DEC     A
        JR      Z,GOTSTR     ;HL=>to length byte
        LD      B,(HL)        ;P/U length
MVHL    INC     HL
        DJNZ    MVHL
        INC     HL          ;to next length byte
        JR      ALOOP
GOTSTR  LD      DE,DBAUD     ;=>buffer to receive
        CALL    MVSTR        ;put (HL) bytes fm HL+1 to DE
;
        LD      A,(IX+UCIMAGE)
        LD      B,'5'
        AND     01100000B       ;isolate Word ln
        JR      Z,GOTLEN
        INC     B               ;'6'
        CP      01000000B
        JR      Z,GOTLEN
        LD      B,'8'
        JR      NC,GOTLEN
        DEC     B
GOTLEN  LD      HL,DWORD
        LD      (HL),B
;
        BIT     4,(IX+UCIMAGE)
        JR      Z,ONESTP
        LD      A,'2'
        LD      (DSTOP),A
;
ONESTP  BIT     3,(IX+UCIMAGE)  ;parity enabled?
        PUSH    AF
        JR      NZ,PAROFF
        LD      HL,AON
        LD      DE,DPARIT
        CALL    MVSTR
PAROFF  LD      A,(IX+BRK)
        OR      A
        JR      NZ,BISON
        LD      HL,AOFF
        LD      DE,DBRK
        CALL    MVSTR
BISON   LD      HL,STMSG1       ;display 1st part
        CALL    $DSPLY
        POP     AF              ;parity on?
        JR      NZ,NOPAR
        LD      HL,STMSGO
        BIT     7,(IX+UCIMAGE)
        JR      Z,EP
        LD      HL,STMSGE
EP      CALL    $DSPLY
;
NOPAR   BIT     1,(IX+UCIMAGE)
        JR      Z,DT1
        LD      HL,AOFF
        LD      DE,DDTR
        CALL    MVSTR
;
DT1     BIT     0,(IX+UCIMAGE)
        JR      Z,DS1
        LD      HL,AOFF
        LD      DE,DRTS
        CALL    MVSTR
;
DS1     LD      C,(IX+MSMASK)
        LD      DE,DCTS
        LD      A,10001000B
        AND     C
        CALL    MVR1
        LD      DE,DDSR
        LD      A,01000100B
        AND     C
        CALL    MVR1
        LD      DE,DCD
        LD      A,00100010B
        AND     C
        CALL    MVR1
        LD      DE,DRI
        LD      A,00010001B
        AND     C
        CALL    MVR1
        LD      HL,STMSG2
        CALL    $DSPLY
        RET
;
MVR1    LD      HL,AIGNOR       ;=>ignore string
        JR      Z,MVSTR         ;move if both bits are off
        RET     PO              ;leave 'ON' if one bit is set
        LD      HL,AOFF         ;show 'OFF' if both bits set
MVSTR   LD      B,(HL)
MVBYTE  INC HL
        LD      A,(HL)
        LD      (DE),A
        INC     DE
        DJNZ    MVBYTE
        RET
;
CKRSP   LD      (TTYP),HL       ;save type byte posn
;
MVUP    LD      A,15
        LD      C,(HL)          ;HL=>type byte
        AND     C
        LD      B,A
UP      INC     HL
        DJNZ    UP
        INC     HL              ;HL=>resp
        LD      A,(HL)          ;p/u RESPONSE byte
        AND     NUM!FLAG
        AND     C               ;Z if no valid response
        RET
;
GETRSP  LD      C,(HL)  ;print prompt msg
        CALL    $DSP
        INC     HL
        LD      A,'='
        CP      C  
        JR      NZ,GETRSP
        LD      C,' '
        CALL    $DSP
        XOR     A
        LD      (FRESP),A
        LD      HL,INBUF
        LD      B,10
        @@KEYIN
        JP      C,$ABORT        ;quit if BREAK pressed
        INC     B
        DEC     B
        RET     Z               ;quit if null entry
;
        LD      DE,PTBL2
        LD      HL,FSTR
        @@PARAM
        LD      HL,(TTYP)
        CALL    MVUP
        LD      A,(FRESP)
        LD      (HL),A          ;replace resp byte
        INC     HL
        LD      A,(HL)          ;HL=(HL)
        INC     HL 
        LD      H,(HL)
        LD      L,A
        LD      BC,$-$
FPARM   EQU     $-2
        LD      (HL),C          ;put new resp in param space
        INC     HL
        LD      (HL),B
        OR      0FFH    ; Make sure Z is reset
        RET
;
TTYP    DW      0       ;store current parm pointer
;Param block to accept prompted entries..
PTBL2   DB      80H
FTYP    DB      FLAG!NUM!1
        DB      'F'
FRESP   DB      00
        DW      FPARM
        DB      0
FSTR    DB      '(F='
INBUF   EQU     $
;
        END     BEGIN
