#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#include "instruction.h"
#include "symbol.h"
#include "string.h"
#include "opcodes.h"

meta_instruction_def db_meta_instruction = {
	1,                        /* string_args_allowed */
	1,                        /* data_args_required */
	validate_db_instruction,  /* validate */
	data_instruction_size,    /* size */
	encode_data               /* encode */
};

meta_instruction_def dw_meta_instruction = {
	1,                        /* string_args_allowed */
	1,                        /* data_args_required */
	validate_dw_instruction,  /* validate */
	data_instruction_size,    /* size */
	encode_data               /* encode */
};

#define ERR_BUF_SIZE        1024

char *ordinal[] = {
	"first",
	"second",
	"third",
	"fourth",
	"fifth",
	"sixth",
	"seventh",
	"eighth"
};

#define count(array)    (sizeof (array) / sizeof(array[0]))
#define Ordinal(n)      ((n < count(ordinal)) ? ordinal[n] : "" )
#define Meta            (instr->meta_instruction)
#define Opcode          (instr->opcode)
#define Is_Meta         ((Opcode == -1) && (Meta != NULL))
#define String_Allowed  (Is_Meta && Meta->string_args_allowed)
#define Data_Required   (Is_Meta && Meta->data_args_required)

#define Mode            (arg->mode)

static char err_buf[ERR_BUF_SIZE];


instruction *make_instruction(char *text) {
	instruction *instr = (instruction *) malloc(sizeof (instruction));

	instr->instruction = cpstring(text);
	instr->opcode = symbol_value(opcodes, text);
	instr->meta_instruction = NULL;
	instr->args = NULL;

	instr->next = NULL;

	return instr;
}

instruction *make_meta_instruction(char *keyword, argument *arg_chain) {
	instruction *instr = (instruction *) malloc(sizeof (instruction));

	instr->instruction = cpstring(keyword);
	instr->opcode = -1;
	instr->meta_instruction = (meta_instruction_def *) symbol_value(keywords, keyword);
	instr->args = arg_chain;

	instr->next = NULL;

	return instr;
}

void print_text(int dlvl, instruction *instr) {
	if (verbosity >= dlvl)
		while (instr) {
			print_instruction(instr);
			instr = instr->next;
		}
}

void print_meta_instruction(instruction *instr) {
	printf("Meta-Instruction: %s\n", instr->instruction);
	print_arg_chain(instr->args);
}

void print_instruction(instruction *instr) {
	if (Is_Meta)
		return print_meta_instruction(instr);

	printf(
			"Instruction: %s (opcode: 0x%02x, size: %d bytes)\n",
			instr->instruction,
			Opcode,
			encoded_instruction_size(instr)
		);
	print_arg_chain(instr->args);
}

int count_args(instruction *instr) {
	int cnt = 0;
	argument *arg = instr->args;

	while (arg) {
		cnt++;
		arg = arg->next;
	}

	return cnt;
}

char *validate_instruction(instruction *instr) {
	int argc = symbol_value(argcounts, instr->instruction);
	int cnt = count_args(instr);

	int idx;

	char *err_msg;

	argument *arg;

	if (Is_Meta) {
		argc = cnt;

		err_msg = Meta->validate(instr);
		if (err_msg)
			return err_msg;
	}

	if (cnt != argc) {
		sprintf(
			err_buf,
			"Wrong number of arguments for \"%s\".  Expected %i, parsed %i",
			instr->instruction,
			argc,
			cnt
		);
		return err_buf;
	}

	for (idx = 0, arg = instr->args; idx < cnt; idx++, arg = arg->next) {
		if ((Mode == mode_string) && ! String_Allowed) {
			sprintf(
				err_buf,
				"String arguments are not allowed for \"%s\"",
				instr->instruction
			);
			return err_buf;
		}

		if (Data_Required && ! mode_is_data(Mode)) {
			sprintf(
				err_buf,
				"\"%s\" accepts constant data arguments only",
				instr->instruction
			);
			return err_buf;
		}

		err_msg = validate_argument(arg);
		if (err_msg) {
			sprintf(
				err_buf,
				"%s arg: %s",
				Ordinal(idx),
				err_msg
			);
			return err_buf;
		}

	}

	return NULL;
}

#define Encoding	(arg->qual.encoding)

char *validate_db_instruction(instruction *instr) {
	argument *arg;

	for (arg = instr->args; arg != 0; arg = arg->next) {
		if ((Encoding == auto_encoding) || (Encoding == short_encoding)) {
			Encoding = byte_encoding;
		}

		if (Encoding != byte_encoding) {
			sprintf(
				err_buf,
				"\"%s\" accepts byte-sized arguments only",
				instr->instruction
			);
			return err_buf;
		}
	}

	return NULL;
}

char *validate_dw_instruction(instruction *instr) {
	argument *arg;

	for (arg = instr->args; arg != 0; arg = arg->next) {
		if (Encoding == auto_encoding) {
			Encoding = long_encoding;
		}

		if (Encoding != long_encoding) {
			sprintf(
				err_buf,
				"\"%s\" accepts word-sized arguments only",
				instr->instruction
			);
			return err_buf;
		}
	}

	return NULL;
}

int resolve_all_label_refs(instruction *instr) {
	int failure = 0;

	unresolved_labels = new_table();

	while (instr) {
		failure |= resolve_label_refs(instr->args);
		instr = instr->next;
	}

	return failure;
}

int encoded_instruction_size(instruction *instr) {
	int size = 1;
	argument *arg;

	if (Is_Meta)
		return Meta->size(instr);

	for (arg = instr->args; arg != NULL; arg = arg->next) {
		size += encoded_size_of_arg(arg);
	}

	return size;
}

int encoded_text_size(instruction *instr) {
	int size = 0;

	while (instr) {
		size += encoded_instruction_size(instr);
		instr = instr->next;
	}

	return size;
}

#define put_byte(byte)		{ *(data++) = byte; (*bytes_left)--; bytes_written++; }

int encode_instruction(char *data, int *bytes_left, instruction *instr) {
	int bytes_written = 0;
	argument *arg;

	if (Is_Meta) {
		return Meta->encode(data, bytes_left, instr);
	}

	if (*bytes_left > 0) {
		put_byte(Opcode);

		for (
			arg = instr->args;
			(*bytes_left > 0) && (arg != NULL);
			arg = arg->next
		) {
			int count = encode_argument(data, bytes_left, arg);
			bytes_written += count;
			data += count;
		}
	}

	return bytes_written;
}

int encode_data(char *data, int *bytes_left, instruction *instr) {
	int bytes_written = 0;
	argument *arg;

	for (
		arg = instr->args;
		(*bytes_left > 0) && (arg != NULL);
		arg = arg->next
	) {
		int count = encode_argument(data, bytes_left, arg);
		bytes_written += count;
		data += count;
	}

	return bytes_written;
}


int data_instruction_size(instruction *instr) {
	int size = 0;
	argument *arg;

	for (arg = instr->args; arg != NULL; arg = arg->next) {
		size += encoded_size_of_arg(arg);
	}

	return size;
}

instruction *instr_chain_tail(instruction *instr) {
	if (instr)
		while (instr->next)
			instr = instr->next;

	return instr;
}

instruction *append_instruction(instruction *chain, instruction *instr) {
	instruction *tail = instr_chain_tail(chain);

	if (tail)
		tail->next = instr;

	return tail ? chain : instr;
}
