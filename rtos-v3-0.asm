;--------------------------------------------------------------------------
;
;	A Minimal Real-Time OS for AVR microprocessor
;
;    Copyright (C) 2021	Peter Schranz
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.;
;
;
;	2021-06-09	PS	Initial version, this version has only
;				undergone minimal testing. It was
;				created just as an experiment and is
;				partially based on other examples and
;				ideas of other system monitors. It has
;				been developed and used on a Amtega1248P
;	2021-06-19	PS	No longer relies on the standard register
;				settings I was using for my projects written
;				in assembler, that is no reference or 
;				assumptions are made for registers named
;				isreg, itemp, temp, zero, one or ff.
;				unblock and block have been revised and
;				debugging features for the legacy AVR core
;				have been added, an attempt has been made
;				to include this as part of an AVR-GCC 
;				project, which requires some general 
;				changes, e,g low() is lo8() and register
;				pairs need to be replace with the even 
;				register name. At least the project builds.
;				However it still needs to be adopted to
;				use the ABI conventions.
;				New unblocki entry point for ISRs to 
;				signal an event in interrupt state has
;				been added
;	2021-07-06	PS	Add HW debugging
;				Optimize LINK
;				Optimize RELEASE
;				Rewrite unblock
;				!!!! fix major bug in RELEASE of last job
;
;	2021-07-16	PS	XMEGA core do not set the I-flag when
;				executing RETI. So when exiting from the
;				OS we need to check whether we have to 
;				execute a RET or a RETI by examining
;				CPUINT_STATUS.
;				
;				XMEGA core timer B requires to explicitely
;				acknowledge the interrupt in the ISR it is
;				not cleared when the ISR is entered 
;				!!!! don't use unsaved registers in the ISRs
;_______________________________________________________________________________________
;
;	Version 2 of RTOS
;
;	2021-08-06	PS	Use a PIN for soft interrupt to call the OS
;				this will allow to use RETI whenever we return
;				and it allows a high-level interrupt for Q-BUS
;				processing
;				Prepare for ABI for AVR processors
;
;	2021-08-08	PS	NULL job must be executed in non-interrupt
;				state therefore we need a RETI to start it
;				New OSCALL macro that wraps the software 
;				interrupt, currently it saves r25:r24 and
;				copies zh:zl to r25:r24 to make the module
;				identical to the first RTOS version to check
;				with existing main task
;				Use sbiw, adiw to replace 16-bit comparison
;				with 0 or 1.
;
;	2021-08-08	PS	Use ABI for AVR processors
;				-	Parameter is passed in register r25:r24
;				-	Clobbered registers r30, r31 aka zl, zh
;
;	2022-11-28	PS	intsave for interrupts that need to perform more
;				than one unblocking and new interrupt unblocking
;				routine 
;	2023-01-19	PS	resume, suspend, iotick
;
;	2023-02-05	PS	sigqueue, waitqueue
;
;	2023-02-05	PS	suspend timeout as second parameter in r23:r22
;
;	2023-02-06	PS	standardize return values for iotick, waitqueue
;				and suspend, jobs should not make use of internal
;				data structure
;
;	2023-02-06	PS	link now destroys xl, xh. Except when called
;				by create xl, xh was not required to be saved.
;				By letting link use xl and xh without
;				saving will reduce cycles, as in the other cases
;				when link is called xl, xh have already been
;				saved on the stack and where not required to
;				be preserved, this also saves stack
;	2023-05-30	PS	Testoutput, Address Check. In resume return
;				the iostatus only in the ioq and not in the
;				callers register as it is supsected to corrupt
;				r24, r25, randomly. Combine tick and iotick 
;				to one single routine
;
;***	2024-01-07	PS	Version 2 calling convention with changes to 
;				definitions made in Version 3 RTOS
;
;	2024-01-09	PS	Make changes to how create: generates the data
;				on the initial user stack to make sure the values
;				are correct especially the lower registers (zero)
;				R8, which was not taken from the caller before and
;				just set initial SREG to CPU_I_bm
;
;	2024-01-10	PS	Change Integration of tesout. At entry we store
;				the low byte of the JCB address into tesoutent+1,
;				the tesoute macro is just a convenient way to store
;				the values of 4 registers to tesoutent+2, 3, 4, 5,
;				when returning/exiting the OS you either call
;				sysretout or sysextout with yl set to the test
;				output ID, that is bits4..7 set to the call ID
;				using one of the chk_... definitions and bist0..3
;				to describe the actions performed by the call.
;				If bits0..3 are cleared then this means the shortest
;				possible action with no forced rescheduling. Bit3
;				should be set only for corner cases or errors.
;	2024-01-12	PS	newoscall to switch between oscall logic version 2 
;				or version 3
;				Set testoutput for block and unblock as default
;				i.e. change the meaning of tesoutblock_bp/bm
;
;	2024-01-25	PS	iotick as dedicated interrupt using RTC
;
;	2024-02-07	PS	Version 2.9
;	2024-02-07	PS	replace jcb_jobname with jcb_jobid, this is now an
;				index into a table of jobnames, the job Id of the
;				null job is zero. Are only use for the test output
;				and should be unique, the variable jobid will
;				set to the ID of the current job or zero when the
;				null job is started, tesoutent+1 will now set 
;				to the jobid and no longer to the lower byte of
;				of the jcb address
;_______________________________________________________________________________________
;
;	2024-02-13	PS	Version 3 replacing previous 3rd version
;				Supports only new calling convention
;				oscall macro now has to be at the entry of the function
;				as it no longer performs a rjmp
;				Uses jobid instead of jobname
;	2024-02-25	PS	Add new global iostat where we always copy the
;				current jcb_iostat
;	2024-04-21	PS	rename iotime to systicks and make it again
;				16-bit, add sysuptime to RTOS and let iotick
;				increment this 32-bit value
;	2025-12-21	PS	The previous interrupt routine and the way the
;				interrupt routine was processed in oscall macro
;				did not work correctly. Now the oscall just
;				clears b_RTOS and starts saving registers and
;				expects all the handling of b_RTOS, f_RTOS and
;				delays to be handled by the ISR
;
;--------------------------------------------------------------------------
	.cseg
;
;	Local Macro to wrap the software interrupt. We use a software 
;	interrupt for the OS calls. This is done via a level trigger
;	PIN that we can clear in software. Once the pin is cleared it
;	takes one cycle until the ISR starts, therefore we must
;	not continue until the pin is set again. Compared to a normal
;	call this adds some overhead of approx 10 cycles per OS call.
;	Note: the AVR always executes one instruction before an interrupt
;	is honoured. This is in fact used in single step debuggers.
;
.macro	oscall
	cbi	b_RTOS			; trigger software interrupt
;oscall010:
;	sbis	b_RTOS			; check ISR has been executed
;	rjmp	oscall010		; 
	push	r8			; make shure that sbis is
	in	r8, CPU_SREG		; executed after input latched again
	push	zh			; After ret of ISR we are in Level0 IRQ state
	push	zl			; acknowledging the interrupt
	push	yh			; we need to let pass some (>1)
	push	yl			; cycles
;	sbi	f_RTOS			; Acknowledge Pin Change Interrupt
#ifdef tesout
	lds	yl, jobid		; Set current job in test output
	sts	tesoutent+1, yl
#endif
.endmacro

;--------------------------------------------------------------------------
;
;	We use a pin-change interrupt with LEVEL 0 to call the OS routines.
;	The oscall macro makes sure Z has the address of the OS routine and
;	then triggers the interrupt by clearing the PIN. This will execute
;	the ISR rtos_. First we set the PIN, save a minimal task context
;	and acknowledge the interrupt.
;	Using Level  0 as the OS state allows a Level 1 interrupt to even
;	interrupt the OS, this is for cases we need very fast response
;	like the Q-Bus Interface. We also do not need to use CLI and SEI to
;	disable interrupts as we already execute as Level 0 interrupt. And
;	we may just use reti to exit the OS.
;
rtos_:
	sbic	b_RTOS			; Is it an oscall software interrupt
	rjmp	rtos_010		; aaahhh...
	nop
	nop
	nop
	sbi	b_RTOS			; Set the interrupt bit again high
	nop
	nop
	nop
	nop
	sbi	f_RTOS			; Acknowledge Pin Change Interrupt
	ret				; stay in interrupt level0, return to caller

rtos_010:
	ldi	r16, crash_spurious	; 
	jmp	crash			; crashdump (at the moment simple crash)

	reti				; should never happen

;--------------------------------------------------------------------------
;
;	intsave	- interrupt save routine, this routine is intended for
;	interrupt service routines that need to perform multiple unblocking
;	actions and therefore cannot use unblocki. The idea is that the ISR
;	immediately calls intsave without saving any registers. The stack
;	will then look as follow
; SP--->
;	.byte	1	; address high of instuction after call intsave
;	.byte	1	; address low of instuction after call intsave
;	.byte	1	; pch
;	.byte	1	; pcl
;
intsave:
	push	zl
	push	yh
	push	yl
;
;	Now our stack looks as follows, note stack is post-decremented by 
;	the push instruction
;
; SP--->
; +1	.byte	1	; yl
; +2	.byte	1	; yh
; +3	.byte	1	; zl
; +4	.byte	1	; address high of instuction after call intsave
; +5	.byte	1	; address low of instuction after call intsave
;	.byte	1	; pch
;	.byte	1	; pcl
;
;	Next we put the return address to Z and place zh and r8 on the place
;	expected by OS exit, without changing the status register or destroying
;	registers that have not been saved on the stack, finally we fetch the
;	status register into r8.
;
	in	yl, CPU_SPL
	in	yh, CPU_SPH
	ldd	zl, Y+5		; get low address of return address to ISR
	std	Y+5, r8		; save r8 at the correct place in stack
	ldd	r8, Y+4		; get high address
	std	Y+4, zh		; save zh at the correct place in stack
	mov	zh, r8		; copy high address
	in	r8, CPU_SREG	; save status register
;
;	Here we have a stack frame as if we hav called a RT-OS function, ready
;	for sysret/sysext to return to the first job
;
; SP--->
; +1	.byte	1	; yl
; +2	.byte	1	; yh
; +3	.byte	1	; zl
; +4	.byte	1	; zh
; +5	.byte	1	; r8
;	.byte	1	; pch
;	.byte	1	; pcl
;
	ldi	yl, low(sysret)	; Prepare stack with return address to sysret
	ldi	yh, high(sysret); so the ISR just needs to executed a ret to exit.
	push	yl
	push	yh
;
;	On top of the stack we have the address to return from the OS, next we
;	have the stack as expected by sysret/sysext with registers yl, yh, zl, 
;	zh, r8 saved on stack and SREG saved in r8. This ISR may now freely use
;	registers yl, yh, zl, zh and then just execute a ret instruction to exit
;	the ISR, of course it must clear all interrupt flags 
;
; SP--->
; +1	.byte	1	; high(sysret)
; +2	.byte	1	; low(sysret)
; +3	.byte	1	; yl
; +4	.byte	1	; yh
; +5	.byte	1	; zl
; +6	.byte	1	; zh
; +7	.byte	1	; r8
; +8	.byte	1	; pch
; +9	.byte	1	; pcl
;
	ijmp			; Jump back to ISR, the ISR then only needs
				; to execute a ret instruction

;--------------------------------------------------------------------------
;
;	suspend, resume, iotick
;
;	To better support asynchronous events a new set of functions has
;	been added. First we will introduce an io queue control block
;
;	The queue control block is 8 bytes long and has the following fields
;
;	.word	1	; Link Header
;	.word	1	; Timeout value
;	.word	1	; Waiting Job
;	.byte	1	; IO Status
;	.byte	1	; Flags
;
;	Queue control blocks must be initialised with zero and is under
;	the exculsive use of a single job. 
;
;	suspend is intended to let a job wait on an external event but
;	at the same time set a time-out. The job first needs to set the
;	timeout value for how long it wants to wait for the event at the
;	maximum. For the time the value is in units of 1000 ticks. The
;	job will be removed from the runjob queue and put into the waiting
;	job field of the io queue control block. The io queue control
;	block will be inserted into the ioqueue which is then regularly
;	inspected by iotick
;
;	iotick will be called by tick and will check whether the time has
;	come to check for jobs waiting on IO and decrease their timeout
;	values. If the value decreases to a negative value the io queue
;	control block will be removed from the ioqueue and the job will
;	be placed again into the runjob queue. The ioq__timeout flag will
;	be set in the io queue control block to inform the job that the
;	io has not finished but rather a timeout has occured. 
;
;	resume is inteded to be used by interrupt service routines which
;	previously have call intsave. resume is just a subroutine and
;	allows an interrupt service routine to resume multiple tasks.
;	resume must be called with the Z register pointing to the io queue
;	control block. Resume will then go through all io queue control
;	blocks in the ioqeueue and remove it, then it will take the
;	job in the waiting job field and insert the job into the runjob
;	queue.
;
;	To avoid deadlocks there are two flags, ioq__resume and
;	ioq__suspend. The control the situation that the event occurs
;	before the job has called suspend. When a job calls suspend 
;	it will test the ioq__resume bit. If the ioq__resume bit is
;	set this means the event has already occurred. It will then
;	clear teh ioq__resume bit and immediately return. If ioq__resume
;	is not set it will set the ioq__suspend bit.
;
;	resume will likewise test the ioq_suspend bit to make sure the
;	job has already executed suspend, in this case it will clear
;	the ioq__suspend bit and proceed with resuming the job. In case
;	ioq__suspend is not set it will just set ioq_resume and return.
;
;	There is one byte, the IO status, which serves as a communication
;	field between the ISR and the job. Typically the ISR will place
;	the interrupt flag register into the field and the job will then
;	have to deduce what type of event has caused the interrupt.
;
;--------------------------------------------------------------------------
;
;	sigqueue, waitqueue
;
;	Similar to suspend and resume we will have waitqueue and sigqueue
;
;	The queue consists of a queue control block with a link word, 
;	a timer field and queue header and some flags. Initially the 
;	queue is empty. 
;
;	When a queue is empty and a job signals a record the record is
;	inserted into the queue field. Records are placed in FIFO so
;	records are always inserted at the tail. If a record is attached
;	to the queue the que__record flag will be set. 
;
;	When a queue is empty and a job waits for a record and has specified
;	a wait timer of 0 then it will only get a status code of que__timeout.
;
;	When a queue is empty and a job waits for a record and has specified
;	a wait timer of > 0 then it will be removed from the wait queue and
;	the job control block will be inserted into the queue field. The queue
;	control block will be added to the IO queue and the flag que__job
;	will be set
;
;	When a queue has records and a job waits for a record the frontmost
;	record will be removed from the queue and returned to the task. If
;	this was the last record the queue field will be zero and the flag
;	que__record will be cleared. Note that when the queue has records
;	then it cannot be in the IO queue.
;
;	When a queue has records and a job signals a record the record is
;	just added to the tail of the records in the queue field.
;
;	If a job is waiting in the queue and another job waits for a record
;	the job will not be inserted into the queue and get a status code of
;	que__busy.
;
;	If a job is waiting in the queue and another job signals a record
;	the queue control block will be removed from the IO queue, the waiting
;	job will be inserted into the run queue and the reccord will be given
;	to the waiting job and the queue control block will be cleared.
;
;	If a job is waiting and the timer expires, the queue is removed from
;	the queue, the waiting job is inserted into the run queue and will
;	get a status code of que__timeout and the queue control block will
;	be cleared.
;
;	The values signalled back to the waiting job will be done either
;	directly when the process does not involve a context switch or
;	via registers r25:r24 that are saved on the stack of the waiting
;	job. Assuming that the jcb is stored in the Y register then 
;
;		ldd	zl, Y+jcb_stack+0
;		ldd	zh, Y+jcb_stack+1
;		std	Z+25, low(recordaddress)
;		std	Z+26, high(recordaddress)
;
;	will set the return parameters. Records are memory addresses and
;	as such for all architectures the address is higher than 0x00FF
;	i.e. the high byte of the address is not zero. Therefore we will
;	signal status back in registers r25:r24 just with r25=0 and r24
;	being the status code
;
;		r24=0	timeout respectively no record of timeout was 0
;		r24=1	queue is busy, i.e. another job is already waiting
;
;	recordstart	que
;	record		que, link, 2	
;	record		que, timer, 2
;	record		que, queue, 2
;	record		que, iostat, 1
;	record		que, flags, 1
	;
	;	Flags in the que parameter block 
	;
;		.equ	que__record_bp	= 0
;		.equ	que__record_bm	= 0x01
;		.equ	que__job_bp	= 1
;		.equ	que__job_bm	= 0x02
;	recordend	que, size
;
;--------------------------------------------------------------------------
;
;	Testoutput 
;
;	r25:r24		saved to offset 2
;	r23:r22		saved to offset 4
;	r20		bits 0..3 are used as an ID 
;
#ifdef tesout
tesoutput:
	oscall
	tesoute	r24, r25, r22, r23
	mov	yl, r20			;;;
	andi	yl, 0x0F		;;; ID is only 4 bits for the moment
	ori	yl, chk_tesout
	sbic	GPR_GPR0, tesoutout_bp
	rjmp	sysext
#endif
;--------------------------------------------------------------------------
;
;	Exit system without context switch
;
sysextout:
#ifdef tesout
	sbic	GPR_GPR0, tesout_bp
	rjmp	sysextout010
	lds	zl, tesoutptr+0
	lds	zh, tesoutptr+1
	std	Z+0, yl			; ID from routine
	lds	yl, tesoutent+1
	std	Z+1, yl
	lds	yl, tesoutent+2
	std	Z+2, yl
	lds	yl, tesoutent+3
	std	Z+3, yl
	lds	yl, tesoutent+4
	std	Z+4, yl
	lds	yl, tesoutent+5
	std	Z+5, yl
	lds	yl, systicks+0
	lds	yh, systicks+1
	std	Z+6, yl
	std	Z+7, yh
;	adiw	zh:zl, 8
;	andi	zh, high(tesoutlen-1)	; First we only use 0x7000..0x77FF
;	ori	zh, high(tesoutbuf)
;	sts	tesoutptr+0, zl
;	sts	tesoutptr+1, zh
	tesoutnxtptr zl, zh
sysextout010:
#endif
sysext:	pop	yl			; unwind minimal context
	pop	yh
	pop	zl
	pop	zh
	out	CPU_SREG, r8
	pop	r8
	rtdbg	dbg_sysrun, 0		; Switch off debugging
	rtdbg	dbg_sysret, 0
	rtdbg	dbg_tick, 0
	rtdbg	dbg_iotick, 0
	rtdbg	dbg_block, 0
	rtdbg	dbg_unblock, 0
	rtdbg	dbg_release, 0
	rtdbg	dbg_acquire, 0
	rtdbg	dbg_sysnull, 0
	rtdbg	dbg_suspend, 0
	rtdbg	dbg_resume, 0
	rtdbg	dbg_waitqueue, 0
	rtdbg	dbg_sigqueue, 0
	reti
;--------------------------------------------------------------------------
;
;	Central system return, use whenver a queue has been changed
; 
;	Whenever we enter sysret then the stack looks as follows
;
; SP--->
;	.byte	1	; yl
;	.byte	1	; yh
;	.byte	1	; zl
;	.byte	1	; zh
;	.byte	1	; R8
;	.byte	1	; pch	
;	.byte	1	; pcl
;
;	R8 contains the saved SREG value
;	yl contains the TEST OUTPUT ID
;
sysretout:
#ifdef tesout
	sbic	GPR_GPR0, tesout_bp
	rjmp	sysretout010
	lds	zl, tesoutptr+0
	lds	zh, tesoutptr+1
	std	Z+0, yl			; ID from routine
	lds	yl, tesoutent+1
	std	Z+1, yl
	lds	yl, tesoutent+2
	std	Z+2, yl
	lds	yl, tesoutent+3
	std	Z+3, yl
	lds	yl, tesoutent+4
	std	Z+4, yl
	lds	yl, tesoutent+5
	std	Z+5, yl
	lds	yl, systicks+0
	lds	yh, systicks+1
	std	Z+6, yl
	std	Z+7, yh
;	adiw	zh:zl, 8
;	andi	zh, high(tesoutlen-1)	; First we only use 0x7000..0x77FF
;	ori	zh, high(tesoutbuf)
;	sts	tesoutptr+0, zl
;	sts	tesoutptr+1, zh
	tesoutnxtptr zl, zh
sysretout010:
#endif
;
;	You need to make sure that sysret is never used with both curjob and
;	runjob empty. It is the task of the various functions to use the correct
;	return from the kernel, i.e. sysext or sysret
;
sysret:
	rtdbg	dbg_sysret, 1
	lds	zl, curjob+0		;;; Z = curjob
	lds	zh, curjob+1
	lds	yl, runjob+0		;;; Y = runjob
	lds	yh, runjob+1
	cp	zl, yl
	cpc	zh, yh			;;; 
	breq	sysext			;;; job is the same, no context switch
	sbiw	zh:zl, 0
	breq	sysrun			;;; no current job to save context
	push	xh			;;; save context of current job
	push	xl			;;; 
	push	r25			;;; 
	push	r24			;;; 
	push	r23
	push	r22
	push	r21
	push	r20
	push	r19
	push	r18
	push	r17
	push	r16 
	push	r15 
	push	r14 
	push	r13 
	push	r12 
	push	r11 
	push	r10
	push	r9
	push	r8			;;; in fact SREG
	push	r7
	push	r6
	push	r5
	push	r4
	push	r3
	push	r2
	push	r1
	push	r0			;;; 
	in	r0, CPU_SPL
	in	r1, CPU_SPH
	std	Z+jcb_stack+0, r0
	std	Z+jcb_stack+1, r1	;;; Save stack pointer of current context
;--------------------------------------------------------------------------
;
;	All Register are now saved we can now load a new context
;
sysrun:	
	rtdbg	dbg_sysrun, 1
	sts	curjob+0, yl
	sts	curjob+1, yh		;;; Set next job as current job
	sbiw	yh:yl, 0		;;; Test next job
	breq	sysnul			;;; No next job to run
	ldd	r0, Y+jcb_jobid
	sts	jobid, r0
	ldd	r0, Y+jcb_iostat
	sts	iostat, r0
	ldd	r0, Y+jcb_stack+0	;;;
	ldd	r1, Y+jcb_stack+1
	out	CPU_SPL, r0
	out	CPU_SPH, r1		;;; Setup stack pointer of next context
	pop	r0			;;; restore registers of next context
	pop	r1
	pop	r2
	pop	r3
	pop	r4
	pop	r5
	pop	r6
	pop	r7
	pop	r8			;;; in fact SREG
	pop	r9
	pop	r10
	pop	r11
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	r16
	pop	r17
	pop	r18
	pop	r19
	pop	r20
	pop	r21
	pop	r22
	pop	r23
	pop	r24
	pop	r25
	pop	xl
	pop	xh
	pop	yl
	pop	yh
	pop	zl
	pop	zh			;;; 
	out	CPU_SREG, r8
	pop	r8
	rtdbg	dbg_sysrun, 0		; Switch off debugging
	rtdbg	dbg_sysret, 0
	rtdbg	dbg_iotick, 0
	rtdbg	dbg_tick, 0
	rtdbg	dbg_block, 0
	rtdbg	dbg_unblock, 0
	rtdbg	dbg_release, 0
	rtdbg	dbg_acquire, 0
	rtdbg	dbg_sysnull, 0
	rtdbg	dbg_suspend, 0
	rtdbg	dbg_resume, 0
	rtdbg	dbg_waitqueue, 0
	rtdbg	dbg_sigqueue, 0
	reti

;--------------------------------------------------------------------------
;
;	Preparing for the NULL job
;
sysnul:
	rtdbg	dbg_sysrun, 0
	rtdbg	dbg_sysret, 0
	rtdbg	dbg_iotick, 0
	rtdbg	dbg_tick, 0
	rtdbg	dbg_block, 0
	rtdbg	dbg_unblock, 0
	rtdbg	dbg_acquire, 0
	rtdbg	dbg_release, 0
	rtdbg	dbg_suspend, 0
	ldi	zl, low(nstack-1)	;;; point after the null job stack as the stack
	ldi	zh, high(nstack-1)	;;; pointer uses post decrement and pre increment
	out	CPU_SPL, zl
	out	CPU_SPH, zh
	clr	zh
	sts	jobid, zh
	sts	iostat, zh
	ldi	yl, low(nulljob)
	ldi	yh, high(nulljob)
	push	yl
	push	yh
	reti				;;; Exit Interrupt State and execute NULL job
;
;	The famous NULL job
;
nulljob:

	rjmp	nulljob			; No job scheduled, so just loop
;--------------------------------------------------------------------------
;
;	1 millisecond (depends on settings) timer interrupt service routine 
;
;
tick:
#if wdgactive==3
	wdr				; Start Closed Window
#endif
	rtdbg	dbg_tick, 1
	push	r8			;;; Save Minimal Context
	in	r8, CPU_SREG		;;; 
	push	zh			;;;
	push	zl			;;;
	push	yh			;;;
	push	yl			;;; Interrupt Save
	push	xh			;;; Save more registers
	push	xl			;;;

	ack_pit_interrupt
	lds	zl, systicks+0		;;; Increment IO Time
	lds	zh, systicks+1
	adiw	zh:zl, 1
	sts	systicks+0, zl
	sts	systicks+1, zh
	clt				;;; run queue has not been altered
;
;	Use RTC Overflow Interrupt for IO timeout
;
	ldi	yl, low(hibjob)		;
	ldi	yh, high(hibjob)
tick160:			
	ldd	zl, Y+jcb_link+0	; Get next job in hibjob queue
	ldd	zh, Y+jcb_link+1
	sbiw	zh:zl, 0
	breq	tick180			; Done
	ldd	xl, Z+jcb_joblist+0	; Get timeer which is stored in joblist
	ldd	xh, Z+jcb_joblist+1	; and decrement it by one
	sbiw	xh:xl, 1
	std	Z+jcb_joblist+0,xl
	std	Z+jcb_joblist+1,xh
	brmi	tick170			; timer expired so wake-up this job
	movw	yh:yl, zh:zl		; 
	rjmp	tick160			; test with potentially next linked job
tick170:
	ldd	xl, Z+jcb_link+0	; timer of this job has expired, so get next
	ldd	xh, Z+jcb_link+1	; job control block in hibjob queue and
	std	Y+jcb_link+0, xl	; place it to previous link head, i.e. remove
	std	Y+jcb_link+1, xh	; this job from the hibjob queue
	ldi	xl, low(runjob)		; set the queue address to which this job
	ldi	xh, high(runjob)	; control block will be queued
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh
	ldd	xl, Z+jcb_flags
	cbr	xl, jcb__hibernate_bm
	std	Z+jcb_flags, xl		;;; remove hibernate flag
	rcall	link			;;; link to runjob queue according priority
	set
	rjmp	tick160			;;; try next job in hibjob queue
tick180:
	pop	xl
	pop	xh			;;; restore additionally save registers
	rtdbg	dbg_tick, 0
	brtc	tick190			;;; runjob has not been altered fast exit
	rjmp	sysret			;;; has been altered, check for context switch
tick190:
	pop	yl			;;; return to whatever we have interrupted
	pop	yh			;;; unwind stack 
	pop	zl
	pop	zh
	out	CPU_SREG, r8		;;; restore status register
	pop	r8			
	reti				;;; retunr to interrupted job

;--------------------------------------------------------------------------
;
;	Remove IO timeout logic from 'tick' and use the RTC Overflow
;	interrupt as IO timeout check. 
;
;
iotick:
;	push	r18
;	ldi	r18, RTC_OVF_bm		; Acknowledge RTC overflow interrupt
;	sts	RTC_INTFLAGS, r18
;	sbi	i_LED3			; Toggle LED3 just during test
;	pop	r18
;	reti

	rtdbg	dbg_iotick, 1
	push	r8			;;; Save Context
	in	r8, CPU_SREG		;;; 
	push	zh			;;;
	push	zl			;;;
	push	yh			;;;
	push	yl			;;; Interrupt Save
	ack_rtc_ovf_interrupt

	lds	zl, sysuptime+0
	subi	zl, byte1(-1)
	sts	sysuptime+0, zl
	lds	zl, sysuptime+1
	sbci	zl, byte2(-1)
	sts	sysuptime+1, zl
	lds	zl, sysuptime+2
	sbci	zl, byte3(-1)
	sts	sysuptime+2, zl
	lds	zl, sysuptime+3
	sbci	zl, byte4(-1)
	sts	sysuptime+3, zl

;	sbi	i_LED3			;;; Toggle LED3 just during test
	lds	zl, ioqueue+0		;;; Get first IOQ Control Block
	lds	zh, ioqueue+1
	sbiw	zh:zl, 0
	breq	iotick050		;;; No IOQ Control Block

	push	xh			;;; Save more registers
	push	xl			;;;
	clt				;;; run queue has not been altered
	ldi	yl, low(ioqueue)	; Prepare address of "previous"
	ldi	yh, high(ioqueue)
iotick010:
	ldd	xl, Z+ioq_timer+0
	ldd	xh, Z+ioq_timer+1
	sbiw	xh:xl, 1		; decrement timer
	std	Z+ioq_timer+0, xl
	std	Z+ioq_timer+1, xh
	brpl	iotick020			; timer not expired
	push	yh			; Save link head pointer Y
	push	yl
	ldd	xl, Z+ioq_link+0	; Unlink this block from chain
	ldd	xh, Z+ioq_link+1
	std	Y+ioq_link+0, xl	; i.e. let previous point to next or null
	std	Y+ioq_link+1, xh	
	ldi	xl, ioq__timeout_bm
;	ldd	xl, Z+ioq_flags		; update io conrol block flags
;	cbr	xl, ioq__suspend_bm | ioq__job_bm
	std	Z+ioq_flags, xl		; Set timeout flag in ioq control block
	rtdbg	dbg_suspendflg, 0
	ldd	xl, Z+ioq_queue+0	; Get job control block of waiting job
	ldd	xh, Z+ioq_queue+1
	clr	yl
	std	Z+ioq_queue+0, yl	; reset the control block queue head
	std	Z+ioq_queue+1, yl
	movw	zh:zl, xh:xl		; to Z register
	ldi	xl, low(runjob)
	ldi	xh, high(runjob)
	std	Z+jcb_joblist+0, xl	; set the queue of this job to runjob
	std	Z+jcb_joblist+1, xh
	ldd	xl, Z+jcb_flags		; reset status flags
	cbr	xl, jcb__suspend_bm | jcb__wait_bm
	std	Z+jcb_flags, xl
	ldd	yl, Z+jcb_stack+0	; get the stack of the job
	ldd	yh, Z+jcb_stack+1
	ldi	xl, 0			; timeout 
	std	Y+25, xl		; set r24 of job
	std	Y+26, xl		; set r25 of job 
	rcall	link
	set
	pop	zl			; Restore link head pointer to Z
	pop	zh			; 
iotick020:
	movw	yh:yl, zh:zl		; Make this block to the previous
	ldd	zl, Y+ioq_link+0	; Get next block
	ldd	zh, Y+ioq_link+1
	sbiw	zh:zl, 0
	brne	iotick010		; Yes there is another one
;
;
;
	pop	xl
	pop	xh			;;; restore additionally save registers
	brtc	iotick050		;;; runjob has not been altered fast exit
	rjmp	sysret			;;; has been altered, check for context switch
iotick050:
	pop	yl			;;; return to whatever we have interrupted
	pop	yh			;;; unwind stack 
	pop	zl
	pop	zh
	out	CPU_SREG, r8		;;; restore status register
	pop	r8			
	rtdbg	dbg_iotick, 0
	reti				;;; retunr to interrupted job




;--------------------------------------------------------------------------
;
;	link a job into a list, jobs are queued with descending priority, at
;	any given time the highest priority job always is the first in a 
;	queue.
;
;	link is only used within the core OS and is not supposed to be used
;	by any job.
;
;	Z	-->	job control block
;
;	Destroys xl, xh
;
link:
	push	yh			; r0==Z
	push	yl			; r1==X
					; r2==Y
	push	r1			; scratch pad
	push	r0			; scratchpad

	ldd	r1, Z+jcb_priority	; j$priority(r0)

	ldd	xl, Z+jcb_joblist+0	; 
	ldd	xh, Z+jcb_joblist+1	; mov	j$job.list(r0), r1

link100:			; 100$:
	ld	yl, X+			;
	ld	yh, X+			; mov	(r1)+, r2
	sbiw	yh:yl, 0		; subtract 0 to test for 0
	breq	link110			; beq	110$
	ldd	r0, Y+jcb_priority	; j$priority(r2)
	cp	r0, r1			;
	brlo	link110			;
	movw	xh:xl, yh:yl		; mov	r2, r1
	rjmp	link100			; br	100$
	
link110:			; 110$:
	std	Z+jcb_link+0, yl
	std	Z+jcb_link+1, yh	; mov	r2, (r0)
	st	-X, zh
	st	-X, zl			; mov	r0, -(r1)
	pop	r0
	pop	r1
	pop	yl
	pop	yh
	ret	
;--------------------------------------------------------------------------
;
;	r25:r24	-->	io-queue control block
;	r23:r22	-->	timeout
;
;	There are two flags in the io-queue control block that control
;	the interlocking of events and tasks
;
;	ioq__suspend	indicates the job is suspended
;	ioq__resume	indicates the event has already occured (and called resume)
;
;	suspend first checks whether the event has already occured in 
;	which case it will clear the ioq__resume flag and just return
;	Else we remove the job from the runjob queue and insert the
;	io-queue packet into the ioqueue. We update the io-queue control
;	block and job control block with flags and values, we assume
;	the caller has set the timeout, else it might take a very long
;	time (32768 seconds = approx 9 hours). If it was left zero
;	or negative then it will timeout relatively fast (within seconds)
;
suspend:
	oscall
	tesoute	r24, r25, r22, r23
	chkaddr	r25, r24, chk_suspend
	rtdbg	dbg_suspend, 1
	movw	zh:zl, r25:r24
	ldd	yh, Z+ioq_flags
	sbrc	yh, ioq__resume_bp
	rjmp	suspend020		; Event already occurred

	std	Z+ioq_timer+0, r22
	std	Z+ioq_timer+1, r23
	or	r22, r23		; 
	breq	suspend010		; zero means no timeout
	sbr	yh, ioq__suspend_bm
	std	Z+ioq_flags, yh
	rtdbg	dbg_suspendflg, 1	; *** debugging ***
	lds	yl, ioqueue+0		; get front most queue entry or ZERO if none
	lds	yh, ioqueue+1		; 
	chkaddr	yh, yl, chk_suspend+1
	std	Z+ioq_link+0, yl	; let new record point to this entry or ZERO
	std	Z+ioq_link+1, yh
	sts	ioqueue+0, zl		; make new record to the front most queue entry
	sts	ioqueue+1, zh
	lds	yl, runjob+0		; get "us", our job control block
	lds	yh, runjob+1
	std	Z+ioq_queue+0, yl	; save it into the ioq control block
	std	Z+ioq_queue+1, yh	; 
	ldd	zl, Y+ioq_link+0	; get potential next job or ZERO if none
	ldd	zh, Y+ioq_link+1
	sts	runjob+0, zl		; set this or ZERO as first job in queue
	sts	runjob+1, zh
	ldd	zl, Y+jcb_flags		; set the suspend flag in our jcb
	sbr	zl, jcb__suspend_bm
	std	Y+jcb_flags, zl
	std	Y+jcb_joblist+0, r24	; set the jobs suspend queue address
	std	Y+jcb_joblist+1, r25
;
;	The event has not occurred, the job has been removed form the runjob queue
;	and has been queued to the io control block
;
	ldi	yl, chk_suspend+0x01	; Task has been suspended
	rjmp	sysretout		; reschedule
;
;	Event has not occurred but zero timeout was specified so immediately return 0
;
suspend010:
	clr	r24
	clr	r25			; 
	rtdbg	dbg_resumeflag, 0	; *** debugging ***
	ldi	yl, chk_suspend+0x00	; Zero timeout and event did not occur
	rjmp	sysextout		; Exit and create test output
;
;	Event has occurred, acknowledge and return the status and the io_done bit set
;
suspend020:
	mov	r25, yh			; 
	sbr	r25, ioq__iodone_bm	; Bit Mark to make sure r25 is not 0
	ldd	r24, Z+ioq_iostat	;
	cbr	yh, ioq__resume_bm	; Acknowledge event
	rtdbg	dbg_resumeflag, 0	; *** debugging ***
	std	Z+ioq_flags, yh
	ldi	yl, chk_suspend+0x02	; Event already occurred
	rjmp	sysextout		; Exit and create test output
;--------------------------------------------------------------------------
;
;	Z --->		io-queue control block
;	yl -->		io-status
;	yh -->		optional tesout information
;
;	resume a task that was suspended to wait for IO, first we make
;	sure that there is a suspended task, if not we just set the
;	resume flag to indicate the event already occurred and exit.
;	Else it will look for the io-queue control block in the ioqueue
;	and when we found it we will remove it from the queue and put
;	the suspended task into the runjob queue. Fields and flags will
;	be updated accordingly
;
resume:	tesoute	zl, zh, yl, yh
	chkaddr	zh, zl, chk_resume
	rtdbg	dbg_resume, 1		; *** debugging ***
	std	Z+ioq_iostat, yl	; Save io status in control block
	push	yh
	push	yl
	push	xh
	push	xl			
	ldd	yl, Z+ioq_flags
	sbrc	yl, ioq__suspend_bp
	rjmp	resume010		; A job is suspended
;
;	There is currently no job waiting for the event, so just set flag
;
	sbr	yl, ioq__resume_bm	; Signal event already occurred
	rtdbg	dbg_resumeflag, 1	; *** debugging ***
	std	Z+ioq_flags, yl		;
	ldi	yl, chk_resume+0x00
	rjmp	resume060		; Exit with optional test output
;
;	A job is queued to the io control block so we need to remove it from the ioqueue
;
resume010:
	ldi	yl, low(ioqueue)
	ldi	yh, high(ioqueue)
resume020:
	ldd	xl, Y+ioq_link+0	; Get next io control block in queue
	ldd	xh, Y+ioq_link+1
	sbiw	xh:xl, 0		; did we reach the end 
	breq	resume030		; must never happen
	cp	xl, zl
	cpc	xh, zh
	breq	resume040		; Found it
	movw	yh:yl, xh:xl		; try next in queue
	rjmp	resume020
;
;	This should be considered a fatal error perhpas
;
resume030:				; attempt to resume a non-suspended ioq
	ldi	yl, chk_resume+0x0A	; we should actually call the crash handler
	rjmp	resume060		;
;
;	We got the io control block
;
resume040:
	ldi	xl, ioq__iodone_bm	; set iodone flag
	std	Z+ioq_flags, xl		; 
	ldd	xl, Z+ioq_link+0	; Remove this io-queue control block
	ldd	xh, Z+ioq_link+1	; from queue, let previous point to next
	chkaddr	xh, xl, chk_resume+1
	std	Y+ioq_link+0, xl	; which might be zero in case of last
	std	Y+ioq_link+1, xh
	clr	xl
	std	Z+ioq_link+0, xl	; Clear the link header in the ioq control block
	std	Z+ioq_link+1, xl
	ldd	yl, Z+ioq_queue+0	; Get job control block
	ldd	yh, Z+ioq_queue+1
	sbiw	yh:yl, 0		; Make sure we have a job
	breq	resume050		; This should never happen
#ifdef tesout
	ldd	xl, Y+jcb_jobid
	sts	tesoutent+1, xl		; Save which job we resumed
#endif
	ldi	xl, low(runjob)
	ldi	xh, high(runjob)
	std	Y+jcb_joblist+0, xl
	std	Y+jcb_joblist+1, xh	; Set queue
	ldd	xl, Y+jcb_flags
	cbr	xl, jcb__suspend_bm
	rtdbg	dbg_suspendflg, 0			; *** debugging ***
	std	Y+jcb_flags, xl
	movw	zh:zl, yh:yl
	rcall	link
	ldi	yl, chk_resume+0x01
	rjmp	resume060
;
;	No Job found
;
resume050:
	ldi	yl, chk_resume+0x02
;
;	Create Test Output and Return to ISR
;
resume060:

#ifdef tesout
	lds	xl, tesoutptr+0
	lds	xh, tesoutptr+1
	st	X+, yl			; ID from routine
	lds	yl, tesoutent+1		; 
	st	X+, yl
	lds	yl, tesoutent+2
	st	X+, yl
	lds	yl, tesoutent+3
	st	X+, yl
	lds	yl, tesoutent+4
	st	X+, yl
	lds	yl, tesoutent+5
	st	X+, yl
	lds	yl, systicks+0
	lds	yh, systicks+1
	st	X+, yl
	st	X+, yh
	andi	xh, high(tesoutlen-1)	; 
	ori	xh, high(tesoutbuf)
	sts	tesoutptr+0, xl
	sts	tesoutptr+1, xh
#endif
	pop	xl
	pop	xh
	pop	yl
	pop	yh
	rtdbg	dbg_resume, 0		; *** debugging ***
	ret

;--------------------------------------------------------------------------
;
;	Acquires a resource. A resource is a just a word in RAM initialised
;	with 0, which means the resource is free. The first job looking for
;	a resource will set the value of the resource to 1 , which means in 
;	use. In all other cases the job will be queued to the resource and
;	the next available job will be started.
;
;	Note that the values 0 and 1 can never occur as a job control block
;	address as RAM always starts at a higher address. In fact we assume
;	that job control blocks have never an address below 0x0100.
;
;	New system call model
;
;	r24:r25	-> pointer to lock word
;
;
acquire:
	oscall
	tesoute	r24, r25, r22, r23
	rtdbg	dbg_acquire, 1
	movw	zh:zl, r25:r24		;
	ldd	yl, Z+0			; r1==Z
	ldd	yh, Z+1			; r0==Y
	sbiw	yh:yl, 0		; tst	(r1)/r0, subtract 0 to test for 0
	brne	acquire100		; bne	100$
	ldi	yl, low(1)
	ldi	yh, high(1)
	std	Z+0, yl
	std	Z+1, yh			; mov	#1, (r1)
	ldi	yl, chk_acquire+0x00
	rjmp	sysextout
;
;	Lock is in use, remove the job from the runjob
;
acquire100:				; 100$:
	push	xh
	push	xl
	lds	yl, runjob+0		; mov	runjob, r0
	lds	yh, runjob+1
	ldd	xl, Y+jcb_link+0
	ldd	xh, Y+jcb_link+1	;
	sts	runjob+0, xl
	sts	runjob+1, xh		; mov	(r0) ,runjob
	std	Y+jcb_joblist+0, zl
	std	Y+jcb_joblist+1, zh	; mov	r1, j$job.list(r0)
	ldd	xl, Z+0			; get lock status, 
	ldd	xh, Z+1			;
	sbiw	xh:xl, 1		; cmp	#1, (r1)
	brne	acquire110		; bne	110$
;
;	We are the first job waiting for the lock
;
	std	Z+0, yl			; Store the jcb to the lock
	std	Z+1, yh			; mov	r0, (r1)
	std	Y+jcb_link+0, xl	; Note xh:xl is actually zero here
	std	Y+jcb_link+1, xh	; clr	(r0)
	ldi	yl, chk_acquire+0x01
	rjmp	acquire120		; br	120$
acquire110:			; 110$:
	movw	zh:zl, yh:yl		; if we are not the first queue ourselves
	rcall	link			; jsr	pc, link
	ldi	yl, chk_acquire+0x02
acquire120:			; 120$
	pop	xl
	pop	xh
	rjmp	sysretout			; 
;--------------------------------------------------------------------------
;
;	Release does, as the name says, release a resource, only the current
;	job must release a resource and we do not check whether the current 
;	job was the job that acquired the resource. If a resource was       
;	acquired and in the meantime other jobs asked for this resource the 
;	first job will be removed from the queue and inserted into the run  
;	job queue. Also you must not release a free resource.
;
;	r24:r25	-> pointer to lock word
;
;
release:
	oscall
	tesoute	r24, r25, r22, r23
	rtdbg	dbg_release, 1
	movw	zh:zl, r25:r24		; r0==Y
	ldd	yl, Z+0			; r1==Z
	ldd	yh, Z+1			; mov	(r1), r0
	sbiw	yh:yl, 1		; cmp 	r0, #1
	brne	release100		; bne	100$
	std	Z+0, yl			; no other job acquired the lock so
	std	Z+1, yh			; clr	(r1)
	ldi	yl, chk_release+0x00	; Released lock without waiting job
	rjmp	sysextout
release100:				; 100$:	
	push	xh
	push	xl
	adiw	yh:yl, 1		; restore Y pointer
	ldd	xl, Y+jcb_link+0	; Unlink the jcb of waiting job. You must
	ldd	xh, Y+jcb_link+1	; not release an free resource, this would
	std	Z+jcb_link+0, xl	; be fatal here.
	std	Z+jcb_link+1, xh	; mov	(r0), (r1)
	set				; Assume more jobs
	sbiw	xh:xl, 0		; subtract 0 to test for 0 (last job)
	brne	release110		; bne	110$ 
	clt				; Last job
	ldi	xl, low(1)		; Even for small numbers it is better to use		
	ldi	xh, high(1)		; low() and high() to make sure it is correct!
	std	Z+0, xl			; Last waiting job gets now the resource unless
					; that job releases it, it is still in use
	std	Z+1, xh			; mov	#1, (r1)
release110:				; 110$:
	ldi	zl, low(runjob)
	ldi	zh, high(runjob)
	std	Y+jcb_joblist+0, zl
	std	Y+jcb_joblist+1, zh	; mov	#runjob, j$job.list(r0)
	movw	zh:zl, yh:yl		;
	rcall	link			; jsr	pc, link
	pop	xl
	pop	xh
	ldi	yl, chk_release+0x01	; Released lock with waiting job
	bld	yl, 1			; Indicate if more jobs are waiting
	rjmp	sysretout			; 
;--------------------------------------------------------------------------
;
;	block a job until an event occurs. If the event already occured in the 
;	past the block will have been set to 1 in this case the event will be
;	set to 0 and the job continues.
;
;
;	r24:r25	-> pointer to lock word
;

block:	
	oscall
	tesoute	r24, r25, zl, zh
	rtdbg	dbg_block, 1
	movw	zh:zl, r25:r24
	ldd	yl, Z+0
	ldd	yh, Z+1
	sbiw	Y, 1			;;; did event already occur
	brne	block010		;;; no block myself
	std	Z+0, yl			;;; acknowledge event
	std	Z+1, yh			;;; indicate it is now idle
	ldi	yl, chk_block+0x01	;;; Event already occured
	sbic	GPR_GPR0, tesoutblock_bp
	rjmp	sysext
	rjmp	sysextout
block010:
	push	xh
	push	xl
	lds	yl, runjob+0		;;; remove current job from run job
	lds	yh, runjob+1

	ldd	xl, Y+0
	ldd	xh, Y+1			;;; next job
	sts	runjob+0, xl		;;; 
	sts	runjob+1, xh		;;; will become first in runjob queue

	std	Y+jcb_joblist+0, zl	;;;
	std	Y+jcb_joblist+1, zh	;;; set the block queue address
	movw	zh:zl, yh:yl		;;; link this job to the block queue
	rcall	link			;;; place it into the linked list
	rtdbg	dbg_block, 0
	pop	xl
	pop	xh
	ldi	yl, chk_block+0x00	;;; Must wait for event
	sbic	GPR_GPR0, tesoutblock_bp
	rjmp	sysret
	rjmp	sysretout

;--------------------------------------------------------------------------
;	
;	unblock signals an external event and in case a job was waiting it
;	will remove the first job form the block queue and insert it into 
;	the run job queue.
;
;	as with the acquire/release resources a block is just a word in RAM
;	initialised with 0.
;
;	Should no job wait for the event we will bump the value for 0 to 1
;	indicating that the event has already taken place. Should a job then
;	wait for this event it will just continue after setting the event form
;	1 to 0. Note that an event that can occur multiple times never increases
;	the value more than 1
;
;	r25:r24	-> pointer to lock word
;

unblock:
	oscall
	movw	zh:zl, r25:r24
;
;	Special interrupt entry to signal an event to the rtos, the issue is that we
;	currently do not allow nested interrupts and all system routines execute a
;	reti which enables interrupts not what we expect in an interupt routine the
;	interrupt routine must execute a "jmp unblocki" to signal the event and will
;	not be called back. It must setup the stack with r8, zh, zl yh, yl on the stack
;	and SREG saved to r8. This is the only OS function that ISRs may execute.
;
;	Z 	-> pointer to lock word
;
unblocki:				;;; Entry for interrupt service routines
	tesoute	zl, zh, yl, yh
	rtdbg	dbg_unblock, 1
	ldd	yl, Z+0
	ldd	yh, Z+1			;;; Get block status
	sbiw	yh:yl, 1		;;; Has event already occured
	brne	unblock040		;;; NE means yh:yl was not 1
	pop	yl			;;; when yh:yl was 1 then the event
	pop	yh			;;; has already occured once before
	pop	zl			;;; 
	pop	zh
	out	CPU_SREG, r8
	pop	r8
	rtdbg	dbg_unblock, 0
	reti				;;; Exit without test output
unblock040:
	adiw	yh:yl, 1		;;; Restore block status
	brne	unblock060		;;; there is a job waiting
	adiw	yh:yl, 1		;;; 0->1
	std	Z+0, yl			;;; flag a pending unblock/event
	std	Z+1, yh
	ldi	yl, chk_unblock+0x00	;;; No job was waiting
	sbic	GPR_GPR0, tesoutblock_bp
	rjmp	sysext
	rjmp	sysextout
unblock060:
	push	xh
	push	xl
	ldi	xl, low(runjob)		;;; queue the job to the run queue
	ldi	xh, high(runjob)
	std	Y+jcb_joblist+0, xl
	std	Y+jcb_joblist+1, xh
	ldd	xl, Y+0
	ldd	xh, Y+1			;;; get next job in block queue
	std	Z+0, xl			;;; 
	std	Z+1, xh			;;; and set it as next in block queue
	movw	zh:zl, yh:yl		;;; set address of jcb
	rcall	link			;;; link it into the runjob queue
	rtdbg	dbg_unblock, 0
	pop	xl
	pop	xh
	ldi	yl, chk_unblock+0x01	;;; Job was waiting
	sbic	GPR_GPR0, tesoutblock_bp
	rjmp	sysret
	rjmp	sysretout
;--------------------------------------------------------------------------
;
;	r25:r24 -->	queue control block
;	r23:r22 -->	timeout
;
waitqueue:
	oscall
	tesoute	r24, r25, r22, r23
	rtdbg	dbg_waitqueue, 1	; *** debugging ***
	movw	zh:zl, r25:r24		; Z=queue control block
	ldd	yl, Z+ioq_flags
	sbrs	yl, ioq__record_bp	
	rjmp	waitqueue100		; No record queued in control block
	ldd	yl, Z+ioq_queue+0	; Get frontmost record
	ldd	yh, Z+ioq_queue+1
	ldd	r24, Y+0		; Get next to frontmost record or 0
	ldd	r25, Y+1
	std	Z+ioq_queue+0, r24	; and place it to queue as front most 
	std	Z+ioq_queue+1, r25	; now frontmost record has been removed
	sbiw	r25:r24, 0		; check if this was the last record
	brne	waitqueue010		; no there are more in the queue
	ldd	r24, Z+ioq_flags	; reset the ioq__record flag
	cbr	r24, ioq__record_bm	; to show that there are no records
	std	Z+ioq_flags, r24
waitqueue010:
	movw	r25:r24, yh:yl		; move removed record to return value
	ldi	yl, chk_waitqueue+0x01	; There was a record
	rjmp	sysextout

waitqueue100:				; no records queued
	sbrs	yl, ioq__job_bp		; is there already a job waiting?
	rjmp	waitqueue110		; nope
	ldi	r24, low(1)		; another job is already waiting so return busy
	ldi	r25, high(1)		; r25=high(1) is in fact zero!!
	ldi	yl, chk_waitqueue+0x03	; Resource was busy
	rjmp	sysextout

waitqueue110:				; no record and no job is waiting
	std	Z+ioq_timer+0, r22	; set timeout value
	std	Z+ioq_timer+1, r23	;
	or	r22, r23
	brne	waitqueue120
	clr	r24			; zero timeout and no record
	clr	r25
	ldi	yl, chk_waitqueue+0x00	; No record and zero timeout
	rjmp	sysextout

waitqueue120:
	sbr	yl, ioq__job_bm		; set job wait flag
	std	Z+ioq_flags, yl		;
	lds	yl, ioqueue+0		; get front most queue entry or ZERO if none
	lds	yh, ioqueue+1		; 
	std	Z+0, yl			; let new record point to this entry or ZERO
	std	Z+1, yh
	sts	ioqueue+0, zl		; make new record to the front most queue entry
	sts	ioqueue+1, zh
	lds	yl, runjob+0		; get "us", our job control block
	lds	yh, runjob+1
	std	Z+ioq_queue+0, yl	; save it into the ioq control block
	std	Z+ioq_queue+1, yh	; 
	std	Y+jcb_joblist+0, zl	; 
	std	Y+jcb_joblist+1, zh	;
	ldd	zl, Y+jcb_flags		; set the suspend flag in our jcb
	sbr	zl, jcb__wait_bm
	std	Y+jcb_flags, zl
	ldd	zl, Y+0			; get potential next job or ZERO if none
	ldd	zh, Y+1
	sts	runjob+0, zl		; set this or ZERO s first job in queue
	sts	runjob+1, zh
	rtdbg	dbg_waitqueue, 0	; *** debugging ***
	ldi	yl, chk_waitqueue+0x02	; There were no records
	rjmp	sysretout		; reschedule
;--------------------------------------------------------------------------
;
;	r25:r24 -->	queue control block
;	r23:r22 -->	record
;
sigqueue:
	oscall
	tesoute	r24, r25, r22, r23
	rtdbg	dbg_sigqueue, 1
	movw	zh:zl, r25:r24		; Queue Control Block
	ldd	yl, Z+ioq_flags
	sbrs	yl, ioq__job_bp
	rjmp	sigqueue100		; No job waiting
	push	xh			; Job is waiting 
	push	xl
	ldi	yl, low(ioqueue)	; First we need to find the control blcok
	ldi	yh, high(ioqueue)	; in the io queue
sigqueue020:
	ldd	xl, Y+0			; get next control block
	ldd	xh, Y+1
	sbiw	xh:xl, 0		; check if we reached the ned
	breq	sigqueue030		; must never happen
	cp	xl, zl			; compare if this is the current
	cpc	xh, zh
	breq	sigqueue040		; found it thus we will remove it
	movw	yh:yl, xh:xl		; proceed with next 
	rjmp	sigqueue020

sigqueue030:				; this must not happen as we cannot 
	pop	xl			; signal a record to a control block
	pop	xh			; with a job waiting but not in the ioqueue
	ldi	yl, chk_sigqueue+0x0A
	rjmp	sysretout

sigqueue040:				; we found our control block note X=Z=current
	clr	xl			; as we forward the record to the job there is
	std	Z+ioq_flags, xl		; no job and no record
	ldd	xl, Z+0			; Remove this io-queue control block
	ldd	xh, Z+1			; from queue, let previous point to next
	std	Y+0, xl			; which might be zero in case of last
	std	Y+1, xh	
	ldd	yl, Z+ioq_queue+0	; Get job control block
	ldd	yh, Z+ioq_queue+1
	clr	xl
	std	Z+0, xl			; Clear the link header in the que control block
	std	Z+1, xl			; is this really necessary?
	std	Z+ioq_queue+0, xl	; Make sure queue head in control block is reset
	std	Z+ioq_queue+1, xl
	ldi	xl, low(runjob)		; set the queue the job will be inserted now
	ldi	xh, high(runjob)
	std	Y+jcb_joblist+0, xl
	std	Y+jcb_joblist+1, xh	; Set queue
	ldd	xl, Y+jcb_flags
	cbr	xl, jcb__wait_bm	; Make sure the wait flag is reset
	std	Y+jcb_flags, xl
	ldd	zl, Y+jcb_stack+0	; get saved stack pointer of job
	ldd	zh, Y+jcb_stack+1
	std	Z+25, r22		; Copy record address to r25:r24 of the job
	std	Z+26, r23		; saved on the stack of this job
	movw	zh:zl, yh:yl		; job control block
	rcall	link			; Put the job into the runjob queue
	rtdbg	dbg_sigqueue, 0
	pop	xl			; no longer needed
	pop	xh
	ldi	yl, chk_sigqueue+0x01	; Job was waiting for record
	rjmp	sysretout		; reschedule
;
;
;
sigqueue100:				; There is no job waiting, we make sure the
	sbr	yl, ioq__record_bm	; record flag is set and add the record to 
	std	Z+ioq_flags, yl		; the queue
	adiw	zh:zl, ioq_queue
sigqueue110:
	ldd	yl, Z+0			; get next record
	ldd	yh, Z+1
	sbiw	yh:yl, 0		; end of queue
	breq	sigqueue120		; yes Z=last record
	movw	zh:zl, yh:yl		; 
	rjmp	sigqueue110		; try next
sigqueue120:
	std	Z+0, r22		; this is the last record so insert new
	std	Z+1, r23		; record into the link of the last record
	movw	zh:zl, r23:r22
	clr	yl
	std	Z+0, yl			; Make sure new record is marked as last
	std	Z+1, yl
	ldi	yl, chk_sigqueue+0x00	; No job was waiting for record
	rjmp	sysextout
;--------------------------------------------------------------------------
;
;	puts the current job into the hibernate job queue where it will wait
;	until the number of ticks have been passed. "tick" will decrement
;	the timer of all hibernated jobs and should the value drop below 0
;	the job will be put by "tick" from the hibernate queue to the run job
;	queue.
;
;	r24:r25	= ticks to sleep
;
delay:
	oscall
	tesoute	r24, r25, yl, yh
	lds	yl, runjob+0
	lds	yh, runjob+1		;;; Get Job
	std	Y+jcb_joblist+0, r24
	std	Y+jcb_joblist+1, r25	;;; Set Ticks (reuse joblist word in JCB)
	ldd	zl, Y+jcb_flags
	sbr	zl, jcb__hibernate_bm
	std	Y+jcb_flags, zl		;;; Set hibernate flag
	ldd	zl, Y+0
	ldd	zh, Y+1			;;; Get Next Job (or 0 if this was the last)
	sts	runjob+0, zl
	sts	runjob+1, zh		;;; Make it first in runjob
	lds	zl, hibjob+0
	lds	zh, hibjob+1
	std	Y+0, zl
	std	Y+1, zh
	sts	hibjob+0, yl
	sts	hibjob+1, yh		;;; Hibernate the job
;	tst	r25			;;; 
;	brne	delay010		;;; delays > 255 ticks create a testoutput
	rjmp	sysret
delay010:
	ldi	yl, chk_delay
	rjmp	sysretout
;--------------------------------------------------------------------------
;
;	Change the priority of the job, remove the job from the runjob
;	queue and then insert it according to new priority and reschedule.
;
;	r24	= priority
;
setpriority:
	oscall
	clr	yl
	tesoute	r24, yl, yl, yl
	push	xh
	push	xl
	lds	yl, runjob+0
	lds	yh, runjob+1
	ldd	xl, Y+0
	ldd	xh, Y+1
	sts	runjob+0, xl
	sts	runjob+1, xh		;;; Remove myself from runjob (I'm the first)
	std	Y+jcb_priority, r24	;;; Set my new priority
	ldi	xl, low(runjob)
	ldi	xh, high(runjob)
	std	Y+jcb_joblist+0, xl
	std	Y+jcb_joblist+1, xh	;;; Queue me again into the runjob queu
	ldd	zl, Y+0
	ldd	zh, Y+1
	movw	zh:zl, yh:yl
	rcall	link			;;; Link into runjob according priority
	pop	xl
	pop	xh			;;; Restore work register
	ldi	yl, chk_setpriority
	rjmp	sysretout		;;; 
;--------------------------------------------------------------------------
;
;	creates a job. you need a job control block setup with the values 
;	showed as below. 
;
;	priority is a relative value to all existing prioritys, typically you
;	use low values from 0..., 
;
;	Note the first call to create starts the mini RTOS. Further jobs must
;	be created by this first job. If you want to first create all jobs you
;	need to make sure that the first job has the highest priority because
;	whenever you create a job with a priority higher than the current job
;	the new job will be executed.
;
;	r25:r24	-->	Job Control Block (JCB)
;			.byte	2	; Parameter -> later link to next JCB
;			.byte	2	; Program start -> later job list
;			.byte	2	; Stack pointer top of stack
;			.byte	1	; Priority
;			.byte	1	; Flags	
;
;	Result
;	SP	-->	.byte	stacksize-35	the pointer saved in jcb_stack
;			.byte	r0		Y+1
;			.byte	r1		Y+2
;			.byte	r2		Y+3
;			.byte	r3		Y+4
;			.byte	r4		Y+5
;			.byte	r5		Y+6
;			.byte	r6		Y+7
;			.byte	r7		Y+8
;			.byte	sreg		Y+9
;			.byte	r9		Y+10
;			.byte	r10		Y+11
;			.byte	r11		Y+12
;			.byte	r12		Y+13
;			.byte	r13		Y+14
;			.byte	r14		Y+15
;			.byte	r15		Y+16
;			.byte	r16		Y+17
;			.byte	r17		Y+18
;			.byte	r18		Y+19
;			.byte	r19		Y+20
;			.byte	r20		Y+21
;			.byte	r21		Y+22
;			.byte	r22		Y+23
;			.byte	r23		Y+24
;			.byte	r24		Y+25
;			.byte	r25		Y+26
;			.byte	r26;xl		Y+27
;			.byte	r27;xh		Y+28
;			.byte	r28;yl		Y+29
;			.byte	r29;yh		Y+30
;			.byte	r30;zl		Y+31
;			.byte	r31;zh		Y+32	0x20
;			.byte	r8		Y+33	0x21
;			.byte	pch		Y+34	0x22	
;			.byte	pcl		Y+35	0x23
;	Top of stack:
;
;	Some remarks regarding the stack of AVR processors
;	-	To push a return address onto the stack you need to first push
;		the low-byte and then the high-byte.
;	-	ret, reti, and pop use pre-increment
;	-	rcall, call, icall and push use post-decrement
;	-	When creating a job the value in the control block must point
;		past the stack area. In assembler you first allocate space using
;		the .byte directive and put a label as reference on the next 
;		line in the source code. Or use the memory-address + stack-size
;		as the value
;	
;	The context we save is mostly a copy of the current register values, 
;	however the parameter in the JCB is copied to the save values of r25:r24 
;	and can be used as a start parameter for the job created. Typicaly a
;	16-bit pointer to a data structure for the create job, with this it is 
;	possible to run the same job with individual start parameters.
;
;	Note:	All instructions up to sbiw do not alter the status register!
;
;	r24:r25	-> pointer to job control block
;
;	We will use r24, r25 as scratchpad registers
;	
create:	
	oscall
	push	xh			; Save X pointer
	push	xl

	movw	zh:zl, r25:r24		; struct JCB*
	ldd	yl, Z+jcb_jobid
	ldd	xl, Z+jcb_stack+0
	ldd	xh, Z+jcb_stack+1	; Get user stack 
#ifdef tesout
	sts	tesoutent+1, yl		; Job ID
	sts	tesoutent+2, r24	; JCB Address
	sts	tesoutent+3, r25
	sts	tesoutent+4, xl		; Top of Stack
	sts	tesoutent+5, xh
#endif
	in	yl, CPU_SPL		; Get pointer to saved registers
	in	yh, CPU_SPH
;
;	We start using the -X addressing mode as the address required for the
;	stack should point past the top of stack
;
	ldd	r24, Z+jcb_joblist+0	; Program start 
	ldd	r25, Z+jcb_joblist+1
	st	-X, r24			; Program Counter aka Start address
	st	-X, r25			; 
;
;	On Stack we have the following registers from the caller
; SP--->
; +1	.byte	xl
; +2	.byte	xh
; +3	.byte	yl
; +4	.byte	yh
; +5	.byte	zl
; +6	.byte	zh
; +7	.byte	r8
;
	ldd	r24, Y+7		; Following the Program Counter is R8
	st	-X, r24			
	ldd	r24, Y+6		; Then followed by zh, zl, yh, yl, xh, xl
	st	-X, r24			
	ldd	r24, Y+5
	st	-X, r24			
	ldd	r24, Y+4
	st	-X, r24			
	ldd	r24, Y+3
	st	-X, r24			
	ldd	r24, Y+2
	st	-X, r24
	ldd	r24, Y+1
	st	-X, r24
;
;	New way of passing initial parameter to the created job
;
	st	-X, r23	; 'r25'		; New: the start parameter of the job
	st	-X, r22	; 'r24'		; created is passed as the second paremeter
	st	-X, r23			; so we literally duplicate the value
	st	-X, r22			; given by the caller of create
	st	-X, r21
	st	-X, r20
	st	-X, r19
	st	-X, r18
	st	-X, r17
	st	-X, r16
	st	-X, r15
	st	-X, r14
	st	-X, r13
	st	-X, r12
	st	-X, r11
	st	-X, r10
	st	-X, r9
	ldi	r24, CPU_I_bm		; I-bit on the saved SREG must be set
	st	-X, r24			; on stack on the 8th position 
	st	-X, r7
	st	-X, r6
	st	-X, r5
	st	-X, r4
	st	-X, r3
	st	-X, r2
	st	-X, r1
	st	-X, r0
	sbiw	xh:xl, 1		; stack uses post-decrement and pre-increment
	std	Z+jcb_stack+0, xl
	std	Z+jcb_stack+1, xh	; Keep fingers crossed we did it right
	clr	yl
	std	Z+jcb_flags, yl		; Initialise the flags
	std	Z+0, yl			; Initialise link head
	std	Z+1, yl
	ldi	yl, low(runjob)
	ldi	yh, high(runjob)	; Initial queue
	std	Z+jcb_joblist+0, yl
	std	Z+jcb_joblist+1, yh
	rcall	link			; Add it to the runjob queue

#ifdef tesout
	sbic	GPR_GPR0, tesout_bp
	rjmp	create010
	ldi	xl, chk_create
	lds	xh, tesoutent+1
	lds	yl, tesoutptr+0
	lds	yh, tesoutptr+1
	std	Y+0, xl			; Create
	std	Y+1, xh			; Job
	lds	xl, tesoutent+2
	lds	xh, tesoutent+3
	std	Y+2, xl
	std	Y+3, xh
	lds	xl, tesoutent+4
	lds	xh, tesoutent+5
	std	Y+4, xl
	std	Y+5, xh
	lds	xl, systicks+0
	lds	xh, systicks+1
	std	Y+6, xl
	std	Y+7, xh
;	adiw	yh:yl, 8
;	andi	yh, high(tesoutlen-1)	; 
;	ori	yh, high(tesoutbuf)
;	sts	tesoutptr+0, yl
;	sts	tesoutptr+1, yh
	tesoutnxtptr yl, yh
create010:
#endif
	pop	xh
	pop	xl
	rjmp	sysret			; Schedule the created job or return to caller
