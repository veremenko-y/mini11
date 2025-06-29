;
;	mini 11 bootstrap
;
.set spcr,	0x28
.set spsr,	0x29
.set spdr,	0x2a
.set pddr,	0x08
.set ddrd,	0x09
.set tmsk2,	0x24
.set pactl,	0x26

.set baud,	0x2b
.set sccr1,	0x2c
.set sccr2,	0x2d
.set scsr,	0x2e
.set scdr,	0x2f

.set ctmmc,	1
.set ctsd2,	2
.set ctsdblk,	3
.set ctsd1,	4

.set porta,	0x00

	.section .bss ; 0xf040 
cardtype:
	.byte	0

buf:
	.byte	0,0,0,0,0,0,0,0

	.section .text ; 0xf800 
reset_vector:
	;	put the internal ram at f040-f0ff
	;	and i/o at f000-f03f. this costs s 64bits of iram
	;	but gives us a nicer addressing map.
	ldaa	#0xff
	staa  	0x103d
	ldx	#0xf000
	;	free running timer on divide by 16
	ldaa	0x24,x
	oraa    #3
	staa	0x24,x
	;	set up the memory
	;	ensure we are in ram bank 0, romen, cs1 high
	;	regardless of any surprises at reset
	ldaa	#0x80
	staa	porta,x
	bset	pactl,x 0x80
	ldaa	#0x13
	staa	0x39,x	;cop slow, dly still on
	sei
	ldaa	#0x30
	staa	baud,x	; baud
	ldaa	#0x00
	staa	sccr1,x	; sccr1
	ldaa	#0x0c
	staa	sccr2,x	; sccr2
	;	serial is now 9600 8n1 for the 8mhz crystal
	lds	#0xf0ff


	ldy	#init
	jsr	strout

	ldaa	0x3f,x	; config
	jsr	phex	; display it

	ldy	#init2
	jsr	strout
	;
	;	probe for an sd card and set it up as tightly as we can
	;

	ldaa #0x38	; spi outputs on
	staa ddrd,x
	ldaa #0x52	; spi on, master, mode 0, slow (125khz)
	staa spcr,x

	;	raise cs send clocks
	jsr  csraise
	ldaa #200	; time for sd to stabilize
csloop:
	jsr  sendff
	deca
	bne csloop
	ldy #cmd0
	bsr  sendcmd
	decb	; 1 ?
	bne sdfailb
	ldy #cmd8
	jsr sendcmd
	decb
	beq newcard
	jmp oldcard
newcard:
	bsr get4
	ldd buf+2
	cmpd #0x01aa
	bne sdfaild
wait41:
	ldy #acmd41
	jsr sendacmd
	bne wait41
	ldy #cmd58
	jsr sendcmd
	bne sdfailb
	bsr get4
	ldaa buf
	anda #0x40
	bne blocksd2
	ldaa #ctsd2
initok:
	staa cardtype
	jmp loader

get4:
	ldaa #4
	ldy #buf
get4l:
	jsr sendff
	stab ,y
	iny
	deca
	bne get4l
	rts

sdfaild:
	jsr phex
sdfailb:
	tba
sdfaila:
	jsr phex
	ldy #error
	jmp fault

sendacmd:
	pshy
	ldy #cmd55
	jsr sendcmd
	puly
sendcmd:
	jsr csraise
	bsr cslower
	cmpy #cmd0
	beq nowaitff
waitff:
	jsr sendff
	incb
	bne waitff
nowaitff:
	; command, 4 bytes data, crc all preformatted
	ldaa #6
sendlp:
	ldab ,y
	jsr send
	iny
	deca
	bne sendlp
	jsr sendff
waitret:
	jsr sendff
	bitb #0x80
	bne waitret
	cmpb #0x00
	rts

sdfail2:
	bra sdfailb

cslower:
	bclr pddr,x 0x20
	rts
blocksd2:
	ldaa #ctsdblk
	jmp initok
oldcard:
	ldy #acmd41_0	; fixme _0 check ?
	jsr sendacmd
	cmpb #2
	bhs mmc
wait41_0:
	ldy #acmd41_0
	jsr sendacmd
	bne wait41_0
	ldaa #ctsd1
	staa cardtype
	bra secsize
mmc:
	ldy #cmd1
	jsr sendcmd
	bne mmc
	ldaa #ctmmc
	staa cardtype
secsize:
	ldy #cmd16
	jsr sendcmd
	bne sdfail2
loader:
	bsr csraise
	ldy #cmd17
	jsr sendcmd
	bne sdfail2
waitdata:
	jsr sendff
	cmpb #0xfe
	bne waitdata
	ldy #0x0
	clra
dataloop:
	jsr sendff
	stab ,y
	jsr sendff
	stab 1,y
	iny
	iny
	deca
	bne dataloop
	bsr csraise
	ldy #0x0
	ldd ,y
	cpd #0x6811
	bne noboot
	ldaa cardtype
	jmp 2,y

;
;	this lot must preserve a
;
csraise:
	bset pddr,x 0x20
sendff:
	ldab #0xff
send:
;	psha
;	tba
;	jsr phex
;	lda #':'
;	jsr chout
;	pula
	stab spdr,x
sendw:	brclr spsr,x 0x80 sendw
	ldab spdr,x
;	psha
;	tba
;	jsr phex
;	ldaa #10
;	jsr chout
;	ldaa #13
;	jsr chout
;	pula
	rts

;
;	commands
;
cmd0:
	.byte 0x40,0,0,0,0,0x95
cmd1:
	.byte 0x41,0,0,0,0,0x01
cmd8:
	.byte 0x48,0,0,0x01,0xaa,0x87
cmd16:
	.byte 0x50,0,0,2,0,0x01
cmd17:
	.byte 0x51,0,0,0,0,0x01
cmd55:	
	.byte 0x77,0,0,0,0,0x01
cmd58:
	.byte 0x7a,0,0,0,0,0x01
acmd41_0:
	.byte 0x69,0,0,0,0,0x01
acmd41:
	.byte 0x69,0x40,0,0,0,0x01

noboot: ldy	#noboot
	.ascii	"not bootable"
	.byte	13,10,0
fault:	jsr	strout
stopb:	bra	stopb

init:
	.ascii	"mini11 68hc11 system, (c) 2019-2023 alan cox"
	.byte	13,10
	.ascii	"firmware revision: 0.1.1"
	.byte	13,10,13,10
	.ascii	"mc68hc11 config register "
	.byte	0

init2:
	.byte	13,10
	.ascii	"booting from sd card..."
	.byte	13,10,0

error:
	.ascii	"sd error"
	.byte	13,10,0

	;
	;	serial i/o	
	;

phex:	psha
	lsra
	lsra
	lsra
	lsra
	bsr	hexdigit
	pula
	anda #0x0f
hexdigit:
	cmpa #10
	bmi lo
	adda #7
lo:	adda #'0'
chout:	brclr	scsr,x 0x80 chout
	staa	scdr,x
choute:	brclr	scsr,x 0x80 choute	; helps debug as it's now sync
strdone: rts
strout:	ldaa	,y
	beq	strdone
	bsr	chout
	iny
	bra	strout

.section .vectors ; 0xfffe
vectors:
	.word	reset_vector
