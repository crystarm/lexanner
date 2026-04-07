/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_PARSER_TAB_H_INCLUDED
# define YY_YY_PARSER_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    KW_BEGIN = 258,                /* KW_BEGIN  */
    KW_END = 259,                  /* KW_END  */
    KW_IF = 260,                   /* KW_IF  */
    KW_ELSE = 261,                 /* KW_ELSE  */
    KW_WHILE = 262,                /* KW_WHILE  */
    KW_FOR = 263,                  /* KW_FOR  */
    KW_DO = 264,                   /* KW_DO  */
    KW_PRINT = 265,                /* KW_PRINT  */
    KW_READ = 266,                 /* KW_READ  */
    KW_INT = 267,                  /* KW_INT  */
    KW_FLOAT = 268,                /* KW_FLOAT  */
    KW_STRING = 269,               /* KW_STRING  */
    KW_BOOL = 270,                 /* KW_BOOL  */
    KW_RETURN = 271,               /* KW_RETURN  */
    KW_VAR = 272,                  /* KW_VAR  */
    KW_THEN = 273,                 /* KW_THEN  */
    KW_STEP = 274,                 /* KW_STEP  */
    KW_TO = 275,                   /* KW_TO  */
    BOOL_LITERAL = 276,            /* BOOL_LITERAL  */
    IDENTIFIER = 277,              /* IDENTIFIER  */
    INT_LITERAL = 278,             /* INT_LITERAL  */
    FLOAT_LITERAL = 279,           /* FLOAT_LITERAL  */
    STRING_LITERAL = 280,          /* STRING_LITERAL  */
    ASSIGN = 281,                  /* ASSIGN  */
    COLON_ASSIGN = 282,            /* COLON_ASSIGN  */
    PLUS = 283,                    /* PLUS  */
    MINUS = 284,                   /* MINUS  */
    MUL = 285,                     /* MUL  */
    DIV = 286,                     /* DIV  */
    MOD = 287,                     /* MOD  */
    EQ = 288,                      /* EQ  */
    NEQ = 289,                     /* NEQ  */
    LT = 290,                      /* LT  */
    GT = 291,                      /* GT  */
    LE = 292,                      /* LE  */
    GE = 293,                      /* GE  */
    LAND = 294,                    /* LAND  */
    LOR = 295,                     /* LOR  */
    LNOT = 296,                    /* LNOT  */
    SEMICOLON = 297,               /* SEMICOLON  */
    COMMA = 298,                   /* COMMA  */
    COLON = 299,                   /* COLON  */
    DOT = 300,                     /* DOT  */
    LPAREN = 301,                  /* LPAREN  */
    RPAREN = 302,                  /* RPAREN  */
    LBRACE = 303,                  /* LBRACE  */
    RBRACE = 304,                  /* RBRACE  */
    LBRACKET = 305,                /* LBRACKET  */
    RBRACKET = 306                 /* RBRACKET  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef int YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);


#endif /* !YY_YY_PARSER_TAB_H_INCLUDED  */
