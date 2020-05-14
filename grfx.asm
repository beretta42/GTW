;;;
;;;  GTW graphics engine
;;;
;;;
	org	$0
P_NO	rmb	1		; player number
P_STATE rmb	1		; player state
P_MX	rmb	2		; player missle X coord
P_MY	rmb	2		; player missle Y coord
P_X	rmb	1		; player X coord
P_Y	rmb	1		; player Y coord
P_VX	rmb	2		; player missle X velocity
P_VY	rmb	2		; player missle Y velocity
P_NAME	rmb	16		; player name
P_SCORE	rmb	2		; player score
P_AVA	rmb	1		; player's avatar no.
P_HP	rmb	1		; hit points
P_Z	equ	*		; size of struct

ST_MISS	equ	$1		; player missle is live
ST_ACT	equ	$2		; player slot is active

K_SPACE equ	$1
K_RIGHT equ	$2
K_LEFT	equ	$4
K_DOWN	equ	$8
K_UP	equ	$10
K_Z	equ	$20
K_Y	equ	$40
K_X	equ	$80

PSCR	equ	$3800
SSCR	equ	PSCR+$1800

BLUE	equ	%10101010
RED	equ	%01010101
WHITE	equ	%11111111
BLACK	equ	%00000000
	
	org	$1000

task	.dw	stack1p
stack1p	zmb	128		; our comm task
stack1  
stack2p	zmb	128		; our graphic engine task
stack2

	
bstack	.dw	0		; saved entry stack
mode	.db	0		; time-sclicer mode state
ptab	zmb	P_Z*8		; table of known players
grav	.dw	$0004		; force of gravity in acc
keys	.db	0		;
okeys	.db	0		; old key set from previous sample
power	.dw	$40		; initial force
angle	.db	0		; angle of initial force
ud_ang	zmb	6
nick	zmb	16		; our nickname
cmode	.db	0		; client mode
serverf	.db	0		; server flag
tnick	zmb	16		; temporary holder for nick
me	.dw	0		; my player struct
lastrnd	.dw	1		; random number seed
init_mode
	.db	0		; state of init code
shot	.db	0		; shot timer
in_mode	.db	1		; state of input
conmode	.db	0		; connect mode
btimer  .db	0		; blink counter
lift	.dw	10*20		; lift timer

	
logmem	fill	32,475		; 25 x 19 log screen
lpos	.dw	logmem+450	; current pos of log
lcol	.db	0		; column of cursor
spos	.dw	0		; current pos of score screen
	.db	0		; mod pos of score screen
npos	.dw	0		; saved beginning of current line
	
;;; process map
mapptr	.dw	pmap		; a stack of free client slots
pmap	.db	0
	.db	1
	.db	2
	.db	3
	.db	4
	.db	5
	.db	6
	.db	7
	
;;; terrain map
	.db	18		; leave this be. makes terrain building easier
terrain
	zmb	32		; sky/terrain Y pos for each fat pixel
pfield
	zmb	32		; for each fat pixel, 0=empty, 1-8 player no


;;; missle mask
misstab
	.db	%11000000
	.db	%00110000
	.db	%00001100
	.db	%00000011


	
;;; sin lookup - this table represents
;;;  a sine ratio in degrees, each value
;;;  is represented as a fractional part
;;;  to 8 binary places.
sintab
	.db	0
	.db	4
	.db	9
	.db	13
	.db	18
	.db	22
	.db	27
	.db	31
	.db	36
	.db	40
	.db	44
	.db	49
	.db	53
	.db	58
	.db	62
	.db	66
	.db	71
	.db	75
	.db	79
	.db	83
	.db	88
	.db	92
	.db	96
	.db	100
	.db	104
	.db	108
	.db	112
	.db	116
	.db	120
	.db	124
	.db	128
	.db	132
	.db	136
	.db	139
	.db	143
	.db	147
	.db	150
	.db	154
	.db	158
	.db	161
	.db	165
	.db	168
	.db	171
	.db	175
	.db	178
	.db	181
	.db	184
	.db	187
	.db	190
	.db	193
	.db	196
	.db	199
	.db	202
	.db	204
	.db	207
	.db	210
	.db	212
	.db	215
	.db	217
	.db	219
	.db	222
	.db	224
	.db	226
	.db	228
	.db	230
	.db	232
	.db	234
	.db	236
	.db	237
	.db	239
	.db	241
	.db	242
	.db	243
	.db	245
	.db	246
	.db	247
	.db	248
	.db	249
	.db	250
	.db	251
	.db	252
	.db	253
	.db	254
	.db	254
	.db	255
	.db	255
	.db	255
	.db	255
	.db	255
	.db	255
	.db	255


	
start
	pshs	cc
	;; get setup
	;; setup main window screen
	ldx	#$ffc0		; is SAM mode
	sta	,x		; 0
	sta	3,x		; 1  - to sam
	sta	5,x		; 1
	lda	#$f8		; 1,1,1,1, ccs=1  to vdg
	sta	$ff22
	;; set video address
	ldx	#$ffc6		; is SAM address
	sta	,x		; 0
	sta	2,x		; 0
	sta	5,x		; 1
	sta	7,x		; 1 = 8
	sta	9,x		; 1
	sta	10,x		; 0
	sta	12,x		; 0 = 0x18 = $3000
	;; get setup info from human
	jsr	setup
	orcc	#$50		; turn off interrupts
	jsr	DWInit
	;; init random seed
	ldd	$112
	std	lastrnd
	;; if we're a server, setup terrain map
	tst	serverf
	beq	c@
	ldx	#terrain
d@	jsr	random
	tstb
	pshs	cc
	andb	#7
	puls	cc
	bpl	f@
	negb
f@	addb	-1,x
	cmpb	#23
	bhs 	d@
	cmpb	#2
	blo	d@		
*	ldb	#23		; flat terrain override!!!!!
	stb	,x+
	cmpx	#terrain+32
	bne	d@
	;; push irq interrupt vector
c@	lda	$10c
	ldx	$10d
	pshs	a,x
	sts	bstack
	;; install our interrupt
	lda	#$7e		; jmp 
	ldx	#irq		; to irq
	sta	$10c
	stx	$10d
	;; set low speed
*	ldx	#$ffd6
*	sta	,x		; R = 0 0
*	sta	2,x
	;; check for CoCo3
*	ldb	$fffc		; get MSB of NMI Vector
*	cmpb	#$fe		; is coco3?
*	lbne	err@		; no then error
cont@	;; setup keyboard
*     	clr	$11a		; lower case
	;; clear screen
	ldx	#PSCR		; base of screen buffer
	ldd	#0
a@	std	,x++
	cmpx	#PSCR+$1800	; check for end of screen
	bne	a@		; loop if not done
	;; draw status line
	jsr	draw_status
	;; draw terrain if master
	tst	serverf
	beq	e@
	jsr	draw_terrain
	;; make and draw me if master
*	jsr	join_game
	;; loging to IRC channel
e@
*	jsr	splash
	jsr	comm_init
	;; loop foreva
	lds	#stack1		; setup us as task1
	;; make stack for engine task
	ldu	#stack2		
	ldx	#update
	pshu	x
	leau	-9,u
	ldb	#$80
	pshu	b
	stu	stack2p		; setup update as task2
	andcc	#~$10		; turn on interrupts
	jmp	docom0


;;; get a new player slot no.
alloc_no
	pshs	x
	ldx	mapptr		; x is stack
	ldb	,x+
	stx	mapptr
	puls	x,pc


;;; free a player no.
free_no
	pshs	x
	ldx	mapptr
	stb	,-x
	stx	mapptr
	puls	x,pc

;;; get a random number (sure...)
;;;  takes: nothing, seed in lastrnd
;;;  returns: D = random
random
	ldd	lastrnd		; get state of random
	lsra
	rorb
	bcc	out@
	eora	#$b4
out@	std	lastrnd
	rts


;;; draw power / angle
draw_status
	pshs	d,x
	ldb	#WHITE
	stb	colorm
	;; clear top line
	clra
	ldx	#PSCR
a@	clr	,x+
	deca
	bne	a@
	;; set screen text pos
	ldx	#PSCR
	clr	mod
	;; print power
	ldd	power
	jsr	putd
	;; print angle
	ldx	#PSCR+$10
	clr	mod
	ldb	angle
	sex			; Whoopie!
	jsr	putsd
	puls	d,x,pc
	
	

;;; draw terrain
draw_terrain
	;; setup X loop
	ldb	#32
	ldx	#PSCR+$1700
	pshs	b,x
	ldu	#land
	ldy	#terrain
	;; setup Y loop
b@	ldb	#24
	subb	,y+
	pshs	b
	;; apply
a@	jsr	putplayer
	;; incr Y loop
	leax	-256,x
	dec 	,s
	bne	a@
	;; incr X loop
	leas	1,s
	ldx	1,s
	leax	1,x
	stx	1,s
	dec	,s
	bne	b@
	;; clean up
	leas	3,s
	rts



;;; Draw IRC log
;;;   modifies: nothing
draw_log
	pshs	cc,d,x,y,u
	orcc	#$50
	;; clear screen
	jsr	clr_sscr
	;; draw log buffer to screen
	ldx	#SSCR
	ldu	#logmem
	lda	#19
	pshs	a,x		; push row counter, screen address
c@	clr 	mod
	lda	#25
b@	ldb	,u+
	pshs	a
	jsr	putb
	jsr	inc5
	puls	a
	deca
	bne	b@
	;; inc line
	ldx	1,s
	leax	288,x		; drop by 9 lines
	stx	1,s
	dec	,s		; bump row counter
	bne	c@		; row loop if not done
	;; done looping
	leas	3,s		; drop row, screen address
	;; change display address to $4800
	jsr	draw_sscr
	puls	cc,d,x,y,u,pc


;;; print a string to log
;;;  takes: X ptr
putlogs
	pshs	b,x
a@	ldb	,x+
	beq	out@
	jsr	putlog
	bra	a@
out@	puls	b,x,pc


crlog
	pshs	d
	lda	lcol		; get number of columns remaining
	ldb	#32		; print a space
a@	jsr	putlog
	deca
	bne	a@
	ldb	#25		; reset number of columns
	stb	lcol
	puls	d,pc
	
;;; print a byte to log
;;;   takes: B byte
putlog
	pshs	d,x,u
	ldx	lpos
	stb	,x+
	cmpx	#logmem+475
	bhs	scr@
	stx	lpos
	dec	lcol
	puls	d,x,u,pc
scr@	orcc	#$10
	ldx	#logmem+25
	ldu	#logmem
	ldb	#18
	pshs	b
	;; 8 bytes
a@	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	;; 8 bytes
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	;; 8 bytes
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	;;  1 byte
	lda	,x+
	sta	,u+
	dec	,s		; bump counter
	bne	a@
	andcc	#~$10
	leas	1,s		; drop counter
	ldx	#logmem+450	; space out last line
	ldb	#32
	lda	#25
b@	stb	,x+
	deca
	bne	b@
	ldx	#logmem+450	; reset lpos
	stx	lpos
	ldb	in_mode
	cmpb	#2
	bne	out@
	;; redraw screen
	jsr	draw_log
out@	puls	d,x,u,pc	; return

	

	

;;; draw player score
;;;   takes: X/mod = screen pos, U = player struct
;;;   modifies: nothing
draw_score
	pshs	d,x,u
	;; check for active slot
	ldb	P_STATE,u
	andb	#ST_ACT
	beq	a@		; not active
	;; draw avatar
*	ldb	P_AVA,u
	ldb	P_NO,u		; until we have avatars
	incb			;
	lda	#8
	mul
	addd	#playertab
	tfr	d,u
	jsr	putplayer
	;; draw name
	ldx	2,s
	leax	3,x
	clr	mod
	ldu	4,s
	leau	P_NAME,u
	jsr	puts
	;; draw score
	ldx	2,s
	leax	20,x
	clr	mod
	ldu	4,s
	ldd	P_SCORE,u
	jsr	putd
	;; draw HP
	ldx	2,s
	leax	26,x
	clr	mod
	clra
	ldb	P_HP,u
	jsr	putd
b@	puls	d,x,u,pc
	;; not active
a@	ldu	#p0@
	jsr	puts
	bra	b@
p0@	fcn	"Empty"
	
;;; Draw player scores
draw_scores
	pshs	cc,d,x,y,u
	orcc	#$50
	;; clear screen
	jsr	clr_sscr
	;; print header
	ldb	#%01010101
	stb	colorm
	ldx	#SSCR
	ldu	#p0@
	jsr	puts
	;; draw all scores to screen
	ldx	#SSCR+(2*256)
	ldu	#ptab
	ldb	#8
b@	clr	mod
	jsr	draw_score
	leax	384,x
	leau	P_Z,u
	decb
	bne	b@
	;; draw then menu ( X = screen ptr)
	jsr	draw_menu
	puls	cc,d,x,y,u,pc
p0@	fcn	"--= Players =--"


	;; keyboard scanning for play mode
play_update
	clr	,-s		; push flag for angle redraw
	;; copy keys to old
	ldb	keys
	stb	okeys
	;; get keys
	clr	keys
	ldb	#$fe
b@	stb	$ff02
	lda	$ff00
	coma
	rora
	rora
	rora
	rora
	rol	keys
	rolb
	orb	#1
	bcs	b@
	;; process keys
	lda	keys
	lbeq	i@
	;; angle right	
	tfr	a,b
	andb	#K_RIGHT
	beq	c@
	ldb	angle
	addb	#2
	cmpb	#89
	bgt	c@
	inc	,s
	stb	angle
	;; angle left
c@	tfr	a,b
	andb	#K_LEFT
	beq	d@
	ldb	angle
	subb	#2
	cmpb	#-89
	blt	d@
	inc	,s
	stb	angle
	;; power up
d@	tfr	a,b
	andb	#K_UP
	beq	e@
	inc	,s
	ldd	power
	cmpd	#400		; high limit power (was 280)
	bgt	h@
	addd	#4
	std	power
	bra	i@
	;; power down
e@	tfr	a,b
	andb	#K_DOWN
	beq	f@
	inc	,s
	ldd	power
	beq	f@
	subd	#4
	std	power
	bra	i@
	;; space
f@	tfr	a,b
	andb	#K_SPACE
	beq	g@
	jsr	do_space
	bra	k@
	;; Y key
g@	tfr	a,b
	andb	#K_Y
	beq	w@
	jsr	quit1
	;; Z key
w@	tfr	a,b
	andb	#K_Z
	beq	h@
	ldx	#nuke_anim
	stx	anim
	ldx	me
	stx	anim+2
	ldb	#1
	jsr	sound
	bra	k@
	;; X key
h@	tfr	a,b
	andb	#K_X
	beq	i@
	ldb	okeys
	bitb	#K_X
	bne	i@
	jsr	inc_inmode
	bra	k@
	;; update angle display
i@	tst	,s
	beq	k@
	jsr	display_angle
	jsr	draw_status
k@	leas	1,s
	rts


	;; keyboard scanning for menu mode
menu_update
	pshs	d,x
	jsr	$a1cb		; basic keyboard scan
	beq	out@
	cmpa	#$5e		; up arrow?
	beq	up@
	cmpa	#$0a		; down arrow?
	beq	down@
	cmpa	#'X		; X?
	bne	z@
	jsr	inc_inmode
	bra	out@
z@	cmpa	#$20		; is a space
	beq	do_menu_space
out@	puls	d,x,pc
up@	tst	menu_select
	beq	out@
	dec	menu_select
	jsr	draw_mind
	bra	out@
down@	ldb	menu_select
	cmpb	#3
	beq	out@
	inc	menu_select
	jsr	draw_mind
	bra	out@
do_menu_space
	ldb	menu_select
	cmpb	#1		; quit?
	bne	a@		; next test
	jsr	quit1
	bra	out@
a@	cmpb	#0		; join/leave toggle
	beq	do_toggle
	cmpb	#3		; restart?
	lbeq	restart
	cmpb	#2		; is 2?
	lbeq	watch@
	ldb	#5
	stb	shot
	jsr	draw_play
c@
	bra	out@
do_toggle
	;; enable a lock-out here !!!!
	tst	cmode
	bne	stop@	
	;; start playing
	jsr	join_game
	tst	serverf
	beq	b@
	jsr	set_blink
	ldx	me
	jsr	send_ack
b@	jsr	send_basic
*	jsr	clr_pscr	; fixme: ok for clients not for server
	jsr	draw_play
	clr	in_mode
	ldx	#m3
	stx	mstr
	jsr	draw_menu
	bra	out@
	;; stop playing
stop@	ldx	me
	orcc	#$10
	ldx	#p0@
	jsr	appString
	ldx	me
	ldb	P_NO,x
	jsr	appHex
	jsr	appCRLF
	jsr	send
	ldb	P_NO,x
	jsr	delete_player
	clr	cmode
	andcc	#~$10
	ldx	#m0
	stx	mstr
	jsr	draw_menu
	jmp	out@
	;; watch existing game
watch@	jsr	redraw_play
	jsr	draw_play
	clr	in_mode
	jsr	draw_menu
	lbra	out@
p0@	fcn	"PRIVMSG #coco_war :@^"
	

menu_select
	.db	0
	
;;; draw menu
draw_menu
	pshs	d,x,y,u
	;; clear the screen
	ldx	#SSCR+(14*256)
	ldb	#4
c@	clra
b@	clr	,x+
	deca
	bne	b@
	decb
	bne	c@
	;; 
	ldx	#SSCR+(14*256)+8
	pshs	x
	ldb	#$ff
	stb	colorm
	ldy	#strings@
a@	ldb	#$2
	stb	mod
	ldu	,y++
	beq 	out@
	jsr	puts
	ldx	,s
	leax	256+32+32,x
	stx	,s
	bra	a@
out@
	jsr	draw_mind
	;; fix stack, return
	leas	2,s
	puls	d,x,y,u,pc
strings@
mstr	.dw	m0
	.dw	m1
	.dw	m2
	.dw	m4
	.dw	0

m0	fcn	"Join Game"
m1	fcn	"Quit"
m2	fcn	"Watch Game"
m4	fcn	"Re-Setup"
m3	fcn	"Admit Defeat"

	
	;; draw the menu selection indicator
start@	equ	SSCR+(14*256)+7
draw_mind
	ldx	#start@
	pshs	x
	;; clear
	ldd	#0
a@	stb	,x
	leax	32,x
	cmpx	#start@+(320*4)
	blo	a@
	puls	x
	;; draw
	lda	menu_select
e@	beq	d@
	leax	(32*10),x
	deca
	bra	e@
d@	ldb	#'*
	clr	mod
	jsr	putb
	rts
	
	

inc_inmode
	pshs	b
	ldb	in_mode
	incb
	cmpb	#2
	bls	a@
	clrb
a@	stb	in_mode
	decb
	lbmi	draw_play@
	lbeq	draw_scores@
	jsr	draw_log
out@	puls	b,pc
draw_play@
	jsr	draw_play
	bra	out@
draw_scores@
	jsr	draw_scores
	jsr	draw_sscr
	bra	out@
	
draw_play	
	pshs	d,x
	;; change display address to $3800
	clr	$ffcb		; 1
	clr	$ffcd		; 1
	clr	$ffcf		; 1
	clr	$ffd0		; 0
	puls	d,x,pc

draw_sscr
	pshs	d,x
	;; change display address to $4800
	clr	$ffca		; 0
	clr	$ffcd		; 1
	clr	$ffce		; 0
	clr	$ffd1		; 1
	puls	d,x,pc

	
playertab
	;; blank
blank	.db	0,0,0,0,0,0,0,0
	;; check
	.db	%11001100
	.db	%00110011
	.db	%11001100
	.db	%00110011
	.db	%11001100
	.db	%00110011
	.db	%11001100
	.db	%00110011
	;; orange
	.db	%01010101
	.db	%01010101
	.db	%01010101
	.db	%01010101
	.db	%01010101
	.db	%01010101
	.db	%01010101
	.db	%01010101
	;; outline
	.db	%01010101
	.db	%01010101
	.db	%01000001
	.db	%01000001
	.db	%01000001
	.db	%01000001
	.db	%01010101
	.db	%01010101
	;; tri - white
	.db	%01010101
	.db	%01010101
	.db	%11111111
	.db	%11111111
	.db	%11111111
	.db	%10101010
	.db	%10101010
	.db	%10101010
	;; X
	.db	%11000011
	.db	%11000011
	.db	%01100110
	.db	%01100110
	.db	%00111000
	.db	%01100110
	.db	%11000011
	.db	%11000011
	;; blue 0
	.db	%10101010
	.db	%10000010
	.db	%10000010
	.db	%10000010
	.db	%10000010
	.db	%10000010
	.db	%10000010
	.db	%10101010
	;; torn
	.db	%01110111
	.db	%11011101
	.db	%01110111
	.db	%11011101
	.db	%01110111
	.db	%11011101
	.db	%01110111
	.db	%11011101
	;; white
	.db	255,255,255,255,255,255,255,255
	
	;; blue
land	.db	%10101010
	.db	%10001010
	.db	%10100010
	.db	%00101010
	.db	%10100010
	.db	%10101000
	.db	%10001010
	.db	%10100010

graph_tab
	;; terrain explosion
	.db	%00110100
	.db	%11111111
	.db	%10111011
	.db	%11111111
	.db	%10111101
	.db	%11101111
	.db	%10111101
	.db	%00111000
	;; player explosion
pexplode
	.db	%00000000
	.db	%00011000
	.db	%00011000
	.db	%00011000
	.db	%00011000
	.db	%00000000
	.db	%00011000
	.db	%00000000
dead
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00111000
	.db	%01111100
dead1
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00111100
	.db	%01111110
	.db	%11111111
dead2
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00111100
	.db	%00111100
	.db	%01111111
	.db	%11111111
	.db	%11111111
dead3
	.db	%00000000
	.db	%00111000
	.db	%00111000
	.db	%00111000
	.db	%00111100
	.db	%11111111
	.db	%11111111
	.db	%11111111	
dead4
	.db	%01111110
	.db	%01111110
	.db	%00111000
	.db	%01111100
	.db	%00111100
	.db	%00111100
	.db	%11111111
	.db	%11111111

dead5
	.db	%01111110
	.db	%11111111
	.db	%10111111
	.db	%00111000
	.db	%00111000
	.db	%00111000
	.db	%00111000
	.db	%11111111

dead6
	.db	%01111110
	.db	%11111111
	.db	%11111111
	.db	%00111000
	.db	%00111000
	.db	%00111000
	.db	%00101000
	.db	%11011010	
dead7
	.db	%01111100
	.db	%11111110
	.db	%11111110
	.db	%00110000
	.db	%00110000
	.db	%00110000
	.db	%00110000
	.db	%00000000
dead8
	.db	%00111000
	.db	%01111110
	.db	%01111110
	.db	%00110000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	.db	%00000000
	
;;; Put a player on screen
;;;   X = screen location to draw
;;;   u = player avatar
;;;   modifies: d
putplayer
	pshs	x,u
	lda	#8
	pshs	a
a@	lda	,u+
	sta	,x
	leax	32,x
	dec	,s
	bne	a@
	leas	1,s
	puls	x,u,pc

	

;;; IRQ routine
;;;
;;; 
irq
	lda	$ff02		; clear pia's interrupt flag
	sts	[task]		; store stack
	;; increment state 
	ldb	mode
	incb
	cmpb	#3
	bne	a@
	clrb
a@	stb	mode
	;; 
	cmpb	#2		; are we 2
	beq	b@		; yes then run graphics task
	;; no then run comm task
	ldx	#stack1p
	bra	cont@
	;; yes then run graphics task
b@	ldx	#stack2p
	;; store and return 
cont@	stx	task
	lds	[task]		; restore stack to which ever task
cont2@	rti			; store cpu stack and return
	
	


	;; update any shells in the air
update_all
	jsr	display_angle
	ldx	#ptab		; X = table of players
	;; loop through each player 
a@	lda	P_STATE,x	; get player state
	anda	#ST_MISS	; is there a missle for this player?
	beq	b@		; no then skip
	;; yes then redraw missle
	orcc	#$10
	jsr	draw_missle
	;; calc new X
	ldd	P_MX,x		; get missle X
	addd	P_VX,x		; add missle x velocity
	std	P_MX,x		; store missle x
	;; check for X bounds
	bmi	c@		; past left edge?
	cmpd	#$3fc0		; past right edges?
	bhs	c@
	;; calc new Y
	ldd	P_VY,x		; get missle V
	addd	grav		; add gravity
	std	P_VY,x		; save for next time
	addd	P_MY,x		; add to X
	std	P_MY,x
	;; check for Y bounds
	cmpd	#0x5c00
	bge	c@
	;; check for terrain collision
	jsr	col_player
	bcc	c@
	jsr	col_terrain
	bcs	j@		; no terrain collision
c@	ldb	P_STATE,x	; get status
	andb	#~ST_MISS	; turn off missile
	stb	P_STATE,x	; 
	bra	b@
	;; draw player missle
j@	jsr	draw_missle
	;; goto next player slot
b@	andcc	#~$10
	leax	P_Z,x		; goto next player
	cmpx	#ptab+(P_Z*8)	; are we done?
	bne	a@
	;; leave
	jsr	display_angle
	rts



	
;;; collide a missle against a player
;;;   takes: X = player struct for missle
col_player
	pshs	d,x,u
	tfr	x,u
	;; find x
	ldd	P_MX,u
	lsra
	pshs	a		; ( x )
	tfr	a,b
	clra
	addd	#pfield
	pshs	d		; ( x *pfield )
	ldb	[,s]		; b = no of player
	pshs	b		; a dummy
	beq	nocol@		; if zero then no player is in this Y
	decb
	jsr	getplayer	; X = target player
	lda	P_Y,x		; get Y
	sta	,s		; ( x *pfield y )
	;; get missle's y
	ldd	P_MY,u		; A = missle Y
	lsra			;
	lsra			;
	cmpa	,s		; compare to missle
	beq	ann@		;
nocol@	coma
	bra	out@
col@	clra
out@	leas	4,s		; fix stack
	puls	d,x,u,pc	; return
	;; announce a hit
ann@	tst	serverf		; only send string if we're the server
	beq	col@		;
	ldx	#p0@
	jsr	appString	; send prefix
	ldb	[1,s]
	decb
	pshs	b		; save object player no for later adjust
	jsr	appHex		; send target player no
	ldb	P_NO,u		;
	jsr	hit_splayer	; adjust subject's score
	jsr	appHex		; send player that hit the target 
	jsr	appCRLF		; send with CRLF
	jsr	send		;
	;; adjust me potentially send a term, so
	;; we have to do it AFTER completing the hit announcement
	puls	b
	jsr	draw_hit_player
	jsr	hit_oplayer	;
	bra	col@
p0@	fcn	"PRIVMSG #coco_war :@$"



	
;;; collide a missle against terrain
;;;   takes: X = player struct
col_terrain
	pshs	d,x,u
	tfr	x,u
	;; find x
	ldd	P_MX,u
	lsra
	pshs	a		; ( x )
	tfr	a,b
	clra
	addd	#terrain
	pshs	d		; ( x *ter )
	ldb	[,s]		; b = height of land
	pshs	b		; ( x *ter h )
	;; test for too low
	ldb	[1,s]		; get terrain
	cmpb	#22		; is low as can go?
	bhi 	nocol@		; no collision
	;; is missle lower than land?
	ldd	P_MY,u		; a = y tile coordinate of missle
	asra			;
	asra			;
	cmpa	,s		; compare to terrain map y coord
	blt	nocol@		; no collision
	;; collision!
	;; explode terrain
	clrb			; x 256 a line
	addb	3,s		; 
	adca	#0
	addd	#PSCR
	tfr	d,x
	ldu	#graph_tab
	jsr	putplayer
	;; make sound
	ldb	#0
	jsr	sound
	;; undraw explosion
	ldu	#land
	jsr	putplayer
	;; clear top square
	lda	[1,s]
	clrb
	addd	#PSCR
	addb	3,s
	adca	#0
	tfr	d,x
	ldu	#playertab
	jsr	putplayer
	inc	[1,s]		; inc, (lower) terrian
	;; move player
	ldx	#pfield
	ldb	3,s
	ldb	b,x		; b = player (1-8)
	beq 	c@		; no player - don't move
	decb			; b = player (0-7)
	jsr	getplayer	; x = player to move
	jsr	undraw_player	; remove player
	inc	P_Y,x		; drop player by one fat pixel
	jsr	display_player	; and put it back on
c@
*	orcc	#$10
*	andcc	#~$10
	clra			; clear carry on collision
a@	leas	4,s
	puls	d,x,u,pc
nocol@	coma			; set carry on no collision
	bra	a@


	
update
	jsr	do_lift
	jsr	do_blink
	tst	shot
	beq	b@
	dec	shot
b@	ldb	in_mode		; get screen/keyboard mode
	decb			; 0,1,2 -> -1,0,1
	bmi	in0@
	jsr	menu_update
	bra	a@
in0@	jsr	play_update
	;; update missles
a@	jsr	update_all
 	;; wait
	sync
	jmp	update



do_lift
	pshs	cc,d,x
	orcc	#$10
	;; don't do this if just client
	tst	serverf
	beq	out@
	;; dec timer
	ldd	lift
	beq	c@		; timer shouldn't be 0
	subd	#1
	std	lift
	bne	out@
	;; reset timer
c@	ldd	#15*20	
	std	lift
	;; find min/max
	ldd	#$0c0c
	std	min@
	ldx	#terrain
	lda	#32
a@	ldb	,x+
	cmpb	min@
	bhi	nmin@
	cmpb	max@
	blo	nmax@
b@	deca
	bne	a@
	ldb	max@
	cmpb	#2
	beq	out@
	;; find mid
	ldb	min@
	subb	max@
	lsrb
	addb	max@
	cmpb	#16
	blo 	out@
	;; tell all to lift
	ldx	#p0@
	jsr	appString
	jsr	appCRLF
	jsr	send
	jsr	lift_terrain	; and lift ourselves
	;; return
out@	puls	cc,d,x,pc
nmin@	stb	min@
	bra	b@
nmax@	stb	max@
	bra	b@
min@	.db	0
max@	.db	0
p0@	fcn	"PRIVMSG #coco_war :@&"	

quit1
	ldx	#p0@
	jsr	appString
	jsr	appCRLF
	jsr	send
	jsr	DWClose
	rts
p0@	fcn	"QUIT :exit game"


;;; quit
quit
	;; !!! may need to wait for close connection byte here...
	orcc	#0x50		; shut off interrupts
	lds	bstack		; reset stack
	puls	a,x
	sta	$10c
	stx	$10d
	puls	cc,pc		; quit to BASIC
	
	
;;; do space bar - sets up players missle
do_space
	pshs	d,x,u
	;; if timer is zero then ok
	tst	shot
	lbne	out@
	;; set missle flag
	ldx	me		; do we already have a missile?
	ldb	P_STATE,x
	bitb	#ST_MISS
	lbne	out@		; yes then don't launch
	tst	cmode		; are we in the game?
	beq	out@		; no then don't launch
	;; else then launch
	orb	#ST_MISS	; set missile flag
	stb	P_STATE,x
	;; set shot timer
	ldb	#30		; 1.5 seconds @ 20hz
	stb	shot
	;; set X coord
	clrb
	lda	P_X,x
	lsla
	adda	#1
	std	P_MX,x
	;; set Y coord
	clrb
	lda	P_Y,x
	lsla
	lsla
	subd	#$80
	std	P_MY,x
	;; get start X velocity
	jsr	angle_abs
	ldx	#sintab
	ldb	b,x		; b=multi
	clra			; D = sin 2^8
	ldx	power
	jsr	$9fb5		; multiply, Y,U = result
	pshs	y,u		; push result onto stack
	ldd	1,s		; get result
	tst	angle
	bpl	a@
	coma
	comb
	addd	#1
a@	ldx	me
	std	P_VX,x		; set X velocity
	leas	4,s
	;; get start Y velocity
	jsr	angle_abs
	pshs	b
	ldb	#90
	subb	,s+
	ldx	#sintab
	ldb	b,x
	clra
	ldx	power
	jsr	$9fb5
	pshs	y,u
	clra
	clrb
	subd	1,s
	ldx	me
	std	P_VY,x		; set Y velocity
	leas	4,s
	jsr	draw_missle	;; draw missile
	;; send pertinent data to IRC channel
	ldx	#p0@
	jsr	appString
	ldx	me
	lda	#12
b@	ldb	,x+
	jsr	appHex
	deca
	bne	b@
	jsr	appCRLF
	com	rts
out@	puls	d,x,u,pc	; return
p0@	fcn	"PRIVMSG #coco_war :@@"



	
;;; return abs of angle
angle_abs
	ldb	angle
	bpl	out@
	negb
out@	rts


	
;;; Draw missle on screen (if possible)
;;;   takes: X = player struct
draw_missle
	pshs	d,x,u
	;; check flag
	ldb	P_STATE,x	; get player state
	andb	#ST_MISS	; is a missle?
	beq	out@		; no then don't do draw
	;; bounds check X
	ldd	P_MX,x		; D = x position (packed)
	bmi	out@		; quit if X is minus
	cmpd	#$3f80		; is off screen?
	bhi	out@		; then quit
	;; bounds check Y
	ldd	P_MY,x		; D = y position (packed)
	bmi	out@		; quit if Y is minus
	rola
	cmpa	#191		; is off screen?
	bhi	out@		; then quit
	;; make Y offset
	ldb	#32		; 32 bytes per line
	mul			; D = Y buffer offset
	pshs	d		; save it. ( yoff )
	;; make X offset
	ldd	P_MX,x		; D = X position (packed)
	lsra			; A = byte offset
	tfr	a,b		; B = byte offset
	clra			; D = byte offset
	addd	,s++		; pull and add Y offset ( -- )
	addd	#PSCR		; add screen base
	tfr	d,u		; U = screen location
	ldd	P_MX,x		; D = X position (packed)
	rolb
	rola
	anda	#3
	ldx	#misstab
	lda	a,x
	tfr	a,b
	eorb	,u
	stb	,u
	leau	32,u
	eora	,u
	sta	,u
out@	puls	d,x,u,pc



;;; Hook for display angle
display_angle
	pshs	d,x,y,u
	ldx	#ud_ang
	jsr	draw_missle
	ldx	me
	;; push Y
	clrb
	lda	P_Y,x
	lsla
	lsla
	subd	#$80
	std	ud_ang+P_MY
	;; push X
	clrb
	lda	P_X,x
	lsla
	adda	#1
	std	ud_ang+P_MX
	;; compute X
	jsr	angle_abs
	ldx	#sintab
	ldb	b,x
	clra	
	ldx	#$400
	jsr	$9fb5
	pshs	y,u
	ldd	1,s
	tst	angle
	bpl	a@
	coma
	comb
	addd	#1
a@	leas	4,s
	addd	ud_ang+P_MX
	std	ud_ang+P_MX
	;; compute Y
	jsr	angle_abs
	pshs	b
	ldb	#90
	subb	,s+
	ldx	#sintab
	ldb	b,x
	clra
	ldx	#$400
	jsr	$9fb5
	pshs	y,u
	clra
	clrb
	subd	1,s
	leas	4,s
	addd	ud_ang+P_MY
	std	ud_ang+P_MY
	ldb	#ST_MISS
	stb	ud_ang+P_STATE
	ldx	#ud_ang
	jsr	draw_missle
	puls	d,x,y,u,pc



;;; put player on map
;;;   takes: X = player struct
;;;   mods: nothing
display_player
	pshs	d,x,u
	;; don't display if not there
	tst	P_STATE,x
	beq	out@
	;; calc y
	lda	P_Y,x
	clrb
	pshs	d
	;; calc x
	clra
	ldb	P_X,x
	addd	,s++
	addd	#PSCR
	pshs	d
	ldb	P_NO,x
	incb
	lda	#8
	mul
	addd	#playertab
	tfr	d,u
	puls	x
	jsr	putplayer
out@	puls	d,x,u,pc

;;; put player on map - low level
;;;    takes: X player, U tile ptr
display_ll
	pshs	d,x,u
	;; calc y
	lda	P_Y,x
	clrb
	pshs	d
	;; calc x
	clra
	ldb	P_X,x
	addd	,s++
	addd	#PSCR
	tfr	d,x
	jsr	putplayer
	puls	d,x,u,pc
	
;;; put player on map
;;;   takes: X = player struct
;;;   mods: nothing
undraw_player
	pshs	d,x,u
	;; calc y
	lda	P_Y,x
	clrb
	pshs	d
	;; calc x
	clra
	ldb	P_X,x
	addd	,s++
	addd	#PSCR
	pshs	d
	ldu	#playertab
	puls	x
	jsr	putplayer
	puls	d,x,u,pc

;;;
;;;
;;;  Communications
;;;
;;; 

DBUF0	equ	$600
CR	equ	$d
BS	equ	$8
IntMasks equ	$50
	
	;; include becker methods
	include dwread_bkr.asm
	include dwwrite_bkr.asm
	;; include regular high-speed methods
	include	dwdefs.d
	include dwread.asm
	include dwwrite.asm

	
DWRead	.dw	DWRead_bkr	; DWRead vector
DWWrite	.dw	DWWrite_bkr	; DWWrite vector
	
;;; this is a pre-formatted transmit buffer to DW
dwbuf	.db	$64,$1		; write to port 1
dwno	rmb	1		; number of bytes
xmitb	rmb	256		; transmit buffer
xpos	.dw	xmitb		; xmit buffer position

;;; This is the server input buffer
ibuff	rmb	512		; input buffer
ipos	.dw	ibuff		; input buffer position

;;; parse buffer
word	rmb	512		; command word buffer
ppos	rmb	2		; parse input pointer

;;; tells com1 routine to send bytes
rts	.db	0		; 0 not ready, 1 ready.
	
	
;;; Start communications
comm_init
	;; open dw port
	jsr	DWOpen
	;; send connect message
	ldx	#p@
	jsr	appString
	ldb	#CR
	jsr	appByte
	jsr	send
	;; return
	rts
p@	fcn	"tcp connect play-classics.net 6667"


;;; Called at startup after receiving a 
;;; 'OK' on TCP connect from DW
irc_init
	;; send PASS message
	ldx	#p3@
	jsr	appString
	jsr	appCRLF
	jsr	send
	;; send NICK message
	ldx	#p2@
	jsr	appString
	ldx	#nick
	jsr	appString
	jsr	appCRLF
	jsr 	send
	;; send USER message
	ldx	#p1@
	jsr	appString
	ldx	#nick
	jsr	appString
	ldx	#p11@
	jsr	appString
	ldx	#nick
	jsr	appString
	jsr	appCRLF	
	jsr	send
	;; join game
*	jsr	join_game
	;; return
	rts
p1@	fcn	"USER "
p11@	fcn	" 0 * "
p2@	fcn	"NICK "
p3@     fcn     "PASS 6809"


join_game
	pshs	x,u
	tst	serverf		; are we the server?
	beq	a@
	;; yup -  make and draw me if master - announce that we are joining
	ldx	#nick
	ldu	#tnick
	jsr	strcpy
	jsr	make_player
	stx	me
	inc	cmode
	jsr	redraw_play
*	jsr	display_player
	puls	x,u,pc
	;; no just client then announce we wish to join
a@	ldx	#p0@
	jsr	appString
	jsr	appCRLF
	jsr	send
	puls	x,u,pc
p0@	fcn	"PRIVMSG #coco_war :@!"
	
;;; Open Vport
DWOpen
	ldx	#0x0129
	ldb	#0xc4
	pshs	b,x
	tfr	s,x
	ldy	#3
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
	jsr	[DWWrite]
	leas	3,s
	rts

;;; Initialize Drivewire
DWInit
	ldx	#0x5a00
	pshs	x
	tfr	s,x
	ldy	#2
	jsr	[DWWrite]
	ldy	#1
	tfr	s,x
	jsr	[DWRead]
	leas	2,s
	rts

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

;;; Append a nibble in hex to xmit buffer
appNibble
	pshs	b
	addb	#'0
	cmpb	#'9
	bls	out@
	addb	#7
out@	bsr	appByte
	puls	b,pc

;;; Append a byte in hex to xmit buffer
appHex
	pshs	b
	lsrb
	lsrb
	lsrb
	lsrb
	bsr	appNibble
	ldb	,s
	andb	#$0f
	bsr	appNibble
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
	jsr	[DWWrite]
	;; reset xmit buffer
	ldd	#xmitb
	std	xpos
	puls	d,x,y,pc

	
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

;;; Copy string ( end at 0 or "!" )
;;;   takes: X = src, U = dest
;;;   returns: nothing
;;;   modifies: D,X,U
strcpy
	pshs	d,x,u
a@	ldb	,x+
	cmpb	#'!
	beq	out@
	stb	,u+
	bne	a@
b@	puls	d,x,u,pc
out@	clr	,u
	bra	b@

;;; Clr memory
;;;   takes: B = no, X = address
;;;   returnes: nothing
;;;   modifies: nothing
memz	pshs	b,x
a@	clr	,x+
	decb
	bne	a@
	puls	b,x,pc
	
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

;; Print reply from DW
DWReply
	lda	#0x43		; Poll/Read op code
	pshs	d		; push onto stack
	tfr	s,x		; setup for DW write
	ldy	#1		;
	orcc	#$50
	jsr	[DWWrite]
	tfr	s,x		; setup for read status
	ldy	#2
	jsr	[DWRead]
	andcc	#~$10
	bcs	err2@		; error on timeout
	bne	err2@		; error on framing
	lda	,s		; get byte1
	bne	e@		; branch if not zero
	;; return nothing to read
	puls	d		; drop stack buffer
	rts			; return
	;; something to read
e@	cmpa	#16		; compare to #16
	blo	sin@		; is lower than a single byte read
	bhi	mul@		; is higher than multi byte read
	;; close port & return
	;; closing the port is not specified by DW
	;; but DW will hang if we don't
	puls	d		; is same so close port
	jmp	quit
	rts
	;; receive a single byte
sin@	puls	d
	jsr	ibufput
	rts			; return
	;; receive multiple bytes
mul@	lda	#30		; max bytes from dw
	cmpa	1,s		;
	bhi	a@		; 
	sta	1,s		; do max receive
a@	clr	,s
	inc	,s
	lda	#0x63
	pshs	a
	tfr	s,x
	ldy	#3
	orcc	#$50
	jsr	[DWWrite]
	ldx	#DBUF0
	ldb	2,s
	clra
	tfr	d,y
	jsr	[DWRead]
	andcc	#~$10
	bcs	err3@
	bne	err3@
	leas	1,s
	puls	d
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

;;; State 0 routine
docom0
	jsr	DWReply
	tst	rts
	beq	a@
	jsr	send
	clr	rts
a@	sync
	bra	docom0
	

	;;;
;;;
;;;	IRC Server Message Processing
;;;
;;;

gen_privmsg
	fcn	"PRIVMSG #coco_war :@"
	
	;; server message commands

tpriv	fcn	"PRIVMSG"
tping	fcn	"PING"
tquit	fcn	"QUIT"
tjoin	fcn	"JOIN"
twel	fcn	"001"
tnotop	fcn	"331"
ttop	fcn	"332"
tname	fcn	"353"
teon	fcn	"366"
tnicku	fcn	"433"		; nick in use
tnicko	fcn	"432"		; erroneous nick
	
icmdtab	.dw	tpriv
	.dw	cpriv

	.dw	tping
	.dw	cping

	.dw	tquit
	.dw	cquit

	.dw	tjoin
	.dw	cjoin

	.dw	twel
	.dw	cwel

	.dw	tnotop
	.dw	cjoined

	.dw	ttop
	.dw	cjoined

	.dw	tname
	.dw	cjoined

	.dw	teon
	.dw	cjoined

	.dw	tnicku
	.dw	cnicku

	.dw	tnicko
	.dw	cnicko
	
	.dw	0
	

	;;  nick in use error
cnicku
	ldb	#%01010101
	stb	colorm
	ldx	npos
	leax	(10*32),x
	stx	npos
	ldu	#p0@
	clr	mod
	jsr	puts
	orcc	#$10
a@	jsr	$a1cb		; basic keyboard scan
	beq	a@		; wait for key
restart	jsr	DWClose		; close DW port
	ldx	#stack1p
	stx	task
	clr	in_mode
	inc	in_mode
	clr	mode
	clr	cmode
	clr	conmode
	clr	init_mode
	clr	serverf
	lds	bstack		; entry stack frame
	puls	a,x
	sta	$10c
	stx	$10d
	puls	cc
	jmp	start
p0@	fcn	"ERR: Nick in Use."

	;; erroneous nick error
cnicko
	ldb	#%01010101
	stb	colorm
	ldx	npos
	leax	256+(2*32),x
	stx	npos
	ldu	#p0@
	clr	mod
	jsr	puts
	puls	d,x,u,y,pc
p0@	fcn	"ERR: Bad Nick."
	
;;; puts byte into input buffer, parsing if necessary
;;;   Takes: B = byte to push
ibufput
	pshs	x
	ldx	ipos		; get position
	tst	init_mode
	bne	a@		; TCP/TELNET connect est. - delimit with CRLF
	cmpb	#CR		; is a CR (end of line?)
	bra	b@
a@	cmpb	#$a		; is a LF (end of line?)
b@	beq	eol@		; go handle end of line
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
	ldb	init_mode	; are we awaiting connect?
	cmpb	#1
	beq	c@		; we are connected....
	;; awaiting connect and have DW response line
	ldd	ibuff		; get first two byte
	cmpd	#$4f4b		; s/b 'OK'
	lbne	printerr	; start over on error
	inc	init_mode	; got OK, so goto DW connect mode
	ldb	init_mode
	cmpb	#1
*	beq	out@
*	ldx	#$8000
*d@	leax	-1,x		; delay a lil' bit
*	bne	d@
e@	ldx	spos		; print "OK"
	ldb	spos+2
	stb	mod
	ldu	#p0@
	jsr	puts	
	ldx	npos		; print a CR
	leax	256+(2*32),x
	stx	npos
	clr	mod
	ldu	#p1@		; print "registering on irc..."
	jsr	puts
	stx	spos
	ldb	mod
	stb	spos+2
	jsr	irc_init	; and send IRQ init stuff
	puls	d,x,y,u,pc	; return
	;; test for prefix
c@	ldb	ibuff
	cmpb	#':		; is a prefix?
	bne	a@		; no then parse this as command
	jsr	getWord		; get prefix
a@	jsr	getWord		; get command
	;; else is a command
	ldu	#word		; U = point at word buffer
	ldy	#icmdtab	; Y = server cmd table
b@	ldx	,y		; X = cmd string
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
	bne 	out@
	;; print error
pe@	ldx	#ibuff
	jsr	putlogs
*	bra	printerr
out@	puls	d,x,y,u,pc	; return
p0@	fcn	"OK"
p1@	fcn	"Registering on IRC..."

	;; handle generic error message
printerr
	ldu	#ibuff
	ldx	npos
	clr	mod
a@	ldb	,u+
	beq	out@
	jsr	putb
	ldb	col@
	incb
	cmpb	#26
	beq	nl@
	stb	col@
	jsr	inc5
	bra	a@
nl@	clr	col@
	leax	320,x
	bra	a@
out@	stx	pos@
	puls	d,x,y,u,pc
pos@	.dw	SSCR+(11*256)
col@	.db	0
	
	ldx	#ibuff-1
	jsr	$b99c		;print the error message
	puls	d,x,y,u,pc	;return


cwel
	;; print OK
	ldx	spos
	ldb	spos+2
	stb	mod
	ldu	#p1@
	jsr	puts
	;; print joining channel
	ldx	npos
	leax	256+(2*32),x
	stx	npos
	clr	mod
	ldu	#p2@
	jsr	puts
	;; send join channel command to IRC
	ldx	#p0@
	jsr	appString
	jsr	appCRLF
	jsr	send
	inc	conmode
	puls	d,x,y,u,pc
p0@	fcn	"JOIN #coco_war"
p1@	fcn	"OK"
p2@	fcn	"Joining Channel..."


cjoined	ldb	conmode
	cmpb	#2
	beq	out@
	ldb	#2
	stb	conmode
	jsr	draw_scores
	jsr	draw_sscr
out@	puls	d,x,y,u,pc

	
	
cjoin
	ldx	#ibuff
	jsr	putlogs
	;; reset parse position
	ldu	#ibuff		; X = input buffer
	stu	ppos		; 
	;; parse nick
	jsr	getWord		; get nick/who field
	ldx	#word+1
	ldu	#tnick
	jsr	strcpy
	jsr	sst_clear
	ldx	#tnick
	jsr	sst_mess
	ldx	#p0@
	jsr	sst_mess
	puls	d,x,y,u,pc
p0@	fcn	" has joined IRC"
	

	;; a Client quits the IRC server
cquit
	ldx	#ibuff
	jsr	putlogs
	;; reset parse position
	ldu	#ibuff		; X = input buffer
	stu	ppos		; 
	;; parse nick
	jsr	getWord		; get nick/who field
	ldx	#word+1
	ldu	#tnick
	jsr	strcpy
	;; interate through names for match
	ldy	#ptab
a@	ldu	#tnick
	leax	P_NAME,y
	jsr	strcmp
	beq	found@
	leay	P_Z,Y
	cmpy	#ptab+(P_Z*8)
	bne	a@
	;; not found
	puls	d,x,y,u,pc
	;; is found
found@	jsr	sst_clear
	leax	P_NAME,y
	jsr	sst_mess
	ldx	#p0@
	jsr	sst_mess
	ldb	P_NO,y
	jsr	delete_player
	puls	d,x,y,u,pc
p0@	fcn	" has left IRC"

	;; handle private messsage
cpriv	
	;; reset parse position
	ldu	#ibuff		; X = imput buffer
	stu	ppos		; parse 
	;; parse and print nick
	jsr	getWord		; get nick/who field
	ldx	#word+1
	ldu	#tnick
	jsr	strcpy
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
	bra	chan@
	;; print channel message
chan@	jsr	getb		; drop space and ":" off buffer
	jsr	getbb		; get next byte
	cmpb	#'@		; is a "@"?
	beq	game_mess	; yes then process message
	;; no then print to log
*	ldx	ppos
*	leax	-1,x
*	jsr	putlogs
ret	puls	d,x,y,u,pc	; return!
	
	;; process a game message
game_mess
	jsr	getbb		; B = message type
	cmpb	#'@		; missle message?
	beq	new_missle
	cmpb	#'!		; new player message?
	beq	new_player
	cmpb	#'#		; is a new player acknowledge
	lbeq	ack_player
	cmpb	#'$		; a player hit by missile
	lbeq	hit_player
	cmpb	#'%		; is a player's basic info
	lbeq	recv_basic
	cmpb	#'^		; is a dead player?
	lbeq	dead_player
	cmpb	#'&		; scroll up :)
	lbeq	lift_terrain0	; call client wrapper
	bra	ret

lift_terrain0
	jsr	lift_terrain	; just lift terrain
	bra	ret
	
	;; recv'd a new missle message
new_missle
	jsr	getb		; B = get a byte
	jsr	getplayer	; X = player struct
	pshs	x		; ( *plyr )
	stb	P_NO,x		; set player number
	leax	P_STATE,x	; to beginning of state
	jsr	getb		; state
	stb	,x+
	jsr	getw		; MX
	std	,x++
	jsr	getw		; MY
	std	,x++
	jsr	getb		; X
	stb	,x+
	jsr	getb		; Y
	stb	,x+
	jsr	getw		; VX
	std	,x++
	jsr	getw		; VY
	std	,x++
	;; set playfield
	ldx	,s		; X = player struct
	ldb	P_X,x		; get X coord
	ldx	#pfield		; get base of playfield
	abx			; X = our spot in playfield
	puls	u		; get player no
	ldb	P_NO,u		;
	incb			; adjust to 1-8
	stb	,x		; and store in play field
	tfr	u,x		; X = player struct
	;; set nickname
	pshs	x
	leau	P_NAME,u
	ldx	#tnick
	jsr	strcpy
	puls	x
	;; redraw player
	jsr	display_player
	jsr	draw_missle
	jmp	ret
	
	;; recv'd a new player message
new_player
	tst	serverf
	beq	a@
	pshs	cc
	orcc	#$10
	jsr	make_player	; x = new player struct
	jsr	send_ack	; let other players know of this new player
	;; send our client info
	jsr	send_basic
	;; draw new player
	puls	cc
	ldb	P_NO,x
	jsr	sst_new
	jsr	display_player
a@	jmp	ret

	;; server does this to send client a notice of new player
	;;  Takes: X = player struct
send_ack
	pshs	cc,d,x,u
	orcc	#$10
	tfr	x,u		;
	ldx	#gen_privmsg	; append generic channel message
	jsr	appString	;
	ldb	#'#		; append new player acknowledge
	jsr	appByte		;
	ldb	P_NO,u		; append player no
	jsr	appHex		;
	ldb	P_X,u		; append player X
	jsr	appHex		; 
	ldb	P_Y,u		; append player Y
	jsr	appHex		;
	;; append terrain
	lda	#32
	ldx	#terrain
b@	ldb	,x+
	jsr	appHex
	deca
	bne	b@
	ldx	#tnick		; append related nick
	jsr	appString
	jsr	appCRLF		; append CRLF
	jsr	send
	puls	cc,d,x,u,pc

	;; client received a player entry
ack_player
	jsr	getb		; get slot no.
	jsr	getplayer	; X = player struct
	pshs	x		; ,s = player struct
	stb	P_NO,x		; player no.
 	lda	#ST_ACT		; is and active player
*	lda	#0
	sta	P_STATE,x	; player state. (!!! state s/b not 0 ? )
	jsr	getw		; get X and Y
	std	P_X,x		; store
	;; store player no in terrain
	ldb	P_NO,x
	incb
	ldx	#pfield
	stb	a,x
	;; get terrain
	lda	#32
	ldx	#terrain
b@	jsr	getb
	stb	,x+
	deca
	bne	b@
	;; get player name
	ldx	,s
	leax	P_NAME,x
c@	jsr	getbb
	cmpb	#CR
	beq	d@
	stb	,x+
	bra	c@
d@	clr	,x
	;; set player's HP
	ldx	,s
	ldb	#4
	stb	P_HP,x
	;; if me then set me
	ldx	,s
	leax	P_NAME,x
	ldu	#nick
	jsr	strcmp
	bne	e@
	ldx	,s
	stx	me
	jsr	set_blink
	inc	cmode
	jsr	draw_terrain
	puls	x
*	jsr	display_player
	jsr	redraw_play
	jsr	send_basic
	jmp	ret
	;; send user info
e@	tst	cmode		; don't send info if we are not joined
	beq	f@
	jsr	send_basic
	;; display new player
f@	puls	x
	ldb	P_NO,x
	jsr	sst_new
	jsr	display_player
	jmp	ret

;;; Handles the reception of other
;;; client's basic data
recv_basic
	pshs	d,x,u
	jsr	getb		; get player no
	jsr	getplayer	; U = player struct
	tfr	x,u		;
	stb	P_NO,u		; store player no
	jsr	getb		; get state
	orb	#ST_ACT		; force active state
	stb	P_STATE,u	;
	jsr	getw		; get score
	std	P_SCORE,u	;
	jsr	getb		; get avatar
	stb	P_AVA,u
	jsr	getb		; get Hit points
	stb	P_HP,u		
	ldx	#tnick		; get nick name
	leau	P_NAME,u
	jsr	strcpy
	puls	d,x,u
	jmp	ret
	
;;;  Called when a player is hit
hit_player
	pshs	d,x
	;; 
	jsr	getb		; get hit player no
	jsr	draw_hit_player	; draw git player on screen
	jsr	hit_oplayer
	;; give subject player 5 points
	jsr	getb		; get subject player no
	jsr	hit_splayer
	;; exit
	puls	d,x
	jmp	ret


;;;  Called when a dead player message arrives
dead_player
	jsr	getb		; get hit player no.
	pshs	b
	jsr	sst_dead
	;; animation and sound
	ldb	,s
	jsr	getplayer	; x is player
	stx	anim+2		; save player struct
	ldx	#nuke_anim	; X is nuke anim list
	stx	anim
	ldb	#1
	jsr	sound
	;; remove player from data
	puls	b		; pull player no
	jsr	delete_player	; remove player
	jmp 	ret


;;; Takes: B = play no.
draw_hit_player
	pshs	d,x,u
	jsr	getplayer
	ldu	#pexplode
	jsr	display_ll
	;; play sound
	ldb	#1
	jsr	sound
	;; put player back
	jsr	display_player
	puls	d,x,u,pc

;;; Called to adjust hit point of object player
;;;   takes: B = object player
hit_oplayer
	pshs	d,x,u
	jsr	getplayer	; x = player
	dec	P_HP,x		; dec hit points
	beq	a@		; if zero see if us
b@	jsr	draw_scores
	;; !! check for end of life here
	puls	d,x,u,pc
a@	cmpx	me		; is me?
	bne	b@		; nope then just leave
	;; set client's mode to 0 - not playing
	clr	cmode		; toggle to not playing
	ldd	#m0
	std	mstr
	;; we're dead, announce
	tfr	x,u
	orcc	#$10
	ldx	#p0@		; prefix
	jsr	appString
	ldb	P_NO,u		; get player no
	jsr	appHex
	jsr	appCRLF
	jsr	send
	;; start nuke ani
	ldx	me
	ldb	P_NO,x
	jsr	sst_dead
	andcc	#~$10
	ldx	#nuke_anim
	stx	anim
	ldx	me
	stx	anim+2
	ldb	#1
	jsr	sound
	;; delete player from ptab
	ldb	1,s
	jsr	delete_player
	puls	d,x,u,pc
p0@	fcn	"PRIVMSG #coco_war :@^"

;;; Called to adjust score of subject player
;;;   takes: B = subject player
hit_splayer
	pshs	d,x
	orcc	#$10
	jsr	getplayer	; X = player
	jsr	draw_missle	; undraw missle
	ldb	P_STATE,x	; flip missle state off
	andb	#~ST_MISS	;
	stb	P_STATE,x	;
	ldd	P_SCORE,x	; inc score by 5
	addd	#5		;
	std	P_SCORE,x	;
	jsr	draw_scores
	andcc	#~$10
	puls	d,x,pc
	
	

;;; broadcast our basic player information
;;;  but not our location to fellow players
send_basic
	pshs	cc,d,x,u
	orcc	#$50
	ldu	me
	beq	out@		; me is NULL, we're not in game yet
	ldx	#p0@		; send string
	jsr	appString
	ldb	P_NO,u		; send No
	jsr	appHex
	ldb	P_STATE,u	; send state
	jsr	appHex
	ldb	P_SCORE,u	; send score
	jsr	appHex
	ldb	P_SCORE+1,u
	jsr	appHex
	ldb	P_AVA,u		; send avatar no
	jsr	appHex
	ldb	P_HP,u		; send hit points
	jsr	appHex	
	jsr	appCRLF		; and CRLF
	com	rts
out@	puls	cc,d,x,u,pc
p0@	fcn	"PRIVMSG #coco_war :@%"

	
;;; Get a player struct
;;;   takes: B - player no.
;;;   returns: X - player struct
getplayer
	pshs	d
	lda	#P_Z
	mul
	addd	#ptab
	tfr	d,x
	puls	d,pc
	

;;; make a new player
;;;   takes: nothing
;;;   returns: X - new player struct
make_player
	pshs	d,u
	jsr	alloc_no	; B = next player slot
	pshs	b		; ( no )
	lda	#P_Z		; A = size of slots
	mul			; D = offset
	addd	#ptab
	tfr	d,x		; X = new player struct
	ldb	#P_Z
	jsr	memz		; clear the struct
	ldb	,s
	stb	P_NO,x		;
	;; find a unoccupied X
a@	jsr	random
	lsrb
	lsrb
	lsrb
	stb	P_X,x
	pshs	x		; ( no *player )
	ldx	#pfield
	abx	b,x
	pshs	x		; ( no *player *pfield )
	tst	,x
	beq	c@
	;; someone's already here
b@	leas	4,s		; drop player, field ( no )
	bra	a@
	;; found empty pfield
c@	ldb	4,s		; get player no
	incb			; make 1-8
	stb	[,s]		; store it in players' field
	;; make a Y coord
	ldx	2,s		; get X pixels
	ldb	P_X,x
	ldx	#terrain	; get height of terrain
	ldb	b,x
	decb
	ldx	2,s		; store Y in player struct
	stb	P_Y,x		;
	;; copy nick over
	ldx	#tnick
	ldu	2,s
	leau	P_NAME,u
	jsr	strcpy
	leas	2,s		; ( no *player )
	puls	x		; ( no ) x=player
	;; clear score
*	clr	P_SCORE,x	; no need, zero's above?
*	clr	P_SCORE+1,x
	;; set State
	ldb	#ST_ACT
	stb	P_STATE,x
	;; set HP
	ldb	#4
	stb	P_HP,x
	;; out!
	leas	1,s		; ( )
	puls	d,u,pc


;;; delete player from game
;;;   B = player no
delete_player
	pshs	d,x,u
	;; clear slot state
	jsr	getplayer 	; X = player
	ldu	#blank		; undraw player
	jsr	display_ll	;
	ldb	P_STATE,x
	andb	#ST_MISS
	beq	a@
	jsr	draw_missle	; erase missle
a@	lda	P_X,x		; get player's X
	ldb	#P_Z
	jsr	memz		; zero player struct
	ldx	#pfield		; X = pfield
	clr	a,x		; clear pfield map of player
	;; if server then free no
	tst	serverf
	beq	out@
	ldb	1,s		; get no.
	jsr	free_no
out@	jsr	draw_scores
	puls	d,x,u,pc
	

	;; get a nibble
getn
	pshs	u
	ldu	ppos
	ldb	,u+
	subb	#'0
	cmpb	#10
	blo	out@
	subb	#7
out@	stu	ppos
	puls	u,pc


	;; get a byte
getb
	bsr	getn
	lslb
	lslb
	lslb
	lslb
	pshs	b
	bsr	getn
	orb	,s+
	rts

	;; get a word
getw
	bsr	getb
	tfr	b,a
	bsr	getb
	rts

	;; get a byte
getbb	pshs	x
	ldx	ppos
	ldb	,x+
	stx	ppos
	puls	x,pc

	;; handle ping message
cping
	ldx	#p@		; point to pong message
	jsr	appString	; append
	ldx	ppos		; parse position
	jsr	appString	; append server name
	jsr	appCRLF		; append CR/LF
	com	rts		; ready to send
	puls	d,x,y,u,pc	; return!
p@	fcn	"PONG "
	

	;; do nothing with a message
drop
	puls	d,x,y,u,pc



;;;
;;;
;;;  Text mode Initial setup
;;;
;;;

;;; A simple line getter
;;;   takes: X = buffer, B = max size
;;;   modes: D,X
getline
	pshs	x
a@	jsr	$a1b1		; get a key
	cmpa	#CR		; is EOL?
	beq	out@		; yup then out
	cmpa	#BS		; is a Backspace?
	beq	bs@
	tstb			; do we have any space left?
	beq	a@		; nope then loop
	sta	,x+
	jsr	putconba	; put char
	decb
	bra	a@
out@	clr	,x		; terminate with a 0
	puls	x,pc
bs@	cmpx	,s		; are we at beginning?
	beq	a@		; yup then start over again
	leax	-1,x		; move x back one
	incb
	jsr	putconba	; print "bs"
	bra	a@

;;; gets Y or N from user
;;;  takes nothing
;;;  returns Z set on Y, else n
yorn
	jsr	getconb		; get a byte from console
	jsr	putconb		; print key
	cmpb	#'Y
	rts
	
	
setup
	ldb	#BLUE		;
	stb	colorm
	jsr	clr_sscr	; clear score screen
	ldx	spos
	leax	1,x
	stx	spos
	ldy	#p3@		; get array
	ldx	npos
	jsr	putcona		; put arraw to screen
	jsr	putconcr
	jsr	putconcr
	jsr	draw_sscr	; display score screen
	ldb	#WHITE
	stb	colorm
	;; get DW port type
	ldx	#p2@		; print prompt
	jsr	putcons		; 
	jsr	yorn		; is Y?
	bne	b@
	;; is Y
	bra	c@
	;; is N
b@	ldx	#DWRead_hs
	stx	DWRead
	ldx	#DWWrite_hs
	stx	DWWrite
	bra	c@
	;; get server flag setting
c@	jsr	putconcr
	ldx	#p0@
	jsr	putcons
	jsr	yorn
	bne	a@		; no
	;; is a y - mark as server
	com	serverf		; flip server flag
	;; get irc nickname
a@	jsr	putconcr
	ldx	#p1@
	jsr	putcons
	jsr	putconcr
	ldx	#nick
	ldb	#15
	jsr	getline		; get name
	;; set artifacting
	jsr	putconcr
	ldx	#p9@
	jsr	putcons
	jsr	yorn
	beq	d@
	ldb	#$e8		; 
	stb	$ff22
	;; put TCP connection
d@	ldb	#RED
	stb	colorm
	jsr	putconcr	; a cr
	jsr	putconcr
	ldx	#p8@
	jsr	putcons
	rts
p0@	fcn	"Server? "
p1@	fcn	"IRC Nickname?"
p2@	fcn	'"Becker" port? '
p9@	fcn	"Artifacting? "
p3@	.dw	p4@
	.dw	p5@
	.dw	p6@
	.dw	p7@
	.dw	0
p4@	fcn	"Global Thermonuclear War"
p5@	fcn	" a game that nobody wins"
p6@	fcn	" by Brett M Gordon for"
p7@	fcn	" #Retrochallenge 2016"
p8@	fcn	"TCP connection..."


;;; bitmaped text

glyphs
	include	5x8font.asm

mod	.db 	0 		; sub pixels
colorm	.db	%01010101	; color of text

lookup
	.db	%00000000
	.db	%00000011
	.db	%00001100
	.db	%00001111
	.db	%00110000
	.db	%00110011
	.db	%00111100
	.db	%00111111
	.db	%11000000
	.db	%11000011
	.db	%11001100
	.db	%11001111
	.db	%11110000
	.db	%11110011
	.db	%11111100
	.db	%11111111


;;;  Put char to screen
;;;    Takes: X / mod = screen position
;;;    takes: B = ascii char to print
;;;    mods: A
putb
	pshs	x,u		; push beginning X ( U X )
	;; lookup char in glyph table
	ldu	#glyphs		; U point to base of glyphs
	subb	#$20		; subtract printable char bias
	lda	#8
	mul
	leau	d,u		; U = points to glyph
	;; do each row
	ldb	#8		; eight row height
	pshs	b		; push onto stack for counter ( U X rowc )
b@	ldb	,u+		; get first byte
	;; shift byte based on mod
	lda	mod		; shift bits based on modulus
	beq	out@		; test first
a@	lsrb
	deca
	bne	a@
out@
	;; apply top nibble
	pshs	b,u		; save byte ( U x rowc u b )
	lsrb			; lookup top nibble in table
	lsrb
	lsrb
	lsrb
	ldu	#lookup
	ldb	b,u		; B = bit mask
	tfr	b,a		; A = bit mask
	andb	colorm		; B = color bits
	pshs	b		; push mask bits ( U x rowc u b mask )
	coma
	anda	,x		; get byte from screen
	ora	,s+		; apply bits ( U x rowc u b )
	sta	,x+		; save to screen
	;; apply bottom nibble
	puls	b		; get bit ( x rowc u )
	andb	#$f		; u
	ldu	#lookup
	ldb	b,u		; B = bit mask
	tfr	b,a		; A = bit mask
	andb	colorm		; B = color bits
	pshs	b		; push mask bits ( U x rowc u mask )
	coma			; A = screen mask
	anda	,x		; get byte from screen
	ora	,s+		; apply bits ( U x rowc u )
	sta	,x+		; apply to screen
	;; increment to next line
	leax	30,x		; goto next line
	puls	u		; restore glyph pointer ( U x rowc )
	dec	,s		; bump counter
	bne	b@		; do next row if not done
	puls	b,x,u,pc	; fix stack ( )

;;; Put null termed string to screen
;;;   Takes: X = screen pointer
;;;   Takes: U = string pointer
puts
a@	ldb	,u+
	beq	out@
	jsr	putb
	jsr	inc5
	bra	a@
out@	rts

	
;;; Increment X/mod by 5 pixels
inc5	pshs	b
	ldb	mod
	addb	#5
	pshs	b
	andb	#3
	stb	mod
	puls	b
	lsrb
	lsrb
	abx
	puls	b,pc


;;; divide by 10
;;;   Takes: D = dividend
;;;   returns: D = quotient, X=remainder
div
	ldx	#0
a@	leax	1,x
	subd	#10
	bpl	a@
	addd	#10
	leax	-1,x		; X = quot, D remainder
	rts

	zmb	16
scr
	
;;; print D in decimal
;;;    takes: X = screen pos
putd	pshs	d,x,u
	ldu	#scr
	clr	,-u
a@	bsr	div		
	stx	,s
	addb	#'0
	pshu	b
	ldd	,s
 	bne	a@
	ldx	2,s
	jsr	puts
	puls	d,x,u,pc

;;; print D as signed decimal
;;;   takes: X = screen pos
putsd	pshs	d,x,u
	tsta
	pshs	cc
	bpl	c@
	coma
	comb
	addd	#1
c@	ldu	#scr
	clr	,-u
a@	bsr	div		
	stx	1,s
	addb	#'0
	pshu	b
	ldd	1,s
 	bne	a@
	puls	cc
	bpl 	b@
	ldb	#'-
	pshu	b
b@	ldx	2,s
	jsr	puts
	puls	d,x,u,pc



sound_tab
	;; sound 0 - simple explosion
	.db	255		; len
	.db	8		; 1/freq
	.db	0		; 1/volume

	.db	255
	.db	6
	.db	1

	.db	255		; len
	.db	255		; 1/freq
	.db	2		; 1/v

	.db	255
	.db	255
	.db	4
	
	.dw	0		; zero termed
	;; sound 1 - large explosion
	.db	128		; len
	.db	128		; 1/freq
	.db	2		; 1/vol

	.db	128		; len
	.db	64		; 1/freq
	.db	2		; 1/vol

	.db	128		; len
	.db	16		; 1/freq
	.db	0		; 1/vol

	.db	255		; len
	.db	2		; 1/freq
	.db	0		; 1/vol
	
	.db	255		; len
	.db	255		; 1/freq
	.db	0		; 1/volume
	
	.db	255		; len
	.db	255		; 1/freq
	.db	1		; 1/volume

	.db	255		; len
	.db	255
	.db	4
	
	.dw	0		; zero termed


anim	.dw	0		; set for address of animation
	.dw	0		; address of actor


nuke_anim
	.dw	dead
	.dw	dead
	.dw	dead1
	.dw	dead1
	.dw	dead2
	.dw	dead3
	.dw	dead4
	.dw	dead5
	.dw	dead6
	.dw	dead7
	.dw	dead8
	.dw	dead8
	.dw	0
	
;;; make some noise
;;;   b=noise no.
sound
	pshs	cc,d,x
	lslb
	ldx	#sound_tab
	abx			; X = sound list
	orcc	#$50
	ldb	#$3c		; enable sound
	stb	$ff23		;
b@	ldd	,x++
	beq	out@		; is zero then end of sound
	pshs	x,u
	ldu	anim
	beq	z@
	ldu	,u
	beq	z@
	ldx	anim+2
	jsr	display_ll
	ldu	anim
	leau	2,u
	stu	anim
z@	puls	x,u
  	pshs	d		; ( freq len )
	lda	,x+
	pshs	a		; ( freq len vol )
a@	jsr	random		; get a random number
	lda	,s		; A = volume (shift count)
	beq	d@
e@	lsrb
	deca
	bne	e@
d@
*	andb	#~$3		; keep RS232 low
	orb	#$3
	stb	$ff20		; store in reg
	ldb	2,s		; get frequency
c@	decb
	bne	c@
	dec	1,s		; dec length
	bne	a@
	leas	3,s
	bra	b@
out@	ldd	anim
	beq	x@
	ldx	anim+2
	jsr	display_player
x@	clr	anim		; clear animation pointer
	clr	anim+1
	ldb	#$34		; disable sound
	stb	$ff23		;
	ldb	$ff22	
	puls	cc,d,x,pc



stt_pos	.dw	0
stt_mod	.db	0

;;; display a status message
;;;   takes: X = message
sst_mess
	pshs	d,x,u
	tfr	x,u
	ldx	stt_pos
	ldb	stt_mod
	stb	mod
	jsr	puts
	stx	stt_pos
	ldb	mod
	stb	stt_mod
	puls	d,x,u,pc

;;; clear status message
sst_clear
	pshs	d,x
	ldx	#PSCR+$1700
	stx	stt_pos
	clr	stt_mod
	clra
a@	clr	,x+
	deca
	bne	a@
	puls	d,x,pc

;;; announce a dead player
;;;   takes: B - dead player
sst_dead
	pshs	x
	jsr	sst_clear
	jsr	getplayer
	leax	P_NAME,x
	jsr	sst_mess
	ldx	#p0@
	jsr	sst_mess
	puls	x,pc
p0@	fcn	" has lost"
	
;;; announce a new player
sst_new
	pshs	x
	jsr	sst_clear
	jsr	getplayer
	leax	P_NAME,x
	jsr	sst_mess
	ldx	#p0@
	jsr	sst_mess
	puls	x,pc
p0@	fcn	" is playing"

;;; clear the text screen
clr_sscr
	ldx	#SSCR
	stx	spos
	stx	npos
	clr	spos+2
a@	clr	,x+
	cmpx	#SSCR+$1800
	bne	a@
	rts

;;; clear the play screen
clr_pscr
	ldx	#PSCR
a@	clr	,x+
	cmpx	#PSCR+$1800
	bne	a@
	rts
	

;;; print an text array to score screen
;;;   takes: Y = array of z-termed text pointers
;;;   takes: X = screen address
putcona
	pshs	d,x,y,u
a@	clr	mod
	ldu	,y++
	beq	out@
	stx	npos
	jsr	puts
	stx	spos
	ldb	mod
	stb	spos+2
	ldx	npos
	leax	(32*10),x
	bra	a@	
out@	puls	d,x,y,u,pc
	
;;; do a Splash screen
splash
	clrb
	decb
	stb	colorm
	jsr	clr_sscr	; clear screen
	ldy	#a0@		; write text
	ldx	#SSCR+(1*32)
	jsr	putcona
	jsr	draw_sscr	; display screen
	rts
a0@	.dw	p0@
	.dw	p1@
	.dw	p2@
	.dw	p3@
	.dw	p4@
	.dw	0
	fcn	"-------------------------"
p0@	fcn	"Global Thermonuclear War"
p1@	fcn	" a game that nobody wins"
p2@	fcn	" #Retrochallenge 2016"
p3@	fcn	" "
p4@	fcn	"TCP connection..."

	
;; set blinking state
set_blink		
	ldb	#(3*20)		; blink for 3 secounds
	stb	btimer
	rts

;;; do blink
do_blink
	pshs	d,x
	ldb	btimer
	beq	out@
	ldx	me
	beq	out@
	decb
	beq	b@
	stb	btimer
	andb	#8
	beq	a@
	;; draw player
b@	jsr	display_player
	bra	out@
	;; undraw player
a@	jsr	undraw_player
out@	puls	d,x,pc
	

;;; put byte to graphics consol (from A reg)
putconba
	exg	a,b
	jsr	putconb
	exg	a,b
	rts
	
;;; put byte to graphics consol
;;;   takes: B=char
putconb
	pshs	a,b,x
	ldx	spos
	ldb	spos+2
	stb	mod
	ldb	1,s
	cmpb	#BS		; is a BS?
	beq	bs@
	jsr	putb
	jsr	inc5
	stx	spos
	ldb	mod
	stb	spos+2
out@	puls	a,b,x,pc
bs@	ldb	spos+2		; get mod
	subb	#5		; sub 5
	ldx	spos
c@	leax	-1,x
	addb	#4
	bmi	c@
	stx	spos
	stb	spos+2
	stb	mod
	ldb	colorm
	pshs 	b
	clr	colorm
	ldb	#$7f
	jsr	putb
	puls	b
	stb	colorm
	bra	out@

	
;;; do a CR to consol
putconcr
	pshs	x
	ldx	npos
	leax	320,x
	stx	npos
	stx	spos
	clr	mod
	puls	x,pc

;;; get a byte from console
getconb
	pshs	a
	jsr	$a1b1
	tfr	a,b
	puls	a,pc
	
	
;;; put a string to graphic consol
putcons
	pshs	b,x
a@	ldb	,x+
	beq	out@
	jsr	putconb
	bra	a@
out@	puls	b,x,pc
	

;;; lift terrain by one
lift_terrain
	pshs	cc,d,x,u
	orcc	#$10
	;; raise entire terrain map by one.
	ldx	#terrain	; X = terrain
	lda	#32		; a counter
a@	dec	,x+		; get a level
	deca
	bne	a@
	;; raise each player (and missile and their missile ) 
	ldu	#pfield
	lda	#32		; counter
b@	ldb	,u+		; get value
	beq	next@		; if zero then no player here
	decb			; b = player no
	jsr	getplayer	; X = player struct
	dec	P_Y,x		; move player up
	ldb	P_STATE,x
	bitb	#ST_MISS	; is a missile?
	beq	next@		; nope
	pshs	a
	ldd	P_MY,x
	subd	#(8*127)	; eight lines up shifted 7 bits right
	std	P_MY,x
	puls	a
next@	deca
	bne	b@		;
	jsr	redraw_play
	puls	cc,d,x,u,pc	; return


redraw_play
	jsr	clr_pscr
	jsr	clr_pscr	;
	jsr	draw_status	;
	jsr	draw_terrain	;
	jsr	draw_players	;
	rts

draw_players
	pshs	x
	ldx	#ptab
a@	jsr	display_player
	jsr	draw_missle
	leax	P_Z,x
	cmpx	#ptab+(8*P_Z)
	bne	a@
	puls	x,pc

	
	
code_end	equ	*

	IFGE	*-PSCR
	WARNING move pscr to higher address
	ENDC

	end	start

	
