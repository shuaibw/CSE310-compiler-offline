%{
#include <iostream>
#include<string>
#include<fstream>
#include "SymbolInfo.h"
#include "SymbolTable.h"
#include "ScopeTable.h"
#include "parserutil.h"

extern int yylineno;
extern FILE* yyin;
const char* PARSER_LOG_FILE = "./parserlog.txt";
const char* PARSER_ERR_FILE = "./parsererr.txt";
const char* LEX_LOG_FILE = "./lexlog.txt";
const char* LEX_TOKEN_FILE = "./lextok.txt";
ofstream plo(PARSER_LOG_FILE, ios::out); // parser log out
ofstream peo(PARSER_ERR_FILE, ios::out); // parser error out
ofstream llo(LEX_LOG_FILE, ios::out); // lex log out
ofstream lto(LEX_TOKEN_FILE, ios::out); // lex token out
int err_count = 0;
SymbolTable sym_tab(7);
vector<SymbolInfo> param_holder;
vector<string> arg_type_holder;

void yyerror(string s){
	plo << "Error at line "<< yylineno << ": " << s << "\n" << endl;
    peo << "Error at line "<< yylineno << ": " << s << "\n" << endl;
    err_count++;
}

int yylex(void);
int yyparse(void);

%}
%define parse.error verbose
%union {
    SymbolInfo* sym_info;
    struct putil* pt;
    char *op;
}

%token IF INT FLOAT VOID ELSE FOR WHILE DO BREAK CHAR DOUBLE RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN INCOP DECOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%token <sym_info> ID CONST_INT CONST_FLOAT CONST_CHAR ERRFLT 
%token <op> ADDOP MULOP RELOP LOGICOP ASSIGNOP
%type <pt>  start program unit variable var_declaration type_specifier func_declaration func_definition parameter_list
%type <pt>  expression factor unary_expression term simple_expression rel_expression statement statements compound_statement logic_expression expression_statement
%type <pt> arguments argument_list declaration_list

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%destructor{delete $$;} <pt>
%%
start               :   program
{
    print_parser_grammar("start", "program");
    $$ = new putil();
    $$->data = $1->data;
    delete $1;
}
program             :   program unit
{
    $$ = new putil();
    $$->data = $1->data + "\n" + $2->data;
    print_parser_grammar("program", "program unit");
    print_parser_text($$->data);
    delete $1;
    delete $2;
}
                    |   unit
{
    $$ = new putil();
    $$->data = $1->data;
    print_parser_grammar("program", "unit");
    print_parser_text($$->data);
    delete $1;
}
                    ;
unit                :   var_declaration
{
    $$ = new putil();
    $$->data = $1->data;
    print_parser_grammar("unit", "var_declaration");
    print_parser_text($$->data);
    delete $1;
}
                    |   func_declaration
{
    $$ = new putil();
    $$->data = $1->data;
    print_parser_grammar("unit", "func_declaration");
    print_parser_text($$->data);
    delete $1;
}
                    |   func_definition
{
    $$ = new putil();
    $$->data = $1->data;
    print_parser_grammar("unit", "func_definition");
    print_parser_text($$->data);
    delete $1;
}
                    ;
func_declaration    :   type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
{
    print_parser_grammar("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
    $$ = new putil();
    $$->data = $1->data + " " + $2->getName() + "(" + $4->data + ");";
    bool inserted = sym_tab.insert($2->getName(), $2->getType(), llo);
    if(inserted == false) {
        print_multidecl_func($2->getName());
    }
    else {
        print_parser_text($$->data);
        SymbolInfo* sym = sym_tab.lookUp($2->getName());
        sym->ret_type = $1->data;
        sym->param_list = param_holder;
        sym->is_func = true;
    }
    param_holder.clear();
    delete $2;
    delete $4;
}
                    |   type_specifier ID LPAREN RPAREN SEMICOLON
{
    print_parser_grammar("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
    $$ = new putil();
    $$->data = $1->data + " " + $2->getName() + "();";
    bool inserted = sym_tab.insert($2->getName(), $2->getType(), llo);
    if(inserted == false) {
        print_multidecl_func($2->getName());
    }
    else {
        print_parser_text($$->data);
        SymbolInfo* sym = sym_tab.lookUp($2->getName());
        sym->ret_type = $1->data;
        sym->is_func = true;
    }
    delete $1;
    delete $2;
}
                    ;
func_definition     :   type_specifier ID LPAREN parameter_list RPAREN 
{   //Function scope not entered yet, insert function to global scope
    bool inserted = sym_tab.insert($2->getName(), $2->getType(), llo);
    SymbolInfo* sym = sym_tab.lookUp($2->getName());
    if(inserted){ //first time definition
        sym->param_list = param_holder;
        sym->func_defined = true;
        sym->is_func = true;
        sym->ret_type = $1->data;
    }
    else if(sym->is_func){ //in current scope, sym points to previously declared ID. Now validate
        if(!sym->func_defined){ //was not defined previously, but ret_type, param fixed
            sym->func_defined = true;
            bool param_len_match = sym->param_list.size()==param_holder.size();
            bool ret_type_match = sym->ret_type == $1->data;
            if(!ret_type_match){
                print_ret_type_mismatch($2->getName());
            }
            if(!param_len_match){
                print_param_len_mismatch($2->getName());
            }
            else{
                validate_param_type(sym, param_holder);
            }
        }else{ //was defined already
            print_multidef_func($2->getName());
        }
    }else{ // something other than func exists with same name
        print_multidecl_var($2->getName());
    }
    // Don't clear params, to be inserted in function scope by compound_statement
}
                        compound_statement
{
    print_parser_grammar("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
    if(!match_types($1->data, $7->type)) print_return_type_mismatch($2->getName());
    plo << $1->data << ", "<<$7->type<<"\n\n";
    $$ = new putil();
    $$->data = $1->data + " " + $2->getName() + "(" + $4->data + ")" + $7->data;
    print_parser_text($$->data);
    
    delete $1;
    delete $2;
    delete $4;
    delete $7;
}
                    |   type_specifier ID LPAREN RPAREN
{
    bool inserted = sym_tab.insert($2->getName(), $2->getType(), llo);
    SymbolInfo* sym = sym_tab.lookUp($2->getName());
    if(inserted){
        sym->func_defined = true;
        sym->is_func = true;
        sym->ret_type = $1->data;
        param_holder.clear();
    }
    else if(sym->is_func){ //in current scope, sym points to previously declared ID. Now validate
        if(!sym->func_defined){
            sym->func_defined = true;
            bool ret_type_match = sym->ret_type == $1->data;
            if(!ret_type_match){
                print_ret_type_mismatch($2->getName());
            }
        }else{
            print_multidef_func($2->getName());
        }
    }else{
        print_multidecl_var($2->getName());
    }
}
                        compound_statement
{
    print_parser_grammar("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
    if(!match_types($1->data, $6->type)) print_return_type_mismatch($2->getName());
    plo << $1->data << ", "<<$6->type<<"\n\n";
    $$ = new putil();
    $$->data = $1->data + " " + $2->getName() + "()" + $6->data;
    print_parser_text($$->data);
    delete $1;
    delete $2;
    delete $6;
}
                    ;

parameter_list      :   parameter_list COMMA type_specifier ID
{
    if(find_param_by_name(param_holder, $4->getName())){
        print_multidecl_param($4->getName());
    }
    param_holder.emplace_back($4->getName(), $3->data);
    print_parser_grammar("parameter_list", "parameter_list COMMA type_specifier ID");
    $$ = new putil();
    $$->data = $1->data +"," + $3->data + " " + $4->getName();
    print_parser_text($$->data);
    delete $1;
    delete $3;
    delete $4;
}
                    |   parameter_list COMMA type_specifier
{
    print_parser_grammar("parameter_list", "parameter_list COMMA type_specifier");
    param_holder.emplace_back("-1", $3->data);
    $$ = new putil();
    $$->data = $1->data + "," + $3->data;
    print_parser_text($$->data);
    delete $1;
    delete $3;
}
                    |   type_specifier ID
{
    if(find_param_by_name(param_holder, $2->getName())){
        print_multidecl_param($2->getName());
    }
    param_holder.emplace_back($2->getName(), $1->data);
    print_parser_grammar("parameter_list", "type_specifier ID");
    $$ = new putil();
    $$->data = $1->data + " " + $2->getName();

    print_parser_text($$->data);
}
                    |   type_specifier
{
    print_parser_grammar("parameter_list", "type_specifier");
    param_holder.emplace_back("-1", $1->data);
    $$ = new putil();
    $$->data = $1->data;
    print_parser_text($$->data);
}
                    ;
compound_statement  :   LCURL 
{ //Now insert function parameters to scope table if they exist
    sym_tab.enterScope();
    if(!param_holder.empty()){ //param holder contains function
        for(const auto &sym: param_holder) {
            bool inserted = sym_tab.insert(sym.getName(), "ID", llo);
            
            sym_tab.lookUp(sym.getName())->data_type = sym.getType();
        }
    }
    param_holder.clear();
}
                        statements RCURL
{
    print_parser_grammar("compound_statement", "LCURL statements RCURL");
    $$ = new putil();
    $$->data = "{\n" + $3->data + "\n}";
    $$->type = $3->type; //for holding return data type
    print_parser_text($$->data);
    sym_tab.printAllScopes(plo);
    sym_tab.exitScope();
    delete $3;
}
                    |   LCURL
{
    sym_tab.enterScope();
}
                        RCURL
{
    print_parser_grammar("compound_statement", "LCURL RCURL");
    $$ = new putil();
    $$->data = "{}";
    print_parser_text($$->data);
    sym_tab.printAllScopes(plo);
    sym_tab.exitScope();
}
                    ;
var_declaration     :   type_specifier declaration_list SEMICOLON
{
    print_parser_grammar("var_declaration", "type_specifier declaration_list SEMICOLON");
    if($1->data == "void"){
        print_void_var();
    }
    $$ = new putil();
    $$->data = $1->data + " " + $2->data + ";";
    print_parser_text($$->data);
    //set data types in symbol info
    vector<string> vars = split($2->data, ',');
    for(const auto &s: vars){
        size_t loc = s.find("[");
        string name;
        string dtype;
        if(loc==string::npos) {
            name=s;
            dtype=$1->data;
        }
        else {
            name=s.substr(0, loc);
            dtype="ara_"+$1->data;
        }
        SymbolInfo* sym = sym_tab.lookUp(name);
        if(!sym->data_type.empty()) continue;
        sym->data_type = dtype;
    }
    delete $1;
    delete $2;
}
                    ;
type_specifier      :   INT
{
    print_parser_grammar("type_specifier", "INT");
    $$ = new putil();
    $$->data = "int";
    $$->type = "int";
    print_parser_text($$->data);
}
                    |   FLOAT
{
    print_parser_grammar("type_specifier", "FLOAT");
    $$ = new putil();
    $$->data = "float";
    $$->type = "float";
    print_parser_text($$->data);
}
                    |   VOID
{
    print_parser_grammar("type_specifier", "VOID");
    $$ = new putil();
    $$->data = "void";
    $$->type = "void";
    print_parser_text($$->data);
}
                    ;
                    ;
declaration_list    :   declaration_list COMMA ID
{
    $$ = new putil();
    $$->data = $1->data + "," + $3->getName();
    //----Symbol table insertion
    bool inserted = sym_tab.insert($3->getName(), $3->getType(), llo);
    if(inserted == false){
        print_multidecl_var($3->getName());
    }
    print_parser_grammar("declaration_list", "declaration_list COMMA ID");
    print_parser_text($$->data);
    //----Finished symbol table insertion
    delete $1;
    delete $3;
}
                    |   declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
{
    $$ = new putil();
    $$->data = $1->data + "," + $3->getName() + "[" + $5->getName() + "]";
    //-----Symbol table insertion
    bool inserted = sym_tab.insert($3->getName(), $3->getType(), llo);
    if(inserted == false) {
        print_multidecl_var($3->getName());
    }
    print_parser_grammar("declaration_list", "declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
    print_parser_text($$->data);
    //-----Finished SymbolTable insertion
    delete $1;
    delete $3;
    delete $5;
}
                    |   ID
{
    $$ = new putil();
    $$->data = $1->getName();
    //-----SymbleTable insertion
    bool inserted = sym_tab.insert($1->getName(), $1->getType(), llo);
    if(inserted == false) {
        print_multidecl_var($1->getName());
    }
    print_parser_grammar("declaration_list", "ID");
    print_parser_text($$->data);
    //------Finished SymbolTable insertion
    delete $1;
}
                    |   ID LTHIRD CONST_INT RTHIRD
{
    $$ = new putil();
    $$->data = $1->getName() + "[" + $3->getName() + "]";
    //-----SymbleTable insertion
    bool inserted = sym_tab.insert($1->getName(), $1->getType(), llo);
    if(inserted == false) {
        print_multidecl_var($1->getName());
    }
    print_parser_grammar("declaration_list", "ID LTHIRD CONST_INT RTHIRD");
    print_parser_text($$->data);
    //------Finished SymbolTable insertion
    delete $1;
    delete $3;
}
                    ;
statements          :   statement
{
    print_parser_grammar("statements", "statement");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type; //for return value data type
    print_parser_text($$->data);
    delete $1;
}
                    |   statements statement
{
    print_parser_grammar("statements", "statements statement");
    $$ = new putil();
    $$->data = $1->data + "\n" + $2->data;
    $$->type = $2->type //for return value data type
    print_parser_text($$->data);
    delete $1;
    delete $2;
}
                    ;
statement           :   var_declaration
{
    print_parser_grammar("statement", "var_declaration");
    $$ = new putil();
    $$->data = $1->data;
    print_parser_text($$->data);
    delete $1;
}
                    |   expression_statement
{
    print_parser_grammar("statement", "expression_statement");
    $$ = new putil();
    $$->data = $1->data;
    print_parser_text($$->data);
    delete $1;
}
                    |   compound_statement
{
    print_parser_grammar("statement", "compound_statement");
    $$ = new putil();
    $$->data = $1->data;
    print_parser_text($$->data);
    delete $1;
}
                    |   FOR LPAREN expression_statement expression_statement expression RPAREN statement
{
    print_parser_grammar("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
    $$ = new putil();
    $$->data = "for(" + $3->data + $4->data + $5->data + ")" + $7->data;
    print_parser_text($$->data);
    delete $3;
    delete $4;
    delete $5;
    delete $7;
}
                    |   IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
{
    print_parser_grammar("statement", "IF LPAREN expression RPAREN statement");
    $$ = new putil();
    $$->data = "if(" + $3->data + ")" + $5->data;
    print_parser_text($$->data);
    delete $3;
    delete $5;
}
                    |   IF LPAREN expression RPAREN statement ELSE statement
{
    print_parser_grammar("statement", "IF LPAREN expression RPAREN statement ELSE statement");
    $$ = new putil();
    $$->data = "if(" + $3->data + ")" + $5->data + "else " + $7->data;
    print_parser_text($$->data);
    delete $3;
    delete $5;
    delete $7;
}
                    |   WHILE LPAREN expression RPAREN statement
{
    print_parser_grammar("statement", "WHILE LPAREN expression RPAREN statement");
    $$ = new putil();
    $$->data = "while(" + $3->data + ")" + $5->data;
    print_parser_text($$->data);
    delete $3;
    delete $5;
}
                    |   PRINTLN LPAREN ID RPAREN SEMICOLON
{
    print_parser_grammar("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
    $$ = new putil();
    $$->data = "printf(" + $3->getName() + ");";
    SymbolInfo* sym = sym_tab.lookUp($3->getName());
    if(sym==nullptr){
        print_undecl_var($3->getName());
    }
    print_parser_text($$->data);
    delete $3;
}
                    |   RETURN expression SEMICOLON
{
    print_parser_grammar("statement", "RETURN expression SEMICOLON");
    $$ = new putil();
    $$->data = "return " + $2->data + ";";
    $$->type = $2->type;
    print_parser_text($$->data);
    delete $2;
}
                    ;
expression_statement    :   SEMICOLON
{
    print_parser_grammar("expression_statement", "SEMICOLON");
    $$ = new putil();
    $$->data = ";";
    print_parser_text($$->data);
}
                    |   expression SEMICOLON
{
    print_parser_grammar("expression_statement", "expression SEMICOLON");
    $$ = new putil();
    $$->data = $1->data + ";";
    print_parser_text($$->data);
    delete $1;
}
                        ;
variable            :   ID
{
    print_parser_grammar("variable", "ID");
    $$ = new putil();
    $$->data = $1->getName();
    SymbolInfo* ret = sym_tab.lookUp($1->getName());
    if(ret == nullptr){
        print_undecl_var($1->getName());
        $$->type = "ERR";
    }else{
        if(ret->data_type.find("ara")==0){ //if data type starts with ara (ara_int, ara_float)
            print_inv_ara_assignment(ret->getName()); //must contain []
        }
        $$->type = ret->data_type;
    }
    print_parser_text($$->data);
    delete $1;
}
                    |   ID LTHIRD expression RTHIRD
{
    print_parser_grammar("variable", "ID LTHIRD expression RTHIRD");
    $$ = new putil();
    $$->data = $1->getName() + "[" + $3->data + "]";
    SymbolInfo *ret = sym_tab.lookUp($1->getName());
    bool is_idx_int = $3->type == "CONST_INT" ||  $3->type == "int";
    if(ret == nullptr){ //not declared yet
        print_undecl_var($1->getName());
        $$->type="ERR";
    }else if (ret->data_type.find("ara")!=0){//data_type doesn't begin with ara_, so not an ara
        print_not_an_ara($1->getName());
    } else if(!is_idx_int){ //Invalid index
        print_invalid_ara_idx();
    }
    $$->type = ret->data_type;
    print_parser_text($$->data);
    delete $1;
    delete $3;
}
                    ;
expression          :   logic_expression
{
    print_parser_grammar("expression", "logic_expression");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    |   variable ASSIGNOP logic_expression
{
    print_parser_grammar("expression", "variable ASSIGNOP logic_expression");
    string v = $1->data;
    size_t loc = v.find("[");
    string var_name = loc==string::npos? v : v.substr(0, loc);
    SymbolInfo* sym = sym_tab.lookUp(var_name);
    if($3->type=="void") print_void_func_in_expr(); //don't check anything else
    else if(sym!=nullptr && !match_types(sym->data_type, $3->type)){ //was declared before, but type mismatch
        print_type_mismatch();
    }
    $$ = new putil();
    $$->data = $1->data + "=" + $3->data;
    $$->type = $3->type;
    print_parser_text($$->data);
    delete $1;
    delete $3;
}
                    ;
logic_expression    :   rel_expression
{
    print_parser_grammar("logic_expression", "rel_expression");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    |   rel_expression LOGICOP rel_expression
{
    print_parser_grammar("logic_expression", "rel_expression LOGICOP rel_expression");
    $$ = new putil();
    $$->data = $1->data + $2 + $3->data;
    $$->type = "CONST_INT";
    print_parser_text($$->data);
    delete $1;
    delete $2;
    delete $3;
}
                    ;   
rel_expression      :   simple_expression
{
    print_parser_grammar("rel_expression", "simple_expression");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    |   simple_expression RELOP simple_expression
{
    print_parser_grammar("rel_expression", "simple_expression RELOP simple_expression");
    $$ = new putil();
    $$->data = $1->data + $2 + $3->data;
    $$->type = "CONST_INT";
    print_parser_text($$->data);
    delete $1;
    delete $2;
    delete $3;
}
                    ;
simple_expression   :   term
{
    print_parser_grammar("simple_expression", "term");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    |   simple_expression ADDOP term
{
    print_parser_grammar("simple_expression", "simple_expression ADDOP term");
    $$ = new putil();
    $$->data = $1->data + $2 + $3->data;
    $$->type = upcast_type($1->type, $3->type);
    print_parser_text($$->data);
    delete $1;
    delete $2;
    delete $3;
}
                    ;
term                :   unary_expression
{
    print_parser_grammar("term", "unary_expression");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    |   term MULOP unary_expression
{
    print_parser_grammar("term", "term MULOP unary_expression");
    $$ = new putil();
    $$->data = $1->data  + $2 + $3->data;
    //div/mod by zero check
    if($3->data=="0"){
        if($2[0]=='%') print_mod_by_zero();
        else if($2[0]=='*') print_div_by_zero();
    }
    //void func check
    if($3->type=="void") print_void_func_in_expr();
    if($2[0]=='%'){
        $$->type="CONST_INT"; 
        if ($1->type!="CONST_INT" || $3->type!="CONST_INT") {
            print_mod_mismatch();
        }
    }else{
        $$->type = upcast_type($1->type, $3->type);
    }
    print_parser_text($$->data);
    delete $1;
    delete $2;
    delete $3;
}
                    ;
unary_expression    :   ADDOP unary_expression
{
    print_parser_grammar("unary_expression", "ADDOP unary_expression");
    $$ = new putil();
    $$->data = $1 + $2->data;
    $$->type = $2->type;
    print_parser_text($$->data);
    delete $1;
    delete $2;
}
                    |   NOT unary_expression
{
    print_parser_grammar("unary_expression", "NOT unary_expression");
    $$ = new putil();
    $$->data = "!"+$2->data;
    $$->type = $2->type;
    print_parser_text($$->data);
    delete $2;
}
                    |   factor
{
    print_parser_grammar("unary_expression", "factor");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    ;
factor              :   variable
{
    print_parser_grammar("factor", "variable");
    $$ = new putil();
    $$->data = $1->data;
    $$->type = $1->type;
    print_parser_text($$->data);
    delete $1;
}
                    |   ID LPAREN argument_list RPAREN
{
    print_parser_grammar("factor", "ID LPAREN argument_list RPAREN");
    $$ = new putil();
    $$->data = $1->getName() + "(" + $3->data + ")";
    SymbolInfo* sym = sym_tab.lookUp($1->getName());
    if(sym==nullptr){
        print_undef_func($1->getName());
        $$->type = "ERR";
    }else{
        $$->type = sym->ret_type;
        if(!sym->is_func) print_not_a_func($1->getName()); //something other than function
        else if(!sym->func_defined) print_undef_func($1->getName());//declared, not defined
        else if(arg_type_holder.size()!=sym->param_list.size()){ //declared, defined, arglens no match
            print_param_len_mismatch($1->getName());
        }else{ //arg lens matched, now validate
            validate_arg_type(sym, arg_type_holder);
        }
    }
    arg_type_holder.clear();
    print_parser_text($$->data);
    delete $1;
    delete $3;
}
                    |   LPAREN expression RPAREN
{
    print_parser_grammar("factor", "LPAREN expression RPAREN");
    $$ = new putil();
    $$->data = "(" + $2->data + ")";
    $$->type = $2->type;
    print_parser_text($$->data);
    delete $2;
}
                    |   CONST_INT
{
    print_parser_grammar("factor", "CONST_INT");
    $$ = new putil();
    $$->data = $1->getName();
    $$->type = "CONST_INT";
    print_parser_text($$->data);
    delete $1;
}
                    |   CONST_FLOAT
{
    print_parser_grammar("factor", "CONST_FLOAT");
    $$ = new putil();
    $$->data = $1->getName();
    $$->type = "CONST_FLOAT";
    print_parser_text($$->data);
    delete $1;
}
                    |   variable INCOP
{
    print_parser_grammar("factor", "variable INCOP");
    $$ = new putil();
    $$->data = $1->data + "++";
    $$->type = "INCOP";
    print_parser_text($$->data);
    delete $1;
}
                    |   variable DECOP
{
    print_parser_grammar("factor", "variable DECOP");
    $$ = new putil();
    $$->data = $1->data + "--";
    $$->type = "DECOP";
    print_parser_text($$->data);
    delete $1;
}
                    ;          
argument_list       :   arguments
{
    print_parser_grammar("argument_list", "arguments");
    $$ = new putil();
    $$->data = $1->data;
    print_parser_text($$->data);
    delete $1;
}
                    |
{
    print_parser_grammar("argument_list", "");
    $$ = new putil();
}
                    ;
arguments           :   arguments COMMA logic_expression
{
    print_parser_grammar("arguments", "arguments COMMA logic_expression");
    $$ = new putil();
    $$->data = $1->data + "," + $3->data;
    arg_type_holder.push_back($3->type);
    print_parser_text($$->data);
    delete $1;
    delete $3;
}
                    |   logic_expression
{
    print_parser_grammar("arguments", "logic_expression");
    $$ = new putil();
    $$->data = $1->data;
    arg_type_holder.push_back($1->type);
    print_parser_text($$->data);
    delete $1;
}
                    ;
%%

main(int argc, char* argv[])
{
    #ifdef YYDEBUG
    yydebug = 1;
    #endif
    if(argc != 2){
        cout<<"No source file provided"<<endl;
        return 1;
    }

    FILE *fin = fopen(argv[1], "r");
    if(fin == NULL){
        cout<<"Error opening file"<<endl;
        return 1;
    }
    yyin = fin;
    yylineno = 1;
    yyparse();
    sym_tab.printAllScopes(plo);
    plo << "Total number of lines: " << yylineno << endl;
    plo << "Total number of errors: " << err_count << endl;
    fclose(fin);
    plo.close();
    peo.close();
    exit(0);
}
