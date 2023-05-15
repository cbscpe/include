;==========================================================================
;
;	Small Monitor, inspired by the Apple II Monitor
;	2017-07-02	No longer assume Y will be preserved, the pointer into
;			the cli buffer is now always updated in a memory
;			location and always fetched before being used and 
;			stored back if updated, this allows action routines
;			to use all pointer registers.
;	2017-09-02	Include the pattern and hexdump features
;
;	2018-02-04	Generalized monitor
;			The Monitor is split into three modules
;
;			..\include\monitor-v2-0.inc
;			..\include\monitor-chartbl-v2-0.asm
;			..\include\monitor-subtbl-v2-0.asm
;			..\include\monitor-v2-0.asm
;
;			You must inlcude all three files. And when you add
;			your own commands the command character must be placed
;			after the chartable and the pointer to the routine
;			after the subtbl. You can add as many commands as needed.
;			Characters: space, '.', ':', '-', '+', '<', '/', <CR>, 
;			M, V, P, X are already used. 
;
;	.include	"../include/monitor-v1-3.asm"
;	.include	"../include/monitor-chartbl-v1-3.asm"
;	.db		0, '?'			; Help command
;	.include	"../include/monitor-subtbl-v1-3.asm"
;	.dw		helpscreen		; Help command
;
;
;	2018-12-31	Use preprocessor to activate options.
;			#define loaduser		Defines external load routine
;			#define	storeuser		Defines external store routine
;
;	2021-11-02	ABI void mon(char* clibuffer, char prompt);
;
;	2021-12-22	Save R2,R4, R5 to keep a copy of input parameteres
;			Use R24 for Load/Store
;			Use R25 as general purpose internal register
;					
;==========================================================================
	.cseg
mon:
					; This is the <entry> of the monitor
	push	r2			; it expects a serout and a serin routine
	push	r4			; and an initialised UART.
	push	r5			; char must be defined as the register that
	push	yl			; is used to send or receive a character via
	push	yh			; the UART
	mov	r2, r22			; Save Prompt
	movw	r5:r4, r25:r24		; Save Buffer
monb:
	ldi	r24, 0x07
	rcall	charout
monz:
	movw	yh:yl, r5:r4
	rcall	getlnz
	sts	mode,zero
	movw	yh:yl, r5:r4
nxtitm:
	rcall	getnum			; Try and get a number
	ldi	r16,numchr		; getnum returns with first non digit in 'char'
	ldi	zl,low(2*chrtbl)
	ldi	zh,high(2*chrtbl)
chrsrch:
	dec	r16
	brmi	monb			; All entries done reset to monitor
	lpm	r25,Z+			; First byte of table is not used
	lpm	r25,Z+			; Get second byte
	cp	r25,r24			; is it equal to character
	brne	chrsrch			; no try next
	push	yl
	push	yh
	rcall	tosub			; call appropriate action routine
	pop	yh
	pop	yl
	rjmp	nxtitm			; try to find next command
;
;	FAKEMON as implemented in the original Apple II to call
;	monitor in mini assembler when the first character is $
;	in other words you can call fakemon with a string of
;	monitor commands and have it executed. The string must
;	be terminated by a <CR>.
;
fakemon:
	sts	mode, zero
	push	r4
	push	r5
	push	yl
	push	yh
	movw	r5:r4, r25:r24
	movw	yh:yl, r25:r24
	rjmp	fakemon1

fakemon3:
	push	yl
	push	yh
	rcall	tosub
	pop	yh
	pop	yl

fakemon1:
	rcall	getnum
	
	cpi	r24, 0x60		; lower case ?
	brlo	fakemon4		; nope
	andi	r24, 0x5F		; Perhaps yes make sure we have upper case only
fakemon4:
	ldi	r16, numchr
	ldi	zl, low(2*chrtbl)
	ldi	zh, high(2*chrtbl)
fakemon2:
	dec	r16
	brmi	fakereset
	lpm	r25, Z+
	lpm	r25, Z+
	cp	r25, r24
	brne	fakemon2		; Try next command
	cpi	r24, CR			; special case CR
	brne	fakemon3		; all other commands are executed as normal
	lds	r25, mode		; Get current mode
	sts	mode, zero		; Clear next mode
	rcall	monbl1			; CR for fakemon
	pop	yh
	pop	yl
	pop	r5
	pop	r4
	ret
fakereset:
	pop	yh
	pop	yl
	pop	r5
	pop	r4
	ldi	r24, 0x07
	rjmp	charout
;
;	Try get a hex number
;
getnum:
	clt				; Assume no digit
	sts	a2l,zero		; Prepare number with 0
	sts	a2h,zero
	sts	a2b,zero		; 24-bit extension

nxtchr:
	ld	r24,Y+			; Get Next Character in Buffer
	cpi	r24, 0x60		; lower case ?
	brlo	nxtchr1			; nope
	andi	r24, 0x5F		; Perhaps yes make sure we have upper case only
nxtchr1:

	cpi	r24, '/'
	breq	setbank
	ldi	r16,0x30		; 
	eor	r16,r24			; Convert 
	cpi	r16,0x0A		; was the character between '0' and '9'
	brlo	dig			; yes so we have a digit
	subi	r16,-0x89		; Convert so 'A' to 'F' are mapped to 0xFA to 0xFF
	cpi	r16,0xFA		; i.e. the lower nibble correponds to the value
	brsh	dig			; If higher than we have a digit
	ret				; no digit just return with Character in char

setbank:
	lds	r25,a2l			; 24-bit extension
	sts	a2b, r25		; 24-bit extension
	sts	a2l, zero		; 24-bit extension
	sts	a2h, zero		; 24-bit extension
	rjmp	digbank			; 24-bit extension

dig:
	set				; We have a digit
	andi	r16,0x0F		; Isolate Value in r16
	mov	r25,r16			; Save value in r25
	lds	r16, a2l		; get current a2l
	swap	r16			; exchange lower and higher bits
	push	r16
	andi	r16, 0xF0		; isolate previous lower bits now higher bits
	or	r16, r25			; copy in lower bits of digit
	sts	a2l, r16		; save new value
	pop	r16			; get saved value
	andi	r16, 0x0F		; get the previous higher bits
	mov	r25, r16			; they form the new lower bits of upper byte
	lds	r16, a2h		; get old upper byte
	swap	r16
	andi	r16, 0xF0		; isolate previous lower bits in higher bits
	or	r16, r25			; copy in previous higher bits of lower byte
	sts	a2h, r16		; save new value
digbank:
	lds	r25, mode		; get mode
	tst	r25			; no mode
	brne	nxtchr
	lds	r25, a2l			; so copy the value to a1 and a3
	sts	a1l, r25
	sts	a3l, r25
	lds	r25, a2h
	sts	a1h, r25
	sts	a3h, r25
	lds	r25, a2b			; 24-bit extension
	sts	a1b, r25			; 24-bit extension
	sts	a3b, r25			; 24-bit extension
	rjmp	nxtchr
;
;	Execute Action routine for command
;
tosub:
	subi	zl, low(2-(2*numchr))
	sbci	zh, high(2-(2*numchr))
	lpm	xl, Z+			; that we skip the entry with the character)
	lpm	xh, Z+
	movw	Z,X			; Get Address to Z
	lds	r25, mode		; Get current mode
	sts	mode, zero		; Clear next mode
	ijmp				; Execute action routine
;
;	get line terminated with <CR>
;
;	Version 1.1
;	Y		must point to the buffer
;	T-bit	controls conversion to uppercase
;		0	don't convert lowercase to uppercase
;		1	convert lowercase ASCII to uppercase
;	destroys r25
;
getlnz:
	movw	xh:xl, yh:yl
getln:
	ldi	r24, 0x0d
	rcall	charout
	ldi	r24, 0x0a
	rcall	charout
	mov	r24, r2
	rcall	charout			; Send Prompt
nxtchar:
	rcall	charin			; Get a character
	cpi	r24, 0x0A		; ignore line-feeds
	breq	nxtchar			;
	cpi	r24, 0x03		; Cancel
	brne	getlnz01
	ldi	r24, '^'		; then send a carret
	rcall	charout
	ldi	r24, 'C'		; and a capital C
	rcall	charout
	rjmp	getln			; restart with getline

getlnz01:
	cpi	r24, 0x08
	breq	rubout
	cpi	r24, 0x7F
	breq	rubout

	push	r24
	cpi	r24, 0x0D		; next is not for <CR>
	breq	getlnz02
	cpi	r24, 0x20		; Is it a control character
	brsh	getlnz02
	ori	r24, 0x40		; Convert to "character" echo
getlnz02:
	rcall	charout			; valid character for echo
	pop	r24
	st	Y+, r24			; Save Character in line buffer
	cpi	r24, 0x0D		; <CR>
	brne	nxtchar			; No get another character
	ldi	r24, 0x0A
	rcall	charout
	ret				; Else execute command

rubout:
	cp	yl, xl
	cpc	yh, xh
	breq	getln
	ldi	r24, 0x08
	rcall	charout			; send rubout character
	ldi	r24, ' '		; 
	rcall	charout
	ldi	r24, 0x08
	rcall	charout
	sbiw	Y, 1
	rjmp	nxtchar

;
;	Core Monitor Routine
;
moncr:
	rcall	monbl1
	pop	yh
	pop	yl
	pop	r16
	pop	r16
	rjmp	monz

monlt:
	lds	r25, a2l
	sts	a4l, r25
	sts	a5l, r25
	lds	r25, a2h
	sts	a4h, r25
	sts	a5h, r25
	lds	r25, a2b			; 24-bit extension
	sts	a4b, r25			; 24-bit extension
	sts	a5b, r25			; 24-bit extension
	ret

monmove:
	lds	xl, a1l
	lds	xh, a1h
	rcall	load
	lds	xl, a4l
	lds	xh, a4h
	rcall	store
	rcall	nxta4
	brlo	monmove
	ret

monverify:
	lds	xl, a1l
	lds	xh, a1h
	rcall	load
	push	r24			; Save value from source
	lds	xl, a4l
	lds	xh, a4h
	rcall	load
	pop	r16			; Restore value from source
	cp	r24, r16
	breq	monverifyok
	push	r24			; Save value from a4
	push	r16			; Save value from a1
	rcall	pra1
	pop	r25			; Print value from a1
	rcall	prbyte
	ldi	r16, ' '
	mov	r24, r16
	rcall	charout
	ldi	r16, '('
	mov	r24, r16
	rcall	charout
	pop	r25			; Print value from a4
	rcall	prbyte
	ldi	r16, ')'
	mov	r24, r16
	rcall	charout
	
monverifyok:
	rcall	nxta4
	brlo	monverify
	ret	

monbl1:					; 
	movw	zh:zl, r5:r4
	adiw	zh:zl, 1
	cp	zl, yl
	cpc	zh, yh
	breq	monxam8
monblank:
	brts	monblank2
	sts	mode, r25		; Restore Mode if no digit
	ret				; 

monblank2:
	mov	r16, r25
	cpi	r16, ':'		; Was Mode = ':'
	brne	monxampm
monstore:				; If Mode was ':' we store characters
	sts	mode, r25		; Keep in Store mode for additional data
	lds	r24, a2l			; Get low byte
	lds	xl, a3l			; Get Pointer
	lds	xh, a3h
	rcall	store
	adiw	X, 1
	sts	a3l, xl			; Save Incremented Pointer for next store
	sts	a3h, xh
	ret

monsetmode:
	sts	mode, r24		; Just put the character as mode
	ret

monxam8:				; Examine next Memory up to address = 0 (mod 8)
	lds	r16, a1l		; Set A2 = A1 | 0x0007
	ori	r16, crwidth
	sts	a2l, r16
	lds	r16, a1h
	sts	a2h, r16
monmodchk:
	lds	r16, a1l
	andi	r16, crwidth
	brne	mondataout
	ldi	r24, ' '
	rcall	charout
monxam:
	rcall	pra1
mondataout:
;	ldi	r16, ' '
;	mov	r24, r16
	ldi	r24, ' '
	cpi	r16, 0x08
	brne	mondataout010
	rcall	charout
mondataout010:
	rcall	charout
	lds	xl, a1l
	lds	xh, a1h
	rcall	load
	mov	r25, r24		; prbyte exepcts parameter in r25
	rcall	prbyte
	rcall	nxta1
	brlo	monmodchk
	ret

monxampm:
	sbrs	r25, 0			; + and - are odd, : and . are even ASCII values
	rjmp	monxam			; if : or . goto exam
	lds	r16, a2l
	sbrs	r25, 1			; + = 0x2B and - = 0x2D so - has bit 1 clear
	neg	r16			; take negative value
	lds	r25, a1l
	add	r25, r16
	ldi	r16, 0x0d
	mov	r24, r16
	rcall	charout
	ldi	r16, 0x0a
	mov	r24, r16
	rcall	charout
	ldi	r16, '='
	mov	r24, r16
	rcall	charout
prbyte:
	mov	r24, r25
	swap	r24
	rcall	prhex
	mov	r24, r25
prhex:
	ldi	r16, 0x0F
	and	r24, r16
prhexz:
	ldi	r16, 10
	cp	r24, r16
	ldi	r16, '0'
	brlo	prbyte01
	ldi	r16, 'A'-10
prbyte01:
	add	r24, r16
	rjmp	charout

prntx:
	mov	r25, xh
	rcall	prbyte
prntxl:
	mov	r25, xl
	rcall	prbyte
prblnk:
	ldi	r16, ' '
	mov	r24, r16
	rcall	charout
	rcall	charout
	rjmp	charout

pra1:
	lds	xl, a1l
	lds	xh, a1h
prx:
	ldi	r16, 0x0d
	mov	r24, r16
	rcall	charout
	ldi	r16, 0x0a
	mov	r24, r16
	rcall	charout
	rcall	prntx
	ldi	r16, '-'
	mov	r24, r16
	rjmp	charout

nxta4:
	lds	r16, a4l
	inc	r16
	sts	a4l, r16
	brne	nxta1
	lds	r16, a4h
	inc	r16
	sts	a4h, r16
nxta1:
	lds	r16, a1l
	lds	r25, a2l
	cp	r16, r25
	lds	r16, a1h
	lds	r25, a2h
	cpc	r16, r25
	lds	r16, a1l
	inc	r16
	sts	a1l, r16
	brne	rts4b
	lds	r16, a1h
	inc	r16
	sts	a1h, r16
rts4b:
	ret	

;==========================================================================
;
;	Hooks
;
;
#ifndef charout
charout:
	jmp	serout
#endif
#ifndef charin
charin:
	jmp	serin
#endif
;
;	Monitor Load and Store routines. 
;
;	X	16-bit address
;	r24	Byte to store to return
;
;	The main program can define it's own load and store routines. In 
;	this case it must define loadusr and storeusr variables to suppress
;	the inclusion of the default load and store routines.
;
#ifndef loaduser
load:
	ld	r24, X
	ret
#endif
#ifndef storeuser
store:
	st 	X, r24
	ret
#endif
;--------------------------------------------------------------------------
;
;	Monitor Function Routines
;
;
;	Store incrementing values to the range given starting with 0 this
;	is used to create a pattern in RAM to check that the ROM reading
;	logic is correct.
;
monpattern:
	clr	r16
monpattern010:
	lds	xl, a1l
	lds	xh, a1h
	st	X, r16
	inc	r16
	push	r16
	rcall	nxta1
	pop	r16
	brlo	monpattern010
	ret

;
;	Output as in hexdump -C but only for 16bytes
;
monhexline2:
	rcall	monhexline
monhexline:
	ldi	r16, 8
monhexline010:
	push	r16
	ld	r25, X+
	rcall	prbyte
	ldi	r24, ' '
	rcall	charout
	pop	r16
	dec	r16
	brne	monhexline010
	rcall	charout
	ret
;
;
;
monhexchar:
	ldi	r24, '|'
	rcall	charout
	ldi	r16, 16
monhexchar010:
	push	r16
	ld	r24, X+
	cpi	r24, 0x20
	brlo	monhexchardot
	cpi	r24, 0x7f
	brlo	monhexcharout
monhexchardot:
	ldi	r24, '.'
monhexcharout:
	rcall	charout
	pop	r16
	dec	r16
	brne	monhexchar010
	ldi	r24, '|'
	rcall	charout
	ret
;
;
;	
monhexdump:
	lds	xl, a1l				; Get start address
	lds	xh, a1h				; used by prx
	andi	xl, 0xF0			; Make it 16-byte boundary
	sts	a1l, xl				; save it back to start address
	
	rcall	prx				; print address and '-'
	ldi	r24, ' '			; space
	rcall	charout
	lds	xh, a1h				; Get address
	lds	xl, a1l
	rcall	monhexline2			; Print monhex Values
	lds	xh, a1h				; Restart at first address
	lds	xl, a1l
	rcall	monhexchar			; Print ASCII (or . vor invalid)
	sts	a1l, xl
	sts	a1h, xh				; Advance address
	ret
