# Function to generate cohorts
function cohort_generation(df)
    # Extract the year from the datetime objects
    df[!, "CustomerID"] = map(hash, df[:, "Unique Customer Number"])
    df = df[:, ["CustomerID", "Order Date", "total"]]
    
    #rename order date to date
    df = rename(df, "Order Date" => :Date)

    # Convert 'Order Date' column to datetime objects
    df[!, "Date"] = Dates.DateTime.(df[:, "Date"], "mm/dd/yy")

    # Extract the year from the datetime objects
    df[!, "Date"] = Dates.year.(df[:, "Date"])

    #check if first year is less than 999 and if so add 2000 to all years
    if minimum(df[:, "Date"]) < 999
        df[!, "Date"] = df[:, "Date"] .+ 2000
    end


    grouped = groupby(df, "CustomerID")

    cohorts = combine(grouped, "Date" => minimum)
    df = leftjoin(df, cohorts, on = :CustomerID)

    #rename Order Date_minimum to cohort
    df = rename(df, "Date_minimum" => :Cohort)

    # Create a new column called Cohort Index, which is the number of years between the cohort and the order date
    df[!, "Cohort_Index"] = (df[:, "Date"] .- df[:, "Cohort"])

    return df
end

# Function to group cohorts
function cohort_grouping(df, method, values="total")
    df = copy(df::DataFrame)

    grouped_df = groupby(df, ["Cohort", "Cohort_Index"])

    totaled_df = sort(combine(grouped_df, Symbol(values) => method => Symbol(values)), [:Cohort])

    unstacked = unstack(totaled_df, :Cohort, :Cohort_Index, Symbol(values))
   
    return unstacked
end

# Average Order Value
function aov_cohort_generation(sum_cohort, count_cohort)
    sum_cohort[:,Not(1)] ./= count_cohort[:,Not(1)] 
    return sum_cohort
end

function ltv_cohort_generation(df, sum_cohort, method="sum")
    sum_cohort = copy(sum_cohort)
    
    # CHANGE THIS TO NUMBER OF PEOPLE NOT NUMBER OF ORDERS
    count_people_cohort = cohort_grouping(df, length ∘ unique, "CustomerID")
    i = 0
    for column in eachcol(count_people_cohort)
        if i == 0
            i = i + 1
            continue
        end
        column[:] = count_people_cohort[:,2]
    end
    
    # Calculate Average Order Value (AOV) using aov_cohort_generation function
    ltv_cohort = aov_cohort_generation(sum_cohort, count_people_cohort)

    # Return the ltv_cohort DataFrame
    return ltv_cohort
end

function baseline_cohort(df)

    normalized_df = copy(df)

    i = 0
    for column in eachcol(normalized_df)
        if i == 0
            i = i + 1
            continue
        end
        column = 100*column/normalized_df[:,2]
    end

    return normalized_df
end
