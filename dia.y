%require "3.8"

%{
#include <stdio.h>
#include <stdint.h>

#undef DIA_DEBUG
#define DIA_DEBUG(...) (DIA_VERBOSE_LEVEL < 1 ? : fprintf(stderr, "[DIA:dia.y] " __VA_ARGS__))

extern uint8_t DIA_VERBOSE_LEVEL;
extern char* yytext;
extern int yylex();
extern void yyerror(const char*);
extern char* DIA_CODE_FILE_NAME;
extern uint8_t _QUIET;

struct _custom_function_t* custom_functions;
%}

/* The lines start with %token will generate .tab.h file
 * it will possible to use it with bison
 */

%code requires {
#include "dia.h"
#include "dia_calculation.h"

dia_node* dia_create_unary_function(
    char* node_name,
    DIA_TOKEN_TYPE type,
    dia_node* a1
  );
dia_node* dia_create_binary_function(
    char* node_name,
    DIA_TOKEN_TYPE type,
    dia_node* a1,
    dia_node* a2
  );
typedef struct _custom_function_t {
    dia_node* node;
    struct _custom_function_t* next;
  } custom_function_t;
dia_node* dia_create_node(char* node_name, DIA_TOKEN_TYPE type);
}

%union {
  int i;
  double f;
  char* str;

  dia_node* node;
  custom_function_t* func;
}

%token <node> DIA_INTEGER
%token <node> DIA_DOUBLE
%token <node> DIA_HEXADECIMAL
%token <node> DIA_STRING
%token <node> DIA_BOOL
%token <node> DIA_VECTOR

%token DIA_MAIN_FUNC          "main"
%token DIA_ALLOC              "="

/* Calculation */
%token DIA_PLUS               "+"
%token DIA_MINUS              "-"
%token DIA_MUL                "*"
%token DIA_DIV                "/"
%token DIA_MOD                "%"

%token DIA_LOGICAL_AND
%token DIA_LOGICAL_OR
%token DIA_LOGICAL_NOT

%token DIA_EQUAL              "=="
%token DIA_NOT_EQUAL          "!="
%token DIA_GREATER_EQUAL      ">="
%token DIA_GREATER            ">"
%token DIA_LESS_EQUAL         "<="
%token DIA_LESS               "<"

%token DIA_BIT_AND            "&"
%token DIA_BIT_XOR
%token DIA_BIT_OR             "|"
%token DIA_BIT_NOT            "~"

/* Calculation: End */

%token DIA_COMMA              ","
%token DIA_BIND               "."
%token DIA_NEXT               ";"

%token DIA_OPEN_PARENTHESIS   "("
%token DIA_CLOSE_PARENTHESIS  ")"
%token DIA_OPEN_BRACKET       "["
%token DIA_CLOSE_BRACKET      "]"

%token DIA_COLON              ":"

%token DIA_IF                 "if"
%token DIA_ELSE               "else"

/* Precedence */
/* Reference: https://en.cppreference.com/w/c/language/operator_precedence */
%left DIA_LOGICAL_OR
%left DIA_LOGICAL_AND

%left DIA_BIT_OR
%left DIA_BIT_XOR
%left DIA_BIT_AND

%left DIA_EQUAL DIA_NOT_EQUAL
%left DIA_GREATER_EQUAL DIA_GREATER DIA_LESS_EQUAL DIA_LESS

%left DIA_PLUS DIA_MINUS
%left DIA_MUL DIA_DIV DIA_MOD

%token <str> DIA_IDENTIFIER

%%

/* enjoy = "Enjoy the flexivity of the Dia language!"
 *
 * main = puts("Hello World!");
 *        enjoy.puts;
 *
 */

dia: custom_func dia_main
     {
       DIA_DEBUG("Welcome to the Dia World!\n");
       custom_functions = $<func>1;

       for (custom_function_t* _func = $<func>1; _func != NULL; _func = _func->next) {
         dia_debug_function_descriptor(_func->node, 0);
       }

       if (!_QUIET && DIA_CODE_FILE_NAME) _dia_comment_generating();

       _dia_header_definition();
       for (custom_function_t* _func = $<func>1; _func != NULL; _func = _func->next) {
         char* _name = _func->node->name;
         DIA_DEBUG("It is going to generate code for the function %s...\n", _name);
         dia_custom_function(_func->node);
         DIA_DEBUG("I'm expecting that code generation for the custom function is done...!\n");
       }

       dia_main($<node>2);
     }
   ;

custom_func: /* If the custom_func reaches to the end, or the custom_func does not exist */ { $<func>$ = NULL; }
           | DIA_IDENTIFIER DIA_OPEN_PARENTHESIS custom_parameters DIA_CLOSE_PARENTHESIS DIA_COLON DIA_IDENTIFIER DIA_ALLOC dia_expr custom_func
             {
               DIA_DEBUG("DIA_IDENTIFIER ( dia_parameters [:types], ... ) : type DIA_ALLOC dia_expr custom_func\n");

               custom_function_t* func = (custom_function_t*)calloc(1, sizeof(custom_function_t));
               func->next = $<func>9;

               dia_node* node = (dia_node*)calloc(1, sizeof(dia_node));
               node->name = strdup($1);
               node->next_function = $<node>8;
               node->type = dia_token_type_from_string($<str>6);

               node->num_of_params = 0;
               for (dia_node* _node = $<node>3; _node; _node = _node->next_function)
                 node->num_of_params++;

               node->parameters = (dia_node**)calloc(node->num_of_params, sizeof(dia_node*));

               dia_node* _param = $<node>3;
               for (int i=0; i<node->num_of_params; i++) {
                 dia_node* tmp = _param->next_function;
                 node->parameters[i] = _param;

                 _param->next_function = NULL;
                 _param = tmp;
               }
               if (_param != NULL)
                 DIA_DEBUG("warning: There is an unhandled parameter in the custom function %s.\n", node->name);

               func->node = node;
               $<func>$ = func;
             }
           | DIA_IDENTIFIER DIA_ALLOC dia_expr custom_func
             {
               DIA_DEBUG("Dia: custom function, which name is '%s'\n", $1);
               custom_function_t* func = (custom_function_t*)calloc(1, sizeof(custom_function_t));
               func->next = $<func>4;

               dia_node* node = (dia_node*)calloc(1, sizeof(dia_node));
               node->name = strdup($1);
               node->next_function = $<node>3;
               node->num_of_params = 0;

               DIA_TOKEN_TYPE return_type = 0;
               for (dia_node* _node = node->next_function; _node != NULL; _node = _node->next_function) {
                 dia_debug_function_descriptor(_node, 0);
                 return_type = _node->type;
               }
               node->type = return_type;

               func->node = node;
               $<func>$ = func;
             }
           ;

custom_parameters: DIA_IDENTIFIER DIA_COLON DIA_IDENTIFIER
                   {
                     dia_node* node = (dia_node*)calloc(1, sizeof(dia_node));
                     node->name = $<str>1;
                     node->type = dia_token_type_from_string($<str>3);
                     $<node>$ = node;
                   }
                 | DIA_IDENTIFIER DIA_COLON DIA_IDENTIFIER DIA_COMMA custom_parameters
                   {
                     dia_node* node = (dia_node*)calloc(1, sizeof(dia_node));
                     node->name = $<str>1;
                     node->type = dia_token_type_from_string($<str>3);
                     node->next_function = $<node>5;
                     $<node>$ = node;
                   }
                 ;

dia_main: DIA_MAIN_FUNC DIA_ALLOC dia_expr
          {
            DIA_DEBUG("Let's go to the final job, (except for the cleanup)\n");
            $<node>$ = $<node>3;
          }


dia_expr: dia_expr DIA_BIND dia_expr
          {
            $<node>$ = dia_bind($<node>1, $<node>3);
          }
        | dia_expr DIA_NEXT dia_expr
          {
            $<node>1->next_function = $<node>3;
            DIA_DEBUG("Reserved for DIA_NEXT\n");
            $<node>$ = $<node>1;
          }
        | dia_expr DIA_NEXT
          {
            DIA_DEBUG("Semicolon Terminated\n");
            $<node>$ = $<node>1;
          }
        | dia_function
        | dia_if
        ;

dia_if: DIA_IF DIA_OPEN_PARENTHESIS dia_function DIA_CLOSE_PARENTHESIS dia_expr dia_else
        {
          DIA_DEBUG("dia_if: If-else detected.\n");
          if ($<node>3->type != DIA_BOOL)
            yyerror("The expression inside the if component should return Bool type.");

          dia_node* node = (dia_node*)malloc(sizeof(dia_node));
          node->name = strdup("if");
          node->num_of_params = 3;
          node->parameters = (dia_node**)calloc(3, sizeof(dia_node*));
          node->parameters[0] = $<node>3;
          node->parameters[1] = $<node>5;
          node->parameters[2] = $<node>6;

          dia_debug_function_descriptor(node, 0);
          $<node>$ = node;
        }
      ;

dia_else: DIA_ELSE dia_if { $<node>$ = $<node>2; }
        | DIA_ELSE dia_function { $<node>$ = $<node>2; }
        ;

dia_function: DIA_IDENTIFIER DIA_OPEN_PARENTHESIS dia_parameters DIA_CLOSE_PARENTHESIS
              {
                DIA_DEBUG("Entering dia_function\n");
                dia_node* node = (dia_node*)malloc(sizeof(dia_node));
                node->name = strdup($1);

                // Calculating the size of the parameters
                for (dia_node* _node = $<node>3; _node != NULL; _node = _node->next_parameter) {
                  dia_debug_function_descriptor(_node, 0);
                  ++node->num_of_params;
                }

                node->parameters = (dia_node**)malloc(sizeof(dia_node*)*node->num_of_params);

                // Build up parameters, and clean up next_parameter pointers
                int i=0;
                for (dia_node* _node = $<node>3; _node != NULL; i++) {
                  dia_node* tmp = _node->next_parameter;
                  _node->next_parameter = NULL;
                  node->parameters[i] = _node;
                  _node = tmp;
                }
                dia_debug_function_descriptor(node, 0);
                $<node>$ = node;
              }
            | DIA_IDENTIFIER
              {
                dia_node* _node = (dia_node*)malloc(sizeof(dia_node));
                _node->name = strdup($1);

                dia_debug_function_descriptor(_node, 0);

                $<node>$ = _node;
              }
            | dia_calculation
            | token
            ;

dia_parameters: dia_function
                {
                  DIA_DEBUG("+- Function Parameter: %s\n", $<node>1->name);
                  $<node>$ = $<node>1;
                }
              | dia_parameters DIA_COMMA dia_function
                {
                  dia_node* node = $<node>1;
                  for (; node->next_parameter != NULL; node = node->next_parameter)
                    DIA_DEBUG("node->name : %s\n", node->name);
                  node->next_parameter = $<node>3;

                  DIA_DEBUG("+- Function Parameter: %s ... %s\n", $<node>1->name, $<node>3->name);
                  $<node>$ = $<node>1;
                }
              ;

/* Calculation */
dia_calculation: dia_arithmetic
               | dia_logical
               | dia_comparison
               | dia_bitwise
               ;

dia_arithmetic: dia_function DIA_PLUS dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "plus", $<node>1->type, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_MINUS dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "minus", $<node>1->type, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_MUL dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "times", $<node>1->type, $<node>1, $<node>3
                  );
               }
              | dia_function DIA_DIV dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "divide", $<node>1->type, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_MOD dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "modular", $<node>1->type, $<node>1, $<node>3
                  );
                }
              ;

dia_logical: dia_function DIA_LOGICAL_AND dia_function
             {
               $<node>$ = dia_create_binary_function(
                 "logical_and", DIA_BOOL, $<node>1, $<node>3
               );
             }
           | dia_function DIA_LOGICAL_OR dia_function
             {
               $<node>$ = dia_create_binary_function(
                 "logical_or", DIA_BOOL, $<node>1, $<node>3
               );
             }
           | DIA_LOGICAL_NOT dia_function
             { $<node>$ = dia_create_unary_function(
                                          "logical_not", DIA_BOOL, $<node>2); }
           ;

dia_comparison: dia_function DIA_EQUAL dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "equal", DIA_BOOL, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_NOT_EQUAL dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "not_equal", DIA_BOOL, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_GREATER_EQUAL dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "greater_equal", DIA_BOOL, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_GREATER dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "greater", DIA_BOOL, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_LESS_EQUAL dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "less_equal", DIA_BOOL, $<node>1, $<node>3
                  );
                }
              | dia_function DIA_LESS dia_function
                {
                  $<node>$ = dia_create_binary_function(
                    "less", DIA_BOOL, $<node>1, $<node>3
                  );
                }
              ;

dia_bitwise: dia_function DIA_BIT_AND dia_function
             {
               $<node>$ = dia_create_binary_function(
                 "bit_and", DIA_BOOL, $<node>1, $<node>3
               );
             }
           | dia_function DIA_BIT_OR dia_function
             {
               $<node>$ = dia_create_binary_function(
                 "bit_or", DIA_BOOL, $<node>1, $<node>3
               );
             }
           | dia_function DIA_BIT_XOR dia_function
             {
               $<node>$ = dia_create_binary_function(
                 "bit_xor", DIA_BOOL, $<node>1, $<node>3
               );
             }
           | DIA_BIT_NOT dia_function
             {
               $<node>$ = dia_create_unary_function(
                 "bit_not", DIA_BOOL, $<node>2
               );
             }
          ;

token: DIA_STRING         { $<node>$ = dia_string($1); }
     | DIA_INTEGER        { $<node>$ = dia_integer($1); }
     | DIA_DOUBLE         { $<node>$ = dia_double($1); }
     | DIA_BOOL           { $<node>$ = dia_bool($1); }
     | DIA_OPEN_PARENTHESIS dia_calculation DIA_CLOSE_PARENTHESIS         { $<node>$ = $<node>2; }
     | DIA_OPEN_BRACKET dia_parameters DIA_CLOSE_BRACKET
       {
         dia_node* vec = (dia_node*)malloc(sizeof(dia_node));
         vec->num_of_params = 0;
         vec->name = strdup("vector");
         vec->next_function = NULL;
         vec->parameters = NULL;
         vec->type = DIA_VECTOR;

         DIA_TOKEN_TYPE type_of_first_element = 0;
         if ($<node>2->next_parameter != NULL)
           type_of_first_element = $<node>2->next_parameter->type;

         for (dia_node* _node = $<node>2; _node != NULL; _node = _node->next_parameter) {
           if (type_of_first_element != _node->type) {
             DIA_DEBUG("dia_vector: Type mismatch\n");
             DIA_DEBUG("dia_vector: vec[0]: %d\n", type_of_first_element);
             DIA_DEBUG("dia_vector: vec[%d]: %d\n", vec->num_of_params, vec->type);
           }
           vec->num_of_params++;
         }

         int i = 0;
         dia_node** params = (dia_node**)malloc(sizeof(dia_node*)*vec->num_of_params);
         for (dia_node* _node = $<node>2; _node != NULL; i++) {
           dia_node* tmp = _node->next_parameter;
           _node->next_parameter = NULL;
           params[i] = _node;
           _node = tmp;
         }

         vec->parameters = params;
         dia_debug_function_descriptor(vec, 0);
         $<node>$ = vec;
       }
     ;

%%

dia_node* dia_create_unary_function(
    char* node_name,
    DIA_TOKEN_TYPE type,
    dia_node* a1
  ) {
  dia_node* _node = dia_create_node(node_name, type);
  _node->parameters = (dia_node**)malloc(sizeof(dia_node*));
  _node->parameters[0] = a1;
  _node->num_of_params = 1;

  return _node;
}

dia_node* dia_create_binary_function(
    char* node_name,
    DIA_TOKEN_TYPE type,
    dia_node* a1,
    dia_node* a2
  ) {
   dia_node* _node = dia_create_node(node_name, type);
  _node->parameters = (dia_node**)malloc(sizeof(dia_node*)*2);
  _node->parameters[0] = a1;
  _node->parameters[1] = a2;
  _node->num_of_params = 2;

  return _node;
}

dia_node* dia_create_node(char* node_name, DIA_TOKEN_TYPE type) {
  dia_node* node = (dia_node*)malloc(sizeof(dia_node));
  node->name = strdup(node_name);
  node->next_parameter = NULL;
  node->next_function = NULL;
  node->parameters = NULL;
  node->num_of_params = 0;
  node->type = type;

  return node;
}

void yyerror(const char *str) {
  puts("diac: There was an error while parsing the code");
  printf("[DIA:Error] %s\n", str);

  return;
}
