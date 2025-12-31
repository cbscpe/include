;--------------------------------------------------------------------------
;
;	Print routine area and return status area. Note that print has one
;	16 byte area that it can print. We put the return status area into
;	the 16 byte area so we do not need to move data around.
;
pprint:		.byte	16

