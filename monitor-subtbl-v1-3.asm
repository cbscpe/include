;
;	Valid command characters and action routine table
;	Note that up to verify they are part of the core
;	action routines, add your routine after the core
;	routines
;
subtbl:
	.equ	numchr	= subtbl-chrtbl
	.dw	monblank
	.dw	monsetmode
	.dw	monsetmode
	.dw	monsetmode
	.dw	monsetmode
	.dw	monlt
	.dw	moncr
	.dw	monmove
	.dw	monverify
	.dw	monpattern
	.dw	monhexdump
