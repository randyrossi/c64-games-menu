!to "menu",cbm

; A simple game browser for the C64 that works with
; pi1541 or sd2iec. The menu lets you page through a
; large index with game descriptions, directory names
; and .d64 image names. Games must be organized under
; directories ; named with a single char (0abcd...etc)

; Index file format
; Filename: letter-pagenum  i.e. a-3
; dirname + $0d + imagename + $0d + description + $0d
; if dirname starts with $00, no more entries
; if dirname starts with $ff, no more entries and last page

; TODO Use * key to load "*",8,1 instead of "$" + list

*=$801              ;START ADDRESS IS $801

FILECODE   = $100e ; 1 char we read from memory
SCREENCODE = $100f ; 1 byte we poke to screen mem
CURLETTER  = $1010 ; 1 current selected letter
CURROW     = $1011 ; 1 current row within page
CURPAGE    = $1012 ; 1 current page
SAVEX      = $1013 ; 1 tmp for storing x
SAVEA      = $1014 ; 1 tmp for storing accum
SAVEY      = $1015 ; 1 tmp for storing y
FNLEN      = $1016 ; 1 filename length
IMAGELEN   = $1017 ; 1 length of image string
DESCLEN    = $1018 ; 1 length of description string
DIRNAMELEN = $1019 ; 1 length of dirname string
DIR_OR_RUN = $101a ; 1 flag for enter vs *
DRIVENUM   = $101b ; 1 device number to use
DESCRIP    = $1020 ; 40 description string
IMAGENAME  = $1048 ; 20 image string
DIRNAME    = $105c ; 10 directory string
SAVEPSA1   = $1080 ; 1 tmp to save page start address
SAVEPSA2   = $1081 ; 1 tmp to save page start address
LINE       = $1082 ; 1 tmp for iterating, holds max row for cur page
LASTFLAG   = $1083 ; 1 1=last entry in page, ff=last entry and last page
FILENAME   = $1084 ; 10 scratch space for filename

; Change the $38 after the $2c to the drive number (in petscii)
; you want this program to default to.
BASIC:  !BYTE $0B,$08,$01,$00,$9E,$32,$30,$36,$33,$2c,$38,$00,$00,$00
        ;Adds BASIC line: 1 SYS 2063,8

MAIN:
	; grab parameter from sys to change drive number we will use
        JSR     $AEFD         ; check for comma
        JSR     $B79E         ; get 8-bit parameter into X
	JSR     SETDRIVE

	; set screen colors
        LDA     #$00
        STA     $D020
        STA     $D021

	; initialize variables
	LDA     #$00
	STA     CURLETTER
	LDA     #$02
	STA     CURROW
	LDA     #0
	STA     CURPAGE

BEGIN:
	; construct filename from letter/page
	LDX     #0
	LDA     CURLETTER
	TAY
        LDA     LETTERS,y
	STA     FILENAME,X
        INX
	LDA     #$2D        ; dash
	STA     FILENAME,X
        INX
        LDA     CURPAGE
        CMP     #10
        BCS     TWODIG      ; CURPAGE >= 10
ONEDIG:
        TAY
	LDA     DIGITS,Y     
        STA     FILENAME,x
	INX
        STX     FNLEN
	JMP     LOADCURPAGE
TWODIG:
	STX     SAVEX
	LDX     #0
TWODIG2:
	; how many times can we subtract 10?
	INX
	CLD
	SBC    #$0a
        CMP    #$0a
        BCS    TWODIG2      ; A >= 10
	STA    SAVEA
	LDA    DIGITS,x
	LDX    SAVEX
        STA    FILENAME,x
	INX
	LDA    SAVEA        ; leave 2nd digit in A
        JMP    ONEDIG
        
LOADCURPAGE:
	; load current page into memory
        LDA     #147            ;CLR
        JSR     $FFD2           ;CHAR OUT
        LDA     #144            ;BLK (to hide the loading message)
        JSR     $FFD2           ;CHAR OUT
        LDA     #$0d            ;set c800 to empty entry in case load fails
        STA     $c800
        LDA     #$0d
        STA     $c801
        LDA     #$0d
        STA     $c802
        LDA     #$ff
        STA     $c803
	LDA     FNLEN           ;FILE NAME LENGTH
        LDX     #<FILENAME
        LDY     #>FILENAME
	JSR     LOADPAGE

	; clear screen and print top menu
        LDY     #$00
TOPMENU:
        LDA     MENUTEXT,Y
        JSR     $FFD2           ;CHAR OUT
        INY
        CPY     #29
        BNE     TOPMENU

	; also print filename top right
        LDY     #4
PRSPC:
	LDA     #$20 ; space
	JSR     $FFD2
	DEY
	BNE     PRSPC

        LDY     FNLEN
        LDX     #0
PRINTFN:
        LDA     FILENAME,X
	JSR     $FFD2
	INX
	DEY
	BNE     PRINTFN

; show drive num in upper right corner
	LDA     DRVO
        STA     $426
	LDA     DRVO2
        STA     $427
	LDA     #1
	STA     $d827
	STA     $d826

        ; highlight current letter
        LDY CURLETTER
        LDA $400,y
        EOR #$80
        STA $400,y

        ; set page data source address in $fb/$fc
        LDA     #$00
        STA     $fb
        LDA     #$c8
        STA     $fc

	; always start at line 2
        LDA     #2
        STA     LINE

	; print all descriptions for this page
FULLPAGE:
        JSR     GETNEXT
        LDA     LINE
        JSR     SHOWDESC
        INC     LINE
        LDA     LASTFLAG
        CMP     #0
	; keep iterating until we get 0 or ff
        BEQ     FULLPAGE

	; show instructions at bottom
	LDY     #0
SHOWINSTR:
	LDA     INSTRUCT,Y
	EOR     #$80
	STA     $7c0,y
	LDA     #1
	STA     $dbc0,y
	INY
	CPY     #40
	BNE     SHOWINSTR

HANDLEKEY:
	; hilite current row
	LDA     CURROW
	JSR     REVERSE

	; wait for a key to be pressed
WAITKEY:
	JSR     $FFE4 ; get char
	CMP     #0
	BEQ     WAITKEY

	; un-hilite
        STA     SAVEA
	LDA     CURROW
	JSR     REVERSE
	LDA     SAVEA

	; jump to key handler
	CMP     #$11
	BEQ     KDOWN
	CMP     #$91
	BEQ     KUP
	CMP     #$1d
	BEQ     KRIGHT
	CMP     #$9d
	BEQ     KLEFT
	CMP     #$30
	BEQ     KZERO
	CMP     #95
	BEQ     KBACK
	CMP     #$20
	BEQ     KSPACE
	CMP     #$0d
	BEQ     KENTER
	CMP     #$2a
	BEQ     KASTERISK
	CMP     #$2c
	BEQ     KNEXTDRIVE
	CMP     #$41
	BCS     KLET   ; >=41 ? handle letter key
	JMP     HANDLEKEY

KUP:
	JMP UP
KDOWN:
	JMP DOWN
KLEFT:
	JMP LEFT
KRIGHT:
	JMP RIGHT
KSPACE:
	JMP SPACE
KBACK:
	JMP BACK
KZERO:
	JMP ZERO
KLET:
	JMP LET
KENTER:
	LDA #0
	STA DIR_OR_RUN
	JMP ENTER
KASTERISK:
	LDA #1
	STA DIR_OR_RUN
	JMP ENTER
KNEXTDRIVE:
	JMP NEXTDRIVE

; begin key handling routines

ENTER:
	; first fetch the row we selected
        LDA     #$00
        STA     $fb
        LDA     #$c8
        STA     $fc

	LDY     #1
FETCHROW:
	INY
	STY     SAVEY
        JSR     GETNEXT
	LDY     SAVEY
	CPY     CURROW
	BNE     FETCHROW

	; clr and print commands to load the selection
        LDY     #$00
ENTER1:
        LDA     EXECUTE1,Y
        JSR     $FFD2           ;CHAR OUT
        INY
        CPY     #26             ; num chars
        BNE     ENTER1

	; letter
	LDY     CURLETTER
	LDA     LETTERS,y
        JSR     $FFD2           ;CHAR OUT

	LDA     #47  ; /
        JSR     $FFD2           ;CHAR OUT

	; print dirname
        LDY     #$00
DNOUT:
        LDA     DIRNAME,Y
        JSR     $FFD2           ;CHAR OUT
	INY
	CPY     DIRNAMELEN
	BNE     DNOUT

	LDA     #47  ; /
        JSR     $FFD2           ;CHAR OUT

	; print imagename
        LDY     #$00
IMOUT:
        LDA     IMAGENAME,Y
        JSR     $FFD2           ;CHAR OUT
	INY
	CPY     IMAGELEN
	BNE     IMOUT

	; print rest of commands
        LDY     #$00
ENTER2:
        LDA     EXECUTE2,Y
        JSR     $FFD2           ;CHAR OUT
        INY
        CPY     #30             ; num chars
        BNE     ENTER2

	LDA     DIR_OR_RUN
	CMP     #1
	BEQ     DOLOAD
DODIR:
        LDY     #$00
ENTER3:
        LDA     EXECUTE3,Y
        JSR     $FFD2           ;CHAR OUT
        INY
        CPY     #20             ; num chars
        BNE     ENTER3
	JMP     DORETURNS

DOLOAD:
        LDY     #$00
ENTER4:
        LDA     EXECUTE4,Y
        JSR     $FFD2           ;CHAR OUT
        INY
        CPY     #21             ; num chars
        BNE     ENTER4
	
DORETURNS:
	; returns to execute commands
	LDA     #13
	STA     631
	STA     632
	STA     633
	STA     634
	LDA     #4
	STA     198
	RTS

	; 0 key handler
ZERO:
	LDA #0
	STA CURLETTER
	STA CURPAGE
	LDA #2
	STA CURROW
	JMP BEGIN

	; letter key jump
LET:
	CMP #$5b       ; > z? ignore
	BCS LET2
	CLD
	SBC #$3f
	STA CURLETTER
	LDA #2
	STA CURROW
	LDA #0
	STA CURPAGE
	JMP BEGIN
LET2:
	JMP HANDLEKEY

	; prev letter
LEFT:
	LDA #0
	STA CURPAGE
	LDA #2
	STA CURROW
	LDA CURLETTER
	CMP #0
	BEQ LEFT2
	DEC CURLETTER
	JMP BEGIN
LEFT2:
	LDA #26
	STA CURLETTER
	JMP BEGIN

	; next letter
RIGHT:
	LDA #0
	STA CURPAGE
	LDA #2
	STA CURROW
	LDA CURLETTER
	CMP #26
	BEQ RIGHT2
	INC CURLETTER
	JMP BEGIN
RIGHT2:
	; wrap back to 0
	LDA #0
	STA CURLETTER
	JMP BEGIN

	; next game
DOWN:
	INC CURROW
	LDA CURROW
	CMP LINE
	BNE DOWNB
	LDA #2 ; always wrap around back to 2
	STA CURROW
DOWNB:
	JMP HANDLEKEY

	; prev game
UP:
	LDA CURROW
	CMP #2    ; 2 is always top entry
	BEQ UPWR
	DEC CURROW
	JMP HANDLEKEY
UPWR:
	LDA LINE
	CLD
	SBC #1
	STA CURROW
	JMP HANDLEKEY

	; next page
SPACE:
	LDA #2
	STA CURROW
	LDA LASTFLAG
	CMP #$ff
	BEQ SPACE2
	INC CURPAGE
	JMP BEGIN
SPACE2:
	LDA #0
	STA CURPAGE
	JMP BEGIN

	; prev page
BACK:
	LDA #2
	STA CURROW
	LDA CURPAGE
	CMP #0
	BEQ BACK2
	DEC CURPAGE
BACK2:
	JMP BEGIN

NEXTDRIVE:
	INC DRIVENUM
	LDA DRIVENUM
	CMP #13
	BCS DRIVEWRAP  ; A >= 13?
DODRIVE:
	STA DRIVENUM
	TAX
	JSR SETDRIVE
	JMP BEGIN
DRIVEWRAP:
	LDA #8
	JMP DODRIVE

; copy desc to destination line of screen
; accum has line num
; non destructive to fb/fc page data ptrs
SHOWDESC:
        ASL           ; accum x 2
        TAX           

	; be non destructive to $fb/$fc pointer
        LDA     $fb
        STA     SAVEPSA1
        LDA     $fc
        STA     SAVEPSA2

	; setup $fe/fd screen ptr and $2/$3 color mem ptr 
	LDA     SCREEN,X
        STA     $fe
        LDA     COLOR,X
        STA     $3
        INX
	LDA     SCREEN,X
        STA     $fd
        LDA     COLOR,X
        STA     $2

	; setup description src ptr in $fb/$fc
	LDA     #<DESCRIP
        STA     $fb
	LDA     #>DESCRIP
        STA     $fc

        LDY     #0
SHOW1:
        LDA     #1       ; white
        STA     ($2),y   ; set color mem
        LDA     ($fb),y  ; read src byte
        JSR     TOSCREENCODE ; convert to screen code
	LDA     FILECODE
        CMP     #$0d
        BEQ     SHOW2        ; don't poke the end marker
	LDA     SCREENCODE
        STA     ($fd),y      ; poke screen code
SHOW2:
        INY
	LDA     FILECODE
        CMP     #$0d
        BNE     SHOW1        ; more?

	; restore saved ptr
        LDA     SAVEPSA1
        STA     $fb
        LDA     SAVEPSA2
        STA     $fc
        RTS

; grab next entry from page into our vars
; will set LASTFLAG appropriately
GETNEXT:
        LDA     #<DIRNAME
        STA     $fd
        LDA     #>DIRNAME
        STA     $fe

        LDX     #0
        LDY     #0
DIR1:
        LDA     ($fb,x)
        STA     ($fd),y
        INC     $fb
        BNE     DIR2
        INC     $fc
DIR2:
	INY
        CMP     #$0d
        BNE     DIR1

	DEY
	STY     DIRNAMELEN

        LDA     #<IMAGENAME
        STA     $fd
        LDA     #>IMAGENAME
        STA     $fe

        LDY     #0
IMAGE1:
        LDA     ($fb,x)
        STA     ($fd),y
        INC     $fb
        BNE     IMAGE2
        INC     $fc
IMAGE2:
	INY
        CMP     #$0d
	BNE     IMAGE1

	DEY
	STY     IMAGELEN

        LDA     #<DESCRIP
        STA     $fd
        LDA     #>DESCRIP
        STA     $fe

        LDY     #0
DESC1:
        LDA     ($fb,x)
        STA     ($fd),y
        INC     $fb
        BNE     DESC2
        INC     $fc
DESC2:
	INY
        CMP     #$0d
        BNE     DESC1

	DEY
	STY     DESCLEN

        LDY     #0
        LDA     ($fb),y
        CMP     #0
	BNE     NOTLAST
        ; this is the last entry but more pages follow 
        LDA     #1
        STA     LASTFLAG
        RTS
NOTLAST:
        CMP     #$ff
        BNE     NOTLASTPAGE
        ; this is the entry and the last page 
        LDA     #$ff
        STA     LASTFLAG
        RTS
NOTLASTPAGE:
        ; neither last entry nor last page
        LDA     #0
        STA     LASTFLAG
        RTS

; Reverse a line of text on screen at line Y
; A = linenum
REVERSE:
        ASL           ; accum x 2
        TAX           
        ; copy screen line addr to 0xfb
        LDA     SCREEN,X
        STA     $fc
        INX
        LDA     SCREEN,X
        STA     $fb
        
        LDY #39
REVLOOP:
        LDA ($fb),y
        EOR #$80
        STA ($fb),y
        DEY
        BNE REVLOOP
        LDA ($fb),y
        EOR #$80
        STA ($fb),y
	RTS

; accum = length of filename
; x = address low byte
; y = address high byte
LOADPAGE:
	JSR $FFBD ; SETNAM
	LDA #4    ; logical num
	LDX DRIVENUM  ; drive was set by sys
	LDY #1    ; secondary
	JSR $FFBA ; SETLFS
	LDA #0    ; LOAD = 0, VERIFY = 1
	LDX #$00
	LDY #$c0
	JSR $FFD5 ; do LOAD
	RTS

; translate chars to screen code
TOSCREENCODE:
	STA     FILECODE
	STA     SCREENCODE
        CMP     #$41
        BCS     ISCHAR1      ; A >=0x41 
	RTS
ISCHAR1:
	CMP     #$5b         ; A >=0x5b
	BCS     IGNORE
	CLD
	SBC     #$3f
	STA     SCREENCODE
IGNORE:
	RTS
	
; X expected to have drive number desired
SETDRIVE:
	STX     DRIVENUM
        ; also store drive num as petscii in memory for
        ; the load steps
        TXA
        CMP     #10
        BCS     TWODIGDRIVE      ; drive >= 10
	; single digit for drive
	ADC     #$30   ; to petscii
	STA     DRVO2
	STA     DRVLO2
	STA     DRVLI2
	LDA     #$20   ; space for first digit
	STA     DRVO
	STA     DRVLO
	STA     DRVLI
	RTS
TWODIGDRIVE
	LDX     #0
TWODIGDRIVE2:
	; how many times can we subtract 10?
	INX
	CLD
	SBC    #$0a
        CMP    #$0a
        BCS    TWODIGDRIVE2      ; A >= 10
	ADC    #$30
	STA    DRVO2
	STA    DRVLO2
	STA    DRVLI2
	LDA    #$31
	; first digit becomes 1 (only support up to 19)
	STA    DRVO
	STA    DRVLO
	STA    DRVLI
	RTS

; addresses for start of every screen line char cell
SCREEN: !BYTE $04,$00,$04,$28,$04,$50,$04,$78,$04,$a0
        !BYTE $04,$c8,$04,$f0,$05,$18,$05,$40,$05,$68
        !BYTE $05,$90,$05,$b8,$05,$e0,$06,$08,$06,$30
        !BYTE $06,$58,$06,$80,$06,$a8,$06,$d0,$06,$f8
        !BYTE $07,$20,$07,$48,$07,$70,$07,$98,$07,$c0 

; addresses for stat of every screen line color cell
COLOR:  !BYTE $d8,$00,$d8,$28,$d8,$50,$d8,$78,$d8,$a0
	!BYTE $d8,$c8,$d8,$f0,$d9,$18,$d9,$40,$d9,$68
	!BYTE $d9,$90,$d9,$b8,$d9,$e0,$da,$08,$da,$30
	!BYTE $da,$58,$da,$80,$da,$a8,$da,$d0,$da,$f8
	!BYTE $db,$20,$db,$48,$db,$70,$db,$98,$db,$c0 

MENUS:  !PET "0abcdefghijklmnopqrstuvwxyz"

MENUTEXT:
        !BYTE   147,5           ;CLEAR SCREEN AND WHITE
LETTERS:
        !PET    "0abcdefghijklmnopqrstuvwxyz"

INSTRUCT:
        !BYTE $15,$2f,$04,$3d,$0d,$0f,$16,$05,$20,$0c,$2f,$12,$3d,$0c,$05,$14 
        !BYTE $14,$05,$12,$20,$13,$10,$03,$2f,$1f,$3d,$10,$01,$07,$05,$20,$05
        !BYTE $0e,$14,$05,$12,$3d,$13,$05,$0c

DIGITS:
	!pet    "0123456789"

EXECUTE1:   ;26
	!BYTE   147,17,17
	!pet    "new"
	!BYTE   13,13,13
	!pet    "open1,"
DRVO: ;becomes first digit of drive num
        !pet " "
DRVO2: ;becomes second digit of drive num
        !pet "?"
        !pet ",15,"
	!BYTE   34
	!pet    "cd://"

; need a delay after open to give pi1541 some time to
; mount the disk
EXECUTE2:   ;30 bytes
	!BYTE   34
	!pet    ":close1:for i=1to2200:next"
	!BYTE   13,13,13

EXECUTE3:   ;20 bytes
	!pet    "load"
	!BYTE   34
	!pet    "$"
	!BYTE   34
	!pet    ","
DRVLI: ; becomes first digit of drive num
	!pet    " "
DRVLI2: ; becomes first digit of drive num
	!pet    "?"
	!BYTE   13,13,13,13,13
	!pet    "list"
	!BYTE   19

EXECUTE4:  ;21 bytes
	!pet    "load"
	!BYTE   34
	!pet    "*"
	!BYTE   34
	!pet    ","
DRVLO: ; becomes first digit of drive num
        !pet    " "
DRVLO2: ; becomes second digit of drive num
        !pet    "?"
        !pet    ",1"
	!BYTE   13,13,13,13,13
	!pet    "run"
	!BYTE   19
