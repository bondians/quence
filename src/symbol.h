#ifndef __symbol_h__
#define __symbol_h__

typedef long sym_val_t;

typedef struct symbol {
		char *name;
		sym_val_t value;

		/* b-tree links */
		struct symbol *l;
		struct symbol *r;
} symbol;

typedef struct {
		char *name;
		sym_val_t value;
} symbol_init;

typedef struct {
		symbol *root;
		int		case_sensitive;
} *symbol_table;

#define root(table)	(table->root)

int compare(char *str1, char *str2, int case_sense);

void set_symbol(symbol_table table, char *name, sym_val_t value);
sym_val_t symbol_value(symbol_table table, char *symname);
int symbol_exists(symbol_table, char *symname);

symbol *new_node(char *name, sym_val_t value);
symbol *locate_sym(symbol_table table, char *name);

void print_table(int lvl, symbol_table table);
void print_node(symbol *node);

symbol_table new_table();

symbol_table init_table(symbol_init symbols[]);

/* global symbol tables for use by the quence assembler */
extern symbol_table labels;
extern symbol_table identifiers;

extern symbol_table keywords;
extern symbol_table opcodes;
extern symbol_table argcounts;

extern symbol_table array_ids;
extern unsigned array_sizes[];
extern char * array_names[];
extern const int n_arrays;

extern symbol_table control_vars;
extern const int n_control_vars;
extern char * control_var_names[];

#endif /* __symbol_h__ */
