% Лабораторная работа № 1 «Стековая виртуальная машина»
% 4 марта 2024 г.
% Андрей Кабанов, ИУ9-62Б

# Цель работы
Целью данной работы является написание интерпретатора ассемблера модельного компьютера, 
который будет использоваться в последующих лабораторных как целевой язык.

# Индивидуальный вариант
Нужно написать на модельном ассемблере программу и запустить её.

Программа считывает с устройства ввода десятичное число и распечатывает на стандартное 
устройство вывода его факториал.

# Реализация

Модуль `Files`
```julia
module Files
    function read_from_file(file)
        lines = []
        open(file, "r") do f
            for i in readlines(f)
                push!(lines, i)
            end
        end
        return lines
    end
    function write_to_file(file, str)
        open(file, "w") do f
            print(f, str)
        end
    end
end
```

Модуль `Indents`
```julia
module Indents
    id_code = Dict(
        "ADD"=> -1,
        "SUB"=> -2,
        "MUL"=> -3,
        "DIV"=> -4,
        "MOD"=> -5,
        "NEG"=> -6,
        "BITAND"=> -7,
        "BITOR"=> -8,
        "BITNOT"=> -9,
        "LSHIFT"=> -10,
        "RSHIFT"=> -11,
        "DUP"=> -12,
        "DROP"=> -13,
        "SWAP"=> -14,
        "ROT"=> -15,
        "OVER"=> -16,
        "DROPN"=> -17,
        "PUSHN"=> -18,
        "LOAD"=> -19,
        "SAVE"=> -20,
        "GETIP"=> -21,
        "SETIP"=> -22,
        "GETSP"=> -23,
        "SETSP"=> -24,
        "GETFP"=> -25,
        "SETFP"=> -26,
        "GETRV"=> -27,
        "SETRV"=> -28,
        "CMP"=> -29,
        "JMP"=> -22,
        "JLT"=> -30,
        "JGT"=> -31,
        "JEQ"=> -32,
        "JLE"=> -33,
        "JGE"=> -34,
        "JNE"=> -35,
        "CALL"=> -36,
        "RETN"=> -37,
        "IN"=> -38,
        "OUT"=> -39,
        "HALT"=> -40,
    )
end
```
Основная программа
```julia
include("files.jl")
include("idents.jl")

using .Files: read_from_file, write_to_file
using .Indents: id_code
function parse_sasm(lines)
    code = []
    for line ∈ lines
        sublines = split(line, " ")
        for subline ∈ sublines
            terms = split(subline, "\t")
            for term in terms
                if term != "" && term != ";"
                    push!(code, term)
                elseif term == ";"
                    @goto endline
                end
            end
        end
        @label endline
    end
    return code
end
function first_pass(code)
    current = 256
    pre_code = Dict{String, Any}("PROGRAM_SIZE" => C_NULL)
    check_def = Dict("PROGRAM_SIZE" => [])
    machine_code = []
    for term ∈ code
        if tryparse(Int, term) !== nothing
            push!(machine_code, parse(Int, term))
            current+=1
        else
            if length(term) > 1 && term[1] == ':'
                if term[2:end] ∈ keys(pre_code)
                    println("Syntax Error")
                    exit(0)
                else
                    pre_code[term[2:end]] = current
                    if ( term[2:end] ∈ keys(check_def) &&
                         length( check_def[term[2:end]]) > 0)
                        for i ∈ check_def[term[2:end]]
                            machine_code[i] = current
                        end
                        check_def[term[2:end]] = []
                    end
                end
            else
                if term ∈ keys(id_code) 
                    push!(machine_code, id_code[term])
                    current+=1
                elseif (term ∈ keys(pre_code) &&
                     term ≠ "PROGRAM_SIZE")
                    push!(machine_code, pre_code[term])
                    current+=1
                else
                    if term ∈ keys(check_def)
                        push!(check_def[term], current-255)
                    else
                        check_def[term] = [current-255]
                    end
                    push!(machine_code, 0)
                    current+=1
                end
            end
        end
    end
    pre_code["PROGRAM_SIZE"] = current
    for i ∈ check_def["PROGRAM_SIZE"]
        machine_code[i] = current
    end
    check_def["PROGRAM_SIZE"] = []
    if !allequal(values(check_def))
        println("Syntax Error")
        exit(0)
    end
    return machine_code
end
function run_sasm(instructions, MEM_SIZE)
    M = Array{BigInt}([0 for _ ∈ 1:MEM_SIZE])
    current = 256
    for instruction ∈ instructions
        M[current] = instruction
        current+=1
    end
    PROGRAM_SIZE = current
    SP = MEM_SIZE+1
    IP = 256
    FP = 0
    RV = 0
    while IP != PROGRAM_SIZE
        if M[IP] > -1
            SP-=1
            M[SP] = M[IP]
            IP+=1
        elseif M[IP] == -1
            M[SP+1] += M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -2
            M[SP+1] -= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -3
            M[SP+1] *= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -4
            M[SP+1] ÷= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -5
            M[SP+1] %= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -6
            M[SP] = -M[SP]
            IP+=1
        elseif M[IP] == -7
            M[SP+1] &= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -8
            M[SP+1] |= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -9
            M[SP] = ~M[SP]
            IP+=1
        elseif M[IP] == -10
            M[SP+1] <<= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -11
            M[SP+1] >>= M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -12
            M[SP-1] = M[SP]
            SP-=1
            IP+=1
        elseif M[IP] == -13
            SP+=1
            IP+=1
        elseif M[IP] == -14
            M[SP+1], M[SP] = M[SP], M[SP+1]
            IP+=1
        elseif M[IP] == -15
            M[SP+2], M[SP+1], M[SP] = M[SP+1], M[SP], M[SP+2]
            IP+=1
        elseif M[IP] == -16
            M[SP-1] = M[SP+1]
            SP-=1
            IP+=1
        elseif M[IP] == -17
            SP+=M[SP]+1
            IP+=1
        elseif M[IP] == -18
            SP-=M[SP]-1
            IP+=1
        elseif M[IP] == -19
            M[SP] = M[M[SP]]
            IP+=1
        elseif M[IP] == -20
            M[M[SP+1]] = M[SP]
            SP += 2
            IP+=1
        elseif M[IP] == -21
            M[SP-1] = IP+1
            SP-=1
            IP+=1
        elseif M[IP] == -22
            IP = M[SP]-1
            SP+=1
            IP+=1
        elseif M[IP] == -23
            M[SP-1] = SP
            SP-=1
            IP+=1
        elseif M[IP] == -24
            SP = M[SP]
            IP+=1
        elseif M[IP] == -25
            M[SP-1] = FP
            SP-=1
            IP+=1
        elseif M[IP] == -26
            FP = M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -27
            M[SP-1] = RV
            SP-=1
            IP+=1
        elseif M[IP] == -28
            RV = M[SP]
            SP+=1
            IP+=1
        elseif M[IP] == -29
            if M[SP+1] < M[SP]
                M[SP+1] = -1
            elseif M[SP+1] == M[SP]
                M[SP+1] = 0
            else
                M[SP+1] = 1
            end
            SP+=1
            IP+=1
        elseif M[IP] == -30
            IP = M[SP+1] < 0 ? M[SP] : IP + 1
            SP+=2
        elseif M[IP] == -31
            IP = M[SP+1] > 0 ? M[SP] : IP + 1
            SP+=2
        elseif M[IP] == -32
            IP = M[SP+1] == 0 ? M[SP] : IP + 1
            SP+=2
        elseif M[IP] == -33
            IP = M[SP+1] ≤ 0 ? M[SP] : IP + 1
            SP+=2
        elseif M[IP] == -34
            IP = M[SP+1] ≥ 0 ? M[SP] : IP + 1
            SP+=2
        elseif M[IP] == -35
            IP = M[SP+1] ≠ 0 ? M[SP] : IP + 1
            SP+=2
        elseif M[IP] == -36
            g = IP + 1
            IP = M[SP]
            M[SP] = g
        elseif M[IP] == -37
            IP = M[SP+1]
            SP+=M[SP]+2
        elseif M[IP] == -38
            M[SP-1] = Int(read(stdin, Char))
            SP-=1
            IP+=1
        elseif M[IP] == -39
            print(stdout, Char(M[SP]))
            SP+=1
            IP+=1
        elseif M[IP] == -40
            exit(M[SP])
            SP+=1
            IP+=1
        end
        if IP < 256
            println("Bus error")
            exit()
        end
    end
end

begin
    if ARGS[1] == "-c"
        code = parse_sasm(read_from_file(ARGS[2]))
        machine_code = first_pass(code)
        res_str = ""
        for code_cell ∈ machine_code
            global res_str
            res_str *= string(code_cell)
            res_str *= " "
        end
        res_str = res_str[begin:end-1]
        write_to_file(splitext(ARGS[2])[1], res_str)
    else
        if splitext(ARGS[1])[2] == ".sasm"
            code = parse_sasm(read_from_file(ARGS[1]))
            machine_code = first_pass(code)
            run_sasm(machine_code, parse(Int, ARGS[2]))
        elseif splitext(ARGS[1])[2] == ""
            line = read_from_file(ARGS[1])[1]
            instructions = split(line, " ")
            machine_code = []
            for instruction ∈ instructions
                push!(machine_code, parse(Int, instruction))
            end
            run_sasm(machine_code, parse(Int, ARGS[2]))
        end
    end
    
end
```

# Тестирование

Программа на ассемблере
```
main CALL 0 HALT
:end
DROP 1
pend JMP

:main
10 read_int JMP :ret DROP DUP end JEQ DUP 1 SUB end JEQ
1 SWAP 1 factorial CALL ; factorial
; call (res, number, counter)
:pend
0 SETFP write_int JMP :ret2 ; write_int call (number)
0 RETN ; return 

:read_int ; read number loop
IN DUP ; ... -> char char
10 SUB read_end JEQ ; if char \n -> char goto: read_end
48 SUB DUP 10 SUB read_int JLT ; if number ->
; number goto: read_int
0 HALT ; return if NaN

:read_end ; sum numbers while not oef
DROP ; ... \n -> ...
10 SETFP ; FP = 10
:loop1
SWAP ; num1 num2 -> num2 num1
DUP 10 SUB ret JEQ ; if eof -> return
GETFP MUL ; num -> num*10^n
GETFP 10 MUL SETFP ADD loop1 JMP  ; n++, sum num ->
; sum+num, goto next

:factorial ; res num counter ip
ROT ROT ;  -> ip num counter
1 ADD SETFP ; ip nun counter -> ip nun, FP = ++counter
DUP GETFP CMP rec JNE ; ip num -> ip num, goto
; rec if new_counter < num
ROT ; res ip num -> ip num res
GETFP MUL ; ip num res -> ip num res*(new_counter)
SWAP DROP ; -> ip new_res
SWAP 0 RETN ; -> new_res ip

:rec
ROT ; res ip num -> ip num res
GETFP MUL ; ip num res -> ip num res*(new_counter)
SWAP GETFP ; ip num new_res -> ip new_res
;  num new_counter
factorial CALL ; -> ip new_res
;  num new_counter newip, CALL RECUR
; -> ip new_res
SWAP ; -> new_res ip
0 RETN ; -> new_res

:write_int
GETFP 1 ADD SETFP ; SETFP++
DUP 10 MOD ; num -> num num[end]
DUP ROT SWAP ; num num[end] -> num[end] num[end] num
;  ->  num[end] num num[end]
SUB 10 DIV DUP print JEQ ; -> num[end] num[0:end], 
; goto loop if num[0:end] != 0 else goto print
write_int JMP 
:print
DROP ; num[last] or 0 -> ...
DUP 48 ADD OUT GETFP 1 SUB DUP SETFP print JNE ; num[i] -> 
; num[i] num[i]+48>>cout -> num[i],
; goto loop if --SETFP != 0 else return
10 OUT DROP ret2 JMP

```

Вывод на `stdout`

```
10
3628800
```

# Вывод
При выполнении лабораторной лабораторной работы были приобретены навыки написания виртуальной 
стековой машины, а также интерпретатора модельного ассемблера. Был изучен синтаксис 
реализованного ассемблера. А также была написана простая программа на изученном ассемблере.