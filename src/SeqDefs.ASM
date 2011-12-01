ST7/
	.TAB	10,11,22,40
	.FORM	64
	TITLE	"VTree 8-Channel Light Controller"
	SUBTTL	"Sequencer macros and constant definitions"
	.NOCHANGE

;*****************************************||*****************************************
;*							*
;*	     VTree: The "Virtual Tree" 8-Channel Light Controller		*
;*							*
;*	          Sequencer macros and constant definitions		*
;*							*
;*	        Copyright (C) 2002, Mark Schultz / Rising Edge		*
;*							*
;*----------------------------------------------------------------------------------*
;*							*
;* Author:		Mark Schultz				*
;* Filename:	SeqDefs.ASM					*
;* File version:	1.06					*
;* H/W version:	2.10					*
;* Last update:	02-Jan-2005					*
;* Target:		vTree Sequencer				*
;* Tool set:	STM Assembler				*
;*							*
;************************************************************************************
;Tabs:      13          25          37          49          61          73          85
;	|	|	|	|	|	|	|

;*****************************************||*****************************************
;*		           Revision History			*
;************************************************************************************
;
;Version	Date	Modifications
;-------	--------	-------------------------------------------------------------
;1.00	11/17/02	- First version created
;
;1.01	11/24/02	- Added support for new sequencer commands and addressing
;		  modes (file system)
;
;1.02	12/05/02	- Support for a few new opcodes and new addressing mode
;		  (8-bit constant) added.
;		- Test code stripped out and moved to SeqTest.ASM, file is
;		  now INCLUDEable.
;
;1.03	12/23/02	- Added definitions for new operations:
;		  RUND, RUNM, OPEND, LEA, SPOUT, SPOUTS, SPOUTU, SPOUTD
;		- Added macros Constant4, Constant8, Constant12, Constant16
;		  to allow forced definition of constant types (needed
;		  to handle forward-reference phasing problem)
;		- Added macros SAddress (12 bit) and LAddress (16 bit)
;		  to allow forced sized constants for addresses.
;		- Added PagePad macro to help create file sizes that are
;		  powers of 2.  Not necessary, just convenient for debug.
;
;1.04	12/24/02	- Removed definitions for BSHL and BSHR operations.
;		- Added definitions for RUNP and OPENP
;		- Opcode table reorganized again.
;
;1.05	12/26/02	- IJLT operation renamed to IJLE.
;	12/29/02	- Added control variables for time-of-day clock.
;	12/30/02	- Removed definitions for DREF, DINT, DCLR.
;		- Added definitions for INPUT and ATOI.
;
;------------------------------------------------------------------------------------

	#IFDEF	SeqDefs_

;	SeqDefs.ASM already included.

	#ELSE

	#DEFINE	SeqDefs_ 1

;*****************************************||*****************************************
;*		         Constant Definitions			*
;************************************************************************************

	BYTES

;	Array names

Intensity@	EQU	0
TransCtrl@	EQU	1
MAGCtrl@	EQU	2
MAGCount@	EQU	3
MAGPreCnt@	EQU	4
MAGClkDiv@	EQU	5
MAGStep@	EQU	6
MAGBound1@	EQU	7
MAGBound2@	EQU	8
Gain@	EQU	9
AnalogIn@	EQU	10
UsrTmrCnt@	EQU	11
UsrTmrLim@	EQU	12
Display@	EQU	13
FixTmrCnt@	EQU	14
Buffer1@	EQU	15
Buffer2@	EQU	16
Buffer3@	EQU	17
Register@	EQU	18

;	Control variable names

MAGGCtrl?	EQU	0
MAGSteps?	EQU	1
DigitalON?	EQU	2
TimeToggle?	EQU	3
TimeFlag?	EQU	4
UsrTmrFlg?	EQU	5
RandSeed?	EQU	6
I2CError?	EQU	7
ACPeriod?	EQU	8
LineStat?	EQU	9
SCICtrl?	EQU	10
USBStat?	EQU	11
ConSCICtrl?	EQU	12
ConUSBCtrl?	EQU	13
EEStat?	EQU	14
FileStat?	EQU	15
DispCtrl?	EQU	16
DispIndex?	EQU	17
FileStart?	EQU	18
FileEnd?	EQU	19
FilePos?	EQU	20
FileDirPtr?	EQU	21
SeqCtrl?	EQU	22
SeqPC?	EQU	23
SeqSP?	EQU	24
SeqSPLim?	EQU	25
SeqStart?	EQU	26
SeqEnd?	EQU	27
ExecPC?	EQU	28
InstrCnt?	EQU	29
IOCount?	EQU	30
SeqIOCnt?	EQU	31
SeqIOLim?	EQU	32
Seconds?	EQU	33
Clock?	EQU	34
ClockSec?	EQU	35

;*****************************************||*****************************************
;*		          Macro Definitions			*
;************************************************************************************

;	Sequencer operations

	#DEFINE	_NOP	DC.B $00
	#DEFINE	_MOVE	DC.B $01
	#DEFINE	_ZERO	DC.B $02
	#DEFINE	_XCHA	DC.B $03
	#DEFINE	_XCHB	DC.B $04
	#DEFINE	_XCHN	DC.B $05
	#DEFINE	_ADD	DC.B $06
	#DEFINE	_SUB	DC.B $07
	#DEFINE	_INC	DC.B $08
	#DEFINE	_INCBC	DC.B $09
	#DEFINE	_INCWC	DC.B $0A
	#DEFINE	_DEC	DC.B $0B
	#DEFINE	_DECBC	DC.B $0C
	#DEFINE	_DECWC	DC.B $0D
	#DEFINE	_INV	DC.B $0E
	#DEFINE	_CPL2	DC.B $0F
	#DEFINE	_AND	DC.B $10
	#DEFINE	_OR	DC.B $11
	#DEFINE	_XOR	DC.B $12
	#DEFINE	_ANDOR	DC.B $13
	#DEFINE	_SHL	DC.B $14
	#DEFINE	_SHLBC	DC.B $15
	#DEFINE	_SHLWC	DC.B $16
	#DEFINE	_SHR	DC.B $17
	#DEFINE	_SHRBC	DC.B $18
	#DEFINE	_SHRWC	DC.B $19
	#DEFINE	_MUL	DC.B $1A
	#DEFINE	_RAND	DC.B $1B
	#DEFINE	_DIV16	DC.B $1C
	#DEFINE	_DIV32	DC.B $1D
	#DEFINE	_WAIT	DC.B $1E
	#DEFINE	_LWAIT	DC.B $1F
	#DEFINE	_SETBC	DC.B $20
	#DEFINE	_SETWC	DC.B $21
	#DEFINE	_CLRBC	DC.B $22
	#DEFINE	_CLRWC	DC.B $23
	#DEFINE	_AMOVE	DC.B $24
	#DEFINE	_ALOAD	DC.B $25
	#DEFINE	_MMOVE	DC.B $26
	#DEFINE	_MADD	DC.B $27
	#DEFINE	_MSUB	DC.B $28
	#DEFINE	_MINC	DC.B $29
	#DEFINE	_MDEC	DC.B $2A
	#DEFINE	_MAND	DC.B $2B
	#DEFINE	_MOR	DC.B $2C
	#DEFINE	_MXOR	DC.B $2D
	#DEFINE	_MANDOR	DC.B $2E
	#DEFINE	_NOPX	DC.B $2F
	#DEFINE	_JMP	DC.B $30
	#DEFINE	_JLT	DC.B $31
	#DEFINE	_JLE	DC.B $32
	#DEFINE	_JEQ	DC.B $33
	#DEFINE	_JNE	DC.B $34
	#DEFINE	_JGE	DC.B $35
	#DEFINE	_JGT	DC.B $36
	#DEFINE	_JZ	DC.B $37
	#DEFINE	_JNZ	DC.B $38
	#DEFINE	_JBCS	DC.B $39
	#DEFINE	_JWCS	DC.B $3A
	#DEFINE	_JEOF	DC.B $3B
	#DEFINE	_JBCC	DC.B $3C
	#DEFINE	_JWCC	DC.B $3D
	#DEFINE	_JNEOF	DC.B $3E
	#DEFINE	_NOPY	DC.B $3F
	#DEFINE	_JBS	DC.B $40
	#DEFINE	_JABS	DC.B $41
	#DEFINE	_JBC	DC.B $42
	#DEFINE	_JABC	DC.B $43
	#DEFINE	_DJNZ	DC.B $44
	#DEFINE	_IJLE	DC.B $45
	#DEFINE	_CALL	DC.B $46
	#DEFINE	_RET	DC.B $47
	#DEFINE	_PUSH	DC.B $48
	#DEFINE	_POP	DC.B $49
	#DEFINE	_RSP	DC.B $4A
	#DEFINE	_OPEN	DC.B $4B
	#DEFINE	_OPENP	DC.B $4C
	#DEFINE	_OPEND	DC.B $4D
	#DEFINE	_CLOSE	DC.B $4E
	#DEFINE	_SEEK	DC.B $4F
	#DEFINE	_INP	DC.B $50
	#DEFINE	_INPS	DC.B $51
	#DEFINE	_INPU	DC.B $52
	#DEFINE	_OUT	DC.B $53
	#DEFINE	_OUTS	DC.B $54
	#DEFINE	_OUTU	DC.B $55
	#DEFINE	_OUTD	DC.B $56
	#DEFINE	_AINP	DC.B $57
	#DEFINE	_AINPS	DC.B $58
	#DEFINE	_AINPU	DC.B $59
	#DEFINE	_AOUT	DC.B $5A
	#DEFINE	_AOUTS	DC.B $5B
	#DEFINE	_AOUTU	DC.B $5C
	#DEFINE	_AOUTD	DC.B $5D
	#DEFINE	_DOUT	DC.B $5E
	#DEFINE	_DOUTS	DC.B $5F
	#DEFINE	_DOUTU	DC.B $60
	#DEFINE	_DOUTD	DC.B $61
	#DEFINE	_HOUT	DC.B $62
	#DEFINE	_HOUTS	DC.B $63
	#DEFINE	_HOUTU	DC.B $64
	#DEFINE	_HOUTD	DC.B $65
	#DEFINE	_SOUT	DC.B $66
	#DEFINE	_SOUTS	DC.B $67
	#DEFINE	_SOUTU	DC.B $68
	#DEFINE	_SOUTD	DC.B $69
	#DEFINE	_SPOUT	DC.B $6A
	#DEFINE	_SPOUTS	DC.B $6B
	#DEFINE	_SPOUTU	DC.B $6C
	#DEFINE	_SPOUTD	DC.B $6D
	#DEFINE	_INPUT	DC.B $6E
	#DEFINE	_ATOI	DC.B $6F
	#DEFINE	_RUN	DC.B $70
	#DEFINE	_RUNP	DC.B $71
	#DEFINE	_RUND	DC.B $72
	#DEFINE	_RUNM	DC.B $73
	#DEFINE	_LEA	DC.B $74
	#DEFINE	_SIZE	DC.B $75
	#DEFINE	_AMAG	DC.B $76
	#DEFINE	_MSTEP	DC.B $77
	#DEFINE	_BAUD	DC.B $78
	#DEFINE	_MCALL	DC.B $79
	#DEFINE	_INIT	DC.B $7A
	#DEFINE	_RESET	DC.B $7B
	#DEFINE	_BREAK	DC.B $7C
	#DEFINE	_END	DC.B $7D
	#DEFINE	_ENDOS	DC.B $7E

;------------------------------------------------------------------------------------

;	Sequencer parameters

;	Constant (4, 12, 16 bit)

Constant	MACRO	Value
	#IF	{Value LT $10}
	DC.B	{$00+Value}
	#ELSE
	#IF	{Value LT $100}
	DC.B	$20,Value
	#ELSE
	#IF	{Value LT $1000}
	DC.B	{$10+{HIGH Value}},{LOW Value}
	#ELSE
	DC.B	$21,{HIGH Value},{LOW Value}
	#ENDIF
	#ENDIF
	#ENDIF
	MEND

;	4-bit constant only

Constant4	MACRO	Value
	#IF	{Value LT $10}
	DC.B	{$00+Value}
	#ELSE
	%OUT	4-bit constant too large
	ERROR
	#ENDIF
	MEND

;	8-bit constant only

Constant8	MACRO	Value
	#IF	{Value LT $100}
	DC.B	$20,Value
	#ELSE
	%OUT	8-bit constant too large
	ERROR
	#ENDIF
	MEND

;	12-bit constant only

Constant12	MACRO	Value
	#IF	{Value LT $1000}
	DC.B	{$10+{HIGH Value}},{LOW Value}
	#ELSE
	%OUT	12-bit constant too large
	ERROR
	#ENDIF
	MEND

;	16-bit constant only

Constant16	MACRO	Value
	DC.B	$21,{HIGH Value},{LOW Value}
	MEND

;	Address constants (variation of standard constant)

ProgStart	MACRO
_Base	CEQU	*
	MEND

SAddress	MACRO	Addr
	#IF	{Addr LT $1000}
	DC.B	{$10+{HIGH {Addr-_Base}}}
	DC.B	{LOW {Addr-_Base}}
	#ELSE
	%OUT	Address out of 12-bit range
	ERROR
	#ENDIF
	MEND

LAddress	MACRO	Addr
	DC.B	$21
	DC.B	{HIGH {Addr-_Base}}
	DC.B	{LOW {Addr-_Base}}
	MEND

;	Byte register (short & long addresses)

ByteReg	MACRO	Reg
	#IF	{Reg LT $10}
	DC.B	{$40+Reg}
	#ELSE
	#IF	{Reg LT $100}
	DC.B	$60,Reg
	#ELSE
	%OUT	Invalid register reference
	ERROR
	#ENDIF
	#ENDIF
	MEND

;	Word register (short and long addresses)

WordReg	MACRO	Reg
	#IF	{Reg LT $10}
	DC.B	{$50+Reg}
	#ELSE
	#IF	{Reg LT $100}
	DC.B	$61,Reg
	#ELSE
	%OUT	Invalid register reference
	ERROR
	#ENDIF
	#ENDIF
	MEND

;	Byte register selected by register (short and long addresses)

ByteInd	MACRO	Reg
	#IF	{Reg LT $10}
	DC.B	{$70+Reg}
	#ELSE
	#IF	{Reg LT $100}
	DC.B	$90,Reg
	#ELSE
	%OUT	Invalid register reference
	ERROR
	#ENDIF
	#ENDIF
	MEND

;	Word register selected by register (short and long addresses)

WordInd	MACRO	Reg
	#IF	{Reg LT $10}
	DC.B	{$80+Reg}
	#ELSE
	#IF	{Reg LT $100}
	DC.B	$91,Reg
	#ELSE
	%OUT	Invalid register reference
	ERROR
	#ENDIF
	#ENDIF
	MEND

;	Array indexed by constant

ArrayConst	MACRO	Array,Index
	#IF	{Index LT $10}
	DC.B	{$A0+Index},Array&@
	#ELSE
	%OUT	Constant index too large (must be < $10)
	ERROR
	#ENDIF
	MEND

;	Array indexed by register (short and long addresses)

ArrayReg	MACRO	Array,Reg
	#IF	{Reg LT $10}
	DC.B	{$B0+Reg},Array&@
	#ELSE
	#IF	{Reg LT $100}
	DC.B	$C0,Reg,Array&@
	#ELSE
	%OUT	Invalid register reference
	ERROR
	#ENDIF
	#ENDIF
	MEND

;	Control variable

CtrlVar	MACRO	Var
	DC.B	$C1,Var&?
	MEND

;	Byte file read (only)

ByteFileRd	MACRO
	DC.B	$C2
	MEND

;	Word file read (only)

WordFileRd	MACRO
	DC.B	$C3
	MEND

;	Byte file read/write

ByteFileRW	MACRO
	DC.B	$C4
	MEND

;	Word file read/write

WordFileRW	MACRO
	DC.B	$C5
	MEND

;	Byte file write (only)

ByteFileWr	MACRO
	DC.B	$C6
	MEND

;	Word file write (only)

WordFileWr	MACRO
	DC.B	$C7
	MEND

;	Byte RAM access (short and long addresses)

ByteRAMK	MACRO	Addr
	#IF	{Addr LT $100}
	DC.B	$F0,Addr
	#ELSE
	DC.B	$F2,{HIGH Addr},{LOW Addr}
	#ENDIF
	MEND

;	Word RAM access (short and long addresses)

WordRAMK	MACRO	Addr
	#IF	{Addr LT $100}
	DC.B	$F1,Addr
	#ELSE
	DC.B	$F3,{HIGH Addr},{LOW Addr}
	#ENDIF
	MEND

;	Byte RAM access, address specified by (word) register

ByteRAMReg	MACRO	Reg
	DC.B	$F4,Reg
	MEND

;	Word RAM access, address specified by (word) register

WordRAMReg	MACRO	Reg
	DC.B	$F5,Reg
	MEND

;	Byte program memory access, address specified by a 16-bit constant

BytePrgK	MACRO	Addr
	DC.B	$F6
	DC.B	{HIGH {Addr-_Base}}
	DC.B	{LOW {Addr-_Base}}
	MEND

;	Word program memory access, address specified by a 16-bit constant

WordPrgK	MACRO	Addr
	DC.B	$F7
	DC.B	{HIGH {Addr-_Base}}
	DC.B	{LOW {Addr-_Base}}
	MEND

;	Byte program memory access, address specified by (word) register

BytePrgReg	MACRO	Reg
	DC.B	$F8,Reg
	MEND

;	Word program memory access, address specified by (word) register

WordPrgReg	MACRO	Reg
	DC.B	$F9,Reg
	MEND

;	Byte EEPROM access specified by constant address

ByteEEK	MACRO	Addr
	DC.B	$FA,{HIGH Addr},{LOW Addr}
	MEND

;	Word EEPROM access specified by constant address

WordEEK	MACRO	Addr
	DC.B	$FB,{HIGH Addr},{LOW Addr}
	MEND

;	Byte EEPROM access specified by a (word) register

ByteEEReg	MACRO	Reg
	DC.B	$FC,Reg
	MEND

;	Word EEPROM access specified by a (word) register

WordEEReg	MACRO	Reg
	DC.B	$FD,Reg
	MEND

	#ENDIF

;	Fill to a specified page boundary

PagePad	MACRO	PageSize
	SKIP	{{1 SHL PageSize} - {* AND {{1 SHL PageSize}-1}}},$00
	MEND
