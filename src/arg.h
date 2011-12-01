#ifndef __arg_h__
#define __arg_h__

#include "qualifier.h"
#include "symbol.h"

/*
 *  argument 'mode' or type constants
 */

#define	mode_constant         0x00
#define mode_register         0x01
#define mode_r_indirect       0x02
#define mode_array_c_ind      0x03
#define mode_array_r_ind      0x04
#define	mode_control          0x05
#define mode_file             0x06
#define mode_ram              0x07
#define mode_ram_indirect     0x08
#define mode_program          0x09
#define mode_program_indirect 0x0a
#define mode_eeprom           0x0b
#define mode_eeprom_indirect  0x0c
#define mode_asm_constant     0x0d
#define mode_string           0x0e
#define mode_label_undef      0x0f

#define n_modes               0x10

/*
 *  mode_is_valid - check if the given mode really exists
 *  mode_is_data - check if the given mode is a valid constant data mode
 */

#define mode_is_valid(mode)	(((unsigned) mode) < ((unsigned) n_modes))
#define mode_is_data(mode)	((mode == mode_asm_constant) || (mode == mode_string))

/*
 *  file i/o flags - used to encode file i/o operations, in the 'value'
 *  field of the 'argument' structure
 */

#define file_io_read      0x2
#define file_io_write	    0x4
#define file_io_rw        (file_read | file_write)
#define file_io_byte      0x0
#define file_io_word      0x1

/*
 *  Various macros to test those flags
 */

#define file_read(A)      (A & file_io_read)
#define file_write(A)     (A & file_io_write)
#define file_rw(A)        (file_read(A) || file_write(A))
#define file_word(A)      (A & file_io_word)
#define file_byte(A)      (! file_word(A))

/*
 *	argument - type used to represent arguments to quence instructions
 *  consists of:
 *    mode - the kind of arg it is
 *	  value - the value of the arg, or the array if it's an array elem arg
 *    index - the index of the array elem, if applicable
 *    qual - qualifications on the arg (ie, ".s")
 *
 *    next - a pointer to the next arg, used to make a linked list of all
 *           args of a given instruction
 */

typedef struct _arg {
	unsigned	mode;
	sym_val_t 	value;
	sym_val_t	index;

	qualifier	qual;

	struct _arg *next;
} argument;

/*
 *  constructor functions - these allocate and fill in the fields of
 *  'argument' structures
 */

argument *int_arg(unsigned mode, unsigned value, qualifier q);
argument *file_arg(char *arg);
argument *array_elem_arg(unsigned mode, unsigned array, int idx, qualifier q);
argument *array_arg(unsigned array, qualifier q);
argument *forward_ref_arg(char *symbol, qualifier q);

/*
 *  Argument list manipulation
 */

argument *arg_chain_tail(argument *arg);
argument *arg_append(argument *arg1, argument *arg2);

/*
 *  Argument printing, for debug use
 */

void print_arg(argument *arg);
void print_arg_chain(argument *head);

/*
 *  various short-string parsers
 */

unsigned parse_file_arg(char *text);
int mode_for_location(char *text);

/*
 *  function vector types, for validation rules
 */

typedef char *(*val_func)(argument *);
typedef int (*size_func)(argument *);
typedef int (*enc_func)(char *data, int *bytes_left, argument *arg);

/*
 *  validation_rule - data structure describing how arguments of
 *  different types are to be handled when validating and encoding
 *  them
 */

typedef struct {
	/*
	 *  kind_of_arg - a string describing the kind of argument
	 *  that the rule handles.  Used in formatting error strings.
	 */

	char 	   *kind_of_arg;

	/* flags descibing whether encoding and access mode may be set */

	unsigned
		set_enc_allowed	:	1,
		set_acc_allowed	:	1,

		/* bitmap describing which encodings are valid */
		enc_allowed_mask:	5,
		/* bitmap describing which encodings allow negative parameter values */
		neg_allowed_mask:	5,

		#define allow_encodings(a, s, y, m, l)		(a | (s << 1) | (y << 2) | (m << 3) | (l << 4))
		#define encoding_allowed(mask, encoding)	(mask & (1 << encoding))

		/* flag indicating whether to resolve unspecified encodings */
		resolve_encoding:	1,

		/* bitmap describing which access mode are valid */
		acc_allowed_mask:	2;

		#define allow_acc_modes(b, w)				(b | (w << 1))
		#define acc_mode_allowed(mask, mode)		(mask & (1 << mode))

		/* max_int for each encoding */
		unsigned	max_int[5];

		/* functions to call for special-case validation and encoding */
		val_func	further_validation;
		enc_func	encode;

		/* flag - whether to use fixed encoding lookup table or call a function */
		unsigned	variable_size	:	1;

	union {
		/* encoding sizes for each encoding */
		unsigned fixed[5];
		/* function to compute encoded size */
		size_func variable;
	} size;
} validation_rule;

/*
 *  Rules - the main table of validation_rule's, indexed by 'mode'
 */

extern validation_rule Rules[];

/*
 *  validate_argument - check argument against all known rules.  If it's
 *  ok, return NULL.  Otherwise return a message saying what's wrong.
 */

char *validate_argument(argument *arg);

/*
 *  special-case validation functions
 */

char *validate_array_c_index(argument *arg);
char *validate_array_r_index(argument *arg);
char *validate_control_var(argument *arg);

/*
 *  resolve_encoding - Find the best legal encoding for the value
 *  of the argument given
 */

void resolve_encoding(argument *arg);

/*
 *  Forward reference resolution
 */

int resolve_label_refs(argument *chain);
int resolve_label_ref(argument *arg);
extern symbol_table unresolved_labels;

/*
 *  Encoded size prediction
 */

int encoded_size_of_arg(argument *arg);
int string_size(argument *arg);

/*
 *  Argument encoding (for output)
 */

int encode_argument(char *data, int *bytes_left, argument *arg);
int encode_const(char *data, int *bytes_left, argument *arg);
int encode_register(char *data, int *bytes_left, argument *arg);
int encode_array_c_ind(char *data, int *bytes_left, argument *arg);
int encode_array_r_ind(char *data, int *bytes_left, argument *arg);
int encode_control_var(char *data, int *bytes_left, argument *arg);
int encode_file_io(char *data, int *bytes_left, argument *arg);
int encode_ram_addr(char *data, int *bytes_left, argument *arg);
int encode_data_const(char *data, int *bytes_left, argument *arg);
int encode_string(char *data, int *bytes_left, argument *arg);

#endif /* __arg_h__ */
