cc = gcc
cflags = -std=c11 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L
ldflags = -lfl

binary = lexanner
parser_src = parser.y
lexer_src = scanner.l
parser_c = parser.tab.c
parser_h = parser.tab.h
lexer_c = scanner.yy.c

.PHONY: all clean rebuild run test

all: $(binary)

$(binary): $(parser_c) $(lexer_c)
	$(cc) $(cflags) -o $(binary) $(parser_c) $(lexer_c) $(ldflags)

$(parser_c) $(parser_h): $(parser_src)
	bison -d -o $(parser_c) $(parser_src)

$(lexer_c): $(lexer_src) $(parser_h)
	flex -o $(lexer_c) $(lexer_src)

run: $(binary)
	if [ -n "$(input)" ]; then ./$(binary) < "$(input)"; else ./$(binary); fi

test: $(binary)
	./$(binary) < tests/input_ok.txt
	./$(binary) < tests/input_bad.txt

clean:
	rm -f $(binary) $(parser_c) $(parser_h) $(lexer_c)

rebuild: clean all
