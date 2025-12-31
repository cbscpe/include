;--------------------------------------------------------------------------
;
;	2019-01-06	Added CreatePath
;
;	Combine the current working path with a new path/file name to form
;	a fully qualified path. It is assumed that both string are valid and
;	existing paths or files respectively. E.g. have been checked using
;	Name2DirEntry, i.e. both, the working path and the new path/file
;	name must exist.
;	The function will scan the new path/file for the delimiter. If the
;	substring corresponds to ".." then it will remove the top element
;	from the working path. If it is a filename it will be added to the
;	working path. 
;	2019-07-18	Paths preceeded with DELIM are now handled as absolute paths
;			Use pointer and not location Path
;
;	Input:
;		X	Pointer to the new path/file zero terminated string
;		Z	Pointer to the current working path
;
;	Output:
;			Working path updated with 
;
;	Version 2.0
;
;	Combine input path with a new path/file name to form a fully qualified
;	path/file name. It is assumed that both string are valid and existing
;	paths or files respectively, e.g. have been checked using
;	Name2DirEntry, i.e. both, the working path and the new path/file name
;	must exist.
;
;	The function will scan the new path/file for the delimiter. If the
;	substring corresponds to ".." then it will remove the top element from
;	the input path. If it is a filename it will be added to the working
;	path. 
;
;	Input:
;	r25:r24		Pointer to base path
;	r23:r22		Pointer to file including sub-directories to add to the path
;
;	Output:
;	The input path is updated
;	
CreatePath:;(char* path, char* dir)
	push	yl
	push	yh

	movw	zh:zl, r25:r24
	movw	xh:xl, r23:r22
	
	movw	r23:r22, zh:zl		; Save pointer to current path, can't reuse
					; r25:r24 as CopyName destroys r24
	ld	r18, X			; 
	cpi	r18, DELIM		; Absolute Path?
	brne	CreatePath010		; 
	st	Z, zero			; then ignore current path 
	adiw	X, 1			; skip over leading DELIM of absolute path
	ld	r18, X			; 
	tst	r18			; Check for root
	brne	CreatePath010		; 
	rjmp	CreatePathExit		; It's the root, so we are done

CreatePath010:
;
;
;
	rcall	CopyName
	brtc	CreatePathExit		; No more
;
;	check if the element just copied is '..' 
;
	lds	r18, NameBuffer+0
	cpi	r18, '.'
	brne	CreatePath040
	lds	r18, NameBuffer+1
	cpi	r18, '.'
	brne	CreatePath040
	lds	r18, NameBuffer+2
	tst	r18
	brne	CreatePath040
;
;	Move to parent directory check if we are not at the root level.
;	If we are not at the root level and must remove the top directory
;
;	To remove the top directory we scan the current path until we reach
;	the terminating 0. When scanning the path we look for a DELIM and 
;	remember the last occurance
;
	movw	zh:zl, r23:r22
	movw	yh:yl, r23:r22		; Initialise empty path
CreatePath020:	
	ld	r18, Z+			; Scan Path
	tst	r18
	breq	CreatePath030		; Reached end of path
	cpi	r18, DELIM		; delimiter?
	brne	CreatePath020
	movw	Y, Z			; Remember delimiter
	sbiw	Y, 1
	rjmp	CreatePath020
;
;	Y points either to the last delimiter or to the empty Path
;
CreatePath030:
	st	Y, zero			; Terminate path
	cpi	r24, DELIM		; Another Path Element
	brne	CreatePathExit		; no so we are done
	rjmp	CreatePath010
;
;	need to add NameBuffer to Path
;
CreatePath040:
	movw	zh:zl, r23:r22
	ld	r18, Z
	tst	r18
	breq	CreatePath055		; Empty Path just add NameBuffer

CreatePath050:
	ld	r18, Z+
	tst	r18
	brne	CreatePath050
	ldi	r18, DELIM
	st	-Z, r18			; New delimiter
	adiw	Z, 1			; readjust
CreatePath055:
	ldi	yl, low(NameBuffer)
	ldi	yh, high(NameBuffer)
CreatePath060:
	ld	r18, Y+
	st	Z+, r18
	tst	r18
	brne	CreatePath060		; Copy until the end of the element
	cpi	r24, DELIM		; Another command element?
	breq	CreatePath010		; Yes process it
;
CreatePathExit:
	pop	yh
	pop	yl
	ret


