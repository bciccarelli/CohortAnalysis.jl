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