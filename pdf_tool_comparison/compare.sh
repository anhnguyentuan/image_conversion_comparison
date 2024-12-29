#!/bin/bash

DIR_1=$1
DIR_2=$2

if [ ! -d "$DIR_1" ] || [ ! -d "$DIR_2" ]; then
    echo "Directories does not exist."
    exit 1
fi

run_compare() {
    echo "Compare $DIR_1 with $DIR_2"
    MSI_THRESHOLD=8000
    find "$DIR_1" -type f -name "*.png" | while read -r file; do
        local file_name=$(basename "$file")
        # Get relative file path from the source directory by removing the source directory path
        local relative_file_path=${file##$DIR_1/}
        # Append prefix path with slash character (/) if it's not empty
        local file_2="${DIR_2:+$DIR_2/}${relative_file_path}"

        if [ ! -f "$file_2" ]; then
            echo "File $file_2 does not exist"
            continue
        fi

        # Compare the files
        local mse=$(mse_compare $file $file_2)
        local ssim=$(ssim_compare $file $file_2)

        local v=$(echo "$mse" | awk '{print $1}')
        # if (( $(echo "$v > $MSI_THRESHOLD" | bc -l) )); then
            echo "$relative_file_path: MSE: $mse; SSIM: $ssim"
        # fi
    done
    echo "==================================="
}

# MSE compare with ImageMagick
mse_compare() {
    local image_1=$1
    local image_2=$2
    local basename=$(basename "$image_1")
    local mse_diff=$(magick compare -metric MSE "$image_1" "$image_2" null: 2>&1)
    if [ $? -eq 0 ]; then
        echo "$mse_diff"
    else
        echo "10000 (1)"
    fi
}

# SSIM comparison with OpenCV
ssim_compare() {
    local image_1=$1
    local image_2=$2
    local basename=$(basename "$image_1")
    local ssim_diff=$(magick compare -metric SSIM "$image_1" "$image_2" null: 2>&1)
    if [ $? -eq 0 ]; then
        echo "$ssim_diff"
    else
        echo ""
    fi
}

run_compare
