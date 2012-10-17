#!/usr/bin/env perl

# No copyright
# public domain
# written by Marco Pessotto

use strict;
use warnings;
use Cwd;
use File::Spec::Functions;
use File::Basename;
use Getopt::Long;
use Cwd;
use File::Spec;
use File::Spec::Functions;
use File::Find;
use File::Path qw/make_path remove_tree/;
use Data::Dumper;
use File::Temp qw/ :seekable /;
use File::Copy;


my $run;
my $debug;
my $extension = qr{\.\w+$};

my $options = GetOptions (
  "run" => \$run,
  "debug" => \$debug,
 );

unless ($run) {
  give_help();
  exit;
}

print "Using " . `which context` . `context --version`;

my $root = getcwd;
my $diffs = catdir($root, "diffs");
remove_tree($diffs, { verbose => 1 });
make_path($diffs);

# create the reference table;

my %testtable;
find (\&wanted, "references");
my %reftable = %testtable; # copy
%testtable = ();
find (\&wanted, "src");

sub wanted {
  my $file     = $_;
  my $dir      = $File::Find::dir;
  my $fullname = $File::Find::name;
  my $fullpath = getcwd;
  return unless -f $file;
  my ($basename, $path, $suffix) = fileparse($file, $extension);
  return unless ($suffix eq ".pdf" or $suffix eq '.tex');
  if ((exists $testtable{$basename}) and ($testtable{$basename} ne $fullpath)) {
    warn "Overwriting " . $testtable{$basename} . " in the testtable with "
      . $fullpath . "!\n"
    }
  $testtable{$basename} = $fullpath;
}
# tables done

print_debug("Targets: ", Dumper(\%testtable, \%reftable));

my $results = {};

foreach my $key (keys %reftable) {
  my $dir = $testtable{$key};
  my $tex = $key . ".tex";
  unless ($dir) {
    warn "Missing src file for $key\n";
    next;
  };
  chdir $dir or die "Couldn't chdir into $dir\n";
  # compile the pdf
  print ".";
  if (-f $tex) {
    # compile and compare
    $results->{$key} = {
      success => 'FAILED',
      compare => [],
      elapsed => 0,
     };
    compile_and_compare($key, $tex, catfile($reftable{$key}, $key . ".pdf"));
  } else {
    #    warn "Missing TeX file for $tex in " . getcwd() . "\n";
  }
  chdir $root;
}

print "\n";
print_debug(Dumper($results));
print format_result($results);


sub compile_and_compare {
  my ($basename, $tex, $reference) = @_;
  unless (-f $tex and -f $reference) {
    warn "Faulty argument\n";
    return;
  }
  print_debug("Compiling $tex in ", getcwd(), "\n");
  my $starttime = time;
  return unless (tex_compile("context", "--batchmode", "--noconsole",
			     "--purgeresult", "--purge", $tex));
  my $stoptime = time;
  $results->{$basename}->{elapsed} = $stoptime - $starttime;
  my $generated = $basename . ".pdf";
  return unless (-f $generated);
  $results->{$basename}->{success} = 'OK';
  diff_pdf($basename, $generated, $reference);
}


sub format_result {
  my $result = shift;
  printf "\n|%20s | %7s | %12s \t| %12s \t| %5s | %4s |\n",
    "File name", "Success", "Differs Avg", "Worst value", "Pages", "Time";
  foreach my $key (sort (keys %$result)) {
    printf "|%20s | %7s |  %3.6f \t|  %3.6f \t| %5s | %4s |\n",
      $key, $result->{$key}->{success},
	get_average($result->{$key}->{compare}),
	  get_maximum($result->{$key}->{compare}), 
	    scalar(@{$result->{$key}->{compare}}), 
	      $result->{$key}->{elapsed};
  }
}


sub get_average {
  my $arrayref = shift;
  my $total = scalar @$arrayref;
  return 0 if $total == 0;
  my $count = 0;
  foreach my $item (@$arrayref) {
    $count += $item;
  }
  return $count / $total;
}

sub get_maximum {
  my $arrayref = shift;
  my $max = 0;
  foreach my $item (@$arrayref) {
    $max = $item if $max < $item
  }
  return $max;
}


sub diff_pdf {
  my ($id, $out, $reference) = @_;
  print_debug("\n$out <=> $reference\n");
  my @produced = @{generate_ppm($out)};
  my @original = @{generate_ppm($reference)};
  my $index = 0;
  while (@produced) {
    my $prod = shift @produced;
    my $orig = shift @original;
    unless ($orig) {
      warn "\nTHE PAGE COUNT FOR $id DIFFERS!\n";
      last;
    }
    $index++;
    push @{$results->{$id}->{compare}}, compare_ppm($orig, $prod, $id, $index);
  }
  warn "THE TOTAL PAGES NUMBER FOR $id DIFFERS!\n" if @original;
}

sub compare_ppm {
  my ($orig, $prod, $basename, $page) = @_;
  die "Wrong arguments\n" unless ($orig and $prod and $basename and $page);
  # print $basename, $page, "\n";
  my $outfile = catfile($diffs, $basename . "-" . $page . ".png");
  my $temp = File::Temp->new(SUFFIX => '.txt');
  print_debug("Comparing $orig with $prod\n");
  system('compare', $orig, $prod, '-compose', 'src',
	 '-highlight-color', 'black', $outfile) == 0
	   or die "Couldn't compare $!";
  # convert to text with a high -resize
  system('convert', '-resize', '200x200', $outfile, $temp->filename) == 0
    or die "Couldn't resize $!";
  # parse. If 0%, unlink the png
  my $percent = parse_txt($temp);
  if ($percent == 0) {
    unlink $outfile
  } else {
    # if there is a link, we leave a non executable script to be
    # called with sh file.txt, to easily catch the differences.
    my $generatedpdf = get_master_file($prod, $basename);
    my $originalpdf  = get_master_file($orig, $basename);

    my $pdfviewerscript = $outfile;
    $pdfviewerscript =~ s/png$/sh/;
    open (my $fh, ">", $pdfviewerscript)
      or die "Cannot print in $pdfviewerscript $!\n";
    print $fh '#!/bin/sh', "\n";
    print $fh "exiftool -Title=GENERATED $generatedpdf\n";
    print $fh 'PDFVIEWER=${PDFVIEWER:-mupdf}', "\n";
    print $fh '$PDFVIEWER ', $generatedpdf, ' &', "\n";
    print $fh '$PDFVIEWER ', $originalpdf,  "\n";
    print $fh <<"EOF";
if [ "\$1" = "-p" ]; then
   mv -vi $generatedpdf $originalpdf
fi
EOF
    close $fh;
  }
  return $percent;
}

sub get_master_file {
  my ($ppm, $basename) = @_;
  my @dirs;
  unless (file_name_is_absolute($ppm)) {
    push @dirs, File::Spec->splitdir(getcwd());
  }
  push @dirs, File::Spec->splitdir(dirname($ppm));
  # go up;
  pop @dirs;
  return catfile(@dirs, $basename . ".pdf");
}

sub parse_txt {
  my $fh = shift;
  $fh->seek(0,0);
  my $total = 0;
  my $match = 0;
  my $header = <$fh>;
  while (<$fh>) {
    $match++ unless m/ffffff/i;
    $total++;
  }
  return ($match * 100 / $total);
}

sub generate_ppm {
  my $pdf = shift;
  my ($basename, $path, $suffix) = fileparse($pdf, ".pdf");
  my $targetdir = catdir($path, $basename);
  return unless -f $pdf;
  
  # create the dir and populate it
  make_path($targetdir, {verbose => 1});
  clean_ppm_dir($targetdir);
  system('pdftoppm', $pdf, catfile($targetdir, "out")) == 0 or return;

  # read the files and return the list of paths
  opendir (my $dh, $targetdir) or return;
  my @ppms = sort(grep { /\.ppm$/ } readdir($dh));
  closedir $dh;
  my @fullpaths;
  while (@ppms) {
    my $f = catfile($targetdir, shift @ppms);
    next unless -f $f;
    push @fullpaths, $f;
  }
  print_debug("Path of ppms: ", Dumper(\@fullpaths));
  return \@fullpaths ;
}

# helpers

sub tex_compile {
  my @exectex = @_;
  die "Can't fork: $!" unless defined(my $pid = open(CHILD, "-|"));
  my $error;
  if ($pid) {			# parent
    while (<CHILD>) {
      if (m/fatal error/) {
	#	warn "Compilation failed!";
	$error = 1;
      }
    }
    close CHILD;
  } else {
    exec @exectex or warn "Couldn't exec!\n";
  }
  $error ? return : return 1;
}

sub clean_ppm_dir {
  my $dir = shift;
  return unless -d $dir;
  opendir (my $dh, $dir) or die "Couldn't open $dir, $!";
  my @ppms = grep { /.ppm$/ } readdir ($dh);
  closedir $dh;
  foreach my $ppm (@ppms) {
    my $f = catfile($dir, $ppm);
    if (-f $f) {
      unlink $f or warn "$f removal: $!\n"
    }
  }
  return;
}

sub print_debug {
  if ($ENV{CONTEXTTEXTDEBUG} or $debug) {
    print @_;
  }
}

sub give_help {
  print <<'HELP';

Run the test suit if the argument "--run" is provided.

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

HELP
}
