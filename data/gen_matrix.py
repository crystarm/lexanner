import csv

TERMS = [
    "#",
    "KW_VAR",
    "KW_PRINT",
    "IDENTIFIER",
    "ASSIGN",
    "LPAREN",
    "RPAREN",
    "PLUS",
    "MINUS",
    "MUL",
    "DIV",
    "MOD",
    "INT_LITERAL",
    "FLOAT_LITERAL",
    "STRING_LITERAL",
    "BOOL_LITERAL",
    "SEMICOLON",
]

firstvt_factor = {
    "LPAREN",
    "IDENTIFIER",
    "INT_LITERAL",
    "FLOAT_LITERAL",
    "STRING_LITERAL",
    "BOOL_LITERAL",
}
lastvt_factor = {
    "RPAREN",
    "IDENTIFIER",
    "INT_LITERAL",
    "FLOAT_LITERAL",
    "STRING_LITERAL",
    "BOOL_LITERAL",
}

firstvt_term = set(firstvt_factor) | {"MUL", "DIV", "MOD"}
lastvt_term = set(lastvt_factor) | {"MUL", "DIV", "MOD"}

firstvt_expr = set(firstvt_term) | {"PLUS", "MINUS"}
lastvt_expr = set(lastvt_term) | {"PLUS", "MINUS"}

rels: dict[tuple[str, str], set[str]] = {}


def add(a: str, b: str, r: str) -> None:
    key = (a, b)
    if key not in rels:
        rels[key] = set()
    rels[key].add(r)


# stmt -> KW_VAR IDENTIFIER ASSIGN expr SEMICOLON
add("KW_VAR", "IDENTIFIER", "=")
add("IDENTIFIER", "ASSIGN", "=")
for t in firstvt_expr:
    add("ASSIGN", t, "<")
for t in lastvt_expr:
    add(t, "SEMICOLON", ">")

# stmt -> IDENTIFIER ASSIGN expr SEMICOLON
add("IDENTIFIER", "ASSIGN", "=")
for t in firstvt_expr:
    add("ASSIGN", t, "<")
for t in lastvt_expr:
    add(t, "SEMICOLON", ">")

# stmt -> KW_PRINT LPAREN expr RPAREN SEMICOLON
add("KW_PRINT", "LPAREN", "=")
for t in firstvt_expr:
    add("LPAREN", t, "<")
for t in lastvt_expr:
    add(t, "RPAREN", ">")
add("LPAREN", "RPAREN", "=")
add("RPAREN", "SEMICOLON", "=")

# expr -> expr PLUS term
for t in lastvt_expr:
    add(t, "PLUS", ">")
for t in firstvt_term:
    add("PLUS", t, "<")

# expr -> expr MINUS term
for t in lastvt_expr:
    add(t, "MINUS", ">")
for t in firstvt_term:
    add("MINUS", t, "<")

# term -> term MUL factor
for t in lastvt_term:
    add(t, "MUL", ">")
for t in firstvt_factor:
    add("MUL", t, "<")

# term -> term DIV factor
for t in lastvt_term:
    add(t, "DIV", ">")
for t in firstvt_factor:
    add("DIV", t, "<")

# term -> term MOD factor
for t in lastvt_term:
    add(t, "MOD", ">")
for t in firstvt_factor:
    add("MOD", t, "<")

# factor -> LPAREN expr RPAREN
for t in firstvt_expr:
    add("LPAREN", t, "<")
for t in lastvt_expr:
    add(t, "RPAREN", ">")
add("LPAREN", "RPAREN", "=")

# boundary
for t in {"KW_VAR", "KW_PRINT", "IDENTIFIER"}:
    add("#", t, "<")
add("SEMICOLON", "#", ">")
add("#", "#", "=")

with open("lexanner/data/matrix.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow([""] + TERMS)
    for r in TERMS:
        row = [r]
        for c in TERMS:
            mark = ""
            if (r, c) in rels:
                mark = "".join(sorted(rels[(r, c)]))
            row.append(mark)
        w.writerow(row)

print("written: lexanner/data/matrix.csv")
