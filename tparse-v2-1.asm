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
;	When calling the parser Z must point to the start table (caution it must
;	be a byte pointer for lpm, typically twice the address) and X must point
;	to the string to be parsed. If the sring could be parsed successfully
;	carry will be cleared on return. Else carry will be set. X will point
;	to the position up to which the parser has analyzed the string (not
;	necessarily the end of the string)
;
;
;	1.2	11-10-2020	- Add Switch as syntax element
;				- Add Flag to select white space as a syntax element
;	2.0	04-12-2021	- Start using ABI
;		24-12-2021	- Adjust/Describe calling convention of action routines
;	2.1	04-06-2022	- New end-of-table with error message
;				- Remove debugging code
;
;--------------------------------------------------------------------------
;
;	Input:
;		r25:r24	Pointer to parser table
;		r23:r22	Pointer to string
;
scancmd:
	movw	Z, r25:r24
	movw	X, r23:r22
	rjmp	scancommand
;--------------------------------------------------------------------------
;
;	Re-entering scancommand with subcommand
;
;	Input:
;		Z		Pointer to parser table in flash
;		X		Pointer to string
;
scansubcmd:
	adiw	r25:r24, 1	; Skip filler byte
	movw	zh:zl, r25:r24	; Pointer to element in table
	lpm	r24, Z+		; Linked entry
	lpm	r25, Z+
	add	r24, r24	; Make byte address
	adc	r25, r25
	movw	zh:zl, r25:r24	; Sub Table
;--------------------------------------------------------------------------
;
;	Process Command Table Entry
;
;	Input:
;		Z	Pointer to parser table
;		X	Pointer to string
;
;	Output:
;		X	Points after the last byte successfully parsed
;
;	Conditions:
;		CS	syntax error
;		CC	parsing string sucessfully
;
;	Registers:
;
;		r22, r23, r24, r25
;
scancommand:
	lpm	r24, Z+
	lpm	r25, Z+			; Get address of syntax element Z->Action
	sbiw	r25:r24, 1
	breq	scancommanderror	; End of Table with error message
	adiw	r25:r24, 1
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
;
;	Whenever we have an action routine then call it
;	X Points past the matched element, you must not 
;	change X unless you know what you do.
;	The action routine must clear the carry bit to
;	accept the syntax element or set the carry to 
;	reject the syntax element. 
;
;	Action routines may change registers r16-25, zl and zh
;	all other registers must be preserved
;
	movw	zh:zl, r25:r24
	push	xl
	push	xh
	icall	
	pop	xh
	pop	xl
	brcs	scannextentry2		; Action rejected the entry
;
scannoaction:
	pop	zh
	pop	zl			; Restore pointer Z->Next
	pop	r25
	pop	r24			; Discard saved buffer pointer
	lpm	r24, Z+
	lpm	r25, Z+			; Next Table
	sbiw	r25:r24, 0
	breq	scancommand		; Just next entry
	movw	zh:zl, r25:r24
	adiw	r25:r24, -cmd_done
	breq	scancommanddone
	add	zl, zl
	adc	zh, zh
	rjmp	scancommand
;
scannextentry:
	pop	zh
	pop	zl			; Restore Pointer Z->Action
	pop	xh
	pop	xl			; Previous command buffer pointer
	adiw	zh:zl, 4		; Skip action and next table address
	rjmp	scancommand
;
scannextentry2:
	pop	zh
	pop	zl			; Restore pointer Z->Next
	pop	xh
	pop	xl			; Previou buffer pointer
	adiw	zh:zl, 2		; Skip next table address
	rjmp	scancommand
;
scancommanderror:
	lpm	r24, Z+
	lpm	r25, Z+
	sec
	ret
;
scancommandfailed:
	push	zl
	push	zh
	lsr	zh
	ror	zl
	sts	pprint+0, zl
	sts	pprint+1, zh
	pop	zh
	pop	zl
	call	print
	.db	CR, LF, "--Unidentified Command at 0x", 0x81, 0x80, 0, 0
	sec
	ret

scancommanddone:
	movw	r25:r24, xh:xl		;
	clc
	ret
;
;	Skip blanks
;
scanskipnext:
	adiw	X, 1
scanskipblank:
	ld	r23, X
	cpi	r23, ' '
	breq	scanskipnext
	ret
;
;	scanelement
;
;	X	pointer to inputbuffer
;	Z	pointer to element descriptione
;
scanelement:
	lpm	r22, Z+
	movw	r25:r24, zh:zl
	mov	zl, r22
	andi	zl, 0x7f		; Remove marker bit
	cpi	zl, scantablesize	; Check against table size
	brsh	scanillegal
	clr	zh			; Make pointer to jump table
	subi	zl, low(-scantable)
	sbci	zh, high(-scantable)
	ijmp				; Go

scanillegal:
	push	zl
	push	zh
	lsr	zh
	ror	zl
	sts	pprint+0, zl
	sts	pprint+1, zh
	sts	pprint+2, r22
	pop	zh
	pop	zl
	call	print
	.db	CR, LF, "--Undefined Syntax Element 0x", 0x82, " at 0x", 0x81, 0x80, 0, 0
	sec
	ret
;--------------------------------------------------------------------------
;
;	Action Jump Table
;
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
	push	r22			; Remember options for suffix
	movw	zh:zl, r25:r24
	lsr	zh
	ror	zl
	sts	pprint+0, zl
	sts	pprint+1, zh
	sts	pprint+2, r22		; Options
	movw	zh:zl, r25:r24
	sts	scanresult+0, zero
	sts	scanresult+1, zero
	sts	scanresult+2, zero
	sts	scanresult+3, zero
scankeywordloo:
	ld	r23, X+
	lpm	r22, Z+			; Get both characters
;
;	Case:	(Z) == 0x00
;
	tst	r22
	breq	scankeywordsuf		; Reach end of keyword
;
;	Case:	(Z) == Lowercase i.e. optional character in keyword
;
	cpi	r22, 0x60
	brlo	scankeywordupp
	andi	r22, 0x5f
	cpi	r23, 0x60
	brlo	scankeyword010
	andi	r23, 0x5f		; Translate input to upper case
scankeyword010:
	cp	r23, r22
	breq	scankeywordloo		; Matching optional characters
	rjmp	scankeywordsuf		; Check for allowed suffix
;
;	Case:	(Z) == Uppercase i.e. required character in keyword
;
scankeywordupp:
	cpi	r23, 0x60
	brlo	scankeyword020
	andi	r23, 0x5f		; Translate input to upper case
scankeyword020:
	cp	r22, r23
	breq	scankeywordloo				
	pop	r22
	sec				; No match for mandatory part
	ret
;
;	We have reached the end of the required keyword or we have reached
;	the optional part of the keyword and got a non-matching character.
;	Now we need to check for a suffix. If a suffix is allowed we either
;	have just a number (at the moment we accept only one digit) or an
;	empty string. 
;
scankeywordsuf:
	pop	r22			; Get options for suffix
	sbrs	r22, 0   					; 
	rjmp	scankeywordnos		; no suffix at all
	cpi	r23, '0'
	brlo	scankeywordcol		; Check for a digit
	cpi	r23, '9'+1
	brsh	scankeywordcol
	subi	r23, '0'		; Convert digit to number
	sts	scanresult+2, r23	; Save result
	ld	r23, X+
scankeywordcol:				; Get next character
	sbrs	r22, 1   		; Check for colon
	rjmp	scankeywordnos		; No so we must have a whitespace
	cpi	r23, ':'		; Must be colon
	brne	scankeyworderr
	ld	r23, X+
scankeywordnos:				; no further suffix so the character
	cpi	r23, CR			; must be a white space
	breq	scankeywordsuc
	cpi	r23, NULL
	breq	scankeywordsuc
	cpi	r23, SPACE
	breq	scankeywordsuc
scankeyworderr:
	sec				; word longer than keyword and no suffix allowed
	ret
scankeywordsuc:
	sbiw	X, 1
	clc
	ret
	
scandebugkeyword:
	call	print
	.db	CR, LF, "Keyword at 0x", 0x81, 0x80, " options 0x", 0x82, 0
	ret
scandebugkeyword2:
	sts	pprint+0, r23		; Input
	sts	pprint+1, r22		; Key
	call	print
	.db	CR, LF, "Keyword if 0x", 0x80, " matches 0x", 0x81, 0, 0
	ret
;
;	Scans an arbitrary string, i.e. any non-blank characters
;	the string must not be empty, returns the pointer and
;	the length in scanresult. 
;
scanstring:
	sts	scanresult+0, xl
	sts	scanresult+1, xh
	sts	scanresult+2, zero
	sts	scanresult+3, zero
	ldi	r22, -1			; Initialise -1
scanstringnext:
	inc	r22			; 
	ld	r23, X+
	cpi	r23, CR			; end-of-line?
	breq	scanstringeol		; finish
	cpi	r23, NULL		; end-of-line?
	breq	scanstringeol		; finish
	cpi	r23, ' '		; space
	brne	scanstringnext		; no get next
scanstringeol:
	sts	scanresult+2, r22	; save length
	tst	r22
	breq	scanstringempty
	sbiw	X, 1
	clc
	ret
scanstringempty:
	sec
	ret
;
;	Quoted string, quotes supported are ' and "
;
scanqstring:
;	ldi	r24, CR
;	call	serout_4
;	ldi	r24, LF
;	call	serout_4
;	ldi	r24, 'q'
;	call	serout_4
	ld	r22, X+
	cpi	r22, NULL
	breq	scanqstringerr
	cpi	r22, CR
	breq	scanqstringerr
	cpi	r22, '"'
	breq	scanqstringq
	cpi	r22, '\''
	breq	scanqstringq
	sec
	ret
scanqstringerr:
;	ldi	r24, 'e'
;	call	serout_4
	sec
	ret
scanqstringq:
;	mov	r24, r22
;	call	serout_4
	sts	scanresult+0, xl
	sts	scanresult+1, xh
	ldi	r23, 0xff
	sts	scanresult+2, r23
	sts	scanresult+3, zero
scanqstringnext:
	lds	r23, scanresult+2
	inc	r23
	sts	scanresult+2, r23
	ld	r23, X+
	cpi	r23, NULL
	breq	scanqstringerr
	cpi	r23, CR
	breq	scanqstringerr
	cp	r23, r22
	breq	scanqstringexit
;	mov	r24, r23
;	call	serout_4
	rjmp	scanqstringnext
scanqstringexit:
;	mov	r24, r23
;	call	serout_4
;	ldi	r24, 'q'
;	call	serout_4
	clc
	ret
;
;	Makes sure we are at end of line
;
scaneol:
	sts	scanresult+0, zero
	sts	scanresult+1, zero
	sts	scanresult+2, zero
	sts	scanresult+3, zero
	ld	r23, X
	cpi	r23, CR			; Clears carry if equal
	breq	scaneolret
	cpi	r23, NULL		; Clears carry if equal
	breq	scaneolret
	sec
scaneolret:
	ret
;
;	Scans a valid name. Names are string that start with a A-Z
;	and contain A-Z, 0-9, _, $, @
;
scanname:
	sts	scanresult, xl
	sts	scanresult+1, xh
	sts	scanresult+2, zero
	sts	scanresult+3, zero
	ldi	r22, 1			; Assume we found at least one
	ld	r23, X+			; character
	cpi	r23, 0x60		; Conver to upper case
	brlo	scanname010
	andi	r23, 0x5f
scanname010:
	cpi	r23, 'A'		; Initial character A-Z?
	brlo	scannameinv
	cpi	r23, 'Z'+1
	brsh	scannameinv
scannamenext:					
	ld	r23, X+			; Convert to upper case
	cpi	r23, 0x60
	brlo	scanname020
	andi	r23, 0x5f
scanname020:
	cpi	r23, '$'		; Special Characters
	breq	scannameok
	cpi	r23, '_'
	breq	scannameok
	cpi	r23, '@'
	breq	scannameok
	cpi	r23, '0'		; 
	brlo	scannamechk
	cpi	r23, '9'+1
	brlo	scannameok		; Is between 0-9
scanname030:
	cpi	r23, 'A'
	brlo	scannamechk
	cpi	r23, 'Z'+1
	brsh	scannamechk
scannameok:				; Is between A-Z
	inc	r22			; One more found
	rjmp	scannamenext		; and check next
scannamechk:
	cpi	r23, NULL		; When no valid character
	breq	scannamesuc		; was found then we either
	cpi	r23, CR			; When no valid character
	breq	scannamesuc		; was found then we either
	cpi	r23, ' '		; have to be at end of line
	breq	scannamesuc		; or a space terminates the name
scannameinv:
	sec				; Not the case -> error
	ret
scannamesuc:
	sbiw	X, 1
	sts	scanresult+2, r22	; Save length of name
	clc				; Return -> sucess
	ret
;
;
;
scannumber:
	push	r4
	push	r5
	push	r6
	push	r7			; 32-bit integer
;	push	count			; Flags
	sts	scanresult+0, zero
	sts	scanresult+1, zero
	sts	scanresult+2, zero
	sts	scanresult+3, zero
	clr	r4
	clr	r5
	clr	r6
	clr	r7
;	clr	count
	ld	r23, X+
	rcall	scannumberwhite
	breq	scannumbererr
	cpi	r23, '0'
	brne	scannumberdec
	ld	r23, X+
	rcall	scannumberwhite
	brne	scannumber010
	rjmp	scannumberok		; Just a 0
scannumber010:
	cpi	r23, 0x60		; lower case ?
	brlo	scannumber020		; nope
	andi	r23, 0x5F		; Perhaps yes make sure we have upper case only
scannumber020:

	cpi	r23, 'X'
	breq	scannumberhex
;	cpi	r23, 'B'
;	breq	scannumberbinary
	rjmp	scannumberoct
scannumberhex:
	ld	r23, X+
	rcall	scannumberishex
	brcc	scannumberhex010
	rjmp	scannumbererr
scannumberhex010:
	rcall	scannumberaddhex
	ld	r23, X+
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
	ld	r23, X+
	rcall	scannumberwhite
	brne	scannumberdec020
	rjmp	scannumberok
scannumberdec020:
	cpi	r23, '.'
	breq	scannumberdec030
	rcall	scannumberisdec
	brcc	scannumberdec010
	rjmp	scannumbererr
scannumberdec030:
	ld	r23, X+
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
	ld	r23, X+
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
	sts	scanresult+0, r4
	sts	scanresult+1, r5
	sts	scanresult+2, r6
	sts	scanresult+3, r7
	clc
	rjmp	scannumberok010
;
;
;
scannumbererr:
	sec
scannumberok010:
;	pop	count
	pop	r7
	pop	r6
	pop	r5
	pop	r4
	ret
;
;	White space
;
scannumberwhite:
	cpi	r23, NULL		; <CR>
	breq	scannumberwhite010	; Zero Value
	cpi	r23, CR			; <CR>
	breq	scannumberwhite010	; Zero Value
	cpi	r23, TAB		; <HT>
	breq	scannumberwhite010	; Zero Value
	cpi	r23, SPACE		; <space>
scannumberwhite010:
	ret
;
;	Hex digit
;
scannumberishex:
	cpi	r23, 0x60		; lower case ?
	brlo	scannumberishex010	; nope
	andi	r23, 0x5F		; Perhaps yes make sure we have upper case only
scannumberishex010:
	ldi	r22,0x30		; 
	eor	r23,r22			; Convert 
	cpi	r23,0x0A		; was the character between '0' and '9'
	brlo	scannumberishex020	; yes so we have a digit
	subi	r23,-0x89		; Convert so 'A' to 'F' are mapped to 0xFA to 0xFF
	cpi	r23,0xFA		; i.e. the lower nibble correponds to the value
	brsh	scannumberishex020	; If higher than we have a digit
	sec
	ret
scannumberishex020:
	push	r23
	pop	r23
	clc
	ret
;
;	Decimal digit
;
scannumberisdec:	
	ldi	r22,0x30		; 
	eor	r23,r22			; Convert 
	cpi	r23,0x0A		; was the character between '0' and '9'
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
	ldi	r22,0x30		; 
	eor	r23,r22			; Convert 
	cpi	r23,0x08		; was the character between '0' and '9'
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
	swap	r23
	rol	r23
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	ret
;
;	Add Hex Digit to number
;
scannumberaddhex:
	swap	r23
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	rol	r23
	rol	r4
	rol	r5
	rol	r6
	rol	r7
	ret
;
;	Add Decimal Digit to number
;
scannumberadddec:
	lsl	r4
	rol	r5
	rol	r6
	rol	r7
	push	r7
	push	r6
	push	r5
	push	r4
	lsl	r4
	rol	r5
	rol	r6
	rol	r7
	lsl	r4
	rol	r5
	rol	r6
	rol	r7
	pop	r22
	add	r4, r22
	pop	r22
	adc	r5, r22
	pop	r22
	adc	r6, r22
	pop	r22
	adc	r7, r22
	add	r4, r23
	adc	r5, zero
	adc	r6, zero
	adc	r7, zero
	ret
;
;	Match a specific character
;
scanchar:
	ld	r23, X+
	cpi	r23, NULL
	breq	scancharerr
	cpi	r23, CR
	breq	scancharerr
	tst	r23
	breq	scancharerr
	movw	zh:zl, r25:r24
	lpm	r22, Z
	cp	r23, r22
	brne	scancharerr
	sts	scanresult+0, xl
	sts	scanresult+1, xh
	sts	scanresult+2, r23
	clc
	ret
scancharerr:
	sec
	ret
;
;	Match any non-terminating character
;
scanany:
	ld	r23, X+
	cpi	r23, NULL
	breq	scananyerr
	cpi	r23, CR
	breq	scananyerr
	tst	r23
	breq	scananyerr
	sts	scanresult+2, r23
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
	ld	r23, X+
	cpi	r23, '-'
	brne	scanswitcherr
	ld	r23, X+
	movw	zh:zl, r25:r24
	lpm	r22, Z
	cp	r23, r22
	brne	scanswitcherr
	sts	scanresult+2, r23
	clc
	ret
scanswitcherr:
	sec
	ret
	