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