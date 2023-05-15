;==========================================================================
;
;	Small Monitor, inspired by the Apple II Monitor
;		2017-07-02	No longer assume Y will be preserved, the pointer into
;					the cli buffer is now always updated in a memory
;					location and always fetched before being used and 
;					stored back if updated, this allows action routines
;					to use all pointer registers.
;		2017-09-02	Include the pattern and hexdump features
;
;		2018-02-04	Generalized monitor
;					The Monitor is split into three modules
;
;					..\include\monitor-chartbl-v1-3.asm
;					..\include\monitor-subtbl-v1-3.asm
;					..\include\monitor-v1-3.asm
;
;					You must inlcude all three files. And when you add
;					your own commands the command character must be placed
;					after the chartable and the pointer to the routine
;					after the subtbl. You can add as many commands as needed.
;					Characters: space, '.', ':', '-', '+', '<', '/', <CR>, 
;					M, V, P, X are already used. 
;
;		.include	"../include/monitor-v1-3.asm"
;		.include	"../include/monitor-chartbl-v1-3.asm"
;			.db		0, '?'			; Help command
;
;		.include	"../include/monitor-subtbl-v1-3.asm"
;			.dw		helpscreen		; Help command
;
;
;		2018-12-31	Use preprocessor to activate options.
;					#define loaduser		Defines external load routine
;					#define	storeuser		Defines external store routine
;					#define	clibuffer		Defines external input buffer
;		2019-01-06	FAKEMON call monitor from CLI
;		2019-01-07	Do also a fake tosub for <CR> in FAKEMON
;		2019-01-08	Lower/Upper case handling removed from GETLNZ and 
;					now handled in nxtchr
;		2019-01-08	V1-6 cleanup, remove unnecessary comments
;					#define charout
;					#define charin
;		2021-11-02	ABI
;					
;==========================================================================
	.dseg
prompt:		.byte	1
mode:		.byte	1
cliptr:		.byte	2
a1l:		.byte	1
a1h:		.byte	1
a2l:		.byte	1
a2h:		.byte	1
a3l:		.byte	1
a3h:		.byte	1
a4l:		.byte	1
a4h:		.byte	1
a5l:		.byte	1
a5h:		.byte	1
a1b:		.byte	1		; 24-bit extension
a2b:		.byte	1		; 24-bit extension
a3b:		.byte	1		; 24-bit extension
a4b:		.byte	1		; 24-bit extension
a5b:		.byte	1		; 24-bit extension
bootstrap:	.byte	1
#ifndef clibuffer
clibuf:		.byte	80
#define clibuffer clibuf
#endif
#define crwidth 0x0F
	.cseg
mon:
							; This is the <entry> of the monitor
							; it expects a serout and a serin routine
							; and an initialised UART.
							; char must be defined as the register that
							; is used to send or receive a character via
							; the UART
	ldi		char, 0x07
	rcall	charout
monz:
	ldi		temp, '*'		; Prompt
	sts		prompt, temp
	ldi		yl,low(clibuffer)
	ldi		yh,high(clibuffer)
	rcall	getlnz
	sts		mode,zero
	ldi		yl,low(clibuffer)
	ldi		yh,high(clibuffer)
nxtitm:
	rcall	getnum			; Try and get a number
	ldi		temp,numchr		; getnum returns with first non digit in 'char'
	ldi		zl,low(2*chrtbl)
	ldi		zh,high(2*chrtbl)
chrsrch:
	dec		temp
	brmi	mon				; All entries done reset to monitor
	lpm		r0,Z+			; First byte of table is not used
	lpm		r0,Z+			; Get second byte
	cp		r0,char			; is it equal to character
	brne	chrsrch			; no try next
	push	yl
	push	yh
	rcall	tosub			; call appropriate action routine
	pop		yh
	pop		yl
	rjmp	nxtitm			; try to find next command
;
;	FAKEMON as implemented in the original Apple II to call
;	monitor in mini assembler when the first character is $
;	in other words you can call fakemon with a string of
;	monitor commands and have it executed. The string must
;	be terminated by a <CR>.
;
fakemon:
	sts		mode, zero
	sts		cliptr+0, yl
	sts		cliptr+1, yh
	rjmp	fakemon1

fakemon3:
	push	yl
	push	yh
	rcall	tosub
	pop		yh
	pop		yl

fakemon1:
	rcall	getnum
	
	cpi		char, 0x60		; lower case ?
	brlo	fakemon4		; nope
	andi	char, 0x5F		; Perhaps yes make sure we have upper case only
fakemon4:
	ldi		temp, numchr
	ldi		zl, low(2*chrtbl)
	ldi		zh, high(2*chrtbl)
fakemon2:
	dec		temp
	brmi	fakereset
	lpm		r0, Z+
	lpm		r0, Z+
	cp		r0, char
	brne	fakemon2
	cpi		char, CR
	brne	fakemon3
	lds		r0, mode		; Get current mode
	sts		mode, zero		; Clear next mode
	rcall	monbl1
	ret
fakereset:
	ldi		char, 0x07
	rjmp	charout
;
;	Try get a hex number
;
getnum:
	clt						; Assume no digit
	sts		a2l,zero		; Prepare number with 0
	sts		a2h,zero
	sts		a2b,zero		; 24-bit extension

nxtchr:
	ld		char,Y+			; Get Next Character in Buffer
	cpi		char, 0x60		; lower case ?
	brlo	nxtchr1			; nope
	andi	char, 0x5F		; Perhaps yes make sure we have upper case only
nxtchr1:

	cpi		char, '/'
	breq	setbank
	ldi		temp,0x30		; 
	eor		temp,char		; Convert 
	cpi		temp,0x0A		; was the character between '0' and '9'
	brlo	dig				; yes so we have a digit
	subi	temp,-0x89		; Convert so 'A' to 'F' are mapped to 0xFA to 0xFF
	cpi		temp,0xFA		; i.e. the lower nibble correponds to the value
	brsh	dig				; If higher than we have a digit
	ret						; no digit just return with Character in char

setbank:
	lds		r0,a2l			; 24-bit extension
	sts		a2b, r0			; 24-bit extension
	sts		a2l, zero		; 24-bit extension
	sts		a2h, zero		; 24-bit extension
	rjmp	digbank			; 24-bit extension

dig:
	set						; We have a digit
	andi	temp,0x0F		; Isolate Value in Temp
	mov		r0,temp			; Save value in r0
	lds		temp, a2l		; get current a2l
	swap	temp			; exchange lower and higher bits
	push	temp
	andi	temp, 0xF0		; isolate previous lower bits now higher bits
	or		temp, r0		; copy in lower bits of digit
	sts		a2l, temp		; save new value
	pop		temp			; get saved value
	andi	temp, 0x0F		; get the previous higher bits
	mov		r0, temp		; they form the new lower bits of upper byte
	lds		temp, a2h		; get old upper byte
	swap	temp
	andi	temp, 0xF0		; isolate previous lower bits in higher bits
	or		temp, r0		; copy in previous higher bits of lower byte
	sts		a2h, temp		; save new value
digbank:
	lds		r0, mode		; get mode
	tst		r0				; no mode
	brne	nxtchr
	lds		r0, a2l			; so copy the value to a1 and a3
	sts		a1l, r0
	sts		a3l, r0
	lds		r0, a2h
	sts		a1h, r0
	sts		a3h, r0
	lds		r0, a2b			; 24-bit extension
	sts		a1b, r0			; 24-bit extension
	sts		a3b, r0			; 24-bit extension
	rjmp	nxtchr
;
;	Execute Action routine for command
;
tosub:
	subi	zl, low(2-(2*numchr))
	sbci	zh, high(2-(2*numchr))
	lpm		xl, Z+			; that we skip the entry with the character)
	lpm		xh, Z+
	movw	Z,X				; Get Address to Z
	lds		r0, mode		; Get current mode
	sts		mode, zero		; Clear next mode
	ijmp					; Execute action routine
;
;	get line terminated with <CR>
;
;	Version 1.1
;		Y		must point to the buffer
;		T-bit	controls conversion to uppercase
;			0	don't convert lowercase to uppercase
;			1	convert lowercase ASCII to uppercase
;		destroys R0 and R1
;
getlnz:
	sts		cliptr+0, yl
	sts		cliptr+1, yh
getln:
	ldi		char, 0x0d
	rcall	charout
	ldi		char, 0x0a
	rcall	charout
	lds		char, prompt	; 
	rcall	charout			; Send Prompt
nxtchar:
	rcall	charin			; Get a character
	cpi		char, 0x0A		; ignore line-feeds
	breq	nxtchar			;
	cpi		char, 0x03		; Cancel
	brne	getlnz01
	ldi		char, '^'		; then send a carret
	rcall	charout
	ldi		char, 'C'		; and a capital C
	rcall	charout
	rjmp	getln			; restart with getline

getlnz01:
	cpi		char, 0x08
	breq	rubout
	cpi		char, 0x7F
	breq	rubout

	push	char
	cpi		char, 0x0D		; next is not for <CR>
	breq	getlnz02
	cpi		char, 0x20		; Is it a control character
	brsh	getlnz02
	ori		char, 0x40		; Convert to "character" echo
getlnz02:
	rcall	charout			; valid character for echo
	pop		char
	st		Y+, char		; Save Character in line buffer
	cpi		char, 0x0D		; <CR>
	brne	nxtchar			; No get another character
	ldi		char, 0x0A
	rcall	charout
	ret						; Else execute command

rubout:
	lds		zl, cliptr+0
	lds		zh, cliptr+1
	cp		yl, zl
	cpc		yh, zh
	breq	getln
	ldi		char, 0x08
	rcall	charout			; send rubout character
	ldi		char, ' '		; 
	rcall	charout
	ldi		char, 0x08
	rcall	charout
	sbiw	Y, 1
	rjmp	nxtchar

;
;	Core Monitor Routine
;
moncr:
	rcall	monbl1
	pop		yh
	pop		yl
	pop		temp
	pop		temp
	rjmp	monz

monlt:
	lds		r0, a2l
	sts		a4l, r0
	sts		a5l, r0
	lds		r0, a2h
	sts		a4h, r0
	sts		a5h, r0
	lds		r0, a2b			; 24-bit extension
	sts		a4b, r0			; 24-bit extension
	sts		a5b, r0			; 24-bit extension
	ret

monmove:
	lds		xl, a1l
	lds		xh, a1h
	rcall	load
	lds		xl, a4l
	lds		xh, a4h
	rcall	store
	rcall	nxta4
	brlo	monmove
	ret

monverify:
	lds		xl, a1l
	lds		xh, a1h
	rcall	load
	push	r0				; Save value from source
	lds		xl, a4l
	lds		xh, a4h
	rcall	load
	pop		temp			; Restore value from source
	cp		r0, temp
	breq	monverifyok
	push	r0				; Save value from a4
	push	temp			; Save value from a1
	rcall	pra1
	pop		r0				; Print value from a1
	rcall	prbyte
	ldi		temp, ' '
	mov		char, temp
	rcall	charout
	ldi		temp, '('
	mov		char, temp
	rcall	charout
	pop		r0				; Print value from a4
	rcall	prbyte
	ldi		temp, ')'
	mov		char, temp
	rcall	charout
	
monverifyok:
	rcall	nxta4
	brlo	monverify
	ret	

monbl1:						; 
	lds		zl, cliptr+0
	lds		zh, cliptr+1
	adiw	zh:zl, 1
	cp		zl, yl
	cpc		zh, yh
	breq	monxam8
monblank:
	brts	monblank2
	sts		mode, r0		; Restore Mode if no digit
	ret						; 

monblank2:
	mov		temp, r0
	cpi		temp, ':'		; Was Mode = ':'
	brne	monxampm
monstore:					; If Mode was ':' we store characters
	sts		mode, r0		; Keep in Store mode for additional data
	lds		r0, a2l			; Get low byte
	lds		xl, a3l			; Get Pointer
	lds		xh, a3h
	rcall	store
	adiw	X, 1
	sts		a3l, xl			; Save Incremented Pointer for next store
	sts		a3h, xh
	ret

monsetmode:
	sts		mode, char		; Just put the character as mode
	ret

monxam8:					; Examine next Memory up to address = 0 (mod 8)
	lds		temp, a1l		; Set A2 = A1 | 0x0007
	ori		temp, crwidth
	sts		a2l, temp
	lds		temp, a1h
	sts		a2h, temp
monmodchk:
	lds		temp, a1l
	andi	temp, crwidth
	brne	mondataout
	ldi		char, ' '
	rcall	charout
monxam:
	rcall	pra1
mondataout:
	ldi		temp, ' '
	mov		char, temp
	rcall	charout
	lds		xl, a1l
	lds		xh, a1h
	rcall	load
	rcall	prbyte
	rcall	nxta1
	brlo	monmodchk
	ret

monxampm:
	sbrs	r0, 0			; + and - are odd, : and . are even ASCII values
	rjmp	monxam			; if : or . goto exam
	lds		temp, a2l
	sbrs	r0, 1			; + = 0x2B and - = 0x2D so - has bit 1 clear
	neg		temp			; take negative value
	lds		r0, a1l
	add		r0, temp
	ldi		temp, 0x0d
	mov		char, temp
	rcall	charout
	ldi		temp, 0x0a
	mov		char, temp
	rcall	charout
	ldi		temp, '='
	mov		char, temp
	rcall	charout
prbyte:
	mov		char, r0
	swap	char
	rcall	prhex
	mov		char, r0
prhex:
	ldi		temp, 0x0F
	and		char, temp
prhexz:
	ldi		temp, 10
	cp		char, temp
	ldi		temp, '0'
	brlo	prbyte01
	ldi		temp, 'A'-10
prbyte01:
	add		char, temp
	rjmp	charout

prntx:
	mov		r0, xh
	rcall	prbyte
prntxl:
	mov		r0, xl
	rcall	prbyte
prblnk:
	ldi		temp, ' '
	mov		char, temp
	rcall	charout
	rcall	charout
	rjmp	charout

pra1:
	lds		xl, a1l
	lds		xh, a1h
prx:
	ldi		temp, 0x0d
	mov		char, temp
	rcall	charout
	ldi		temp, 0x0a
	mov		char, temp
	rcall	charout
	rcall	prntx
	ldi		temp, '-'
	mov		char, temp
	rjmp	charout

nxta4:
	lds		temp, a4l
	inc		temp
	sts		a4l, temp
	brne	nxta1
	lds		temp, a4h
	inc		temp
	sts		a4h, temp
nxta1:
	lds		temp, a1l
	lds		r0, a2l
	cp		temp, r0
	lds		temp, a1h
	lds		r0, a2h
	cpc		temp, r0
	lds		temp, a1l
	inc		temp
	sts		a1l, temp
	brne	rts4b
	lds		temp, a1h
	inc		temp
	sts		a1h, temp
rts4b:
	ret	

;==========================================================================
;
;	Hooks
;
;
#ifndef charout
charout:
	rjmp		serout
#endif
#ifndef charin
charin:
	rjmp		serin
#endif
;
;	Monitor Load and Store routines. 
;
;	X		16-bit address
;	r0		Byte to store to return
;
;	The main program can define it's own load and store routines. In 
;	this case it must define loadusr and storeusr variables to suppress
;	the inclusion of the default load and store routines.
;
#ifndef loaduser
load:
	ld		r0, X
	ret
#endif
#ifndef storeuser
store:
	st 		X, r0
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
	clr		temp
monpattern010:
	lds		xl, a1l
	lds		xh, a1h
	st		X, temp
	inc		temp
	push	temp
	rcall	nxta1
	pop		temp
	brlo	monpattern010
	ret

;
;	Output as in hexdump -C but only for 16bytes
;
monhexline2:
	rcall	monhexline
monhexline:
	ldi		temp, 8
monhexline010:
	push	temp
	ld		r0, X+
	rcall	prbyte
	ldi		char, ' '
	rcall	charout
	pop		temp
	dec		temp
	brne	monhexline010
	rcall	charout
	ret
;
;
;
monhexchar:
	ldi		char, '|'
	rcall	charout
	ldi		temp, 16
monhexchar010:
	push	temp
	ld		char, X+
	cpi		char, 0x20
	brlo	monhexchardot
	cpi		char, 0x7f
	brlo	monhexcharout
monhexchardot:
	ldi		char, '.'
monhexcharout:
	rcall	charout
	pop		temp
	dec		temp
	brne	monhexchar010
	ldi		char, '|'
	rcall	charout
	ret
;
;
;	
monhexdump:
	lds		xl, a1l				; Get start address
	lds		xh, a1h				; used by prx
	andi	xl, 0xF0			; Make it 16-byte boundary
	sts		a1l, xl				; save it back to start address
	
	rcall	prx					; print address and '-'
	ldi		char, ' '			; space
	rcall	charout
	lds		xh, a1h				; Get address
	lds		xl, a1l
	rcall	monhexline2			; Print monhex Values
	lds		xh, a1h				; Restart at first address
	lds		xl, a1l
	rcall	monhexchar				; Print ASCII (or . vor invalid)
	sts		a1l, xl
	sts		a1h, xh				; Advance address
	ret
