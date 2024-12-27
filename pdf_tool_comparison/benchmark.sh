#!/bin/bash

# Input/Output directory
TOOL="$1"

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
INPUT_DIR=$(realpath "$SCRIPT_DIR/../test_data/pdf_files")
OUTPUT_DIR=$(realpath "$SCRIPT_DIR/../test_data/output")

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

echo "[$TOOL] Benchmark Summary - $(date)"
echo "Input Directory: $INPUT_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo "==================================="

# Function to run benchmark for a PDF file
run_benchmark_for_file() {
    local file=$1
    local file_name=$(basename "$file")
    echo "Processing $file_name..."

    local tool="$TOOL"
    local output_dir="$OUTPUT_DIR/$tool/$file_name"
    mkdir -p $output_dir

    printf "Sanitize"
    local san_file="$output_dir/sanitized.pdf"
    benchmark_command "$(sanitize $tool $file $san_file)"

    printf "Split pages"
    local split_dir="$output_dir/split"
    local split_files="$split_dir/page_%d.pdf"
    mkdir -p "$split_dir"
    benchmark_command "$(split $tool $file $split_files)"

    # Fetch the first file in directory to convert to png
    printf "Convert png"
    local png_dir="$output_dir/png"
    local png_tool=$tool
    mkdir -p "$png_dir"
    for file in $split_dir/*.pdf; do
        local file_name=$(basename "$file")
        local png_file="$png_dir/${file_name%.*}"
        if [[ -f $file ]]; then
            printf "  $file_name"
            benchmark_command "$(convert_png  $tool $file $png_file)"
        fi
    done

    echo "==================================="
    sleep 0.1
}

sanitize() {
    local tool="$1"
    local input_file="$2"
    local output_file="$3"
    if [[ $tool == "poppler" ]]; then
        local cmd="pdftocairo -pdf $input_file $output_file"
    elif [[ $tool == "gs" ]]; then
        local cmd="gs -dQUIET -dSAFER -dBATCH -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -o $output_file $input_file"
    elif [[ $tool == "qpdf" ]]; then
        local cmd="qpdf --empty --object-streams=generate --flatten-annotations=all --pages $input_file 1-z -- $output_file"
    fi
    echo "$cmd"
}

split() {
    local tool="$1"
    local input_file="$2"
    local output_file="$3"

    if [[ $tool == "poppler" ]]; then
        local cmd="pdfseparate $input_file $output_file"
    elif [[ $tool == "gs" ]]; then
        local cmd="gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dSAFER -sOutputFile=$output_file $input_file"
    elif [[ $tool == "qpdf" ]]; then
        local cmd="qpdf --split-pages $input_file $output_file"
    fi
    echo "$cmd"
}

convert_png() {
    local tool="$1"
    local input_file="$2"
    local output_file="$3"

    local cmd="pdftoppm -r 350 -png $input_file $output_file"
    if [[ $tool == "gs" ]]; then
        output_file="$output_file.png"
        local cmd="gs -dSAFER -dBATCH -dNOPAUSE -dNOPROMPT -sDEVICE=png16m -r350 -sOutputFile=$output_file $input_file"
    fi
    echo "$cmd"
}

compare_mse() {
    local file1="$1"
    local file2="$2"

    local mse=$(compare -metric MSE $file1 $file2 null: 2>&1)
    echo "$mse"
}


# Benchmark a command and log the results
benchmark_command() {
    local cmd="$1"

    # Init PID monitor
    # Run the command in the background
    $cmd >/dev/null 2>&1 &
    local PID=$!

    # Init peak memory and CPU usage
    local start_time=$(gdate +%s.%N) # Use $EPOCHREALTIME
    local cpu_usage=()
    local mem_usage=()

    # Monitor the process until it finishes
    while kill -0 "$PID" 2>/dev/null; do
        # Capture memory and CPU usage
        local pid_stats=$(ps -p "$PID" -o %mem,%cpu | tail +2)
        local mem_usage=$(echo "$pid_stats" | awk '{print $1}')
        local cpu_usage=$(echo "$pid_stats" | awk '{print $2}')

        sleep 0.1
    done

    # Calculate duration of the process
    local end_time=$(gdate +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local cpu_p90=$(calculate_p90 "${cpu_usage[@]}")
    local mem_p90=$(calculate_p90 "${mem_usage[@]}")

    # Finalize the log
    echo "  $duration secs | CPU $cpu_p90% | MEM $mem_p90%"
}

calculate_p90() {
    local array=("$@")
    local n=${#array[@]}

    sorted=($(printf "%s\n" "${array[@]}" | sort -n))
    # Calculate
    local index=$(echo "($n * 0.9) - 1" | bc | awk '{print int($1)}')
    echo "${sorted[$index]}"
}

# Fetch and process each PDF file in the input directory
for FILE in $INPUT_DIR/*.pdf; do
    if [[ -f $FILE ]]; then
        run_benchmark_for_file "$FILE"
    fi
done

echo "Benchmark completed"