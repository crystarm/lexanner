%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *msg);
int lexer_error_count(void);

typedef struct node {
    char *label;
    struct node **children;
    size_t child_count;
} node_t;

static node_t *root = NULL;
static int syntax_error_count = 0;

static char **derivation_steps = NULL;
static size_t derivation_count = 0;
static size_t derivation_cap = 0;

static char *dup_text(const char *s) {
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

static node_t *make_node_owned(char *label, size_t child_count, node_t **children) {
    node_t *n = (node_t *)malloc(sizeof(node_t));
    size_t i = 0;

    if (n == NULL) {
        free(label);
        return NULL;
    }

    n->label = label;
    n->child_count = child_count;
    n->children = NULL;

    if (child_count > 0) {
        n->children = (node_t **)malloc(sizeof(node_t *) * child_count);
        if (n->children == NULL) {
            free(n->label);
            free(n);
            return NULL;
        }

        for (i = 0; i < child_count; i += 1) {
            n->children[i] = children[i];
        }
    }

    return n;
}

static node_t *make_node(const char *label, size_t child_count, node_t **children) {
    return make_node_owned(dup_text(label), child_count, children);
}

static void free_tree(node_t *n) {
    size_t i = 0;

    if (n == NULL) {
        return;
    }

    for (i = 0; i < n->child_count; i += 1) {
        free_tree(n->children[i]);
    }

    free(n->children);
    free(n->label);
    free(n);
}

static void print_tree(const node_t *n, int depth) {
    int i = 0;
    size_t j = 0;

    if (n == NULL) {
        return;
    }

    for (i = 0; i < depth; i += 1) {
        printf("  ");
    }

    printf("%s\n", n->label);

    for (j = 0; j < n->child_count; j += 1) {
        print_tree(n->children[j], depth + 1);
    }
}

static void add_derivation_step(const char *step) {
    char **new_buf = NULL;
    size_t new_cap = 0;

    if (derivation_count == derivation_cap) {
        new_cap = (derivation_cap == 0) ? 32 : (derivation_cap * 2);
        new_buf = (char **)realloc(derivation_steps, new_cap * sizeof(char *));
        if (new_buf == NULL) {
            return;
        }
        derivation_steps = new_buf;
        derivation_cap = new_cap;
    }

    derivation_steps[derivation_count] = dup_text(step);
    if (derivation_steps[derivation_count] == NULL) {
        return;
    }
    derivation_count += 1;
}

static void print_derivation(void) {
    size_t i = 0;

    if (derivation_count == 0) {
        return;
    }

    printf("\nDerivation chain (reductions):\n");
    for (i = 0; i < derivation_count; i += 1) {
        printf("%zu) %s\n", i + 1, derivation_steps[i]);
    }
}

static void free_derivation(void) {
    size_t i = 0;

    for (i = 0; i < derivation_count; i += 1) {
        free(derivation_steps[i]);
    }

    free(derivation_steps);
    derivation_steps = NULL;
    derivation_count = 0;
    derivation_cap = 0;
}
%}

%define parse.error verbose

%code requires {
    typedef struct node node_t;
}

%union {
    char *text;
    node_t *node;
}

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
%token <text> BOOL_LITERAL
%token <text> IDENTIFIER
%token <text> INT_LITERAL
%token <text> FLOAT_LITERAL
%token <text> STRING_LITERAL
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

%type <node> program sentence stmt expr term factor

%destructor { free($$); } <text>

%left PLUS MINUS
%left MUL DIV MOD

%start program

%%

program:
    sentence {
        node_t *kids[1] = { $1 };
        root = make_node("Program", 1, kids);
        $$ = root;
        add_derivation_step("program -> sentence");
    }
;

sentence:
    stmt {
        node_t *kids[1] = { $1 };
        $$ = make_node("Sentence", 1, kids);
        add_derivation_step("sentence -> stmt");
    }
;

stmt:
    KW_VAR IDENTIFIER ASSIGN expr SEMICOLON {
        node_t *id_leaf = NULL;
        node_t *kids[2];

        char *id_label = (char *)malloc(strlen("id: ") + strlen($2) + 1);
        if (id_label != NULL) {
            sprintf(id_label, "id: %s", $2);
        }
        id_leaf = make_node_owned(id_label, 0, NULL);
        free($2);

        kids[0] = id_leaf;
        kids[1] = $4;
        $$ = make_node("Stmt(var id = expr ;)", 2, kids);
        add_derivation_step("stmt -> var IDENTIFIER = expr ;");
    }
  | IDENTIFIER ASSIGN expr SEMICOLON {
        node_t *id_leaf = NULL;
        node_t *kids[2];

        char *id_label = (char *)malloc(strlen("id: ") + strlen($1) + 1);
        if (id_label != NULL) {
            sprintf(id_label, "id: %s", $1);
        }
        id_leaf = make_node_owned(id_label, 0, NULL);
        free($1);

        kids[0] = id_leaf;
        kids[1] = $3;
        $$ = make_node("Stmt(id = expr ;)", 2, kids);
        add_derivation_step("stmt -> IDENTIFIER = expr ;");
    }
  | KW_PRINT LPAREN expr RPAREN SEMICOLON {
        node_t *kids[1] = { $3 };
        $$ = make_node("Stmt(print(expr);)", 1, kids);
        add_derivation_step("stmt -> print ( expr ) ;");
    }
;

expr:
    expr PLUS term {
        node_t *kids[2] = { $1, $3 };
        $$ = make_node("Expr(+)", 2, kids);
        add_derivation_step("expr -> expr + term");
    }
  | expr MINUS term {
        node_t *kids[2] = { $1, $3 };
        $$ = make_node("Expr(-)", 2, kids);
        add_derivation_step("expr -> expr - term");
    }
  | term {
        node_t *kids[1] = { $1 };
        $$ = make_node("Expr", 1, kids);
        add_derivation_step("expr -> term");
    }
;

term:
    term MUL factor {
        node_t *kids[2] = { $1, $3 };
        $$ = make_node("Term(*)", 2, kids);
        add_derivation_step("term -> term * factor");
    }
  | term DIV factor {
        node_t *kids[2] = { $1, $3 };
        $$ = make_node("Term(/)", 2, kids);
        add_derivation_step("term -> term / factor");
    }
  | term MOD factor {
        node_t *kids[2] = { $1, $3 };
        $$ = make_node("Term(%)", 2, kids);
        add_derivation_step("term -> term % factor");
    }
  | factor {
        node_t *kids[1] = { $1 };
        $$ = make_node("Term", 1, kids);
        add_derivation_step("term -> factor");
    }
;

factor:
    LPAREN expr RPAREN {
        node_t *kids[1] = { $2 };
        $$ = make_node("Factor((expr))", 1, kids);
        add_derivation_step("factor -> ( expr )");
    }
  | IDENTIFIER {
        char *label = (char *)malloc(strlen("id: ") + strlen($1) + 1);
        if (label != NULL) {
            sprintf(label, "id: %s", $1);
        }
        $$ = make_node_owned(label, 0, NULL);
        free($1);
        add_derivation_step("factor -> IDENTIFIER");
    }
  | INT_LITERAL {
        char *label = (char *)malloc(strlen("int: ") + strlen($1) + 1);
        if (label != NULL) {
            sprintf(label, "int: %s", $1);
        }
        $$ = make_node_owned(label, 0, NULL);
        free($1);
        add_derivation_step("factor -> INT_LITERAL");
    }
  | FLOAT_LITERAL {
        char *label = (char *)malloc(strlen("float: ") + strlen($1) + 1);
        if (label != NULL) {
            sprintf(label, "float: %s", $1);
        }
        $$ = make_node_owned(label, 0, NULL);
        free($1);
        add_derivation_step("factor -> FLOAT_LITERAL");
    }
  | STRING_LITERAL {
        char *label = (char *)malloc(strlen("string: ") + strlen($1) + 1);
        if (label != NULL) {
            sprintf(label, "string: %s", $1);
        }
        $$ = make_node_owned(label, 0, NULL);
        free($1);
        add_derivation_step("factor -> STRING_LITERAL");
    }
  | BOOL_LITERAL {
        char *label = (char *)malloc(strlen("bool: ") + strlen($1) + 1);
        if (label != NULL) {
            sprintf(label, "bool: %s", $1);
        }
        $$ = make_node_owned(label, 0, NULL);
        free($1);
        add_derivation_step("factor -> BOOL_LITERAL");
    }
;

%%

void yyerror(const char *msg) {
    syntax_error_count += 1;
    fprintf(stderr, "syntax_error: %s\n", msg);
}

int main(int argc, char **argv) {
    int parse_result = 0;
    int lex_errors = 0;

    (void)argc;
    (void)argv;

    parse_result = yyparse();
    lex_errors = lexer_error_count();

    if (parse_result == 0 && syntax_error_count == 0 && lex_errors == 0 && root != NULL) {
        print_derivation();
        printf("\nParse tree:\n");
        print_tree(root, 0);
    } else {
        fprintf(stderr, "analysis_failed: lexical_errors=%d, syntax_errors=%d\n", lex_errors, syntax_error_count);
    }

    free_tree(root);
    root = NULL;
    free_derivation();

    return (parse_result == 0 && syntax_error_count == 0 && lex_errors == 0) ? 0 : 1;
}
