;--------------------------------------------------------------------------
;
;	To debug the RT-OS we need a debug port so we can follow the 
;	RT-OS using a Logic Analyzer. Normally not activated.
;
;
;	2024-01-07	PS	Version 2 calling convention with changes to 
;				definitions made in Version 3 RTOS
.equ	rtosversion = '2'
.equ	rtosrevision = '8'

;#define	dbg_port	VPORTD_OUT	; Use the Data Port
;#define dbg_sysret	0
;#define dbg_sysrun	1
;#define dbg_block	2
;#define dbg_unblock	3
;#define dbg_acquire	4
;#define dbg_release	5
;#define dbg_tick	6
;#define dbg_sysnul	7
;#define dbg_suspend	0
;#define dbg_resume	1
;#define dbg_sigqueue	0
;#define dbg_waitqueue	1
;#define dbg_iotick	2
;#define dbg_suspendflag	2
;#define dbg_resumeflag	3

#define	tesout
;
;	Identification values 
;
#define chk_suspend	0x10
#define chk_acquire	0x20
#define	chk_release	0x30
#define	chk_block	0x40
#define	chk_unblock	0x50
#define	chk_delay	0x60
#define	chk_setpriority	0x70
#define	chk_waitqueue	0x80
#define	chk_sigqueue	0x90
#define	chk_create	0xA0
#define	chk_resume	0xB0
#define chk_iotick	0xC0
#define	chk_tesout	0xD0
#define chk_interrupt	0xE0
#define chk_invalid	0xF0

#define crash_maxisr	0xFA
#define crash_mem	0xFB
#define	crash_wdg	0xFC
#define crash_rtos	0xFD
#define crash_nojob	0xFE
#define	crash_spurious	0xFF
;--------------------------------------------------------------------------
;
;	Debugging and Test Output
;
.macro	rtdbg
	#ifdef dbg_port
	.ifdef @0
	.if @1 == 1
	sbi	dbg_port, @0
	.endif
	.if @1 == 0
	cbi	dbg_port, @0
	.endif
	.endif
	#endif
.endm
;
;	Check that the address is a valid RAM address else call crashdump
;
.macro	chkaddr
	#ifdef	dbg_chkaddr
	sbiw	@0:@1, 0
	breq	c020
	cpi	@0, high(INTERNAL_SRAM_START)
	brlo	c010
	cpi	@0, high(INTERNAL_SRAM_END)
	brlo	c020
c010:
	ldi	r16, @2
	call	crash
c020:
	#endif
.endm
;--------------------------------------------------------------------------
;
;	Testoutput Macros
;
;	During each call a testoutput entry is created in the buffer 
;	"tesoutent" and depending on the settings this buffer is then
;	placed into the circular testoutput buffer typically located
;	at 0x7000 in RAM
;
;	Entry Test Output Macro that sets the function code and the
;	low byte of job control block address. We assume that job
;	control blocks are defined in a contiguous block of RAM and
;	that we typically do not have more than a few jobs, so the
;	low-byte of the JCB identifies the job
;
.macro	tesoute
#ifdef	tesout
	sts	tesoutent+2, @0
	sts	tesoutent+3, @1
	sts	tesoutent+4, @2
	sts	tesoutent+5, @3
#endif
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

	.macro	ack_rtc_ovf_interrupt
	ldi	zl, RTC_OVF_bm		; Acknowledge RTC overflow interrupt
	sts	RTC_INTFLAGS, zl
	.endmacro
;--------------------------------------------------------------------------
;
;	A minimal set of routines that allow parallel jobs on a AVR
;	microcontroller. You need to provide at least the following
;	data section
;
		.dseg
		align	4
runjob:		.byte	2		; Initialise with 0
curjob:		.byte	2		; Initialise with 0
hibjob:		.byte	2		; Initialise with 0
ioqueue:	.byte	2		; Initialise with 0
iotime:		.byte	4		; Initialise with 0
tesoutptr:	.byte	2		; Test Output Pointer
cpuload:	.byte	4
tesoutent:	.byte	6		
intlevel:	.byte	1
jobid:		.byte	1
nguard:		.byte	1		; Null Job Stack Guard Byte
;
;	2022-01-26	The stack of the null job must be as large as all nested
;			interrupts may require. In case of two interrupt levels
;			the previous default of 19bytes was not sufficient!
;			Therefore null stack has been increased to 39bytes
;
		.byte	39		; minimum amount of stack for null job
		align	4		; align to nice boundary
nstack:
;
;	and of course data sections for the job control blocks (see create:)
;	and the individual stacks of each process and other resources you
;	need in your application (see other routines)

;--------------------------------------------------------------------------
;
;	JCB	- Job Control Block
;
recordstart	jcb
record		jcb, link, 2		; Link header to queue JCBs
record		jcb, stack, 2		; Saved Stack Pointer
record		jcb, joblist, 2		; Address of queue to which this JCB is queued
record		jcb, priority, 1
record		jcb, flags, 1
;
	.equ	jcb__hibernate_bp = 0		; Task is in hibjob queue [delay()]
	.equ	jcb__hibernate_bm = 0x01
	.equ	jcb__suspend_bp	= 1		; Task is suspended
	.equ	jcb__suspend_bm	= 0x02
	.equ	jcb__wait_bp = 2		; Task is waitqueued
	.equ	jcb__wait_bm = 0x04
;
record		jcb, iostat, 1			; 
record		jcb, jobid, 1			; 
record		jcb, jobname, 2			; 
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

	.equ	ioq__iodone_bp	= 0		; IO finished
	.equ	ioq__iodone_bm	= 0x01
	.equ	ioq__resume_bp	= 2		; Event already occurred
	.equ	ioq__resume_bm	= 0x04
	.equ	ioq__suspend_bp	= 1		; Job is suspended
	.equ	ioq__suspend_bm	= 0x02
	.equ	ioq__record_bp	= 3		; Waitqueue has records queued
	.equ	ioq__record_bm	= 0x08
	.equ	ioq__job_bp	= 4		; Waitqueue has job waiting
	.equ	ioq__job_bm	= 0x10
	.equ	ioq__timeout_bp	= 7
	.equ	ioq__timeout_bm = 0x80
recordend	ioq, size
