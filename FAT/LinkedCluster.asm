;--------------------------------------------------------------------------
;
;	This routine finds the next cluster of the linked clusters of a 
;	file. 
;
;	Input:
;		r25:r24		datastructure of file
;
;	Output:
;		P_Cluster updated with linked cluster
;
;	Completioncode: r24
;		FAT_EOF		end of file reached no more clusters
;		FAT_OK		new cluster stored int P_Cluster
;
;	This routine uses the IO Parameter block at Vol_fatiob of the volume
;	control block to perform the necessary IO to read a sector of the FAT.
;
;	The cluster is used as index into the FAT. We assume a sector has
;	512bytes, we do not support different sector sizes for the moment.
;
;	For FAT-16 the FAT is an array of uint16_t clusters for FAT-32 the
;	FAT is an array of uint32_t. First we need to translate the cluster
;	into a sector index into the FAT and a byte offset into the sector.
;
;	In case of FAT-16 this is simple the high byte is the sector offset
;	and the low byte of the cluster is the array index into the sector.
;	In case of FAT-32 we need to first multiply the cluster by 2 to
;	have the same logic.
;
;
LinkedCluster:;(struct* IOParameterBlock, struct* VolumeControlBlock)
	push	yl
	push	yh			; save
	movw	yh:yl, r25:r24
	movw	zh:zl, r23:r22
	ldd	r16, Y+P_Cluster+0	; Retrieve the Cluster
	ldd	r17, Y+P_Cluster+1	; 
	clr	r18			; Assume FAT16
	clr	r19
;
;	Calculate Sector in FAT of current cluster
;	FAT16: 256 entries per sector, just shift one byte right
;	Sector = Vol_Fat1Start + P_Cluster/256
;

	ldd	r20, Z+Vol_Status
	sbrs	r20, Vol__FAT32
	rjmp	LinkedCluster16
;
;	FAT32: 128 entries per sector, first shift the cluster one bit 
;	to the left so we can use the same formula
;	
;	Sector = Vol_Fat1Start + (P_Cluster*2)/256

	ldd	r18, Y+P_Cluster+2	; For FAT32 it is 4 bytes
	ldd	r19, Y+P_Cluster+3	;

	add	r16, r16		; In case of FAT32 we need to
	adc	r17, r17		; shift the Cluster by 2 in order
	adc	r18, r18		; to convert cluster in Sector as
	adc	r19, r19		; a FAT entry has 4 bytes

LinkedCluster16:
	push	r20			; Need Vol Status later again
	push	yl
	push	yh			; Save current data structure pointer
	ldd	yl, Z+Vol_fatiob+0	; All FAT operations use a dedicated
	ldd	yh, Z+Vol_fatiob+1	; control block
;
;	Now bits 8..31 of the cluster number are the sector offset
;	into the FAT, just add Vol_fat1start to get the required
;	sector to have in memory.
;
	ldd	r20, Z+Vol_fat1start+0
	add	r17, r20		; Add bit0..7 of fat1start to bit8..15
	ldd	r20, Z+Vol_fat1start+1
	adc	r18, r20		; Add bit8..15 of fat1start to bit16..23
	ldd	r20, Z+Vol_fat1start+2
	adc	r19, r20		; Add bit16..23 of fat1start to bit24..31
	ldd	r20, Z+Vol_fat1start+3
	adc	r20, zero		; Add carry to bit24..31 of fat1start
	
	ldd	r21, Y+P_Sector+0	; Check if we already have the required
	cp	r21, r17		; sector in the memory buffer
	ldd	r21, Y+P_Sector+1
	cpc	r21, r18
	ldd	r21, Y+P_Sector+2
	cpc	r21, r19
	ldd	r21, Y+P_Sector+3
	cpc	r21, r20
	breq	LinkedSameSect		; We already have it

LinkedReadSect:
	std	Y+P_Sector+0, r17	; Save Sector to read
	std	Y+P_Sector+1, r18
	std	Y+P_Sector+2, r19
	std	Y+P_Sector+3, r20	; 

	movw	r25:r24, yh:yl
	push	r16			; Save sector offset (r16 is a volatile reg)
	call	SD_CARD_READ
	pop	r16			; Restore sector offset
LinkedDead:
	cpi	r24, SD_SUCCESS
	brne	LinkedDead		; Loop of Death

LinkedSameSect:
;
;	For FAT-16 bits0..7 of r16 are an index into an array of 256 uint16_t
;	values and for FAT-32 bits1..7 of r16 are an index into an array of
;	128 uint32_t values. Therefore we need to add twice the value of r16
;	to the buffer address of the FAT sector we have read.
;
	ldi	r24, FAT_OK		; We assume that there is another cluster
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	add	xl, r16			; Add low 8 bits of index twice to
	adc	xh, zero		; the buffer address to get the pointer
	add	xl, r16			; to linked cluster, note that we need
	adc	xh, zero		; to respect a potential carry 
	pop	yh
	pop	yl			; Restore calling data structure pointer
	pop	r20			; Restore Volume Status
	sbrc	r20, Vol__FAT32
	rjmp	LinkedCluster32
;
;	At the same time we copy the new cluster we also check the end of cluster
;	chain. A FAT16 entry of 0xFFF8..0xFFFF defines end of chain.
;
	ld	r16, X+			; Get the next FAT-16 cluster
	ld	r17, X+
	std	Y+P_Cluster+0, r16
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, zero	; Cluster is only a 16-bit value so for
	std	Y+P_Cluster+3, zero	; FAT-16 set upper word to zero
	andi	r16, 0xF8		; Mask bits in lower byte of next cluster
	cpi	r16, 0xF8		; And compare to the value for end of
	brne	Linked16		; linked cluster
	cpi	r17, 0xFF
	brne	Linked16
	ldi	r24, FAT_EOF		; We reached the end
Linked16:
	pop	yh
	pop	yl
	ret
;
;
;
LinkedCluster32:
;
;	At the same time we copy the new cluster we also check the end of cluster
;	chain. A FAT32 entry of 0x0FFFFFF8..0x0FFFFFFF defines end of chain.
;
	ld	r16, X+			; Get the next FAT-32 cluster
	ld	r17, X+
	ld	r18, X+
	ld	r19, X+
	std	Y+P_Cluster+0, r16	; Save it to the IO Parameter
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19

	andi	r16, 0xF8		; Mask the lower bits
	cpi	r16, 0xF8		; Compare
	brne	LinkedMore
	cpi	r17, 0xFF
	brne	LinkedMore
	cpi	r18, 0xFF
	brne	LinkedMore
	andi	r19, 0x0F		; Mask the higher bits
	cpi	r19, 0x0F		; Compare
	brne	LinkedMore
	ldi	r24, FAT_EOF		; We reached the end
LinkedMore:
	pop	yh
	pop	yl
	ret

