%{
	#include "asm.h"
	token_value asm_token;
	
	#include "string.h"
	#include "symbol.h"
	#include "qualifier.h"
	#include "arg.h"
	#include "instruction.h"
	
	#include "asm_parse.h"
	
	char *asm_source_file;
	char *asm_base_file;
	int asm_linenum;
	
%}

letter					[a-z]
digit					[0-9]
alnum					[a-z0-9]

space					[ \t]+
newline					[\r\n]+
anyspace				[ \t\r\n]+

identifier				{letter}[[:alnum:]_]+
label					{identifier}
control_var				{identifier}
array					{identifier}
keyword					{identifier}
instruction				{identifier}
dot_suffix				\.(([syml]?[bw])|([bw]?[syml]))
file_mode				~[bw](r|w|(rw))

hex_int					(($|0x)[0-9a-f]+)|([0-9a-f]+h)
oct_int					(\\[0-7]+)|([0-7]+o)
dec_int					{digit}+
bin_int					(%[01]+)|([01]+b)

int_literal				{hex_int}|{oct_int}|{dec_int}|{bin_int}

float_literal			(({digit}+(\.{digit}+)?)|(\.{digit}+))(e{digit}+)?

oct_char				(\\[01][0-7]?[0-7]?)

left_quote				\"|Ò
right_quote				\"|Ó
escaped					(\\.)|(\\\n)
string_literal			{left_quote}([^\\"Ó]|{oct_char}|{escaped}|{newline})*{right_quote}

char					[^\\']|{oct_char}|{escaped}
char_int				'{char}'
wchar_int				'{char}{char}'

asm_comment				;.*
osa_comment				--.*
c_startcom				\/\*
c_endcom				\*\/
c_comment				{c_startcom}(([^*]+)|(\*[^/])|{newline})+{c_endcom}
cpp_comment				\/\/.*
sh_comment				#.*
percent_bang_psadobe	^#!.*
comment					{c_comment}|{cpp_comment}|{osa_comment}

punctuation				[,:;+\-*/()\[\]?#$@]

left_curly				\{
right_curly				\}
location_qual			[REP]:

l_and					&&
l_or					\|\|
l_not					!

eq						=
eeq						==
ne						(!=)|(<>)
lt						<
gt						>
le						<=
ge						>=

and						"&"|AND
or						"|"|OR
xor						"^"|XOR

wnot					"~"|WNOT
bnot					BNOT

shl						"<<"|SHL
shr						">>"|SHR

low						LOW
high					HIGH

strlen					STRLEN

cpp_start				^#

%x cpp cpp_start
%%

{cpp_start}				{ BEGIN cpp; }

{newline}				{ asm_linenum++; return ENDLINE; }
{comment}				{ asm_linenum += count_endlines(yytext); }
{percent_bang_psadobe}	{ if (asm_linenum != 0) REJECT; }
{space}					/* Eat */

{l_and}					{ return L_AND; }
{l_or}					{ return L_OR; }
{l_not}					{ return L_NOT; }

{eeq}					{ return EEQ; }
{eq}					{ return EQ; }
{ne}					{ return NE; }
{lt}					{ return LT; }
{gt}					{ return GT; }
{le}					{ return LE; }
{ge}					{ return GE; }

{and}					{ return AND; }
{or}					{ return OR; }
{xor}					{ return XOR; }

{wnot}					{ return WNOT; }
{bnot}					{ return BNOT; }

{shl}					{ return SHL; }
{shr}					{ return SHR; }

{low}					{ return LOW; }
{high}					{ return HIGH; }

{strlen}				{ return STRLEN; }

{hex_int}				{ asm_token.i = atoi_hex(yytext); return INTEGER; }
{oct_int}				{ asm_token.i = atoi_oct(yytext); return INTEGER; }
{bin_int}				{ asm_token.i = atoi_bin(yytext); return INTEGER; }
{dec_int}				{ asm_token.i = atoi(yytext); return INTEGER; }
{char_int}				{ asm_token.i = atoi_char(yytext); return INTEGER; }
{wchar_int}				{ asm_token.i = atoi_wchar(yytext); return INTEGER; }

{string_literal}		{ asm_token.s = unquote(yytext); return STRING; }

{dot_suffix}			{ asm_token.s = yytext; return DOT_SUFFIX; }
{file_mode}				{ asm_token.s = yytext; return FILE_MODE; }
{location_qual}			{ asm_token.s = yytext; return LOCATION_QUALIFIER; }

{keyword}				%{
							if(symbol_exists(keywords, yytext)) {
								asm_token.s = yytext;
								return KEYWORD;
							} else {
								REJECT;
							}
						%}

{instruction}			%{
							if(symbol_exists(opcodes, yytext)) {
								asm_token.s = yytext;
								return INSTRUCTION;
							} else {
								REJECT;
							}
						%}

{label}					%{	
							if(symbol_exists(labels, yytext)) {
								asm_token.s = yytext;
								return LABEL;
							} else {
								REJECT;
							}
						%}

{control_var}			%{
							if(symbol_exists(control_vars, yytext)) {
								asm_token.s = yytext;
								return CONTROL_VAR;
							} else {
								REJECT;
							}
						%}

{array}					%{
							if(symbol_exists(array_ids, yytext)) {
								asm_token.s = yytext;
								return ARRAY;
							} else {
								REJECT;
							}
						%}

{identifier}			%{
							if(symbol_exists(identifiers, yytext)) {
								asm_token.s = yytext;
								return IDENTIFIER;
							} else {
								REJECT;
							}
						%}

{identifier}			{ asm_token.s = yytext; return IDENTIFIER_UNDEF; }


{punctuation}			{ asm_token.c = yytext[0]; return yytext[0]; }

{left_curly}			{ return '{'; }
{right_curly}			{ return '}'; }

.						{ yyerror("Garbage in the input stream"); return LEX_ERR; }

<cpp,cpp_start>{space}	/* eat */
<cpp_start>{dec_int}	{ asm_linenum = atoi(yytext); BEGIN cpp; d_printf(1, "#line directive: %d\n", asm_linenum); }
<cpp>{string_literal}	%{
							free(asm_source_file);
							asm_source_file = unquote(yytext);
							
							if (asm_source_file[0])
								asm_source_file = cpstring(asm_source_file);
							else
								asm_source_file = cpstring(asm_base_file);
							
							d_printf(1, "#line directive: %s\n", asm_source_file);
						%}
<cpp>{dec_int}			/* Eat - what's it mean? */
<cpp>{newline}			{ BEGIN INITIAL; }
<cpp>.					{ yyerror("Preprocessor garbage in the input stream"); return LEX_ERR; }

%%

int yywrap() {
	return 1;
}
