%option noyywrap nounput noinput

%x cmt
%x str

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "parser.tab.h"

static int current_line = 1;
static int current_col = 1;
static int token_index = 0;
static int token_line = 1;
static int token_col = 1;
static int table_header_printed = 0;

static int comment_start_line = 1;
static int comment_start_col = 1;

static int string_start_line = 1;
static int string_start_col = 1;

static char string_lexeme[8192];
static char string_value[8192];
static int string_lexeme_len = 0;
static int string_value_len = 0;

static void mark_token_start(void) {
    token_line = current_line;
    token_col = current_col;
}

static void advance_position_text(const char *text, int len) {
    int i = 0;
    while (i < len) {
        if (text[i] == '\n') {
            current_line += 1;
            current_col = 1;
        } else {
            current_col += 1;
        }
        i += 1;
    }
}

static void print_escaped(FILE *out, const char *s) {
    size_t i = 0;
    while (s[i] != '\0') {
        unsigned char c = (unsigned char)s[i];
        if (c == '\n') {
            fputs("\\n", out);
        } else if (c == '\t') {
            fputs("\\t", out);
        } else if (c == '\r') {
            fputs("\\r", out);
        } else if (c == '\\') {
            fputs("\\\\", out);
        } else if (c == '"') {
            fputs("\\\"", out);
        } else if (c < 32 || c == 127) {
            fprintf(out, "\\x%02X", c);
        } else {
            fputc((int)c, out);
        }
        i += 1;
    }
}

static void ensure_table_header(void) {
    if (!table_header_printed) {
        printf("number | line | lexeme | type | value\n");
        table_header_printed = 1;
    }
}

static void emit_token_row(const char *lexeme, const char *type_name, const char *value) {
    ensure_table_header();
    token_index += 1;
    printf("%d | %d | ", token_index, token_line);
    print_escaped(stdout, lexeme);
    printf(" | %s | ", type_name);
    if (value != NULL) {
        print_escaped(stdout, value);
    }
    printf("\n");
}

static void emit_lex_error_at(int line, int col, const char *message, const char *fragment) {
    fprintf(stderr, "lexical_error %d:%d: %s", line, col, message);
    if (fragment != NULL && fragment[0] != '\0') {
        fprintf(stderr, " [");
        print_escaped(stderr, fragment);
        fprintf(stderr, "]");
    }
    fprintf(stderr, "\n");
}

static void emit_lex_error_here(const char *message, const char *fragment) {
    emit_lex_error_at(token_line, token_col, message, fragment);
}

static void string_reset(void) {
    string_lexeme_len = 0;
    string_value_len = 0;
    string_lexeme[0] = '\0';
    string_value[0] = '\0';
}

static void append_buf(char *buf, int *len, int cap, const char *src, int src_len) {
    int i = 0;
    while (i < src_len && (*len) < cap - 1) {
        buf[*len] = src[i];
        *len += 1;
        i += 1;
    }
    buf[*len] = '\0';
}

static void append_char(char *buf, int *len, int cap, char ch) {
    if (*len < cap - 1) {
        buf[*len] = ch;
        *len += 1;
        buf[*len] = '\0';
    }
}
%}

id_start [A-Za-z_]
id_char [A-Za-z0-9_]
identifier {id_start}{id_char}*
int_lit [0-9]+
float_lit [0-9]+"."[0-9]+

%%
[ \t\r]+ {
    advance_position_text(yytext, yyleng);
}

\n {
    advance_position_text(yytext, yyleng);
}

"#"[^\n]* {
    advance_position_text(yytext, yyleng);
}

"//"[^\n]* {
    advance_position_text(yytext, yyleng);
}

"/*" {
    mark_token_start();
    comment_start_line = token_line;
    comment_start_col = token_col;
    advance_position_text(yytext, yyleng);
    BEGIN(cmt);
}

<cmt>"*/" {
    advance_position_text(yytext, yyleng);
    BEGIN(INITIAL);
}

<cmt>\n {
    advance_position_text(yytext, yyleng);
}

<cmt>. {
    advance_position_text(yytext, yyleng);
}

<cmt><<EOF>> {
    emit_lex_error_at(comment_start_line, comment_start_col, "unclosed multiline comment", "/*");
    return 0;
}

\" {
    mark_token_start();
    string_start_line = token_line;
    string_start_col = token_col;
    string_reset();
    append_buf(string_lexeme, &string_lexeme_len, (int)sizeof(string_lexeme), yytext, yyleng);
    advance_position_text(yytext, yyleng);
    BEGIN(str);
}

<str>[^\\\"\n]+ {
    append_buf(string_lexeme, &string_lexeme_len, (int)sizeof(string_lexeme), yytext, yyleng);
    append_buf(string_value, &string_value_len, (int)sizeof(string_value), yytext, yyleng);
    advance_position_text(yytext, yyleng);
}

<str>\\[nt\\\"] {
    append_buf(string_lexeme, &string_lexeme_len, (int)sizeof(string_lexeme), yytext, yyleng);
    if (yytext[1] == 'n') {
        append_char(string_value, &string_value_len, (int)sizeof(string_value), '\n');
    } else if (yytext[1] == 't') {
        append_char(string_value, &string_value_len, (int)sizeof(string_value), '\t');
    } else if (yytext[1] == '\\') {
        append_char(string_value, &string_value_len, (int)sizeof(string_value), '\\');
    } else if (yytext[1] == '"') {
        append_char(string_value, &string_value_len, (int)sizeof(string_value), '"');
    }
    advance_position_text(yytext, yyleng);
}

<str>\\. {
    append_buf(string_lexeme, &string_lexeme_len, (int)sizeof(string_lexeme), yytext, yyleng);
    advance_position_text(yytext, yyleng);
    emit_lex_error_at(current_line, current_col - yyleng, "invalid escape sequence in string", yytext);
    append_char(string_value, &string_value_len, (int)sizeof(string_value), yytext[1]);
}

<str>\" {
    append_buf(string_lexeme, &string_lexeme_len, (int)sizeof(string_lexeme), yytext, yyleng);
    advance_position_text(yytext, yyleng);
    if (string_value_len > 32) {
        emit_lex_error_at(string_start_line, string_start_col, "string literal is longer than 32 characters", string_lexeme);
    }
    token_line = string_start_line;
    token_col = string_start_col;
    emit_token_row(string_lexeme, "STRING_LITERAL", string_value);
    BEGIN(INITIAL);
    return STRING_LITERAL;
}

<str>\n {
    emit_lex_error_at(string_start_line, string_start_col, "unclosed string literal", string_lexeme);
    advance_position_text(yytext, yyleng);
    BEGIN(INITIAL);
}

<str><<EOF>> {
    emit_lex_error_at(string_start_line, string_start_col, "unclosed string literal", string_lexeme);
    return 0;
}

"begin" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_BEGIN", yytext);
    return KW_BEGIN;
}

"end" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_END", yytext);
    return KW_END;
}

"if" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_IF", yytext);
    return KW_IF;
}

"else" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_ELSE", yytext);
    return KW_ELSE;
}

"while" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_WHILE", yytext);
    return KW_WHILE;
}

"for" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_FOR", yytext);
    return KW_FOR;
}

"do" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_DO", yytext);
    return KW_DO;
}

"print" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_PRINT", yytext);
    return KW_PRINT;
}

"read" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_READ", yytext);
    return KW_READ;
}

"int" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_INT", yytext);
    return KW_INT;
}

"float" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_FLOAT", yytext);
    return KW_FLOAT;
}

"string" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_STRING", yytext);
    return KW_STRING;
}

"bool" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_BOOL", yytext);
    return KW_BOOL;
}

"return" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_RETURN", yytext);
    return KW_RETURN;
}

"var" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_VAR", yytext);
    return KW_VAR;
}

"then" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_THEN", yytext);
    return KW_THEN;
}

"step" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_STEP", yytext);
    return KW_STEP;
}

"to" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "KW_TO", yytext);
    return KW_TO;
}

"true" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "BOOL_LITERAL", "true");
    return BOOL_LITERAL;
}

"false" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "BOOL_LITERAL", "false");
    return BOOL_LITERAL;
}

"and" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LAND", yytext);
    return LAND;
}

"or" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LOR", yytext);
    return LOR;
}

"not" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LNOT", yytext);
    return LNOT;
}

[0-9]+".."[0-9]+ {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_lex_error_here("invalid float literal", yytext);
}

"."[0-9]+ {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_lex_error_here("invalid float literal", yytext);
}

[0-9]+"." {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_lex_error_here("invalid float literal", yytext);
}

{float_lit} {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "FLOAT_LITERAL", yytext);
    return FLOAT_LITERAL;
}

{int_lit} {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "INT_LITERAL", yytext);
    return INT_LITERAL;
}

{identifier} {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    if ((int)strlen(yytext) > 32) {
        emit_lex_error_here("identifier is longer than 32 characters", yytext);
    }
    emit_token_row(yytext, "IDENTIFIER", yytext);
    return IDENTIFIER;
}

":=" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "COLON_ASSIGN", yytext);
    return COLON_ASSIGN;
}

"==" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "EQ", yytext);
    return EQ;
}

"!=" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "NEQ", yytext);
    return NEQ;
}

"<=" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LE", yytext);
    return LE;
}

">=" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "GE", yytext);
    return GE;
}

"&&" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LAND", yytext);
    return LAND;
}

"||" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LOR", yytext);
    return LOR;
}

"=" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "ASSIGN", yytext);
    return ASSIGN;
}

"+" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "PLUS", yytext);
    return PLUS;
}

"-" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "MINUS", yytext);
    return MINUS;
}

"*" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "MUL", yytext);
    return MUL;
}

"/" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "DIV", yytext);
    return DIV;
}

"%" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "MOD", yytext);
    return MOD;
}

"<" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LT", yytext);
    return LT;
}

">" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "GT", yytext);
    return GT;
}

"!" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LNOT", yytext);
    return LNOT;
}

";" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "SEMICOLON", yytext);
    return SEMICOLON;
}

"," {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "COMMA", yytext);
    return COMMA;
}

":" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "COLON", yytext);
    return COLON;
}

"." {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "DOT", yytext);
    return DOT;
}

"(" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LPAREN", yytext);
    return LPAREN;
}

")" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "RPAREN", yytext);
    return RPAREN;
}

"{" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LBRACE", yytext);
    return LBRACE;
}

"}" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "RBRACE", yytext);
    return RBRACE;
}

"[" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "LBRACKET", yytext);
    return LBRACKET;
}

"]" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "RBRACKET", yytext);
    return RBRACKET;
}

. {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_lex_error_here("invalid symbol", yytext);
}

<<EOF>> {
    return 0;
}
%%
