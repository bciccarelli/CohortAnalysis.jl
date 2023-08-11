# Function to generate cohorts
function cohort_generation(df::DataFrame)::DataFrame
    # Extract the year from the datetime objects
    df[!, "CustomerID"] = map(hash, df[:, "Unique Customer Number"])
    df = select(df, ["CustomerID", "Order Date", "total"])
    
    # Convert 'Order Date' column to datetime objects and extract year
    df[!, "Date"] = Dates.year.(Dates.DateTime.(df[:, "Order Date"], "mm/dd/yy"))
    
    # Check if the first year is less than 999 and if so add 2000 to all years
    if minimum(df[:, "Date"]) < 999
        df[!, "Date"] .+= 2000
    end

    grouped = groupby(df, "CustomerID")
    cohorts = combine(grouped, :Date => minimum => :Cohort)

    df = leftjoin(df, cohorts, on=:CustomerID)
    df[!, "Cohort_Index"] = df[:, "Date"] .- df[:, "Cohort"]

    return df
end

function cohort_grouping(df::DataFrame, method::Function, values::Symbol=:total)::DataFrame
    grouped_df = groupby(df, ["Cohort", "Cohort_Index"])
    totaled_df = sort(combine(grouped_df, values => method => values), [:Cohort])
    return unstack(totaled_df, :Cohort, :Cohort_Index, values)
end

# Average Order Value
function aov_cohort_generation(sum_cohort::DataFrame, count_cohort::DataFrame)::DataFrame
    new_cohort = sum_cohort[:, Not(1)] ./ count_cohort[:, Not(1)] 
    new_cohort = hcat(sum_cohort[:, 1], new_cohort)
    rename!(new_cohort, :x1 => :Cohort)
    return new_cohort
end

function ltv_cohort_generation(df::DataFrame, sum_cohort::DataFrame)::DataFrame
    count_people_cohort = cohort_grouping(df, length ∘ unique, :CustomerID)
    count_people_cohort[:, 2:end] .= count_people_cohort[:, 2]

    # Calculate Average Order Value (AOV) using aov_cohort_generation function
    ltv_cohort = aov_cohort_generation(sum_cohort, count_people_cohort)

    # Return the ltv_cohort DataFrame
    return ltv_cohort
end

function baseline_cohort(df::DataFrame)::DataFrame
    normalized_df = copy(df)
    for i in 2:ncol(normalized_df)
        normalized_df[:, i] .= 100 .* normalized_df[:, i] ./ normalized_df[:, 2]
    end
    return normalized_df
end

function generate_base_cohorts(year_sum_cohort::DataFrame, year_count_cohort::DataFrame)::Tuple{DataFrame, DataFrame}
    base_year_sum_cohort = baseline_cohort(year_sum_cohort)
    base_year_count_cohort = baseline_cohort(year_count_cohort)
    return base_year_sum_cohort, base_year_count_cohort
end
