#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#include "asm.h"
#include "symbol.h"
#include "opcodes.h"
#include "symbol_defs.h"
#include "instruction.h"
#include "output.h"
#include "string.h"

char *release_version = "1.01";

int one_input_file = 0;
int symbol_help_mode = 0;
char *output_file = "q.out";
char *preprocessor;

void version(int short_vers);
void usage(char *prog_name);

int main (int argc, char **argv) {
	char *prog_name = argv[0];
	int c;
	int failure = 0;

	/*
	 *  Init global symbol tables
	 */

	init_opcodes();
	init_symbols();

	identifiers = new_table();
	labels = new_table();
	labels->case_sensitive = 1;

	#if defined(__MINGW32_VERSION)
	preprocessor = "c:\\mingw\\bin\\cpp";
	#else
	preprocessor = "cpp";
	#endif

	/*
	 *  Parse Command-line opts (is getopt available for dos/win?)
	 */

	while ((c = getopt(argc, argv, "qvVo:e:su?hlHp:P")) != -1) {
		switch (c) {
			case 'o':
				one_input_file = 1;
				output_file = cpstring(optarg);
				break;
			case 'e':
				out_ext = cpstring(optarg);
				break;
			case 'H':
				symbol_help_mode = 1;
				break;
			case 'q':
				verbosity--;
				break;
			case 'v':
				verbosity++;
				break;
			case 's':
				safe_write = 1;
				break;
			case 'u':
				safe_write = 0;
				break;
			case 'l':
				labels->case_sensitive = 0;
				break;
			case 'p':
				preprocessor = cpstring(optarg);
				break;
			case 'P':
				preprocessor = NULL;
				break;
			case 'V':
				version(0);
				exit(0);
			case '?':
			default:
				usage(prog_name);
				break;
		}
	}

	argc -= optind;
	argv += optind;

	/*
	 *  Lookup symbol help
	 *    case 0: symbol_help_mode
	 */

	if (symbol_help_mode) {
		if (argc == 0) {
			eprintf("Opcodes available:\n");
			print_table(0, opcodes);
		}

		while (argc--) {
			char *symbol = (argv++)[0];
			symbol_table help_table = opcode_help();

			char *help = (char *) symbol_value(help_table, symbol);
			if (help == NULL)
				help = ": no entry";

			fprintf(stderr, "%s%s\n", symbol, help);
		}

		return 0;
	}

	/*
	 *  Parse the file
	 *    case 1: no cmdline files
	 */

	if (argc == 0) {
		return quence("", output_file);
	}

	/*
	 *    case 2: -o given
	 */

	if (one_input_file) {
		if (argc--)
			return quence((argv++)[0], output_file);

		if (argc) {
			eprintf("when using -o, only one source file may be given");
			exit(1);
		}
	}

	/*
	 *    case 3: bulk quence
	 */

	while (argc--) {
		char *in = (argv++)[0];
		failure |= quence(in, NULL);
	}

	return failure;
}

void version(int short_vers) {
	if (short_vers) {
		fprintf(stderr,"Quence v%s ($Id: main.c,v 1.13 2002/12/10 01:01:25 mokus Exp $)\n", release_version);
	} else {
		fprintf(stderr, "\n");
		fprintf(stderr,"Quence v%s\n", release_version);
		fprintf(stderr, "Release tag: $Name:  $\n");
		fprintf(stderr, "\n");
	}
}

void usage(char *prog_name) {
	fprintf(stderr, "\n");
	version(1);
	fprintf(stderr, "Usage: %s [options] [file] [file2] [...]\n", prog_name);
	fprintf(stderr, "\n");
	fprintf(stderr, "Options:\n");
	fprintf(stderr, "  -o outfile  Send compiled output to outfile\n");
	fprintf(stderr, "  -p pp       Use 'pp' as a preprocessor (default: %s)\n", preprocessor);
	fprintf(stderr, "  -e outext   Use outext as path extension for out files\n");
	fprintf(stderr, "  -H opcode   Get help on opcode - prints a blurb from SeqNotes.TXT\n");
	fprintf(stderr, "  -v          Increment verbosity level\n");
	fprintf(stderr, "  -q          Decrement verbosity level\n");
	fprintf(stderr, "  -P          Don't use any preprocessor\n");
	fprintf(stderr, "  -s          Safe write - don't write output if assembly fails\n");
	fprintf(stderr, "  -u          Unsafe write - write output even if assembly fails\n");
	fprintf(stderr, "  -l          Case insensitive labels (default is case-sensitive)\n");
	fprintf(stderr, "\n");

	exit(-1);
}

/*
 *	$Log: main.c,v $
 *	Revision 1.13  2002/12/10 01:01:25  mokus
 *	finally ready...
 *
 */
