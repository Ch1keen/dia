#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "dia.tab.h"
#include "dia_node.h"
#include "dia_vector.h"

#undef DIA_DEBUG
#define DIA_DEBUG(...) (DIA_VERBOSE_LEVEL < 1 ? : fprintf(stderr, "[DIA:dia.c] " __VA_ARGS__))
#undef DIA_DEBUG_2
#define DIA_DEBUG_2(...) (DIA_VERBOSE_LEVEL < 2 ? : fprintf(stderr, "[DIA:dia.c] " __VA_ARGS__))

#ifndef _DIA_H
#define _DIA_H

dia_node* dia_string(dia_node* arg);
dia_node* dia_integer(dia_node* arg);
dia_node* dia_double(dia_node* arg);
dia_node* dia_bool(dia_node* arg);

// Utility functions
char* dia_token_type_to_string(DIA_TOKEN_TYPE type);
DIA_TOKEN_TYPE dia_token_type_from_string(char* strtype);
uint8_t is_variable(dia_node* node);
void dia_free_node (dia_node* node);
dia_node* dia_bind(dia_node* prev, dia_node* next);
void dia_debug_function_descriptor(dia_node* node, int depth);

// Pre-defined functions
dia_node* dia_print(dia_node* node);
dia_node* dia_puts(dia_node* node);
dia_node* dia_gets(dia_node* node);

void _dia_header_definition();
void _dia_comment_generating();
dia_node* dia_generate_code(dia_node* node);

void dia_custom_function(dia_node* node);
void dia_main(dia_node* node);

#endif
