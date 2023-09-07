# Function to generate cohorts
function cohort_generation(df::DataFrame, customerID::Symbol, transactionDate::Symbol, revenueItem::Symbol)::DataFrame
    
    new_names = Dict(
        customerID=>"customerID",
        transactionDate=>"transDate",
        revenueItem=>"revenueItem"
    )
    rename!(df, new_names)
    
    df = select(df, ["customerID", "transDate", "revenueItem"])
    
    # Convert 'transDate' column to datetime objects and extract year
    try
        df[!, "Date"] = Dates.year.(Dates.DateTime.(df[:, "transDate"], "mm/dd/yy"))
    catch
        df[!, "Date"] = Dates.year.(Dates.DateTime.(df[:, "transDate"], "mm/dd/yyyy"))
    end
    
    # Check if the first year is less than 999 and if so add 2000 to all years
    if minimum(df[:, "Date"]) < 999
        df[!, "Date"] .+= 2000
    end

    grouped = groupby(df, "customerID")
    cohorts = combine(grouped, :Date => minimum => :Cohort)

    df = leftjoin(df, cohorts, on=:customerID)
    df[!, "Cohort_Index"] = df[:, "Date"] .- df[:, "Cohort"]

    return df
end

function cohort_grouping(df::DataFrame, method::Function, values::Symbol=:revenueItem)::DataFrame
    grouped_df = groupby(df, ["Cohort", "Cohort_Index"])
    totaled_df = sort(combine(grouped_df, values => method => values), [:Cohort])

    return unstack(totaled_df, :Cohort, :Cohort_Index, values)
end

# Average Order Value
function aov_cohort_generation(sum_cohort::DataFrame, count_cohort::DataFrame)::DataFrame
    new_cohort = sum_cohort[:, 2:end] ./ count_cohort[:, 2:end] 
    new_cohort = hcat(sum_cohort[:, 1], new_cohort)
    rename!(new_cohort, :x1 => :Cohort)
    return new_cohort
end

function ltv_cohort_generation(df::DataFrame, sum_cohort::DataFrame)::DataFrame
    count_people_cohort = cohort_grouping(df, float ∘ length ∘ unique, :customerID)
    count_people_cohort[:, 2:end] .= count_people_cohort[:, 2]

    # Calculate Average Order Value (AOV) using aov_cohort_generation function
    ltv_cohort = aov_cohort_generation(sum_cohort, count_people_cohort)

    # Return the ltv_cohort DataFrame
    return ltv_cohort
end

function baseline_cohort(df::DataFrame)::DataFrame
    normalized_df = copy(df)
    denominator = normalized_df[:, 2]
    normalized_df[:, 2:end] .= 100e0 .* normalized_df[:, 2:end] ./ denominator
    return normalized_df
end

function generate_base_cohorts(year_sum_cohort::DataFrame, year_count_cohort::DataFrame)::Tuple{DataFrame, DataFrame}
    base_year_sum_cohort = baseline_cohort(year_sum_cohort)
    base_year_count_cohort = baseline_cohort(year_count_cohort)
    return base_year_sum_cohort, base_year_count_cohort
end

function cohort_diagonals(cohort::DataFrame)
    a = reverse(Matrix(cohort[:, 2:end]), dims=2)
    b = reverse([(LinearAlgebra.diag(a, i)) for i in 0:minimum(size(a))-1])
    
    # Find the maximum length of the diagonals
    max_len = maximum(length(diag) for diag in b)

    # Pad each diagonal to the maximum length with `missing`
    b_padded = [vcat(diag, fill(missing, max_len - length(diag))) for diag in b]

    df = DataFrame(mapreduce(permutedims, vcat, b_padded), :auto)

    # Shift each column
    # for i = 2:ncol(df)  # Start from second column and end before the last one
    #     df[!, i] = [df[i:end, i]; Vector{Missing}(undef, i-1)]
    # end

    df[!, :Year] = reverse(cohort[!, :Cohort])

    return(df)
end