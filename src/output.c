#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "asm.h"
#include "instruction.h"
#include "arg.h"
#include "output.h"
#include "string.h"

#define CPP_CMD_LEN 256
#define CPP_TEMP_FILE "quence.tmp"

//extern int errno;

unsigned long output_address = 0;
int safe_write = 0;
char *out_ext = "";

int start_preprocessor(char *cpp, char *in_name, FILE **in_fd) {

	char cmdline[CPP_CMD_LEN];
	int err;

	if (cpp != NULL) {
//		if (access(cpp, X_OK))
//			return 1;
		if (in_name != NULL) {
			if (access(in_name, R_OK))
				return 2;
			sprintf(cmdline, "%s -o %s %s", cpp, CPP_TEMP_FILE, in_name);
		} else {
			sprintf(cmdline, "%s -o %s", cpp, CPP_TEMP_FILE);
		}

		err = system(cmdline);
		if (err) return 3;

		*in_fd = fopen(CPP_TEMP_FILE, "r");
		if (errno) return 2;
		return 0;

	} else {

		if (in_name != NULL) {
			*in_fd = fopen(in_name, "r");
			if (errno) return 2;
		} else {
			*in_fd = stdin;
		}
		return 0;
	}
}

output_thingy *new_output(char *source_file) {
	output_thingy *out = (output_thingy *) malloc(sizeof *out);

	out->source_file = source_file;
	out->output_file = change_ext(source_file, out_ext);

	out->source_lines = 0;
	out->output_bytes = 0;

	out->data = NULL;
	out->output_pos = 0;

	return out;
}

void set_output_file(output_thingy *out, char *file) {
	free(out->output_file);

	out->output_file = cpstring(file);
}

int compile_text(output_thingy *out, instruction *text) {
	instruction *instr;
	int bytes_left;
	int i;

	out->source_lines = asm_linenum;
	bytes_left = out->output_bytes = encoded_text_size(parsed_text);

	out->data = (char *) malloc(out->output_bytes);
	out->output_pos = 0;

	for (i=0; i < out->output_bytes; i++)
		out->data[i] = 0;
//	bzero(out->data, out->output_bytes);

	for (instr = text; instr != NULL; instr = instr->next)
		out->output_pos += encode_instruction(out->data + out->output_pos, &bytes_left, instr);

	return out->output_pos;
}

int output_data(output_thingy *out) {
	FILE *outfile = fopen(out->output_file, "w");
	int count;

	if (outfile == NULL)
		return -1;

	count = fwrite(out->data, 1, out->output_bytes, outfile);

	fclose(outfile);

	if (count < out->output_bytes)
		return count + 1;

	return 0;
}

extern FILE *yyin;
int quence(char *src, char *output) {
	output_thingy *out;

	int sz_theory;
	int sz_actual;

	int success;
	int err;

	/* Parse the input file */

//	if (src[0] = 0)
//		yyin = stdin;
//	else
//		yyin = fopen(src, "r");

	err = start_preprocessor(preprocessor, src, &yyin);
	switch (err) {
		case 0 : break;
		case 1 :
			eprintf("Preprocessor executable \"%s\" not found.\n", preprocessor);
			break;
		case 2 :
			eprintf("Could not open input file \"%s\" for reading.\n", src);
			break;
		case 3 :
			eprintf("Preprocessor \"%s\" returned error on file \"%s\".\n", preprocessor, src);
			break;
		default :
			eprintf("Unknown preprocessor error (%d).\n", err);
	}
	if (err) return 1;

	asm_source_file = cpstring(src);
	asm_base_file = cpstring(src);
	asm_linenum = 1;
	success = (yyparse() == 0);

	/* Close input file, and delete temporary file if used */

	if (fileno(yyin) != STDIN_FILENO) {
		fclose(yyin);
		if (preprocessor != NULL)
			unlink(CPP_TEMP_FILE);
	}

	if (! success)
		return 1;

	/* Check for unresolvable label refs */

	if (resolve_all_label_refs(parsed_text) != 0) {
		eprintf("Unresolved labels (and number of occurences):\n");
		print_table(0, unresolved_labels);
		eprintf("\n");

		return 2;
	}

	/* Print parsed text */

	d_printf(2, "Input file %s parsed as follows:\n", src);
	print_text(2, parsed_text);
	d_printf(2, "\n");

	/* output assembled data */

	out = new_output(src);
	if (output)
		set_output_file(out, output);

	sz_theory = encoded_text_size(parsed_text);
	sz_actual = compile_text(out, parsed_text);

	if (sz_theory == sz_actual) {
		output_data(out);
		eprintf("Syntax OK: %d bytes written.\n", sz_actual);
	} else {
		if (! safe_write) {
			output_data(out);
			eprintf("Internal compile error: %d of %d bytes written.\n", sz_actual, sz_theory);
		} else {
			eprintf("Internal compile error: %d of %d bytes generated (0 written).\n", sz_actual, sz_theory);
		}
		return 3;
	}

	return 0;
}
