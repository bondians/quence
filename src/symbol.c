#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#include "symbol.h"
#include "string.h"

/* global symbol tables for use by the quence assembler */
symbol_table labels;
symbol_table identifiers;

symbol_table keywords;
symbol_table opcodes;
symbol_table argcounts;

symbol_table array_ids;

symbol_table control_vars;

int compare(char *str1, char *str2, int case_sense) {
	return case_sense ? strcmp(str1, str2) : strcasecmp(str1, str2);
}

void set_symbol(symbol_table table, char *name, sym_val_t value) {
	symbol *node = root(table);

	if (root(table) == NULL) {
		root(table) = new_node(name, value);
		return;
	}

	while (node) {
		int cmp = compare(name, node->name, table->case_sensitive);

		if (cmp < 0) {
			if (node->l) {
				node = node->l;
			} else {
				node->l = new_node(name, value);
				node = NULL;
			}
		} else if (cmp == 0) {
			node->value = value;
			node = NULL;
		} else {
			if (node->r) {
				node = node->r;
			} else {
				node->r = new_node(name, value);
				node = NULL;
			}
		}
	}
}

sym_val_t symbol_value(symbol_table table, char *symname) {
	symbol *node = locate_sym(table, symname);

	return node ? node->value : 0;
}

int symbol_exists(symbol_table table, char *symname) {
	symbol *node = locate_sym(table, symname);

	return (node != 0);
}

symbol *new_node(char *name, sym_val_t value) {
	symbol *node = (symbol *) malloc (sizeof (symbol));

	node->name = name;
	node->value = value;
	node->r = node->l = NULL;

	return node;
}

symbol *locate_sym(symbol_table table, char *name) {
	symbol *node = root(table);
	symbol *located = NULL;

	while (node) {
		int cmp = compare(name, node->name, table->case_sensitive);

		if (cmp < 0) {
			if (node->l)
				node = node->l;
			else
				node = NULL;
		} else if (cmp == 0) {
			located = node;
			node = NULL;
		} else {
			if (node->r)
				node = node->r;
			else
				node = NULL;
		}
	}

	return located;
}

void print_table(int lvl, symbol_table table) {
	if ((verbosity >= lvl) && table)
		print_node(root(table));
}

void print_node(symbol *node) {
	if (node) {
		if (node->l)
			print_node(node->l);

		printf("%s:\t0x%02lx\n", node->name, node->value);

		if (node->r)
			print_node(node->r);
	}
}

symbol_table new_table() {
	symbol_table table = (symbol_table) malloc(sizeof (&table));

	root(table) = NULL;
	table->case_sensitive = 0;

	return table;
}

symbol_table init_table(symbol_init symbols[]) {
	symbol_table table = new_table();
	int idx;

	for (idx = 0; symbols[idx].name; idx++) {
		set_symbol(table, symbols[idx].name, symbols[idx].value);
	}

	return table;
}
