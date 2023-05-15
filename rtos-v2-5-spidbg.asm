;
;	Assume SPI0 for Debugging and PA7 for chip select
;
;
spixyz:
	push	r18
	cbi	VPORTA_OUT, 7
;
	ldi	r18, 0
	sts	SPI0_DATA, r18
spixyz010:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz010
	lds	r18, SPI0_DATA
;	
	ldi	r18, W5500_SHAR
	sts	SPI0_DATA, r18
spixyz020:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz020
	lds	r18, SPI0_DATA
;	
	ldi	r18, 0			; Read common registers
	sts	SPI0_DATA, r18
spixyz030:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz030
	lds	r18, SPI0_DATA
;	
	sts	SPI0_DATA, xh
spixyz040:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz040
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, xl
spixyz050:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz050
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, yh
spixyz060:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz060
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, yl
spixyz070:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz070
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, Zh
spixyz080:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz080
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, zl
spixyz090:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spixyz090
	lds	r18, SPI0_DATA
;
	sbi	VPORTA_OUT, 7
	pop	r18
	ret


;
;	Assume SPI0 for Debugging and PA7 for chip select
;
;
spiyz:
	push	r18
	cbi	VPORTA_OUT, 7
;
	ldi	r18, 0
	sts	SPI0_DATA, r18
spiyz010:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz010
	lds	r18, SPI0_DATA
;	
	ldi	r18, W5500_GAR
	sts	SPI0_DATA, r18
spiyz020:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz020
	lds	r18, SPI0_DATA
;	
	ldi	r18, 0			; Read common registers
	sts	SPI0_DATA, r18
spiyz030:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz030
	lds	r18, SPI0_DATA
;	
	sts	SPI0_DATA, yh
spiyz060:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz060
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, yl
spiyz070:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz070
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, Zh
spiyz080:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz080
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, zl
spiyz090:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiyz090
	lds	r18, SPI0_DATA
;
	sbi	VPORTA_OUT, 7
	pop	r18
	ret


;
;	Assume SPI0 for Debugging and PA7 for chip select
;
;
spiryz:
	push	r18
	cbi	VPORTA_OUT, 7
;
	ldi	r18, 0
	sts	SPI0_DATA, r18
spiryz010:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz010
	lds	r18, SPI0_DATA
;	
	ldi	r18, W5500_PHAR		; PPP Destination Hardware
	sts	SPI0_DATA, r18
spiryz020:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz020
	lds	r18, SPI0_DATA
;	
	ldi	r18, 0			; Read common registers
	sts	SPI0_DATA, r18
spiryz030:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz030
	lds	r18, SPI0_DATA
;	
	sts	SPI0_DATA, r25
spiryz040:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz040
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, r24
spiryz050:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz050
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, yh
spiryz060:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz060
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, yl
spiryz070:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz070
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, Zh
spiryz080:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz080
	lds	r18, SPI0_DATA
;
	sts	SPI0_DATA, zl
spiryz090:
	lds	r18, SPI0_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	spiryz090
	lds	r18, SPI0_DATA
;
	sbi	VPORTA_OUT, 7
	pop	r18
	ret