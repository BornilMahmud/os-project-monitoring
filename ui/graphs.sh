#!/usr/bin/env bash
# ui/graphs.sh - Live ASCII, Unicode block, and Braille terminal graph renderers for SMD-TUI

# Render a horizontal gauge/progress bar
# Example: render_gauge_bar 60 20 "blocks" -> "[████████████░░░░░░░░] 60%"
render_gauge_bar() {
    local percent="${1:-0}"
    local width="${2:-20}"
    local style="${3:-blocks}"

    percent=$(clamp "$percent" 0 100)

    local filled=$(( (percent * width) / 100 ))
    local empty=$(( width - filled ))

    local bar=""
    if [[ "$style" == "ascii" ]]; then
        local f_str=""
        local e_str=""
        for ((i=0; i<filled; i++)); do f_str="${f_str}="; done
        for ((i=0; i<empty; i++)); do e_str="${e_str}-"; done
        bar="[${f_str}${e_str}] ${percent}%"
    else
        local f_str=""
        local e_str=""
        for ((i=0; i<filled; i++)); do f_str="${f_str}█"; done
        for ((i=0; i<empty; i++)); do e_str="${e_str}░"; done
        bar="[${f_str}${e_str}] ${percent}%"
    fi

    echo "$bar"
}

# Render a single-line sparkline from a series of values (0-100)
# Example: render_sparkline "blocks" 10 30 70 90
render_sparkline() {
    local style="${1:-blocks}"
    shift
    local values=("$@")

    if [[ ${#values[@]} -eq 0 ]]; then
        echo ""
        return 0
    fi

    local spark=""
    local block_glyphs=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")
    local ascii_glyphs=("_" "." "-" "*" "#")

    for v in "${values[@]}"; do
        v=$(clamp "$v" 0 100)
        if [[ "$style" == "ascii" ]]; then
            # 5 bins: 0-19, 20-39, 40-59, 60-79, 80-100
            local idx=$(( v * 4 / 100 ))
            if [[ $idx -ge 5 ]]; then idx=4; fi
            spark="${spark}${ascii_glyphs[$idx]}"
        else
            # 8 bins: 0-7
            local idx=$(( v * 7 / 100 ))
            if [[ $idx -ge 8 ]]; then idx=7; fi
            spark="${spark}${block_glyphs[$idx]}"
        fi
    done

    echo "$spark"
}

# Render a multi-line ASCII/Unicode trend chart (similar to Task Manager)
# Arguments: height width max_value metric_name values...
render_trend_chart() {
    local height="${1:-6}"
    local width="${2:-50}"
    local max_val="${3:-100}"
    local label="${4:-History}"
    shift 4
    local values=("$@")

    if [[ $max_val -le 0 ]]; then max_val=100; fi

    # Take the latest $width points
    local start_idx=0
    if [[ ${#values[@]} -gt $width ]]; then
        start_idx=$(( ${#values[@]} - width ))
        values=("${values[@]:$start_idx}")
    fi

    echo "  ┌─ ${label} (Max: ${max_val}) ───────────────────────────────────┐"

    for ((row=height; row>=1; row--)); do
        local row_thresh=$(( (row * max_val) / height ))
        local row_prev_thresh=$(( ((row - 1) * max_val) / height ))
        local line_str=""

        for ((col=0; col<width; col++)); do
            local val="${values[$col]:-0}"
            if [[ $val -ge $row_thresh ]]; then
                line_str="${line_str}█"
            elif [[ $val -gt $row_prev_thresh ]]; then
                line_str="${line_str}▄"
            else
                line_str="${line_str} "
            fi
        done

        printf "  │%3d%% │%s│\n" "$row_thresh" "$line_str"
    done

    local bot_border=""
    for ((col=0; col<width; col++)); do bot_border="${bot_border}─"; done
    echo "  └───┴─${bot_border}┘"
}
