#!/bin/bash

# Input/Output directory
TOOL="$1"
PARALLEL_JOBS="${2:-4}"
THREADS_NUMBER="${3:-4}"

SCRIPT_DIR=$(dirname "$0")
INPUT_DIR="${INPUT:-$(realpath "$SCRIPT_DIR/../test_data/pdf_files")}"
OUTPUT_DIR="${OUTPUT:-$(realpath "$SCRIPT_DIR/../test_data/output")}"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

echo "[$TOOL] Benchmark Summary - $(date)"
echo "Input Directory: $INPUT_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo "With $PARALLEL_JOBS parallel jobs and $THREADS_NUMBER rendering threads for gs"

# Function to run benchmark for a PDF file
run_benchmark_for_file() {
    local file=$1
    local file_name=$(basename "$file")
    echo "==================================="
    echo "Processing $file_name..."

    local tool="$TOOL"
    local output_dir="$OUTPUT_DIR/$file_name"
    mkdir -p $output_dir

    printf "Sanitize"
    local san_file="$output_dir/sanitized.pdf"
    local san_cmd=$(sanitize $tool $file $san_file)
    local perf_cmd=$(run_with_perf "$san_cmd")
    eval $perf_cmd

    printf "Split pages"
    local split_dir="$output_dir/split"
    local split_files="$split_dir/page_%d.pdf"
    mkdir -p "$split_dir"
    local split_cmd=$(split $tool $san_file $split_files)
    local perf_cmd=$(run_with_perf "$split_cmd")
    eval $perf_cmd
    # Rename the split files to remove leading zeros
    for page_file in "$split_dir"/*.pdf; do
        new_name=$(echo "$page_file" | sed -E 's/_0*([1-9][0-9]*).pdf/_\1.pdf/')
        mv "$page_file" "$new_name"
    done

    # Fetch the first file in directory to convert to png
    printf "Convert png"
    local start_time=$(echo $EPOCHREALTIME)
    local png_dir="$output_dir/png"
    local png_tool=$tool
    mkdir -p "$png_dir"
    commands=()
    for page_file in "$split_dir"/*.pdf; do
        file_name=$(basename $page_file)
        png_file="$png_dir/${file_name%.*}"
        local perf_cmd=$(run_with_perf "$(convert_png $tool $page_file $png_file)" $file_name)
        commands+=("$perf_cmd")
    done
    printf "%s\n" "${commands[@]}" | parallel -j $PARALLEL_JOBS

    local end_time=$(echo $EPOCHREALTIME)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    echo "Done in $duration secs"
    sleep 0.1
}

GS_DEFAULT_OPTIONS="-dNOPAUSE -dQUIET -dSAFER -dNumRenderingThreads=$THREADS_NUMBER -dBandBufferSpace=500000000 -dBufferSpace=1000000000 -c \"30000000 setvmthreshold\""
sanitize() {
    local tool="$1"
    local input_file="$2"
    local output_file="$3"
    if [[ $tool == "poppler" ]]; then
        local cmd="pdftocairo -pdf $input_file $output_file"
    elif [[ $tool == "gs" ]]; then
        local cmd="gs -dNOPAUSE -dQUIET -dSAFER -dBATCH -dNEWPDF=true -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -o $output_file -f $input_file"
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
        local cmd="gs -dNOPAUSE -dQUIET -dSAFER -dBATCH -sDEVICE=pdfwrite -sOutputFile=$output_file -f $input_file"
    elif [[ $tool == "qpdf" ]]; then
        local cmd="qpdf --split-pages $input_file $output_file"
    fi
    echo "$cmd"
}

convert_png() {
    local tool="$1"
    local input_file="$2"
    local output_file="$3"

    local cmd="pdftoppm -r 350 -singlefile -png $input_file $output_file"
    if [[ $tool == "gs" ]]; then
        output_file="$output_file.png"
        local cmd="gs -sDEVICE=png16m -r350 -sOutputFile=$output_file $GS_DEFAULT_OPTIONS -f $input_file"
    fi
    echo "$cmd"
}

run_with_perf() {
    local cmd="$1"
    local prefix="$2"

    local perf_cmd="perf stat -e task-clock -- $cmd 2>&1 | awk \
        '/time elapsed/ { elapsed=\$1 \"s\" } \
        /CPUs utilized/ { cpu_utilized=\$5 } \
        END { printf \"$prefix : %s, %s cpus\n\", elapsed, cpu_utilized }'"
    echo "$perf_cmd"
}

# Fetch and process each PDF file in the input directory
for FILE in $INPUT_DIR/*.pdf; do
    if [[ -f $FILE ]]; then
        run_benchmark_for_file "$FILE"
    fi
done

echo "Benchmark completed"