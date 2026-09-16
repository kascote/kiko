<!-- dmetrics:start -->
## Code metrics — dmetrics

This project measures code with **dmetrics** (cyclomatic and cognitive
complexity per function, import coupling per library) against thresholds in
`analysis_options.yaml`. Run it once per task, after your edits, not after
every edit:

    dmetrics analyze [<file>|<dir> ...]

Pass the package's source roots: `lib`, plus `bin` when it has one. With no
targets it measures the current directory, tests and fixtures included, which
is usually more than you want.

Exit 0 is clean, 1 means violations, 2 means the analysis did not complete
(fix that first). Before interpreting a report, run `dmetrics agent`: it
explains the report line, what each metric measures and what to do about a
warning.
Warnings are evidence to weigh, not orders to obey. Never lower a threshold
or add an override to make a run pass; propose the change instead.
When the tool gets in your way, say so instead of working around it: a
report that misleads, a construct a metric misreads, a flag or an output you
needed and did not find. Report it as a gap in dmetrics, with the case that
showed it, so the tool improves rather than the workaround spreading.
<!-- dmetrics:end -->
