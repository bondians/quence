/*
 *  token_value - union type for passing values from the lexer to the parser
 */

typedef union {
		long int i;
		float f;
		char c;
		char *s;
	} token_value;

extern token_value asm_token;

extern char *asm_source_file;
extern char *asm_base_file;
extern int asm_linenum;

extern void *parsed_text;
