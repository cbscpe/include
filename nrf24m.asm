;-----------------------------------------------------------------------------
;
;	RF24 Library using a standard control block
;
;	All Routines are called with a single parameter, the control
;	block parameter block, except for the initialisation module
;	that requires the parameter for the ports
;
recordstart	rf24
record		rf24, pipe0,		5
record		rf24, pipe0open,	1
record		rf24, ackpayloads,	1
record		rf24, dynamicpayloads,	1
record		rf24, payloadsize,	1
record		rf24, addresswidth,	1
record		rf24, configregister,	1
record		rf24, status,		1
record		rf24, variant,		1
record		rf24, register,		1
record		rf24, regvalue,		1
record		rf24, port,		2
record		rf24, ce,		1
record		rf24, csn,		1
record		rf24, spi,		2
recordend	rf24, size

.macro	_begin
;
;	Assumes Y points to instance, destroys Z
;
	ldd	zl, Y+rf24_port+0
	ldd	zh, Y+rf24_port+1
	ldd	@0, Y+rf24_csn
	std	Z+PORT_OUTCLR_offset, @0
.endmacro
.macro	_spi
;
;	Assumes Y points to instance, destroys Z
;
	ldd	zl, Y+rf24_spi+0
	ldd	zh, Y+rf24_spi+1
        std	Z+SPI_DATA_offset, @0
l010:
	ldd     @0, Z+SPI_INTFLAGS_offset
        sbrs    @0, SPI_IF_bp
        rjmp    l010
        ldd     @0, Z+SPI_DATA_offset
.endmacro
.macro	_end
;
;	Assumes Y points to instance, destroys Z
;
	ldd	zl, Y+rf24_port+0
	ldd	zh, Y+rf24_port+1
	ldd	@0, Y+rf24_csn
	std	Z+PORT_OUTSET_offset, @0
.endmacro

	.cseg
;-----------------------------------------------------------------------------
;
;	Create a new RF24 instance, for the moment we require that CE and CSN
;	are on the same port but different pins, we do not support the tiny
;	model. We assume a new AVR core AVR4 (AVR128Dx or Atmega4809 etc.)
;
;	The IO devices on these architectures are highly standardised and
;	each device has a naturally alligend base address of the device
;	registers and the instances of a given device, e.g. PORT, UART, SPI,
;	have a naturally alligned size in the address space, so it is easy
;	to calculate the addresses and support dynamic instances
;
;
nrf24_new:;(uint8_t port, uint8_t ce, uint8_t csn, uint8_t spi)
;
;	r24	port	Portname	A=0, B=1, ....
;	r22	ce	PIN		0..7
;	r20	cns	PIN		0..7
;	r18	spi	Number		SPI0=0, SPI1=1
;
	mov	r23, r24		; malloc only uses r25:r24
	ldi	r24, low(rf24_size)
	ldi	r25, high(rf24_size)
	call	malloc
	sbiw	r25:r24, 0
	brne	nrf24_new010
	ret
nrf24_new010:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r25, low(PORTB_base - PORTA_base)
	mul	r23, r25
	movw	zh:zl, r1:r0
	clr	zero
	subi	zl, low(-PORTA_base)
	sbci	zh, high(-PORTA_base)
	std	Y+rf24_port+0, zl	; 
	std	Y+rf24_port+1, zh	; 
	ldi	r25, 1			; Convert CE Pin Nbr to Bit Mask
	tst	r22
	breq	nrf24_new030
nrf24_new020:
	lsl	r25
	dec	r22
	brne	nrf24_new020	
nrf24_new030:
	std	Y+rf24_ce, r25
	std	Z+PORT_DIRSET_offset, r25 
	std	Z+PORT_OUTCLR_offset, r25
	ldi	r25, 1			; Convert CSN Pin Nbr to Bit Mask
	tst	r20
	breq	nrf24_new050
nrf24_new040:
	lsl	r25
	dec	r20
	brne	nrf24_new040	
nrf24_new050:
	std	Y+rf24_csn, r25
	std	Z+PORT_DIRSET_offset, r25 
	std	Z+PORT_OUTSET_offset, r25

	ldi	r25, low(SPI1_base - SPI0_base)
	mul	r18, r25
	movw	zh:zl, r1:r0
	clr	zero			; Restore ZERO
	subi	zl, low(-SPI0_base)
	sbci	zh, high(-SPI0_base)
	std	Y+rf24_spi+0, zl
	std	Y+rf24_spi+1, zh
	ldi	r18, SPI_MASTER_bm | SPI_PRESC_DIV4_gc
	std	Z+SPI_CTRLA_offset, r18		
        ldi     r18, SPI_SSD_bm
        std     Z+SPI_CTRLB_offset, r18
	ldi	r18, SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
	std	Z+SPI_CTRLA_offset, r18		
	
	ldi	r24, 32
	std	Y+rf24_payloadsize, r24
	ldi	r24, 0
	std	Y+rf24_variant, r24
	std	Y+rf24_pipe0open, r24
	ldi	r24, 5
	std	Y+rf24_addresswidth, r24
	ldi	r24, 1
	std	Y+rf24_dynamicpayloads, r24
	
	movw	r25:r24, yh:yl
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
nrf24_begin:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, low(5)
	ldi	r25, high(5)
	call	delay
;
	ldi	r22, 4			; Delay in steps of 250usec
	ldi	r20, 7			; Retries
	movw	r25:r24, yh:yl
	rcall	nrf24_setRetries
	ldi	r22, RF24_250KBPS
	movw	r25:r24, yh:yl
	rcall	nrf24_setDataRate
;
;	In RF24.cpp the FEATURE register is checked, we only support the + variant
;
	push	r16
	push	r17
	ldi	r22, FEATURE
	movw	r25:r24, yh:yl
	rcall	_nrf24_read_register
	mov	r16, r24
;	ldi	r24, FEATURE
;	std	Y+rf24_register, r24
;	movw	r25:r24, yh:yl
;	rcall	nrf24_read_register
;	ldd	r16, Y+rf24_regvalue	; before_toggle
	movw	r25:r24, yh:yl		;
	rcall	nrf24_toggle_features	;
	ldi	r22, FEATURE
	movw	r25:r24, yh:yl		;
	rcall	_nrf24_read_register	;
	mov	r17, r24
;	movw	r25:r24, yh:yl		;
;	rcall	nrf24_read_register	;
;	ldd	r17, Y+rf24_regvalue	; after_toggle
	ldi	r24, 1
	cpse	r16, r17		; _is_p_variant = before_toggle == after_toggle;
	ldi	r24, 0			; not equal so set it zero
	std	Y+rf24_variant, r24	; set variant
	tst	r17			; if (after_toggle)
	breq	nrf24_begin030		; {
	tst	r24			;   if (is_p_variant)
	breq	nrf24_begin020		;   {
	movw	r25:r24, yh:yl		;
	rcall	nrf24_toggle_features	;     toggle_features();
nrf24_begin020:				;   }
	ldi	r24, FEATURE		;
	std	Y+rf24_register, r24	;   
	std	Y+rf24_regvalue, zero	;
	movw	r25:r24, yh:yl		;
	rcall	nrf24_write_register	;   write_regiser(FEATURE, 0);
nrf24_begin030:				; }
	pop	r17
	pop	r16
;
	std	Y+rf24_ackpayloads, zero
	ldi	r24, DYNPD
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, zero
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
;
	std	Y+rf24_dynamicpayloads, zero
	ldi	r24, EN_AA
	ldi	r22, (1<<ENAA_P0) | (1<<ENAA_P1) | (1<<ENAA_P2) | (1<<ENAA_P3) | (1<<ENAA_P4) | (1<<ENAA_P5)
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
;
	ldi	r24, EN_RXADDR
	ldi	r22, (1<<ERX_P0) | (1<<ERX_P1)
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
;
	movw	r25:r24, yh:yl
	ldi	r22, 32
	rcall	nrf24_setPayloadSize
;
	movw	r25:r24, yh:yl
	ldi	r22, 5
	rcall	nrf24_setAddressWidth
;
	movw	r25:r24, yh:yl
	ldi	r22, 75
	rcall	nrf24_setChannel
;	
	ldi	r24, NRF_STATUS
	ldi	r22, (1<<RX_DR) | (1<<TX_DS) | (1<<MAX_RT)
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	movw	r25:r24, yh:yl
	rcall	nrf24_flush_rx
	movw	r25:r24, yh:yl
	rcall	nrf24_flush_tx

	ldi	r24, NRF_CONFIG
	ldi	r22, (1<<EN_CRC) | (1<<CRCO)
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register

	ldi	r22, NRF_CONFIG
	movw	r25:r24, yh:yl
	rcall	_nrf24_read_register
;	ldi	r24, NRF_CONFIG
;	std	Y+rf24_register, r24
;	movw	r25:r24, yh:yl
;	rcall	nrf24_read_register
;	ldd	r24, Y+rf24_regvalue
	std	Y+rf24_configregister, r24

	movw	r25:r24, yh:yl
	rcall	nrf24_powerUp
	clr	r24
	ldd	r22, Y+rf24_configregister
	cpi	r22, (1<<EN_CRC) | (1<<CRCO) | (1<<PWR_UP)
	brne	nrf24_begin040
	inc	r24
nrf24_begin040:
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;	Instead of updating 3 boolean variables it just returns the
;	status from the NRF24L01+ and the caller can check the bits
;
nrf24_whatHappened:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, NRF_STATUS
	ldi	r25, (1<<RX_DR) | (1<<TX_DS) | (1<<MAX_RT)
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r25
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldd	r24, Y+rf24_status
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;	This function returns -1 if no pipe has data else it returns the pipe.
;	This is different to the RF24 arduino library function
;
nrf24_available:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	_begin	r25
	ldi	r24, RF24_NOP		; Note that when the first byte is
	_spi	r24			; sent over the SPI interface the
	_end	r25			; NRF24L01+ returns the status at
	std	Y+rf24_status, r24
	lsr	r24			; RX_P_NO to bits 0:2
	andi	r24, 0x07
	cpi	r24, 6			; Valid eipe?
	brlo	nrf24_available010	; Yes data was received on a pipe
	ldi	r24, -1			; No data received
nrf24_available010:
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_write:;(struct nrf24 *nrf24[r25:r24], const uint8_t* address[r23:r22], uint8_t length:[r20])
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	cpi	r20, 33
	brlo	nrf24_write010
	ldi	r20, 32			; no more than 32 bytes
nrf24_write010:
	ldd	r21, Y+rf24_payloadSize
	cp	r20, r21
	brlo	nrf24_write020
	mov	r20, r21		; no more than configured payload size
nrf24_write020:
	movw	xh:xl, r23:r22
	_begin	r24
	ldi	r24, W_TX_PAYLOAD
	_spi	r24
nrf24_write030:
	ld	r24, X+	
	_spi	r24
	dec	r20
	brne	nrf24_write030
	_end	r24

	ldd	zl, Y+rf24_port+0
	ldd	zh, Y+rf24_port+1
	ldd	r24, Y+rf24_ce
	std	Z+PORT_OUTSET_offset, r24; Set CE Pin, enable RF Transmitter

nrf24_write040:
	_begin	r24
	ldi	r24, RF24_NOP
	_spi	r24
	_end	r25			; Must not destroy r24
	andi	r24, (1<<TX_DS) | (1<<MAX_RT)
	breq	nrf24_write040		; Loop if not set
	
	ldd	zl, Y+rf24_port+0
	ldd	zh, Y+rf24_port+1
	ldd	r24, Y+rf24_ce
	std	Z+PORT_OUTCLR_offset, r24; Clear CE Pin, enable RF Transmitter

	_begin	r24
	ldi	r24, W_REGISTER | NRF_STATUS
	_spi	r24
	ldi	r25, (1<<TX_DS) | (1<<MAX_RT)
	_spi	r25
	_end	r25
	ldi	r25, 1			; Assume success
	sbrs	r24, MAX_RT
	rjmp	nrf24_write050
	_begin	r24
	ldi	r24, FLUSH_TX
	_spi	r24
	_end	r24
	clr	r25
nrf24_write050:
	mov	r24, r25
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
nrf24_read:;(struct nrf24 *nrf24, void *buf, uint8_t len)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	clr	r19			; Assume no extra bytes from FIFO
	cpi	r20, 33
	brlo	nrf24_read010		;
	ldi	r20, 32			; Cannot read more then 32 bytes from FIFO
nrf24_read010:
	ldd	r18, Y+rf24_dynamicpayloads
	tst	r18
	brne	nrf24_read020		; Dynamic Payload Size
	ldi	r19, 32			; In case we have no dynamic payloads
	sub	r19, r20		; we need to retrieve 32 bytes even when
					; less bytes requested
nrf24_read020:
	movw	xh:xl, r23:r22
	_begin	r24
	ldi	r24, R_RX_PAYLOAD	; Read Receive FIFO
	_spi	r24
	tst	r20			; Another byte to the buffer
	breq	nrf24_read040		; No
nrf24_read030:
	ldi	r24, 0xFF
	_spi	r24
	st	X+, r24
	dec	r20
	brne	nrf24_read030
nrf24_read040:
	tst	r19			; Another byte from FIFO
	breq	nrf24_read060		; No
nrf24_read050:
	ldi	r24, 0xFF
	_spi	r24
	dec	r19
	brne	nrf24_read050
nrf24_read060:
	_end	r24
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_startListening:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, NRF_CONFIG
	std	Y+rf24_register, r24
	ldd	r24, Y+rf24_configregister
	ori	r24, (1<<PRIM_RX)
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r25, NRF_STATUS
	ldi	r24, (1<<RX_DR) | (1<<TX_DS) | (1<<MAX_RT)
	std	Y+rf24_register, r25
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldd	zl, Y+rf24_port+0
	ldd	zh, Y+rf24_port+1
	ldd	r24, Y+rf24_ce
	std	Z+PORT_OUTSET_offset, r24	; Set CE Pin, enable RF Receiver
	ldd	r24, Y+rf24_pipe0open
	tst	r24
	breq	nrf24_startListening020		; no need to restore address of Pipe0
	ldd	r25, Y+rf24_addresswidth
	movw	xh:xl, yh:yl
	adiw	xh:xl, rf24_pipe0
	_begin	r24
	ldi	r24, W_REGISTER | RX_ADDR_P0
	_spi	r24
nrf24_startListening010:
	ld	r24, X+
	_spi	r24
	dec	r25
	brne	nrf24_startListening010
	_end	r24
	rjmp	nrf24_startListening030
nrf24_startListening020:
	clr	r22
	movw	r25:r24, yh:yl
	rcall	nrf24_closeReadingPipe
nrf24_startListening030:
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_stopListening:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+rf24_port+0
	ldd	zh, Y+rf24_port+1
	ldd	r24, Y+rf24_ce
	std	Z+PORT_OUTCLR_offset, r24
	ldi	r24, low(1)
	ldi	r25, high(1)			; Wait for some time
	call	delay
	movw	r25:r24, yh:yl
	ldd	r22, Y+rf24_ackpayloads		; Are Payloads Acknowledged
	cpse	r22, zero
	rcall	nrf24_flush_tx			; Then flush transceiver FIFO
	ldd	r22, Y+rf24_configregister
	cbr	r22, (1<<PRIM_RX)		; Disable receiver in Config Reg
	std	Y+rf24_configregister, r22
	ldi	r24, NRF_CONFIG
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register		; Write to Chip
	ldi	r24, EN_RXADDR			; Get receiver enable status
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	sbr	r24, (1<<ERX_P0)		; Enable Pipe0 receiver
	ldi	r22, EN_RXADDR
	std	Y+rf24_register, r22
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_enableDynamicPayloads:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, FEATURE
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	ori	r24, (1<<EN_DPL)
	ldi	r25, FEATURE
	std	Y+rf24_register, r25
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, DYNPD
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	ori	r24, (1<<DPL_P0) | (1<<DPL_P1) | (1<<DPL_P2) | (1<<DPL_P3) | (1<<DPL_P4) | (1<<DPL_P5)
	ldi	r25, DYNPD
	std	Y+rf24_register, r25
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, 1
	std	Y+rf24_dynamicpayloads, r24
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_getDynamicPayloadSize:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	_begin	r24
	ldi	r24, R_RX_PL_WID
	_spi	r24
	std	Y+rf24_status, r24	; Always save returned status from command
	ldi	r24, 0xFF
	_spi	r24
	_end	r25
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_isPVariant:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r24, Y+rf24_variant
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_enableAckPayload:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r24, Y+rf24_ackpayloads
	cpi	r24, 0
	breq	nrf24_enableAckPayload090
	ldi	r24, FEATURE
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	ori	r24, (1<<EN_DPL) | (1<<EN_ACK_PAY)
	ldi	r25, FEATURE
	std	Y+rf24_register, r25
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, DYNPD
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	ori	r24, (1<<DPL_P0) | (1<<DPL_P1) | (1<<DPL_P2) | (1<<DPL_P3) | (1<<DPL_P4) | (1<<DPL_P5)
	ldi	r25, DYNPD
	std	Y+rf24_register, r25
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, 1
	std	Y+rf24_dynamicpayloads, r24
	std	Y+rf24_ackpayloads, r24
nrf24_enableAckPayload090:
	pop	yh
	pop	yl
	ret
	
nrf24_disableAckPayload:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r24, Y+rf24_ackpayloads
	tst	r24
	breq	nrf24_disableAckPayload010
	ldi	r24, FEATURE
	std	Y+rf24_register, r24
	movw	yh:yl, r25:r24
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	cbr	r24, (1<<EN_ACK_PAY)
	std	Y+rf24_regvalue, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
nrf24_disableAckPayload010:
	pop	yh
	pop	yl
	ret
	
;-----------------------------------------------------------------------------
;
;
;
nrf24_openWritingPipe:;(struct nrf24 *nrf24[r25:r24], const uint8_t* address[r23:r22])
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	movw	xh:xl, r23:r22
	ldd	r18, Y+rf24_addresswidth
	_begin	r24
	ldi	r24, W_REGISTER | RX_ADDR_P0
	_spi	r24
nrf24_openWritingPipe010:
	ld	r24, X+
	_spi	r24
	dec	r18
	brne	nrf24_openWritingPipe010
	_end	r24

	movw	xh:xl, r23:r22
	ldd	r18, Y+rf24_addresswidth
	_begin	r24
	ldi	r24, W_REGISTER | TX_ADDR
	_spi	r24
nrf24_openWritingPipe020:
	ld	r24, X+
	_spi	r24
	dec	r18
	brne	nrf24_openWritingPipe020
	_end	r24
	pop	yh
	pop	yl
	ret
	
nrf24_readTXAddr:;(struct nrf24 *nrf24[r25:r24], uint8_t* buffer[r23:r22])
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	movw	xh:xl, r23:r22
	ldd	r18, Y+rf24_addresswidth
	_begin	r24
	ldi	r24, R_REGISTER | TX_ADDR
	_spi	r24
nrf24_readTXAddr010:
	_spi	r24
	st	X+, r24
	dec	r18
	brne	nrf24_readTXAddr010
	_end	R24
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_openReadingPipe:;(struct nrf24 *nrf24, uint8_t child, const uint8_t* address)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	cpi	r22, 0
	brne	nrf24_openReadingPipe020
	ldd	r18, Y+rf24_addresswidth	; In case of Pipe0 we save the
	movw	xh:xl, r21:r20			; the address to the instance
	movw	zh:zl, yh:yl
	adiw	zh:zl, rf24_pipe0
nrf24_openReadingPipe010:
	ld	r19, X+
	st	Z+, r19
	dec	r18
	brne	nrf24_openReadingPipe010
	ldi	r18, 1
	std	Y+rf24_pipe0open, r18		; Mark Pipe0 is open
nrf24_openReadingPipe020:
	movw	xh:xl, r21:r20			; Get address of buffer to index register
	ldi	r18, (1<<ERX_P0)		; Assume RX Pipe 0
	ldi	r19, W_REGISTER | RX_ADDR_P0	;
	cpi	r22, 0
	breq	nrf24_openReadingPipe030	; 3..5 byte address
	ldi	r18, (1<<ERX_P1)
	ldi	r19, W_REGISTER | RX_ADDR_P1	; Assume RX Pipe 1
	cpi	r22, 1
	breq	nrf24_openReadingPipe030	; 3..5 byte address
	ldi	r18, (1<<ERX_P2)		; Assume RX Pipe 2
	ldi	r19, W_REGISTER | RX_ADDR_P2	;
	cpi	r22, 2
	breq	nrf24_openReadingPipe050	; Only one byte
	ldi	r18, (1<<ERX_P3)		; Assume RX Pipe 3
	ldi	r19, W_REGISTER | RX_ADDR_P3	;
	cpi	r22, 3
	breq	nrf24_openReadingPipe050	; Only one byte
	ldi	r18, (1<<ERX_P4)		; Assume RX Pipe 4
	ldi	r19, W_REGISTER | RX_ADDR_P4	;
	cpi	r22, 4
	breq	nrf24_openReadingPipe050	; Only one byte
	ldi	r18, (1<<ERX_P5)		; Assume RX Pipe 5
	ldi	r19, W_REGISTER | RX_ADDR_P5	;
	cpi	r22, 5
	breq	nrf24_openReadingPipe050	; Only one byte
	rjmp	nrf24_openReadingPipe090	; do nothing
;
;	Open Pipe 0 or 1 -> write a complete address as defined in nrf24addresswidth
;
nrf24_openReadingPipe030:
	_begin	r22
	ldd	r22, Y+rf24_addresswidth
	_spi	r19				; Write Address Register P0/P1
nrf24_openReadingPipe040:
	ld	r19, X+
	_spi	r19
	dec	r22
	brne	nrf24_openReadingPipe040
	_end	r19
	rjmp	nrf24_openReadingPipe090
;
;	Open Pipe 2,3,4 or 5 only write MSB of address
;
nrf24_openReadingPipe050:
	_begin	r20
	_spi	r19				; Write Address Register P2..5
	ld	r19, X+
	_spi	r19
	_end	r19
	rjmp	nrf24_openReadingPipe090
;
nrf24_openReadingPipe090:
	ldi	r24, EN_RXADDR
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register		; Preserves register r18!
	ldd	r22, Y+rf24_regvalue
	or	r22, r18
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_closeReadingPipe:;(struct nrf24 *nrf24, uint8_t child)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, EN_RXADDR
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	cpi	r22, 0
	brne	nrf24_closeReadingPipe010
	cbr	r24, (1<<ERX_P0)		; Clear Pipe 0 Enable
	std	Y+rf24_pipe0open, zero		; Remember Pipe 0 closed
	rjmp	nrf24_closeReadingPipe070
nrf24_closeReadingPipe010:
	cpi	r22, 1
	brne	nrf24_closeReadingPipe020
	cbr	r24, (1<<ERX_P1)		; Clear Pipe 1 Enable
	rjmp	nrf24_closeReadingPipe070
nrf24_closeReadingPipe020:
	cpi	r22, 2
	brne	nrf24_closeReadingPipe030
	cbr	r24, (1<<ERX_P2)
	rjmp	nrf24_closeReadingPipe070
nrf24_closeReadingPipe030:
	cpi	r22, 3
	brne	nrf24_closeReadingPipe040
	cbr	r24, (1<<ERX_P3)
	rjmp	nrf24_closeReadingPipe070
nrf24_closeReadingPipe040:
	cpi	r22, 4
	brne	nrf24_closeReadingPipe050
	cbr	r24, (1<<ERX_P4)
	rjmp	nrf24_closeReadingPipe070
nrf24_closeReadingPipe050:
	cpi	r22, 5
	brne	nrf24_closeReadingPipe060
	cbr	r24, (1<<ERX_P5)
	rjmp	nrf24_closeReadingPipe070
nrf24_closeReadingPipe060:
	rjmp	nrf24_closeReadingPipe090
nrf24_closeReadingPipe070:
	std	Y+rf24_regvalue, r24
	ldi	r24, EN_RXADDR
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
nrf24_closeReadingPipe090:
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_readRXAddresses:;(struct nrf24 *nrf24, uint8_t* buffer)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	movw	xh:xl, r23:r22
	_begin	r24
	ldi	r24, RX_ADDR_P0
	_spi	r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_end	r24	
	_begin	r24
	ldi	r24, RX_ADDR_P1
	_spi	r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_spi	r24
	st	X+, r24
	_end	r24	
	_begin	r24
	ldi	r24, RX_ADDR_P2
	_spi	r24
	_spi	r24
	st	X+, r24
	_end	r24	
	_begin	r24
	ldi	r24, RX_ADDR_P3
	_spi	r24
	_spi	r24
	st	X+, r24
	_end	r24	
	_begin	r24
	ldi	r24, RX_ADDR_P4
	_spi	r24
	_spi	r24
	st	X+, r24
	_end	r24	
	_begin	r24
	ldi	r24, RX_ADDR_P5
	_spi	r24
	_spi	r24
	st	X+, r24
	_end	r24
	pop	yh
	pop	yl	
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_readRXPLWidths:;(struct nrf24 *nrf24, uint8_t *buffer)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	movw	xh:xl, r23:r22
	ldi	r24, RX_PW_P0
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	st	X+, r24
	ldi	r24, RX_PW_P1
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	st	X+, r24
	ldi	r24, RX_PW_P2
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	st	X+, r24
	ldi	r24, RX_PW_P3
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	st	X+, r24
	ldi	r24, RX_PW_P4
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	st	X+, r24
	ldi	r24, RX_PW_P5
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	st	X+, r24
	pop	yh
	pop	yl
	ret
	
nrf24_writeRXPLWidths:;(struct nrf24 *nrf24, uint8_t pw)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	std	Y+rf24_regvalue, r22
	ldi	r24, RX_PW_P0
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, RX_PW_P1
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, RX_PW_P2
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, RX_PW_P3
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, RX_PW_P4
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r24, RX_PW_P5
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setCRCLength:;(struct nrf24 *nrf24, rf24_crclength_e length)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r24, Y+rf24_configregister
	andi	r24, ~((1<<CRCO) | (1<<EN_CRC))	; Disable CRC
	cpi	r22, RF24_CRC_DISABLED
	breq	nrf24_setCRCLength020		; Done
	cpi	r22, RF24_CRC_8
	breq	nrf24_setCRCLength010
	cpi	r22, RF24_CRC_16
	brne	nrf24_setCRCLength030		; Invalid value
	ori	r22, ((1<<CRCO) | (1<<EN_CRC))
	rjmp	nrf24_setCRCLength020
nrf24_setCRCLength010:
	ori	r22, (1<<EN_CRC)
nrf24_setCRCLength020:
	std	Y+rf24_configregister, r22
	std	Y+rf24_regvalue, r22
	ldi	r24, NRF_CONFIG
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
nrf24_setCRCLength030:
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setAutoAck:;(struct nrf24 *nrf24, uint_8 mask)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	
	ldi	r23, EN_AA
	std	Y+rf24_register, r23
	std	Y+rf24_regvalue, r22
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
	
nrf24_getAutoAck:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r22, EN_AA
	std	Y+rf24_register, r22
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setPALevel:;(struct nrf24 *nrf24, uint8_t level, bool lnaEnable)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, RF_SETUP
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_read_register
	cpi	r22, RF24_PA_MAX+1
	brlo	nrf24_setPALevel010
	ldi	r22, RF24_PA_MAX
nrf24_setPALevel010:
	lsl	r22			; Shift one bit to the left
	ldd	r24, Y+rf24_regvalue
	cbr	r24, 2*RF24_PA_MAX
	or	r24, r22
	std	Y+rf24_regvalue, r24
	ldi	r24, RF_SETUP
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_powerUp:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r22, Y+rf24_configregister
	sbrc	r22, PWR_UP
	rjmp	nrf24_powerUp010
	sbr	r22, (1<PWR_UP)
	std	Y+rf24_configregister, r22
	ldi	r23, NRF_CONFIG
	std	Y+rf24_register, r23
	std	Y+rf24_regvalue, r22
	rcall	nrf24_write_register
	ldi	r24, low(5)
	ldi	r25, high(5)
	call	delay
nrf24_powerUp010:
	pop	yh
	pop	yl
	ret	
;-----------------------------------------------------------------------------
;
;
;
nrf24_getChannel:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r22, RF_CH
	std	Y+rf24_register, r22
	rcall	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setChannel:;(struct nrf24 *nrf24, uint8_t channel)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	cpi	r22, 126
	brlo	nrf24_setChannel010
	ldi	r22, 125
nrf24_setChannel010:
	ldi	r23, RF_CH
	std	Y+rf24_register, r23
	std	Y+rf24_regvalue, r22
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_getAddressWidth:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r24, Y+rf24_addresswidth
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setAddressWidth:;(struct nrf24 *nrf24, uint8_t width)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	cpi	r22, 6
	brlo	nrf24_setAddressWidth010
	ldi	r22, 5
	cpi	r22, 3
	brsh	nrf24_setAddressWidth010
	ldi	r22, 2
nrf24_setAddressWidth010:
	std	Y+rf24_addresswidth, r22
	subi	r22, 2
	ldi	r23, SETUP_AW
	std	Y+rf24_register, r23
	std	Y+rf24_regvalue, r22
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setPayloadSize:;(struct nrf24 *nrf24, uint8_t size)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	tst	r22
	brne	nrf24_setPayloadSize010
	ldi	r22, 1
	rjmp	nrf24_setPayLoadSize020
nrf24_setPayLoadSize010:	
	cpi	r22, 33			
	brlo	nrf24_setPayloadSize020
	ldi	r22, 32
nrf24_setPayLoadSize020:
	std	Y+rf24_payloadsize, r22
	std	Y+rf24_regvalue, r22
	ldi	r22, RX_PW_P0
	std	Y+rf24_register, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r22, RX_PW_P1
	std	Y+rf24_register, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r22, RX_PW_P2
	std	Y+rf24_register, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r22, RX_PW_P3
	std	Y+rf24_register, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r22, RX_PW_P4
	std	Y+rf24_register, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	ldi	r22, RX_PW_P5
	std	Y+rf24_register, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_setDataRate:;(struct nrf24 *nrf24, rf24_datarate_e speed)
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r23, RF_SETUP
	std	Y+rf24_register, r23
	rcall	nrf24_read_register
	ldd	r23, Y+rf24_regvalue
	andi	r23, ~((1<<RF_DR_LOW) | (1<<RF_DR_HIGH))
	cpi	r22, RF24_250KBPS
	brlo	nrf24_setDataRate010
	ori	r23, (1<<RF_DR_LOW)
	rjmp	nrf24_setDataRAte020
nrf24_setDataRate010:
	bst	r22, 0
	bld	r23, RF_DR_HIGH
nrf24_setDataRate020:
	std	Y+rf24_regvalue, r23
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret

nrf24_setRetries:;(struct nrf24 *nrf24[r25:r24], uint8_t delay[r22], uint8_t retry[r20])
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	andi	r20, 0x0F		; Retry in bits 3:0
	swap	r22
	andi	r22, 0xF0		; Put Delay to bits 7:4
	or	r22, r20		; Merge
	ldi	r24, SETUP_RETR
	std	Y+rf24_register, r24
	std	Y+rf24_regvalue, r22
	movw	r25:r24, yh:yl
	rcall	nrf24_write_register
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;
nrf24_toggle_features:;(struct nrf24 *nrf24[r25:r24])
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	ldi	r24, ACTIVATE
	_spi	r24
	std	Y+rf24_status, r24	; Always save returned status from command
	ldi	r24, 0x73
	_spi	r24
	_end	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;
;

nrf24_flush_rx:;(struct nrf24 *nrf24[r25:r24])
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	ldi	r24, FLUSH_RX
	_spi	r24
	std	Y+rf24_status, r24	; Always save returned status from command
	_end	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
	
nrf24_flush_tx:;(struct nrf24 *nrf24[r25:r24])
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	ldi	r24, FLUSH_TX
	_spi	r24
	std	Y+rf24_status, r24	; Always save returned status from command
	_end	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;	nrf24_read_register and nrf24_write_register must be rewritten to
;	use all parameters and return a value in the first case, also they
;	will be sub-routines that do not alter any register except r25 & r24.
;

;	Read Register
;
nrf24_read_register:;(struct nrf24 *nrf24[r25:r24])
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	ldd	r24, Y+rf24_register
	andi	r24, 0x1F
	ori	r24, R_REGISTER
	_spi	r24
	std	Y+rf24_status, r24	; Always save returned status from command
	ldi	r24, 0xFF
	_spi	r24
	std	Y+rf24_regvalue, r24
	_end	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
	
_nrf24_read_register:;(struct nrf24 *nrf24[r25:r24], uint8_t reg[r22])
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	andi	r25, 0x1F
	ori	r25, R_REGISTER
	_spi	r25
	std	Y+rf24_status, r25	; Always save returned status from command
	ldi	r24, 0xFF
	_spi	r24
	_end	r25
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;	This is the general purpose write register currently in use which
;	is totally stupid using variables in the instance when called
;
nrf24_write_register:;(struct nrf24 *nrf24)
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	ldd	r24, Y+rf24_register
	andi	r24, 0x1F
	ori	r24, W_REGISTER
	_spi	r24
	std	Y+rf24_status, r24	; Always save returned status from command
	ldd	r24, Y+rf24_regvalue
	_spi	r24
	_end	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret

_nrf24_write_register:;(struct nrf24 *nrf24[r25:r24], uint8_t reg[r22], uint8_t value[r20])
	push	yl
	push	yh
	push	zl
	push	zh
	movw	yh:yl, r25:r24
	_begin	r24
	mov	r25, r22
	andi	r25, 0x1F
	ori	r25, W_REGISTER
	_spi	r25
	std	Y+rf24_status, r25	; Always save returned status from command
	mov	r25, r20
	_spi	r25
	_end	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
