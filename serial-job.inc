;--------------------------------------------------------------------------
;
;	2021-11-27	.dseg in separate files
;
;
	.dseg
tx3ring:	.byte	256
rx3ring:	.byte	256
tx3inptr:	.byte	1		; Transmitring insert pointer
tx3outptr:	.byte	1		; Transmitring remove pointer
tx3cnt:		.byte	1		; Transmitring usage counter
rx3inptr:	.byte	1		; Receivering insert pointer
rx3outptr:	.byte	1		; Receivering remove pointer
rx3cnt:		.byte	1		; Receivering usage counter
serout3:	.byte	2		; Serial Out Lock
serin3:		.byte	2		; Serial In Lock
	



recordstart	usart
record		usart, txring, 256
record		usart, rxring, 256
record		usart, txinptr, 1
record		usart, txoutptr, 1
record		usart, txcnt, 1	
record		usart, rxinptr, 1
record		usart, rxouitptr, 1
record		usart, rxcnt, 1
record		usart, txblock, 2
record		usart, rxblock, 2
recordend	usart, size


.equ	serial0 = PC
	.byte	usart_size
.equ	serial1 = PC
	.byte	usart_size
.equ	serial2 = PC
	.byte	usart_size
.equ	serial3 = PC
	.byte	usart_size
.equ	serial4 = PC
	.byte	usart_size
.equ	serial5 = PC
	.byte	usart_size
