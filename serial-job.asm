	.cseg
;=============================================================================
;
;	The goal is to have one function for serial input and output and
;	dispatch according to the LUNs we have attached to the job control
;	block.
;
;	
;
serout:
	push	zl			; 
	push	zh			; 
	sbis    GPR_GPR0, serout__drv	; Is driver active
	rjmp    serout010		; No so use normal polled IO on default USART
	lds	zl, runjob+0
	lds	zh, runjob+1		; Get our job control block
	ldd	zl, Z+jcb_size
	andi	zl, 0x07
	clr	zh
	subi	zl, low(-serouttab)
	sbci	zh, high(-serouttab)
	ijmp
serouttab:
	rjmp	serout_0wait
	rjmp	serout_1wait
	rjmp	serout_2wait
	rjmp	serout_3wait
	rjmp	serout_4wait
	rjmp	serout_5wait
	nop
	nop
	
serout010:
        lds     zl, USART3_STATUS
        sbrs    zl, USART_DREIF_bp
        rjmp    serout010
        sts     USART3_TXDATAL, r24
	pop	zh
	pop	zl
	ret
;--------------------------------------------------------------------------
;
;
;
serin:
	sbis    GPR_GPR0, serin__drv	; Is driver active
	rjmp    serin010		; No so use normal polled IO on default USART
	lds	zl, runjob+0
	lds	zh, runjob+1		; Get our job control block
	ldd	zl, Z+jcb_size
	andi	zl, 0x07
	clr	zh
	subi	zl, low(-serintab)
	sbci	zh, high(-serintab)
	ijmp
serintab:
	rjmp	serout_0wait
	rjmp	serout_1wait
	rjmp	serout_2wait
	rjmp	serout_3wait
	rjmp	serout_4wait
	rjmp	serout_5wait
	nop
	nop
serin010:				; Else proceed with polled IO
        lds     r24, USART3_STATUS
        sbrs    r24, USART_RXCIF_bp
        rjmp    serin100
        lds     r24, USART3_RXDATAL
        pop	zh
        pop	zl
        ret

;--------------------------------------------------------------------------
;
;	Interrupt driven serial input and output routines with a transmit and
;	a receive ring buffer. The ring buffers one page of 256bytes long
;	so pointers and counters are just 8 bits long. Each ring buffer has 
;	three variables associated.
;	An insert pointer, a remove pointer and a count. If count is zero the
;	ring buffer is empty, if count is 0xFF the ring buffer is full.
;	The transmitter uses the data register empty interrupt which is more
;	suitable for this scenario. In this way the serout routine only waits
;	for the transmit ring buffer not being full, then inserts the byte
;	increments the count and insert pointer and then activates the data
;	register empty interrupt.
;
;	Interrupt routines must not make any system calls, if an interrupt
;	has to make a system call it must push the registers zh and zl onto
;	the stack (first zh then zl), restore any previously changed status
;	register to the pre interrupt state, load the address of the user interrupt 
;	service routine into zh:zl and jmp to the intdis (interrupt dispatcher)
;	The interrupt dispatcher will then call the user interrupt service
;	routine which is allowed to make system calls like unblock.
;
;	Interrupt routines may end with a jump to unblocki with the stack
;	set up as follows
; SP--->
;	.byte	1	; zl
;	.byte	1	; zh
;	.byte	1	; R8
;	.byte	1	; pch	
;	.byte	1	; pcl
;
;	R8 contains the saved SREG value and Z pointing to the lock word
;
;	2021-11-27	Activate ABI
;--------------------------------------------------------------------------

;
;	Data Register Empty Interrupt, i.e. another character may be sent to USART
;
;dre3_isr:
.macro	dre
.equ dre##@0##_isr = PC				;;;
	push	r8
	in	r8, CPU_SREG			;;; Save status  
	push	zh				;;; Save registers
	push	zl				;;; 
	push	yh
	push	yl
	lds	zl, serial##0##+usart_txcnt	;;; Get number of characeters in ring buffer
	dec	zl				;;; 
	sts	serial##0##+usart_txcnt, zl	;;; 
	brne	dre##@0##_isr_next		;;; There are still more
	cli
	lds	zl, USART##@0##_CTRLA		;;; If this is the last character in the ring
	cbr	zl, USART_DREIE_bm		;;; we clear the data register empty interrutp
	sts	USART##@0##_CTRLA, zl		;;; 
	sei
dre##@0##_isr_next:				;;; 

	lds	zl, serial##0##+usart_txoutptr	;;; Note that we only get DRE interrupts
	inc	zl				;;; if there is at least one characeters in the
	sts	serial##0##+usart_txoutptr, zl	;;; transmit ring buffer
	clr	zh				;;;
	subi	zl, low(-tx##@0##ring)		;;;
	sbci	zh, high(-tx##@0##ring)		;;; calculate address of character to send 
	ld	yl, Z				;;; get character
	sts	USART##@0##_TXDATAL, yl		;;; send character
	ldi	zl, low(serial##0##+usart_txblock)
	ldi	zh, high(serial##0##+usart_txblock)
	jmp	unblocki			;;; Unblock waiting job and sysret
.endmacro
	dre	3
;--------------------------------------------------------------------------
;
;
;
serout_3:
	push	zl
	push	zh
.macro	xmit
.equ serout_##@0##wait = PC
	cli
	lds	zl, serial##0##+usart_txcnt	;;; Get number of characters in buffer
	inc	zl				;;; We want to add a character
	brne	serout_##@0##nowait		;;; Not full, so we will not wait
	sei					;;; -> 6 cycles ~0.19usec
	push	r25				;
	push	r24				;
	ldi	r24, low(serial##0##+usart_txblock)	;
	ldi	r25, high(serial##0##+usart_txblock)	;
	call	block				;
	pop	r24				;
	pop	r25				;
	rjmp	serout_##@0##wait		; Then wait until there is room
;
serout_##@0##nowait:				;;;
	sts	serial##0##+usart_txcnt, zl	;;; There is space in ring buffer
	lds	zl, serial##0##+usart_txinptr	;;; Get input pointer
	inc	zl				;;;
	sts	serial##0##+usart_txinptr, zl	;;; Update input pointer
	clr	zh				;;;
	subi	zl, low(-tx##@0##ring)		;;;
	sbci	zh, high(-tx##@0##ring)		;;;
	st	Z, r24				;;;
	lds	zl, USART##@0##_CTRLA		;;; Activate the data register empty
	sbr	zl, USART_DREIE_bm		;;; interrupt so the ISR picks up the
	sts	USART##@0##_CTRLA, zl		;;; queued character(s)
	sei					;;; -> 25 cycles ~0.78usec
	pop	zh				;
	pop	zl				;
	ret
.endmacro
	xmit	3
;--------------------------------------------------------------------------
;
;	Receive Complete Interrupt
;
macro	rxc
.equ rxc##@0##_isr = PC
	push	r8				;;;
	in	r8, CPU_SREG			;;; Save status 
	push	zh				;;; Save Registers used
	push	zl				;;;
	push	yh
	push	yl
	lds	yl, USART##@0##_RXDATAL		;;; Retrieve the character
	lds	zl, serial##0##+usart_rxcnt	;;; Check the received character count
	inc	zl				;;; Add a character
	breq	rxc##@0##_overflow		;;; Buffer full so ignore it
	sts	serial##0##+usart_rxcnt, zl	;;; one more
	lds	zl, serial##0##+usart_rxinptr	;;; get index into ring buffer
	inc	zl				;;; update index
	sts	serial##0##+usart_rxinptr, zl	;;;
	clr	zh				;;; make it 16-bit offset
	subi	zl, low(-rx##@0##ring)		;;; add buffer start
	sbci	zh, high(-rx##@0##ring)		;;;
	st	Z, yl				;;; save characters
rxc##@0##_overflow:
	ldi	zl, low(serial##0##+usart_rxblock)
	ldi	zh, high(serial##0##+usart_rxblock)
	jmp	unblocki			;;; Unblock waiting job and sysret
.endmacro
	rxc	3

;--------------------------------------------------------------------------
;
;	The task dispatcher is currently linked to the serin routine. 
;
serin_3:
	push	zl				; Save registers
	push	zh
.macro	rcv
.equ serin_##@0##wait = PC
	cli					; block interrupts
	lds	zl, serial##0##+usart_rxcnt	;;; check number of characters in rx input
	tst	zl				;;; ring buffer
	brne	serin_##@0##nowait		;;; we have one
	
	sei					;;; -> 6 cycles ~0.19usec
	push	r25				;
	push	r24				;
	ldi	r24, low(serial##0##+usart_rxblock)	; else wait for input
	ldi	r25, high(serial##0##+usart_rxblock)	;
	call	block				;
	pop	r24				;
	pop	r25				;
	rjmp	serin_##@0##wait		; retry

serin_##@0##nowait:				;;;
	lds	zl, serial##0##+usart_rxcnt	;;; get count
	dec	zl				;;; and remove one character
	sts	serial##0##+usart_rxcnt, zl	;;; 
	lds	zl, serial##0##+usart_rxoutptr	;;; get rx ring read pointer
	inc	zl				;;;
	sts	serial##0##+usart_rxoutptr, zl	;;; we to a pre-increment now
	clr	zh				;;; make it a 16-bit offset
	subi	zl, low(-rx##@0##ring)		;;; add receive ring buffer base
	sbci	zh, high(-rx##@0##ring)		;;;
	ld	r24, Z				;;; get character
	sei					;;; -> 24 cycles ~0.75usec
	pop	zh				;
	pop	zl				;
	ret
.endmacro
	rcv	3
;--------------------------------------------------------------------------
;
;	Force redraw of line at prompt by inserting a ^R
;
;	Input:
;		none
;	Registers:
;		r24, r25, zl, zh
;
#define CTRL_R 0x12
.macro	redraw
.equ redraw_##@0## = PC
	cli
	lds	zl, serial##0##+usart_rxcnt	;;; Check the received character count
	inc	zl				;;; Add a character
	breq	redraw_##@0##v			;;; Buffer full so ignore it should not happen
	sts	serial##0##+usart_rxcnt, zl	;;; one more
	lds	zl, serial##0##+usart_rxinptr	;;; get index into ring buffer
	inc	zl				;;; update index
	sts	serial##0##+usart_rxinptr, zl	;;;
	clr	zh				;;; make it 16-bit offset
	subi	zl, low(-rx##@0##ring)		;;; add buffer start
	sbci	zh, high(-rx##@0##ring)		;;;
	ldi	r24, CTRL_R			;;; Redraw character
	st	Z, r24				;;; save characters
	sei					;;; -> 19 cycles ~0.6usec

	ldi	r24, low(serial##0##+usart_rxblock)
	ldi	r25, high(serial##0##+usart_rxblock)
	jmp	unblock				; Unblock waiting job and return

redraw_##@0##v:					;;; 6
	sei					;;; -> 7 cycles ~0.22usec
	ret	
.endm
	redraw	3
	