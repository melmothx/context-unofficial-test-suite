# ConTeXt unofficial test suite

The script which runs the test is called run-test.pl

It runs the test suit if the argument "--run" is provided.

The debug is activated with the option "--debug" (or with the
environment variable CONTEXTTEXTDEBUG=1.

To add a test file, put the resulting PDF under the directory
"references", and the sources under "src". In "src" you can add
multiple files in subdirectories, but the master .tex path and the
reference .pdf path MUST match.

E.g., to add a testfile with multiple sources, add this file (keep
them under version control).

    src/complex/file1.tex
    src/complex/file2.tex
    src/complex/file3.tex
    src/complex/myproject-which-includes-the-three-files.tex
    references/complex/myproject-which-includes-the-three-files.pdf
    
When the rastered PDF differs, a image with the differences is left in
the "diffs" directory.
