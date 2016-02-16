;;;
;;;  CCIRC - CoCo IRC Client for CoCo3
;;;
;;;

	include	yados.def	; YA-DOS definitions
;;; Colors
WHITE	equ	0 		; white
RED	equ	1 		; red
BLUE	equ	2		; blue
GREEN	equ	3 		; green
CYAN	equ	4 		; cyan
MAGENTA	equ	5 		; magenta
YELLOW	equ	6 		; yellow
GRAY	equ	7 		; grey

	
;;; Screen buffer struct
	org	$0
SCRBEG  rmb	2		; beginning of memory buffer
SCRPOS	rmb	2		; screen buffer memory position
SCRX	rmb	1		; screen buffer X position
SCRY	rmb	1		; screen buffer Y position
SCRM	rmb	1		; max lines in buffer
SCRC	rmb	1		; if there's a cursor
SCRA	rmb	1		; current screen attributes
SCRZ	equ	*		; size of struct
	
	org 	$1000		; start of this program

DBUF0	equ	$600
CR	equ	$d
BS	equ	$8
	
;;;
;;; Ram Variables
;;; 
drvNo	.db	0		; device no (for YA-DOS)

DWRead	.dw	YDWRead		; DWRead vector
DWWrite	.dw	YDWWrite	; DWWrite vector

;;; This is the server input buffer
ibuff	rmb	512		; input buffer
ipos	.dw	ibuff		; input buffer position
	
;;; this is a transmit buffer to DW
dwbuf	.db	$64,$1		; write to port 1
dwno	rmb	1		; number of bytes
xmitb	rmb	256		; transmit buffer
xpos	.dw	xmitb		; xmit buffer position

;;; this is the keyboard output buffer
obuff	rmb	512		; output buffer
opos	.dw	obuff		; output buffer position

	
mbuf	rmb	SCRZ		; main window buffer
kbuf	rmb	SCRZ		; keyboard window
sbuf	rmb	SCRZ		; status window

dwsq	.db	0		; DW poll sqelch
timer	rmb	2		; timer value

chan	rmb	16		; saved channel string
nick	rmb	16		; saved nickname
word	rmb	512		; command word buffer
ppos	rmb	2		; parse input pointer

cpl	.db	80		; Charactors per line
attr	.db	0
	
start
	;; clear global string
	clr	chan
	clr	nick
	clr 	word
	;; check for CoCo3
	ldb	$fffc		; get MSB of NMI Vector
	cmpb	#$fe		; is coco3?
	lbne	err@		; no then error
	;; check for YA-DOS
	ldd	$d930		; get MSW of Magic
	cmpd	#$5941		; is "YA" ?
	bne	a@		; no then check for next flavor
	ldd	$d932		; get LSW of Magic
	cmpd	#$4453		; is "DS" ?
	bne	a@		; no then check for next flavor
	ldb	#0		; B = Drivewire device
	SCALL	SDWSETUP	; set it up
	bcs	err@
	bra 	cont@		; continue with setup
	;; check for HDBDOS
a@	ldb	$C101		; check a patch
	cmpb	#$12		; is it a NOP?
	bne	b@		; no then check for next flavor
	ldd	$d93f		; get DWRead vector
	std	DWRead		; store as our vector
	ldd	$d941		; get DWWrite vector
	std	DWWrite		; store as out vector
	bra	cont@
	;; check for SDC-DOS
b@	ldd	$dffe		; check rom for signature
	cmpd	#$0203
	bne	err@		; first word doesn't match
	ldd	$dff0
	std	DWRead
	ldd	$dff2
	std	DWWrite
cont@	;; setup keyboard
     	clr	$11a		; lower case
	;; setup main window screen
	jsr	scrInit
	ldx	#mbuf		; main window buffer
	ldu	#$6000		; start of window
	ldb	#21		; 23 lines
	jsr	bufIni		; initialize buffer
	;; setup status screen
	ldx	#sbuf		; status buffer
	lda	#21
	ldb	cpl
	lslb
	mul
	addd	#$6000
	tfr	d,u
	ldb	#1
	jsr	bufIni
	jsr	drawStatus
	;; setup keyboard screen
	ldx	#kbuf		; keyboard buffer
	lda	#22
	ldb	cpl
	lslb
	mul
	addd	#$6000
	tfr	d,u
	ldb	#2		; 2 lines
	jsr	bufIni
	clr	SCRC,x
	com	SCRC,x
	;; Setup DW device
	jsr	DWOpen		; open port
	;; send a command
c@	jsr	getKey		; get keys
	;; get result
	jsr	DWReply		; get from dw
	bra	c@
	;; return
err@	rts			; return to basic



;;; Set screen buffer forground attributes
;;;   takes: X = screen struct ptr, B = color number
;;;   returns: nothing
bufFcolor
	pshs	b
	lslb			; shift arg to fg bits pos
	lslb
	lslb
	pshs	b		; save on stack
	ldb	SCRA,x		; b = attribute bytes
	andb	#$c7		; mask off foreground bits
	orb	,s+		; set fg bits from stack
	stb	SCRA,x		; save in attribute bytes
	puls	b,pc		; return

;;; Print a space to screen buffer
;;;   takes: X = screen struct ptr
;;;   returns: nothing
bufSpace
	pshs	b
	ldb	#$20
	jsr	bufPrint
	puls	b,pc

;;; Print a CR to screen buffer
;;;   takes: X = screen struct ptr
;;;   returns: nothing
bufCR
	pshs	b
	ldb	#CR
	jsr	bufPrint
	puls	b,pc

	
	
;;; Print byte to a screen buffer
;;;   takes: X = screen struct ptr, B = byte
;;;   returns: nothing
bufPrint
	pshs	d,u
	jsr	bufScursor
	cmpb	#CR
	beq	cr@		; go do cr
	cmpb	#BS
	beq	bs@
	;; convert underscore
	cmpb	#$5f		; underscore?
	bne	c@		; no then no translate
	ldb	#127
c@	ldu	SCRPOS,x	; U = screen position
	stb	,u+
	ldb	SCRA,x
	stb	,u+
	stu	SCRPOS,x	; save new screen position
	;; increment X position
	ldb	SCRX,x		; get position
	incb			; increment
	cmpb	cpl		; past last column?
	beq	incy@		; no past last column
	stb	SCRX,x		; save position
	bra	out@		; return
	;; increment Y position
incy@	clr	SCRX,x		; reset column
	ldb	SCRY,x		; get line post
	incb			; increment it
	cmpb	SCRM,x		; on max line?
	beq	scroll@		; go scroll
	stb	SCRY,x		; save it
	bra	out@
	;; Scroll
scroll@
	ldu	SCRBEG,x	; begining of screen
	;; move M-1 lines
	lda	SCRM,x		; lines
	deca			; lines - 1
	ldb	cpl
	lslb
	mul			; D = number of bytes to move
	addd	SCRBEG,x	; posititon to stop at
	pshs	d		; push onto stack
a@	ldb	160,u		; get byte from next line
	stb	,u+		; put here and increment
	cmpu	,s		; at end?
	bne	a@		; nope do again
	puls	d		; drop stop address
	;; clear out last line
	lda	cpl
b@	ldb	#$20
	stb	,u+
	ldb	SCRA,x
	stb	,u+
	deca
	bne	b@
	;; reset position
	ldu	SCRPOS,x	; X = old position
	leau	-160,u
	stu	SCRPOS,x	; new position
	;; put cursor and leave
out@	jsr	bufScursor	
	puls	d,u,pc		; restore, return
	;; do a CR
cr@	clra
	ldb	cpl		; D = 80
	subb	SCRX,x		; subtract to get remaining chars in line
	lslb			; convert to position
	addd	SCRPOS,x	; add to position to get new position
	std	SCRPOS,x	; store it
	bra	incy@		; and increment y
	;; do a BS
bs@	ldu	SCRPOS,x	; D = screen position
	cmpu	SCRBEG,x	; are we at beginning?
	beq	out@		; yes then do nothing!
	leau	-2,u		; else adjust screen pos
	stu	SCRPOS,x	;
	ldb	#$20
	stb	,u+
	ldb	SCRA,x
	stb	,u
	dec	SCRX,x		; adjust X
	bmi	bsy@		;
	bra	out@
bsy@	ldb	cpl
	decb
	stb	SCRX,x		; reset X
	dec	SCRY,x		; decrement y
	bra	out@

	
;;; Initializes a screen buffer
;;;   Takes: X = screen struct ptr, B = lines, U=screen begining
;;;   returns: nothing
bufIni
	stu	SCRBEG,x
	clr	SCRC,x
	stb	SCRM,x
	bsr	bufClear
	rts

;;; Print a Zstring to buffer w/ word wrap
;;;   takes: X = screen struct ptr, U = string to print
;;;   returns: nothing
bufWWString
	pshs	d,x,u
	stu	ppos
a@	jsr	getWord		; get a white-space string
	ldx	#word
	jsr	strlen		; B = string length
	beq	ret@		; zero string length - return
	ldx	2,s		; get buffer pointer
	addb	SCRX,x		; add string length to X position
	bcs	cr@		; overflow then do a CR
	subb	cpl		; subtract charactors per line
	bcc	cr@		; overflow then do a CR
	;; no wrap so just print it
b@	ldu	#word
	jsr	bufString	; print it
	jsr	bufSpace
	bra	a@
	;; wrap so do a CR first
cr@	jsr	bufCR
	jsr	bufSpace
	jsr	bufSpace
	bra	b@		; and print string normally
ret@	puls	d,x,u,pc
	
	
;;; Prints a Zstring to buffer
;;;   Takes: X = screen struct ptr, U = string pointer
;;;   returns: nothing
bufString
	pshs	b,u
a@	ldb	,u+
	beq	out@
	jsr	bufPrint
	bra	a@
out@	puls	b,u,pc

	
;;; Clear buffer
;;;   takes: X = screen struct ptr
;;;   returns: nothing
bufClear
	pshs	d,u
	jsr	bufScursor
	clr	SCRA,x
	lda	cpl
	lsla	
	ldb	SCRM,x
	mul
	addd	SCRBEG,x
	pshs	d
	lda	#$20
	ldb	SCRA,x
	ldu	SCRBEG,x
a@	std	,u++
	cmpu	,s
	bne	a@
	puls	d
	ldu	SCRBEG,x
	stu	SCRPOS,x
	clr	SCRX,x
	clr	SCRY,x
	jsr	bufScursor
	puls	d,u,pc

bufScursor
	pshs	b,u
	tst	SCRC,x		; does window have a cursor?
	beq	out@
	ldu	SCRPOS,x
	ldb	1,u
	eorb	#$3f
	stb	1,u
out@	puls	b,u,pc

	
	
;;; Possibly get key from keyboard
getKey
	jsr	$a1cb		; A = get a key?
	beq	out@		; no key leave
	cmpa	#BS
	beq	bs@		; is a BS?
	cmpa	#CR
	beq	cr@		; is a CR?
	cmpa	#$15
	beq	wbs@		; is a Shift-left
	;; add to output buffer
	ldu	opos
	sta	,u+
	stu	opos
echo@	tfr	a,b
	ldx	#kbuf
	jsr	bufPrint
out@	rts
	;; handle backspace
bs@	ldu	opos		; backspace buffer
	cmpu	#obuff		; equal to output buff?
	beq	out@		; yes - don't do anything
	leau	-1,u		; move back
	stu	opos
	bra	echo@
	;; handle CR (send to DW)
cr@	ldu	opos
	clr	,u+
	stu	opos
	jsr	parse
	ldd	#obuff		; reset output buffer
	std	opos
	ldx	#kbuf		; point to keyboard window
	jsr	bufClear	; clear it
	bra	out@
	;; handle a word erase (shift-left)
wbs@	; remove "leading" spaces
	ldu	opos
	cmpu	#obuff
	beq	out@
	ldb	,-u
	cmpb	#$20
	bne	a@
	lda	#BS
	bsr	bs@
	bra	wbs@
	;; remove non spaces
a@	ldu	opos
	cmpu	#obuff
	beq	out@
	ldb	,-u
	cmpb	#$20
	beq	b@
	lda	#BS
	bsr	bs@
	bra	a@
	;; remove trailing spaces
b@	ldu	opos
	cmpu	#obuff
	beq	out@
	ldb	,-u
	cmpb	#$20
	bne	out@
	lda	#BS
	bsr	bs@
	bra	b@
	


;;; Initialize Screen
scrInit
	;; setup gimme
	ldb	#$4c		; coco 3 graphics (reset to $CC)
	stb	$ff90
	ldb	#$03		; text-mode
	stb	$ff98
*	ldb	#$54		; 80 column, no attrib
	ldb	#$15		; 80 column, w/ attributes
	stb	$ff99
	ldd	#$ec00		; $6000 ($76000)
	std	$ff9d
	ldb	#0
	stb	$ffb0
	ldb	#$ff
	stb	$ffb8
	;; setup colors
	ldu	#rgbpal
setpal	ldx	#$ffb8
	lda	#8
a@	ldb	,u+
	stb	,x+
	deca
	bne	a@
	rts
	;; RGB color table
rgbpal	.db	63		; White
	.db	32		; Red
	.db	8		; Blue
	.db	16		; Green
	.db	24		; Cyan
	.db	40		; Magenta
	.db	48		; yellow
	.db	7		; Gray
	;; Composite Table
cmppal	.db	48		; White
	.db	23		; Red
	.db	28		; Blue
	.db	34		; Green
	.db	30		; Cyan
	.db	25		; Magenta
	.db	20		; yellow
	.db	16		; Gray
	


;;; 
;;;
;;;  Drivewire routines
;;;
;;; 
	
	
;;; Open Vport
DWOpen
	ldx	#0x0129
	ldb	#0xc4
	pshs	b,x
	tfr	s,x
	ldy	#3
*	SCALL	SDWWRITE
	jsr	[DWWrite]
	leas	3,s
	rts

;;; Close Vport
DWClose
	ldx	#0x012a
	ldb	#0xc4
	pshs	b,x
	tfr	s,x
	ldy	#3
*	SCALL	SDWWRITE
	jsr	[DWWrite]
	leas	3,s
	rts
	

;;; Send input buffer to DW
DWSend
	;; calc buffer size
	ldd	opos		; D = end
	subd	#obuff		; subtract start = size
	stb	dwno		; save in packet
	;; send buffer to DW
	addd	#3		; add three byte packet
	tfr	d,y		; number of byte to send in Y
	ldx	#dwbuf		; buffer
*	SCALL	SDWWRITE	; send!
	jsr	[DWWrite]
	;; reset output buffer
	ldd	#obuff		; D = start
	std	opos		; save to pos pointer
	;; cls screen

	rts			; return

;; Print reply from DW
DWReply
	tst	dwsq		; are we squelching?
	beq	cont@		; no then read
	ldd	timer		; get timer
	cmpd	$112		; are we bigger?
	bcc	ret@		; not time just return
	com	dwsq		; turn off squalching and read
cont@	lda	#0x43		; Poll/Read op code
	pshs	d		; push onto stack
	tfr	s,x		; setup for DW write
	ldy	#1		;
*	SCALL	SDWWRITE	; send to DW
	jsr	[DWWrite]
	tfr	s,x		; setup for read status
	ldy	#2
*	SCALL	SDWREAD		; get status bytes
	jsr	[DWRead]
	bcs	err2@		; error on timeout
	bne	err2@		; error on framing
	lda	,s		; get byte1
	bne	e@		; branch if not zero
	;; return nothing to read
	puls	d		; drop stack buffer
	com	dwsq		; squelch dw poller
	ldd	$112		; get time
	addd	#30		; squelch for 30 ticks
	bcc	a@		; if no carry then ok to set
	;; timer overflowed, skip squelch
	com	dwsq	        ; turn squelching off
a@	std	timer		; save squelch time
ret@	rts			; return
	;; something to read
e@	clr	dwsq	        ; turn off squelching  
	cmpa	#16		; compare to #16
	blo	sin@		; is lower than a single byte read
	bhi	mul@		; is higher than multi byte read
	;; close port & return
	;; closing the port is not specified by DW
	;; but DW will hang if we don't
	puls	d		; is same so close port
	jsr	DWClose
	jsr	DWOpen
	rts
	;; receive a single byte
sin@	puls	d
	jsr	ibufput
	rts			; return
	;; receive multiple bytes
mul@	clr	,s
	inc	,s
	lda	#0x63
	pshs	a
	tfr	s,x
	ldy	#3
*	SCALL	SDWWRITE
	jsr	[DWWrite]
	ldx	#DBUF0
	ldb	2,s
	clra
	tfr	d,y
*	SCALL	SDWREAD
	jsr	[DWRead]
	bcs	err3@
	bne	err3@
	puls	cc,d
	exg 	a,b
	ldx	#DBUF0
d@	ldb	,x+
	jsr	ibufput
	deca
	bne	d@
	rts			; return
err3@	leas	1,s
err2@	leas	2,s
	rts


YDWRead
	SCALL	SDWREAD
	rts

YDWWrite
	SCALL 	SDWWRITE
	rts


	
;;;
;;;
;;;  IRC Command routines
;;;
;;; 


;;; Command name vector table

tserver	fcn	"server"
tjoin	fcn	"join"
tuser	fcn	"user"
tme	fcn	"me"
tquit	fcn	"quit"
tnick	fcn	"nick"
tmsg	fcn	"msg"
tnames	fcn	"names"
tcmp	fcn	"cmp"
trgb	fcn	"rgb"
texit	fcn	"exit"
	
cmdtab	.dw	tserver
	.dw	cserver

	.dw	tjoin
	.dw	cjoin

	.dw	tuser
	.dw	cuser

	.dw	tme
	.dw	cme

	.dw	tquit
	.dw	cquit

	.dw	tnick
	.dw	cnick

	.dw	tmsg
	.dw	cmsg

	.dw	tnames
	.dw	cnames

	.dw	tcmp
	.dw	ccmp

	.dw	trgb
	.dw	crgb

	.dw	texit
	.dw	cexit
	
	.dw	0


;;; Get a command word from input buffer
;;;    takes: ppos=start of input buffer
;;;    returns: word=parsed command
getWord pshs	d,x,u
	ldx	ppos		; X = start of output buffer
	ldu	#word		; start of word buffer
	;; remove spaces
b@	ldb	,x		; get byte
	beq	out@		; is zero copy byte
	cmpb	#$20		; is space or less?
	bhi	a@		; no then copy bytes
	leax	1,x		; yes then get next byte
	bra	b@
	;; copy byte to word buffer
a@	ldb	,x		; get a byte
	cmpb	#$20		; is space (or less?)
	bls	out@		; done!
	stb	,u+
	leax	1,x
	bra	a@
out@	clr	,u		; put a zero in word buffer
	stx	ppos		; save parse position
	puls	d,x,u,pc	; restore return


;;; Compares two strings
;;;   takes: X=string, U=string
;;;   returns: Z set on string equality
strcmp	pshs	d,x,u
a@	ldb	,x+
	cmpb	,u+
	bne	out@
	tstb
	beq	out@
	bra	a@
out@	puls	d,x,u,pc


;;; Find length of string
;;;   takes: X=string
;;;   returns: B = size of string
strlen	pshs	x
	clrb
a@	tst	,x+
	beq	out@
	incb
	bra	a@
out@	tstb
	puls	x,pc

	
	
;;; Append string xmit buffer
;;;   takes: X = ptr to string
appString
	pshs	b,x,u
	;; copy to xmit buffer
	ldu	xpos		; transmit buffer
a@	ldb	,x+
	beq	out@
	stb	,u+
	bra	a@
out@	stu	xpos		; save buffer pos
	puls	b,x,u,pc	; return

;;; Append a byte to xmit buffer
appByte
	pshs	u
	ldu	xpos
	stb	,u+
	stu	xpos
	puls	u,pc

;;; Append a space to xmit buffer
appSpace
	pshs	b
	ldb	#$20
	bsr	appByte
	puls	b,pc

;;; Append crlf to xmit buffer
appCRLF
	pshs	b
	ldb	#CR
	bsr	appByte
	ldb	#$a
	bsr	appByte
	puls	b,pc

;;; send xmit buffer to DW
send
	pshs	d,x,y
	ldd	xpos		; end address
	subd	#xmitb		; sub start address; D = length
	stb	dwno		; save length in xmit prefix
	addd	#3		; add 3 to length = total DW length
	tfr	d,y		; put in Y
	ldx	#dwbuf		; X = DW packet buffer
*	SCALL 	SDWWRITE	; send to DW
	jsr	[DWWrite]
	;; reset xmit buffer
	ldd	#xmitb
	std	xpos
	puls	d,x,y,pc

	
parse
	ldb	obuff		; get first char
	beq	empty@		; empty string do not process
	cmpb	#'/		; is a command?
	beq	command		; go parse command
	;; echo to main window
	ldx	#mbuf
	ldb	#GREEN
	jsr	bufFcolor
	ldu	#nick
	jsr	bufString
	jsr	bufSpace
	ldb	#WHITE
	jsr	bufFcolor
	ldu	#obuff
	jsr	bufWWString
	jsr	bufCR
	;; send privmsg
	ldx	#privmsg@
	jsr	appString
	jsr	appSpace
	ldx	#chan
	jsr	appString
	jsr	appSpace
	ldb	#':
	jsr	appByte
	ldx	#obuff
	jsr	appString
	jsr	appCRLF
	jmp	send
empty@	rts
privmsg@	fcn	"PRIVMSG "


;;; find command in table
command
	ldd	#obuff+1	; set parse pos to after "/"
	std	ppos
	jsr	getWord		; parse word into buffer
	ldu	#word		; U = word buffer
	ldy	#cmdtab		; first command
a@	ldx	,y		; X is string pointer
	beq	err@		; end of table
	jsr	strcmp		; match?
	beq	match@		; yup
	leay	4,y		; goto next command
	bra	a@
match@	ldy	2,y		; get vector
	jmp	,y		; jmp to it!
	;; else just pass through!
err@	ldx	#obuff+1
	jsr	appString
	ldb	#CR
	jsr	appByte
	jmp	send

	;; /server command
cserver
	ldx	#p@
	jsr	appString
	jsr	getWord		; parse hostname
	ldx	#word
	jsr	appString
	jsr	appSpace
	jsr	getWord		; parse tcp port
	tst	,x		; is null?
	bne     a@
	ldx	#p1@		; get default port
a@	jsr	appString	; append port number
	ldb	#CR
	jsr	appByte
	jmp	send
p@	fcn	"tcp connect "
p1@	fcn	"6667"
	

	;; /join command
cjoin
	ldx	#obuff+1
	jsr	appString
	jsr	appCRLF
	jsr	send
	;; get channel name
	jsr	getWord
	ldx	#word		; source is parse position
	ldu	#chan		; dest is chan name buffer
a@	ldb	,x+
	stb	,u+
	bne	a@
	jsr	drawStatus
	rts

	;; /user command (/user name nick)
cuser	; send user command
	ldx	#p1@
	jsr	appString
	jsr	getWord
	ldx	#word
	jsr	appString
	ldx	#p2@
	jsr	appString
	ldx	#word
	jsr	appString
	jsr	appCRLF
	jsr	send
	;; send nick command
	ldx	#p3@
	jsr	appString
	jsr	getWord
	ldx	#word
	jsr	appString
	;; copy nick to saved buffer
	ldu	#nick
a@	ldb	,x+
	stb	,u+
	bne	a@
	;; continue building nick command
	jsr	appCRLF
	jsr	send
	jmp	drawStatus
p1@	fcn	"USER "
p2@	fcn	" 0 * "
p3@	fcn	"NICK "

	;; /me action
cme	ldx	#privmsg@
	jsr	appString
	jsr	appSpace
	ldx	#chan
	jsr	appString
	jsr	appSpace
	ldb	#':
	jsr	appByte
	ldx	#p2@
	jsr	appString
	ldx	ppos
	jsr	appString
	ldb	#1
	jsr	appByte
	jsr	appCRLF
	jmp	send
privmsg@	fcn	"PRIVMSG "
p2@	.db	$1
	fcn	"ACTION"

	;; /msg action
cmsg	ldx	#p1@
	jsr	appString
	jsr	getWord
	ldx	#word
	jsr	appString
	jsr	appSpace
	ldb	#':
	jsr	appByte
	ldx	ppos
	jsr	appString
	jsr	appCRLF
	jsr	send
	;; print to output
	ldx	#mbuf
	ldb	#RED
	jsr	bufFcolor
	ldu	#p2@
	jsr	bufString
	ldu	#obuff
	stu	ppos
	jsr	getWord		; parse off "/msg"
	jsr	getWord		; parse off "nick"
	ldu	#word		; print nick
	jsr	bufString
	jsr	bufSpace
	ldb	#WHITE
	jsr	bufFcolor
	ldu	ppos		; point to message after nick
	jsr	bufWWString	; print
	jmp	bufCR		;
p1@	fcn	"PRIVMSG "
p2@	fcn	"!!!->"

	;; /quit action
cquit	; send quit message
	ldx	#p@
	jsr	appString
	ldb	#':
	jsr	appByte
	ldx	ppos
	leax	1,x		; skip space
	jsr	appString
	jsr	appCRLF
	jsr	send
	;; and close connect to server
	jsr	DWClose		; close DW vport
	jsr	DWOpen		; reopen DW vport
	;; reset status line
	clr	nick
	clr	chan
	jsr	drawStatus
	rts			; return to BASIC
p@	fcn	"QUIT "

	;; /nick action
cnick	; send whole string minus / to server
	ldx	#obuff
	leax	1,x
	jsr	appString	; append whole string
	jsr	appCRLF
	jsr	send
	;; rip nickname from string
	jsr	getWord		; get nickname
	ldx	#word
	ldu	#nick
a@	ldb	,x+
	stb	,u+
	bne	a@
	jsr	drawStatus
	rts			; return


	;; /names action
cnames	; send "/names to server"
	ldx	#p@
	jsr	appString
	jsr	getWord
	tst	word
	beq	a@
	ldx	#word
	bra	b@
a@	ldx	#chan
b@	jsr	appString
	jsr	appCRLF
	jsr	send
	rts			; return
p@	fcn	"NAMES "


	;; /cmp action
ccmp	ldu	#cmppal
	jmp	setpal

	;; /rgb action
crgb	ldu	#rgbpal
	jmp	setpal


	;; quit the program
cexit	; send quit message
	jsr	DWClose		; close DW vport
	puls	d,x		; drop getKey and start's return address
	clr	$11a		; reset keyboard to uppercase
	com	$11a
	rts
p@	fcn	"QUIT "


	
	
	
;;;
;;;
;;; Status line
;;;
;;; 





	
strcpy
a@	ldb	,x+
	stb	,u+
	bne	a@
	rts
	
drawStatus
	ldx	#sbuf		; status buffer
	jsr	bufClear
	ldb	#GRAY
	jsr	bufFcolor
	ldu	#p1@
	jsr	bufString	; print string
	;; put nick name
	ldb	#WHITE
	jsr	bufFcolor
	ldb	#3
	stb	SCRX,x
	clra
	lslb
	addd	SCRBEG,x
	std	SCRPOS,x
	ldu	#nick
	jsr	bufString	; print string
	;; put channel no
	ldb	#40
	stb	SCRX,x
	clra
	lslb
	addd	SCRBEG,x
	std	SCRPOS,x
	ldu	#chan
	jsr	bufString	; print channel
	rts
p1@	fcc	"!-------------------"
	fcc	"--------------------"
	fcc	"--------------------"
	fcn	"------------------!"
	

;;;
;;;
;;;	IRC Server Message Processing
;;;
;;;

	;; server message commands

tpriv	fcn	"PRIVMSG"
tping	fcn	"PING"
t366	fcn	"366"		; end of names list
t375	fcn	"375"		; start of MOTD
t376	fcn	"376"		; end of MOTD
t372	fcn	"372"		; MOTD line
tjoin2	fcn	"JOIN" 		; someone joined
tpart	fcn	"PART"		; someone left
tnick2	fcn	"NICK"		; someone changed nickname
t353	fcn	"353"		; names reply
tquit2	fcn	"QUIT"		; quit reply
ttopic2	fcn	"TOPIC"		; topic change
ttopic3	fcn	"331"		; no topic
ttopic4	fcn	"332"		; no topic
ttopic5	fcn	"333"		; topic set by
	
icmdtab	.dw	tpriv
	.dw	cpriv

	.dw	tping
	.dw	cping

	.dw	t366
	.dw	drop

	.dw	t375
	.dw	drop

	.dw	t376
	.dw	drop

	.dw	t372
	.dw	c372

	.dw	tjoin2
	.dw	cjoin2

	.dw	tpart
	.dw	cpart

	.dw	tnick2
	.dw	cnick2

	.dw	t353
	.dw	c353

	.dw	tquit2
	.dw	cquit2

	.dw	ttopic2
	.dw	ctopic2

	.dw	ttopic3
	.dw	ctopic3

	.dw	ttopic4
	.dw	ctopic3

	.dw	ttopic5
	.dw	drop
	
	.dw	0
	
	
;;; puts byte into input buffer, parsing if necissary
;;;   Takes: B = byte to push
ibufput
	pshs	x
	ldx	ipos		; get position
	cmpb	#$a		; is a LF (end of line?)
	beq	eol@		; go handle end of line
	stb	,x+		; store the byte
	stx	ipos		; save position for next call
	puls	x,pc
eol@	clr	,x		; store a zero for good luck
	jsr	mparse		; parse the input buffer
	ldx	#ibuff		; reset the input buffer
	stx	ipos
	puls	x,pc
	
;; parses input
mparse	pshs	d,x,y,u
	;; setup parser
	ldd	#ibuff		; input buffer
	std	ppos		; parse position
	;; test for prefix
	ldb	ibuff
	cmpb	#':		; is a prefix?
	bne	a@		; no then parse this as command
	jsr	getWord		; get prefix
a@	jsr	getWord		; get command
	;; else is a command
	ldu	#word		; U = point at word buffer
	ldy	#icmdtab	; Y = server cmd table
b@	ldx	,y		; X = cmd string
*	beq	nf@		; command not found
	beq	reply@
	jsr	strcmp		; is this the command?
	beq	found@		; yup
	leay	4,y		; goto next command
	bra	b@
found@	ldy	2,y		; process command
	jmp	,y		; do it
reply@
	ldb	word
	cmpb	#'4		; is a four?
	beq	printerr
	jsr	getWord		; get channel no
	ldx	#mbuf		; main window
	ldb	#GRAY
	jsr	bufFcolor
*	ldu	ppos		; get messsage
	ldu	#ibuff
	leau	1,u		; skip " :"
	jsr	bufString	; print it to screen
	puls	d,x,y,u,pc	; return


	;; handle generic error message
printerr
	jsr	getWord		; drop nickname
	ldx	#mbuf
	ldb	#RED
	jsr	bufFcolor
	ldu	ppos
	leau	1,u
	jsr	bufString
	puls	d,x,y,u,pc	;return


	;; Print name w/ color hashing
	;;   takes: U = name string (end in 0 or ! )
	;;   takes: X = output buffer
	;;   returns: nothing
nprint
	;; hash for color
	pshs	b,u		; save regs
	clr	,-s		; push a accum
a@	ldb	,u+		; get a name byte
	beq	out@		; is end?
	cmpb	#'!		; is end?
	beq	out@		;
	addb	,s		; add and store to accum
	stb	,s
	bra	a@		; repeat
out@	puls	b		; pull accum
c@	subb	#6		; subtract six
	bcc	c@
	addb	#7
	jsr	bufFcolor	; set the color
	ldu	1,s		; reset U
b@	ldb	,u+		; get a name byte
	beq	out2@		; is end?
	cmpb	#'!		; is end?
	beq	out2@		;
	jsr	bufPrint	; print it
	bra	b@		; repeat
out2@	puls	b,u,pc		; restore, return
	

	;; handle private messsage
cpriv	
	ldx	#mbuf		; print to main window
	ldb	#GREEN
	jsr	bufFcolor
	;; reset parse position
	ldu	#ibuff		; X = imput buffer
	stu	ppos		; parse 
	;; parse and print nick
	jsr	getWord		; get nick/who field
	ldu	#word+1
	jsr	nprint
	;; is a channel message or private?
	jsr	getWord		; parse off command
	jsr	getWord		; parse off channel
	ldb	word		; get first char of recepient
	cmpb	#'#		; is a "#" ?
	beq	chan@
	cmpb	#'&		; is a "&" ?
	beq	chan@
	cmpb	#'+		; is a "+" ?
	beq	chan@
	cmpb	#'!		; is a "!" ?
	beq	chan@
	;; print a private message
	ldb	#RED
	jsr	bufFcolor
	ldu	#p@
	jsr	bufString
	bra	a@
	;; print channel message
chan@	ldb	#WHITE
	jsr	bufFcolor
	jsr	bufSpace	; print space
a@	ldu	ppos		; get parse position
	leau	2,u		; remove space and ":"
	jsr	bufWWString	; and print the string!
	jsr	bufCR		; print a CR
	puls	d,x,y,u,pc	; return!
p@	fcn	"<-!!! "

	;; handle ping message
cping
	ldx	#p@		; point to pong message
	jsr	appString	; append
	ldx	ppos		; parse position
	jsr	appString	; append server name
	jsr	appCRLF		; append CR/LF
	jsr	send		; send to server
	puls	d,x,y,u,pc	; return!
p@	fcn	"PONG "
	

	;; do nothing with a message
drop
	puls	d,x,y,u,pc


	;; MOTD line
c372	ldx	#mbuf
	ldb	#BLUE
	jsr	bufFcolor
	jsr	getWord
	ldu	ppos		; get messsage
	leau	2,u		; skip " :"
	jsr	bufString	; print it to screen
	puls	d,x,y,u,pc

	;; join line
cjoin2	jsr	pnick
	ldu	#p@
	jsr	bufString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	" joined channel"

	;; part line
cpart	jsr	pnick
	ldu	#p@
	jsr	bufString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	" left channel"


	;; nick line
cnick2	jsr	pnick
	ldu	#p@
	jsr	bufString
	jsr	getWord
	ldu	#word+1
	jsr	bufString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	" is now known as "


	
	;; print nick predicate
pnick
	ldx	#mbuf
	ldb	#GRAY
	jsr	bufFcolor
	ldu	#ibuff+1
a@	ldb	,u+
	cmpb	#'!
	beq	out@
	jsr	bufPrint
	bra	a@
out@	rts


	;; print user quit message
cquit2
	jsr	pnick
	ldu	#p@
	jsr	bufString
	ldu	ppos
a@	ldb	,u+
	cmpb	#':
	bne	a@
	jsr	bufString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	" has quit: "
	

	;; names reply
c353	ldx	#mbuf
	ldb	#GRAY
	jsr 	bufFcolor
	ldu	#p@
	jsr	bufString
	ldu	ppos
a@	ldb	,u+
	cmpb	#':
	bne	a@
	jsr	bufWWString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	"names: "


	;; topic change
ctopic2	jsr	pnick
	ldu	#p@
	jsr	bufString
	ldu	ppos
a@	ldb	,u+
	cmpb	#':
	bne	a@
	jsr	bufString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	" changed topic to: "

	;; topic rply message
ctopic3	ldx	#mbuf
	ldu	#p@
	jsr	bufString
	ldu	ppos
a@	ldb	,u+
	cmpb	#':
	bne	a@
	jsr	bufWWString
	jsr	bufCR
	puls	d,x,y,u,pc
p@	fcn	"Channel topic: "

	
	
	end	start