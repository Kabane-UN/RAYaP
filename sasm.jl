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
                    if term[2:end] ∈ keys(check_def) && length( check_def[term[2:end]]) > 0
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
                elseif (term ∈ keys(pre_code) && term ≠ "PROGRAM_SIZE")
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