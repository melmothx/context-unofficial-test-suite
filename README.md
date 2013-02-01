# ConTeXt unofficial test suite

## Organization of the test suite

- `src/`: Directory containing test files
- `references/`: Directory containing reference pdf output
- `diffs/`: Directory generate by `run-test.pl`
- `run-test.pl`: Perl script to run tests

## Dependencies

- [ImageMagick](http://www.imagemagick.org)
- `pdftoppm`, part of [Poppler Utilities](http://poppler.freedesktop.org/)

## How to run tests

- To run all tests:

        run-test.pl --run

- To run tests on a single file or directory

        run-test.pl --single reference/path/to/test


- To get diagnostic information: Add the option `--debug` or set the
  environment variable `CONTEXTTEXTDEBUG=1`.

When the rastered PDF differs, a image with the differences is left in
the "diffs" directory.

## Add test file to suite

- Add the `.tex` file in an appropriate sub-directory of `src/` and add the
  corresponding `.pdf` file in the parallel sub-directory of `references/`

- A test file may consist of multiple files as long as the name of the master
  `.tex` file matches the reference `.pdf` file.
