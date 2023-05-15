;--------------------------------------------------------------------------
;
;	To debug the RT-OS we need a debug port so we can follow the 
;	RT-OS using a Logic Analyzer. Normally not activated.
;
;#define	dbg_port	VPORTD_OUT	; Use the Data Port
;
;#define dbg_sysret	0
;#define dbg_sysrun	1
;#define dbg_block	2
;#define dbg_unblock	3
;#define dbg_acquire	4
;#define dbg_release	5
;#define dbg_tick	6
;#define dbg_sysnul	7

;--------------------------------------------------------------------------
;
;	Reset the TICK timer interrupt, this depends on the MCU
;
;	AVR128DB
;
	.macro	ack_timer_interrupt
	ldi	zl, TCB_CAPT_bm
	sts	TCB0_INTFLAGS, zl
	.endmacro

;--------------------------------------------------------------------------
;
;	A minimal set of routines that allow parallel jobs on a AVR
;	microcontroller. You need to provide at least the following
;	data section
;
	.dseg
	align	4
runjob:	.byte	2		; Initialise with 0
curjob:	.byte	2		; Initialise with 0
hibjob:	.byte	2		; Initialise with 0
nguard:	.byte	1		; Null Job Stack Guard Byte
;
;	2022-01-26	The stack of the null job must be as large as all nested
;			interrupts may require. In case of two interrupt levels
;			the previous default of 19bytes was not sufficient!
;			Therefore null stack has been increased to 39bytes
;
	.byte	39		; Stack of the Null Job
nstack:
;
;	and of course data sections for the job control blocks (see create:)
;	and the individual stacks of each process and other resources you
;	need in your application (see other routines)


recordstart	jcb
record		jcb, link, 2
record		jcb, stack, 2
record		jcb, joblist, 2
record		jcb, priority, 1
record		jcb, flags, 1
	.equ	jcb__hibernate_bp = 0
	.equ	jcb__suspend_bp	= 1	
recordend	jcb, size

