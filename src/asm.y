%{
  #include <unistd.h>
  #include <stdio.h>
  #include <string.h>

  #include "asm.h"
  #include "symbol.h"
  #include "output.h"
  #include "qualifier.h"
  #include "arg.h"
  #include "instruction.h"
  #include "string.h"

  void *parsed_text = NULL;
%}

%start text

%token KEYWORD INSTRUCTION IDENTIFIER IDENTIFIER_UNDEF LABEL CONTROL_VAR ARRAY
%token DOT_SUFFIX FILE_MODE LOCATION_QUALIFIER LEX_ERR
%token ENDLINE
%token STRING INTEGER FLOAT
%token '#' '$' '@'
%token ':' ',' ';'
%token '[' ']' '{' '}' '(' ')'
%token '?'

/* operator precedences */

%left L_AND L_OR L_NOT
%left LT GT EQ EEQ LE GE NE
%left '+' '-'
%left '*' '/' '%' AND OR XOR SHL SHR
%nonassoc WNOT BNOT LOW HIGH UMINUS UPLUS STRLEN


%union { long Int; char *String; qualifier Qualifier; argument *Arg; instruction *Instr; }
%type <Int>		literal identifier label array control_var expression arg_expression arg_expression_not_label
%type <String>		keyword undef_identifier loc_qual string_expression str_xp_paren string
%type <Qualifier>	dot_qual
%type <Arg>		opt_args args argument constant_arg register_arg indir_reg_arg
%type <Arg>		opt_data_args data_args data_argument
%type <Arg>		array_index opt_subscr array_arg
%type <Arg>		control_var_arg file_mode file_io_arg extern_arg
%type <Instr>		instruction statement line text

%%

text:			/* empty */				{ parsed_text = $$ = NULL; }
			| text line				{ parsed_text = $$ = append_instruction($1, $2); };

line:			endline					{ $$ = NULL; }
			| statement endline			{ output_address += encoded_instruction_size($1); $$ = $1; }
			| assignment endline			{ $$ = NULL; }
			| label_decl line			{ $$ = $2; };

label_decl:		undef_identifier ':'			{ set_symbol(labels, $1, output_address); };

statement:		instruction				opt_args {
								  char *msg;
								  $1->args = $2;
								  $$ = $1;
								  msg = validate_instruction($$);
								  if (msg) {
								    yyerror (msg);
								    print_instruction($$);
								    return 1;
								  }
								}
			| keyword opt_data_args			{
								  char *msg;
								  $$ = make_meta_instruction($1, $2);
								  msg = validate_instruction($$);
								  if (msg) {
								    yyerror (msg);
								    print_instruction($$);
								    return 1;
								  }
								};

assignment:		undef_identifier EQ expression		{ set_symbol(identifiers, $1, $3); };

instruction:		INSTRUCTION				{ $$ = make_instruction(asm_token.s); };

opt_args:		/* empty */				{ $$ = NULL; }
			| args					{ $$ = $1; };

opt_data_args:		/* empty */				{ $$ = NULL; }
			| data_args				{ $$ = $1; };

args:			argument
			| args ',' argument			{ $$ = $1; arg_append($1, $3); };

data_args:		data_argument
			| data_args ',' data_argument		{ $$ = $1; arg_append($1, $3); };

argument:		constant_arg
			| register_arg
			| indir_reg_arg
			| array_arg
			| control_var_arg
			| file_io_arg
			| extern_arg;

data_argument:		expression							{ $$ = int_arg(mode_asm_constant, $1, (qualifier) {0}); }
			| arg_expression dot_qual		{
								  if ($2.acc_set) {
								    if ($2.enc_set) {
								      yyerror("cannot set both access *and* encoding in data argument");
								      return -1;
								    }
								    $2.enc_set = 1;
								    $2.encoding = ($2.access == byte_access) ? byte_encoding : long_encoding;
								  }
								  $$ = int_arg(mode_asm_constant, $1, $2);
								}
			| string_expression			{ $$ = int_arg(mode_string, (sym_val_t) $1, (qualifier) {0}); };

constant_arg:		'#' arg_expression dot_qual		{ $$ = int_arg(mode_constant, $2, $3); }
			| undef_identifier dot_qual		{ $$ = forward_ref_arg($1, $2); }
			| label					{ $$ = int_arg(mode_constant, $1, (qualifier) {0}); };

register_arg:		arg_expression_not_label dot_qual	{ $$ = int_arg(mode_register, $1, $2); }
			| expression				{ $$ = int_arg(mode_register, $1, (qualifier) {0}); };

indir_reg_arg:		'[' register_arg ']'			{ $$ = $2; $$->mode = mode_r_indirect; };

array_arg:		opt_at array opt_subscr			{
								  if ($3) {
								    int idx_const = ($3->mode == mode_constant);
								    int mode = (idx_const ? mode_array_c_ind : mode_array_r_ind);
								    $$ = $3;
								    $$->mode = mode;
								    // $$->type = type_array_elem;
								    $$->index = $$->value;
								    $$->value = $2;
								  } else {
								    $$ = array_arg($2, (qualifier) {0}); /* no way to give qualifier? */
								  }
								};

array_arg:		'@' arg_expression opt_subscr		{
								  if ($3) {
								    int idx_const = ($3->mode == mode_constant);
								    int mode = (idx_const ? mode_array_c_ind : mode_array_r_ind);
								    $$ = $3;
								    $$->mode = mode;
								    // $$->type = type_array_elem;
								    $$->index = $$->value;
								    $$->value = $2;
								  } else {
								    $$ = array_arg($2, (qualifier) {0}); /* no way to give qualifier? */
								  }
								};

opt_subscr:		/* nothing */				{ $$ = NULL; }
			| '[' array_index ']'			{ $$ = $2; };

control_var_arg:	opt_dollar_sign control_var		{ $$ = int_arg(mode_control, $2, (qualifier) {0}); }
			| '$' arg_expression			{ $$ = int_arg(mode_control, $2, (qualifier) {0}); };

file_io_arg:		file_mode;

extern_arg:		'{' loc_qual opt_pound arg_expression dot_qual '}'	{ $$ = int_arg(mode_for_location($2), $4, $5); if ($2) free ($2); }
			| '{' loc_qual '[' expression ']' dot_qual'}'		{ $$ = int_arg(indirect_mode_for_location($2), $4, $6); if ($2) free ($2); };

dot_qual:		DOT_SUFFIX				{ $$ = parse_qualifier(asm_token.s); }
			|					{ $$ = (qualifier) {0}; };

opt_at:			'@'
			| ;					/* or nothing */

opt_pound:		'#'
			| ;					/* or nothing */

array:			ARRAY					{ $$ = symbol_value(array_ids, asm_token.s); };

array_index:		constant_arg
			| register_arg ;

opt_dollar_sign:	'$'
			| ;					/* or nothing */

control_var:		CONTROL_VAR				{ $$ = symbol_value(control_vars, asm_token.s); };

file_mode:		FILE_MODE				{ $$ = file_arg(asm_token.s); };

loc_qual:		/* nothing - assume R: */		{ $$ = NULL; }
			| LOCATION_QUALIFIER			{ $$ = cpstring(asm_token.s); };

keyword:		KEYWORD					{ $$ = cpstring(asm_token.s); };

endline:		ENDLINE
			| ';' ;

identifier:		IDENTIFIER				{ $$ = symbol_value(identifiers, asm_token.s); };

undef_identifier:	IDENTIFIER_UNDEF			{ $$ = cpstring(asm_token.s); };

arg_expression:		arg_expression_not_label
			| label ;

arg_expression_not_label: literal
			| identifier
			| '(' expression ')'			{ $$ = $2; };

expression:		literal					{ $$ = $1; }
			| identifier				{ $$ = $1; }
			| '(' expression ')'			{ $$ = $2; }
			| expression '+' expression		{ $$ = $1 + $3; }
			| expression '-' expression		{ $$ = $1 - $3; }
			| expression '*' expression		{ $$ = $1 * $3; }
			| expression '/' expression		{ $$ = $1 / $3; }
			| expression '%' expression		{ $$ = $1 % $3; }
			| expression AND expression		{ $$ = $1 & $3; }
			| expression OR expression		{ $$ = $1 | $3; }
			| expression XOR expression		{ $$ = $1 ^ $3; }
			| expression SHL expression		{ $$ = $1 << $3; }
			| expression SHR expression		{ $$ = $1 >> $3; }
			| WNOT expression			{ $$ = $2 ^ 0xffff; }
			| BNOT expression			{ $$ = $2 ^ 0x00ff; }
			| LOW expression			{ $$ = $2 & 0x00ff; }
			| HIGH expression			{ $$ = ($2 & 0xff00) >> 8; }
			| '-' expression %prec UMINUS		{ $$ = (- $2); }
			| '+' expression %prec UPLUS		{ $$ = $2; }
			| expression L_AND expression		{ $$ = ($1 && $3); }
			| expression L_OR expression 		{ $$ = ($1 || $3); }
			| L_NOT expression			{ $$ = (! $2); }
			| expression LT expression		{ $$ = ($1 < $3); }
			| expression GT expression		{ $$ = ($1 > $3); }
			| expression EQ expression		{ $$ = ($1 == $3); }
			| expression EEQ expression		{ $$ = ($1 == $3); }
			| expression NE expression		{ $$ = ($1 != $3); }
			| expression LE expression		{ $$ = ($1 <= $3); }
			| expression GE expression		{ $$ = ($1 >= $3); }
			| expression '?' expression ':' expression { $$ = ($1) ? ($3) : ($5); 	}
			| STRLEN str_xp_paren			{ $$ = strlen($2); free($2); };

literal:		INTEGER					{ $$ = asm_token.i; };

str_xp_paren:		'(' string_expression ')'		{ $$ = $2; };

string_expression:	string
			| '(' string_expression ')'		{ $$ = $2; }
			| string_expression '.' string		{ $$ = catstring($1, $3); }
			| string_expression '.' expression	{ char *str = " "; str[0] = $3; $$ = catstring($1, cpstring(str)); };

string:			STRING					{ $$ = cpstring(asm_token.s); };

label:			LABEL					{ $$ = symbol_value(labels, asm_token.s); }
			| '?'					{ $$ = output_address; };

%%

void strip_newline(char *str) {
  while (*str) {
    if (*str == '\n')
      *str = 0;
    else
      str++;
  }
}

extern FILE *yyin;

int yyerror(char *msg) {
  char text_buf[40];

  fgets(text_buf, sizeof(text_buf), yyin);
  strip_newline(text_buf);

  eprintf("%s line %d: %s\n", asm_source_file, asm_linenum, msg);
  eprintf("  (somewhere before text: %s)\n", text_buf);

  return -1;
}
