nrf24print:;(struct nrf24* nrf24[r25:r24])
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	call	print
			;-----------------=
	.db	CR, LF, "SPI Frequency:   = ", 0

	lds	r24, SPI0_CTRLA
	andi	r24, SPI_PRESC_gm		;
	cpi	r24, SPI_PRESC_DIV4_gc
	brne	nrf24print010
	call	print
	.db	"DIV4 ", 0
	lds	r25, SPI0_CTRLB
	rjmp	nrf24print050
nrf24print010:
	cpi	r24, SPI_PRESC_DIV16_gc
	brne	nrf24print020
	call	print
	.db	"DIV16 ", 0, 0
	lds	r25, SPI0_CTRLB
	rjmp	nrf24print050
nrf24print020:
	cpi	r24, SPI_PRESC_DIV64_gc
	brne	nrf24print030
	call	print
	.db	"DIV64 ", 0, 0
	lds	r25, SPI0_CTRLB
	rjmp	nrf24print050
nrf24print030:
	cpi	r24, SPI_PRESC_DIV128_gc
	brne	nrf24print040
	call	print
	.db	"DIV128 ", 0
	lds	r25, SPI0_CTRLB
	rjmp	nrf24print050
nrf24print040:
	call	print
	.db	"Invalid", 0
nrf24print050:
	movw	r25:r24, yh:yl
	call	nrf24_getChannel
	clr	r25
	subi	r24, low(-2400)
	sbci	r25, high(-2400)
	sts	pprint+0, r24
	sts	pprint+1, r25
	call	print
			;-----------------=
	.db	CR, LF, "Channel:         =", 0xC0, "MHz", 0, 0
	

	movw	r25:r24, yh:yl
	call	nrf24_isPVariant
	ldi	r18, ' '
	cpse	r24, zero
	ldi	r18, '+'
	sts	pprint+0, r18
	call	print
			;-----------------=
	.db	CR, LF, "Model:           = nrf24l01", 0x90, 0, 0

	ldi	r24, NRF_STATUS
	rcall	nrf24printreadreg
	sts	pprint+0, r24
	ldi	r18, '0'
	sbrc	r24, RX_DR
	inc	r18
	sts	pprint+1, r18
	ldi	r18, '0'
	sbrc	r24, TX_DS
	inc	r18
	sts	pprint+2, r18
	ldi	r18, '0'
	sbrc	r24, MAX_RT
	inc	r18
	sts	pprint+3, r18
	mov	r18, r24
	lsr	r18
	andi	r18, 0x07
	ori	r18, '0'
	sts	pprint+4, r18
	ldi	r18, '0'
	sbrc	r24, TX_FULL
	inc	r18
	sts	pprint+5, r18
	call	print
			;-----------------=
	.db	CR, LF, "Status:          = 0x", 0x80, " RX_DR=", 0x91, " TX_DS=", 0x92, " MAX_RT=", 0x93, " RX_P_NO=", 0x94, " TX_FULL=", 0x95, 0
	
	ldi	r22, low(pprint)
	ldi	r23, high(pprint)
	movw	r25:r24, yh:yl
	call	nrf24_readRXAddresses
	call	print
			;-----------------=
	.db	CR, LF, "RX_ADDR_P0, P1   = 0x", 0x80, 0x81, 0x82, 0x83, 0x84, " 0x", 0x85, 0x86, 0x87, 0x88, 0x89
	.db	CR, LF, "RX_ADDR_P2-5     = 0x", 0x8a, " 0x", 0x8b," 0x", 0x8c, " 0x", 0x8d, 0, 0

	ldi	r22, low(pprint)
	ldi	r23, high(pprint)
	movw	r25:r24, yh:yl
	call	nrf24_readRXPLWidths
	call	print
			;-----------------=
	.db	CR, LF, "RX_PW_P0-5       = 0x", 0x80, " 0x", 0x81," 0x", 0x82, " 0x", 0x83,  " 0x", 0x84,  " 0x", 0x85, 0, 0

	ldi	r22, low(pprint)
	ldi	r23, high(pprint)
	movw	r25:r24, yh:yl
	call	nrf24_readTXAddr
	call	print
			;-----------------=
	.db	CR, LF, "TX_ADDR          = 0x", 0x80, 0x81, 0x82, 0x83, 0x84, 0, 0

	movw	r25:r24, yh:yl
	call	nrf24_getAutoAck
	sts	pprint+0, r24
	call	print
			;-----------------=
	.db	CR, LF, "EN_AA            = 0x", 0x80, 0, 0

	ldi	r24, EN_RXADDR
	rcall	nrf24printreadreg
	sts	pprint+0, r24
	call	print
			;-----------------=
	.db	CR, LF, "EN_RXADDR        = 0x", 0x80, 0, 0

	ldi	r24, RF_SETUP
	rcall	nrf24printreadreg
	sts	pprint+0, r24
	call	print
			;-----------------=
	.db	CR, LF, "RF_SETUP         = 0x", 0x80, 0, 0

	ldi	r24, NRF_CONFIG
	rcall	nrf24printreadreg
	sts	pprint+0, r24
	call	print
			;-----------------=
	.db	CR, LF, "CONFIG           = 0x", 0x80, 0, 0

	ldi	r24, DYNPD
	rcall	nrf24printreadreg
	sts	pprint+0, r24
	ldi	r24, FEATURE
	rcall	nrf24printreadreg
	sts	pprint+1, r24
	call	print
			;-----------------=
	.db	CR, LF, "DYNDP/FEATURE    = 0x", 0x80, "/", 0x81, 0, 0

	ldi	r24, RF_SETUP
	rcall	nrf24printreadreg
	sbrs	r24, RF_DR_LOW
	rjmp	nrf24print060		; Not 250kbps
	call	print
			;-----------------=
	.db	CR, LF, "Data Rate        = 250kbs", 0
	rjmp	nrf24print080
nrf24print060:
	sbrs	r24, RF_DR_HIGH
	rjmp	nrf24print070
	call	print
			;-----------------=
	.db	CR, LF, "Data Rate        = 2Mbps", 0, 0
	rjmp	nrf24print080
nrf24print070:
	rjmp	nrf24print060		; Not 250kbps
	call	print
			;-----------------=
	.db	CR, LF, "Data Rate        = 1Mbps", 0, 0
nrf24print080:
	ldi	r24, NRF_CONFIG
	rcall	nrf24printreadreg
	sbrc	r24, EN_CRC
	rjmp	nrf24print090		; Not 250kbps
	call	print
			;-----------------=
	.db	CR, LF, "CRC Length       = Disabled", 0
	rjmp	nrf24print110
nrf24print090:
	sbrs	r24, CRCO
	rjmp	nrf24print100
	call	print
			;-----------------=
	.db	CR, LF, "CRC Length       = 2 bytes", 0, 0
	rjmp	nrf24print110
nrf24print100:
	call	print
			;-----------------=
	.db	CR, LF, "CRC Length       = 1 byte", 0
nrf24print110:
	ldi	r24, RF_SETUP
	rcall	nrf24printreadreg
	andi	r24, 0x06
	cpi	r24, 2*RF24_PA_MIN
	brne	nrf24print111
	call	print
			;-----------------=
	.db	CR, LF, "Power Level      = PA_Min", 0
	rjmp	nrf24print120
nrf24print111:
	cpi	r24, 2*RF24_PA_LOW
	brne	nrf24print112
	call	print
			;-----------------=
	.db	CR, LF, "Power Level      = PA_Low", 0
	rjmp	nrf24print120
nrf24print112:
	cpi	r24, 2*RF24_PA_HIGH
	brne	nrf24print113
	call	print
			;-----------------=
	.db	CR, LF, "Power Level      = PA_High", 0, 0
	rjmp	nrf24print120
nrf24print113:
	cpi	r24, 2*RF24_PA_MAX
	brne	nrf24print120
	call	print
			;-----------------=
	.db	CR, LF, "Power Level      = PA_MAX", 0
nrf24print120:
	ldi	r24, SETUP_RETR
	rcall	nrf24printreadreg
	sts	pprint+0, r24
	call	print
			;-----------------=
	.db	CR, LF, "SETUP_RTR        = 0x", 0x80, 0, 0
	
	mov	r25, r24	; ARD 7:4, ARC 3:0
	swap	r25		; ARD
	andi	r24, 0x0F	; Isolate ARC
	andi	r25, 0x0F	; Isolate ARD
	sts	pprint+0, r24
	sts	pprint+1, r25
	call	print
			;-----------------=
	.db	CR, LF, "ARC/ARD          = 0x", 0x80, "/", 0x81, 0, 0
	pop	yh
	pop	yl
	clc
	ret	
	
	
nrf24printreadreg:
	std	Y+rf24_register, r24
	movw	r25:r24, yh:yl
	call	nrf24_read_register
	ldd	r24, Y+rf24_regvalue
	ret	
	
nrf24powerlevels:
	.db	"PA_Min  "
	.db	"PA_Low  "
	.db	"PA_High "
	.db	"PA_Max  "

