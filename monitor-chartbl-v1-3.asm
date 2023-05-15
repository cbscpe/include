;
;	Valid command characters and action routine table
;	Note that up to verify they are part of the core
;	action routines, add your routine after the core
;	routines
;
chrtbl:
	.db		0, ' '		; Blank
	.db		0, '.'		; Range
	.db		0, ':'		; Store
	.db		0, '-'		; Subtract
	.db		0, '+'		; Add
	.db		0, '<'		; Destination
	.db		0, 0x0D		; <CR>
	.db		0, 'M'		; Move
	.db		0, 'V'		; Verify
	.db		0, 'P'		; Pattern
	.db		0, 'X'		; Hexdump
