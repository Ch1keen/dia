CC=gcc
MAKE=make

compiler:
	bison -d dia.y
	flex dia.l
	$(CC) -o diac main.c dia.tab.c lex.yy.c -lfl
	$(MAKE) clean_sources

lexer:
	flex dia.l
	$(CC) lex.yy.c -o dia_lexer -lfl

clean_sources:
	rm lex.yy.c dia.tab.c dia.tab.h

clean: clean_sources
	rm dia_lexer diac
