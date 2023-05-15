	.dseg

scanresult:	.byte	4
scanoptions:	.byte	1

.equ	cmd_done	= -1
.equ	kw_endtable	= 0

.equ	tp__space	= 0
.equ	tp__multiline	= 1

.macro	P_KEYWORD
.if (STRLEN(@0)&1)
.db	0x80, @0, 0x00, 0x00
.else
.db	0x80, @0, 0x00
.endif
.endmacro
;
.macro	P_KEYSUFF
.if (STRLEN(@0)&1)
.db	0x81, @0, 0x00, 0x00
.else
.db	0x81, @0, 0x00
.endif
.endmacro
;
.macro	P_STRING
.db		0x82, 0x00
.endmacro
;
.macro	P_KEYDEVICE
.if (STRLEN(@0)&1)
.db	0x83, @0, 0x00, 0x00
.else
.db	0x83, @0, 0x00
.endif
.endmacro
;
.macro	P_NAME
.db		0x84, 0x00
.endmacro
;
.macro	P_NUMBER
.db		0x85, 0x00
.endmacro
;
.macro	P_EOL
.db		0x86, 0x00
.endmacro
;
.macro	P_QSTRING
.db		0x87, 0x00
.endmacro
;
.macro	P_SUBCMD
.db		0x88, 0x00
.dw		@0
.endmacro
;
.macro	P_CHAR
.db		0x89, @0
.endmacro
;
.macro	P_ANY
.db		0x8a, 0x00
.endmacro
;
.macro	P_LAMBDA
.db		0x8b, 0x00
.endmacro
;
.macro	P_SWITCH
.db		0x8c, @0
.endmacro