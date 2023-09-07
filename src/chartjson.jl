function build_heatmap(title, xValues, yValues, zValues)
    return Dict(
        "layout" => Dict("title" => title),
        "data" => Dict(
            "x" => xValues,
            "y" => yValues,
            "z" => zValues,
            "type" => "heatmap"
        )
    )
end

function build_barchart(title, xValues, yValues)
    return Dict(
        "layout" => Dict(
            "title" => title,
            "barnorm" => "percent",
            "barmode" => "stack",
            "bargap" => "0.5"),
        "data" => [Dict(
            "x" => xValues,
            "y" => y,
            "type" => "bar",
            "name" => year
        ) for (year, y) in zip(reverse(xValues), yValues)]
    )
end

function build_section_json(name, charts)
    return Dict(
        "name" => name,
        "charts" => charts
    )
end

function build_complete_json(success, sections)
    return Dict(
        "success" => success,
        "sections" => sections
    )
end

function float_to_string(n::Float64)::String
    parts = split(string(n), 'e')
    if length(parts) == 1
        return parts[1]
    end
    base, exponent = parts
    exp = parse(Int, exponent)
    
    if exp > 0
        if contains(base, '.')
            base = replace(base, "." => "")
        end
        zeros_to_add = exp - (length(base) - 1)
        return base * (zeros_to_add > 0 ? "0"^zeros_to_add : "")
    else
        return "0." * "0"^(-exp - 1) * replace(base, "." => "")
    end
end

function named_heatmap(heatmap::DataFrame, title::String)
    heatmap = round.(heatmap, digits=4)
    
    xValues = names(heatmap[:,Not(1)])
    yValues = heatmap[:, 1]
    zValues = heatmap[:,Not(1)]

    zValues = [[ismissing(cell) ? nothing : float_to_string(cell) for cell in row] for row in eachrow(zValues)]

    return build_heatmap(
            title,
            xValues,
            yValues,
            zValues
        )
end

function named_barchart(barchart::DataFrame, title::String)
    barchart = round.(barchart, digits=4)
    
    xValues = barchart[!, :Year]
    
    yValues = [col for col in eachcol(barchart[:, 1:end-1])]
    
    return build_barchart(
            title,
            xValues,
            yValues
        )
end