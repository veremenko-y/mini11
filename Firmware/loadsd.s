;
;	the sd boot code hands us
;	a = card type
;	x = i/o base (0xf000)
;	y = our base
;	s = internal ram somewere at f0ff or so
;	p = interrupts off
;
;	io at f000, iram at f000 (with some overlap)
;

	.text

.set ctmmc, 1
.set ctsd2, 2
.set ctsdblk, 3
.set ctsd1, 4

.set spcr, 0x28
.set spsr, 0x29
.set spdr, 0x2a
.set pddr, 0x08
.set ddrd, 0x09

	.word	0x6811
start:
	bra gostart

lbainc:	.word	0x200
cardtype:
	.byte	0x00
cmd17:
	.byte 0x51
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0x01

gostart:
	; block or byte lba - set lbainc accordingly
	staa cardtype
	cmpa #ctsdblk
	bne bytemode
	ldd #1
	std lbainc
bytemode:
	ldaa #0x50		; spi on master, faster
	staa spcr,x

	ldaa #0x23
	staa 0xfe7b		; ram 3 in place of rom

	ldy #0x0200
	ldaa #0x77		; 0xee00 bytes (0x0200-0xefff)

loadloop:
	psha			; save count

	pshy			; save pointer whist we do the command
	ldy #cmd17
	; move on an lba block
	ldd 3,y			; update the offset or lba number
	addd lbainc
	std 3,y
	jsr sendcmd		; send a read command
	bne sdfail
waitdata:
	bsr sendff		; wait for the fe marker
	cmpb #0xfe
	bne waitdata
	puly			; recover data pointer
	clra			; copy count (512 bytes)
dataloop:
	bsr sendff
	stab ,y
	bsr sendff
	stab 1,y
	iny
	iny
	deca
	bne dataloop
	bsr csraise		; end command
	ldaa #'.'
	bsr outch
	pula			; recover counter
	deca
	bne loadloop		; done ?
	ldaa #0x0d
	bsr outch
	ldaa #0x0a
	bsr outch
	jmp 0x0200		; and run

sdfail: ldaa #'e'
fault:	bsr outch
stopb:	bra stopb

outch:
	brclr 0x2e,x 0x80 outch
	staa 0x2f,x
	rts

cslower:
	bclr pddr,x 0x20
	rts
;
;	this lot must preserve a
;
csraise:
	bset pddr,x 0x20
sendff:
	ldab #0xff
send:
	stab spdr,x
sendw:
	brclr spsr,x 0x80 sendw
	ldab spdr,x
	rts

sendcmd:
	bsr csraise
	bsr cslower
waitff:
	bsr sendff
	incb
	bne waitff
nowaitff:
	; command, 4 bytes data, crc all preformatted
	ldaa #6
sendlp:
	ldab ,y
	bsr send
	iny
	deca
	bne sendlp
	bsr sendff
waitret:
	bsr sendff
	bitb #0x80
	bne waitret
	cmpb #0x00
	rts
