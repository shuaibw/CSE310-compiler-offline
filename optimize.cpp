#include<fstream>
#include<string>
#include<iostream>
#include<vector>
using namespace std;
const char* ASM_CODE_OPTIM = "./optimized_code_1.asm";
const char* ASM_CODE_OUT = "./code.asm";

ifstream fin(ASM_CODE_OUT, ios::in);
ofstream fout(ASM_CODE_OPTIM, ios::out);
string line;
vector<string> code;
void two_window_pass();
void six_window_pass();
void advanced_two_window_pass();
void four_window_pass();
vector<string> split(string s, char c = ' '){
    vector<string> result;
    const char* str = s.c_str();
    do{
        const char *begin = str;
        while(*str != c && *str) str++;
        result.push_back(string(begin, str));
    } while (0 != *str++);
    return result;
}

void peep_optimize(){
    while (std::getline(fin, line))
    {
        code.emplace_back(line);
    }
    two_window_pass();
 
    fin = ifstream(ASM_CODE_OPTIM, ios::in);
    fout = ofstream("./optimized_code.asm", ios::out);
    code.clear();
    while (std::getline(fin, line))
    {
        code.emplace_back(line);
    }
    six_window_pass();
    fin = ifstream("./optimized_code.asm", ios::in);
    fout = ofstream("./final_code_temp.asm", ios::out);
    code.clear();
    while(std::getline(fin, line)){
        if(line[0]!=';') code.emplace_back(line);
    }
    two_window_pass();

    fin = ifstream("./final_code_temp.asm", ios::in);
    fout = ofstream("./final_code.asm", ios::out);

    four_window_pass();

}
void two_window_pass(){
    for(int i=0;i<code.size() - 1;i++){
        string c1 = code.at(i);
        string c2 = code.at(i+1);
        vector<string> p1 = split(c1, ' ');
        vector<string> p2 = split(c2, ' ');
        //remove redundant jumps
        //JMP @L1 --> delete
        //L1:
        if(p1.at(0)[0]=='J' && p1.at(1)+":"==p2.at(0)){
            code.erase(code.begin() + i);
        }

        if(p1.at(0)=="PUSH" && p2.at(0)=="POP"){
            //remove redundant push pops
            if(p1.at(1)==p2.at(1)){
                code.at(i)="; PEEP --> " + code.at(i);
                code.at(i+1)="; PEEP --> " + code.at(i+1);
                continue;
            }
        }
        //remove redundant move
        if(p1.at(0)=="MOV" && p2.at(0)=="MOV"){
            p1.at(1).pop_back(); // MOV DS, AX --> remove comma after DS
            p2.at(1).pop_back();
            // MOV DX, AX
            // MOV AX, DX --> eliminate
            if (p1.at(2)==p2.at(1) && p1.at(1)==p2.at(2)){
                code.at(i+1)= "; PEEP --> " + code.at(i+1);
                continue;
            }
        }
        
    }
    for(const auto &s: code) fout << s << endl;
    fout.close();
    fin.close();
}
void four_window_pass(){
    for(int i=0;i<code.size()-3;i++){
        string c1 = code.at(i);//push 3
        string c2 = code.at(i+1);//push 4
        string c3 = code.at(i+2);//pop bx
        string c4 = code.at(i+3);//push ax

        vector<string> p1 = split(c1, ' ');
        if(p1.at(0)!="PUSH") continue;
        vector<string> p2 = split(c2, ' ');
        if(p2.at(0)!="PUSH") continue;
        vector<string> p3 = split(c3, ' ');
        if(p3.at(0)!="POP") continue;
        vector<string> p4 = split(c4, ' ');
        if(p4.at(0)!="POP") continue;

        //convert push 7, pop ax to mov ax, 7
        bool is_mem1 = p1.at(1)[0]=='t' || p1.at(1)[0]=='[';
        bool is_mem2 = p2.at(1)[0]=='t' || p2.at(1)[0]=='[';
        bool is_mem3 = p3.at(1)[0]=='t' || p3.at(1)[0]=='[';
        bool is_mem4 = p4.at(1)[0]=='t' || p4.at(1)[0]=='[';
        if((!is_mem1 || !is_mem4)){
            code.at(i)="; PEEP --> " + code.at(i);
            code.at(i+3) = "; PEEP --> " + code.at(i+3);
            if(p1.at(1)!=p4.at(1))
            code.insert(code.begin()+i+4, "MOV " + p4.at(1) +", " + p1.at(1));
        }
        if((!is_mem2 || !is_mem3)){
            code.at(i+1)="; PEEP --> " + code.at(i+1);
            code.at(i+2) = "; PEEP --> " + code.at(i+2);
            if(p2.at(1)!=p3.at(1))
            code.insert(code.begin()+i+4, "MOV " + p3.at(1) +", " + p2.at(1));
        }
    }
    for(const auto &s: code) {
        if(s[0]==';') continue;
        fout << s << endl;
    }
    fout.close();
    fin.close();
}
void six_window_pass(){
    for(int i=0;i<code.size()-5;i++){
        string c1=code.at(i);  //PUSH 1
        string c2 =code.at(i + 1); // PUSH 2
        string c3=code.at(i + 2); // POP AX
        string c4=code.at(i + 3); // POP BX
        string c5=code.at(i + 4); // CWD
        string c6=code.at(i + 5); // MUL BX

        vector<string> p6=split(c6, ' ');
        if(p6.at(0)=="NOP") continue;
        vector<string> p5=split(c5, ' '); // CWD
        if(p5.at(0)!="CWD") continue;
        vector<string> p1=split(c1, ' ');
        vector<string> p2=split(c2, ' ');
        if(p1.at(1)!="2" && p2.at(1)!="2") continue;
        vector<string> p3=split(c3, ' ');
        vector<string> p4=split(c4, ' ');
        // comment out PUSH 2
        if(p1.at(1)=="2"){
            code.at(i)="; PEEP MULOP --> " + code.at(i);
        }else{
            code.at(i+1)="; PEEP MULOP --> " + code.at(i+1);
        }
        // comment out POP BX
        if(p3.at(1)=="BX"){
            code.at(i+2)="; PEEP --> " + code.at(i+2);
        }else{
            code.at(i+3)="; PEEP --> " + code.at(i+3);
        }
        // AX now contains number other than 2
        code.at(i+4)="; PEEP --> " + code.at(i+4);
        code.at(i+5)="; PEEP --> " + code.at(i+5);
        if(p6.at(0) =="IMUL"){
            code.insert(code.begin()+i+6, "SAL AX, 1");
        }else{
            code.insert(code.begin()+i+6, "SAR AX, 1");
        }
    }
    for(const auto &s: code) fout << s <<endl;
    fout.close();
    fin.close();
}
    

int main(){
    peep_optimize();
}