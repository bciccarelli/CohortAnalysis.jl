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
    file_name = haskey(parsed_args, "file") ? parsed_args["file"] : "data/Cohort Data.csv"
    if file_name === nothing
        file_name = "data/Cohort Data.csv"
    end
    
    output_id = haskey(parsed_args, "id") ? parsed_args["id"] : "NO_ID"
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

    aov_cohort = aov_cohort_generation(year_sum_cohort, year_count_cohort)
    ltv_cohort = ltv_cohort_generation(cohorts, year_sum_cohort)

    base_year_sum_cohort, base_year_count_cohort = generate_base_cohorts(year_sum_cohort, year_count_cohort)

    heatmaps = [year_sum_cohort, base_year_sum_cohort, year_count_cohort, base_year_count_cohort, aov_cohort, ltv_cohort]
    
    charts = []
    for heatmap in heatmaps
        # round heatmap values to 4 decimal places
        heatmap = round.(heatmap, digits=4)
        
        xvalues = names(heatmap[:,Not(1)])
        yvalues = heatmap[:, 1]
        zvalues = heatmap[:,Not(1)]
        transposed_df = permutedims(zvalues)
        zvalues = [[ismissing(cell) ? nothing : cell for cell in row] for row in eachrow(transposed_df)]
        
        push!(charts, build_chart_json("title", xvalues, yvalues, zvalues))
    end


    sections = [build_section_json("Heatmaps", charts)]

    complete_json = build_complete_json(true, sections) |> JSON.json

    println(complete_json)

    isdir("files") || mkdir("files")

    XLSX.openxlsx("files/$(output_id).xlsx", mode="w") do xf
        for (i, df) in enumerate(heatmaps)
            title = "Sample_" * string(i)
            sheet = i == 1 ? xf[i] : XLSX.addsheet!(xf, title)
            XLSX.rename!(sheet, title)
            XLSX.writetable!(sheet, df)
        end
    end

    heatmaps_csv = vcat([vcat(df, DataFrame()) for df in heatmaps]...)
    CSV.write("files/$(output_id).csv", heatmaps_csv)

    return 0
end

end