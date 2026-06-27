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


## FAT Library

This is a collection of routines that allow reading data from a FAT-16 or FAT-32
formatted SD-Card
