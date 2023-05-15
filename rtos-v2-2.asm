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

;--------------------------------------------------------------------------
	.cseg
;
;	Local Macro to wrap the software interrupt. We use a software 
;	interrupt for the OS calls. This is done via a level trigger
;	PIN that we can clear in software. Once the pin is cleared it
;	might take some cycles until the ISR starts, therefore we must
;	not continue until the pin is set again. Compared to a normal
;	call this adds some overhead of approx 10 cycles per OS call.
;
.macro	oscall
	ldi	zl, low(@0)
	ldi	zh, high(@0)		; Set function to call
	cbi	b_RTOS			; Trigger software interrupt
	sbis	b_RTOS			; check ISR has been executed
	rjmp	PC-1			; 
	ret				; Normal return
.endmacro
;--------------------------------------------------------------------------
;
;	We use a pin-change interrupt with LEVEL 0 to call the OS routines.
;	The OSCALL macro makes sure Z has the address of the OS routine and
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
	sbis	b_RTOS			; Is it an OSCALL software interrupt
	rjmp	oscall_			; yes ->
	reti				; should never happen
	
oscall_:
	push	r8			; save minimal context
	in	r8, CPU_SREG
	sbi	b_RTOS			; important, between setting the pin and
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	sbi	f_RTOS			; Acknowledge interrupt
	ijmp	


;--------------------------------------------------------------------------
;
;	Exit system without context switch
;
sysext:	pop	yl			; unwind minimal context
	pop	yh
	pop	zl
	pop	zh
	out	CPU_SREG, r8
	pop	r8
	#ifdef dbg_sysrun
	cbi	dbg_port, dbg_sysrun
	#endif
	#ifdef dbg_sysret
	cbi	dbg_port, dbg_sysret
	#endif
	#ifdef dbg_tick
	cbi	dbg_port, dbg_tick
	#endif
	#ifdef dbg_block
	cbi	dbg_port, dbg_block
	#endif
	#ifdef dbg_unblock
	cbi	dbg_port, dbg_unblock
	#endif
	#ifdef dbg_release
	cbi	dbg_port, dbg_release
	#endif
	#ifdef dbg_acquire
	cbi	dbg_port, dbg_acquire
	#endif
	#ifdef dbg_null
	cbi	dbg_port, dbg_null
	#endif
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
;
sysret:
	#ifdef dbg_sysret
	sbi	dbg_port, dbg_sysret
	#endif
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
	#ifdef dbg_sysrun
	sbi	dbg_port, dbg_sysrun
	#endif
	sbiw	yh:yl, 0		;;; Test runjob
	breq	sysnul			;;; No next job to run
	sts	curjob+0, yl
	sts	curjob+1, yh		;;; Set next job as current job
	ldd	r0, Y+jcb_stack+0	;;;
	ldd	r1, Y+jcb_stack+1
	out	CPU_SPL, r0
	out	CPU_SPH, r1			;;; Setup stack pointer of next context
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
	#ifdef dbg_sysrun
	cbi	dbg_port, dbg_sysrun
	#endif
	#ifdef dbg_sysret
	cbi	dbg_port, dbg_sysret
	#endif
	#ifdef dbg_tick
	cbi	dbg_port, dbg_tick
	#endif
	#ifdef dbg_block
	cbi	dbg_port, dbg_block
	#endif
	#ifdef dbg_unblock
	cbi	dbg_port, dbg_unblock
	#endif
	#ifdef dbg_sysnul
	cbi	dbg_port, dbg_sysnul
	#endif
	#ifdef dbg_acquire
	cbi	dbg_port, dbg_acquire
	#endif
	#ifdef dbg_release
	cbi	dbg_port, dbg_release
	#endif
	reti

;--------------------------------------------------------------------------
;
;	Preparing for the NULL job
;
sysnul:
	#ifdef dbg_sysrun
	cbi	dbg_port, dbg_sysrun
	#endif
	#ifdef dbg_sysret
	cbi	dbg_port, dbg_sysret
	#endif
	#ifdef dbg_tick
	cbi	dbg_port, dbg_tick
	#endif
	#ifdef dbg_block
	cbi	dbg_port, dbg_block
	#endif
	#ifdef dbg_unblock
	cbi	dbg_port, dbg_unblock
	#endif
	#ifdef dbg_acquire
	cbi	dbg_port, dbg_acquire
	#endif
	#ifdef dbg_release
	cbi	dbg_port, dbg_release
	#endif
	clr	zl
	sts	curjob+0, zl		;;; no current user job
	sts	curjob+1, zl
	ldi	zl, low(nstack-1)	;;; point after the null job stack as the stack
	ldi	zh, high(nstack-1)	;;; pointer uses post decrement and pre increment
	out	CPU_SPL, zl
	out	CPU_SPH, zh
	ldi	yl, low(nulljob)
	ldi	yh, high(nulljob)
	push	yl
	push	yh
	reti				;;; Exit Interrupt State and execute NULL job
;
;	The famous NULL job
;
nulljob:
;	cli
;	#ifdef dbg_sysnul
;	sbi	dbg_port, dbg_sysnul
;	#endif
;	.ifdef SLPCTRL_CTRLA
;	ldi	r16, SLPCTRL_SMODE_IDLE_gc+SLPCTRL_SEN_bm
;	sts	SLPCTRL_CTRLA, r16
;	.endif
;	.ifdef SMCR
;	ldi	r16, (1<<SE)
;	out	SMCR, r16
;	.endif
;	sei
;	sleep
;	#ifdef dbg_sysnul
;	sbi	dbg_port, dbg_sysnul
;	#endif
	rjmp	nulljob			; No job scheduled, so just loop
;--------------------------------------------------------------------------
;
;	1 millisecond (depends on settings) timer interrupt service routine 
;
;	You need to setup a timer to create a regular intterrupt and use
;	this routine as the interrupt service routine.
;
tick:
#ifdef dbg_tick
	sbi	dbg_port, dbg_tick
#endif
	push	r8			;;; 
	in	r8, CPU_SREG		;;;
	push	zh			;;;
	push	zl			;;; Interrupt Save
	ack_timer_interrupt
	lds	zl, hibjob+0
	lds	zh, hibjob+1		;;; get job to look at
	sbiw	zh:zl, 0		;;; subtract 0 to test for 0
	brne	tick100			;;; found one
	pop	zl			;;; else do a quick exit
	pop	zh
#ifdef dbg_tick
	cbi	dbg_port, dbg_tick
#endif
	out	CPU_SREG, r8		;;; we always return from the timer interrupt
	pop	r8
	reti
tick100:
	push	yh
	push	yl
	push	xh
	push	xl
	ldi	yl, low(hibjob)
	ldi	yh, high(hibjob)
tick110:			
	ldd	xl, Z+jcb_joblist+0
	ldd	xh, Z+jcb_joblist+1
	sbiw	xh:xl, 1
	std	Z+jcb_joblist+0,xl
	std	Z+jcb_joblist+1,xh
	brpl	tick120
	ldd	xl, Z+0
	ldd	xh, Z+1
	std	Y+0, xl
	std	Y+1, xh
	ldi	xl, low(runjob)
	ldi	xh, high(runjob)
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh
	ldd	xl, Z+jcb_flags
	cbr	xl, 0x01
	std	Z+jcb_flags, xl		;;; remove hibernate flag
	rcall	link			;;; our link does not change registers
	movw	zh:zl, yh:yl
tick120:
	movw	yh:yl, zh:zl
	ldd	zl, Y+0
	ldd	zh, Y+1
	sbiw	zh:zl, 0
	brne	tick110
	pop	xl
	pop	xh
	rjmp	sysret
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
link:
	push	yh			; r0==Z
	push	yl			; r1==X
	push	xh			; r2==Y
	push	xl
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
	std	Z+0, yl
	std	Z+1, yh			; mov	r2, (r0)
	st	-X, zh
	st	-X, zl			; mov	r0, -(r1)
	pop	r0
	pop	r1
	pop	xl
	pop	xh
	pop	yl
	pop	yh
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
acquire:
	oscall	acquire_
;
acquire_:
#ifdef dbg_acquire
	sbi	dbg_port, dbg_acquire
#endif
	movw	zh:zl, r25:r24		;
	ldd	yl, Z+0			; r1==Z
	ldd	yh, Z+1			; r0==Y
	sbiw	yh:yl, 0		; tst	(r1)/r0, subtract 0 to test for 0
	brne	acquire100		; bne	100$
	ldi	yl, low(1)
	ldi	yh, high(1)
	std	Z+0, yl
	std	Z+1, yh			; mov	#1, (r1)
	pop	yl
	pop	yh
	pop	zl
	pop	zh
	out	CPU_SREG, r8
	pop	r8
#ifdef dbg_acquire
	cbi	dbg_port, dbg_acquire
#endif
	reti

acquire100:			; 100$:
	push	xh
	push	xl
	lds	yl, runjob+0		; mov	runjob, r0
	lds	yh, runjob+1
	ldd	xl, Y+0
	ldd	xh, Y+1			;
	sts	runjob+0, xl
	sts	runjob+1, xh		; mov	(r0) ,runjob
	std	Y+jcb_joblist+0, zl
	std	Y+jcb_joblist+1, zh	; mov	r1, j$job.list(r0)
	ldd	xl, Z+0
	ldd	xh, Z+1			;
	sbiw	xh:xl, 1		; cmp	#1, (r1)
	brne	acquire110		; bne	110$
	std	Z+0, yl			;
	std	Z+1, yh			; mov	r0, (r1)
	std	Y+0, xl			; Note xh:xl is actually zero here
	std	Y+1, xh			; clr	(r0)
	rjmp	acquire120		; br	120$
acquire110:			; 110$:
	movw	zh:zl, yh:yl
	rcall	link			; jsr	pc, link
acquire120:			; 120$
	pop	xl
	pop	xh
	rjmp	sysret			; 
;--------------------------------------------------------------------------
;
;	Release does as the name says release a resource, only the current job
;	can release a resource and we do not check whether the current job
;	was the job that acquired the resource. If a resource was acquired
;	and in the meantime other jobs asked for this resource the first
;	job will be removed from the queue and inserted into the run job queue.
;
;	New system call model
;
;	r24:r25	-> pointer to lock word
;
release:
	oscall	release_
;
release_:				; 
#ifdef dbg_release
	sbi	dbg_port, dbg_release
#endif
	movw	zh:zl, r25:r24		; r0==Y
	ldd	yl, Z+0			; r1==Z
	ldd	yh, Z+1			; mov	(r1), r0
	sbiw	yh:yl, 1		; cmp 	r0, #1
	brne	release100		; bne	100$
	std	Z+0, yl
	std	Z+1, yh			; clr	(r1)
	pop	yl
	pop	yh
	pop	zl
	pop	zh
#ifdef dbg_release
	cbi	dbg_port, dbg_release
#endif
	out	CPU_SREG, r8
	pop	r8
	reti

release100:			; 100$:	
	push	xh
	push	xl
	adiw	yh:yl, 1		; restore Y pointer
	ldd	xl, Y+0	
	ldd	xh, Y+1
	std	Z+0, xl
	std	Z+1, xh			; mov	(r0), (r1)
	sbiw	xh:xl, 0		; subtract 0 to test for 0
	brne	release110		; bne	110$
	ldi	xl, low(1)		; Even for small numbers it is better to use		
	ldi	xh, high(1)		; low() and high() to make sure it is correct!
	std	Z+0, xl
	std	Z+1, xh			; mov	#1, (r1)
release110:			; 110$:
	pop	xl
	pop	xh
	ldi	zl, low(runjob)
	ldi	zh, high(runjob)
	std	Y+jcb_joblist+0, zl
	std	Y+jcb_joblist+1, zh	; mov	#runjob, j$job.list(r0)
	movw	zh:zl, yh:yl		;
	rcall	link			; jsr	pc, link
	rjmp	sysret			; 

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
	oscall	block_

block_:
	#ifdef dbg_block
	sbi	dbg_port, dbg_block
	#endif
	movw	zh:zl, r25:r24
	ldd	yl, Z+0
	ldd	yh, Z+1
	sbiw	Y, 1			;;; did event already occur
	brne	block010		;;; no block myself
	std	Z+0, yl			;;; acknowledge event
	std	Z+1, yh			;;; indicate it is now idle
	pop	yl			;;; quick exit
	pop	yh
	pop	zl
	pop	zh
	out	CPU_SREG, r8
	pop	r8
	#ifdef dbg_block
	cbi	dbg_port, dbg_block
	#endif
	reti

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
	pop	xl
	pop	xh
	movw	zh:zl, yh:yl		;;; link this job to the block queue
	rcall	link			;;; place it into the linked list
	#ifdef dbg_block
	cbi	dbg_port, dbg_block
	#endif
	rjmp	sysret

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
	oscall	unblock_

unblock_:
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
	#ifdef dbg_unblock
	sbi	dbg_port, dbg_unblock
	#endif
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
	#ifdef dbg_unblock
	cbi	dbg_port, dbg_unblock
	#endif
	reti

unblock040:
	adiw	yh:yl, 1		;;; Restore block status
	brne	unblock060		;;; there is a job waiting
	
	ldi	yl, low(1)		;;; no job waiting so just bump
	ldi	yh, high(1)		;;; the value from 0 -> 1
	std	Z+0, yl			;;; flag a pending unblock/event
	std	Z+1, yh
	
	pop	yl
	pop	yh
	pop	zl
	pop	zh
	out	CPU_SREG, r8
	pop	r8
	#ifdef dbg_unblock
	cbi	dbg_port, dbg_unblock
	#endif
	reti
	
unblock060:
	push	xh
	push	xl
	ldi	xl, low(runjob)		;;; queue the job to the run queu
	ldi	xh, high(runjob)
	std	Y+jcb_joblist+0, xl
	std	Y+jcb_joblist+1, xh
	ldd	xl, Y+0
	ldd	xh, Y+1			;;; get next job in block queue
	std	Z+0, xl			;;; 
	std	Z+1, xh			;;; and set it as next in block queue
	movw	zh:zl, yh:yl		;;; set address of jcb
	pop	xl
	pop	xh
	rcall	link			;;; link it into the runjob queue
	#ifdef dbg_unblock
	cbi	dbg_port, dbg_unblock
	#endif
	rjmp	sysret
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
	oscall	delay_

delay_:
	lds	yl, runjob+0
	lds	yh, runjob+1		;;; Get Job
	std	Y+jcb_joblist+0, r24
	std	Y+jcb_joblist+1, r25	;;; Set Ticks (reuse joblist word in JCB)

	ldd	zl, Y+jcb_flags
	ori	zl, 0x01
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
	rjmp	sysret
;
;	r24	= priority
;
setpriority:
	oscall	setpriority_

setpriority_:
	push	xh
	push	xl
	lds	yl, runjob+0
	lds	yh, runjob+1
	ldd	xl, Y+0
	ldd	xh, Y+1
	sts	runjob+0, xl
	sts	runjob+1, xh		;;; Remove myself from runjob (I'm the first)
	std	Y+jcb_priority, zl	;;; Set my new priority
	ldi	xl, low(runjob)
	ldi	xh, high(runjob)
	std	Y+jcb_joblist+0, xl
	std	Y+jcb_joblist+1, xh	;;; Queue me again into the runjob queu
	pop	xl
	pop	xh			;;; Restore work register
	ldd	zl, Y+0
	ldd	zh, Y+1
	movw	zh:zl, yh:yl
	rcall	link			;;; Link into runjob according priority
	rjmp	sysret			;;; 

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
;	SP	-->	.byte	stacksize-35
;			.byte	r0
;			.byte	r1
;			.
;			.
;			.byte	zh
;			.byte	r8
;			.byte	pcl
;			.byte	pch
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
create:
	oscall	create_
	

create_:	

	push	r3			; Save Scratchpad
	push	r2
	push	r1
	push	r0
	
	movw	zh:zl, r25:r24		; struct JCB*
	
	ldd	r0, Z+jcb_joblist+0
	ldd	r1, Z+jcb_joblist+1	; Program start to scratchpad
	movw	r3:r2, yh:yl		; copy Y to scratchpad
	ldd	yl, Z+jcb_stack+0
	ldd	yh, Z+jcb_stack+1	; Get user stack 
;
;	We start using the -Y addressing mode as the address required for the
;	stack should point past the top of stack
;
	st	-Y, r0			; Program Counter aka Start address
	st	-Y, r1			; 
	st	-Y, r8			; During OS calls the top of the stack
	st	-Y, zh			; always has r8 followed by zh, zl, yh, yl
	st	-Y, zl			; 
	st	-Y, r3			; In fact yh, yl 
	st	-Y, r2			;
	st	-Y, xh
	st	-Y, xl
;	st	-Y, r25
;	st	-Y, r24			; replaced by value for ABI of job()
	ldd	r0, Z+0			
	ldd	r1, Z+1			; Get the "parameter" for the job
	st	-Y, r1
	st	-Y, r0			; The parameter used to set jobs register r25:r24
	st	-Y, r23
	st	-Y, r22
	st	-Y, r21
	st	-Y, r20
	st	-Y, r19
	st	-Y, r18
	st	-Y, r17
	st	-Y, r16
	st	-Y, r15
	st	-Y, r14
	st	-Y, r13
	st	-Y, r12
	st	-Y, r11
	st	-Y, r10
	st	-Y, r9
	set
	bld	r8, CPU_I_bp		; Set I in process SREG which is saved
	st	-Y, r8			; on stack on the 8th position 
	st	-Y, r7
	st	-Y, r6
	st	-Y, r5
	st	-Y, r4
	pop	r0
	pop	r1
	pop	r2
	pop	r3			; Restore scratchpad
	st	-Y, r3
	st	-Y, r2
	st	-Y, r1
	st	-Y, r0
	sbiw	yh:yl, 1		; stack uses post-decrement and pre-increment
	std	Z+jcb_stack+0, yl
	std	Z+jcb_stack+1, yh	; Keep fingers crossed we did it right
	clr	yl
	std	Z+jcb_flags, yl		; Initialise the flags
	std	Z+0, yl			; Initialise link head
	std	Z+1, yl
	ldi	yl, low(runjob)
	ldi	yh, high(runjob)	; Initial queue
	std	Z+jcb_joblist+0, yl
	std	Z+jcb_joblist+1, yh
	rcall	link			; Add it to the runjob queue
	rjmp	sysret			; Schedule the created job or return to caller
