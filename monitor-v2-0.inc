	.dseg
mode:		.byte	1
a1l:		.byte	1
a1h:		.byte	1
a2l:		.byte	1
a2h:		.byte	1
a3l:		.byte	1
a3h:		.byte	1
a4l:		.byte	1
a4h:		.byte	1
a5l:		.byte	1
a5h:		.byte	1
a1b:		.byte	1		; 24-bit extension
a2b:		.byte	1		; 24-bit extension
a3b:		.byte	1		; 24-bit extension
a4b:		.byte	1		; 24-bit extension
a5b:		.byte	1		; 24-bit extension
bootstrap:	.byte	1
#ifndef clibuffer
clibuf:		.byte	80
#define clibuffer clibuf
#endif
#define crwidth 0x0F
