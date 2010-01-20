#!/usr/bin/perl

# Copyright 2009, 2010 Kevin Ryde

# This file is part of File-Locate-Iterator.
#
# File-Locate-Iterator is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# File-Locate-Iterator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with File-Locate-Iterator.  If not, see <http://www.gnu.org/licenses/>.

use 5.006;
use strict;
use warnings;
use File::Locate::Iterator;



{
  my $filename = 't/samp.locatedb';
  open MYHANDLE, '<', $filename
    or die "cannot open: $!";
  my $it = File::Locate::Iterator->new (database_fh => \*MYHANDLE,
                                        use_mmap => 'if_possible');
  while (defined (my $str = $it->next)) {
    print "got '$str'\n";
  }
  close MYHANDLE;
  exit 0;
}

{
  my $str;
  {
    my $filename = 't/samp.locatedb';
    open my $fh, '<', $filename
      or die "oops, cannot open $filename: $!";
    binmode ($fh)
      or die "oops, cannot set binary mode on $filename";
    {
      local $/ = undef; # slurp
      $str = <$fh>;
    }
    close $fh
      or die "Error reading $filename: $!";
  }

  open my $fh, '<', \$str
    or die "oops, cannot open string";
  print "fileno ",fileno($fh),"\n";
  my $it = File::Locate::Iterator->new (database_fh => $fh,
                                        use_mmap => 'if_possible');
  print "using_mmap: ",$it->_using_mmap,"\n";

  while (defined (my $str = $it->next)) {
    print "got '$str'\n";
  }
  exit 0;
}



{
  my $filename = 't/samp.locatedb';
  # open my $fh, '<', $filename or die;
  open my $fh, '<', $filename or die;
#  binmode($fh) or die;
  require PerlIO;
  { local $,=' ';
    print PerlIO::get_layers($fh, details=>1),"\n";
  }
  exit 0;
}

{
  my $filename = 't/samp.locatedb';
  my $count = 0;
  my $it = File::Locate::Iterator->new (# globs => ['*.c','/z*'],
                                        use_mmap => 0,
                                        database_file => $filename,
                                       );
  print "fm: ",(defined $it->{'fm'} ? $it->{'fm'} : 'undef'),"\n";
  print "regexp: ",(defined $it->{'regexp'} ? $it->{'regexp'} : 'undef'),"\n";
  print "match: ",(defined $it->{'match'} ? $it->{'match'} : 'undef'),"\n";

  while (defined (my $str = $it->next)) {
    print "got '$str'\n";
    # print "  current ",$it->current,"\n";
    last if $count++ > 3;
  }
  exit 0;
}


{
  my $filename = 't/samp.locatedb';
  open my $fh, '<', $filename or die;
  require PerlIO;
  my $fm = File::Locate::Iterator::FileMap->get($fh);
  print "$fm\n";
  my $fm2 = File::Locate::Iterator::FileMap->get($fh);
  print "$fm2\n";
  exit 0;
}



{
  my $use_mmap = 'if_possible';

  my $filename = File::Locate::Iterator->default_database_file;

  my $mode = '<:encoding(iso-8859-1)';
  $mode = '<:utf8';
  $mode = '<:raw';
  $mode = '<:mmap';
  open my $fh, $mode, $filename
    or die;

  { local $,=' '; print "layers ", PerlIO::get_layers($fh), "\n"; }

  my $it = File::Locate::Iterator->new (database_fh => $fh,
                                        use_mmap => $use_mmap,
                                       );
  print exists $it->{'mmap'} ? "using mmap\n" : "using fh\n";

  exit 0;
}



{
  require File::FnMatch;
  print File::FnMatch::fnmatch('*.c','/foo/bar.c');
  exit 0;
}

{
  require File::Spec;

  # my $use_mmap = 1;
  my $use_mmap = 'if_possible';

   my $filename = '/tmp/frcode.out';
  # my $filename = File::Spec->devnull;

  open my $fh, '>', '/tmp/frcode.in' or die;
  print $fh <<'HERE' or die;
/usr/src
/usr/src/cmd/aardvark.c
/usr/src/cmd/armadillo.c
/usr/tmp/zoo
/usr/tmp/zoo/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
/usr/tmp/zoo/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/y
HERE
  close $fh or die;
  system "/usr/lib/locate/frcode </tmp/frcode.in >/tmp/frcode.out";
  system "ls -l /tmp/frcode.out";

  my $it = File::Locate::Iterator->new (database_file => $filename,
                                        # suffix => '.c',
                                        glob => '/usr/tmp/*',
                                        use_mmap => $use_mmap,
                                       );
  print $it->{'regexp'},"\n";
  print exists $it->{'mmap'} ? "using mmap\n" : "using fh\n";

  # require Perl6::Slurp;
  # Perl6::Slurp::slurp ($options{'database_file'}),

  # use Perl6::Slurp 'slurp';
  # my $str = slurp '/tmp/frcode.out';
  # $it->{'mmap'} = $str;

  while (defined (my $str = $it->next)) {
    print "got '$str'\n";
    # print "  current ",$it->current,"\n";
  }

  # my $str = 'jk';
  # my ($x) = unpack '@1c', $str;
  # print "$x\n";
  # print pos($str)+0;

  exit 0;
}

