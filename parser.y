%{
#include <stdio.h>
#include <stdlib.h>

int yylex(void);
void yyerror(const char *msg);
%}

%define parse.error verbose

%token KW_BEGIN
%token KW_END
%token KW_IF
%token KW_ELSE
%token KW_WHILE
%token KW_FOR
%token KW_DO
%token KW_PRINT
%token KW_READ
%token KW_INT
%token KW_FLOAT
%token KW_STRING
%token KW_BOOL
%token KW_RETURN
%token KW_VAR
%token KW_THEN
%token KW_STEP
%token KW_TO
%token BOOL_LITERAL
%token IDENTIFIER
%token INT_LITERAL
%token FLOAT_LITERAL
%token STRING_LITERAL
%token ASSIGN
%token COLON_ASSIGN
%token PLUS
%token MINUS
%token MUL
%token DIV
%token MOD
%token EQ
%token NEQ
%token LT
%token GT
%token LE
%token GE
%token LAND
%token LOR
%token LNOT
%token SEMICOLON
%token COMMA
%token COLON
%token DOT
%token LPAREN
%token RPAREN
%token LBRACE
%token RBRACE
%token LBRACKET
%token RBRACKET

%start program

%%

program:
    token_list
;

token_list:
    %empty
  | token_list token_item
;

token_item:
    KW_BEGIN
  | KW_END
  | KW_IF
  | KW_ELSE
  | KW_WHILE
  | KW_FOR
  | KW_DO
  | KW_PRINT
  | KW_READ
  | KW_INT
  | KW_FLOAT
  | KW_STRING
  | KW_BOOL
  | KW_RETURN
  | KW_VAR
  | KW_THEN
  | KW_STEP
  | KW_TO
  | BOOL_LITERAL
  | IDENTIFIER
  | INT_LITERAL
  | FLOAT_LITERAL
  | STRING_LITERAL
  | ASSIGN
  | COLON_ASSIGN
  | PLUS
  | MINUS
  | MUL
  | DIV
  | MOD
  | EQ
  | NEQ
  | LT
  | GT
  | LE
  | GE
  | LAND
  | LOR
  | LNOT
  | SEMICOLON
  | COMMA
  | COLON
  | DOT
  | LPAREN
  | RPAREN
  | LBRACE
  | RBRACE
  | LBRACKET
  | RBRACKET
;

%%

void yyerror(const char *msg) {
    fprintf(stderr, "parse_error: %s\n", msg);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return yyparse();
}
