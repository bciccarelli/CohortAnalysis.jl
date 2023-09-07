module CohortAnalysis

using CSV
using DataFrames
using ArgParse
using JSON
using XLSX
using FileIO
using Dates
using LinearAlgebra
using Printf

include("./cohorts.jl")
include("./chartjson.jl")

function julia_main()::Cint
    s = ArgParseSettings()

    @add_arg_table s begin
        "--file"
        help = "file to read"
        "--id"
        help = "id of output files"
        "--customerID"
        help = "customerID column of input file"
        "--transactionDate"
        help = "transactionDate column of input file"
        "--revenueItem"
        help = "revenue column of input file"
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

    customerID = haskey(parsed_args, "customerID") ? parsed_args["customerID"] : "data/Cohort Data.csv"
    if customerID === nothing
        customerID = "Unique Customer Number"
    end
    transactionDate = haskey(parsed_args, "transactionDate") ? parsed_args["transactionDate"] : "NO_ID"
    if transactionDate === nothing
        transactionDate = "Order Date"
    end
    revenueItem = haskey(parsed_args, "revenueItem") ? parsed_args["revenueItem"] : "data/Cohort Data.csv"
    if revenueItem === nothing
        revenueItem = "total"
    end
    
    
    raw = try
        CSV.read(file_name, DataFrame)
    catch e
        rethrow(e)
        return 1
    end

    cohorts = cohort_generation(raw, Symbol(customerID), Symbol(transactionDate), Symbol(revenueItem))

    year_sum_cohort = cohort_grouping(cohorts, sum)
    year_count_cohort = cohort_grouping(cohorts, float ∘ length)

    aov_cohort = aov_cohort_generation(year_sum_cohort, year_count_cohort)
    ltv_cohort = ltv_cohort_generation(cohorts, year_sum_cohort)

    base_year_sum_cohort, base_year_count_cohort = generate_base_cohorts(year_sum_cohort, year_count_cohort)

    # print((aov_cohort; dims=2))
    
    year_sum_barchart = cohort_diagonals(year_sum_cohort)


 
    charts_df = [
        year_sum_cohort,
        base_year_sum_cohort,
        year_count_cohort,
        base_year_count_cohort,
        aov_cohort,
        ltv_cohort,
        year_sum_barchart
    ]
    
    heatmaps = [
        named_heatmap(year_sum_cohort, "Yearly Cohorts - Revenue"), 
        named_heatmap(base_year_sum_cohort, "Yearly Cohorts - Revenue, Baselined"), 
        named_heatmap(year_count_cohort, "Yearly Cohorts - Customers"), 
        named_heatmap(base_year_count_cohort, "Yearly Cohorts - Customers, Baselined"), 
        named_heatmap(aov_cohort, "Yearly Cohorts - AOV"), 
        named_heatmap(ltv_cohort, "Yearly Cohorts - LTV"),
    ]
    barcharts = [
        named_barchart(year_sum_barchart, "Yearly Cohorts - Revenue")
    ]
    
    sections = [build_section_json("Heatmaps", heatmaps), build_section_json("Barcharts", barcharts)]

    complete_json = build_complete_json(true, sections) |> JSON.json

    println(complete_json)

    isdir("files") || mkdir("files")

    XLSX.openxlsx("files/$(output_id).xlsx", mode="w") do xf
        for (i, df) in enumerate(charts_df)
            title = "Sample_" * string(i)
            sheet = i == 1 ? xf[i] : XLSX.addsheet!(xf, title)
            XLSX.rename!(sheet, title)
            XLSX.writetable!(sheet, df)
        end
    end

    charts_csv = vcat([vcat(df, DataFrame()) for df in charts_df]...; cols=:union)
    CSV.write("files/$(output_id).csv", charts_csv)

    return 0
end

end