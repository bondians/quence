#ifndef __output_h__
#define __output_h__

#include "instruction.h"

typedef struct {
	char *source_file;
	char *output_file;

	unsigned source_lines;
	unsigned output_bytes;

	unsigned char *data;
	unsigned output_pos;
} output_thingy;

extern unsigned long output_address;

output_thingy *new_output(char *source_file_name);
void set_output_file(output_thingy *out, char *file);

int compile_text(output_thingy *out, instruction *text);
int output_data(output_thingy *out);

int quence(char *src, char *output);

extern int safe_write;
extern char *out_ext;
extern char *preprocessor;

#endif /* __output_h__ */
