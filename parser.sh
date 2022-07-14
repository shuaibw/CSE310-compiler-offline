#!/bin/bash

./cleaner.sh
bison --color -Wconflicts-sr -v --debug --defines=y.tab.h -Wconflicts-sr parser.y
echo 'Generated the parser C file as well the header file'
g++ -w -c -o y.o parser.tab.c
echo 'Generated the parser object file'
flex lex.l
echo 'Generated the scanner C file'
g++ -w -c -o l.o lex.yy.c
# if the above command doesn't work try g++ -fpermissive -w -c -o l.o lex.yy.c
echo 'Generated the scanner object file'
g++ y.o l.o -lfl -o scanner
echo 'All ready, running'
./scanner input.c