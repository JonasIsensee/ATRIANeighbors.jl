"""
cli.jl

Command-line interface for profile analysis.
"""

const DEFAULT_PROFILE_FILE = "profile_data.json"

"""
    parse_args(args::Vector{String})

Parse command line arguments.
"""
function parse_args(args::Vector{String})
    if isempty(args)
        return Dict("command" => "help")
    end

    result = Dict{String,Any}("command" => args[1])

    i = 2
    while i <= length(args)
        arg = args[i]
        if startswith(arg, "--")
            key = arg[3:end]
            if i < length(args) && !startswith(args[i+1], "--")
                result[key] = args[i+1]
                i += 2
            else
                result[key] = true
                i += 1
            end
        else
            if !haskey(result, "positional")
                result["positional"] = []
            end
            push!(result["positional"], arg)
            i += 1
        end
    end

    return result
end

"""
    show_help()

Display help message.
"""
function show_help()
    println("""
ProfilingAnalysis.jl - Generic Profile Analysis Tool
=====================================================

COMMANDS:

  query [options]
      Query profile data
      Options:
        --input FILE         Input file (default: profile_data.json)
        --top N              Show top N entries (default: 20)
        --file PATTERN       Filter by file pattern
        --function PATTERN   Filter by function pattern
        --pattern PATTERN    Filter by any pattern (file or function)
        --no-system          Filter out system code (default: true)

  summary [options]
      Generate comprehensive summary
      Options:
        --input FILE       Input file (default: profile_data.json)
        --top N            Number of entries to show (default: 20)
        --title TITLE      Custom title for summary

  compare FILE1 FILE2 [options]
      Compare two profile datasets
      Options:
        --top N          Show top N changes (default: 20)

  help
      Show this help message

EXAMPLES:

  # Query top 10 hotspots
  julia -m ProfilingAnalysis query --input profile.json --top 10

  # Find all functions matching pattern
  julia -m ProfilingAnalysis query --input profile.json --pattern distance

  # Generate summary
  julia -m ProfilingAnalysis summary --input profile.json

  # Compare two profiles
  julia -m ProfilingAnalysis compare old.json new.json

PROGRAMMATIC USAGE:

  This package can also be used programmatically in your Julia code:

  ```julia
  using ProfilingAnalysis

  # Collect profile data
  profile = collect_profile_data() do
      # Your workload here
      my_function()
  end

  # Save profile
  save_profile(profile, "myprofile.json")

  # Query profile
  top_10 = query_top_n(profile, 10, filter_fn=e -> !is_system_code(e))

  # Summarize
  summarize_profile(profile)
  ```
""")
end

"""
    run_cli(args::Vector{String})

Main CLI entry point.
"""
function run_cli(args::Vector{String})
    parsed = parse_args(args)
    command = parsed["command"]

    if command == "help"
        show_help()
        return
    end

    if command == "query"
        input = get(parsed, "input", DEFAULT_PROFILE_FILE)

        if !isfile(input)
            println("Error: Profile file not found: $input")
            println("Please provide a valid profile file with --input option.")
            return
        end

        profile = load_profile(input)

        # Apply filters
        entries = if haskey(parsed, "file")
            query_by_file(profile, parsed["file"])
        elseif haskey(parsed, "function")
            query_by_function(profile, parsed["function"])
        elseif haskey(parsed, "pattern")
            query_by_pattern(profile, parsed["pattern"])
        else
            filter_system = get(parsed, "no-system", "true") == "true"
            top_n = parse(Int, get(parsed, "top", "20"))
            filter_fn = filter_system ? (e -> !is_system_code(e)) : nothing
            query_top_n(profile, top_n, filter_fn=filter_fn)
        end

        if haskey(parsed, "top")
            top_n = parse(Int, parsed["top"])
            entries = entries[1:min(top_n, length(entries))]
        end

        print_entry_table(entries)

    elseif command == "summary"
        input = get(parsed, "input", DEFAULT_PROFILE_FILE)

        if !isfile(input)
            println("Error: Profile file not found: $input")
            println("Please provide a valid profile file with --input option.")
            return
        end

        profile = load_profile(input)
        top_n = parse(Int, get(parsed, "top", "20"))
        title = get(parsed, "title", "Profile Summary")

        summarize_profile(profile, top_n=top_n, title=title)

    elseif command == "compare"
        positional = get(parsed, "positional", [])
        if length(positional) < 2
            println("Error: compare requires two profile files")
            println("Usage: compare FILE1 FILE2")
            return
        end

        file1, file2 = positional[1:2]

        if !isfile(file1) || !isfile(file2)
            println("Error: One or both profile files not found")
            return
        end

        profile1 = load_profile(file1)
        profile2 = load_profile(file2)
        top_n = parse(Int, get(parsed, "top", "20"))

        compare_profiles(profile1, profile2, top_n=top_n)

    else
        println("Unknown command: $command")
        println("Run 'help' for usage information")
    end
end
