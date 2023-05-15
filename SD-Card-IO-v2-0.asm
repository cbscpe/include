;--------------------------------------------------------------------------
;
;	To-do-list
;
;	-	Conditional assembly for various processor types
;	-	Define a dedicated register for the SPI primitives to exchange the
;		data with the caller
;	-	rename SD_CARD_CMD55 to SD_SEND_CMD55
;
;
;	SD-Card IO Routines	
;
;	I.	Credits
;		The document which for me inlcuded the most useful information is
;		a PDF by Simeon Maxein.
;
;	1.	SPI Primitives
;		These routines transfere a single byte from and to the SPI device
;		and are used when performance is not impartant, like initialisation
;		command phase and read status. 
;	1.1	SPI_WRITE_DUMMY
;		Writes 0xff to the device. Typically used to get a byte from the
;		SPI device
;	1.2	SPI_WRITE_BYTE
;		Write a byte
;	1.3 SPI_CLEAR
;		Deselect the device. First a dummy byte is sent to flush any 
;		outstanding response. The response is discarded. Then the device
;		is deselected and another dummy byte is written to make sure
;		we end with MOSI in high state
;	1.4	SPI_GET_RESPONSE
;		This routine is used to get a command response byte. This is
;		anything but 0xff. Also this routine only waits for a certain
;		amount of time. When a time out occurs it will return 0xff else
;		it will return the response.
;
;	2.	SD Card Basic Command Routines
;		These routines write a 6 byte command to the SD Card
;
;	2.1	SD_SEND_CMD
;	2.2	SD_CARD_CMD55
;
;--------------------------------------------------------------------------
;
;	I	.dw		mon_sd_card_spi			SD_CARD_SPI
;	H	.dw		mon_sd_card_ifc			SD_CARD_IFC
;	J	.dw		mon_sd_card_init		SD_CARD_INIT
;	K	.dw		mon_sd_card_readocr		SD_CARD_READOCR
;	L	.dw		mon_sd_card_blklen		SD_CARD_BLKLEN
;
;--------------------------------------------------------------------------
;
;	SPI Primitives, these primitives destroy temp!
;
SPI_WRITE_DUMMY:					; Write a dummy 0xFF
	mov		temp, ff
SPI_WRITE_BYTE:						; Alternate Write Entry Point
	out		SPDR, temp				; to write what is set in 'temp'
SPI_WRITE_BYTE_L:
	in		temp, SPSR
	sbrs	temp, SPIF				; Poll SPI End of Transmission Flag
	rjmp	SPI_WRITE_BYTE_L
	ret								; Done
	
SPI_CLEAR:
	rcall	SPI_WRITE_DUMMY			; Flush and remaining byte
	sbi		PORTB, SPI_SS			; Deselect SD-Card
	rcall	SPI_WRITE_DUMMY			; Make sure we end in MOSI=high
	ret

SPI_GET_RESPONSE:						; 
	push	count
	ldi		count, -sdspi_o
SPI_GET_RES_010:
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	cpi		temp, 0xff
	brne	SPI_GET_RES_020
	inc		count
	brne	SPI_GET_RES_010
SPI_GET_RES_020:
	pop		count
	ret
;--------------------------------------------------------------------------
;
;	SD card basic command routines
;
SD_SEND_CMD:						; Send a 6 byte command
	sbi		PORTB, SPI_SS			; Deselect SD-Card
	nop
	nop
	nop
	nop
	rcall	SPI_WRITE_DUMMY			; Set SPI to known state
	cbi		PORTB, SPI_SS			; Select SD-Card
	lds		temp, sd_cmd			; Send 6 command bytes
	rcall	SPI_WRITE_BYTE
	lds		temp, sd_cmd+1
	rcall	SPI_WRITE_BYTE
	lds		temp, sd_cmd+2
	rcall	SPI_WRITE_BYTE
	lds		temp, sd_cmd+3
	rcall	SPI_WRITE_BYTE
	lds		temp, sd_cmd+4
	rcall	SPI_WRITE_BYTE
	lds		temp, sd_cmd+5
	rcall	SPI_WRITE_BYTE
	ret								; Return with SD-Card selected
;
;	SD CMD55 Prefix for ACMDs
;
SD_CARD_CMD55:
	sbi		PORTB, SPI_SS			; Deselect SD-Card
	nop
	nop
	nop
	nop
	rcall	SPI_WRITE_DUMMY			; Set SPI to known state
	cbi		PORTB, SPI_SS			; Select SD-Card


	ldi 	temp, 0x77
	sts		sd_cmd, temp
	sts		sd_cmd+1, zero
	sts		sd_cmd+2, zero
	sts		sd_cmd+3, zero
	sts		sd_cmd+4, zero
	sts		sd_cmd+5, one
	rcall	SD_SEND_CMD				; Send Command
	rcall	SPI_GET_RESPONSE
	rcall	SPI_CLEAR
	ret
;--------------------------------------------------------------------------
;
;	SD-card primitives
;
;	General interface conventions
;
;		-	On success the carry is cleared
;		-	If an error occurs the carry is set
;		-	piostatus has the return code
;		-	piostatus+1 has additional information		-> perhaps we rename that to piostatus and piostatus+1
;
;	SD_CARD_SPI		(CMD0)
;		Descr.		Set the SD-Card in SPI Mode
;		Input		none
;		Output		CC	Card response was success
;					CS	Card command error
;
;		sd_status	sd_reset	set when card responded successfully
;
;	SD_CARD_IFC		(CMD8)
;		Descr.		Request the interface condition. This command is only
;					supported by Version 2 SD-Cards. To detect Version 2
;					cards you must send this command, Version 1 cards will
;					answer with "invalid command".
;		Input		none
;		Output		CC	Card response was success
;					CS	Card reported error
;
;		sd_status	sd_ver2		set when command was accepted. Only version 2
;								cards accept this command
;								when set we also set HCS (Host Capacity Support)
;								during initialisation
;
;	SD_CARD_READOCR	(CMD58)
;		Descr.		Reqeust Operating Conditions. This command is only
;					supported by Version 2 SD-Cards. When the initialisation
;					is finished the card will set CCS in the response if it
;					is a HC/XC card. You should call this function when SD_CARD_IFC
;					was called successfully
;		Input		none
;		Output		CC	Card response was successful
;					CS	Card reported error
;
;		sd_status	sd_ccs	if card reports HCS then we set this bit in the status
;							note that the mask of sd_ccs (0x40) is equivalent to 
;							bit30 in the SD-Card OCR, i.e. bit6 in the first byte.
;							Only cards with >2Gbyte will normally report CCS. Even
;							Version 2 cards with 2Gbyte or less report no CCS.
;							When set SD_CARD_XLT will use block address else it
;							will translate the block address to a byte address.
;
;	SD_CARD_INIT	(ACMD41)
;		Descr.		Requests the card to initialise. Note ACMD41 is only
;					recognised by SD-Cards but not by MMC cards.
;		Input		none
;		Output		CC	Initialisation successfull piostatus+1 contains the number of retries
;					CS	Initialisation unsuccessfull piostatus contains last response
;
;		sd_status	sd_init	set if card could be initialised successfully
;
;	SD_CARD_BLKLEN	(CDM16)
;		Descr.		Set the block length, this is only required for standard
;					cards that do not support card capacity, this is SD-cards
;					with 2Gbyte or less capacity.
;		Input		none
;		Output		piostatus contains the response
;
;	Initialisation procedure
;
;		SD_CARD_SPI						CMD0
;		SD_CARD_IFC		-> V2?			CMD8
;		SD_CARD_INIT					ACMD41
;		if V2 SD_CARD_READOCR			CMD58
;		if not HCXC SD_CARD_BLKLEN		CMD16
;
;--------------------------------------------------------------------------
;	1) SD-Card Set SPI Mode						Monitor Command: I
;
;		After Power-Up the SD-Card is in SD mode, however it can be switched to
;		SPI mode by sending CMD0 after a power-on reset. Note that you cannot
;		exit SPI mode and once the card has been initialised it will no longer
;		recognize initialisation commands. Therefore you must remove and insert
;		the SD-Card to be able to reinitialize the card again.
;
;		piostatus		return code, 0x01 is success 
;		piostatus+2		debug info inner count
;		piostatus+3		count if sent CMD0 command (0xff means fail)
;
SD_CARD_SPI:
	sts		sd_status, zero
	sbi		PORTB, SPI_SS			; Deselect SD-Card
	ldi		count, 10
SD_CARD_W1:
	dec		count					; Wait some time
	brne	SD_CARD_W1

	ldi		temp, (0<<SPIE)|(1<<SPE)|(0<<DORD)|(1<<MSTR)|(0<<CPOL)|(0<<CPHA)|(1<<SPR1)|(1<<SPR0)
	out		SPCR, temp
#ifdef __ATmega1284P__
	ldi		temp, (0<<SPI2X)		; Initialise uses slow clock
	out		SPSR, temp				; Initialise SPI interface
#endif
#ifdef __ATmega162__
	.if		spi2xb == 0
	cbi		SPSR, SPI2X
	.endif
#endif
	ldi		count, 15
SD_CARD_L1:
	rcall	SPI_WRITE_DUMMY			; Create >74 clock cycles with SD-Card deselected
	dec		count
	brne	SD_CARD_L1
;
;	SD-Card Software Reset
;
	ldi		temp, 0x40				; Setup CMD0 = Reset
	sts		sd_cmd, temp
	sts		sd_cmd+1, zero
	sts		sd_cmd+2, zero
	sts		sd_cmd+3, zero
	sts		sd_cmd+4, zero
	ldi		temp, 0x95				; With precalculated CRC
	sts		sd_cmd+5, temp
	rcall	SD_SEND_CMD				; Send Command
;
	ldi		count, -sdspi_i			; Inner time-out
SD_CARD_L2:
	rcall	SPI_WRITE_DUMMY			; Send dummy byte
	in		temp, SPDR
	sts		piostatus, temp			; Remember Status Received
	cpi		temp, 0xff				; Did SD-Card answer, 0xff means no answer
	brne	SD_CARD_DONE			; Yes
	inc		count					; Try one more time
	brne	SD_CARD_L2				; yes
;
SD_CARD_DONE:
	subi	count, -sdspi_i
	sts		piostatus+2, count		; show how many SPI_WRITE_DUMMY before we got a status
	cpi		temp, 0x01				; Is Answer = Success (now in idle state)
	breq	SD_CARD_SUCCESS			; Yes
	rcall	SPI_CLEAR
	sec								; Error
	ret

SD_CARD_SUCCESS:	
	rcall	SPI_CLEAR
	ldi		temp, sd_reset
	sts		sd_status, temp			; Mark status
	clc								; Success
	ret
;
;	2) SD-Card Interface Condition				Monitor Command: H
;
;		After CMD0 has been sent successfully and the card is in idle state
;		the interface conditions should be requested by the host using CMD8
;
;		CMD8 is only recognized by cards that conform to the SD specifications
;		version 2. Version 1 cards will return "invalid command" in the status
;		byte.
;
SD_CARD_IFC:
	ldi		temp, 0x48				; CMD8 Send Interface Condition
	sts		sd_cmd, temp
	sts		sd_cmd+1, zero
	sts		sd_cmd+2, zero
	sts		sd_cmd+3, one			; 2.7-3.6V is applied to SD Card
	ldi		temp, 0xAA
	sts		sd_cmd+4, temp			; Check Pattern that will be returned in response
	ldi		temp, 0x87
	sts		sd_CMD+5, temp			; Checksum
	rcall	SD_SEND_CMD
	rcall	SPI_GET_RESPONSE
	cpi		temp, 0xff				; Error occured
	breq	SD_CARD_IF_ERR
	sts		sd_rsp, temp			; Status
	sbrc	temp, 2					; Illegal Command
	rjmp	SD_CARD_IF_ILL			; This is either a Version 1 Card or a MMC (which we do not support)
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+1, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+2, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+3, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+4, temp
	rcall	SPI_CLEAR
	lds		temp, sd_status
	ori		temp, sd_ver2			; Version 2 Card
	sts		sd_status, temp
SD_CARD_IF_ILL:						; Version 1 Card
	clc
	ret

SD_CARD_IF_ERR:
	rcall	SPI_CLEAR
	sts		sd_status, zero			; no CCS Flag
	sec
	ret

;
;	4) Initialise Card							Monitor Command: J
;
;	ACMD41 is used to query the initialisation status of a SD-Card, non-SD-cards
;	will not respond to ACMD41
;
SD_CARD_INIT:
;
;	We need to query the initialisation status until we get a ready status.
;	The ready status is bit0 of the response. If it is set then the SD-card
;	is idle and when cleared it is ready. All other status bits must be
;	cleared as well, else we have an error.
;
	clr		count
	sts		piostatus, ff
SD_CARD_ACMD41_L1:
	rcall	SD_CARD_CMD55			; Send Prefix to prepare for ACMDs
	ldi		temp, 0x69
	sts		sd_cmd, temp
;
;	Cards that support HCS(High Capacity Support) can be switched to HCS
;	mode then the argument in read and write are no longer byte but block
;	offsets. Note for SDHC and SDXC cards HCS must be set in ACMD41 else
;	they will never switch from idle to ready.
;
	sts		sd_cmd+1, zero
	lds		temp, sd_status			; Response from CMD8
	andi	temp, sd_ver2			; Version 2 Card
	breq	SD_CARD_ACMD41_V1		; Version 1 Cards have no HCS support
	ldi		temp, sd_ccs			; Set bit to activate HCS support if available
SD_CARD_ACMD41_V1:
	sts		sd_cmd+1, temp
	sts		sd_cmd+2, zero
	sts		sd_cmd+3, zero
	sts		sd_cmd+4, zero
	sts		sd_cmd+5, one
	rcall	SD_SEND_CMD
	rcall	SPI_GET_RESPONSE		; R1 response
	
	cpi		temp, 0x00				; Initialisation done? I.e. no longer in idle mode
	breq	SD_CARD_ACMD41_DONE

	cpi		temp, 0x01				; The only other answer we accpet is one
	brne	SD_CARD_ACMD41_E1		; Error

	rcall	SPI_CLEAR
	inc		count
	brne	SD_CARD_ACMD41_L1
	ldi		temp, 0xfe
;
SD_CARD_ACMD41_E1:
	sts		piostatus, temp
	sts		piostatus+1, count
	rcall	SPI_CLEAR
	sec
	ret
;
SD_CARD_ACMD41_DONE:
	sts		piostatus, temp
	sts		piostatus+1, count
	lds		temp, sd_status
	ori		temp, sd_init
	sts		sd_status, temp
	rcall	SPI_CLEAR
	clc
	ret

;
;	3) Read Operation Condition Register		Monitor Command: K
;
;		CMD58, this is only required if the result sent in the reponse to CMD8 is
;		not acceptable. Note Version 1 SD Cards do respond to CMD8 with invalid 
;		command and also don't understand CMD58
;	
SD_CARD_READOCR:
	lds		temp, sd_status
	andi 	temp, sd_ver2
	breq	SD_CARD_READOCR_V1		; 
	ldi		temp, 0x7A				; 0x40 + 58.
	sts		sd_cmd, temp
	sts		sd_cmd+1, zero
	sts		sd_cmd+2, zero
	sts		sd_cmd+3, zero
	sts		sd_cmd+4, zero
	sts		sd_cmd+5, one
	rcall	SD_SEND_CMD
	rcall	SPI_GET_RESPONSE
	cpi		temp, 0xff
	breq	SD_CARD_READOCRERR
	sts		sd_rsp, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+1, temp
	andi	temp, sd_ccs
	breq	SD_CARD_READOCR_NOHCS	; Card has no card capacity support
	lds		temp, sd_status
	ori		temp, sd_ccs
	sts		sd_status, temp			; Set bit in status
SD_CARD_READOCR_NOHCS:
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+2, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+3, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+4, temp
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	sts		sd_rsp+5, temp
	rcall	SPI_CLEAR
SD_CARD_READOCR_V1:
	clc
	ret
SD_CARD_READOCRERR:
	rcall	SPI_CLEAR
	sec
	ret
;
;	5)	Set Block Length						Monitor Command: L
;
;	Set Block Length to 512bytes for standard SD-Cards
;
SD_CARD_BLKLEN:						; Set Block Length
	ldi		temp, 0x50				; Set Block Length Command
	sts		sd_cmd, temp
	sts		sd_cmd+1, zero
	sts		sd_cmd+2, zero
	ldi		temp, 0x02
	sts		sd_cmd+3, temp
	sts		sd_cmd+4, zero
	sts		sd_cmd+5, one
	rcall	SD_SEND_CMD
	rcall	SPI_GET_RESPONSE
	sts		piostatus, temp
	push	temp
	rcall	SPI_CLEAR
	pop		temp
	tst		temp
	clc
	breq	SD_CARD_BLKLEN_SUCC
	sec
SD_CARD_BLKLEN_SUCC:
	ret
;--------------------------------------------------------------------------
;	
;	Input:		Y pointer to standardised parameter block
;
;	Read block rom SD-Card
;

;
;	Timed SD_Card_Read for highest performance
;
SD_CARD_READ:

	push	r24
	push	r25
	push	xl
	push	xh
	push	zl
	push	zh

	ldi		temp,(0<<SPIE)|(1<<SPE)|(0<<DORD)|(1<<MSTR)|(0<<CPOL)|(0<<CPHA)|(0<<SPR1)|(0<<SPR0)
	out		SPCR,temp
;
#ifdef __ATmega1284P__
	ldi		temp,(spi2xb<<SPI2X)	; Requires a pull-up on MISO!!!
	out		SPSR,temp				; Initialise SPI interface
#endif
#ifdef __ATmega162__
	.if		spi2xb == 0
	cbi		SPSR, SPI2X
	.else
	sbi		SPSR, SPI2X
	.endif
#endif
;

	ldi		temp, 0x51				; Read Sector
	sts		sd_cmd, temp
	rcall	SD_CARD_XLT				; Translate Sector to SD Card address
	sts		sd_cmd+5, ff
	rcall	SD_SEND_CMD
	rcall	SPI_GET_RESPONSE
	sts		piostatus, temp
	tst		temp
	breq	XD_READ000
	rjmp	XD_READ910

XD_READ000:
	;+		Start Timer
	sts		TCCR1B, zero			; Stop
	in		temp, TIFR1
	out		TIFR1, temp				; Reset Flags
	sts		TCNT1H, zero
	sts		TCNT1L, zero
	sts		TCCR1A, zero
	ldi		temp, (1<<CS12) | (0<<CS11) | (0<<CS10)	; Prescaler 256 -> 1 count ~10usec
	sts		TCCR1B, temp				; Start
	;-		Start Timer

XD_READ010:
	out		SPDR, ff
XD_READ020:
	in		temp, SPSR
	sbrs	temp, SPIF
	rjmp	XD_READ020
	in		temp, SPDR
	cpi		temp, 0xfe				; Start data token?
	breq	XD_READ030
	cpi		temp, 0xff				; Wait data token?
	breq	XD_READ010
	sts		piostatus, one			; Error 1 invalid token received
	rjmp	XD_READ910
;
;	Timed Read, assuming SPI Clock = CPU Clock / 4 
;	After writing a dummy byte to SPDR, 32 cycles must pass before
;	we can read SPDR to get the byte from the SD-Card, that is for
;	reads the cycle must be exactly 33cycles
;
XD_READ030:
	out		SPDR, ff
	ldi		r24, low(512)			;  1
	ldi		r25, high(512)			;  1
	ldd		xl, Y+P_Address			;  2
	ldd		xh, Y+P_Address+1		;  2
	clr		crcl					;  1
	clr		crch					;  1	->  8
	
	.if		spi2xb == 0
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8

	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8
	.endif

	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8 =>32cycles have past since "out"
;
;	Timed SPI read cycle when SPI CLK is 1/4 of system clock a SPI byte transfer
;	takes 32 clock cycles. One extra cycle is required before we start the next
;	read, therefore the complete read byte loop must take 33 or more cycle.
;
;	When SP CLK is 1/2 of system clock then the read byte loop must take 17 cycles.
;
XD_READ040:
	in		temp, SPDR				;  1
	out		SPDR, ff				;  1
	st		X+, temp				;  2
	updcrc	temp					; 11	-> 15
	
	.if		spi2xb == 0
	rjmp	PC+1					;  2	-> 17

	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8

	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	.endif
	sbiw	r25:r24, 1				;  2
	brne	XD_READ040				;  2	->  8 => 33cycles for the loop
	nop								;  1 	compensate brne not taken

	in		temp, SPDR				;  
	out		SPDR, ff				;  
	sts		pcrc, temp				;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8
	
	.if		spi2xb == 0
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8

	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8
	.endif
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2
	rjmp	PC+1					;  2	->  8 => 32
	
	in		temp, SPDR
	sts		pcrc+1, temp
	rcall	SPI_CLEAR
	clc
	rjmp	XD_READ_SUCCESS
	
XD_READ910:
	rcall	SPI_CLEAR
	sec
XD_READ_SUCCESS:
	;+		Read Timer
	sts		TCCR1B, zero			; Stop
	sts		piostatus+2, ff
	sts		piostatus+3, ff			; Assume overflow
	lds		temp, TCNT1L
	sbis	TIFR1, TOV1
	sts		piostatus+2, temp

	lds		temp, TCNT1H
	sbis	TIFR1, TOV1
	sts		piostatus+3, temp		; Save number of cycles before read data
	;-		Read Timer

	pop		zh
	pop		zl
	pop		xh
	pop		xl
	pop		r25
	pop		r24
	ret



SD_CARD_READ0:
	push	r24
	push	r25
	push	xl
	push	xh
	push	zl
	push	zh

	ldi		temp,(0<<SPIE)|(1<<SPE)|(0<<DORD)|(1<<MSTR)|(0<<CPOL)|(0<<CPHA)|(0<<SPR1)|(0<<SPR0)
	out		SPCR,temp
;
;	ldi		temp,(spi2xb<<SPI2X)	; requires pull-up on MISO
;	out		SPSR,temp				; Initialise SPI interface
;
	ldi		temp, 0x51				; Read Sector
	sts		sd_cmd, temp
	rcall	SD_CARD_XLT				; Translate Sector to SD
	sts		sd_cmd+5, ff
	rcall	SD_SEND_CMD
	rcall	SPI_GET_RESPONSE
	sts		piostatus, temp
	tst		temp
	brne	SD_CARD_READ_ERR1
SD_CARD_READ_L1:
	rcall	SPI_WRITE_DUMMY
	in		temp, SPDR
	cpi		temp, 0xfe				; Data Token?
	breq	SD_CARD_READ_L2			; Fetch data
	cpi		temp, 0xff				; idle byte?
	breq	SD_CARD_READ_L1			; Wait for Data Token
	sts		piostatus, temp			; Invalid Response
	rjmp	SD_CARD_READ_ERR1
	
SD_CARD_READ_L2:
	ldi		r24, low(512)
	ldi		r25, high(512)
	ldd		xl, Y+P_Address
	ldd		xh, Y+P_Address+1
	clr		crcl
	clr		crch
SD_CARD_READ_BUF:
	out		SPDR, ff
	clz								; Make sure BRNE is taken
	rjmp	LOOP003
;
;	Interleave normal processing with waiting for SPI transfer, that
;	is when the transfer is finished read the byte and start another
;	transfer, and only then store the previous byte in the output
;	buffer and decrement the loop counter. 
;
;	As SPI clock rate is set to FCLK/2 we could also time the loop
;	to 16 or more cycles for maximal throughput
;
LOOP002:
	in		temp, SPDR
	out		SPDR, ff
	st		X+, temp
	updcrc	temp
	sbiw	r24:r25,1
LOOP003:
	in		temp, SPSR				; Does not affect SREG
	sbrs	temp, SPIF				; Does not affect SREG
;	sbis	SPSR, SPIF				; Does not affect SREG
	rjmp	LOOP003					; Does not affect SREG
	brne	LOOP002					; Either from start or sbiw

	in		temp, SPDR				; Note first CRC byte has been already
	sts		pcrc, temp
	rcall	SPI_WRITE_DUMMY			; requested. Only the second needs to
	in		temp, SPDR				; be requested.
	sts		pcrc+1, temp
	rcall	SPI_CLEAR
	clc
	rjmp	SD_CARD_READ_END

SD_CARD_READ_ERR1:
	rcall	SPI_CLEAR
	sec
SD_CARD_READ_END:

	pop		zh
	pop		zl
	pop		xh
	pop		xl
	pop		r25
	pop		r24
	ret
;--------------------------------------------------------------------------
;	
;	Input:		Y pointer to standardised parameter block
;
;	Write block to SD-Card
;
SD_CARD_WRITE:
	push	r24
	push	r25
	push	xl
	push	xh
	push	zl
	push	zh

	;+		Start Timer
	sts		TCCR1B, zero			; Stop
	in		temp, TIFR1
	out		TIFR1, temp				; Reset Flags
	sts		TCNT1H, zero
	sts		TCNT1L, zero
	sts		TCCR1A, zero
	ldi		temp, (1<<CS12) | (0<<CS11) | (0<<CS10)	; Prescaler 256 -> 1 count ~10usec
	sts		TCCR1B, temp				; Start
	;-		Start Timer

	
	ldi		temp,(0<<SPIE)|(1<<SPE)|(0<<DORD)|(1<<MSTR)|(0<<CPOL)|(0<<CPHA)|(0<<SPR1)|(0<<SPR0)
	out		SPCR,temp
;
	ldi		temp,(0<<SPI2X)			; Write uses slow clock
	out		SPSR,temp				; Initialise SPI interface
;
	ldi		temp, 0x58				; Write Sector
	sts		sd_cmd, temp
	rcall	SD_CARD_XLT				; Translate Sector to SD-Card address
	sts		sd_cmd+5, ff
	rcall	SD_SEND_CMD				; Send Write Sector Command
	rcall	SPI_GET_RESPONSE		; Get Return status
	sts		piostatus, temp			; Save it
	tst		temp					; Ok?
	brne	SD_CARD_WRITE_ERR1		; No error
	
	ldi		temp, 0xfe				; Data token
	rcall	SPI_WRITE_BYTE			; Write
	ldi		r24, low(512)			; Prepare pointer
	ldi		r25, high(512)
	ldd		xl, Y+P_Address+0
	ldd		xh, Y+P_Address+1
SD_CARD_WRITE_L1:					; 
	ld		temp, X+				; Get Byte
	rcall	SPI_WRITE_BYTE			; Write
	sbiw	r25:r24, 1
	brne	SD_CARD_WRITE_L1		; 512bytes
	
	ldi		temp, 0x01				; Dummy CRC
	rcall	SPI_WRITE_BYTE
	ldi		temp, 0x01
	rcall	SPI_WRITE_BYTE

	rcall	SPI_WRITE_DUMMY			; Get status
	in		temp, SPDR				;
	sts		piostatus+1, temp		; Save in status block
	andi	temp, 0x1f
	cpi		temp, 0x05				; must be 0x05 mod 0x1f
	breq	SD_CARD_WRITE_SUCC		; yes success
SD_CARD_WRITE_ERR1:	
	rcall	SPI_CLEAR				; Stop SPI
	sec								; Error
	rjmp	SD_CARD_WRITE_DONE

SD_CARD_WRITE_SUCC:	
	rcall	SPI_WRITE_DUMMY			; Until the SD-Card has finished
	in		temp, SPDR				; internal operation it will pull
	tst		temp					; MISO low, during that time
	breq	SD_CARD_WRITE_SUCC		; you must not send another command
	rcall	SPI_CLEAR				; Stop SPI
	clc								; Success
SD_CARD_WRITE_DONE:	
	;+		Read Timer
	sts		TCCR1B, zero			; Stop
	sts		piostatus+2, ff
	sts		piostatus+3, ff			; Assume overflow
	lds		temp, TCNT1L
	sbis	TIFR1, TOV1
	sts		piostatus+2, temp

	lds		temp, TCNT1H
	sbis	TIFR1, TOV1
	sts		piostatus+3, temp		; Save number of cycles before read data
	;-		Read Timer

	pop		zh
	pop		zl
	pop		xh
	pop		xl
	pop		r25
	pop		r24
	ret
;--------------------------------------------------------------------------
;
;	Translate Sector in SD-Card address
;
SD_CARD_XLT:
	lds		temp, sd_status
	andi	temp, sd_ccs
	brne	SD_CARD_XLTHC			; HCXC Card
	sts		sd_cmd+4, zero			; Standard SD Cards

	ldd		temp, Y+P_Sector		; require a byte offset so we
	add		temp, temp				; need to translate the sector
	sts		sd_cmd+3, temp			; to a byte offset, as block length

	ldd		temp, Y+P_Sector+1		; has been set to 512 this is just
	adc		temp, temp				; writing twice the sector number in
	sts		sd_cmd+2, temp			; psector to one byte offset of the

	ldd		temp, Y+P_Sector+2		; byte offset field of the read/write
	adc		temp, temp				; command
	sts		sd_cmd+1, temp

	ret
SD_CARD_XLTHC:						; HCXC Card expect just the sector
	ldd		temp, Y+P_Sector		; Number.
	sts		sd_cmd+4, temp
	ldd		temp, Y+P_Sector+1
	sts		sd_cmd+3, temp
	ldd		temp, Y+P_Sector+2
	sts		sd_cmd+2, temp
	ldd		temp, Y+P_Sector+3
	sts		sd_cmd+1, temp
	ret	

	align	8
;=========================================================================
;
;	Note the updcrc macro assumes that the tables are page aligned
;
;	low byte CRC lookup table
; 
	align	8
crclo:
 .db 0x00,0x21,0x42,0x63,0x84,0xA5,0xC6,0xE7,0x08,0x29,0x4A,0x6B,0x8C,0xAD,0xCE,0xEF
 .db 0x31,0x10,0x73,0x52,0xB5,0x94,0xF7,0xD6,0x39,0x18,0x7B,0x5A,0xBD,0x9C,0xFF,0xDE
 .db 0x62,0x43,0x20,0x01,0xE6,0xC7,0xA4,0x85,0x6A,0x4B,0x28,0x09,0xEE,0xCF,0xAC,0x8D
 .db 0x53,0x72,0x11,0x30,0xD7,0xF6,0x95,0xB4,0x5B,0x7A,0x19,0x38,0xDF,0xFE,0x9D,0xBC
 .db 0xC4,0xE5,0x86,0xA7,0x40,0x61,0x02,0x23,0xCC,0xED,0x8E,0xAF,0x48,0x69,0x0A,0x2B
 .db 0xF5,0xD4,0xB7,0x96,0x71,0x50,0x33,0x12,0xFD,0xDC,0xBF,0x9E,0x79,0x58,0x3B,0x1A
 .db 0xA6,0x87,0xE4,0xC5,0x22,0x03,0x60,0x41,0xAE,0x8F,0xEC,0xCD,0x2A,0x0B,0x68,0x49
 .db 0x97,0xB6,0xD5,0xF4,0x13,0x32,0x51,0x70,0x9F,0xBE,0xDD,0xFC,0x1B,0x3A,0x59,0x78
 .db 0x88,0xA9,0xCA,0xEB,0x0C,0x2D,0x4E,0x6F,0x80,0xA1,0xC2,0xE3,0x04,0x25,0x46,0x67
 .db 0xB9,0x98,0xFB,0xDA,0x3D,0x1C,0x7F,0x5E,0xB1,0x90,0xF3,0xD2,0x35,0x14,0x77,0x56
 .db 0xEA,0xCB,0xA8,0x89,0x6E,0x4F,0x2C,0x0D,0xE2,0xC3,0xA0,0x81,0x66,0x47,0x24,0x05
 .db 0xDB,0xFA,0x99,0xB8,0x5F,0x7E,0x1D,0x3C,0xD3,0xF2,0x91,0xB0,0x57,0x76,0x15,0x34
 .db 0x4C,0x6D,0x0E,0x2F,0xC8,0xE9,0x8A,0xAB,0x44,0x65,0x06,0x27,0xC0,0xE1,0x82,0xA3
 .db 0x7D,0x5C,0x3F,0x1E,0xF9,0xD8,0xBB,0x9A,0x75,0x54,0x37,0x16,0xF1,0xD0,0xB3,0x92
 .db 0x2E,0x0F,0x6C,0x4D,0xAA,0x8B,0xE8,0xC9,0x26,0x07,0x64,0x45,0xA2,0x83,0xE0,0xC1
 .db 0x1F,0x3E,0x5D,0x7C,0x9B,0xBA,0xD9,0xF8,0x17,0x36,0x55,0x74,0x93,0xB2,0xD1,0xF0 
;
;	hi byte CRC lookup table
;
crchi:
 .db 0x00,0x10,0x20,0x30,0x40,0x50,0x60,0x70,0x81,0x91,0xA1,0xB1,0xC1,0xD1,0xE1,0xF1
 .db 0x12,0x02,0x32,0x22,0x52,0x42,0x72,0x62,0x93,0x83,0xB3,0xA3,0xD3,0xC3,0xF3,0xE3
 .db 0x24,0x34,0x04,0x14,0x64,0x74,0x44,0x54,0xA5,0xB5,0x85,0x95,0xE5,0xF5,0xC5,0xD5
 .db 0x36,0x26,0x16,0x06,0x76,0x66,0x56,0x46,0xB7,0xA7,0x97,0x87,0xF7,0xE7,0xD7,0xC7
 .db 0x48,0x58,0x68,0x78,0x08,0x18,0x28,0x38,0xC9,0xD9,0xE9,0xF9,0x89,0x99,0xA9,0xB9
 .db 0x5A,0x4A,0x7A,0x6A,0x1A,0x0A,0x3A,0x2A,0xDB,0xCB,0xFB,0xEB,0x9B,0x8B,0xBB,0xAB
 .db 0x6C,0x7C,0x4C,0x5C,0x2C,0x3C,0x0C,0x1C,0xED,0xFD,0xCD,0xDD,0xAD,0xBD,0x8D,0x9D
 .db 0x7E,0x6E,0x5E,0x4E,0x3E,0x2E,0x1E,0x0E,0xFF,0xEF,0xDF,0xCF,0xBF,0xAF,0x9F,0x8F
 .db 0x91,0x81,0xB1,0xA1,0xD1,0xC1,0xF1,0xE1,0x10,0x00,0x30,0x20,0x50,0x40,0x70,0x60
 .db 0x83,0x93,0xA3,0xB3,0xC3,0xD3,0xE3,0xF3,0x02,0x12,0x22,0x32,0x42,0x52,0x62,0x72
 .db 0xB5,0xA5,0x95,0x85,0xF5,0xE5,0xD5,0xC5,0x34,0x24,0x14,0x04,0x74,0x64,0x54,0x44
 .db 0xA7,0xB7,0x87,0x97,0xE7,0xF7,0xC7,0xD7,0x26,0x36,0x06,0x16,0x66,0x76,0x46,0x56
 .db 0xD9,0xC9,0xF9,0xE9,0x99,0x89,0xB9,0xA9,0x58,0x48,0x78,0x68,0x18,0x08,0x38,0x28
 .db 0xCB,0xDB,0xEB,0xFB,0x8B,0x9B,0xAB,0xBB,0x4A,0x5A,0x6A,0x7A,0x0A,0x1A,0x2A,0x3A
 .db 0xFD,0xED,0xDD,0xCD,0xBD,0xAD,0x9D,0x8D,0x7C,0x6C,0x5C,0x4C,0x3C,0x2C,0x1C,0x0C
 .db 0xEF,0xFF,0xCF,0xDF,0xAF,0xBF,0x8F,0x9F,0x6E,0x7E,0x4E,0x5E,0x2E,0x3E,0x0E,0x1E 
