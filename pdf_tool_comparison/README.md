# PDF Tool Comparison

## Benchmark

A benchmark will be conducted for each file using PDF utility tools.

The process will follow the flow below:

- Sanitize PDF files
- Split pages
- Convert splitted pages to PNG

The converted files will be generated in the `test_data/output` directory.

Required to install `gdate` which is GNU's `date`
TODO: use Docker instead

```
brew install gdate
```

```bash
sh ./pdf_tool_comparison/benchmark.sh poppler > poppler_benchmark.log
sh ./pdf_tool_comparison/benchmark.sh gs > gs_benchmark.log
sh ./pdf_tool_comparison/benchmark.sh qpdf > qpdf_benchmark.log
```

## Image conversion quantity

TODO
