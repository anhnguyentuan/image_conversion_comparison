# Image conversion Comparison

## Benchmark

A benchmark will be conducted for each file using PDF utility tools.

The process will follow the flow below:

- Sanitize PDF files
- Split pages
- Convert split pages to PNG

The converted files will be generated in the `test_data/output` directory.

## Usages

Build Docker to run the benchmark. The command should be run at the root folder

```bash
docker build -t pdf-tool-comparison .
```

Perform the benchmark via Docker.
Supported tools are `gs` | `poppler` | `qpdf`

```bash
docker run -it --rm --name=pdf-tool-comparison \
    --security-opt "seccomp:unconfined" \
    -e INPUT="/app/test_data/pdf_files" \
    -e OUTPUT="/app/test_data/output" \
    -v ./:/app/ \
    pdf-tool-comparison \
    /bin/bash ./pdf_tool_comparison/benchmark.sh [qpdf|gs|poppler] > bench.log
```

# Image conversion evaluation

To evaluate the image quality after conversion using different tools, run the `compare.sh` script.

It will output the comparison results between two tools.

Make sure to run the benchmark first to generate the PNG files.

```bash
docker run -it --rm --name=pdf-tool-comparison \
    --security-opt "seccomp:unconfined" \
    -v ./:/app/ \
    pdf-tool-comparison \
    /bin/bash ./pdf_tool_comparison/compare.sh "/app/test_data/output/qpdf" "/app/test_data/output/gs" > compare_gs_poppler.log
```

## Comparison metrics

### MSE

MSE measures the average squared differences between pixel values, helping identify visual deviations.

Lower MSE values indicate closer similarity.

### SSIM

SSIM is a metric used to compare the structure of two images, and it can overlook minor differences in raster properties such as resolution, brightness, or contrast.

• SSIM = 1: The two images are very similar, with identical structures (including minor differences in brightness or color).
• SSIM = 0.9 to 1: The two images have similar structures, but there may be slight differences (due to changes in brightness, contrast, or other factors).
• SSIM < 0.9: The two images differ significantly in structure, and the differences may be noticeable.
• SSIM close to 0: The structures of the two images are very different, and they may have significant differences, such as varying shapes or content.
