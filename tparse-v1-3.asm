;==========================================================================
;
;	Parsing a command line:
;
;	Command lines consist of keywords, strings, etc.. Keywords can be
;	abreviated and are case insensitive. Keywords may have a suffix
;	in the form of a number or a number followed by a colon. The parser
;	uses tables with 3 entries
;
;		-	pointer to desciption of syntax element, 0 means no further 
;			checks possible, i.e. the scan of the command failed or in
;			other words this is not a valid command
;		-	action routine to call in case of success, 0 no action routine
;			this is typically required to make note of the results produced
;			when scanning the syntax element, e.g. the suffix number, the 
;			number or the string/quoted string found
;		-	if the element matches then the third entry gives the address
;			of the next parser table or "cmd_done" in case the end of the
;			command has been reached, if no match the parser proceeds
;			to the following entry
;
;	A syntax element consists of a type followd by additional parameters. In
;	case of keywords the name of the keyword is given the mandatory part must
;	be given in capital and the optional part in lower case. In case of a sub-
;	command the parameter is a pointer to a command table (the parser calls 
;	itself using this pointer as the table pointer)
;
;	A Table must be terminated with a 0 to indicated the end. If you want
;	a command to be valid you must typically scan up to the terminating 
;	character, in our case <CR>, using the eol syntax element and a next
;	table pointer of cmd_done ( -1). You can use cmd_done with every syntax
; 	element type. 
;
;	
;
;	When calling the parser Z must point to the start table (caution it must
;	be a byte pointer for lpm, typically twice the address) and X must point
;	to the string to be parsed. If the sring could be parsed successfully
;	carry will be cleared on return. Else carry will be set. X will point
;	to the position up to which the parser has analyzed the string (not
;	necessarily the end of the string)
;
;
;	1.2		11-10-2020	-	Add Switch as syntax element
;						-	Add Flag to select white space as a syntax element
;
	.cseg
;--------------------------------------------------------------------------
;
;	Re-entering scancommand with subcommand
;
;	Input:
;		Z		Pointer to parser table in flash
;		X		Pointer to string
;
scansubcmd:
	call	print
	.db		0x0a, 0x0d, "Subcommand:", 0x0a, 0x0d, 0x00
	movw	zh:zl, r25:r24
	adiw	zh:zl, 1
	lpm		r24, Z+
	lpm		r25, Z+
	add		r24, r24
	adc		r25, r25
	movw	zh:zl, r25:r24
;--------------------------------------------------------------------------
;
;	Process Command Table Entry
;
;	Input:
;		Z		Pointer to parser table
;		X		Pointer to string
;
;	Output:
;		Z		
;		X		Points after the last byte successfully parsed
;
;	Conditions:
;		CS		syntax error
;		CC		parsing string sucessfully
;
;	Registers:
;
;		r4, r5, r6, r7, temp, char, r24, r25
;
scancommand:
;-	rcall	scandebugtable
	lpm	r24, Z+
	lpm	r25, Z+			; Get address of syntax element Z->Action
	sbiw	r25:r24, 0
	breq	scancommandfailed	; End of Table
	push	xl
	push	xh			; Save command buffer pointer
	push	zl
	push	zh			; Save pointer Z->Action
	add	r24, r24
	adc	r25, r25		; Convert address to Z byte pointer
	movw	zh:zl, r25:r24		;
	rcall	scanskipblank
	rcall	scanelement
	brcs	scannextentry
	pop	zh
	pop	zl			; Restore pointer Z->Action
	lpm	r24, Z+
	lpm	r25, Z+			; Get address of action routine Z->Next
	push	zl
	push	zh			; Save pointer Z->Next

	sbiw	r25:r24, 0
	breq	scannoaction

;-	rcall	scandebugaction
	movw	zh:zl, r25:r24
	icall	
;-	rcall	scandebugresult
	brcs	scannextentry2

scannoaction:
	pop	zh
	pop	zl			; Restore pointer Z->Next
	pop	r25
	pop	r24			; Discard saved buffer pointer
	lpm	r24, Z+
	lpm	r25, Z+			; Next Table
;-	rcall	scandebugnext
	sbiw	r25:r24, 0
	breq	scancommand		; Just next entry
	movw	zh:zl, r25:r24
	adiw	r25:r24, -cmd_done
	breq	scancommanddone
	add	zl, zl
	adc	zh, zh
	rjmp	scancommand

scannextentry:
;-	rcall	scandebugentry
	pop	zh
	pop	zl			; Restore Pointer Z->Action
	pop	xh
	pop	xl			; Previous command buffer pointer
	adiw	zh:zl, 4		; Skip action and next table address
	rjmp	scancommand

scannextentry2:
;-	rcall	scandebugentry2
	pop	zh
	pop	zl			; Restore pointer Z->Next
	pop	xh
	pop	xl			; Previou buffer pointer
	adiw	zh:zl, 2		; Skip next table address
	rjmp	scancommand

;
;
;
scancommandfailed:
	call	print
	.db	0x0a, 0x0d, "--Unidentified Command.", 0x0a, 0x0d, 0x00
	sec
	ret

scancommanddone:
	movw	zh:zl, r25:r24			
;-	call	print
;-	.db		"--Command Done!", CR, LF, 0
	clc
	ret
;
;	Skip blanks
;
scanskipnext:
	adiw	X, 1
scanskipblank:
	ld	char, X
	cpi	char, ' '
	breq	scanskipnext
	ret
;
;	scanelement
;
;	X	pointer to inputbuffer
;	Z	pointer to element descriptione
;
scanelement:
	lpm	temp, Z+
	movw	r25:r24, zh:zl
	mov	zl, temp
	andi	zl, 0x7f					; Remove marker bit
;-	rcall	scandebug
	cpi	zl, scantablesize			; Check against table size
	brsh	scanillegal
	clr	zh							; Make pointer to jump table
	subi	zl, low(-scantable)
	sbci	zh, high(-scantable)
	ijmp								; Go

scanillegal:
	call	print
	.db	"--Undefined Syntax Element!", 0x0a, 0x0d, 0x00
	sec
	ret

;--------------------------------------------------------------------------
;
;	Debug Output sub-routines
;
;
scandebug:
	sts		pprint+0, r24
	sts		pprint+1, r25
	sts		pprint+2, zl
	call	print
	.db		"--Syntax Element: 0x", 0x82, " at 0x", 0x81, 0x80, 0x0a, 0x0d, 0x00
	ret

scandebugentry:
	call	print
	.db		"--scanentry:", CR, LF, 0, 0
	ret

scandebugentry2:
	call	print
	.db		"--scanentry2:", CR, LF, 0
	ret
	
scandebugresult:
	brcs	scandebugresultcs
	call	print
	.db		"--Action Return Carry CLR", CR, LF, 0
	clc
	ret
scandebugresultcs:
	call	print
	.db		"--Action Return Carry SET", CR, LF, 0
	sec
	ret
	
	
scandebugnext:
	sts		pprint+0, r24
	sts		pprint+1, r25
	call	print
	.db		"--Next Table 0x", 0x81, 0x80, CR, LF, 0
	ret
	
scandebugaction:
	sts		pprint+0, r24
	sts		pprint+1, r25
	mov		temp, zh
	lsr		temp
	sts		pprint+9, temp
	mov		temp, zl
	ror		temp
	sts		pprint+8, temp
	call	print
	.db		"--Calling Action 0x", 0x81, 0x80, " (Z->0x", 0x89, 0x88, ")", CR, LF, 0
	ret
;
;	Shift addresses to the right to show the addresses as they occur in the listing
;
scandebugtable:
	mov		temp, zh
	lsr		temp
	sts		pprint+9, temp
	mov		temp, zl
	ror		temp
	sts		pprint+8, temp

	lpm		temp, Z+
	sts		pprint+0, temp
	lpm		temp, Z+
	sts		pprint+1, temp
	lpm		temp, Z+
	sts		pprint+2, temp
	lpm		temp, Z+
	sts		pprint+3, temp
	lpm		temp, Z+
	sts		pprint+4, temp
	lpm		temp, Z+
	sts		pprint+5, temp
	sbiw	zh:zl, 6
	sts		pprint+6, xl
	sts		pprint+7, xh
	in		temp, SPL
	sts		pprint+10, temp
	in		temp, SPH
	sts		pprint+11, temp
	call	print
	.db		"--TPRASE Table entry at 0x", 0x89, 0x88
	.db		": 0x", 0x81, 0x80
	.db		", 0x", 0x83, 0x82
	.db		", 0x", 0x85, 0x84
	.db		" String Addr 0x", 0x87, 0x86, ", Stack 0x", 0x8b, 0x8a, CR, LF, 0
	ret
	
scantable:
	rjmp	scankeyword
	rjmp	scankeyword
	rjmp	scanstring
	rjmp	scankeyword
	rjmp	scanname
	rjmp	scannumber
	rjmp	scaneol			; 
	rjmp	scanqstring
	rjmp	scansubcmd
	rjmp	scanchar
	rjmp	scanany
	rjmp	scanlambda
	rjmp	scanswitch
	
.equ scantablesize=PC-scantable
;
;
;
scankeyword:
	movw	zh:zl, r25:r24
	sts		scanresult, zero
	sts		scanresult+1, zero
	sts		scanresult+2, zero
	sts		scanresult+3, zero
	push	temp						; Remember options for suffix
scankeywordloo:
	ld		char, X+
	lpm		temp, Z+					; Get both characters
;
;	Case:	(Z) == 0x00
;
	tst		temp
	breq	scankeywordsuf				; Reach end of keyword
	
;
;	Case:	(Z) == Lowercase i.e. optional character in keyword
;
	cpi		temp, 0x60
	brlo	scankeywordupp
	andi	temp, 0x5f
	cpi		char, 0x60
	brlo	scankeyword010
	andi	char, 0x5f					; Translate input to upper case
scankeyword010:
	cp		char, temp
	breq	scankeywordloo				; Matching optional characters
	rjmp	scankeywordsuf				; Check for allowed suffix
;
;	Case:	(Z) == Uppercase i.e. required character in keyword
;
scankeywordupp:
	cpi		char, 0x60
	brlo	scankeyword020
	andi	char, 0x5f					; Translate input to upper case
scankeyword020:
	cp		temp, char
	breq	scankeywordloo				
	pop		temp
	sec									; No match for mandatory part
	ret
;
;	We have reached the end of the required keyword or we have reached
;	the optional part of the keyword and got a non-matching character.
;	Now we need to check for a suffix. If a suffix is allowed we either
;	have just a number (at the moment we accept only one digit) or an
;	empty string. 
;
scankeywordsuf:
	pop		temp						; Get options for suffix
	sbrs	temp, 0   					; 
	rjmp	scankeywordnos				; no suffix at all
	cpi		char, '0'
	brlo	scankeywordcol				; Check for a digit
	cpi		char, '9'+1
	brsh	scankeywordcol
	subi	char, '0'					; Convert digit to number
	sts		scanresult+2, char			; Save result
	ld		char, X+
scankeywordcol:							; Get next character
	sbrs	temp, 1   					; Check for colon
	rjmp	scankeywordnos				; No so we must have a whitespace
	cpi		char, ':'					; Must be colon
	brne	scankeyworderr
	ld		char, X+
scankeywordnos:							; no further suffix so the character
	cpi		char, 0x0d					; must be a white space
	breq	scankeywordsuc
	cpi		char, ' '
	breq	scankeywordsuc
scankeyworderr:
	sec									; word longer than keyword and no suffix allowed
	ret
scankeywordsuc:
	sbiw	X, 1
	clc
	ret
;
;	Scans an arbitrary string, i.e. any non-blank characters
;	the string must not be empty, returns the pointer and
;	the length in scanresult. 
;
scanstring:
	sts		scanresult, xl
	sts		scanresult+1, xh
	sts		scanresult+2, zero
	sts		scanresult+3, zero
	mov		count, ff				; Initialise -1
scanstringnext:
	inc		count					; 
	ld		char, X+
	cpi		char, 0x0d				; end-of-line?
	breq	scanstringeol			; finish
	cpi		char, ' '				; space
	brne	scanstringnext			; no get next
scanstringeol:
	sts		scanresult+2, count		; save length
	tst		count
	breq	scanstringempty
	sbiw	X, 1
;	sts		pprint, xl
;	sts		pprint+1, xh
;	call	print
;	.db		"ptr after string:0x", 0x81, 0x80, 0x0d, 0x0a, 0x00
	clc
	ret
scanstringempty:
	sec
	ret
;
;
;
scanqstring:
	ld		temp, X+
	cpi		temp, 0x0d
	breq	scanqstringerr
	cpi		temp, '"'
	breq	scanqstringq
	cpi		temp, '\''
	breq	scanqstringq
	sec
	ret
scanqstringq:
	sts		scanresult, xl
	sts		scanresult+1, xh
	sts		scanresult+2, zero
	sts		scanresult+3, zero
	mov		count, ff

scanqstringnext:
	inc		count
	ld		char, X+
	cpi		char, 0x0d
	breq	scanqstringerr
	cp		char, temp
	brne	scanqstringnext
	sts		scanresult+2, count
	clc
	ret
scanqstringerr:
	sec
	ret
;
;	Makes sure we are at end of line
;
scaneol:
	sts		scanresult, zero
	sts		scanresult+1, zero
	sts		scanresult+2, zero
	sts		scanresult+3, zero
	ld		char, X
;	sts		pprint+0, char
;	call	print
;	.db		"Scaneol 0x", 0x80, CR, LF, 0
	cpi		char, 0x0d			; Clears carry if equal
	breq	scaneolret
	sec
scaneolret:
	ret

;
;	Scans a valid name. Names are string that start with a A-Z
;	and contain A-Z, 0-9, _, $, @
;
scanname:
	sts		scanresult, xl
	sts		scanresult+1, xh
	sts		scanresult+2, zero
	sts		scanresult+3, zero
	mov		count, one				; Assume we found at least one
	ld		char, X+				; character
	cpi		char, 0x60				; Conver to upper case
	brlo	scanname010
	andi	char, 0x5f
scanname010:
	cpi		char, 'A'				; Initial character A-Z?
	brlo	scannameinv
	cpi		char, 'Z'+1
	brsh	scannameinv		
scannamenext:					
	ld		char, X+				; Convert to upper case
	cpi		char, 0x60
	brlo	scanname020
	andi	char, 0x5f
scanname020:
	cpi		char, '$'				; Special Characters
	breq	scannameok
	cpi		char, '_'
	breq	scannameok
	cpi		char, '@'
	breq	scannameok
	cpi		char, '0'				; 
	brlo	scannamechk
	cpi		char, '9'+1
	brlo	scannameok				; Is between 0-9
scanname030:
	cpi		char, 'A'
	brlo	scannamechk
	cpi		char, 'Z'+1
	brsh	scannamechk
scannameok:							; Is between A-Z
	inc		count					; One more found
	rjmp	scannamenext			; and check next
scannamechk:
	cpi		char, 0x0d				; When no valid character
	breq	scannamesuc				; was found then we either
	cpi		char, ' '				; have to be at end of line
	breq	scannamesuc				; or a space terminates the name
scannameinv:
	sec								; Not the case -> error
	ret
scannamesuc:
	sbiw	X, 1
	sts		scanresult+2, count		; Save length of name
	clc								; Return -> sucess
	ret
;
;
;
scannumber:
	push	r4
	push	r5
	push	r6
	push	r7					; 32-bit integer
	push	count				; Flags
	sts		scanresult, zero
	sts		scanresult+1, zero
	sts		scanresult+2, zero
	sts		scanresult+3, zero

	clr		r4
	clr		r5
	clr		r6
	clr		r7
	clr		count

	ld		char, X+
	rcall	scannumberwhite
	breq	scannumbererr
	cpi		char, '0'
	brne	scannumberdec
	ld		char, X+
	rcall	scannumberwhite
	brne	scannumber010
	rjmp	scannumberok		; Just a 0
scannumber010:
	cpi		char, 0x60			; lower case ?
	brlo	scannumber020		; nope
	andi	char, 0x5F			; Perhaps yes make sure we have upper case only
scannumber020:

	cpi		char, 'X'
	breq	scannumberhex
;	cpi		char, 'B'
;	breq	scannumberbinary
	rjmp	scannumberoct
scannumberhex:
	ld		char, X+
	rcall	scannumberishex
	brcc	scannumberhex010
	rjmp	scannumbererr
scannumberhex010:
	rcall	scannumberaddhex
	ld		char, X+
	rcall	scannumberwhite
	breq	scannumberhex020
	rcall	scannumberishex
	brcc	scannumberhex010
	rjmp	scannumbererr
scannumberhex020:
	rjmp	scannumberok
;
;	Scan a decimal number, with optional decimal point
;
scannumberdec:
	rcall	scannumberisdec
	brcc	scannumberdec010
	rjmp	scannumbererr
scannumberdec010:
	rcall	scannumberadddec
	ld		char, X+
	rcall	scannumberwhite
	brne	scannumberdec020
	rjmp	scannumberok
scannumberdec020:
	cpi		char, '.'
	breq	scannumberdec030
	rcall	scannumberisdec
	brcc	scannumberdec010
	rjmp	scannumbererr
scannumberdec030:
	ld		char, X+
	rcall	scannumberwhite
	breq	scannumberok
	rjmp	scannumbererr
;
;	Scan a octal number
;
scannumberoct:
	rcall	scannumberisoct
	brcc	scannumberoct010
	rjmp	scannumbererr
scannumberoct010:
	rcall	scannumberaddoct
	ld		char, X+
	rcall	scannumberwhite
	breq	scannumberoct020
	rcall	scannumberisoct
	brcc	scannumberoct010
	rjmp	scannumbererr
scannumberoct020:
	rjmp	scannumberok
;
;
;
scannumberok:
	sbiw	X, 1
	sts		scanresult+0, r4
	sts		scanresult+1, r5
	sts		scanresult+2, r6
	sts		scanresult+3, r7
	clc
	rjmp	scannumberok010
;
;
;
scannumbererr:
	sec
scannumberok010:
	pop		count
	pop		r7
	pop		r6
	pop		r5
	pop		r4
	ret
;
;	White space
;
scannumberwhite:
	cpi		char, 0x0d			; <CR>
	breq	scannumberwhite010	; Zero Value
	cpi		char, 0x09			; <HT>
	breq	scannumberwhite010	; Zero Value
	cpi		char, 0x20			; <space>
scannumberwhite010:
	ret
;
;	Hex digit
;
scannumberishex:
	cpi		char, 0x60			; lower case ?
	brlo	scannumberishex010	; nope
	andi	char, 0x5F			; Perhaps yes make sure we have upper case only
scannumberishex010:
	ldi		temp,0x30			; 
	eor		char,temp			; Convert 
	cpi		char,0x0A			; was the character between '0' and '9'
	brlo	scannumberishex020	; yes so we have a digit
	subi	char,-0x89			; Convert so 'A' to 'F' are mapped to 0xFA to 0xFF
	cpi		char,0xFA			; i.e. the lower nibble correponds to the value
	brsh	scannumberishex020	; If higher than we have a digit
	sec
	ret
scannumberishex020:
	push	char
	pop		char
	clc
	ret
;
;	Decimal digit
;
scannumberisdec:	
	ldi		temp,0x30			; 
	eor		char,temp			; Convert 
	cpi		char,0x0A			; was the character between '0' and '9'
	brlo	scannumberisdec020	; yes so we have a digit
	sec
	ret
scannumberisdec020:
	clc
	ret
;
;	Octal digit
;
scannumberisoct:	
	ldi		temp,0x30			; 
	eor		char,temp			; Convert 
	cpi		char,0x08			; was the character between '0' and '9'
	brlo	scannumberisoct020	; yes so we have a digit
	sec
	ret
scannumberisoct020:
	clc
	ret
;
;	Add Octal Digit to number
;
scannumberaddoct:
	swap	char
	rol		char
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	ret
;
;	Add Hex Digit to number
;
scannumberaddhex:
	swap	char
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	rol		char
	rol		r4
	rol		r5
	rol		r6
	rol		r7
	ret
;
;	Add Decimal Digit to number
;
scannumberadddec:
	lsl		r4
	rol		r5
	rol		r6
	rol		r7
	push	r7
	push	r6
	push	r5
	push	r4
	lsl		r4
	rol		r5
	rol		r6
	rol		r7
	lsl		r4
	rol		r5
	rol		r6
	rol		r7
	pop		temp
	add		r4, temp
	pop		temp
	adc		r5, temp
	pop		temp
	adc		r6, temp
	pop		temp
	adc		r7, temp
	add		r4, char
	adc		r5, zero
	adc		r6, zero
	adc		r7, zero
	ret
;
;	Match a specific character
;
scanchar:
	ld		char, X+
	cpi		char, 0x0d
	breq	scancharerr
	tst		char
	breq	scancharerr
	movw	zh:zl, r25:r24
	lpm		temp, Z
	cp		char, temp
	brne	scancharerr
	sts		scanresult+0, xl
	sts		scanresult+1, xh
	sts		scanresult+2, char
	clc
	ret
scancharerr:
	sec
	ret
;
;	Match any non-terminating character
;
scanany:
	ld		char, X+
	cpi		char, 0x0d
	breq	scananyerr
	tst		char
	breq	scananyerr
	sts		scanresult+2, char
	clc
	ret
scananyerr:
	sec
	ret
;
;	Match always
;
scanlambda:
	clc
	ret
;
;	Match switch
;
scanswitch:
	ld		char, X+
	cpi		char, '-'
	brne	scanswitcherr
	ld		char, X+
	movw	zh:zl, r25:r24
	lpm		temp, Z
	cp		char, temp
	brne	scanswitcherr
	sts		scanresult+2, char
	clc
	ret
scanswitcherr:
	sec
	ret	


