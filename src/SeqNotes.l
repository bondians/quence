%{	
/*
 *  <SeqNotes.l>
 */
%}

opcode		[[:alpha:]][[:alnum:]]+
endline		[\n\r]

%x opc desc
%%

^\*		{ BEGIN opc; }
.		{ ; }
{endline}	{ ; }

<opc>{opcode}	{ printf("\t{\"%s\", (unsigned) \"", yytext); BEGIN desc; }

<desc>\"	{ printf("%s", "\\\""); }
<desc>.		{ printf("%s", yytext); }
<desc>{endline} { printf("\"},\n"); BEGIN INITIAL; }
%%

int yywrap() {
	return 1;
}
