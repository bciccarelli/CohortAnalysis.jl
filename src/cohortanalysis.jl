module CohortAnalysis

using CSV
using DataFrames
using ArgParse
using JSON
using XLSX
using FileIO
using Dates

include("./cohorts.jl")
include("./chartjson.jl")

function julia_main()::Cint
    s = ArgParseSettings()

    @add_arg_table s begin
        "--file"
        help = "file to read"
        "--id"
        help = "id of output files"
    end

    parsed_args = parse_args(s)

    if haskey(parsed_args, "file")
        file_name = parsed_args["file"]
    end
    if file_name === nothing
        file_name = "data/Cohort Data.csv"
    end

    if haskey(parsed_args, "id")
        output_id = parsed_args["id"]
    end
    if output_id === nothing
        output_id = "NO_ID"
    end

    raw = try
        CSV.read(file_name, DataFrame)
    catch e
        rethrow(e)
        return 1
    end

    cohorts = cohort_generation(raw)

    year_sum_cohort = cohort_grouping(cohorts, sum)
    year_count_cohort = cohort_grouping(cohorts, length)
   
    # datatable = build_table(raw)
    aov_cohort = aov_cohort_generation(copy(year_sum_cohort), year_count_cohort)
    ltv_cohort = ltv_cohort_generation(cohorts, year_sum_cohort)
    
    base_year_sum_cohort = baseline_cohort(year_sum_cohort)
    base_year_count_cohort = baseline_cohort(year_count_cohort)

    heatmaps = [year_sum_cohort, base_year_sum_cohort, year_count_cohort, base_year_count_cohort, aov_cohort, ltv_cohort]

    charts = []
    for heatmap in heatmaps
        # round heatmap values to 4 decimal places
        heatmap = round.(heatmap, digits=4)
        
        xvalues = names(heatmap[:,Not(1)])
        yvalues = heatmap[:, 1]
        zvalues = heatmap[:,Not(1)]
        transposed_df = permutedims(zvalues)
        converted_array = [[ismissing(cell) ? nothing : cell for cell in row] for row in eachrow(transposed_df)]
        zvalues = JSON.json(converted_array)
        
        push!(charts, build_chart_json("title", xvalues, yvalues, zvalues))
    end

    sections = []
    section = build_section_json("Heatmaps", charts)

    push!(sections, section)

    complete_json = build_complete_json(true, sections)

    # convert complete_json to string with JSON module
    complete_json = JSON.json(complete_json)

    println(string(complete_json))

    # check if files directory exists

    if !isdir("files")
        mkdir("files")
    end

    XLSX.openxlsx("files/$(output_id).xlsx", mode="w") do xf
        i = 0
        for df in heatmaps
            i = i + 1
            title = "Sample_" * string(i)
            if i == 1
                sheet = xf[i]
                XLSX.rename!(sheet, title)
            else
                sheet = XLSX.addsheet!(xf, title)
            end
            XLSX.writetable!(sheet, df)
        end
    end

    heatmaps_csv = [vcat(df, DataFrame()) for df in heatmaps]
    CSV.write("files/$(output_id).csv", vcat(heatmaps_csv...))
    return 0
end

end