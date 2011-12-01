#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include "qualifier.h"
#include "symbol.h"
#include "arg.h"
#include "string.h"

/*
 *	Rules - rules for validating and encoding arguments
 */

validation_rule Rules[] = {
	/* mode_constant */
	{
		"constant",                         /* kind_of_arg */
		1, 0,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 1, 1),     /* enc_allowed_mask */
		allow_encodings(1, 0, 1, 0, 1),     /* neg_allowed_mask */
		1,                                  /* resolve_encoding */
		allow_acc_modes(1, 0),              /* acc_allowed_mask */
		{0xffff, 0xf, 0xff, 0xfff, 0xffff}, /* max_int */
		NULL,                               /* further_validation */
		encode_const,                       /* encode */
		0,                                  /* variable_size */
		{ .fixed = {0, 1, 2, 2, 3} }        /* size */
	},

	/* mode_register */
	{
		"register",                         /* kind_of_arg */
		1, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 0, 1),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		1,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xff, 0xf, 0xff, 0x0, 0xff},       /* max_int */
		NULL,                               /* further_validation */
		encode_register,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {0, 1, 2, 0, 2} }        /* size */
	},

	/* mode_r_indirect */
	{
		"register indirect",                /* kind_of_arg */
		1, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 0, 1),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		1,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xff, 0xf, 0xff, 0x0, 0xff},       /* max_int */
		NULL,                               /* further_validation */
		encode_register,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {0, 1, 2, 0, 2} }        /* size */
	},

	/* mode_array_c_ind */
	{
		"array element (const idx)",        /* kind_of_arg */
		0, 0,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 0),              /* acc_allowed_mask */
		{0xff, 0, 0, 0, 0},                 /* max_int */
		validate_array_c_index,             /* further_validation */
		encode_array_c_ind,                 /* encode */
		0,                                  /* variable_size */
		{ .fixed = {2, 0, 0, 0, 0} }        /* size */
	},

	/* mode_array_r_ind */
	{
		"array element (register idx)",     /* kind_of_arg */
		1, 0,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 0, 1),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),	    /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 0),              /* acc_allowed_mask */
		{0xff, 0xff, 0xff, 0, 0xff},        /* max_int */
		validate_array_r_index,             /* further_validation */
		encode_array_r_ind,                 /* encode */
		0,                                  /* variable_size */
		{ .fixed = {0, 2, 3, 0, 3} }        /* size */
	},

	/* mode_control */
	{
		"control variable",                 /* kind_of_arg */
		0, 0,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 0),              /* acc_allowed_mask */
		{0xff, 0, 0, 0, 0},                 /* max_int */
		validate_control_var,               /* further_validation */
		encode_control_var,                 /* encode */
		0,                                  /* variable_size */
		{ .fixed = {2, 0, 0, 0, 0} }        /* size */
	},

	/* mode_file */
	{
		"file I/O",                         /* kind_of_arg */
		0, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),			/* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xff, 0, 0, 0, 0},                 /* max_int */
		NULL,                               /* further_validation */
		encode_file_io,                     /* encode */
		0,                                  /* variable_size */
		{ .fixed = {1, 0, 0, 0, 0} }        /* size */
	},

	/* mode_ram */
	{
		"constant RAM adress",              /* kind_of_arg */
		1, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 0, 1),     /* enc_allowed_mask */
		allow_encodings(1, 0, 0, 0, 1),     /* neg_allowed_mask */
		1,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xffff, 0xff, 0xff, 0, 0xffff},    /* max_int */
		NULL,                               /* further_validation */
		encode_ram_addr,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {0, 2, 2, 0, 3} }        /* size */
	},

	/* mode_ram_indirect */
	{
		"indirect RAM adress",              /* kind_of_arg */
		0, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xff, 0, 0, 0, 0xff},              /* max_int */
		NULL,                               /* further_validation */
		encode_ram_addr,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {2, 0, 0, 0, 0} }        /* size */
	},

	/* mode_program */
	{
		"constant program-relative adress", /* kind_of_arg */
		0, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(1, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xffff, 0, 0, 0, 0},               /* max_int */
		NULL,                               /* further_validation */
		encode_ram_addr,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {3, 0, 0, 0, 0} }        /* size */
	},

	/* mode_program_indirect */
	{
		"indirect program-relative adress", /* kind_of_arg */
		0, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xff, 0, 0, 0, 0xff},              /* max_int */
		NULL,                               /* further_validation */
		encode_ram_addr,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {2, 0, 0, 0, 0} }        /* size */
	},

	/* mode_eeprom */
	{
		"EEPROM adress",                    /* kind_of_arg */
		0, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(1, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xffff, 0, 0, 0, 0},               /* max_int */
		NULL,                               /* further_validation */
		encode_ram_addr,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {3, 0, 0, 0, 0} }        /* size */
	},

	/* mode_eeprom_indirect */
	{
		"indirect EEPROM adress",           /* kind_of_arg */
		0, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xff, 0, 0, 0, 0xff},              /* max_int */
		NULL,                               /* further_validation */
		encode_ram_addr,                    /* encode */
		0,                                  /* variable_size */
		{ .fixed = {2, 0, 0, 0, 0} }        /* size */
	},

	/* mode_asm_constant */
	{
		"data",                             /* kind_of_arg */
		1, 1,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 0, 1),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 1),              /* acc_allowed_mask */
		{0xffff, 0xff, 0xff, 0, 0xffff},    /* max_int */
		NULL,                               /* further_validation */
		encode_data_const,                  /* encode */
		0,                                  /* variable_size */
		{ .fixed = {2, 1, 1, 0, 2} }        /* size */
	},

	/* mode_string */
	{
		"string",                           /* kind_of_arg */
		0, 0,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 0, 0, 0, 0),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 0),              /* acc_allowed_mask */
		{-1, 0, -1, 0, -1},                 /* max_int */
		NULL,                               /* further_validation */
		encode_string,                      /* encode */
		1,                                  /* variable_size */
		{ .variable = &string_size }        /* size */
	},

	/* mode_label_undef */
	{
		"forward label ref",                /* kind_of_arg */
		1, 0,                               /* set_enc_allowed, set_acc_allowed */
		allow_encodings(1, 1, 1, 1, 1),     /* enc_allowed_mask */
		allow_encodings(0, 0, 0, 0, 0),     /* neg_allowed_mask */
		0,                                  /* resolve_encoding */
		allow_acc_modes(1, 0),              /* acc_allowed_mask */
		{0xffff, 0xf, 0xff, 0xfff, 0xffff}, /* max_int */
		NULL,                               /* further_validation */
		NULL,                               /* encode */
		0,                                  /* variable_size */
		{ .fixed = {0, 1, 2, 2, 3} }        /* size */
	}
};

/*
 *  Argument construction functions - these contruct 'argument' data
 *  structures to represent operands that need to be encoded in the
 *  output.  Returns a malloc()ed pointer that eventually needs to get
 *  free()ed.
 */

/*
 *  int_arg - this will be the constructor for most kinds of argument.
 *  constructs any kind of argument that represents a single integer value.
 */

argument *int_arg(unsigned mode, unsigned value, qualifier q) {
	argument *arg = (argument *) malloc(sizeof (argument));

	arg->mode = mode;
	arg->value = value;
	arg->qual = q;

	arg->next = NULL;

	return arg;
}

/*
 *  array_elem_arg - constructor for array element parameters - fills in
 *  the index field of the structure as well, for parameters that require it.
 */

argument *array_elem_arg(unsigned mode, unsigned array, int idx, qualifier q) {
	argument *arg = (argument *) malloc(sizeof (argument));

	arg->mode = mode;
	arg->value = array;
	arg->index = idx;
	arg->qual = q;

	arg->next = NULL;

	return arg;
}

/*
 *  array_arg - a special-case constructor that builds a reference to an entire
 *  array (encoded as a reference to its first element)
 */

argument *array_arg(unsigned array, qualifier q) {
	argument *arg = (argument *) malloc(sizeof (argument));

	arg->mode = mode_array_c_ind;
	arg->value = array;
	arg->index = 0;
	arg->qual = q;

	arg->next = NULL;

	return arg;
}

/*
 *  forward_ref_arg - construct a reference to a symbol that doesn't yet
 *  exist.  It must be resolved by the end of compilation, or compilation
 *  will fail.  A pointer to the string is stored in the 'index' field.
 */

argument *forward_ref_arg(char *symbol, qualifier q) {
	argument *arg = (argument *) malloc(sizeof (argument));

	arg->mode = mode_label_undef;
	arg->value = 0;
	arg->index = (sym_val_t) cpstring(symbol);
	arg->qual = q;

	arg->next = NULL;

	return arg;
}

/*
 *  parse_file_arg - used by file_arg to parse a file i/o argument string
 *  (such as "~br" or "~wrw") into an integer value that can later be
 *  used to encode the output
 */

unsigned parse_file_arg(char *text) {
	int value = 0;

	/*
	 *  first char must be '~'
	 *  this is enforced by the lexer, but a little sanity check never hurts
	 */

	if(text++[0] == '~') {
		char c = text++[0];

		/*
		 *  next must be either 'b' or 'w' - "byte" or "word" access
		 *  this is also enforced by the lexer
		 */

		switch (c) {
			case 'B':
			case 'b':
				value |= file_io_byte;
				break;
			case 'W':
			case 'w':
				value |= file_io_word;
				break;
		}

		/*
		 *  next letter(s) can be "r", "rw", or "w"
		 *  also enforced by lexer
		 */

		while (c = text++[0]) {
			switch (c) {
				case 'R':
				case 'r':
					value |= file_io_read;
					break;
				case 'W':
				case 'w':
					value |= file_io_write;
					break;
			}
		}
	}

	return value;
}

/*
 *  file_arg - parse a file arg string and construct an 'argument'
 *  structure to encode it
 */

argument *file_arg(char *text) {
	argument *arg = (argument *) malloc(sizeof (argument));

	arg->mode = mode_file;
	arg->value = parse_file_arg(text);
	arg->qual = (qualifier) {0};
	arg->qual.access = file_byte(arg->value) ?  byte_access : word_access;

	arg->next = NULL;

	return arg;
}

/*
 *  argument list management stuff
 */

/*
 *  arg_chain_tail - fast-forward to the last argument in a linked list
 */

argument *arg_chain_tail(argument *arg) {
	while (arg && arg->next)
		arg = arg->next;

	return arg;
}

/*
 *  arg_append - put arg2 at the end of the chain starting at arg1, and
 *  return the head of the new chain (arg1, unless it's NULL)
 */

argument *arg_append(argument *arg1, argument *arg2) {
	if(arg1) {
		arg_chain_tail(arg1)->next = arg2;
		return arg1;
	}

	return arg2;
}


/*
 *  Argument printing, for debug purposes
 */

/*
 *  qualifier_encoding - characters for encoding qualifier
 *  qualifier_access - characters for access mode dot-qualifier
 */

static char *qualifier_encoding[] = { "a", "s", "y", "m", "l" };
static char *qualifier_access[] = {"b", "w"};

/*
 *  print_arg - output a description of the argument to stderr.
 *  does nothing if verbosity < 2
 */

void print_arg(argument *arg) {
	d_printf(2, "  %s arg: {0x%04x, 0x%02x, .%s%s} (%d bytes)\n",
		Rules[arg->mode].kind_of_arg,
		arg->value,
		arg->index,
		qualifier_encoding[arg->qual.encoding],
		(arg->qual.acc_set) ? (qualifier_access[arg->qual.access]) : "",
		encoded_size_of_arg(arg)
	);
}

/*
 *  print_arg_chain - output a description of all args, by
 *  calling print_arg for each
 */

void print_arg_chain(argument *head) {
	argument *arg = head;

	while (arg != NULL) {
		print_arg(arg);
		arg = arg->next;
	}
}

/*
 *  Location qualifier parsers
 *  These parse strings of the form "R:", "E:", "P:", ...
 */

/*
 *	default_qualifier - substituted if the parse string is undefined
 */

static char *default_qualifier = "R:";

/*
 *  mode_for_location - returns the mode_* constant for direct access to
 *  the location specified
 */

int mode_for_location(char *text) {
	if (text == NULL) {
		text = default_qualifier;
	}

	switch (text[0]) {
		case 'R':
		case 'r':
			return mode_ram;
			break;
		case 'E':
		case 'e':
			return mode_program;
			break;
		case 'P':
		case 'p':
			return mode_eeprom;
			break;
	}

	return -1;
}

/*
 *  indirect_mode_for_location - returns the mode_* constant for indirect
 *  access to the location specified
 */

int indirect_mode_for_location(char *text) {
	if (text == NULL) {
		text = default_qualifier;
	}

	switch (text[0]) {
		case 'R':
		case 'r':
			return mode_ram_indirect;
			break;
		case 'E':
		case 'e':
			return mode_program_indirect;
			break;
		case 'P':
		case 'p':
			return mode_eeprom_indirect;
			break;
	}

	return -1;
}

/*
 *  Data and macros for validation and encoding of arguments
 *  These basically set up a lot of shorthand for use later in the file
 *  'arg' in the macros below is a reference to "argument *arg", the
 *  main parameter in the functions these are for use in.
 */

/*
 *  Encoding_Strs - strings for use in printf() that will insert the
 *  name of the encoding given for the argument.  See where this is
 *  used and the reason for the spaces should be apparent.
 */

char *Encoding_Strs[] = {
	"",
	"short ",
	"byte ",
	"medium ",
	"long "
};

/*
 *  Access_Strs - same thing, but for access modes.  No spacing tricks
 *  here, cause there's never a need for a null string in place of
 *  these.
 */

char *Access_Strs[] = {
	"byte",
	"word"
};

/*
 *	Mode, Value, Index, Q - shorthand access to fields of 'arg'
 */

#define Mode                   (arg->mode)
#define Value                  (arg->value)
#define Index                  (arg->index)
#define	Q                      (arg->qual)

/*
 *	Encoding, Access - shorthand access to fields of 'arg->qual'
 *  Encoding_Str, Access_Str - lookup string representations for same
 */

#define Encoding               (Q.encoding)
#define Access                 (Q.access)
#define Encoding_Str           (Encoding_Strs[Encoding])
#define Access_Str             (Access_Strs[Access])

/* Rule - the validation rule that applies */

#define Rule                   (Rules[Mode])

/*
 *  encoding_valid, Neg_Allowed, access_valid - Look up whether
 *  different things are permitted, based on relevant validation_rule
 */

#define encoding_valid         (encoding_allowed(Rule.enc_allowed_mask, Encoding))
#define Neg_Allowed            (encoding_allowed(Rule.neg_allowed_mask, Encoding))
#define access_valid           (acc_mode_allowed(Rule.acc_allowed_mask, Access))

/*
 *  Max_Int - look up the largest unsigned value that can be encoded,
 *  based on mode and encoding
 */

#define Max_Int                (Rule.max_int[Encoding])

/*
 *  Sign - locate the sign bit for this encoding
 *  Sign_Ext - construct sign extension from encoding to C int
 *  Min_Int - construct the smallest 2's-comp negative int that will
 *    fit in the same number of bits as Max_Int
 */

#define Sign                   ((Max_Int + 1) >> 1)
#define Sign_Ext               (~ Max_Int)
#define Min_Int                (Sign | Sign_Ext)

/*
 *  Pos_In_Range(x) - determine whether x is in the range of unsigned
 *    integers that can be encoded
 *  Neg_In_Range(x) - determine whether x is in the range of negative
 *    signed integers that can be encoded (subject also to whether
 *    negative values are allowed)
*/

#define Pos_In_Range(x)        (x <= Max_Int)
#define Neg_In_Range(x)        (Neg_Allowed && (x >= Min_Int))

/*
 *	In_Range(x) - determine, after application of all rules, whether
 *    the value x can or cannot be encoded.
 */

#define In_Range(x)            (Pos_In_Range(x) || Neg_In_Range(x))

/*
 *  Trim(x) - mask x by Max_Int - has the effect of truncating the
 *  sign extension of negative values to an encodable size
 */

#define Trim(x)                {x &= Max_Int;}

/*
 *  Further_Validation - shorthand to access soid field of the
 *    relevant rule
 */

#define Further_Validation     (Rule.further_validation)

/*
 *  Should_Resolve - shorthand for the 'resolve_encoding' field - used
 *    to decide whether to try to resolve 'automatic' encodings
 */

#define Should_Resolve         (Rule.resolve_encoding)

/*
 *  validate_argument - check argument against all known rules.  If it's
 *  ok, return NULL.  Otherwise return a message saying what's wrong.
 */

char *validate_argument (argument *arg) {
	/* 1) Is Mode valid? */
	if (Mode >= n_modes)
		return "invalid argument type (internal error?)";

	/* 2) Is Encoding valid? */
	if (Q.enc_set) {
		/* 2a) Is Encoding allowed to be set? */
		if (! Rule.set_enc_allowed)
			return bprintf(
				"encoding may not be specified for %s args",
				Rule.kind_of_arg
			);

		/* 2b) Is given Encoding allowed for this kind of instruction? */
		if (! encoding_valid)
			return bprintf(
				"%sencoding not allowed for %s args",
				Encoding_Str,
				Rule.kind_of_arg
			);
	}

	/* 3) Is Access Mode valid? */
	if (Q.acc_set) {
		/* 3a) Is Access Mode allowed to be set? */
		if (! Rule.set_acc_allowed)
			return bprintf(
				"access mode may not be specified for %s args",
				Rule.kind_of_arg
			);

		/* 3b) Is given Access Mode allowed for this kind of instruction? */
		if (! access_valid)
			return bprintf(
				"%s access mode not allowed for %s args",
				Access_Str,
				Rule.kind_of_arg
			);
	}

	/* 4) Is Value within range? */
	if (! In_Range(Value))
		return bprintf(
			"value %d out of range for %s%s arg",
			Value,
			Encoding_Str,
			Rule.kind_of_arg
		);

	/* 4a) If in range and negative, trim value */
	if (Neg_In_Range(Value))
		Trim(Value);

	/* 5) Should encoding be resolved? */
	if (Should_Resolve)
		resolve_encoding(arg);

	/* 6) Is there anything else, argument-type specific? */
	if (Further_Validation) {
		char *msg = Further_Validation(arg);

		if (msg)
			return msg;
	}

	/* all seems ok */
	return NULL;
}

/*
 *  validate_array_c_index - arg-type specific validation for array
 *  elements indexed by contstant values
 */

char *validate_array_c_index(argument *arg) {
	int N_Indices;

	/* 1) Does it refer to a valid array? */
	if (Value >= n_arrays)
		return bprintf(
			"value %d out of range for array args - there are only %d arrays",
			Value,
			n_arrays
		);

	/* 2) Is the index within bounds?  */
	N_Indices = array_sizes[Value];
	if (Index >= N_Indices)
		return bprintf(
			"index out of range (%d) - @%s has only %d elements",
			Index,
			array_names[Value],
			N_Indices
		);

	/* seems ok */
	return NULL;
}

/*
 *  Array_R_Index_Rule - special case validation_rule for array
 *  element args indexed by register
 */

validation_rule Array_R_Index_Rule = {
	"index register",                     /* kind_of_arg */
	1, 0,                                 /* set_enc_allowed, set_acc_allowed */
	allow_encodings(1, 1, 0, 0, 1),       /* enc_allowed_mask */
	allow_encodings(0, 0, 0, 0, 0),       /* neg_allowed_mask */
	0,                                    /* resolve_encoding */
	allow_acc_modes(1, 0),                /* acc_allowed_mask */
	{0xff, 0xf, 0, 0, 0xff},              /* max_int */
};

/*
 *  Make 'Rule' refer to this structure
 */

#undef  Rule
#define Rule                   Array_R_Index_Rule

/*
 *  validate_array_r_index - special-case validation for array
 *  element args indexed by registers
 */

char *validate_array_r_index(argument *arg) {
	/* 1) Is specified array valid? */
	if (Value >= n_arrays)
		return bprintf(
			"value %d out of range for array args - there are only %d arrays",
			Value,
			n_arrays
		);

	/* 2) Is register index in range? */
	if (! In_Range(Index))
		return bprintf(
			"value %d out of range for %s%s",
			Index,
			Encoding_Str,
			Rule.kind_of_arg
		);

	/* 3) Resolve automatic encodings */
	if (Encoding == auto_encoding) {
		if (Value <= Rule.max_int[short_encoding])
			Encoding = short_encoding;
		else
			Encoding = long_encoding;
	}

	/* seems ok */
	return NULL;
}

/* Restore original definition for Rule macro */

#undef  Rule
#define Rule                   (Rules[Mode])

/*
 *  validate_control_var - special-case validation for control
 *  variable arguments
 */

char *validate_control_var(argument *arg) {
	if (Value >= n_control_vars)
		return bprintf(
			"value %d out of range for a control var - there are only %d",
			Value,
			n_control_vars
		);

	return NULL;
}

/*
 *  Automatic encoding resolution
 */

/*
 *  Slight modification of macros -
 *    Max_Int now takes encoding as an arg
 *    In_Range now also takes encoding as an arg
 */

#undef  Max_Int
#define Max_Int(e)             (Rule.max_int[e])
#undef  In_Range
#define In_Range(val, enc)     (val <= Max_Int(enc))

/*
 *  New macros -
 *    Better_MaxInt - returns true if encoding a has a smaller
 *  max int (and therefore takes less space)
 *    Valid_Enc - return true if given encoding is allowed
 *    Better_Encoding - return true if 'a' is a "better" encoding
 *  than 'b' - that is,
 *      1) it is valid
 *      2) the value to be encoded fits
 *        and
 *      3) it takes less space
 */

#define Better_MaxInt(a, b)    (Max_Int(a) < Max_Int(b))

#define Valid_Enc(a)           (encoding_allowed(Rule.enc_allowed_mask, a))

#define Better_Encoding(a, b)  (Valid_Enc(a) && In_Range(Value, a) \
                               && Better_MaxInt(a, b))

/*
 *  resolve_encoding - Find the best legal encoding for the value
 *  of the argument given
 */

void resolve_encoding(argument *arg) {
	int enc;
	int best_enc = long_encoding;

	for (
		enc = auto_encoding + 1;
		enc < long_encoding;
		enc++
	) {
		if (Better_Encoding(enc, best_enc))
			best_enc = enc;
	}

	Encoding = best_enc;
}

/*
 *  Label resolution
 */

/*
 *  unresolved_labels - used to track labels we were unable to resolve,
 *  and how many times they appeared
 */

symbol_table unresolved_labels = NULL;

/*
 *  resolve_label_refs - call 'resolve_label_ref' for each argument
 *  in a linked list
 */

int resolve_label_refs(argument *chain) {
	int failure = 0;

	while (chain) {
		failure |= resolve_label_ref(chain);
		chain = chain->next;
	}

	return failure;
}

/*
 *  resolve_label_ref - if arg is an unresolved reference, try to
 *  resolve it.  Return 0 on success, nonzero on failure.
 */

int resolve_label_ref(argument *arg) {
	if (Mode == mode_label_undef) {
		if (symbol_exists(labels, (char *) Index)) {
			char *msg;
			char *label;

			Mode = mode_constant;
			label = (char *) Index;
			Value = symbol_value(labels, label);
			Index = 0;

			msg = validate_argument(arg);

			if (msg) {
				eprintf("Resolving Label \"%s\": %s\n", label, msg);
				return 1;
			}

			return 0;
		} else {
			if (unresolved_labels) {
				set_symbol(
					unresolved_labels,
					(char *) Index,
					symbol_value(unresolved_labels, (char *) Index) + 1
				);
			}
			return 1;
		}
	}

	return 0;
}

/*
 *  Encoded-size prediction
 */

/*
 *  encoded_size_of_arg - look up and return encodiei size of argument.
 *  If necessary, call function vector to compute size.
 */

int encoded_size_of_arg(argument *arg) {
	if (Rule.variable_size) {
		return Rule.size.variable(arg);
	}

	return Rule.size.fixed[Encoding];
}

/*
 *  encode_argument - call encoding rule for argument type.  If unable,
 *  alert user and advance write head, so labels will still work in
 *  the rest of the code
 */

int encode_argument(char *data, int *bytes_left, argument *arg) {
	int count;

	if (Rule.encode)
		return Rule.encode(data, bytes_left, arg);

	eprintf("quence: unable to encode argument\n");
	print_arg(arg);

	count = encoded_size_of_arg(arg);
	*bytes_left -= count;
	return count;
}

/*
 *  Some macros to simplify output routines - highly inefficient,
 *  but well worth it for mental energy spared (I know I made the
 *  output stuff overly complex, but c'mon - it was like 2AM!)
 *    put_byte - insert byte to output, advance write head by 1
 *    make_byte - make a byte from 2 nybbles
 *    put_nybbles - make a byte and put it
 */

#define put_byte(byte)         { *(data++) = (byte & 0xff); (*bytes_left)--; bytes_written++; }
#define make_byte(hi,lo)       (((hi << 4) & 0xf0) | (lo & 0x0f))
#define put_nybbles(hi, lo)    (put_byte(make_byte(hi,lo)))

/*
 *  hi - get the high byte of a word
 *  lo - get the low byte of a word
 */

#define hi(word)               ((word >> 8) & 0xff)
#define lo(word)               (word & 0xff)

/*
 *  encode_const - encode constant values
 */

int encode_const(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	switch (Encoding) {
		case short_encoding:
			put_nybbles(0x0, Value);
			break;
		case medium_encoding:
			put_nybbles(0x1, hi(Value));
			put_byte(lo(Value));
			break;
		case byte_encoding:
			put_nybbles(0x2, 0x0);
			put_byte(Value);
			break;
		case long_encoding:
			put_nybbles(0x2, 0x1);
			put_byte(hi(Value));
			put_byte(lo(Value));
			break;
	}

	return bytes_written;
}

/*
 *  indirect_offset - (3 or 0) to be added to hi nybble of first
 *    byte, depending on whether the arg is a direct or indirect
 *    register access
 *  first_nybble - write 2 nybbles, adding offset where needed
 */

#define indirect_offset        ((Mode == mode_r_indirect) ? 3 : 0)
#define first_nybble(hi,lo)    (put_nybbles(hi + indirect_offset, lo))

/*
 *  encode_register - encode register values
 */

int encode_register(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	switch (Encoding) {
		case short_encoding:
			switch (Access) {
				case byte_access:
					first_nybble(0x4, Value);
					break;
				case word_access:
					first_nybble(0x5, Value);
					break;
			}
			break;
		case byte_encoding:
		case long_encoding:
			switch (Access) {
				case byte_access:
					first_nybble(0x6, 0x0);
					put_byte(Value);
					break;
				case word_access:
					first_nybble(0x6, 0x1);
					put_byte(Value);
					break;
			}
			break;
	}

	return bytes_written;
}

/*
 *  these are pretty self-explanatory for a while...
 */

int encode_array_c_ind(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	put_nybbles(0xa, Index);
	put_byte(Value);

	return bytes_written;
}

int encode_array_r_ind(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	switch (Encoding) {
		case short_encoding:
			put_nybbles(0xb, Index);
			put_byte(Value);
			break;
		case byte_encoding:
		case long_encoding:
			put_nybbles(0xc, 0x0);
			put_byte(Index);
			put_byte(Value);
			break;
	}

	return bytes_written;
}

int encode_control_var(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	put_nybbles(0xc, 0x1);
	put_byte(Value);

	return bytes_written;
}

int encode_file_io(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;
	int value = Value;

	if (file_write(value))
		value ^= file_io_read;

	put_nybbles(0xc, value);

	return bytes_written;
}

#define put_word(x)            {put_byte(hi(x)); put_byte(lo(x));}
#define access_offset          ((Access == byte_access) ? 0 : 1)
#undef  first_nybble
#define first_nybble(hi, lo)   put_nybbles(hi, lo + access_offset)

int encode_ram_addr(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	switch (Mode) {
		case mode_ram:
			switch (Encoding) {
				case short_encoding:
				case byte_encoding:
					first_nybble(0xf, 0x0);
					put_byte(Value);
					break;
				case long_encoding:
					first_nybble(0xf, 0x2);
					put_word(Value);
					break;
			}
			break;
		case mode_ram_indirect:
			first_nybble(0xf, 0x4);
			put_byte(Value);
			break;
		case mode_program:
			first_nybble(0xf, 0x6);
			put_word(Value);
			break;
		case mode_program_indirect:
			first_nybble(0xf, 0x8);
			put_byte(Value);
			break;
		case mode_eeprom:
			first_nybble(0xf, 0xa);
			put_word(Value);
			break;
		case mode_eeprom_indirect:
			first_nybble(0xf, 0xc);
			put_byte(Value);
			break;
	}

	return bytes_written;
}

int encode_data_const(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;

	switch (Encoding) {
		case short_encoding:
		case byte_encoding:
			put_byte(Value);
			break;
		case long_encoding:
			put_word(Value);
			break;
	}

	return bytes_written;
}

int encode_string(char *data, int *bytes_left, argument *arg) {
	int bytes_written = 0;
	char *str = (char *) Value;

	while (str[0]) {
		put_byte(str[0]);

		str++;
	}

	put_byte(0);

/*
	if (Encoding == long_encoding) {
		if (bytes_written % 2)
			put_byte(0);
	}
*/

	return bytes_written;
}

/*
 *  string_size - special case size-predictor for const string args
 */

#define Word_Encoding          (Encoding == long_encoding)

int string_size(argument *arg) {
	int length = strlen((char *) Value);
	int size = length + 1;

/*
	if (Word_Encoding) {
		size += (size & 1);
	}
*/

	return size;
}
