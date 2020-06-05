# PumasPostProcessing

In use to build out Post-Processing functions.

## Setup

This package is available through the JuliaPro registry, and can be added in JuliaPro by `]add PumasPostProcessing`.

## Usage

PumasPostProcessing exposes two APIs - a low level, table generating API and a high-level report generating API.

To use the automated report generation, you can call the exported `jmd_report` function, which will take in a `FittedPumasModel` and return a Weave markdown string which can be written to a file.  

```julia
using Weave
write("report.jmd", PumasPostProcessing.jmd_report(fpm, "My Model Name", "1"))
Weave.weave("report.jmd"; doctype="pandoc2pdf", fig_ext= ".pdf",
pandoc_options = ["-V 'geometry:margin=1in'"], keep_unicode = false)
```


There is also "dumb", plain-markdown output from `to_report_str`,as in the following snippet.
If you have [`pandoc`](pandoc.org) installed, there is also a `report_to_pdf` function, which will automatically create a PDF of the report through LaTeX.

```julia
# fpm isa FittedPumasModel
report = to_report_str(fpm)
write("report.md", report)
report_to_pdf("report.pdf", report)
```

The low-level API consists of functions which take in an FPM, and return tables.  These are in the functions
`param_table`, `optim_meta_table`, and `metric_table`, which are all exported.  They are also documented, and you can view their docstrings in the REPL or JuliaPro documentation browser.

## Feature requests and bug reports

Please file any feature requests or bug reports you have as issues on this repo.
