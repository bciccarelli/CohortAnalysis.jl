function build_chart_json(title, xValues, yValues, zValues)
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
