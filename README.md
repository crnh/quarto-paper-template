# Quarto paper template

Template for writing papers with [Quarto](https://quarto.org/).
This paper does intentionally not use Quarto's manuscript format, because that format has issues with certain types of floats.

## How to use

1. Create a new Quarto project with this template:

   ```bash
   quarto use template crnh/quarto-paper-template
   ```
3. Change the project name and description in `pyproject.toml` and update the author information in `index.qmd`.
4. Copy this repository's `.gitignore` file to your project to ignore Quarto's cache and temporary files. Unfortunately, Quarto does not copy the `.gitignore` file from the template, so you have to do this manually.
5. Start writing your paper in `index.qmd`. Good luck!

## Features

- Custom author block based on [kapsner/authors-block](https://github.com/kapsner/authors-block)
- Render main text and supplemental materials to separate files
- Default Python project configuration in `pyproject.toml` with commonly used dependencies for data analysis and visualization
