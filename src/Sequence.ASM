ST7/
	.TAB	10,11,22,40
	.FORM	64
	TITLE	"VTree 8-Channel Light Controller"
	SUBTTL	"Sequencer (program executive)"

;*****************************************||*****************************************
;*							*
;*	     VTree: The "Virtual Tree" 8-Channel Light Controller		*
;*							*
;*		    Sequencer - Program Executive			*
;*							*
;*	        Copyright (C) 2003, Mark Schultz / Rising Edge		*
;*							*
;*----------------------------------------------------------------------------------*
;*							*
;* Author:		Mark Schultz				*
;* Filename:	Sequence.ASM				*
;* File version:	1.04					*
;* H/W version:	2.10					*
;* Last update:	07-Mar-2004					*
;* Target:		ST Microelectronics ST72631			*
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
;1.00	10/26/02	- First version created
;
;1.01	12/05/02	- First debug pass; sequencer can now properly execute
;		  "Hello, World!"
;
;1.02	12/22/02	- More bugfixes, all arg processors tested & debugged.
;		- Opcode table reorganized.
;		- New operations added:
;		  RUNM, RUND, OPEND, LEA, SPOUT, SPOUTS, SPOUTU, SPOUTD
;
;1.03	12/24/02	- BSHL, BSHR operations removed - redundant.
;		- OPENP and RUNP operations added.
;		- Opcode table reorganized.
;		- File I/O arg types now respect the file read-only
;		  attribute.
;
;1.04	12/25/02	- Fixed byte/word operation bug in shift operations.
;	12/26/02	- Fixed several bugs in array operations, made code tighter.
;		- IJLT operation changed to IJLE (inc, jump if less/equal).
;		- Fixed bugs in AND, OR, XOR operations.
;	12/28/02	- SIZE sequencer operation added; returns sizeof(operand)
;	12/29/02	- HOUT and DOUT operations enhanced; MSB of <devmask> arg
;		  will specify output radix (1=Bin, 2=Oct, 3=Dec, 4=Hex) if
;		  it is non-zero; otherwise, output will be in the radix
;		  implied by the instruction (hex or decimal).
;		- Added control variables for time-of-day clock.
;	12/30/02	- DREF, DINT and DCLR operations removed, since the same
;		  functionality can be achieved using OUTD with
;		  an appropriate control code.
;		- INPUT and ATOI operations added.
;	01/03/03	- JEOF and JNEOF operations added.
;		- Interrupt button (INTBTN) is now checked directly in
;		  IntChk routine instead of check in HBInt.
;
;------------------------------------------------------------------------------------

;*****************************************||*****************************************
;*			Include files			*
;************************************************************************************

	#INCLUDE	"Macros.ASM"

	#INCLUDE	"SFRDefs.ASM"

	#INCLUDE	"PortMap.ASM"

	#INCLUDE	"Constant.ASM"

	#INCLUDE	"External.ASM"

;*****************************************||*****************************************
;*		           Local Constants			*
;************************************************************************************

;	Bit definitions for ArgCtrl registers

	BYTES

ArgConst@	EQU	4           	;Writeable: 0=Yes, 1=No
ArgConst?	EQU	{1 SHL ArgConst@}	;
ArgWord@	EQU	5		;Size:      0=Byte, 1=Word
ArgWord?	EQU	{1 SHL ArgWord@}	;
ArgEE@	EQU	6		;Mem space: 0=RAM, 1=EEPROM
ArgEE?	EQU	{1 SHL ArgEE@}	;
ArgSave@	EQU	7		;Writeback: 0=No, 1=Yes
ArgSave?	EQU	{1 SHL ArgSave@}	;

;	Sequencer error codes

SE_END	EQU	0		;End of program, normal termination
SE_Opcode	EQU	1		;Bad opcode
SE_Arg	EQU	2		;Bad argument
SE_Reg	EQU	3		;Invalid register address
SE_ArrayID	EQU	4		;Invalid array ID
SE_ArrayIdx	EQU	5		;Invalid array index
SE_CVIdx	EQU	6		;Invalid control variable index
SE_Mem	EQU	7		;Memory (EEPROM) R/W error
SE_Bound	EQU	8		;Attempt to R/W outside mem bounds
SE_Const	EQU	9		;Attempt to write to a constant
SE_FileIO	EQU	10		;File I/O error
SE_Stack	EQU	11		;Stack over/underflow
SE_Break	EQU	$FF		;Break interrupt

;	Operation codes for ModArray (see Command2.ASM)

Op_Assign	EQU	1		;Array assignment
Op_Add	EQU	2		;Add
Op_Sub	EQU	3		;Subtract
Op_And	EQU	4		;Bitwise AND
Op_Or	EQU	5		;Bitwise OR
Op_XOr	EQU	6		;Bitwise XOR
Op_AndOr	EQU	7		;Bitwise AND, then OR

;	Number base codes

Nbr_Bin	EQU	0		;Binary
Nbr_Oct	EQU	1		;Octal
Nbr_Dec	EQU	2		;Decimal
Nbr_Hex	EQU	3		;Hexadecimal

;	Argument block offsets

ArgOfs	EQU	0		;Argument value
ArgHOfs	EQU	0		;
ArgLOfs	EQU	1		;
ArgPtrOfs	EQU	2		;Argument pointer
ArgPtrHOfs	EQU	2		;
ArgPtrLOfs	EQU	3		;
ArgCtrlOfs	EQU	4		;Argument control flags

;*****************************************||*****************************************
;*		          External Variables			*
;************************************************************************************

	BYTES

;	Aliases

ArgVal	EQU	StrPtr
ArgValH	EQU	StrPtrH
ArgValL	EQU	StrPtrL

ArgPtr	EQU	ObjPtr
ArgPtrH	EQU	ObjPtrH
ArgPtrL	EQU	ObjPtrL

ArgCtrl	EQU	FmtCode

;*****************************************||*****************************************
;*		         External Subroutines			*
;************************************************************************************

	WORDS

	EXTERN	ModArray
	EXTERN	InitMacro
	EXTERN	MAG
	EXTERN	SCIInit,SCIIn,SCIOut
	EXTERN	ConIn,ConOut
	EXTERN	USBIn,USBOut
	EXTERN	USBTxFlush
	EXTERN	GetLine
	EXTERN	PRINTF
	EXTERN	EERead,EEWrite,EERelease
	EXTERN	DAOut,SendDisp
	EXTERN	OpenFile,OpenFileD,CloseFile
	EXTERN	OpenProg,OpenProgD
	EXTERN	FileRead,FileWrite
	EXTERN	FileSeek,FileCheck
	EXTERN	GetDir,FirstFile,NextFile
	EXTERN	MoveArg,GetArg
	EXTERN	NBPrep,Int2Bin,Int2Oct,Int2Dec,Int2Hex
	EXTERN	MUL1616,Random16
	EXTERN	DIV168,DIV3216

;------------------------------------------------------------------------------------

Sequencer	SEGMENT	'CODE'

;************************************************************************************
;Name:	Exec
;Function:  Execute sequencer program
;
;	SeqStart  -> Starting absolute address of sequencer program
;		 (SeqPC is set to this upon entry)
;	SeqEnd    -> Ending absolute address of sequencer program
;	SeqCtrl  <-> FetchRAM bit should be set appropriately on entry
;	CF        -> SET to clear register array before program start
;
;Stack use:	Lots
;Destroyed:	Everything
;************************************************************************************

.Exec	LD	A,SeqStartL		;Set PC to start address
	LD	SeqPCL,A		;
	LD	A,SeqStartH		;
	LD	SeqPCH,A		;

	LD	A,#{NbrVars-1}	;Reset sequencer stack pointer
	LD	SeqSP,A		;

	JRNC	Exec1		;If CF set,
	CALL	ClearReg		;Initialize all but first 16 registers

Exec1	LD	A,SeqCtrl		;Initialize control bits
	AND	A,#FetchRAM?	;Clear some bits
	OR	A,#SeqRun?		;Set run bit
	LD	SeqCtrl,A		;

	LD	X,#$FF		 ;Point to page 1
	CLR	({LOW {InstrCnt-$FE}},X) ;Reset instruction counter
	CLR	({LOW {InstrCnt-$FF}},X) ;

	BRESM	RxFE		;Clear break bit, prevent false stop
	CLR	CLIndex		;Default opcode

Exec2	LD	A,SeqPCL		;Save current PC (for debug report)
	LD	ExecPCL,A		;
	LD	A,SeqPCH		;
	LD	ExecPCH,A		;

	CALL	Fetch		;Fetch opcode
	JRC	ExecErr		;Terminate if error
	LD	CLIndex,A		;Save opcode (for debug report)
	CP	A,#NbrOpCode.L	;Valid opcode ?
	JRUGE	ExecErrO		; No, terminate w/error

	CALLR	IntChk		;Check for interrupt/break condition
	JRC	ExecErrB		;Stop if interrupt

	LD	X,#2		;Opcode table entries are 2 bytes
	MUL	X,A		;Calculate opcode table offset
	ADD	A,#OpProcTbl.L	;Add base address of opcode table
	LD	CLPtrL,A		; and save to CLPtr
	LD	A,X		;
	ADC	A,#OpProcTbl.H	;
	LD	CLPtrH,A		;CLPtr <- Pointer to opcode entry

	LD	A,[CLPtr.W]		;Get argument count / address MSB
	SWAP	A		;Move upper 2 bits to 1's position
	SRL	A		;
	SRL	A		;
	AND	A,#$03		;Mask off unwanted bits
	CALL	FetchAll		;Fetch arguments
	JRC	ExecErr		;Terminate if error

	LD	A,[CLPtr.W]		;Get address MSB
	OR	A,#$C0		;Add $C000 to address
	LD	StrPtrH,A		; and save to StrPtr
	LD	X,#1		;Point to LSB
	LD	A,([CLPtr.W],X)	;Get address LSB
	LD	StrPtrL,A		;StrPtr <- Opcode handler address

	RCF			;Clear error flag
	CALL	[StrPtr.W]		;Perform operation
	JRC	ExecErr		;Terminate if error

	CALL	SaveAllArg		;Write back selected arguments
	JRC	ExecErr		;Terminate if error

	LD	X,#$FF		 ;Point to page 1
	INC	({LOW {InstrCnt-$FE}},X) ;Increment instruction count
	JRNE	Exec3		 ;
	INC	({LOW {InstrCnt-$FF}},X) ;

Exec3	JRA	Exec2		;Continue processing if no errors

;	Error handlers

ExecErrO	LD	A,#SE_Opcode	;Invalid opcode
	JRA	ExecErr		;

ExecErrB	LD	A,#SE_Break		;Interrupt button pressed

;	Error message dump
;	A -> Error # (0=Normal termination, no dump)

ExecErr	BRESM	SeqRun		;Clear run bit

ErrRpt	RCF			;Assume normal termination
	LD	ChanMask,A		;Save error code for PRINTF
	JREQ	ExecErrX		;Exit w/o report if normal termination

	LD	A,ExecPCL		;Calculate execution offset
	SUB	A,SeqStartL		;XO = ExecPC - SeqStart
	LD	CLPtrL,A		;
	LD	A,ExecPCH		;
	SBC	A,SeqStartH		;
	LD	CLPtrH,A		;

	LD	Y,#SeqErrMsg.H	;Point to error text
	LD	X,#SeqErrMsg.L	;
	CALL	PRINTF		;Send error message

	SCF			;CF=1 to indicate abnormal termination

ExecErrX	RET			;Exit

;************************************************************************************
;Name:	IntChk
;Function:	Check for interrupt/break conditions
;
;	CF <- SET if interrupt button pressed or BREAK condition detected
;	      on serial port
;
;Stack use:	CALL overhead (2 bytes)
;Destroyed:	Nothing
;************************************************************************************

IntChk	BTJFM	UFlushTm,IntChk1	;If output buffer flush timeout
	CALL	USBTxFlush		; Flush USB output buffer

IntChk1	BTJFM	INTSW,IntChkX	;Break if INTSW=0 (button pressed)
	BTJTM	RxFE,IntChkX	;Break if BREAK detected on serial in

	RCF			;Break condition does not exist
	RET			;Exit

IntChkX	SCF			;Break condition exists
	RET			;Exit

;************************************************************************************
;Name:	Fetch
;Function:	Fetch next byte of sequencer program
;
;	SeqPC    <-> Pointer to location (in RAM or EEPROM) to fetch next byte
;		 Incremented on exit
;	SeqStart  -> Lower address limit
;	SeqEnd    -> Upper address limit
;	SeqCtrl   -> Sequencer control flags
;	A        <-  Byte fetched from active memory space
;		 Returns with error code if CF=1
;	CF       <-  SET if error occured
;
;Stack use:	15 bytes + CALL overhead (2 bytes)
;Destroyed:	Nothing
;************************************************************************************

;	Check for valid address

Fetch	PUSH	X		;Need X temporarily as pointer
	LD	X,#SeqPC		;Check PC
	CALLR	AddrCheck		;Ensure PC within bounds
	POP	X		;
	JRC	FetchErrB		;Exit w/error if PC outside bounds

;	PC address is valid
;	Determine memory space to fetch next byte from

Fetch2	BTJFM	FetchRAM,Fetch3	;Fetch from RAM or EEPROM ?

;	Fetch from RAM

	LD	A,[SeqPC.W]		;Fetch next byte from RAM
	JRA	Fetch6		;Increment PC and exit

;	Fetch from EEPROM
;	If current EEPROM address pointer <> Sequencer PC,
;	then force retransmission of EEPROM read address

Fetch3	LD	A,SeqPCH		;Check if EEPtr = SeqPC
	CP	A,EEPtrH		;
	JRNE	Fetch4		;
	LD	A,SeqPCL		;
	CP	A,EEPtrL		;
	JREQ	Fetch5		;

;	EEPtr <> SeqPC, force EEPROM address transmission

Fetch4	CALL	EERelease		;EEPROM offline
	LD	A,SeqPCH		;EEPtr <- SeqPC
	LD	EEPtrH,A		;
	LD	A,SeqPCL		;
	LD	EEPtrL,A		;

;	Fetch byte from EEPROM

Fetch5      SCF			;Sequential read mode
	CALL	EERead		;
	JRNE	FetchErrM		;Exit w/error if EEPROM read error

;	Increment sequencer PC & exit

Fetch6	INC	SeqPCL		;Increment sequencer PC LSB
	JRNE	Fetch7		;Exit if no overflow
	INC	SeqPCH		; Overflow, increment PC MSB

Fetch7	RCF			;No errors
	RET			;Exit

;	Memory bound error

FetchErrB	LD	A,#SE_Bound		;Memory bound error
	SCF			;
	RET			;Exit

;	Memory read error

FetchErrM	LD	A,#SE_Mem		;Memory read error
	SCF			;
	RET			;

;************************************************************************************
;Name:	AddrCheck
;Function:	Check address against <SeqStart> and <SeqEnd> boundaries
;
;	X         -> Pointer to value to check against bounds
;	SeqStart  -> Lower address boundary ( GE )
;	SeqEnd    -> Upper address boundary < LT )
;	CF       <-  SET if value outside bounds: NOT (SeqStart <= Value < SeqEnd)
;
;Stack use:	CALL overhead (2 bytes)
;Destroyed:	A
;************************************************************************************

AddrCheck	LD	A,(X)		;Get MSB of value
	CP	A,SeqStartH		;Value MSB < Lower limit ?
	JRULT	AddrCheckE		; Yes, out of bounds
	JRUGT	AddrCheck1		;Check upper limit if n > Low limit
	LD	A,(1,X)		;Get LSB of value
	CP	A,SeqStartL		;Value LSB < Lower limit ?
	JRULT	AddrCheckE		; Yes, error

	LD	A,(X)		;Get value MSB again
AddrCheck1	CP	A,SeqEndH		;Value MSB > Upper limit ?
	JRUGT	AddrCheckE		; Yes, error
	JRULT	AddrCheck2		;Value < Upper limit, value OK
	LD	A,(1,X)		;Get value LSB
	CP	A,SeqEndL		;Value >= Upper limit ?
	JRUGE	AddrCheckE		; Yes, error

AddrCheck2	RCF			;CF=0 to indicate value within bounds
	RET			;Exit

AddrCheckE	SCF			;CF=1 to indicate value out of bounds
	RET			;Exit

;************************************************************************************
;Name:	FetchArg
;Function:	Fetch and interpret a operation argument
;
;	ArgPtr  <-  Pointer to object
;	ArgVal  <-  Value of object
;	ArgCtrl <-  ArgCtrl flags
;	A       <-  Error code (if CF=1)
;	CF      <-  SET if argument parsing error
;
;Stack use:	?
;Destroyed:	A, X, Y
;************************************************************************************

;	Get argument type byte

FetchArg	CALLR	Fetch		;Get argument type byte
	JRC	FetchArg3		;Exit if error
	LD	ArgCtrl,A		;Save type here for now

;	Search argument type table for type match

	CLR	X		;Reset index
FetchArg1	CP	A,(ArgTypeTbl,X)	;Type fetched < Type from table ?
	JRULT	FetchArg4		; Yes, match found
	INC	X		;Point to next table element
	LD	A,(ArgTypeTbl,X)	;Check for end of table
	JREQ	FetchArg2		;Error if end of table
	LD	A,ArgCtrl		;Recover arg type byte
	JRA	FetchArg1		;Continue search

;	Invalid argument

FetchArg2	LD	A,#SE_Arg		;Bad argument
	SCF			;CF=1 to indicate error
FetchArg3	RET			;Exit

;	Argument type matched, invoke handler
;	X has argument type index + 1
;
;	On entry, [A] and <ArgCtrl> contain argument type byte.

FetchArg4	SLL	X		;*2 for word index
	LD	A,({ArgProcTbl-2},X)	;Get handler address
	LD	ArgPtrH,A		;
	LD	A,({ArgProcTbl-1},X)	;
	LD	ArgPtrL,A		;
	LD	A,ArgCtrl		;A <- Argument type byte
	JP	[ArgPtr.W]		;Invoke argument parsing handler

;************************************************************************************
;Name:	FetchAll
;Function:	Fetch multiple arguments
;	Typically used to fetch all arguments required for an operation
;
;	A  <-> Number of arguments to fetch (0-3)
;	       Returns with error code if error encountered
;	CF <-  SET if error encountered
;	Arg[n], Arg[n]Ptr, Arg[n]Ctrl updated as appropriate
;
;Stack use:	?
;Destroyed:	A, X, Y, Digits, ArgVal, ArgPtr, ArgCtrl
;************************************************************************************

FetchAll	CLR	Arg1Ctrl		;Clear all ArgCtrl flags
	CLR	Arg2Ctrl		;
	CLR	Arg3Ctrl		;

	LD	Digits,A		;Digits <- Arg fetch counter
	JREQ	FetchAllX		;Exit if arg count = 0

;	Fetch argument #1

	CALLR	FetchArg		;Fetch 1st argument
	JRC	FetchAllE		;Exit if error
	LD	X,#Arg1		;Move data to Arg1
	CALLR	CopyToArg		;

	DEC	Digits		;Decrement arg count
	JREQ	FetchAllX		;Exit if all args fetched

;	Fetch argument #2

	CALLR	FetchArg		;Fetch 2nd argument
	JRC	FetchAllE		;Exit if error
	LD	X,#Arg2		;Move data to Arg2
	CALLR	CopyToArg		;

	DEC	Digits		;Decrement arg count
	JREQ	FetchAllX		;Exit if all args fetched

;	Fetch argument #3

	CALLR	FetchArg		;Fetch 3rd argument
	JRC	FetchAllE		;Exit if error
	LD	X,#Arg3		;Move data to Arg3
	CALLR	CopyToArg		;

	DEC	Digits		;Decrement arg count

;	Exit

FetchAllX	RCF			;No errors
FetchAllE	RET			;Exit

;************************************************************************************
;Name:	CopyToArg
;Function:	Copy contents of temporary argument data registers to a argument block
;
;	X        -> Destination address (should point to start of a arg block)
;	ArgVal   -> Argument value, copied to Arg[n]
;	ArgPtr   -> Argument pointer, copied to Arg[n]Ptr
;	ArgCtrl  -> Argument control flags, copied to Arg[n]Ctrl
;
;Stack use:	1 byte + CALL overhead (2 bytes)
;Destroyed:	Nothing
;************************************************************************************

CopyToArg	PUSH	A		;Save registers used

	LD	A,ArgValH		;Arg[n] <- ArgVal
	LD	(ArgHOfs,X),A	;
	LD	A,ArgValL		;
	LD	(ArgLOfs,X),A	;

	LD	A,ArgPtrH		;Arg[n]Ptr <- ArgPtr
	LD	(ArgPtrHOfs,X),A	;
	LD	A,ArgPtrL		;
	LD	(ArgPtrLOfs,X),A	;

	LD	A,ArgCtrl		;Arg[n]Ctrl <- ArgCtrl
	LD	(ArgCtrlOfs,X),A	;

	POP	A		;Restore registers
	RET			;Exit

;************************************************************************************
;Name:	SaveAllArg
;Function:	Write all arguments with Arg[n]Ctrl.ArgSave set to their appropriate
;	destination.  See <SaveArg> for more details.
;
;	A  <-  Returns with error code if error encountered
;	CF <-  SET if error encountered
;
;Stack use:	14 bytes + CALL overhead (2 bytes)
;Destroyed:	A, X, ArgPtr
;************************************************************************************

SaveAllArg	LD	X,#Arg1		;Save 1st argument
	CALLR	SaveArg		;
	JRC	SaveAllAX		;Exit if error

	LD	X,#Arg2		;Save 2nd argument
	CALLR	SaveArg		;
	JRC	SaveAllAX		;Exit if error

	LD	X,#Arg3		;Save 3rd argument
	CALLR	SaveArg		;

SaveAllAX	RET			;Exit

;************************************************************************************
;Name:	SaveArg
;Function:	Write the value in Arg[x] to the location specified by Arg[n]Ptr
;	based on the memory space specified in Arg[n]Ctrl.ArgEE IF the
;	writeback flag (Arg[n]Ctrl.ArgSave) is set.
;
;	X   -> Pointer to argument block
;	A  <-  Returns with error code if error encountered
;	CF <-  SET if error encountered
;
;Stack use:	12 bytes + CALL overhead (2 bytes)
;Destroyed:	A, X, ArgPtr
;************************************************************************************

SaveArg	LD	A,(ArgCtrlOfs,X)	;Get control flags
	BCP	A,#ArgSave?		;Save requested ?
	JREQ	SaveArgX		; No, exit (do not save)
	BCP	A,#ArgConst?	;Attempt to write a constant?
	JRNE	SaveArgEC		; Yes, error

	BCP	A,#ArgEE?		;Argument memory space = EEPROM ?
	JRNE	SaveArg2		; Yes, write to EEPROM

;	Write argument to memory

	LD	A,(ArgPtrHOfs,X)	;Copy arg pointer
	LD	ArgPtrH,A		;to fixed location
	LD	A,(ArgPtrLOfs,X)	;
	LD	ArgPtrL,A		;

	LD	A,(ArgCtrlOfs,X)	;Get arg flags again
	BCP	A,#ArgWord?		;
	JREQ	SaveArg1		;If argument is word-sized:

	LD	A,(ArgHOfs,X)	;Write MSB
	LD	[ArgPtr.W],A	;
	LD	A,(ArgLOfs,X)	;Write LSB
	LD	X,#1		;
	LD	([ArgPtr.W],X),A	;

	JRA	SaveArgX		;Exit

SaveArg1	LD	A,(ArgLOfs,X)	;Save byte value
	LD	[ArgPtr.W],A	;

	JRA	SaveArgX		;Exit

;	Write argument to EEPROM

SaveArg2	CALL	EERelease		;EEPROM offline
	LD	A,(ArgPtrHOfs,X)	;Copy arg pointer
	LD	EEPtrH,A		;to EEPROM pointer
	LD	A,(ArgPtrLOfs,X)	;
	LD	EEPtrL,A		;

	LD	A,(ArgCtrlOfs,X)	;Get arg flags again
	BCP	A,#ArgWord?		;
	JREQ	SaveArg3		;If argument is word-sized:

	LD	A,(ArgHOfs,X)	;Write MSB
	SCF			; Sequential write
	CALL	EEWrite		; Send to EEPROM
	JRNE	SaveArgEM		; Exit if error
	LD	A,(ArgLOfs,X)	;Write LSB
	RCF			; Terminal write
	CALL	EEWrite		; Send to EEPROM
	JRNE	SaveArgEM		; Exit if error

	JRA	SaveArgX		;Exit

SaveArg3	LD	A,(ArgLOfs,X)	;Write byte
	RCF			; Terminal write
	CALL	EEWrite		; Send to EEPROM
	JRNE	SaveArgEM		; Exit if error

;	Error exits

SaveArgX	RCF			;No errors
	RET			;Exit

SaveArgEC	LD	A,#SE_Const		;Attempt to write a constant
	SCF			;CF=1 to indicate error
	RET			;Exit

SaveArgEM	LD	A,#SE_Mem		;Memory R/W error
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	FetchStr, FetchStrP
;Function:	FetchStr: Fetch an ASCIIZ string from program space and copy to NumBuf
;	FetchStrP: Same as FetchStr, but get string from EEPROM address at (X)
;
;	X        ->  Pointer to word address (in EEPROM) to fetch string from
;		 (only used if entered at FetchStrP)
;	NumBuf  <-   String fetched (terminated w/0 if length < NumBufSz)
;	NumSize <-   Size of string fetched
;	Arg     <-   Initialized to point to NumBuf
;	CF      <-	 SET if error encountered
;
;Stack use:	17 bytes + CALL overhead (2 bytes)
;Destroyed:	A,X,Y
;************************************************************************************

FetchStrP	LD	A,(X)		;EEPtr <- (X)
	LD	EEPtrH,A		;
	LD	A,(1,X)		;
	LD	EEPtrL,A		;
	CALL	EERelease		;EEPROM address changed

	LD	Y,#1		;Y=1 to use EERead to get string
	JRA	FetchStr1		;Get string

FetchStr	CLR	Y		;Y=0 to use Fetch to get string

FetchStr1	LD	A,#NumBuf.H		;Initialize buffer pointer
	LD	ArgH,A		;
	LD	A,#NumBuf.L		;
	LD	ArgL,A		;

	CLR	X		;X <- Buffer index

FetchStr2	TNZ	Y		;Check get mode
	JREQ	FetchStr3		;Use <Fetch> if Y=0

	SCF			;CF=1 for sequential read
	CALL	EERead		;Get byte from string
	JREQ	FetchStr4		;Continue if read successful
	SCF			;Otherwise, exit w/error
	RET			;

FetchStr3	CALL	Fetch		;Get byte from program space
	JRC	FetchStrX		; Exit if error

FetchStr4	CP	X,#NumBufSz		;Index past end of buffer ?
	JRUGE	FetchStr5		; Yes, do not save
	LD	([Arg.W],X),A	;Write data to buffer
	TNZ	A		;End of string ?
	JREQ	FetchStr6		; Yes, fetch completed
	INC	X		; No, increment buffer index

FetchStr5	TNZ	A		;End of string ?
	JRNE	FetchStr2		; No, continue fetching

FetchStr6   LD	NumSize,X		;Save string length
	RCF			;No errors
FetchStrX	RET			;Exit

;************************************************************************************
;Name:	ClearReg, ClearAll
;Function:	Initialize registers to 0
;
;	CF <- CLEAR
;	Variable array cleared
;
;Stack use:	CALL overhead (2 bytes)
;Destroyed:	A, X
;************************************************************************************

.ClearAll	CLR	X		;Clear all: Start w/register 0
	JRA	ClearReg1		;

.ClearReg	LD	X,#16		;Clear all except first 16

ClearReg1	CLR	A		;Initialization value
ClearReg2	LD	(Variables,X),A	;Clear register
	INC	X		;Increment pointer
	CP	X,SeqSP		;End of register space ?
	JRULE	ClearReg2		; No, continue clearing

	RCF			;CF=0 to indicate no errors
	RET			;Exit

;************************************************************************************
;Name:	SeqInput, SeqInputT
;Function:	Multi-device character input w/optional timeout
;	SeqInput:  Do NOT reset timeout before scanning for input
;	SeqInputT: Reset timeout before scanning for input
;
;	A       <-  Data from selected port(s), NUL if nothing received
;	FmtCode  -> Input device selection/control flags:
;		Bit 0 : Serial port
;		Bit 1 : USB port
;		Bit 6 : Do not wait for data (scan once and exit)
;		Bit 7 : Enable timeout exit
;	CF      <-  CLEAR if data recived, SET if not (or timeout)
;	SeqBC   <-  SET if no data received
;	SeqWC   <-  SET if timeout expired
;
;Stack use:	7 bytes + CALL overhead (2 bytes)
;Destroyed:	FmtCode
;************************************************************************************

.SeqInputT	CLR	SeqIOCnt		;Reset I/O timeout counter
	BRESM	SeqIOT		;

.SeqInput	BRESM	SeqBC		;Byte carry set if no data
	BRESM	SeqWC		;Word carry set if timeout

SeqInput1	BTJF	FmtCode,#0,SeqInput2	;If input from serial port enabled:
	CALL	SCIIn		;Check for data from serial port
	JRNC	SeqInputX		;Exit if data received

SeqInput2	BTJF	FmtCode,#1,SeqInput3	;If input from USB port enabled:
	CALL	USBIn		;Check for data from USB port
	JRNC	SeqInputX		;Exit if data recieved

SeqInput3	BTJT	FmtCode,#6,SeqInputC	;Exit if only one pass allowed
	CALL	IntChk		;Check for interrupt conditions
	JRC	SeqInputC		;Exit if interrupt
	BTJF	FmtCode,#7,SeqInput1	;Don't check timeout if disabled
	BTJFM	SeqIOT,SeqInput1	;Continue send attempt until timeout

	BSETM	SeqWC		;Timeout occured
SeqInputC	BSETM	SeqBC		;No data recieved
	SCF			;CF=1 to indicate timeout/no data
	RET			;Exit

SeqInputX	INC	IOCount		;Increment received data count
	RCF			;CF=0 to indicate data received
	RET			;Exit (CF valid)

;************************************************************************************
;Name:	SeqOutputT, SeqOutput
;Function:	Multi-device character output w/optional timeout
;	SeqOutput: Do NOT reset timeout before attempting output
;	SeqOutputT: Reset timeout before attempting output
;
;	A        -> Data to send
;	FmtCode  -> Output device selection/control flags:
;		Bit 0 : Serial port
;		Bit 1 : USB port
;		Bit 2 : Front panel display
;		Bit 6 : Make only one attempt to output to each device
;		Bit 7 : Enable timeout exit
;	CF      <-  SET if output to any device unsuccessful
;	SeqBC   <- SET if output unsuccessful to one or more devices
;	SeqWC   <- SET if timeout expired
;
;Stack use:	15 bytes + CALL overhead (2 bytes)
;Destroyed:	Nothing
;************************************************************************************

.SeqOutputT	CLR	SeqIOCnt		;Reset I/O timeout counter
	BRESM	SeqIOT		;

.SeqOutput	BRESM	SeqBC		;Byte carry set if output unsuccessful
	BRESM	SeqWC		;Word carry set if timeout

	PUSH	X		;Save registers
	LD	X,FmtCode		;X <- FmtCode (restored on exit)

SeqOutput1	BTJF	FmtCode,#0,SeqOutput2	;If output to serial port enabled:
	CALL	SCIOut		;Attempt to send to serial port
	JRC	SeqOutput2		;If output successful:
	BRES	FmtCode,#0		; Done sending to serial port

SeqOutput2	BTJF	FmtCode,#1,SeqOutput3	;If output to USB port enabled:
	CALL	USBOut		;Attempt to send to USB port
	JRC	SeqOutput3		;If output successful:
	BRES	FmtCode,#1		; Done sending to USB port

SeqOutput3	BTJF	FmtCode,#2,SeqOutput4	;If output to front panel display:
	CALL	DAOut		;Send data to display
	BRES	FmtCode,#2		;Done sending to display

SeqOutput4	BTJT	FmtCode,#0,SeqOutput5	;Check if all devices serviced
	BTJT	FmtCode,#1,SeqOutput5	;
	BTJT	FmtCode,#2,SeqOutput5	;

	INC	IOCount		;Increment bytes sent counter
	JRA	SeqOutputC		;All devices serviced, exit

SeqOutput5	BTJT	FmtCode,#6,SeqOutput6	;Exit if only one pass allowed

	CALL	IntChk		;Check for interrupt conditions
	JRC	SeqOutput6		;Exit if interrupt

	BTJF	FmtCode,#7,SeqOutput1	;Don't check timeout if disabled
	BTJFM	SeqIOT,SeqOutput1	;Continue send attempt until timeout

	BSETM	SeqWC		;Timeout, set word carry

SeqOutput6	BSETM	SeqBC		;Output not fully successful
	SCF			;CF=1, output not successful
	JRA	SeqOutputX		;Exit

SeqOutputC	RCF			;CF=0, output successful
SeqOutputX	LD	FmtCode,X		;Restore FmtCode
	POP	X		;Restore registers
	RET			;Exit

;************************************************************************************
;Name:	Int2Asc
;Function:	Convert 16-bit integer to ASCII numeric
;
;	ObjPtr   -> Integer to convert
;	FWidth   -> Field width
;	Digits   -> Number of fixed digits
;	DecPos   -> Decimal point position
;	X        -> Output device selection / control flags (see SeqOutput)
;	A        -> Conversion base: 0=Binary, 1=Octal, 2=Decimal, 3=Hex
;	NumBuf  <-  <Arg1> converted to ASCII numeric
;	NumSize <-  Size of converted number
;
;Stack use:
;Destroyed:	A, X, Y, FmtCode, ChanMask
;************************************************************************************

.Int2Asc	LD	FmtCode,X		;Set ouput device & options
	PUSH	A		;Save conversion base

	LD	X,Digits		;X <- # digits
	LD	Y,DecPos		;Y <- Decimal position
	CALL	NBPrep		;Prepare NumBuf for conversion

	POP	X		;Get conversion base code
	SLL	X		;*2 for word index
	LD	A,(BaseVTbl,X)	;Copy vector to StrPtr
	LD	StrPtrH,A		;
	LD	A,({BaseVTbl+1},X)	;
	LD	StrPtrL,A		;

	LD	Y,ObjPtrH		;Y,X <- Integer to convert
	LD	X,ObjPtrL		;
	CALL	[StrPtr.W]		;Perform integer to ASCII conversion

;	Fall through to SendNum

;************************************************************************************
;Name:	SendNum
;Function:	Transmit contents of NumBuf to selected device(s)
;
;	FmtCode  -> Output device selection / control flags (see SeqOutput)
;	FWidth   -> Requested field width
;	NumSize  -> Size of converted number (before padding)
;	CF      <-  SET if timeout during transmission
;
;Stack use:	16 bytes + CALL overhead (2 bytes)
;Destroyed:	A, X, Y, FmtCode
;************************************************************************************

SendNum	CLR	SeqIOCnt		;Reset I/O timeout counter
	BRESM	SeqIOT		;

	LD	A,FWidth		;Get requested field width
	SUB	A,NumSize		;Subtract actual number size
	JRULE	SendNum2		;No padding needed if FW <= #size

	LD	Y,A		;Y <- Pad counter
	LD	A,#' '		;Pad with spaces
SendNum1	CALL	SeqOutputT		;Send space
	JRC	SendNumX		;Exit if timeout
	DEC	Y		;Decrement pad count
	JRNE	SendNum1		;Continue until padding sent

SendNum2	CLR	Y		;Reset buffer index
SendNum3	LD	A,(NumBuf,Y)	;Get data from buffer
	JREQ	SendNum4		;Don't send if null
	CALL	SeqOutputT		;Send digit/char
	JRC	SendNumX		;Exit if timeout
SendNum4	INC	Y		;Increment buffer index
	CP	Y,#NumBufSz		;End of buffer ?
	JRULT	SendNum3		; No, continue scan/send

	RCF			;No errors
SendNumX	RET			;Exit

;************************************************************************************
;Name:	SetArrayS
;Function:	Setup for block operation out of a source array
;
;	X   -> Pointer to argument block containing source array information
;	Y   -> Pointer to word location to save array pointer
;
;Stack use:	CALL overhead (2 bytes)
;Destroyed:	A,X
;************************************************************************************

SetArrayS	LD	A,(ArgCtrlOfs,X)	;Get argument control flags
	BCP	A,#{ArgConst?+ArgEE?}	;If source is EEPROM or constant:
	JRNE	SetArrayPK		; Use value register as source
	JRA	SetArrayP		; Otherwise, use arg ptr as source

;************************************************************************************
;Name:	SetArrayD
;Function:	Setup for block operation into a destination array
;
;	X   -> Pointer to argument block containing destination array information
;	Y   -> Pointer to word location to save array pointer
;	A  <-  Error code (if CF set)
;	CF <-  SET if error occurs
;
;Stack use:	CALL overhead (2 bytes)
;Destroyed:	A,X
;************************************************************************************

SetArrayD	LD	A,(ArgCtrlOfs,X)	;Get argument control flags
	BCP	A,#ArgConst?	;If destination is a constant:
	JREQ	SetArrayD1		;

;	Target is a constant, exit w/error

	LD	A,#SE_Const		;Cannot write constant
	SCF			;CF=1 to indicate error
	RET			;Exit

;	Target is EEPROM, set value register as target

SetArrayD1	BCP	A,#ArgEE?		;If target is EEPROM:
	JREQ	SetArrayP		;

	OR	A,#ArgSave?		;Set writeback flag
	LD	(ArgCtrlOfs,X),A	;
	JRA	SetArrayPK		;Set target address & exit

;	Target is RAM, argument pointer is target
;	(also used to set source address for SetArrayS)

SetArrayP	LD	A,(ArgPtrHOfs,X)	;A,X <- Target address (arg ptr)
	LD	X,(ArgPtrLOfs,X)	;
	JRA	SetArrayPX		;Set destination pointer & exit

;	Target is EEPROM/constant, argument value is target
;	(also used to set source address for SetArrayS)

SetArrayPK	BCP	A,#ArgWord?		;Check byte/word flag of target
	JRNE	SetArrayPW		;If target is a byte:
	INC	X		; Target addr +1 (point to LSB)
SetArrayPW	CLR	A		;Target address MSB always 0

;	Set target address & exit

SetArrayPX	LD	(Y),A		;Set target address MSB
	LD	A,X		;
	LD	(1,Y),A		;Set target address LSB

	RCF			;No-error exit
	RET			;

;************************************************************************************
;Name:	A_Reserved
;Function:	Argument parser for 'reserved' types; always returns an error (SE_Arg)
;************************************************************************************

A_Reserved	LD	A,#SE_Arg		;Return 'bad argument' error code
	SCF			;
	RET			;

;************************************************************************************
;Name:	A_Const4
;Function:	Argument parser for 4-bit constant
;************************************************************************************

A_Const4	AND	A,#%00001111	;Isolate constant (LSB)
	CLR	X		;MSB = 0
	LD	Y,#ArgConst?	;ArgCtrl flags

A_Const	LD	ArgCtrl,Y		;Set flags
	LD	ArgValL,A		;Save constant value
	LD	ArgValH,X		;
	LD	A,#ArgValH		;Pointer is irrelevant,
	LD	ArgPtrL,A		; point to a 'safe' spot
	CLR	ArgPtrH		;

	RCF			;No errors
A_ConstE	RET			;Exit

;************************************************************************************
;Name:	A_Const12
;Function:	Argument parser for 12-bit constant
;************************************************************************************

A_Const12	AND	A,#%00001111	;Isolate constant (MSB)
	LD	X,A		;
	CALL	Fetch		;Fetch LSB
	JRC	A_ConstE		;Exit if error

	LD	Y,#{ArgConst?+ArgWord?+1} ;ArgCtrl flags
	JRA	A_Const		;Save constant & exit

;************************************************************************************
;Name:	A_Const8
;Function:	Argument parser for 8-bit constant
;************************************************************************************

A_Const8	CALL	Fetch		;Fetch constant value (LSB)
	JRC	A_ConstE		;Exit if error
	CLR	X		;MSB = 0

	LD	Y,#ArgConst?	;ArgCtrl flags
	JRA	A_Const		;Save constant & exit

;************************************************************************************
;Name:	A_Const16
;Function:	Argument parser for 16-bit constant
;************************************************************************************

A_Const16	CALL	Fetch		;Fetch MSB
	JRC	A_ConstE		;Exit if error
	LD	X,A		;
	CALL	Fetch		;Fetch LSB
	JRC	A_ConstE		;Exit if error

	LD	Y,#{ArgConst?+ArgWord?+1} ;ArgCtrl flags
	JRA	A_Const		;Save constant & exit

;************************************************************************************
;Name:	A_RegB4
;Function:	Argument parser for 4-bit byte register reference
;************************************************************************************

A_RegB4	AND	A,#%00001111	;Isolate register index
	CLR	Y		;ArgCtrl flags

A_Reg	LD	ArgCtrl,A		;Save index for array size calculation

	CP	A,#NbrVars		;Valid register address?
	JRUGE	A_RegER		; No, exit w/error

	ADD	A,#{LOW Variables}	;Calculate variable address
	LD	ArgPtrL,A		;
	CLR	A		;
	ADC	A,#{HIGH Variables}	;
	LD	ArgPtrH,A		;

	LD	A,#NbrVars		;Calculate array size
	SCF			;
	SBC	A,ArgCtrl		;Max size = NbrVars - Reg index - 1
	CP	A,#16		;Upper limit is 16 elements
	JRULT	A_Reg1		;
	LD	A,#15		;
A_Reg1	LD	ArgCtrl,Y		;Merge control flags w/array size
	OR	A,ArgCtrl		;
	LD	ArgCtrl,A		;ArgCtrl <- Array size + flags

	CLR	ArgValH		;Assume byte, clear MSB
	LD	A,[ArgPtr.W]	;Get register value (LSB or MSB)
	BTJF	ArgCtrl,#ArgWord@,A_Reg2 ;If word sized:

	LD	ArgValH,A		;Save MSB
	LD	X,#1		;Point to LSB
	LD	A,([ArgPtr.W],X)	;Get MSB

A_Reg2	LD	ArgValL,A		;Save LSB

	RCF			;No errors
A_RegE	RET			;Exit

A_RegER	LD	A,#SE_Reg		;Invalid register address
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	A_RegW4
;Function:	Argument parser for 4-bit word register reference
;************************************************************************************

A_RegW4	AND	A,#%00001111	;Isolate register index
	LD	Y,#{ArgWord?+1}	;ArgCtrl flags
	JRA	A_Reg		;Fetch value, calculate address

;************************************************************************************
;Name:	A_RegB8
;Function:	Argument parser for 8-bit byte register reference
;************************************************************************************

A_RegB8	CALL	Fetch		;Fetch register address
	JRC	A_RegE		;Exit if error
	CLR	Y		;ArgCtrl flags
	JRA	A_Reg		;Fetch value, calculate address

;************************************************************************************
;Name:	A_RegW8
;Function:	Argument parser for 8-bit word register reference
;************************************************************************************

A_RegW8	CALL	Fetch		;Fetch register address
	JRC	A_RegE		;Exit if error
	LD	Y,#{ArgWord?+1}	;ArgCtrl flags
	JRA	A_Reg		;Fetch value, calculate address

;************************************************************************************
;Name:	A_IRegB4
;Function:	Argument parser for indirect byte register reference using a byte
;	register selected with a 4-bit address
;************************************************************************************

A_IRegB4	AND	A,#%00001111	;Isolate register address
	CLR	Y		;ArgCtrl flags

A_IReg	CP	A,#NbrVars		;Valid variable address ?
	JRUGE	A_RegER		; No, exit w/error

	LD	X,A		;X <- Variable address
	LD	A,(Variables,X)	;A <- Variable value
	JRA	A_Reg		;Use reg value as index

;************************************************************************************
;Name:	A_IRegW4
;Function:	Argument parser for indirect word register reference using a byte
;	register selected with a 4-bit address
;************************************************************************************

A_IRegW4	AND	A,#%00001111	;Isolate register address
	LD	Y,#{ArgWord?+1}	;ArgCtrl flags
	JRA	A_IReg		;Get variable value & use as index

;************************************************************************************
;Name:	A_IRegB8
;Function:	Argument parser for indirect byte register reference using a byte
;	register selected with a 8-bit address
;************************************************************************************

A_IRegB8	CALL	Fetch		;Get register address
	JRC	A_RegE		;Exit if error
	CLR	Y		;ArgCtrl flags
	JRA	A_IReg		;Get variable value & use as index

;************************************************************************************
;Name:	A_IRegW8
;Function:	Argument parser for indirect word register reference using a byte
;	register selected with a 8-bit address
;************************************************************************************

A_IRegW8	CALL	Fetch		;Get register address
	JRC	A_RegE		;Exit if error
	LD	Y,#{ArgWord?+1}	;ArgCtrl flags
	JRA	A_IReg		;Get variable value & use as index

;************************************************************************************
;Name:	A_ArrayC4
;Function:	Argument parser for internal array element indexed by a constant
;	4-bit index
;************************************************************************************

A_ArrayC4	AND	A,#%00001111	;Isolate array index

A_Array	LD	ArgCtrl,A		;Save array index

	CALL	Fetch		;Fetch array ID
	JRC	A_ArrayE		;Exit if error
	CP	A,#NbrArray.L	;Valid array ID ?
	JRUGE	A_ArrayEI		; No, exit w/error

	LD	X,A		;X <- Array ID
	SLL	X		;*2 for word index
	LD	A,({ArrayTbl+1},X)	;Get array address LSB
	ADD	A,ArgCtrl		;Add index
	LD	ArgPtrL,A		;Save

	LD	A,(ArrayTbl,X)	;Get array address MSB
	LD	X,A		;(save copy)
	AND	A,#%00001111	;Mask off max index bits
	ADC	A,#0		;Add carry from LSB
	LD	ArgPtrH,A		;Save address MSB

	LD	A,X		;A <- Array address MSB
	AND	A,#%11110000	;Isolate array max index
	SWAP	A		;Move to bits 0-3
	SUB	A,ArgCtrl		;Max index reduced by index
	JRULT	A_ArrayEX		; Exit if max index < specified index
	LD	ArgCtrl,A		;ArgCtrl <- Max array index, bytesized

	LD	A,[ArgPtr.W]	;Get array value (always byte)
	LD	ArgValL,A		;
	CLR	ArgValH		;MSB = 0

	RCF			;No errors
	RET			;Exit

A_ArrayEI	LD	A,#SE_ArrayID	;Invalid array ID
	SCF			;CF=1 to indicate error
	RET			;Exit

A_ArrayEX	LD	A,#SE_ArrayIdx	;Invalid array index
	SCF			;CF=1 to indicate error
	RET			;Exit

A_ArrayER	LD	A,#SE_Reg		;Invalid register address
	SCF			;CF=1 to indicate error
A_ArrayE	RET			;Exit

;************************************************************************************
;Name:	A_ArrayR8
;Function:	Argument parser for internal array element, indexed using a register
;	specified by a 8-bit address
;************************************************************************************

A_ArrayR8	CALL	Fetch		;Get register address
	JRC	A_ArrayE		;Exit if error

A_ArrayR	CP	A,#NbrVars		;Valid register address ?
	JRUGE	A_ArrayER		; No, exit w/error

	LD	X,A		;X <- Register address
	LD	A,(Variables,X)	;Get variable value, use as index
	JRA	A_Array		;Set up for array access & exit

;************************************************************************************
;Name:	A_ArrayR4
;Function:	Argument parser for internal array element, indexed using a register
;	specified by a 4-bit address
;************************************************************************************

A_ArrayR4	AND	A,#%00001111	;Isolate register address
	JRA	A_ArrayR		;Get register value, continue

;************************************************************************************
;Name:	A_CtrlVar
;Function:	Argument parser for internal control variable selected by a 8-bit
;	constant address
;************************************************************************************

A_CtrlVar	CALL	Fetch		;Get control variable index
	JRC	A_CtrlVX		;Exit if error

	CP	A,#NbrCtrlV.L	;Valid control variable index ?
	JRUGE	A_CtrlVEI		; No, exit w/error

	LD	X,A		;X <- Control variable index
	SLL	X		;*2 for word index
	LD	A,({CtrlVTbl+1},X)	;Get control variable address LSB
	LD	ArgPtrL,A		;Save

	CLR	Y		;Assume byte sized variable
	CLR	ArgValH		;

	LD	A,(CtrlVTbl,X)	;Get control variable address MSB
	JRPL	A_CtrlVar1		;If MSB set:
	LD	Y,#{ArgWord?+1}	; Var size is word
	AND	A,#$7F		; Clear word bit
A_CtrlVar1	LD	ArgPtrH,A		;Save variable address MSB

	LD	ArgCtrl,Y		;Save ArgCtrl flags
	LD	A,[ArgPtr.W]	;Get control variable value (MSB/LSB)
	BTJF	ArgCtrl,#ArgWord@,A_CtrlVar2 ;If word sized:

	LD	ArgValH,A		;Save value MSB
	LD	X,#1		;Point to LSB
	LD	A,([ArgPtr.W],X)	;Get value LSB
A_CtrlVar2	LD	ArgValL,A		;Save value LSB

	RCF			;No errors
	RET			;Exit

A_CtrlVEI	LD	A,#SE_CVIdx		;Invalid control variable index
	SCF			;CF=1 to indicate error
A_CtrlVX	RET			;Exit

;************************************************************************************
;Name:	A_FileRB
;Function:	Argument parser for file byte read
;************************************************************************************

A_FileRB	LD	A,#{ArgEE?+ArgConst?}	;ArgCtrl flags: read byte

A_FileIO	LD	ArgCtrl,A		;Save argument control flags

	LD	A,FilePosL		;Set writeback pointer
	LD	ArgPtrL,A		;to current file position
	LD	A,FilePosH		;
	LD	ArgPtrH,A		;

	CLR	ArgValH		;Assume byte read, MSB=0
	CALL	FileRead		;Read byte from file
	JRC	A_FileIOE		;Exit if error
	BTJF	ArgCtrl,#ArgWord@,A_FileIO1 ;If byte read, save LSB & exit
	LD	ArgValH,A		;Save first byte read as MSB

	CALL	FileRead		;Read byte from file
	JRC	A_FileIOE		;Exit if error
A_FileIO1	LD	ArgValL,A		;Save data LSB

	RCF			;No errors
	RET			;Exit

A_FileIOE	LD	A,#SE_FileIO	;File I/O error
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	A_FileRW
;Function:	Argument parser for file word read
;************************************************************************************

A_FileRW	LD	A,#{ArgEE?+ArgWord?+ArgConst?+1} ;ArgCtrl flags: read word
	JRA	A_FileIO		;Read from file & exit

;************************************************************************************
;Name:	A_FileRWB
;Function:	Argument parser for file byte read & write
;************************************************************************************

A_FileRWB	LD	A,#ArgEE?		;ArgCtrl flags: read/write byte
	JRA	A_FileIO		;Read from file & exit

;************************************************************************************
;Name:	A_FileRWW
;Function:	Argument parser for file word read & write
;************************************************************************************

A_FileRWW	LD	A,#{ArgEE?+ArgWord?+1}	;ArgCtrl flags: read/write word
	JRA	A_FileIO		;Read from file & exit

;************************************************************************************
;Name:	A_FileWB
;Function:	Argument parser for file byte write-only (read returns 0)
;************************************************************************************

A_FileWB	LD	A,#ArgEE?		;ArgCtrl flags: write byte

A_FileWr	BTJFM	FileRO,A_FileWr1	;If file is read-only, then
	OR	A,#ArgConst?	; protect by forcing constant mode
A_FileWr1	LD	ArgCtrl,A		;Save argument control flags

	CALL	FileCheck		;Ensure file pointer is valid
	JRC	A_FileIOE		; Exit w/error if not

	SRL	A		;CF=1 if word operation

	LD	A,FilePosL		;Get file position pointer
	LD	X,FilePosH		;
	LD	ArgPtrL,A		;Save as EEPROM write-back pointer
	LD	ArgPtrH,X		;

	ADC	A,#1		;Advance file pointer (+1 or +2)
	LD	FilePosL,A		;
	JRNC	A_FileWr2		;
	INC	FilePosH		;

A_FileWr2	CALL	FileCheck		;Check updated FilePos for EOF cond.
	CLR	ArgValL		;Read always returns 0
	CLR	ArgValH		;

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	A_FileWW
;Function:	Argument parser for file word write-only (read returns 0)
;************************************************************************************

A_FileWW	LD	A,#{ArgEE?+ArgWord?+1}	;ArgCtrl flags: write word
	JRA	A_FileWr		;Set up for write & exit

;************************************************************************************
;Name:	A_RAMBC8
;Function:  Argument parser for a byte RAM location specified by a constant
;	8-bit address
;************************************************************************************

A_RAMBC8	CALL	Fetch		;Fetch RAM address
	JRC	A_RAME		;Exit if error
	CLR	X		;Address MSB=0
	LD	Y,#$0F		;ArgCtrl flags

A_RAM	LD	ArgCtrl,Y		;Save ArgCtrl flags

	LD	ArgPtrH,X		;Save RAM address
	LD	ArgPtrL,A		;

	CLR	ArgValH		;Assume byte, clear MSB
	LD	A,[ArgPtr.W]	;Get value from RAM (MSB/LSB)
	BTJF	ArgCtrl,#ArgWord@,A_RAM1 ;If word sized:

	LD	ArgValH,A		;Save value MSB
	LD	X,#1		;Point to LSB
	LD	A,([ArgPtr.W],X)	;Get value LSB
A_RAM1	LD	ArgValL,A		;Save value LSB

	RCF			;No errors
A_RAME	RET			;Exit

;************************************************************************************
;Name:	A_RAMWC8
;Function:  Argument parser for a word RAM location specified by a constant
;	8-bit address
;************************************************************************************

A_RAMWC8	CALL	Fetch		;Fetch RAM address
	JRC	A_RAME		;Exit if error
	CLR	X		;Address MSB=0
	LD	Y,#{ArgWord?+$0F}	;ArgCtrl flags
	JRA	A_RAM		;Set up for RAM access & exit

;************************************************************************************
;Name:	A_RAMBC16
;Function:  Argument parser for a byte RAM location specified by a constant
;	16-bit address
;************************************************************************************

A_RAMBC16	CALL	Fetch		;Fetch RAM address MSB
	JRC	A_RAME		;Exit if error
	LD	X,A		;X <- Address MSB

	CALL	Fetch		;Fetch RAM address LSB
	JRC	A_RAME		;Exit if error

	LD	Y,#$0F		;ArgCtrl flags
	JRA	A_RAM		;Set up for RAM access & exit

;************************************************************************************
;Name:	A_RAMWC16
;Function:  Argument parser for a word RAM location specified by a constant
;	16-bit address
;************************************************************************************

A_RAMWC16	CALL	Fetch		;Fetch RAM address MSB
	JRC	A_RAME		;Exit if error
	LD	X,A		;X <- Address MSB

	CALL	Fetch		;Fetch RAM address LSB
	JRC	A_RAME		;Exit if error

	LD	Y,#{ArgWord?+$0F}	;ArgCtrl flags
	JRA	A_RAM		;Set up for RAM access & exit

;************************************************************************************
;Name:	A_RAMBV
;Function:	Argument parser for a byte RAM location indexed by a register
;************************************************************************************

A_RAMBV	LD	Y,#$0F		;ArgCtrl flags

A_RAMV	CALL	Fetch		;Fetch variable address
	JRC	A_RAME		;Exit if error

	CP	A,#{NbrVars-1}	;Valid variable address ?
	JRUGE	A_RAMER		; No, exit w/error

	LD	X,A		;X <- Variable address
	LD	A,({Variables+1},X)	;A <- Variable address LSB
	LD	X,(Variables,X)	;X <- Variable address MSB

	JRA	A_RAM		;Set up for RAM access & exit

A_RAMER	LD	A,#SE_Reg		;Invalid register address
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	A_RAMWV
;Function:	Argument parser for a word RAM location indexed by a register
;************************************************************************************

A_RAMWV	LD	Y,#{ArgWord?+$0F}	;ArgCtrl flags

	JRA	A_RAMV		;Get var value, setup for RAM access

;************************************************************************************
;Name:	A_PMemBC
;Function:	Argument parser for a byte in program memory (RAM or EEPROM), with
;	address specified by a 16-bit constant
;************************************************************************************

A_PMemBC	CLR	A		;ArgCtrl flags

	JRA	A_PMemC		;Fetch value from program space & exit

;************************************************************************************
;Name:	A_PMemWC
;Function:	Argument parser for a word in program memory (RAM or EEPROM), with
;	address specified by a 16-bit constant
;************************************************************************************

A_PMemWC	LD	A,#{ArgWord?+1}	;ArgCtrl flags

	JRA	A_PMemC		;Fetch value from program space & exit

;************************************************************************************
;Name:	A_PMemBR
;Function:	Argument parser for a byte in program memory (RAM or EEPROM), with
;	address specified by a word register specified by a 8-bit address
;************************************************************************************

A_PMemBR	CLR	A		;ArgCtrl flags

	JRA	A_PMemR		;Fetch value from program space & exit

;************************************************************************************
;Name:	A_PMemWR
;Function:	Argument parser for a word in program memory (RAM or EEPROM), with
;	address specified by a word register specified by a 8-bit address
;************************************************************************************

A_PMemWR	LD	A,#{ArgWord?+1}	;ArgCtrl flags

;	Entry point for program memory access via register

A_PMemR	LD	ArgCtrl,A		;Save ArgCtrl flags (EE updated later)

	CALL	Fetch		;Get variable address
	JRC	A_PMemE		;Exit if read error

	CP	A,#{NbrVars-1}	;Check for valid variable address
	JRUGE	A_PMemER		;Exit if invalid address

	LD	X,A		;X <- Variable index
	LD	A,(Variables,X)	;
	LD	Y,A		;Y <- Offset address MSB
	LD	X,({Variables+1},X)	;X <- Offset address LSB

	JRA	A_PMem		;Calculate & check address

;	Entry point for program memory access via constant long address

A_PMemC	LD	ArgCtrl,A		;Save ArgCtrl flags (EE updated later)

	CALL	Fetch		;Get address MSB
	JRC	A_PMemE		;Exit if read error
	LD	Y,A		;Y <- Offset address MSB
	CALL	Fetch		;Get address LSB
	JRC	A_PMemE		;Exit if read error
	LD	X,A		;X <- Offset address LSB

;	Common code for program memory access
;	Calculate absolute address and validate

A_PMem	LD	A,X		;Calculate absolute address:
	ADD	A,SeqStartL		;Addr = Offset + SeqStart
	LD	ArgPtrL,A		;
	LD	A,Y		;
	ADC	A,SeqStartH		;
	LD	ArgPtrH,A		;

	LD	X,#ArgPtr		;Check if address within bounds
	CALL	AddrCheck		;
	JRC	A_PMemEB		;Error if outside bounds

A_PMem1	CLR	ArgValH		;Assume byte read
	BTJTM	FetchRAM,A_PMem3	;If program in EEPROM:

;	Read from EEPROM

	BSET	ArgCtrl,#ArgEE@	;Operand is in EEPROM
	CALL	EERelease		;EEPROM offline

	LD	A,ArgPtrL		;Copy address to EEPROM address ptr
	LD	EEPtrL,A		;
	LD	A,ArgPtrH		;
	LD	EEPtrH,A		;

	BTJF	ArgCtrl,#ArgWord@,A_PMem2 ;If word read:

	SCF			;Sequential read mode
	CALL	EERead		;Read program data MSB
	JRNE	A_PMemEM		;Exit if read error
	LD	ArgValH,A		;Save data MSB

A_PMem2	RCF			;Terminate read
	CALL	EERead		;Read program data LSB
	JRNE	A_PMemEM		;Exit if read error
	LD	ArgValL,A		;Save data LSB

	RCF			;No errors
	RET			;Exit

;	Read from RAM

A_PMem3	LD	A,[ArgPtr.W]	;Get value from RAM (MSB/LSB)
	BTJF	ArgCtrl,#ArgWord@,A_PMem4 ;If word sized:

	LD	ArgValH,A		;Save value MSB
	LD	X,#1		;Point to LSB
	LD	A,([ArgPtr.W],X)	;Get value LSB
A_PMem4	LD	ArgValL,A		;Save value LSB

	RCF			;No errors
	RET			;Exit

;	Error exits

A_PMemER	LD	A,#SE_Reg		;Invalid register address
	SCF			;CF=1 to indicate error
	RET			;Exit

A_PMemEB	LD	A,#SE_Bound		;Attempt to R/W outside program area
	SCF			;CF=1 to indicate error
	RET			;Exit

A_PMemEM	LD	A,#SE_Mem		;Memory R/W error
	SCF			;CF=1 to indicate error
A_PMemE	RET			;Exit

;************************************************************************************
;Name:	A_EEBC
;Function:	Argument parser for a byte EEPROM location specified by a
;	constant 16-bit address
;************************************************************************************

A_EEBC	LD	Y,#ArgEE?		;ArgCtrl flags

A_EEConst	CALL	Fetch		;Get EEPROM address MSB
	JRC	A_EEErr		;Exit if error
	LD	X,A		;X <- MSB
	CALL	Fetch		;Get EEPROM address LSB
	JRC	A_EEErr		;Exit if error

A_EERead	CALL	EERelease		;EEPROM offline
	LD	ArgCtrl,Y		;Save ArgCtrl flags
	LD	ArgPtrH,X		;Set pointer and EEPROM address
	LD	EEPtrH,X		;
	LD	ArgPtrL,A		;
	LD	EEPtrL,A		;

	CLR	ArgValH		;Assume byte read
	BTJF	ArgCtrl,#ArgWord@,A_EEConst1 ;If word access:

;	SCF			;Sequential read mode
	CALL	EERead		;Read EEPROM value MSB
	JRNE	A_EEErrM		;Error if could not read
	LD	ArgValH,A		;Save MSB

A_EEConst1	RCF			;Terminate read
	CALL	EERead		;Read EEPROM value LSB
	JRNE	A_EEErrM		;Error if could not read
	LD	ArgValL,A		;Save LSB

	RCF			;No errors
	RET			;Exit

A_EEErrM	LD	A,#SE_Mem		;Memory R/W error
	SCF			;CF=1 to indicate error
	RET			;Exit w/error

A_EEErrR	LD	A,#SE_Reg		;Invalid variable address
	SCF			;CF=1 to indicate error
A_EEErr	RET			;Exit w/error

;************************************************************************************
;Name:	A_EEWC
;Function:	Argument parser for a word EEPROM location specified by a
;	constant 16-bit address
;************************************************************************************

A_EEWC	LD	Y,#{ArgEE?+ArgWord?+1}	;ArgCtrl flags

	JRA	A_EEConst		;Fetch address, EEPROM value

;************************************************************************************
;Name:	A_EEBV
;Function:	Argument parser for a byte EEPROM location specified by a
;	word variable indexed with a 8-bit address
;************************************************************************************

A_EEBV	LD	Y,#ArgEE?		;ArgCtrl flags

A_EEVar	CALL	Fetch		;Get variable address
	JRC	A_EEErr		;Exit if error

	CP	A,#NbrVars		;Valid variable address?
	JRUGE	A_EEErrR		; No, exit w/error

	LD	X,A		;X <- Variable address
	LD	A,({Variables+1},X)	;A <- Variable value LSB
	LD	X,(Variables,X)	;X <- Variable value MSB

	JRA	A_EERead		;Read EEPROM value & exit

;************************************************************************************
;Name:	A_EEWV
;Function:	Argument parser for a word EEPROM location specified by a
;	word variable indexed with a 8-bit address
;************************************************************************************

A_EEWV	LD	Y,#{ArgEE?+ArgWord?+1}	;ArgCtrl flags

	JRA	A_EEVar		;Fetch variable & EEPROM data

;************************************************************************************
;Name:	O_NOP		NOP
;Operation:	No operation
;************************************************************************************

O_NOP	RET			;No operation, exit (CF=0)

;************************************************************************************
;Name:	O_MOVE		MOVE	dest,src
;Operation:	Copy <src> to <dest>
;************************************************************************************

O_MOVE	LD	A,Arg2H		;Arg1 <- Arg2
	LD	Arg1H,A		;
	LD	A,Arg2L		;
	LD	Arg1L,A		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_ZERO		ZERO	dest
;Operation:	Set <dest> to 0
;************************************************************************************

O_ZERO	CLR	Arg1H		;Arg1 <- 0
	CLR	Arg1L		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_XCHA		XCHA	a,b
;Operation:	Exchange the contents of <a> and <b>
;************************************************************************************

O_XCHA	LD	X,Arg1H		;X,Y <- Arg1
	LD	Y,Arg1L		;

	LD	A,Arg2H		;Arg1 <- Arg2
	LD	Arg1H,A		;
	LD	A,Arg2L		;
	LD	Arg1L,A		;

	LD	Arg2H,X		;Arg2 <- Arg1
	LD	Arg2L,Y		;

	BSET	Arg2Ctrl,#ArgSave@	;Save argument 2
	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_XCHB		XCHB	a
;Operation:	Exchange low and high byte of <a>
;************************************************************************************

O_XCHB	LD	A,Arg1L		;X,A <- Arg1
	LD	X,Arg1H		;

	LD	Arg1L,X		;Arg1 <- A,X
	LD	Arg1H,A		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_XCHN		XCHN	a
;Operation:	Nibble-swap high and low bytes of [a]
;	a[15..12] <-> a[11..8]
;	a[7..4] <-> a[0..3]
;************************************************************************************

O_XCHN	SWAP	Arg1L		;Swap LSB nibbles
	SWAP	Arg1H		;Swap MSB nibbles

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_ADD		ADD	dest,src
;Operation:	<dest> = <dest> + <src>
;************************************************************************************

O_ADD	BRESM	SeqBC		;Reset carry flags
	BRESM	SeqWC		;

	LD	A,Arg1L		;Add LSB's
	ADD	A,Arg2L		;
	LD	Arg1L,A		;
	JRNC	O_ADD1		;Set byte carry
	BSETM	SeqBC		;

O_ADD1	LD	A,Arg1H		;Add MSB's
	ADC	A,Arg2H		;
	LD	Arg1H,A		;
	JRNC	O_ADD2		;Set word carry
	BSETM	SeqWC		;

O_ADD2	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_SUB		SUB	dest,src
;Operation:	<dest> = <dest> - <src>
;************************************************************************************

O_SUB	BRESM	SeqBC		;Reset carry flags
	BRESM	SeqWC		;

	LD	A,Arg1L		;Subtract LSB's
	SUB	A,Arg2L		;
	LD	Arg1L,A		;
	JRNC	O_SUB1		;Set byte carry
	BSETM	SeqBC		;

O_SUB1	LD	A,Arg1H		;Subtract MSB's
	SBC	A,Arg2H		;
	LD	Arg1H,A		;
	JRNC	O_SUB2		;Set word carry
	BSETM	SeqWC		;

O_SUB2	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_INC		INC	a
;Operation:	<a> = <a> + 1
;************************************************************************************

O_INC	BRESM	SeqBC		;Reset carry flags
	BRESM	SeqWC		;

	INC	Arg1L		;Increment LSB
	JRNE	O_INC1		;
	BSETM	SeqBC		;Set byte carry if overflow

	INC	Arg1H		;Increment MSB
	JRNE	O_INC1		;
	BSETM	SeqWC		;Set word carry if overflow

O_INC1
O_Save1X	BSET	Arg1Ctrl,#ArgSave@	;Save argument 1
	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_INCBC		INCBC	a
;Operation:	<a> = <a> + 1 if byte carry set
;************************************************************************************

O_INCBC	BTJTM	SeqBC,O_INC		;Increment if byte carry set
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_INCWC		INCWC	a
;Operation:	<a> = <a> + 1 if word carry set
;************************************************************************************

O_INCWC	BTJTM	SeqWC,O_INC		;Increment if word carry set
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_DEC		DEC	a
;Operation:	<a> = <a> - 1
;************************************************************************************

O_DEC	BRESM	SeqBC		;Reset carry flags
	BRESM	SeqWC		;

	LD	A,Arg1L		;Decrement LSB
	SUB	A,#1		;
	LD	Arg1L,A		;
	JRNC	O_DEC1		;
	BSETM	SeqBC		;Set byte carry if underflow

	LD	A,Arg1H		;Decrement MSB
	SUB	A,#1		;
	LD	Arg1H,A		;
	JRNC	O_DEC1		;
	BSETM	SeqWC		;Set word carry if underflow

O_DEC1	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_DECBC		DECBC	a
;Operation:	<a> = <a> - 1 if byte carry set
;************************************************************************************

O_DECBC	BTJTM	SeqBC,O_DEC		;Decrement if byte carry set
	RET			;Otherwise exit (CF=0)

;************************************************************************************
;Name:	O_DECWC		DECWC	a
;Operation:	<a> = <a> - 1 if word carry set
;************************************************************************************

O_DECWC	BTJTM	SeqWC,O_DEC		;Decrement if byte carry set
	RET			;Otherwise exit (CF=0)

;************************************************************************************
;Name:	O_INV		INV	a
;Operation:	<a> = <a> ^ $FFFF
;************************************************************************************

O_INV	CPL	Arg1H		;Invert <a>
	CPL	Arg1L		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_CPL2		CPL2	a
;Operation:	<a> = (<a> ^ $FFFF) + 1)
;************************************************************************************

O_CPL2	CPL	Arg1H		;Invert <a>
	CPL	Arg1L		;

	JRA	O_INC		;Add 1 & exit

;************************************************************************************
;Name:	O_AND		AND	dest,src
;Operation:	<dest> = <dest> & <src>
;************************************************************************************

O_AND	LD	A,Arg1H		;AND MSB's
	AND	A,Arg2H		;
	LD	Arg1H,A		;

	LD	A,Arg1L		;AND LSB's
	AND	A,Arg2L		;
	LD	Arg1L,A		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_OR		OR	dest,src
;Operation:	<dest> = <dest> | <src>
;************************************************************************************

O_OR	LD	A,Arg1H		;OR MSB's
	OR	A,Arg2H		;
	LD	Arg1H,A		;

	LD	A,Arg1L		;OR LSB's
	OR	A,Arg2L		;
	LD	Arg1L,A		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_XOR		XOR	dest,src
;Operation:	<dest> = <dest> ^ <src>
;************************************************************************************

O_XOR	LD	A,Arg1H		;XOR MSB's
	XOR	A,Arg2H		;
	LD	Arg1H,A		;

	LD	A,Arg1L		;XOR LSB's
	XOR	A,Arg2L		;
	LD	Arg1L,A		;

	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_ANDOR		ANDOR	dest,a,o
;Operation:	<dest> = <dest> ^ <a> | <o>
;************************************************************************************

O_ANDOR	LD	A,Arg1H		;MSB:
	AND	A,Arg2H		; AND
	OR	A,Arg3H		; OR
	LD	Arg1H,A		; Save

	LD	A,Arg1L		;LSB:
	AND	A,Arg2L		; AND
	OR	A,Arg3L		; OR
	LD	Arg1L,A		; Save

O_Save1Xa	JRA	O_Save1X		;Save arg 1, no error exit

;************************************************************************************
;Name:	O_SHL		SHL	a
;Operation:	Shift <a> left
;************************************************************************************

O_SHL	RCF			;Shift in 0

O_DoSHL	CALLR	O_ClearCF		;Clear carries by default

	RLC	Arg1L		;Shift LSB left
	JRNC	O_SHL1		;If CF set,
	BSETM	SeqBC		; set byte carry

O_SHL1	RLC	Arg1H		;Shift MSB left
	JRNC	O_SHL2		;If CF set,
	BSETM	SeqWC		; set word carry

O_SHL2	JRA	O_Save1Xa		;Save arg 1 & exit

;************************************************************************************
;Name:	O_SHLBC		SHLBC	a
;Operation:	Shift <a> left, shifting in byte carry
;************************************************************************************

O_SHLBC	BTJFM	SeqBC,O_DoSHL	;Set CF based on byte carry
	JRA	O_DoSHL		;Perform shift operation, CF=1

;************************************************************************************
;Name:	O_SHLWC		SHLWC	a
;Operation:	Shift <a> left, shifting in word carry
;************************************************************************************

O_SHLWC	BTJFM	SeqWC,O_DoSHL	;Set CF based on word carry
	JRA	O_DoSHL		;Perform shift operation, CF=1

;************************************************************************************
;Name:	O_SHR		SHR	a
;Operation:	Shift <a> right
;************************************************************************************

O_SHR	RCF			;Shift in 0

O_DoSHR	CALLR	O_ClearCF		;Clear carries by default

	LD	A,Arg1Ctrl		;Check operand size
	BCP	A,#ArgWord?		;(cannot use BTFJ, changes CF)
	JREQ	O_SHR1		;Skip MSB shift if byte-sized

	RRC	Arg1H		;Shift MSB right
	JRNC	O_SHR1		;If CF set,
	BSETM	SeqWC		; set word carry

O_SHR1	RRC	Arg1L		;Shift LSB right
	JRNC	O_SHR2		;If CF set,
	BSETM	SeqBC		; set byte carry

O_SHR2	JRA	O_Save1Xa		;Save arg 1 & exit

;************************************************************************************
;Name:	O_SHRBC		SHRBC	a
;Operation:	Shift <a> right, shifting in byte carry
;************************************************************************************

O_SHRBC	BTJFM	SeqBC,O_DoSHR	;Set CF based on byte carry
	JRA	O_DoSHR		;Perform shift operation (CF=1)

;************************************************************************************
;Name:	O_SHRWC		SHRWC	a
;Operation:	Shift <a> right, shifting in word carry
;************************************************************************************

O_SHRWC	BTJFM	SeqWC,O_DoSHR	;Set CF based on word carry
	JRA	O_DoSHR		;Perform shift operation (CF=1)

;************************************************************************************
;Name:	O_CLRBC		CLRBC
;Operation:	Clear byte carry
;************************************************************************************

O_ClearCF	BRESM	SeqWC		;Clear word carry
O_CLRBC	BRESM	SeqBC		;Clear byte carry
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_CLRWC		CLRWC
;Operation:	Clear word carry
;************************************************************************************

O_CLRWC	BRESM	SeqWC		;Clear word carry
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_SETBC		SETBC
;Operation:	Set byte carry
;************************************************************************************

O_SETBC	BSETM	SeqBC		;Set byte carry
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_SETWC		SETWC
;Operation:	Set word carry
;************************************************************************************

O_SETWC	BSETM	SeqWC		;Set word carry
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_JLT		JLT	a,b,dest
;Operation:	Jump to <dest> if <a> < <b>
;************************************************************************************

O_JLT	LD	A,Arg1H		;Check if Arg1 < Arg2
	CP	A,Arg2H		;
	JRULT	O_JArg3		;
	JRUGT	O_JmpX		;
	LD	A,Arg1L		;
	CP	A,Arg2L		;
	JRUGE	O_JmpX		;

O_JArg3	LD	X,#Arg3		;Jump to <Arg3>
	JP	O_DoJMP		;

;************************************************************************************
;Name:	O_JLE		JLE	a,b,dest
;Operation:	Jump to <dest> if <a> <= <b>
;************************************************************************************

O_JLE	LD	A,Arg1H		;Check if Arg1 <= Arg2
	CP	A,Arg2H		;
	JRULT	O_JArg3		;
	JRUGT	O_JmpX		;
	LD	A,Arg1L		;
	CP	A,Arg2L		;
	JRUGT	O_JmpX		;
	JRA	O_JArg3		;Jump to <Arg3>

;************************************************************************************
;Name:	O_JEQ		JEQ	a,b,dest
;Operation:	Jump to <dest> if <a> = <b>
;************************************************************************************

O_JEQ	LD	A,Arg1H		;Check if Arg1 = Arg2
	CP	A,Arg2H		;
	JRNE	O_JmpX		;
	LD	A,Arg1L		;
	CP	A,Arg2L		;
	JRNE	O_JmpX		;

	JRA	O_JArg3		;

;************************************************************************************
;Name:	O_JNE		JNE	a,b,dest
;Operation:	Jump to <dest> if <a> <> <b>
;************************************************************************************

O_JNE	LD	A,Arg1H		;Check if Arg1 <> Arg2
	CP	A,Arg2H		;
	JRNE	O_JArg3		;
	LD	A,Arg1L		;
	CP	A,Arg2L		;
	JREQ	O_JmpX		;
	JRA	O_JArg3		;Jump to <Arg3>

;************************************************************************************
;Name:	O_JGE		JGE	a,b,dest
;Operation:	Jump to <dest> if <a> >= <b>
;************************************************************************************

O_JGE	LD	A,Arg1H		;Check if Arg1 >= Arg2
	CP	A,Arg2H		;
	JRUGT	O_JArg3		;
	JRULT	O_JmpX		;
	LD	A,Arg1L		;
	CP	A,Arg2L		;
	JRULT	O_JmpX		;
	JRA	O_JArg3		;Jump to <Arg3>

;************************************************************************************
;Name:	O_JGT		JGT	a,b,dest
;Operation:	Jump to <dest> if <a> > <b>
;************************************************************************************

O_JGT	LD	A,Arg1H		;Check if Arg1 > Arg2
	CP	A,Arg2H		;
	JRUGT	O_JArg3		;
	JRULT	O_JmpX		;
	LD	A,Arg1L		;
	CP	A,Arg2L		;
	JRULE	O_JmpX		;
	JRA	O_JArg3		;Jump to <Arg3>

;************************************************************************************
;Name:	O_JZ		JZ	a,dest
;Operation:	Jump to <dest> if <a> = 0
;************************************************************************************

O_JZ	LD	A,Arg1H		;Check if Arg1 = 0
	OR	A,Arg1L		;
	JRNE	O_JmpX		;

O_JArg2	LD	X,#Arg2		;Jump to <Arg2>
	JRA	O_DoJMP		;

;************************************************************************************
;Name:	O_JNZ		JNZ	a,dest
;Operation:	Jump to <dest> if <a> <> 0
;************************************************************************************

O_JNZ	LD	A,Arg1H		;Check if Arg1 <> 0
	OR	A,Arg1L		;
	JREQ	O_JmpX		;
	JRA	O_JArg2		;Jump to <Arg2>

;************************************************************************************
;Name:	O_JBCC		JBCC	dest
;Operation:	Jump to <dest> if byte carry clear
;************************************************************************************

O_JBCC	BTJFM	SeqBC,O_JMP		;Jump to <Arg1> if byte carry clear

O_JmpX	RCF			;No errors
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_JWCC		JWCC	dest
;Operation:	Jump to <dest> if word carry clear
;************************************************************************************

O_JWCC	BTJFM	SeqWC,O_JMP		;Jump to <Arg1> if word carry clear

	RCF			;
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_JNEOF		JNEOF	dest
;Operation:	Jump to <dest> if not at end-of-file
;************************************************************************************

O_JNEOF	BTJFM	FileEOF,O_JMP	;Jump to <Arg1> if at end-of-file

	RCF			;
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_JBCS		JBCS	dest
;Operation:	Jump to <dest> if byte carry set
;************************************************************************************

O_JBCS	BTJTM	SeqBC,O_JMP		;Jump to <Arg1> if byte carry set

	RET			;Exit

;************************************************************************************
;Name:	O_JWCS		JWCS	dest
;Operation:	Jump to <dest> if word carry set
;************************************************************************************

O_JWCS	BTJTM	SeqWC,O_JMP		;Jump to <Arg1> if word carry set

	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_JEOF		JEOF	dest
;Operation:	Jump to <dest> if at end-of-file
;************************************************************************************

O_JEOF	BTJTM	FileEOF,O_JMP	;Jump to <Arg1> if at end-of-file

	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_JMP		JMP	dest
;Operation:	Unconditional jump to <dest>
;************************************************************************************

O_JMP	LD	X,#Arg1		;Arg1 has JMP address

O_DoJMP	LD	A,SeqStartL		;Compute new PC address
	ADD	A,(ArgLOfs,X)	;
	LD	SeqPCL,A		;
	LD	A,SeqStartH		;
	ADC	A,(ArgHOfs,X)	;
	LD	SeqPCH,A		;
	JRC	O_JmpErr		;If MSB overflow, address invalid

O_ChkJMP	LD	X,#SeqPC		;Check if new PC is valid
	CALL	AddrCheck		;CF=1 if invalid PC
O_JmpErr	LD	A,#SE_Bound		;Bounds error if CF=1
	RET			;Exit

;************************************************************************************
;Name:	O_JBS		JBS	a,b,dest
;Operation:	Jump to <dest> if any bits in <a> specified by mask <b> are set
;************************************************************************************

O_JBS	LD	X,#Arg3		;<Arg3> has jump address

	LD	A,Arg1L		;Check if any bits set
	AND	A,Arg2L		;
	JRNE	O_DoJMP		;
	LD	A,Arg1H		;
	AND	A,Arg2H		;
	JRNE	O_DoJMP		;

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_JABS		JABS	a,b,dest
;Operation:	Jump to <dest> if all bits in <a> specified by mask <b> are set
;************************************************************************************

O_JABS	LD	X,#Arg3		;<Arg3> has jump address

	LD	A,Arg1L		;Check if all bits set
	AND	A,Arg2L		;
	CP	A,Arg2L		;
	JRNE	O_JABS1		;
	LD	A,Arg1H		;
	AND	A,Arg2H		;
	CP	A,Arg2H		;
	JREQ	O_DoJMP		;

O_JABS1	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_JBC		JBC	a,b,dest
;Operation:	Jump to <dest> if any bits in <a> specified by mask <b> are clear
;************************************************************************************

O_JBC	LD	X,#Arg3		;<Arg3> has jump address

	LD	A,Arg1L		;Check if any bits clear
	AND	A,Arg2L		;
	CP	A,Arg2L		;
	JRNE	O_DoJMP		;
	LD	A,Arg1H		;
	AND	A,Arg2H		;
	CP	A,Arg2H		;
	JRNE	O_DoJMP		;

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_JBAC		JABC	a,b,dest
;Operation:	Jump to <dest> if all bits in <a> specified by mask <b> are clear
;************************************************************************************

O_JABC	LD	X,#Arg3		;<Arg3> has jump address

	LD	A,Arg1L		;Check if all bits clear
	AND	A,Arg2L		;
	JRNE	O_JABC1		;
	LD	A,Arg1H		;
	AND	A,Arg2H		;
	JREQ	O_DoJMP		;

O_JABC1	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_DJNZ		DJNZ	a,dest
;Operation:	Jump to <dest> if <a> <> 0, decrement <a> before jump
;	Note: <a> is tested BEFORE it is decremented
;************************************************************************************

O_DJNZ	LD	A,Arg1L		;Check if <Arg1> = 0
	OR	A,Arg1H		;
	PUSH	CC		;Save status

	LD	A,Arg1L		;Decrement <Arg1>
	SUB	A,#1		;
	LD	Arg1L,A		;
	JRNC	O_DJNZ1		;
	DEC	Arg1H		;

O_DJNZ1	BSET	Arg1Ctrl,#ArgSave@	;Save argument 1
	LD	X,#Arg2		;<Arg2> is jump target

	POP	CC		;<Arg1> <> 0 ?
	JRNE	O_DoJMP		; Yes, perform jump

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_IJLE		IJLE	a,b,dest
;Operation:	<a> = <a> + 1, jump to <dest> if <a> <= <b>
;	Note: <a> is tested AFTER it is incremented
;************************************************************************************

O_IJLE	LD	A,Arg1L		;Get <Arg1>
	LD	X,Arg1H		;

	INC	A		;Increment <Arg1>
	JRNE	O_IJLE1		;
	INC	X		;

O_IJLE1	LD	Arg1L,A		;Save <Arg1>
	LD	Arg1H,X		;
	BSET	Arg1Ctrl,#ArgSave@	;

	CP	X,Arg2H		;Check if <Arg1> <= <Arg2>
	JRULT	O_IJLE2		;
	JRUGT	O_IJLE3		;
	CP	A,Arg2L		;
	JRUGT	O_IJLE3		;

O_IJLE2	OR	A,Arg1H		;If incremented value = 0,
	JREQ	O_IJLE3		; then don't jump (overflow)
	LD	X,#Arg3		;<Arg3> is jump target
	JP	O_DoJMP		;Less than, do jump

O_IJLE3	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_CALL		CALL	dest
;Operation:	Save PC on stack and jump to <dest>
;************************************************************************************

O_CALL	LD	A,SeqPCL		;Push PC on sequencer stack
	CALLR	StackPush		;
	LD	A,SeqPCH		;
	CALLR	StackPush		;

	JP	O_JMP		;Jump to <Arg1>

;************************************************************************************
;Name:	O_RET		RET
;Operation:	Return from subroutine; retreive PC from stack
;************************************************************************************

O_RET	CALLR	StackPop		;Get sequencer PC from stack
	LD	SeqPCH,A		;
	CALLR	StackPop		;
	LD	SeqPCL,A		;

	JP	O_ChkJMP		;Check address and return

;************************************************************************************
;Name:      StackPush
;Function:	Push a byte onto the sequencer stack, check for valid SeqSP
;
;	A  -> Value to push on stack
;	X <-  Sequencer stack pointer
;************************************************************************************

StackPush	LD	X,SeqSP		;Get stack pointer
	CP	X,SeqSPLim		;Below lower limit ?
	JRULT	StackErr		; Yes, exit w/stack error

	LD	(Variables,X),A	;Place value on stack
	DEC	SeqSP		;Decrement stack pointer
	RET			;Exit (CF=0)

StackErr	POP	A		;Deallocate return address
	POP	A		;
	LD	A,#SE_Stack		;Stack under/overflow error
	SCF			;CF=1 to indicate error
	RET			;Return to exec

;************************************************************************************
;Name:	StackPop
;Function:	Pop a byte off the sequencer stack, check for valid SeqSP
;
;	A <-  Value popped off stack
;	X <-  Sequencer stack pointer
;************************************************************************************

StackPop	LD	X,SeqSP		;Get stack pointer
	INC	X		;Increment
	CP	X,#NbrVars		;Beyond end of stack ?
	JRUGE	StackErr		; Yes, exit w/error

	LD	SeqSP,X		;Save updated stack pointer
	LD	A,(Variables,X)	;Get value from stack
	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_PUSH		PUSH	a
;Operation:	Push value of <a> on stack.
;	Number of bytes pushed (1 or 2) depends on size of <a>
;************************************************************************************

O_PUSH	LD	A,Arg1L		;Push LSB
	CALLR	StackPush		;

	BTJF	Arg1Ctrl,#ArgWord@,O_PUSH1 ;If word sized:

	LD	A,Arg1H		;Push MSB
	CALLR	StackPush		;

O_PUSH1	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_POP		POP	a
;Operation:	Place value on top of stack into <a>
;	Number of bytes popped (1 or 2) depends on size of <a>
;************************************************************************************

O_POP	BTJF	Arg1Ctrl,#ArgWord@,O_POP1 ;If word sized:

	CALLR	StackPop		;Pop MSB
	LD	Arg1H,A		;

O_POP1	CALLR	StackPop		;Pop LSB
	LD	Arg1L,A		;

	BSET	Arg1Ctrl,#ArgSave@	;Save <Arg1>
O_WAITX	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_WAIT		WAIT	time
;	O_LWAIT		LWAIT	time
;Operation:	O_WAIT:  Delay execution for <time> * 10 mS
;	O_LWAIT: Delay execution for <time> * AC line cycle
;************************************************************************************

O_WAIT	CLR	Y		;Y=0 : 10mS units
	JRA	O_WAIT1		;

O_LWAIT	LD	Y,#1		;Y=1 : Line cycle units

O_WAIT1	CLR	A		;X,A <- Delay counter
	CLR	X		;

O_WAIT2	CALL	IntChk		;Check for interrupt conditions
	JRC	O_WAITB		;Exit if interrupt

	CP	X,Arg1H		;Exit if count = <Arg1>
	JRULT	O_WAIT3		;
	CP	A,Arg1L		;
	JRUGE	O_WAITX		;

O_WAIT3	INC	A		;Increment count
	JRNE	O_WAIT4		;
	INC	X		;

O_WAIT4	TNZ	Y		;
	JRNE	O_WAIT6		;If 10 mS units selected:

O_WAIT5	BRESM	T10F		;Clear 10mS delay flag
O_WAIT5a	BTJFM	T10F,O_WAIT5a	;Wait 10 mS
	JRA	O_WAIT2		;Repeat until delay complete

O_WAIT6	BRESM	TACZCF		;
O_WAIT6a	BTJFM	TACZCF,O_WAIT6a	;Wait 1 line cycle
	JRA	O_WAIT2		;Repeat until delay complete

O_WAITB	LD	A,#SE_Break		;Break fault
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	O_MADD		MADD	dest,src,mask
;Operation:	Mask add operation: dest[0..7] += <src>, based on 8-bit <mask>
;************************************************************************************

O_MADD	LD	A,#Op_Add		;ADD operation
	JRA	O_MaskOp		;Execute

;************************************************************************************
;Name:	O_MSUB		MSUB	dest,src,mask
;Operation:	Mask add operation: dest[0..7] -= <src>, based on 8-bit <mask>
;************************************************************************************

O_MSUB	LD	A,#Op_Sub		;SUBTRACT operation
	JRA	O_MaskOp		;Execute

;************************************************************************************
;Name:	O_MINC		MINC	dest,mask
;	O_MDEC		MDEC	dest,mask
;Operation:	Mask increment or decrement operation:
;	Increment or decrement dest[0..7], based on 8-bit <mask>
;************************************************************************************

O_MINC	LD	A,#Op_Add		;ADD (increment) operation
	JRA	O_MDEC1		;

O_MDEC	LD	A,#Op_Sub		;SUBTRACT (decrement)

O_MDEC1	LD	X,Arg2L		;Mask in <Arg2>
	CLR	Arg2L		;Add (or subtract) 1
	INC	Arg2L		;
	CLR	Arg2H		;
	JRA	O_MaskOpAlt		;Execute

;************************************************************************************
;Name:	O_MAND		MAND	dest,src,mask
;Operation:	Mask AND operation: dest[0..7] &= <src>, based on 8-bit <mask>
;************************************************************************************

O_MAND	LD	A,#Op_And		;AND operation
	JRA	O_MaskOp		;Execute

;************************************************************************************
;Name:	O_MOR		MOR	dest,src,mask
;Operation:	Mask OR operation: dest[0..7] |= <src>, based on 8-bit <mask>
;************************************************************************************

O_MOR	LD	A,#Op_Or		;OR operation
	JRA	O_MaskOp		;Execute

;************************************************************************************
;Name:	O_MXOR		MXOR	dest,src,mask
;Operation:	Mask XOR operation: dest[0..7] ^= <src>, based on 8-bit <mask>
;************************************************************************************

O_MXOR	LD	A,#Op_XOr		;XOR operation
	JRA	O_MaskOp		;Execute

;************************************************************************************
;Name:	O_MANDOR		MANDOR	dest,src,mask
;Operation:	Mask AND + OR operation:
;	dest[0..7] = dest[0..7] & <src-msb> | <src-lsb>, based on 8-bit <mask>
;	This operation requires a word-sized <src> operation to work as intended
;************************************************************************************

O_MANDOR	LD	A,#Op_AndOr		;AND-OR operation
	JRA	O_MaskOp		;Execute

;************************************************************************************
;Name:	O_MMOVE		MMOVE	dest,src,mask
;Operation:	Mask move operation: dest[0..7] = <src>, based on 8-bit <mask>
;************************************************************************************

O_MMOVE	LD	A,#Op_Assign	;Assign/move operation

O_MaskOp	LD	X,Arg3L		;Normal entry: mask in <Arg3>

O_MaskOpAlt	LD	ChanMask,X		;Set mask
	OR	A,#%01100000	;Read & write enable, byte sized
	LD	FmtCode,A		;Set operation code

	LD	X,#Arg1		;Arg1 is destination
	LD	Y,#ObjPtr		;Use ObjPtr as destination pointer
	CALL	SetArrayD		;Initialize array destination pointer
	JRC	O_MaskOpX		;Exit if error (dest is a constant)

	LD	A,Arg2L		;Set source value
	LD	StrPtrL,A		;
	LD	A,Arg2H		;
	LD	StrPtrH,A		;

	LD	A,Arg1Ctrl		;Set array size
	AND	A,#$0F		;
	LD	Digits,A		;

	SCF			;Ignore single-element conditions
	CALL	ModArray		;Perform mask-based array operation

	RCF			;No errors
O_MaskOpX	RET			;Exit

;************************************************************************************
;Name:	O_INP		INP	d,devmask
;Operation: Input from specified device(s)
;************************************************************************************

O_INP	LD	X,Arg2L		;Get device mask

O_Input	LD	FmtCode,X		;Set device mask

	BTJF	Arg1Ctrl,#ArgWord@,O_Input1 ;If word-sized data:
	CALL	SeqInputT		;Input from selected port
	LD	Arg1H,A		;Save data MSB
	JRC	O_InputX		;Do not attempt LSB if timeout

O_Input1	CALL	SeqInputT		;Input from selected port
	LD	Arg1L,A		;Save data LSB

	BSET	Arg1Ctrl,#ArgSave@	;Save <Arg1>

O_InputX	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_INPS		INPS	d
;Operation: Input from serial port
;************************************************************************************

O_INPS	LD	X,#%10000001	;Input from serial port w/timeout
	JRA	O_Input		;

;************************************************************************************
;Name:	O_INPU		INPU	d
;Operation: Input from USB port
;************************************************************************************

O_INPU	LD	X,#%10000010	;Input from USB port w/timeout
	JRA	O_Input		;

;************************************************************************************
;Name:	O_OUT		OUT	d,devmask
;Operation: Output to specified device(s)
;************************************************************************************

O_OUT	LD	X,Arg2L		;Get device mask

O_Output	LD	FmtCode,X		;Save device mask

	BTJF	Arg1Ctrl,#ArgWord@,O_Output1 ;If word-sized data:
	LD	A,Arg1H		;Output MSB to selected port
	CALL	SeqOutputT		;
	JRC	O_OutputX		;Do not attempt LSB if timeout

O_Output1	LD	A,Arg1L		;Output LSB to selected port
	CALL	SeqOutputT		;

O_OutputX	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_OUTS		OUTS	d
;Operation: Output to serial port
;************************************************************************************

O_OUTS	LD	X,#%10000001	;Output to serial port w/timeout
	JRA	O_Output		;

;************************************************************************************
;Name:	O_OUTU		OUTU	d
;Operation: Output to USB port
;************************************************************************************

O_OUTU	LD	X,#%10000010	;Output to USB port w/timeout
	JRA	O_Output		;

;************************************************************************************
;Name:	O_OUTD		OUTD	d
;Operation: Output to front panel LED display
;************************************************************************************

O_OUTD	LD	X,#%00000100	;Output to front panel LED
	JRA	O_Output		;

;************************************************************************************
;Name:	O_AINP		AINP	d,cnt,devmask
;Operation:	Array d[0..cnt-1] = data from specified device(s)
;	Number of bytes read is the lesser of <cnt> or declared array size
;************************************************************************************

O_AINP	LD	X,Arg3L		;Get device mask

O_AInput	LD	FmtCode,X		;Save device mask

	LD	X,#Arg1		;<Arg1> is destination
	LD	Y,#ObjPtr		;Use <ObjPtr> as destination pointer
	CALL	SetArrayD		;Initialize destination pointer
	JRC	O_AInputX		;Exit if error (dest is a constant)

	LD	A,Arg1Ctrl		;Get control flags for destination
	AND	A,#$0F		;Isolate array size (-1)
	INC	A		;Add 1 to get actual array size
	CP	A,Arg2L		;Declared size >= Requested count ?
	JRUGT	O_AInput1		; Yes, proceed
	LD	Arg2L,A		; No, force count to array size

O_AInput1	CLR	SeqIOCnt		;Reset I/O timeout counter
	BRESM	SeqIOT		;
	CLR	X		;X <- Byte counter

O_AInput2	CP	X,Arg2L		;Byte count >= limit ?
	JRUGE	O_AOutputX		; Yes, receive complete, exit
	CALL	SeqInput		;Check for input from selected device
	LD	([ObjPtr.W],X),A	;Write data to destination
	INC	X		;Increment byte count
	JRNC	O_AInput2		;Continue if receive was successful

O_AInputX	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_AINPS		AINPS	d,cnt
;Operation:	Array d[0..cnt-1] = data from serial port
;	Number of bytes read is the lesser of <cnt> or declared array size
;************************************************************************************

O_AINPS	LD	X,#%10000001	;Read from serial port w/timeout
	JRA	O_AInput		;

;************************************************************************************
;Name:	O_AINPU		AINPU	d,cnt
;Operation:	Array d[0..cnt-1] = data from USB port
;	Number of bytes read is the lesser of <cnt> or declared array size
;************************************************************************************

O_AINPU	LD	X,#%10000010	;Input from USB port w/timeout
	JRA	O_AInput		;

;************************************************************************************
;Name:	O_AOUT		AOUTU	d,cnt,devmask
;Operation:	Transmit contents of d[0..cnt-1] to specified device(s)
;	Number of bytes sent is the lesser of <cnt> or declared array size
;************************************************************************************

O_AOUT	LD	X,Arg3L		;Get device mask

O_AOutput	LD	FmtCode,X		;Save device mask

	LD	X,#Arg1		;<Arg1> is source
	LD	Y,#ObjPtr		;Use <ObjPtr> as source pointer
	CALL	SetArrayS		;Initialize source pointer

	LD	A,Arg1Ctrl		;Get control flags for source
	AND	A,#$0F		;Isolate array size (-1)
	INC	A		;Add 1 to get actual array size
	CP	A,Arg2L		;Declared size >= Requested count ?
	JRUGT	O_AOutput1		; Yes, proceed
	LD	Arg2L,A		; No, force count to array size

O_AOutput1	CLR	SeqIOCnt		;Reset I/O timeout counter
	BRESM	SeqIOT		;
	CLR	X		;X <- Byte counter

O_AOutput2	CP	X,Arg2L		;Byte count >= limit ?
	JRUGE	O_AOutputX		; Yes, send complete, exit
	LD	A,([ObjPtr.W],X)	;Get byte from array
	CALL	SeqOutput		;Attempt to send to selected device
	INC	X		;Increment byte count
	JRNC	O_AOutput2		;Continue if send was successful

O_AOutputX	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_AOUTS		AOUTS	d,cnt
;Operation:	Transmit contents of d[0..cnt-1] to serial port
;	Number of bytes sent is the lesser of <cnt> or declared array size
;************************************************************************************

O_AOUTS	LD	X,#%10000001	;Send via serial port
	JRA	O_AOutput		;

;************************************************************************************
;Name:	O_AOUTU		AOUTU	d,cnt
;Operation:	Transmit contents of d[0..cnt-1] to USB port
;	Number of bytes sent is the lesser of <cnt> or declared array size
;************************************************************************************

O_AOUTU	LD	X,#%10000010	;Send via USB port
	JRA	O_AOutput		;

;************************************************************************************
;Name:	O_AOUTD		AOUTD	d,cnt
;Operation:	Transmit contents of d[0..cnt-1] to front panel LED display
;	Number of bytes sent is the lesser of <cnt> or declared array size
;************************************************************************************

O_AOUTD	LD	X,#%00000100	;Send to front panel display
	JRA	O_AOutput		;

;************************************************************************************
;Name:	O_HOUTS		HOUTS	n,fmt
;Operation:	Convert <n> to ASCII hex based on <fmt> and send to serial port
;************************************************************************************

O_HOUTS	LD	X,#%10000001	;Output to serial port w/timeout
	JRA	O_HexOut		;Convert to hex & send result

;************************************************************************************
;Name:	O_HOUTU		HOUTU	n,fmt
;Operation:	Convert <n> to ASCII hex based on <fmt> and send to USB port
;************************************************************************************

O_HOUTU	LD	X,#%10000010	;Output to USB port w/timeout
	JRA	O_HexOut		;Convert to hex & send result

;************************************************************************************
;Name:	O_HOUTD		HOUTD	n,fmt
;Operation:	Convert <n> to ASCII hex based on <fmt> and send to LED display
;************************************************************************************

O_HOUTD	LD	X,#%00000100	;Output to front panel display
	JRA	O_HexOut		;Convert to hex & send result

;************************************************************************************
;Name:	O_HOUT		HOUT	n,fmt,devmask
;Operation:	Convert <n> to ASCII hex based on <fmt> and send to specified device(s)
;************************************************************************************

O_HOUT	LD	A,#Nbr_Hex		;Default mode is hex

O_VarOut	LD	X,Arg3L		;Get device mask
	TNZ	Arg3H		;MSB of device mask = 0 ?
	JREQ	O_NumOut		; Yes, use default radix as passed

	LD	A,Arg3H		;Get override radix mode
	DEC	A		;
	AND	A,#$03		;Restrict to 0-3
	JRA	O_NumOut		;Convert number using specified radix

O_HexOut	LD	A,#Nbr_Hex		;Convert to hex
	JRA	O_NumOut		;

O_DecOut	LD	A,#Nbr_Dec		;Convert to decimal

O_NumOut	LD	FmtCode,X		;Save device mask

	PUSH	A		;Save A (conversion mode)
	LD	A,Arg1H		;ObjPtr <- Arg1
	LD	ObjPtrH,A		;
	LD	A,Arg1L		;
	LD	ObjPtrL,A		;
	LD	A,Arg2H		;FWidth <- Arg2H
	LD	FWidth,A		;
	LD	A,Arg2L		;Digits <- Arg2L
	LD	Digits,A		;
	CLR	DecPos		;DecPos <- 0
	POP	A		;Restore A (conversion mode)

	CALL	Int2Asc		;Convert & send result
	RCF			;Ignore timeout error
	RET			;Exit

;************************************************************************************
;Name:	O_DOUT		DOUTS	n,fmt,devmask
;Operation:	Convert <n> to ASCII decimal based on <fmt> and send to specified devices
;************************************************************************************

O_DOUT	LD	A,#Nbr_Dec		;Default mode is decimal
	JRA	O_VarOut		;

;************************************************************************************
;Name:	O_DOUTS		DOUTS	n,fmt
;Operation:	Convert <n> to ASCII decimal based on <fmt> and send to serial port
;************************************************************************************

O_DOUTS	LD	X,#%10000001	;Output to serial port w/timeout
	JRA	O_DecOut		;

;************************************************************************************
;Name:	O_DOUTU		DOUTU	n,fmt
;Operation:	Convert <n> to ASCII decimal based on <fmt> and send to USB port
;************************************************************************************

O_DOUTU	LD	X,#%10000010	;Output to USB port w/timeout
	JRA	O_DecOut		;

;************************************************************************************
;Name:	O_DOUTD		DOUTD	n,fmt
;Operation:	Convert <n> to ASCII decimal based on <fmt> and send to LED display
;************************************************************************************

O_DOUTD	LD	X,#%00000100	;Output to front panel display
	JRA	O_DecOut		;

;************************************************************************************
;Name:	O_SPOUTS		SPOUTS	len,strptr
;Operation:	Output string pointed to by <strptr> to serial port
;************************************************************************************

O_SPOUTS	LD	X,#%10000001	;Send via serial port
	JRA	O_StrOutP		;

;************************************************************************************
;Name:	O_SPOUTU		SPOUTU	len,strptr
;Operation:	Output string pointed to by <strptr> to USB port
;************************************************************************************

O_SPOUTU	LD	X,#%10000010	;Send via USB port
	JRA	O_StrOutP		;

;************************************************************************************
;Name:	O_SPOUTD		SPOUTD	len,strptr
;Operation:	Output string pointed to by <strptr> to front panel display
;************************************************************************************

O_SPOUTD	LD	X,#%00000100	;Send to front panel display
	JRA	O_StrOutP		;

;************************************************************************************
;Name:	O_SPOUT		SPOUT	len,strptr,devmask
;Operation:	Output string pointed to by <strptr> to device(s) specified by <devmask>
;************************************************************************************

O_SPOUT	LD	X,Arg3L		;Get device mask

O_StrOutP	CALL	EERelease		;Deselect EEPROM, use new address

	LD	A,Arg2H		;EEPtr <- Arg2 (string address)
	LD	EEPtrH,A		;
	LD	A,Arg2L		;
	LD	EEPtrL,A		;

	LD	A,#%00000001	;Bit 0 set to use EERead to get chars
	JRA	O_StrOutA		;Output string

;************************************************************************************
;Name:	O_SOUT		SOUT	len,devmask,string
;Function:	Output string to device(s) specified by <devmask>
;************************************************************************************

O_SOUT	LD	X,Arg2L		;Get device mask

O_StrOut	CLR	A		;Bit 0 clear, use Fetch to get chars

O_StrOutA	LD	DecPos,A		;Save internal control flags
	LD	FmtCode,X		;Save I/O control flags
	CLR	SeqIOCnt		;Reset I/O timeout counter
	BRESM	SeqIOT		;

	LD	A,Arg1H		;Check if len = 0
	OR	A,Arg1L		;
	JRNE	O_StrOut1		;Proceed normally if len > 0
	BSET	DecPos,#1		;Set bit 1, "terminate on null"

O_StrOut1	BTJT	DecPos,#0,O_StrOut2	;Check getchar method bit
	CALL	Fetch		;Bit 0 = 0: Use Fetch to get char
	JRNC	O_StrOut3		;Continue normally if no error
	JRA	O_StrOutX		;Exit otherwise

O_StrOut2	CALL	EERead		;Bit 0 = 1: Use EERead to get char, CF=1
	SCF			;CF=1 in case of error
	JRNE	O_StrOutX		;Exit if error

O_StrOut3	BTJF	DecPos,#1,O_StrOut4	;Check for null ?
	TNZ	A		; Yes, check for end of string
	JREQ	O_StrOut6		; Output finished if end of string

O_StrOut4	BTJT	DecPos,#2,O_StrOut5	;Don't try to send if prior timeout
	CALL	SeqOutput		;Send byte to selected port
	JRNC	O_StrOut5		;Continue normally if not timed out
	BSET	DecPos,#2		;Scan rest of string but do not send

O_StrOut5	LD	A,Arg1L		;Decrement byte count limit
	SUB	A,#1		;
	LD	Arg1L,A		;
	LD	A,Arg1H		;
	SBC	A,#0		;
	LD	Arg1H,A		;
	OR	A,Arg1L		;Byte count = 0 ?
	JRNE	O_StrOut1		; No, continue sending

O_StrOut6	RCF			;No errors
O_StrOutX	RET			;Exit

;************************************************************************************
;Name:	O_SOUTS		SOUTS	len,string
;Function:	Output string to serial port
;************************************************************************************

O_SOUTS	LD	X,#%10000001	;Output to serial port w/timeout
	JRA	O_StrOut		;

;************************************************************************************
;Name:	O_SOUTU		SOUTU	len,string
;Function:	Output string to USB port
;************************************************************************************

O_SOUTU	LD	X,#%10000010	;Output to USB port w/timeout
	JRA	O_StrOut		;

;************************************************************************************
;Name:	O_SOUTD		SOUTD	len,string
;Function:	Output string to front panel LED display
;************************************************************************************

O_SOUTD	LD	X,#%00000100	;Output to front panel display
	JRA	O_StrOut		;

;	#IF	0

;************************************************************************************
;Name:	O_LINPUT		INPUT	dest,len
;Operation:	Line input using console I/O
;************************************************************************************

O_LINPUT	LD	X,#Arg1		;<Arg1> is destination buffer
	LD	Y,#CLPtr		;Store buffer addr to <CLPtr>
	CALL	SetArrayD		;Set input buffer address
	JRC	O_LINPUTX		;Exit if error (target is constant)

	LD	A,Arg1Ctrl		;Get destination object control info
	AND	A,#$0F		;Isolate object size
	CP	A,Arg2L		;Compare against length limit
	JRULT	O_LINPUT1		;If obj size < limit, use obj size
	LD	A,Arg2L		;Otherwise, use passed limit

O_LINPUT1	LD	FWidth,A		;Set input length limit
	CLR	CLIndex		;Reset input index

O_LINPUT2	CALL	GetLine		;Check for input
	JRNC	O_LINPUT2		;Wait for EOL

	RCF			;No errors
O_LINPUTX	RET			;Exit

;	#ENDIF

;************************************************************************************
;Name:	O_ATOI		ATOI	dest,array
;Operation:	Convert string (array) to integer
;************************************************************************************

O_ATOI	LD	X,#Arg2		;<Arg2> contains string to convert
	LD	Y,#CLPtr		;<CLPtr> points to data to convert
	CALL	SetArrayS		;Initialize source pointer
	CLR	CLIndex		;Reset index (point to start of buf)

	BSETM	SeqWC		;Assume error
	CALL	GetArg		;Parse string, convert to integer
	JRC	O_ATOI1		;Exit if parsing error
	CP	A,#Arg_Num		;Type = Numeric ?
	JRNE	O_ATOI1		; No, error
	BRESM	SeqWC		; Yes, conversion successful

O_ATOI1	LD	X,#Arg1		;Copy <Arg> to <Arg1>
	CALL	MoveArg		;
	BSET	Arg1Ctrl,#ArgSave@	;Save <Arg1>

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_AMOVE		AMOVE	dest,src,cnt
;Operation:	Array copy: dest[0..cnt-1] = src[0..cnt-1]
;************************************************************************************

O_AMOVE	LD	X,#Arg1		;Destination array
	LD	Y,#ObjPtr		;ObjPtr is destination address
	CALL	SetArrayD		;Set up for move to <Arg1>
	JRC	O_AMOVEX		;Exit if error

	LD	X,#Arg2		;Source array
	LD	Y,#StrPtr		;StrPtr is source address
	CALL	SetArrayS		;Set up for move from <Arg2>

	LD	A,Arg1Ctrl		;Isolate array size of <Arg1>
	AND	A,#$0F		;
	LD	Digits,A		;Save <Arg1> array size

	LD	A,Arg2Ctrl		;Isolate array size of <Arg2>
	AND	A,#$0F		;

;	Set move block size to smallest of:
;	<Arg1> size, <Arg2> size, or <Cnt>

	CP	A,Digits		;<Arg2> size <= <Arg1> size ?
	JRULE	O_AMOVE1		; Yes, use <Arg2> size as count
	LD	A,Digits		; No, use <Arg1> size as count
O_AMOVE1	INC	A		;Array sizes are -1, so add 1

	CP	A,Arg3L		;Is Arg1 or Arg2 size <= <Cnt> ?
	JRULE	O_AMOVE2		; Yes, keep smaller count
	LD	A,Arg3L		; No, use <Cnt> as byte move limit
O_AMOVE2	LD	Digits,A		;Save # bytes to move

;	Copy source array to destination array

	CLR	X		;X <- Array index
O_AMOVE3	CP	X,Digits		;Index >= block size ?
	JRUGE	O_AMOVE4		; Yes, move complete, exit

	LD	A,([StrPtr.W],X)	;Get byte from source
	LD	([ObjPtr.W],X),A	;Copy to destination
	INC	X		;Increment array index
	JRA	O_AMOVE3		;Continue until block copied

O_AMOVE4	RCF			;No errors
O_AMOVEX	RET			;Exit

;************************************************************************************
;Name:	O_ALOAD		ALOAD	dest,len,data
;Operation:	Load array with immediate data: dest[0..cnt-1] = data[0..cnt-1]
;************************************************************************************

O_ALOAD	LD	X,#Arg1		;Destination array
	LD	Y,#ObjPtr		;ObjPtr is destination address
	CALL	SetArrayD		;Set up for move to <Arg1>
	JRC	O_ALOADX		;Exit if error

	LD	A,Arg1Ctrl		;Get size of destination array
	AND	A,#$0F		;Isolate size (-1)
	LD	Digits,A		;Save destination array size

	CLR	X		;Reset array index
O_ALOAD1	CP	X,Arg2L		;Index >= data block size ?
	JRUGE	O_ALOAD3		; Yes, load finished
	CALL	Fetch		;Fetch immediate data
	JRC	O_ALOADX		;Exit if error
	CP	X,Digits		;Past end of array ?
	JRUGT	O_ALOAD2		; Yes, do not write data
	LD	([ObjPtr.W],X),A	;Store byte fetched into array
O_ALOAD2	INC	X		;Increment array index
	JRA	O_ALOAD1		;Fetch next value

O_ALOAD3	RCF			;No errors
O_ALOADX	RET			;Exit

;************************************************************************************
;Name:	O_RAND		RAND	dest,range
;Operation:	Generate random number in <dest> with range of 0..<range>-1
;************************************************************************************

O_RAND	CALL	Random16		;Generate random number

	LD	X,#RandSeed		;Random # * <range>
	LD	Y,#Arg2		;
	LD	A,#Arg3		;<Arg3> is destination
	CALL	MUL1616		;Scale random number, MSW is result

	LD	A,Arg3H		;Copy result MSW to destination
	LD	Arg1H,A		;
	LD	A,Arg3L		;
	LD	Arg1L,A		;
	BSET	Arg1Ctrl,#ArgSave@	;Save <Arg1>

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_MUL		MUL	a,b
;Operation:	Var[0..3] = a * b
;************************************************************************************

O_MUL	LD	X,#Arg1		;Calculate <Arg1> * <Arg2>
	LD	Y,#Arg2		;
	LD	A,#Arg3		;<Arg3> is temporary result holder
	CALL	MUL1616		;Perform multiplication

O_Arg3Reg	LD	X,#3		;# bytes to move (-1)
O_Arg3Reg1	LD	A,(Arg3,X)		;Copy result
	LD	(Variables,X),A	;to destination
	DEC	X		;Decrement byte count
	JRPL	O_Arg3Reg1		;Continue until 4-byte block copied

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_DIV16		DIV16	a,b,c
;Operation:	a = a / b, remainder in c
;************************************************************************************

O_DIV16	LD	Y,Arg1H		;Y,X <- Dividend
	LD	X,Arg1L		;
	LD	A,Arg2L		;A <- Divisor

	CALL	DIV168		;Y,X <- Y,X / A, remainder in A

	LD	Arg1H,Y		;Save quotient
	LD	Arg1L,X		;
	LD	Arg3L,A		;Save remainder
	CLR	Arg3H		;Remainder MSB always 0

	BSET	Arg1Ctrl,#ArgSave@	;Save Arg1 (quotient)
	BSET	Arg3Ctrl,#ArgSave@	;and Arg3 (remainder)

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_DIV32		DIV32	a,b
;Operation:	Var[0..3] = Var[3..0] / a, remainder in b
;************************************************************************************

O_DIV32     LD	X,#3		;Copy 4 bytes
O_DIV32a	LD	A,(Variables,X)	;Arg3 <- Register[0..3]
	LD	(Arg3,X),A		;
	DEC	X		;
	JRPL	O_DIV32a		;

;	Arg1 has divisor, Arg2 will have remainder
;	Perform 32/16 divide

	CALL	DIV3216		;Arg3 <- Arg3 / Arg1, Arg2 <- Rem

	BSET	Arg2Ctrl,#ArgSave@	;Save Arg2 (remainder)

	JRA	O_Arg3Reg		;Reg[0..3] <- Arg3, exit

;************************************************************************************
;Name:	O_BAUD		BAUD	rate
;Operation:	Initialize serial port, set baud rate
;************************************************************************************

O_BAUD	LD	X,Arg1L		;Get baud rate parameter
	JP	SCIInit		;Initialize serial port, exit

;************************************************************************************
;Name:	O_MCALL		MCALL	addr,a_cc,x_y
;Operation:	Call machine-language subroutine
;	Arg1   -> Address to call
;	Arg2L <-> A register
;	Arg2H <-> CC register
;	Arg3L <-> X register
;	Arg3H <-> Y register
;************************************************************************************

O_MCALL	LD	A,Arg2H		;Get CC register value
	PUSH	A		;Place on stack for later retrieval
	LD	A,Arg2L		;A
	LD	X,Arg3L		;X
	LD	Y,Arg3H		;Y
	POP	CC		;CC

	CALL	[Arg1.W]		;Call subroutine

	PUSH	CC		;Save CC for later retrieval
	LD	Arg2L,A		;Save A
	LD	Arg3L,X		;Save X
	LD	Arg3H,Y		;Save Y
	POP	A		;
	LD	Arg2H,A		;Save CC

	BSET	Arg2Ctrl,#ArgSave@	;Save Arg2 (A,CC)
	BSET	Arg3Ctrl,#ArgSave@	;Save Arg3 (X,Y)

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_RSP		RSP
;Operation:	Reset stack pointer and stack overflow limit
;************************************************************************************

O_RSP	LD	A,#{NbrVars-1}	;Reset stack pointer
	LD	SeqSP,A		;
	LD	A,#{NbrVars-16}	;Reset stack pointer overflow limit
	LD	SeqSPLim,A		;

	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_SIZE		SIZE	dest,obj
;Operation:	Store size of <obj> (in bytes) in <dest>
;************************************************************************************

O_SIZE	LD	A,Arg2Ctrl		;Get control info for <obj>
	AND	A,#$0F		;Isolate size info
	INC	A		;Size in ArgCtrl is -1, so add 1
	LD	Arg1L,A		;Save size in <dest>
	CLR	Arg1H		;MSB always 0
	BSET	Arg1Ctrl,#ArgSave@	;Save <dest>
	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_OPEND		OPEND	diraddr
;Operation:	Open a file for I/O, specified by the directory entry pointed to
;	by <diraddr>
;************************************************************************************

O_OPEND	LD	A,Arg1L		;X,A <- Directory entry pointer
	LD          X,Arg1H		;

	CALL	GetDir		;Get directory data
	JRC	O_OPENEE		;Exit if error reading directory
	JP	OpenFileD		;Open file & exit

;************************************************************************************
;Name:	O_OPEN		OPEN	type,filename
;Operation:	Open a file for I/O
;************************************************************************************

O_OPEN	CALL	FetchStr		;Get filename
O_OpenStr	JRC	O_OPENX		;Exit if error

	LD	Y,Arg1L		;Get file type
	CALL	OpenFile		;Attempt to open file
	JRNE	O_OPENEE		; Exit if EEPROM error
	JRC	O_OPENEF		; Exit if file not found

O_OPENX	RET			;Exit (CF=0)

O_OPENEE	LD	A,#SE_Mem		;Memory read error
	SCF			;CF=1 to indicate error
	RET			;Exit

O_OPENEF	LD	A,#SE_FileIO	;File I/O error
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	O_OPENP		OPENP	type,nameptr
;Operation:	Open a file for I/O using filename pointed to by <nameptr>
;************************************************************************************

O_OPENP	LD	X,#Arg2		;<Arg2> points to filename
	CALL	FetchStrP		;Get string at <Arg2>
	JRA	O_OpenStr		;Look up file and open it

;************************************************************************************
;Name:	O_RUND		RUND	diraddr
;Operation:	Run a sequencer program specified by the directory record
;	stored in EEPROM at <diraddr>
;************************************************************************************

O_RUND	LD	A,Arg1L		;X,A <- Directory entry pointer
	LD          X,Arg1H		;

O_RunDir	CALL	GetDir		;Get directory data
	JRC	O_OPENEE		;Exit if error reading directory
	CALL	OpenProgD		;Set up for program execution
	JRA	O_RunItE		;and run it

;************************************************************************************
;Name:	O_RUN		RUN	filename
;Operation:	Open and run a sequencer program
;************************************************************************************

O_RUN	CALL	FetchStr		;Get filename
O_RunStr	JRC	O_OPENX		;Exit if error

	CALL	OpenProg		;Attempt to open program file
	JRNE	O_OPENEE		; Exit if EEPROM error
	JRC	O_OPENEF		; Exit if file not found

O_RunItE	BRESM	FetchRAM		;Program executing from EEPROM

O_RunIt	POP	A		;Pop off return address
	POP	A		;
	RCF			;CF=0, do not clear registers
	JP	Exec		;Execute program

;************************************************************************************
;Name:	O_RUNP		RUNP	nameptr
;Operation:	Open and run a sequencer program using filename pointed to by <nameptr>
;************************************************************************************

O_RUNP	LD	X,#Arg1		;<Arg1> points to filename
	CALL	FetchStrP		;Get string at <Arg1>
	JRA	O_RunStr		;Look up file and run it

;************************************************************************************
;Name:	O_RUNM		RUNM	start,end
;Operation:	Run a sequencer program in CPU memory space
;************************************************************************************

O_RUNM	LD	A,Arg1L		;Copy start address to
	LD	SeqStartL,A		; sequencer start address
	LD	A,Arg1H		;
	LD	SeqStartH,A		;

	LD	A,Arg2L		;Copy end address to
	LD	SeqEndL,A		; sequencer end address
	LD	A,Arg2H		;
	LD	SeqEndH,A		;

	BSETM	FetchRAM		;Program executing from CPU memory

	JRA	O_RunIt		;Run program

;************************************************************************************
;Name:	O_ENDOS		ENDOS
;	O_END		END
;Operation:	O_ENDOS: End program and restart "operating system" program
;	O_END:   End program, exit sequencer
;************************************************************************************

O_ENDOS	CALL	FirstFile		;Get dir data for first file
	JRC	O_END		;Just quit if error
	LD	A,DecPos		;Get file type
	CP	A,#FT_OS		;OS file type ?
	JRNE	O_END		; No, just quit

	CALL	OpenProgD		;Set up to run OS program
	JRA	O_RunItE		;Run it

O_END	LD	A,#SE_END		;End of program "fault"
	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************
;Name:	O_CLOSE		CLOSE
;Operation:	Close currently open file
;************************************************************************************

O_CLOSE	JP	CloseFile		;Close file

;************************************************************************************
;Name:	O_SEEK		SEEK	pos
;Operation:	Change file pointer (seek to a specified position in a file)
;************************************************************************************

O_SEEK	LD	A,Arg1L		;Get seek offset
	LD	X,Arg1H		;
	CALL	FileSeek		;Position file pointer
	JRC	O_OPENEF		;Exit w/error if cannot seek

	RET			;No errors, exit (CF=0)

;************************************************************************************
;Name:	O_AMAG		AMAG	mode
;Operation:	Set mag mode: <mode> = 0 manual, <mode> > 0 auto
;************************************************************************************

O_AMAG	BRESM	AutoMAG		;Assume auto mode off

	LD	A,Arg1L		;Check mode
	OR	A,Arg1H		;
	JREQ	O_AMAGX		;Exit w/auto mode off if arg=0

	BSETM	AutoMAG		;Enable MAG auto mode

O_AMAGX	RET			;Exit (CF=0)

;************************************************************************************
;Name:	O_MSTEP		MSTEP
;Operation:	Step the MAG
;************************************************************************************

O_MSTEP	CALL	MAG		;Step the MAG

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_LEA		LEA	dest,target
;Operation:	Load effective address: <dest> = @<target>
;************************************************************************************

O_LEA	LD	A,Arg2PtrH		;Copy address of <Arg2>
	LD	Arg1H,A		; to value of <Arg1>
	LD	A,Arg2PtrL		;
	LD	Arg1L,A		;

	BSET	Arg1Ctrl,#ArgSave@	;Save <Arg1>

	RET			;Exit

;************************************************************************************
;Name:	O_RESET		RESET
;Operation:	Set all light controls to defaults
;************************************************************************************

O_RESET	CALL	InitMacro		;Set all controls to defaults

	RCF			;No errors
	RET			;Exit

;************************************************************************************
;Name:	O_BREAK		BREAK
;Operation:	Generate break interrupt/fault
;************************************************************************************

O_BREAK	LD	A,#SE_Break		;Break fault

	SCF			;CF=1 to indicate error
	RET			;Exit

;************************************************************************************

;	Argument type table
;
;	This table is scanned for a match of the argument type byte.
;	The ArgType is considered 'matched' if:
;	ArgTypeTbl[n] <= ArgType < ArgTypeTbl[n+1]
;	As such, the entries in this table must be listed in order of lowest
;	to highest value.  The end of the table (after the first entry) is
;	marked with $00.
;
;	The index [n] derived from searching this table is used to
;	index (in word-wise fashion) the ArgProcTbl.

ArgTypeTbl	DC.B	%00000000		;4-bit constant
	DC.B	%00010000		;12-bit constant
	DC.B	%00100000		;8-bit constant
	DC.B	%00100001		;16-bit constant
	DC.B	%00100010		;Reserved (00100001-00111111)
	DC.B	%01000000		;Register reference, 4-bit addr (byte)
	DC.B	%01010000		;Register reference, 4-bit addr (word)
	DC.B        %01100000		;Register reference, 8-bit addr (byte)
	DC.B	%01100001		;Register reference, 8-bit addr (word)
	DC.B	%01100010		;Reserved (01100010-01101111)
	DC.B	%01110000		;Indirect register, 4-bit addr (byte)
	DC.B	%10000000		;Indirect register, 4-bit addr (word)
	DC.B	%10010000		;Indirect register, 8-bit addr (byte)
	DC.B	%10010001		;Indirect register, 8-bit addr (word)
	DC.B	%10010010		;Reserved (10010010-10011111)
	DC.B	%10100000		;Array with constant 4-bit index
	DC.B	%10110000		;Array indexed by register, 4-bit adr
	DC.B	%11000000		;Array indexed by register, 8-bit adr
	DC.B	%11000001		;Control variable access
	DC.B	%11000010		;Read byte from file
	DC.B	%11000011		;Read word from file
	DC.B	%11000100		;Write byte to file
	DC.B	%11000101		;Write word to file
	DC.B	%11000110		;Write byte to file (read returns 0)
	DC.B	%11000111		;Write word to file (read returns 0)
	DC.B	%11001000		;Reserved (11001000-11001111)
	DC.B	%11110000		;RAM, const 8-bit addr (byte)
	DC.B	%11110001		;RAM, const 8-bit addr (word)
	DC.B	%11110010		;RAM, const 16-bit addr (byte)
	DC.B	%11110011		;RAM, const 16-bit addr (word)
	DC.B	%11110100		;Indirect RAM, 8-bit reg addr (byte)
	DC.B	%11110101		;Indirect RAM, 8-bit reg addr (word)
	DC.B	%11110110		;Program memory, 16-bit const (byte)
	DC.B	%11110111		;Program memory, 16-bit const (word)
	DC.B	%11111000		;Program memory, 8-bit reg addr (byte)
	DC.B	%11111001		;Program memory, 8-bit reg addr (word)
	DC.B	%11111010		;EEPROM, 16-bit addr (byte)
	DC.B	%11111011		;EEPROM, 16-bit addr (word)
	DC.B	%11111100		;Indirect EEPROM, 8-bit reg addr (byte)
	DC.B	%11111101		;Indirect EEPROM, 8-bit reg addr (word)
	DC.B	%11111110		;Reserved (1111110-11111111)
	DC.B	0		;END OF TABLE

;	Argument processing vector table
;
;	The entries in this table have a 1:1 correspondence with entries
;	in ArgTypeTbl.  The entries are pointers to subroutines that read
;	and interpret secondary argument data and set up the values in
;	the Arg[x], ArgPtr[x] and ArgCtrl[x] variables.

ArgProcTbl	DC.W	A_Const4		;4-bit constant
	DC.W	A_Const12		;12-bit constant
	DC.W	A_Const8		;8-bit constant
	DC.W	A_Const16		;16-bit constant
	DC.W	A_Reserved		;Reserved (00100010-00111111)
	DC.W	A_RegB4		;Register reference, 4-bit addr (byte)
	DC.W	A_RegW4		;Register reference, 4-bit addr (word)
	DC.W        A_RegB8		;Register reference, 8-bit addr (byte)
	DC.W	A_RegW8		;Register reference, 8-bit addr (word)
	DC.W	A_Reserved		;Reserved (01100010-01101111)
	DC.W	A_IRegB4		;Indirect register, 4-bit addr (byte)
	DC.W	A_IRegW4		;Indirect register, 4-bit addr (word)
	DC.W	A_IRegB8		;Indirect register, 8-bit addr (byte)
	DC.W	A_IRegW8		;Indirect register, 8-bit addr (word)
	DC.W	A_Reserved		;Reserved (10010010-10011111)
	DC.W	A_ArrayC4		;Array with constant 4-bit index
	DC.W	A_ArrayR4		;Array indexed by register, 4-bit adr
	DC.W	A_ArrayR8		;Array indexed by register, 8-bit adr
	DC.W	A_CtrlVar		;Control variable access
	DC.W	A_FileRB		;Read byte from file
	DC.W	A_FileRW		;Read word from file
	DC.W	A_FileRWB		;Read/Write byte to file
	DC.W	A_FileRWW		;Read/Write word to file
	DC.W	A_FileWB		;Write byte to file (read returns 0)
	DC.W	A_FileWW		;Write word to file (read returns 0)
	DC.W	A_Reserved		;Reserved (11000010-11101111)
	DC.W	A_RAMBC8		;RAM, const 8-bit addr (byte)
	DC.W	A_RAMWC8		;RAM, const 8-bit addr (word)
	DC.W	A_RAMBC16		;RAM, const 16-bit addr (byte)
	DC.W	A_RAMWC16		;RAM, const 16-bit addr (word)
	DC.W	A_RAMBV		;Indirect RAM, 8-bit reg addr (byte)
	DC.W	A_RAMWV		;Indirect RAM, 8-bit reg addr (word)
	DC.W	A_PMemBC		;Program memory, 16-bit const (byte)
	DC.W	A_PMemWC		;Program memory, 16-bit const (word)
	DC.W	A_PMemBR		;Program memory, 8-bit reg addr (byte)
	DC.W	A_PMemWR		;Program memory, 8-bit reg addr (word)
	DC.W	A_EEBC		;EEPROM, 16-bit addr (byte)
	DC.W	A_EEWC		;EEPROM, 16-bit addr (word)
	DC.W	A_EEBV		;Indirect EEPROM, 8-bit reg addr (byte)
	DC.W	A_EEWV		;Indirect EEPROM, 8-bit reg addr (word)
	DC.W	A_Reserved		;Reserved (1111110-11111111)
	DC.W	A_Reserved		;END OF TABLE

;	Array pointers
;
;	Entries in this table correspond to array ID's 0-18, and point
;	to the base address of the array.  The upper 4 bits of the address
;	are used to specify the array size - 1; e.g. if the upper 4 bits
;	are equal to %0111, the array is 8 bytes long.

A_NbrChan	EQU	{{NbrChan-1} SHL 12}
A_NbrADC	EQU	{{NbrADChan-1} SHL 12}
A_NbrDisp	EQU	{{DispDigits-1} SHL 12}
A_NbrTmr	EQU	{{NbrUsrTmr-1} SHL 12}
A_NbrFTmr	EQU	{{NbrFixTmr-1} SHL 12}
A_NbrBuf	EQU	{{NumBufSz-1} SHL 12}
A_NbrUSB	EQU	{{USBBufSz-1} SHL 12}
A_NbrVar	EQU	{15 SHL 12}

ArrayTbl	DC.W	{A_NbrChan+Intensity}	;0
	DC.W	{A_NbrChan+XlatCtrl}	;1
	DC.W	{A_NbrChan+MAGCtrl}	;2
	DC.W	{A_NbrChan+MAGCount}	;3
	DC.W	{A_NbrChan+MAGPreCnt}	;4
	DC.W	{A_NbrChan+MAGClkDiv}	;5
	DC.W	{A_NbrChan+MAGStep}	;6
	DC.W	{A_NbrChan+MAGBound1}	;7
	DC.W	{A_NbrChan+MAGBound2}	;8
	DC.W	{A_NbrADC+XGain}	;9
	DC.W	{A_NbrADC+AInput}	;10
	DC.W	{A_NbrTmr+UsrTmrCnt}	;11
	DC.W	{A_NbrTmr+UsrTmrLim}	;12
	DC.W	{A_NbrDisp+DispBuf}	;13
	DC.W	{A_NbrFTmr+FixTmrCnt}	;14
	DC.W	{A_NbrBuf+NumBuf}	;15
	DC.W	{A_NbrUSB+EP2RxBuf}	;16
	DC.W	{A_NbrUSB+EP2TxBuf}	;17
	DC.W	{A_NbrVar+Variables}	;18

NbrArray.B	EQU	{{*-ArrayTbl}/2}

;	Control variable pointers
;
;	Entries in this table correspond to the control variable ID's 0-35,
;	and point to the control variable in RAM.  Bit 15 (MSbit) is used
;	as a size flag for the object (0=Byte, 1=Word).

CtrlVTbl	DC.W	{$0000+MAGGCtrl}	;0
	DC.W	{$8000+MAGSteps}	;1
	DC.W	{$0000+DigitalON}	;2
	DC.W	{$0000+TimeTgl}	;3
	DC.W	{$0000+TimeFlag}	;4
	DC.W	{$0000+UsrTmrFlg}	;5
	DC.W	{$8000+RandSeed}	;6
	DC.W	{$0000+I2CErr}	;7
	DC.W	{$8000+ACPeriod}	;8
	DC.W	{$0000+LineStat}	;9
	DC.W	{$0000+SCICtrl}	;10
	DC.W	{$0000+USBStat}	;11
	DC.W	{$0000+ConSCICtrl}	;12
	DC.W	{$0000+ConUSBCtrl}	;13
	DC.W	{$0000+EEStat}	;14
	DC.W	{$0000+FileStat}	;15
	DC.W	{$0000+DispCtrl}	;16
	DC.W	{$0000+DispIdx}	;17
	DC.W	{$8000+FileStart}	;18
	DC.W	{$8000+FileEnd}	;19
	DC.W	{$8000+FilePos}	;20
	DC.W	{$8000+FDirPtr}	;21
	DC.W	{$0000+SeqCtrl}	;22
	DC.W	{$8000+SeqPC}	;23
	DC.W	{$0000+SeqSP}	;24
	DC.W	{$0000+SeqSPLim}	;25
	DC.W	{$8000+SeqStart}	;26
	DC.W	{$8000+SeqEnd}	;27
	DC.W	{$8000+ExecPC}	;28
	DC.W	{$8000+InstrCnt}	;29
	DC.W	{$0000+IOCount}	;30
	DC.W	{$0000+SeqIOCnt}	;31
	DC.W	{$0000+SeqIOLim}	;32
	DC.W	{$8000+Seconds}	;33
	DC.W	{$8000+Hour}	;34
	DC.W	{$0000+Second}	;35

NbrCtrlV.B	EQU	{{*-CtrlVTbl}/2}

;	Integer-to-number base vector table

BaseVTbl	DC.W	Int2Bin
	DC.W	Int2Oct
	DC.W	Int2Dec
	DC.W	Int2Hex

;	Opcode processing vector table
;
;	Entries in this table are built using the DEFOP macro, which constructs
;	a composite address and argument count in 16 bits.  The upper 2 bits
;	(14 & 15) specify the argument count, and the lower 14 bits contain the
;	operation handler address.  When the <Exec> routine calculates the
;	actual operation handler address, it adds $C000 to the 14-bit address
;	field in this table to compute the actual operation handler address.

OpProcTbl	DEFOP	O_NOP,0		;00 : NOP
	DEFOP	O_MOVE,2		;01 : MOVE
	DEFOP	O_ZERO,1		;02 : ZERO
	DEFOP	O_XCHA,2		;03 : XCHA
	DEFOP	O_XCHB,1		;04 : XCHB
	DEFOP	O_XCHN,1		;05 : XCHN
	DEFOP	O_ADD,2		;06 : ADD
	DEFOP	O_SUB,2		;07 : SUB
	DEFOP	O_INC,1		;08 : INC
	DEFOP	O_INCBC,1		;09 : INCBC
	DEFOP	O_INCWC,1		;0A : INCWC
	DEFOP	O_DEC,1		;0B : DEC
	DEFOP	O_DECBC,1		;0C : DECBC
	DEFOP	O_DECWC,1		;0D : DECWC
	DEFOP	O_INV,1		;0E : INV
	DEFOP	O_CPL2,1		;0F : CPL2
	DEFOP	O_AND,2		;10 : AND
	DEFOP	O_OR,2		;11 : OR
	DEFOP	O_XOR,2		;12 : XOR
	DEFOP	O_ANDOR,3		;13 : ANDOR
	DEFOP	O_SHL,1		;14 : SHL
	DEFOP	O_SHLBC,1		;15 : SHLBC
	DEFOP	O_SHLWC,1		;16 : SHLWC
	DEFOP	O_SHR,1		;17 : SHR
	DEFOP	O_SHRBC,1		;18 : SHRBC
	DEFOP	O_SHRWC,1		;19 : SHRWC
	DEFOP	O_MUL,2		;1A : MUL
	DEFOP	O_RAND,2		;1B : RAND
	DEFOP	O_DIV16,3		;1C : DIV16
	DEFOP	O_DIV32,2		;1D : DIV32
	DEFOP	O_WAIT,1		;1E : WAIT
	DEFOP	O_LWAIT,1		;1F : LWAIT
	DEFOP	O_SETBC,0		;20 : SETBC
	DEFOP	O_SETWC,0		;21 : SETWC
	DEFOP	O_CLRBC,0		;22 : CLRBC
	DEFOP	O_CLRWC,0		;23 : CLRWC
	DEFOP	O_AMOVE,3		;24 : AMOVE
	DEFOP	O_ALOAD,2		;25 : ALOAD
	DEFOP	O_MMOVE,3		;26 : MMOVE
	DEFOP	O_MADD,3		;27 : MADD
	DEFOP	O_MSUB,3		;28 : MSUB
	DEFOP	O_MINC,2		;29 : MINC
	DEFOP	O_MDEC,2		;2A : MDEC
	DEFOP	O_MAND,3		;2B : MAND
	DEFOP	O_MOR,3		;2C : MOR
	DEFOP	O_MXOR,3		;2D : MXOR
	DEFOP	O_MANDOR,3		;2E : MANDOR
	DEFOP	O_NOP,0		;2F : reserved
	DEFOP	O_JMP,1		;30 : JMP
	DEFOP	O_JLT,3		;31 : JLT
	DEFOP	O_JLE,3		;32 : JLE
	DEFOP	O_JEQ,3		;33 : JEQ
	DEFOP	O_JNE,3		;34 : JNE
	DEFOP	O_JGE,3		;35 : JGE
	DEFOP	O_JGT,3		;36 : JGT
	DEFOP	O_JZ,2		;37 : JZ
	DEFOP	O_JNZ,2		;38 : JNZ
	DEFOP	O_JBCS,1		;39 : JBCS
	DEFOP	O_JWCS,1		;3A : JWCS
	DEFOP	O_JEOF,1		;3B : JEOF
	DEFOP	O_JBCC,1		;3C : JBCC
	DEFOP	O_JWCC,1		;3D : JWCC
	DEFOP	O_JNEOF,1		;3E : JNEOF
	DEFOP	O_NOP,0		;3F : reserved
	DEFOP	O_JBS,3		;40 : JBS
	DEFOP	O_JABS,3		;41 : JABS
	DEFOP	O_JBC,3		;42 : JBC
	DEFOP	O_JABC,3		;43 : JABC
	DEFOP	O_DJNZ,2		;44 : DJNZ
	DEFOP	O_IJLE,3		;45 : IJLE
	DEFOP	O_CALL,1		;46 : CALL
	DEFOP	O_RET,0		;47 : RET
	DEFOP	O_PUSH,1		;48 : PUSH
	DEFOP	O_POP,1		;49 : POP
	DEFOP	O_RSP,0		;4A : RSP
	DEFOP	O_OPEN,1		;4B : OPEN
	DEFOP	O_OPENP,2		;4C : OPENP
 	DEFOP	O_OPEND,1		;4D : OPEND
	DEFOP	O_CLOSE,0		;4E : CLOSE
	DEFOP	O_SEEK,1		;4F : SEEK
	DEFOP	O_INP,2		;50 : INP
	DEFOP	O_INPS,1		;51 : INPS
	DEFOP	O_INPU,1		;52 : INPU
	DEFOP	O_OUT,2		;53 : OUT
	DEFOP	O_OUTS,1		;54 : OUTS
	DEFOP	O_OUTU,1		;55 : OUTU
	DEFOP	O_OUTD,1		;56 : OUTD
	DEFOP	O_AINP,3		;57 : AINP
	DEFOP	O_AINPS,2		;58 : AINPS
	DEFOP	O_AINPU,2		;59 : AINPU
	DEFOP	O_AOUT,3		;5A : AOUT
	DEFOP	O_AOUTS,2		;5B : AOUTS
	DEFOP	O_AOUTU,2		;5C : AOUTU
	DEFOP	O_AOUTD,2		;5D : AOUTD
	DEFOP	O_DOUT,3		;5E : DOUT
	DEFOP	O_DOUTS,2		;5F : DOUTS
	DEFOP	O_DOUTU,2		;60 : DOUTU
	DEFOP	O_DOUTD,2		;61 : DOUTD
	DEFOP	O_HOUT,3		;62 : HOUT
	DEFOP	O_HOUTS,2		;63 : HOUTS
	DEFOP	O_HOUTU,2		;64 : HOUTU
	DEFOP	O_HOUTD,2		;65 : HOUTD
	DEFOP	O_SOUT,2		;66 : SOUT
	DEFOP	O_SOUTS,1		;67 : SOUTS
	DEFOP	O_SOUTU,1		;68 : SOUTU
	DEFOP	O_SOUTD,1		;69 : SOUTD
	DEFOP	O_SPOUT,3		;6A : SPOUT
	DEFOP	O_SPOUTS,2		;6B : SPOUTS
	DEFOP	O_SPOUTU,2		;6C : SPOUTU
	DEFOP	O_SPOUTD,2		;6D : SPOUTD
	DEFOP	O_LINPUT,2		;6E : INPUT
	DEFOP	O_ATOI,2		;6F : ATOI
	DEFOP	O_RUN,0		;70 : RUN
	DEFOP	O_RUNP,1		;71 : RUNP
	DEFOP	O_RUND,1		;72 : RUND
	DEFOP	O_RUNM,2		;73 : RUNM
	DEFOP	O_LEA,2		;74 : LEA
	DEFOP	O_SIZE,2		;75 : SIZE
	DEFOP	O_AMAG,1		;76 : AMAG
	DEFOP	O_MSTEP,0		;77 : MSTEP
	DEFOP	O_BAUD,1		;78 : BAUD
	DEFOP	O_MCALL,3		;79 : MCALL
	DEFOP	ClearReg,0		;7A : INIT
	DEFOP	O_RESET,0		;7B : RESET
	DEFOP	O_BREAK,0		;7C : BREAK
	DEFOP	O_END,0		;7D : END
	DEFOP	O_ENDOS,0		;7E : ENDOS

NbrOpCode.B	EQU	{{*-OpProcTbl} SHR 1}

;	Error/break report text
;
;   ER=## OP=## PC=#### XP=#### XO=#### SA=#### EA=#### IC=#### SP=## FL=########
;
;	ER : Error code
;	OP : Opcode last processed (instruction on which error occured)
;	PC : Program counter (absolute EEPROM address)
;	XP : Execution Point, program counter relative to start of file
;	XO : Execution Offset, PC relative to instruction causing error
;	SA : Start Address of program file (absolute)
;	EA : End Address of program file +1 (absolute)
;	IC : Instruction Count, number of instructions executed since prog start
;	SP : Stack Pointer, relative to start of variable/register space
;	FL : Flags, the contents of SeqStat

SeqErrMsg	DC.B	CR
	STRING	"ER="
	DC.B	T_HexByte
	DC.W	ChanMask
	DC.B	2,2,0
	STRING	" OP="
	DC.B	T_HexByte
	DC.W	CLIndex
	DC.B	2,2,0
	STRING	" PC="
	DC.B	T_HexWord
	DC.W	SeqPC
	DC.B	4,4,0
	STRING	" XP="
	DC.B	T_HexWord
	DC.W	ExecPC
	DC.B	4,4,0
	STRING	" XO="
	DC.B	T_HexWord
	DC.W	CLPtr
	DC.B	4,4,0
	STRING	" SA="
	DC.B	T_HexWord
	DC.W	SeqStart
	DC.B	4,4,0
	STRING	" EA="
	DC.B	T_HexWord
	DC.W	SeqEnd
	DC.B	4,4,0
	STRING	" IC="
	DC.B	T_HexWord
	DC.W	InstrCnt
	DC.B	4,4,0
	STRING	" SP="
	DC.B	T_HexByte
	DC.W	SeqSP
	DC.B	2,2,0
	STRING	" FL="
	DC.B	T_BinByte
	DC.W	SeqCtrl
	DC.B	8,8,0
	DC.B	CR,NUL

;************************************************************************************

	END
