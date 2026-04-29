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

typedef struct {
    int number;
    int line;
    char *lexeme;
    char *type_name;
    char *value;
} token_row_t;

static token_row_t *table_rows = NULL;
static size_t table_rows_count = 0;
static size_t table_rows_cap = 0;

static int comment_start_line = 1;
static int comment_start_col = 1;

static int string_start_line = 1;
static int string_start_col = 1;

static int lex_error_count = 0;

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

static char *dup_plain(const char *s) {
    size_t len = 0;
    char *out = NULL;

    if (s == NULL) {
        s = "";
    }

    len = strlen(s);
    out = (char *)malloc(len + 1);
    if (out == NULL) {
        return NULL;
    }

    memcpy(out, s, len + 1);
    return out;
}

static char hex_digit(unsigned int v) {
    if (v < 10U) {
        return (char)('0' + v);
    }
    return (char)('A' + (v - 10U));
}

static char *dup_escaped(const char *s) {
    size_t in_len = 0;
    size_t cap = 0;
    size_t i = 0;
    size_t j = 0;
    char *out = NULL;

    if (s == NULL) {
        s = "";
    }

    in_len = strlen(s);
    cap = in_len * 4 + 1;
    out = (char *)malloc(cap);
    if (out == NULL) {
        return NULL;
    }

    while (i < in_len) {
        unsigned char c = (unsigned char)s[i];

        if (c == '\n') {
            out[j++] = '\\';
            out[j++] = 'n';
        } else if (c == '\t') {
            out[j++] = '\\';
            out[j++] = 't';
        } else if (c == '\r') {
            out[j++] = '\\';
            out[j++] = 'r';
        } else if (c == '\\') {
            out[j++] = '\\';
            out[j++] = '\\';
        } else if (c == '"') {
            out[j++] = '\\';
            out[j++] = '"';
        } else if (c < 32 || c == 127) {
            out[j++] = '\\';
            out[j++] = 'x';
            out[j++] = hex_digit((unsigned int)((c >> 4) & 0x0F));
            out[j++] = hex_digit((unsigned int)(c & 0x0F));
        } else {
            out[j++] = (char)c;
        }

        i += 1;
    }

    out[j] = '\0';
    return out;
}

static int push_token_row(token_row_t row) {
    token_row_t *new_rows = NULL;
    size_t new_cap = 0;

    if (table_rows_count == table_rows_cap) {
        new_cap = (table_rows_cap == 0) ? 64 : (table_rows_cap * 2);
        new_rows = (token_row_t *)realloc(table_rows, new_cap * sizeof(token_row_t));
        if (new_rows == NULL) {
            return 0;
        }
        table_rows = new_rows;
        table_rows_cap = new_cap;
    }

    table_rows[table_rows_count] = row;
    table_rows_count += 1;
    return 1;
}

static void flush_token_table(void) {
    size_t i = 0;
    size_t w_number = strlen("number");
    size_t w_line = strlen("line");
    size_t w_lexeme = strlen("lexeme");
    size_t w_type = strlen("type");
    size_t w_value = strlen("value");

    if (table_rows_count == 0) {
        return;
    }

    for (i = 0; i < table_rows_count; i += 1) {
        char number_buf[32];
        char line_buf[32];
        int number_len = snprintf(number_buf, sizeof(number_buf), "%d", table_rows[i].number);
        int line_len = snprintf(line_buf, sizeof(line_buf), "%d", table_rows[i].line);
        size_t lexeme_len = strlen(table_rows[i].lexeme);
        size_t type_len = strlen(table_rows[i].type_name);
        size_t value_len = strlen(table_rows[i].value);

        if (number_len > 0 && (size_t)number_len > w_number) {
            w_number = (size_t)number_len;
        }
        if (line_len > 0 && (size_t)line_len > w_line) {
            w_line = (size_t)line_len;
        }
        if (lexeme_len > w_lexeme) {
            w_lexeme = lexeme_len;
        }
        if (type_len > w_type) {
            w_type = type_len;
        }
        if (value_len > w_value) {
            w_value = value_len;
        }
    }

    printf("%-*s | %-*s | %-*s | %-*s | %-*s\n",
           (int)w_number, "number",
           (int)w_line, "line",
           (int)w_lexeme, "lexeme",
           (int)w_type, "type",
           (int)w_value, "value");

    for (i = 0; i < table_rows_count; i += 1) {
        char number_buf[32];
        char line_buf[32];

        snprintf(number_buf, sizeof(number_buf), "%d", table_rows[i].number);
        snprintf(line_buf, sizeof(line_buf), "%d", table_rows[i].line);

        printf("%-*s | %-*s | %-*s | %-*s | %-*s\n",
               (int)w_number, number_buf,
               (int)w_line, line_buf,
               (int)w_lexeme, table_rows[i].lexeme,
               (int)w_type, table_rows[i].type_name,
               (int)w_value, table_rows[i].value);

        free(table_rows[i].lexeme);
        free(table_rows[i].type_name);
        free(table_rows[i].value);
    }

    free(table_rows);
    table_rows = NULL;
    table_rows_count = 0;
    table_rows_cap = 0;
}

static void emit_token_row(const char *lexeme, const char *type_name, const char *value) {
    token_row_t row;
    char *lexeme_esc = NULL;
    char *type_copy = NULL;
    char *value_esc = NULL;

    token_index += 1;

    lexeme_esc = dup_escaped(lexeme);
    type_copy = dup_plain(type_name);
    value_esc = dup_escaped(value);

    if (lexeme_esc == NULL || type_copy == NULL || value_esc == NULL) {
        free(lexeme_esc);
        free(type_copy);
        free(value_esc);
        return;
    }

    row.number = token_index;
    row.line = token_line;
    row.lexeme = lexeme_esc;
    row.type_name = type_copy;
    row.value = value_esc;

    if (!push_token_row(row)) {
        free(lexeme_esc);
        free(type_copy);
        free(value_esc);
    }
}

static void emit_lex_error_at(int line, int col, const char *message, const char *fragment) {
    lex_error_count += 1;
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

int lexer_error_count(void) {
    return lex_error_count;
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
    flush_token_table();
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
    yylval.text = dup_plain(string_value);
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
    flush_token_table();
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
    yylval.text = dup_plain("true");
    return BOOL_LITERAL;
}

"false" {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "BOOL_LITERAL", "false");
    yylval.text = dup_plain("false");
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
    yylval.text = dup_plain(yytext);
    return FLOAT_LITERAL;
}

{int_lit} {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    emit_token_row(yytext, "INT_LITERAL", yytext);
    yylval.text = dup_plain(yytext);
    return INT_LITERAL;
}

{identifier} {
    mark_token_start();
    advance_position_text(yytext, yyleng);
    if ((int)strlen(yytext) > 32) {
        emit_lex_error_here("identifier is longer than 32 characters", yytext);
    }
    emit_token_row(yytext, "IDENTIFIER", yytext);
    yylval.text = dup_plain(yytext);
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
    flush_token_table();
    return 0;
}
%%
