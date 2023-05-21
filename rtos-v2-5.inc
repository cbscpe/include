;--------------------------------------------------------------------------
;
;	To debug the RT-OS we need a debug port so we can follow the 
;	RT-OS using a Logic Analyzer. Normally not activated.
;
#define	dbg_port	VPORTD_OUT	; Use the Data Port
;
;#define dbg_sysret	0
;#define dbg_sysrun	1
;#define dbg_block	2
;#define dbg_unblock	3
;#define dbg_acquire	4
;#define dbg_release	5
;#define dbg_tick	6
;#define dbg_sysnul	7
;#define dbg_suspend     0
;.equ	dbg_suspend	= 0
;#define dbg_resume      1
;#define dbg_sigqueue     0
;#define dbg_waitqueue    1
;#define dbg_iotick      2
;#define dbg_suspendflag 2
;#define dbg_resumeflag  3

#define	ioticks	1000
#define	tesout

.macro	rtdbg
	.ifdef @0
	.if @1 == 1
	sbi	dbg_port, @0
	.endif
	.if @1 == 0
	cbi	dbg_port, @0
	.endif
	.endif
.endm
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
	.macro	ack_pit_interrupt
	ldi	zl, RTC_PI_bm
	sts	RTC_PITINTFLAGS, zl
	.endmacro
;--------------------------------------------------------------------------
;
;	A minimal set of routines that allow parallel jobs on a AVR
;	microcontroller. You need to provide at least the following
;	data section
;
		.dseg
#ifdef tesout
		align	8
tesoutbuf:	.byte	256
#endif
		align	4
runjob:		.byte	2		; Initialise with 0
curjob:		.byte	2		; Initialise with 0
hibjob:		.byte	2		; Initialise with 0
ioqueue:	.byte	2		; Initialise with 0
iotime:		.byte	2		; Initialise with 0
tesoutptr:	.byte	1		; Test Output Pointer
tesoutfnc:	.byte	1		; Test Output Function Code
nguard:		.byte	1		; Null Job Stack Guard Byte
;
;	2022-01-26	The stack of the null job must be as large as all nested
;			interrupts may require. In case of two interrupt levels
;			the previous default of 19bytes was not sufficient!
;			Therefore null stack has been increased to 39bytes
;
		.byte	39		; 
		align	4		; align to nice boundary
nstack:
;
;	and of course data sections for the job control blocks (see create:)
;	and the individual stacks of each process and other resources you
;	need in your application (see other routines)

;
;	JCB	- Job Control Block
;
recordstart	jcb
record		jcb, link, 2
record		jcb, stack, 2
record		jcb, joblist, 2
record		jcb, priority, 1
record		jcb, flags, 1
	.equ	jcb__hibernate_bp = 0
	.equ	jcb__hibernate_bm = 0x01
	.equ	jcb__suspend_bp	= 1	
	.equ	jcb__suspend_bm	= 0x02
	.equ	jcb__wait_bp = 2
	.equ	jcb__wait_bm = 0x04
record		jcb, iostat, 2
record		jcb, jobname, 2
recordend	jcb, size
;
;	IOQ	- IO-Queue Control Block
;
;	The IO-Queue Control block is an 8-byte data structure that will be
;	inserted into the ioqueue if a task suspends itself. It is intended
;	for tasks that wait on a IO to finish within a certain amount of time.
;	As with block/unblock it is intended to allow an ISR to resume a
;	suspended task, in addition it can drop a byte into iostat offset
;	to inform the job about the event that caused the resume. At the
;	same time it allows a task to set a timeout. When a timeout occurs
;	the IO-Queue Control block will be removed and the job will be
;	resumed with the timeout flag set in the flags field informing
;	the job that a timeout has occurred. It is the task of the ISR
;	to check whether a timeout has occurred should the event trigger
;	the interrupt before the job can take necessary actions. Typically
;	the ISR should not resume the task anymore as a resume event will
;	be stored in the flags field to avoid deadlocks when the event
;	occurs before the job was able to suspend itself.
;
recordstart	ioq
record		ioq, link, 2	
record		ioq, timer, 2
record		ioq, queue, 2
record		ioq, iostat, 1
record		ioq, flags, 1
;
;	Flags in the ioq parameter block 
;

	.equ	ioq__resume_bp	= 2
	.equ	ioq__resume_bm	= 0x04
	.equ	ioq__suspend_bp	= 1
	.equ	ioq__suspend_bm	= 0x02
	.equ	ioq__iodone_bp	= 0
	.equ	ioq__iodone_bm	= 0x01
	
	
	.equ	ioq__record_bp	= 3
	.equ	ioq__record_bm	= 0x08
	.equ	ioq__job_bp	= 4
	.equ	ioq__job_bm	= 0x10
recordend	ioq, size
