#ifndef __opcodes_h__
#define __opcodes_h__

extern char *instructions[];

#include "symbol.h"

void init_opcodes();
symbol_table opcode_help();

#endif /* __opcodes_h__ */
