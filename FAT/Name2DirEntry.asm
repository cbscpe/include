;--------------------------------------------------------------------------
;
;	Name2DirEntry
;
;	This function takes a pointer to a path name. It walks through the 
;	path and checks if the name exists in the current directory. For this
;	the path is split into individual file names by scanning the path for
;	a delimiter (DELIM).
;	-	If the name is not found it will return a file not found error. 
;	-	If the name found is a normal filename and the name is not the
;		last name in the path it will return a not a directory error
;	-	If the name found is a directory and is not the last name it will 
;		take the next name and search for it in the new directory
;	-	If the end of the path has been reached it will return success, in
;		this case P_Cluster in the Vol_diriob parameter block will be set
;		to the start cluster of the last file found and Vol_DirPointer will
;		be set to the directory entry in the buffer used for directory IO.
;		Note that when the root directory has been requested P_Cluster and
;		Vol_DirPointer will be set to zero
;
;	The search will start with the current directory. The current directory
;	is defined as the start cluster of the directory stored in Vol_DirCluster.
;	To do this it will first copy Vol_DirClsuter to P_Cluster in the Vol_diriob 
;	Parameter block. However if the path is an absolute path the search will
;	start using the root directory
;
;	-	Vol_UpdatePtr	Pointer to the current name
;	-	Vol_DirPointer	Pointer to the directory entry
;
;
;	Input:
;		r25:r24	Pointer to Volume Control Block
;		r23:r22	Pointer to Path
;
Name2DirEntry:; uint8_t Name2DirEntry(struct* VolumeControlBlock, char* name)
	push	r6
	push	r7			; Intermediate storage for CopyName pointer
	push	yl
	push	yh
	
	movw	r7:r6, r23:r22
	movw	yh:yl, r25:r24
;
;	Prepare the starting point
;
	ldd	r16, Y+Vol_DirCluster+0	; Assume relative path 
	ldd	r17, Y+Vol_DirCluster+1
	ldd	r18, Y+Vol_DirCluster+2
	ldd	r19, Y+Vol_DirCluster+3

	movw	xh:xl, r7:r6		; Get Name Pointer
	ld	r24, X			; Check for absolute path
	cpi	r24, DELIM		
	brne	Name2DirRel		; it is a realtive path
	adiw	xh:xl, 1		; Adjust pointer to rest of the name
	movw	r7:r6, xh:xl		; Save Pointer
	clr	r16			; so we need to start at the root directory
	clr	r17
	clr	r18
	clr	r19
	ld	r24, X
	cpi	r24, NULL
	brne	Name2DirRel
	std	Y+Vol_DirPointer+0, zero
	std	Y+Vol_DirPointer+1, zero
	
Name2DirRel:

	ldd	zl, Y+Vol_diriob+0	; io parameter block for directory IO
	ldd	zh, Y+Vol_diriob+1
	std	Z+P_Cluster+0, r16	; start cluster for name lookup
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19

Name2DirEntry000:
	movw	xh:xl, r7:r6		; Get Name Pointer
	std	Y+Vol_UpdatePtr+0, xl	; Save current position as update pointer for
	std	Y+Vol_UpdatePtr+1, xh	; MatchFileName
	rcall	CopyName		; Copy a file/directory name
	movw	r7:r6, xh:xl		; Save Pointer
	brtc	Name2DirEntryDone	; Rest of name is empty -> done
;++
	push	r24			; Save end character
	rcall	Name2ChkRoot		; Skip .. in path when we are
	brcs	Name2DirEntry030	; at root
	movw	r25:r24, yh:yl
	rcall	OpenDir			; Open the directory
;	tst	r24
;	breq	Name2DirEntryfnf
Name2DirEntry010:
	movw	r25:r24, yh:yl
	rcall	ReadDir			; Read Directory Entry
	tst	r24
	brne	Name2DirEntryfnf	; End of Directory reached
	movw	r25:r24, yh:yl
	rcall	MatchFileName		; Compare Entry with Name
	tst	r24
	brne	Name2DirEntry010	; Not this one
	ldd	zl, Y+Vol_DirPointer+0	; Directory found
	ldd	zh, Y+Vol_DirPointer+1
	ldd	r18, Z+D_Attr
	sbrs	r18, A_Directory
	rjmp	Name2DirEntrynad	; this is not a directory, check if ok

	ldd	r16, Z+D_Cluster+0	; Get start cluster of directory 
	ldd	r17, Z+D_Cluster+1	;
	clr	r18
	clr	r19			; Assume FAT16
	ldd	r21, Y+Vol_Status
	sbrs	r21, Vol__FAT32
	rjmp	Name2DirEntry020
	ldd	r18, Z+D_ClusterH+0	; Upper 16-bits in case of FAT32
	ldd	r19, Z+D_ClusterH+1
Name2DirEntry020:
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	std	Z+P_Cluster+0, r16	; start cluster
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19
Name2DirEntry030:
	pop	r24
;--
	cpi	r24, DELIM		; Is there potentially another name?
	breq	Name2DirEntry000	; then proceed with next name
Name2DirEntryDone:
	clr	r24
Name2DirEntryExit:
	pop	yh
	pop	yl
	pop	r7
	pop	r6
	ret
;
;	Current name is not a directory, so we cannot proceed, therefore check
;	if this is the last name element
;
Name2DirEntrynad:
	pop	r24			; restore delimiter
	cpi	r24, CR			; 
	breq	Name2DirEntryDone
	cpi	r24, NULL
	breq	Name2DirEntryDone
	ldi	r24, FAT_NAD
;
Name2DirEntryfnf:
	pop	r24
	ldi	r24, FAT_FNF
	rjmp	Name2DirEntryExit
;
;	We cannot do a step to '..' if we are at the root
;
;	CS	if we have a step to '..' but we are already at root
;	CS	otherwise
;
Name2ChkRoot:
	ldd	r16, Y+Vol_DirCluster+0
	ldd	r17, Y+Vol_DirCluster+1
	ldd	r18, Y+Vol_DirCluster+2
	ldd	r19, Y+Vol_DirCluster+3

	subi	r16, 0
	sbci	r17, 0
	sbci	r18, 0
	sbci	r19, 0
	brne	Name2ChkRoot010		; not at root directory
	
	ldi	xl, low(NameBuffer)
	ldi	xh, high(NameBuffer)

	ld	r18, X+
	cpi	r18, '.'
	brne	Name2ChkRoot010		; not a '..' step
	ld	r18, X+
	cpi	r18, '.'
	brne	Name2ChkRoot010		; not a '..' step
	ld	r18, X+
	cpi	r18, NULL
	brne	Name2ChkRoot010		; not a '..' step even if it starts with ..
	std	Y+Vol_DirPointer+0, zero
	std	Y+Vol_DirPointer+1, zero
	sec				; at root and step is '..'
	ret

Name2ChkRoot010:
	clc
	ret
