;--------------------------------------------------------------------------
;
;	Match filename
;		Y		Pointer to datastructure setup to read a directory
;				entry (e.g. after calling ReadDir)
;		NameBuffer	null terminate filename
;
;	Completioncode:
;		CC		entry matches filename
;		CS		entry does not match
;
;	Registers:
;		r18
;
;
;	Alternate entry:
;
;	This entry will copy back the found real filename to the buffer which
;	pointer is stored at P_DirName of the datastructure. The name is not
;	zero terminated, so in case you need a zero terminated string you must
;	clear the buffer in advance. This feature is normally used by the 
;	Name2DirEntry function to update inline the given path with the real
;	filenames. This is because filenames are case insensitive but sometimes
;	we want to give feedback to the user with the as it is stored in the
;	directory with the correct case. One example is the "pwd" print working
;	directory command.
;
;	Version 2.0
;
;	r25:r24	Volume Control Block
;	Uses global Buffer LongFileN
;	Completion Code in r24
;	no alternative entry, always updates the input with the real name on disk
;
;
MatchFileName:;uint8_t (struct* VolumeControlBlock);
	push	yl
	push	yh
	movw	yh:yl, r25:r24
;
	ldi	xl, low(NameBuffer)
	ldi	xh, high(NameBuffer)	; Get pointer to the name to match
	ldd	r18, Y+Vol_Status
	sbrs	r18, Vol__Long
	rjmp	MatchSFN		; Match Short File Name
	
	ldi	zl, low(LongFileN)
	ldi	zh, high(LongFileN)	; Get pointer to long file name

MatchFilelLoop:
	ld	r18, X+			; Get character from name buffer
	ld	r19, Z+			; Get character from long file name
	ucase	r18
	ucase	r19			; Convert to upper case
	cp	r18, r19		; Compare the two characters
	brne	MatchFileFNF		; ->file not found
	tst	r18			; did we reach the end of the name
	brne	MatchFilelLoop		; no, do next character
	clr	r24			; SUCCESS
	ldi	zl, low(LongFileN)
	ldi	zh, high(LongFileN)
	ldd	xl, Y+Vol_UpdatePtr+0
	ldd	xh, Y+Vol_UpdatePtr+1
MatchFileUpdateL:
	ld	r18, Z+
	cpi	r18, 0			; if .eq. clears carry
	breq	MatchFileFin
	st	X+, r18
	rjmp	MatchFileUpdateL

MatchFileFNF:				; Match File-not-found
	ldi	r24, FAT_FNF
MatchFileFin:
	pop	yh
	pop	yl
	ret
;
;	Match short filename 
;
MatchSFN:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	ldi	r24, FAT_FNF		; Asssume File not found
	ldi	r17, 8			; 8 character name
MatchSFNName:
	ld	r18, X+			; Get next input filename character
	ldd	r16, Z+D_Name		; Get next directory filename character
	adiw	Z, 1			; Adjust pointer
	cpi	r16, 0x20		; blank
	breq	MatchSFNDot		; Then next might be a dot
	ucase	r18			; Convert input character
	cp	r16, r18		; EQ?
	brne	MatchSFNFin		; file not found
	dec	r17			; Next name character
	brne	MatchSFNName		;
	ld	r18, X+
MatchSFNDot:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
;	
;	The Name part matches the input filename. Now we have various
;	possibilities
;
;	First byte of extension is a space and we have reached end of file -> match
;	First byte of extension is not a space and we have a .	-> possible match
;
	ldd	r16, Z+D_Ext		;
	cpi	r16, 0x20		; no extension?
	breq	MatchSFNNull		; then we must have reached end of input file
	cpi	r18, '.'		; we have an extension so we need a dot
	brne	MatchSFNFin		; no match
	ldi	r17, 3			; Compare extension
MatchSFNExt:
	ld	r18, X+
	ldd	r16, Z+D_Ext
	adiw	Z, 1
	cpi	r16, 0x20		; blank
	breq	MatchSFNNull		; Then must be end of input filename
	ucase	r18
	cp	r16, r18
	brne	MatchSFNFin	
	dec	r17
	brne	MatchSFNExt
	ld	r18, X+
MatchSFNNull:
	tst	r18
	brne	MatchSFNFin
MatchSFNFound:
	clr	r24			; SUCCESS
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	ldd	xl, Y+Vol_UpdatePtr+0
	ldd	xh, Y+Vol_UpdatePtr+1

	ldi	r17, 8
MatchSFNFound010:
	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFound020
	st	X+, r16
	dec	r17
	brne	MatchSFNFound010

MatchSFNFound020:
	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFin
	ldi	r18, '.'
	st	X+, r18
	st	X+, r16

	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFin
	st	X+, r16

	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFin
	st	X+, r16
MatchSFNFin:
	pop	yh
	pop	yl
	ret

