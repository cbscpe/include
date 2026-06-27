# include

This is a collection of some of my often used include files for my AVR assembler
projects. It is some sort of source library. I use the `avrasm2` assembler from
Microchip included in Microchip Studio. I do not use the IDE but just the assembler.

# Content

## Macro Library

A set of often used macros. As the avrasm2 is very limited I try to add features
I normally expect in form of a macro. 

### record macro

Often I need data structures with offsets, like a struct data type in C or other
languages. I use the macros recordstart, record, recordend and recordcont. Offsets
have a prefix and a suffix. Often used for control blocks.

You start a control block defintion by using recordstart and then add fields
using the record macro. The control block is finished by recordend. Offsets
configured with these macros always start with 0. For control blocks that
start with a different value you can use recordcont. This can be used
to continue an existing control block, for example you have a message header
control block which is identical for all messages and then you extend this
message header with several individual control blocks that follow the header
for the different message types.

## RT-OS V3.0

Many applications of a microcontroller require the execution of quasi parallel
processes. Typically you use some sort of cooperative scheduler that gives each
task control over the CPU and expects that control is given back within a short
time to pass the control onto the next task. But when you have tasks that use
large amount of CPU power or when you need to use delays, then the cooperative
approach gets more and more complex. One solution is a real-time scheduler 
with preemptive execution of tasks. So why not write your own scheduler. There
are plenty of examples you can study. My RT-OS is based on a scheduler used
in the RQDX3 Q-BUS disk controller. This scheduler implemented the following
system calls

- ACQUIRE -- mark a data structure or other resources as "in use"
- RELEASE -- free a previously acquired resource, and wake any job waiting
- BLOCK -- block further execution of the current job (sleep indefinitely)
- UNBLOCK -- wake up a job which had previously blocked itself
- CREATE -- set up a context for a new job and start it running
- SLEEP -- hibernate for a fixed number of seconds

I ported this scheduler to the AVR microcontroller. After some iteration I
decided to only support the newest AVR microcontroller, i.e. the
megaAVR® 0-series, AVR® DA(S), AVR® DB and AVR® DD families. The RT-OS makes
use of the following microcontroller resources

- 1 GPIO pin which must be reserved for the RT-OS
- RTC

The GPIO pin is used as a software interrupt substitute. The complete OS
routines are executed at interrupt level 0. This has the advantage that you
never disable interrupts completely and can still have a single interrupt that
executes at level 1 which can interrupt even the OS which gives interrupt
sources that require extremely low interrupt latency the possibility to execute
immediately.

The RTC is used as timer, which is used for the delay() function of the OS. I 
use the PIT of the RTC which generates an interrupt every 1/1024th of a second.
Therefore the delay() function has a granularity of approximatively 1ms.

## malloc(), free()

Often you need to allocated memory dynamically and therefore I have written
my own version of malloc() and free(). If used they make use of the same
software interrupt as the RT-OS and thus share the GPIO pin. In fact malloc()
and free() are like part of the OS function.

## FAT Library

This is a collection of routines that allow reading data from a FAT-16 or FAT-32
formatted SD-Card. Initially developed for my PDP-11 disk emulator hardware, so
I could use a standard file system to store disk images for the PDP-11. 


### Control Blocks

The FAT Library uses a set of control blocks which are used to store all
the control information to access the file system

#### IO Parameter Block

The most basic is the IO Parameter block. This is mainly used for block IO
to the device which holds the data. One such control block must be allocated


```
;--------------------------------------------------------------------------
;
;	IO parameter block
;
;	This parameter block is related to block based IO to and from 
;	the massstorage device. In our case primarely an SD-Card connected
;	via SPI to the uController. 
;
recordstart	P
record		P, Address, 2		; Address of the IO Buffer
record		P, Sector, 4
record		P, Wordcount, 2		; IO Wordcount for TURBO and MULTIPLE
record		P, Error, 2
record		P, Duration, 2

record		P, Cluster, 4		; Current Cluster
record		P, MaxSector, 0		; Maximum Sectors that can be read 
record		P, Extended, 4		; Used to keep extended partition sector 
					; during Mount Volume
record		P, Flag, 1
;
;	28-05-2022	New IO paramter block flags. With TURBO and MULTIPLE
;			we have two SD_CARD_READ routines that interleave
;			reading data from the SD-Card with DMA, so we need
;			to signal some actions
;		P__Skip	As the sector size of RL01/02 is 256bytes and the 
;			blocksize of SD-Cards is 512bytes the data requested
;			might start in the second half of the SD-Card block
;		P__NoCheck When Read No Check is requested we must not check
;			the CRC of the block retrieved from the SD-Card
;		P__Contig is set if the IO fits within a contiguous blocks
;			of SD-Card blocks, which is the case for partitions
;			and contiguous disk images, might as well extend this
;			to disk image fragments that hold the complete IO
;			in the future, if set then we can use MULTIPLE
;
	.equ	P__Skip		= 2	; Skip first half of block for DMA
	.equ	P__NoCheck	= 3	; Ignore CRC Errors when reading blocks
	.equ	P__Contig	= 4	; Either a partition or contiguous file
	.equ	Part__Next	= 5	; Analyze next extended partition table
	.equ	Part__Ext	= 7	; Current MBR has Extended Partition
record		P, NumSect, 1		; Housekeeping Counter
record		P, Volume, 2		; Pointer to volume control block
recordend	P, Size

```
