#ifndef __instruction_h__
#define __instruction_h__

#include "arg.h"

struct _instruction;

typedef struct {
	unsigned	string_args_allowed	:	1,
		data_args_required	:	1;

	char *(*validate)(struct _instruction *);
	int (*size)(struct _instruction *);
	int (*encode)(char *data, int *bytes_left, struct _instruction *instr);
	/* func output_function; */
} meta_instruction_def;

typedef struct _instruction {
	char *instruction;
	unsigned opcode;
	meta_instruction_def *meta_instruction;
	argument *args;

	struct _instruction *next;
} instruction;

extern meta_instruction_def db_meta_instruction;
extern meta_instruction_def dw_meta_instruction;

instruction *make_instruction(char *instr);
instruction *make_meta_instruction(char *keyword, argument *arg_chain);

void print_instruction(instruction *instr);
void print_text(int dlvl, instruction *instr);

char *validate_instruction(instruction *instr);
char *validate_db_instruction(instruction *instr);
char *validate_dw_instruction(instruction *instr);

int resolve_all_label_refs(instruction *instr);

int encoded_instruction_size(instruction *instr);
int encoded_text_size(instruction *instr);

int encode_instruction(char *data, int *bytes_left, instruction *instr);

int encode_data(char *data, int *bytes_left, instruction *instr);

int data_instruction_size(instruction *instr);

instruction *instr_chain_tail(instruction *instr);
instruction *append_instruction(instruction *chain, instruction *instr);

#endif /* __instruction_h__ */
