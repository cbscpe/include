;
;	Edit Command Line
;
;	r25:r24	Commandline 
;	r22	Prompt
;
;	r23	destroyed
;
#define	cmdok	0			; Editing ended with ENTER or CR
#define cmdup	1			; Editing ended with cursor up (previous)
#define cmddown	2			; Editing ended with cursor down (next)
;
;	r5:r4
;	 |
;	 v
;	| | | | | | | | | | | | | | |*		* = CR or NULL
;	+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;	           ^                 ^
;	           |                 |
;	           Y                 Z
;
;	First start a new line and show a prompt
;
;	int readcmdline(char* clibuffer, char prompt)
;
readcmdline:
;	push	zh
;	push	zl
	push	yh
	push	yl
;	push	xh
;	push	xl
	push	r5
	push	r4
	movw	r5:r4, r25:r24
	ldi	r24, CR			; 
	call	serout
	ldi	r24, LF
	call	serout
	mov	r24, r22
	call	serout			; Display Prompt
;
;	Print command line
;
	
;	sts	rcl+0, r4		;- debugging
;	sts	rcl+1, r5		;- debugging
;
;	First show the commandline so we not only can read
;	a new command line but also edit an existing one
;
	movw	Y, r4
readcmdline010:
	ld	r24, Y			; Get Next Character
	cpi	r24, CR			; End of Line
	breq	readcmdline015		; Monitor Format
	cpi	r24, 0
	breq	readcmdline015		; C-String Format
	adiw	Y, 1
	call	serout			; Print character
	rjmp	readcmdline010

readcmdline015:
	mov	r23, r24		; Remember end-of-line character
	movw	Z,Y			; Z is end-of-line pointer

readcmdline020:	
;	sts	rcl+2, xl		;- debugging
;	sts	rcl+3, xh		;- debugging
;	sts	rcl+4, yl		;- debugging
;	sts	rcl+5, yh		;- debugging
;	sts	rcl+6, zl		;- debugging
;	sts	rcl+7, zh		;- debugging
	call	serin			; Get Character
	cpi	r24, BKSP
	breq	readcmdlinebksp
	cpi	r24, TAB
	breq	readcmdlinetab
	cpi	r24, DEL
	breq	readcmdlinedel
	cpi	r24, CR
	breq	readcmdlinecr
	cpi	r24, LF
	breq	readcmdlinelf
	cpi	r24, ESC
	breq	readcmdlineesc
	cpi	r24, EOF
	breq	readcmdlineeof
	cpi	r24, 0x01		; CTRL-A	begin-of-line
	breq	readcmdlinectrla
	cpi	r24, 0x05		; CTRL-E	end-of-line
	breq	readcmdlinectrle
	cpi	r24, 0x12		; CTRL-R	redraw
	breq	readcmdlinectrlr
;
;	A normal Character
;
	cp	yl, zl
	cpc	yh, zh
	brlo	readcmdline110			; Insert Character
	call	serout				; Append Character
	st	Y+, r24
	adiw	Z, 1
	rjmp	readcmdline020
;
;	Insert the character at the insert point
;
readcmdline110:
	movw	X, Y				; Copy Insert Point
readcmdline115:
	call	serout				; Echo Character
	ld	r16, X				; Get Character in buffer at insert
	st	X+, r24				; Save new character at insert point
	mov	r24, r16
	cp	xl, zl
	cpc	xh, zh
	brlo	readcmdline115
	st	X, r24
	call	serout
	ldi	r24, BKSP
readcmdline120:
	call	serout
	sbiw	X, 1
	cp	xl, yl
	cpc	xh, yh
	brne	readcmdline120
	adiw	Z, 1				; 
	adiw	Y, 1
	rjmp	readcmdline020
	
readcmdlinebksp:
	rjmp	readcmdbksp			; Backspace
readcmdlinetab:
	rjmp	readcmdline020			; Ignore TAB
readcmdlinedel:
	rjmp	readcmdbksp			; DEL is like Backspace
readcmdlinecr:
	rjmp	readcmdenter			; CR
readcmdlinelf:
	rjmp	readcmdline020			; Ignore Linefeed
readcmdlineesc:
	rjmp	readcmdesc			; ESC Sequence
readcmdlineeof:
	rjmp	readcmdline020
readcmdlinectrla:				; Beginning of line
	ldi	r24, BKSP
readcmdlinectrla010:	
	cp	r4, yl
	cpc	r5, yh
	brsh	readcmdlinectrla020
	call	serout
	sbiw	Y, 1
	rjmp	readcmdlinectrla010
	
readcmdlinectrla020:	
	rjmp	readcmdline020

readcmdlinectrle:				; End of line
	ld	r24, Y
	cp	yl, zl
	cpc	yh, zh
	brsh	readcmdlinectrle020
	call	serout
	adiw	Y, 1
	rjmp	readcmdlinectrle
	
readcmdlinectrle020:	
	rjmp	readcmdline020

readcmdlinectrlr:				; Redraw
	ldi	r24, CR
	call	serout
	ldi	r24, LF
	call	serout
	mov	r24, r22			; Display promt
	call	serout
	movw	X, r4				; Copy Pointer
readcmdlinectrlr010:
	ld	r24, X+				; Print line
	cp	zl, xl
	cpc	zh, xh				; up to end of line pointer
	brlo	readcmdlinectrlr020
	call	serout
	rjmp	readcmdlinectrlr010
readcmdlinectrlr020:
	sbiw	X, 1				; adjust copy pointer
readcmdlinectrlr030:
	ldi	r24, BKSP			; eventually we need to 
	cp	yl, xl
	cpc	yh, xh				; set the cursor
	brsh	readcmdlinectrlr040		; SH -> cursor is now at the correct pos.
	call	serout
	sbiw	X, 1				; one position back
	rjmp	readcmdlinectrlr030
readcmdlinectrlr040:
	rjmp	readcmdline020			; done
;
;
;
readcmdbksp:
	cp	r4, yl		
	cpc	r5, yh
	brne	readcmdbksp010			; If insert point is beginning of line
	rjmp	readcmdline020			; then we have nothing to do
readcmdbksp010:
	ldi	r24, BKSP			; Send a backspace character to set
	call	serout				; position on screen one char left 
	movw	X, Y				; Copy insert point
	ldi	r16, 1			; one backspace to compensate last blank 
readcmdbksp020:
	cp	xl, zl				; 
	cpc	xh, zh
	breq	readcmdbksp025			; Insert point is and end of line
	ld	r24, X				; get character
	st	-X, r24				; shift to the left
	adiw	X, 2				; increment copy pointer
	call	serout				; echo it on screen overwriting existing
	inc	r16				; One backspace
	rjmp	readcmdbksp020
readcmdbksp025:
	ldi	r24, ' '			; overwrite last characters
	call	serout
	ldi	r24, BKSP
readcmdbksp030:
	call	serout
	dec	r16
	brne	readcmdbksp030
	sbiw	Z, 1
	sbiw	Y, 1
	rjmp	readcmdline020
;
;	Escape Sequences supported VT-52/100 cursor and <ENTER> key
;
;	<esc>A
;	<esc>B
;	<esc>C
;	<esc>D
;	<esc>M
;	<esc>OA
;	<esc>OB
;	<esc>OC
;	<esc>OD
;	<esc>OM
;
;
readcmdesc:
	call	serin
	cpi	r24, 'O'			; The O after escape is only used
	breq	readcmdesc010			; by the VT-100 in keypad mode
	cpi	r24, '['			; ANSI
	rjmp	readcmdline020
	
readcmdesc010:
	call	serin
	cpi	r24, 'A'
	breq	readcmdescup
	cpi	r24, 'B'
	breq	readcmdescdown
	cpi	r24, 'C'
	breq	readcmdescright
	cpi	r24, 'D'
	breq	readcmdescleft
	cpi	r24, 'M'
	breq	readcmdescenter
	rjmp	readcmdline020


readcmdescup:
	st	Z, r23				; Mark End-of-Line
	ldi	r24, cmdup
	sec
	rjmp	readcmdexit
readcmdescdown:
	st	Z, r23				; Mark End-of-Line
	ldi	r24, cmddown
	sec
	rjmp	readcmdexit
readcmdescright:
	cp	yl, zl
	cpc	yh, zh
	breq	readcmdescright010
	ld	r24, Y+
	call	serout
readcmdescright010:
	rjmp	readcmdline020
	
readcmdescleft:
	cp	r4, yl
	cpc	r5, yh
	breq	readcmdescleft010
	sbiw	Y, 1
	ldi	r24, BKSP
	call	serout
readcmdescleft010:
	rjmp	readcmdline020

readcmdenter:
readcmdescenter:
	st	Z, r23				; Mark End-of-Line
	ldi	r24, cmdok
	clc
readcmdexit:
	pop	r4
	pop	r5
;	pop	xl
;	pop	xh
	pop	yl
	pop	yh
;	pop	zl
;	pop	zh
	ret	
