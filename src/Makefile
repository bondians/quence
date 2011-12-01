CC=gcc
CFLAGS=-g
OFILES=main.o symbol.o output.o qualifier.o opcodes.o symbol_defs.o arg.o instruction.o string.o asm_lex.o asm_parse.o
SUDO=sudo

quence:		${OFILES} Makefile
	${CC} ${CFLAGS} -o quence ${OFILES}

depend:		asm_parse.c asm_lex.c
	makedepend -m *.c

install:	quence
	${SUDO} install -o 0 -g 0 -s quence /usr/local/bin/quence

install-1.0:	quence-1.0
	(cd quence-1.0; make install)

quence-1.0.tgz:	quence-1.0
	tar czf quence-1.0.tgz quence-1.0

clean:
	rm -f *.o
	rm -f asm_lex.c asm_parse.c asm_parse.h asm_parse.output
	rm -f q.out
	rm -f opcodes.c symbol_defs.c

clean-all:	clean
	rm -f quence
	makedepend


get-docs:
	scp 'archive:/archive/disk3/Projects/vTree/Seq*.{ASM,TXT}' .

quence-1.0:
	rm -Rf quence-1.0
	cvs export -r Release_1_0 -kv -d quence-1.0 Projects/vTree/quence

main.o:		main.c Makefile
	${CC} ${CFLAGS} -c main.c

symbol.o:	symbol.c Makefile
	${CC} ${CFLAGS} -c symbol.c

output.o:	output.c Makefile
	${CC} ${CFLAGS} -c output.c

qualifier.o:	qualifier.c Makefile
	${CC} ${CFLAGS} -c qualifier.c

opcodes.o:	opcodes.c Makefile
	${CC} ${CFLAGS} -c opcodes.c

symbol_defs.o:	symbol_defs.c Makefile
	${CC} ${CFLAGS} -c symbol_defs.c

arg.o:		arg.c Makefile
	${CC} ${CFLAGS} -c arg.c

instruction.o:	instruction.c Makefile
	${CC} ${CFLAGS} -c instruction.c

string.o:	string.c Makefile
	${CC} ${CFLAGS} -c string.c

asm_lex.o:	asm_lex.c asm.h symbol.h qualifier.h arg.h instruction.h asm_parse.h string.h Makefile
	${CC} ${CFLAGS} -c asm_lex.c

asm_parse.o:	asm_parse.c asm.h symbol.h output.h qualifier.h arg.h instruction.h string.h Makefile
	${CC} ${CFLAGS} -c asm_parse.c

asm_parse.c:	asm.y asm.h Makefile
	bison -o asm_parse.c -dv asm.y

asm_lex.c:	asm.l asm.h asm_parse.c Makefile
	flex -oasm_lex.c -i asm.l

opcodes.c:	SeqDefs SeqDefs.ASM SeqNotes.TXT
	./SeqDefs opcodes.c

symbol_defs.c:	SeqDefs SeqDefs.ASM SeqNotes.TXT
	./SeqDefs symbol_defs.c

# DO NOT DELETE
