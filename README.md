# BulkRenamePS
A PowerShell script for batch-renaming files using custom input and output patterns, with interactive prompts and conflict handling.

## Pattern Variables and Usage
This tool lets you define input and output patterns using named variables enclosed in square brackets. The script will match files against your input pattern, extract variable values, and use those values to construct output filenames.

- **Input pattern:** pattern used to match existing filenames (example: `[Prefix]_[NR].cr2`).
- **Output pattern:** pattern used to generate new filenames (example: `Result_[NR].cr2`).
- **Variables:** any token inside `[]` becomes a capture variable (e.g., `[Prefix]`, `[NR]`).

How it works:
- The script matches files using the input pattern. For example, given a file named `IMG_8069.cr2` and the input pattern `[Prefix]_[NR].cr2`:
	- `Prefix` = `IMG`
	- `NR` = `8069`
- You can then use these variables in the output pattern. With `Result_[NR].cr2`, the result becomes `Result_8069.cr2`.

Examples:
- Match all `.cr2` files with a numeric suffix and rewrite with `Result_` prefix:

	- Input pattern: `[Prefix]_[NR].cr2`
	- Output pattern: `Result_[NR].cr2`
	- `IMG_8069.cr2` -> `Result_8069.cr2`

- Keep the original prefix and add a suffix:

	- Input pattern: `[Name].cr2`
	- Output pattern: `[Name]_edited.cr2`
	- `IMG_8069.cr2` -> `IMG_8069_edited.cr2`

Notes and tips:
- Patterns are literal except for variable tokens in `[]`. Use separators (like `_` or `-`) to make matching unambiguous.
- It will look for the seperator between variables, try to find patterns in which you can generalize the filenames
- If multiple files produce the same output name, the script should warn or handle conflicts (see the script's interactive prompts).
- To match all files in a folder, use a simple input pattern like `[*].*` or use the interactive prompt to accept all files.
