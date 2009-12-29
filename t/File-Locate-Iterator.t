#!/usr/bin/perl

# Copyright 2009 Kevin Ryde

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
use Test::More tests => 64;

SKIP: { eval 'use Test::NoWarnings; 1'
          or skip 'Test::NoWarnings not available', 1; }

my $want_version = 5;
cmp_ok ($File::Locate::Iterator::VERSION, '>=', $want_version,
        'VERSION variable');
cmp_ok (File::Locate::Iterator->VERSION,  '>=', $want_version,
        'VERSION class method');
{ ok (eval { File::Locate::Iterator->VERSION($want_version); 1 },
      "VERSION class check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { File::Locate::Iterator->VERSION($check_version); 1 },
      "VERSION class check $check_version");
}

#-----------------------------------------------------------------------------
# samp.txt / samp.locatedb

sub no_inf_loop {
  my ($name) = @_;
  my $count = 0;
  return sub {
    if ($count++ > 20) { die "Oops, eof not reached on $name"; }
  };
}

sub slurp_lines {
  my ($filename) = @_;
  open my $fh, '<', $filename or die "Cannot open $filename: $!";
  my @ret = <$fh>;
  close $fh or die "Error reading $filename: $!";
  foreach (@ret) { chomp }
  return @ret;
}
require FindBin;
require File::Spec;
my $samp_txt      = File::Spec->catfile ($FindBin::Bin, 'samp.txt');
my $samp_locatedb = File::Spec->catfile ($FindBin::Bin, 'samp.locatedb');
diag "Test samp_txt=$samp_txt, samp_locatedb=$samp_locatedb";
{
  my @samp_txt = slurp_lines ($samp_txt);
  my $orig_RS = $/;

  {
    my $it = File::Locate::Iterator->new (database_file => $samp_locatedb);
    my @want = @samp_txt;
    my @got;
    my $noinfloop = no_inf_loop($samp_locatedb);
    while (defined (my $filename = $it->next)) {
      push @got, $filename;
      $noinfloop->();
    }
    is_deeply (\@got, \@want, 'samp.locatedb');
  }

  # with 'glob'
  {
    my $it = File::Locate::Iterator->new (database_file => $samp_locatedb,
                                          glob => '*.c');
    my $noinfloop = no_inf_loop("$samp_locatedb with *.c");
    my @want = grep {/\.c$/} @samp_txt;
    my @got;
    while (defined (my $filename = $it->next)) {
      push @got, $filename;
      $noinfloop->();
    }
    is_deeply (\@got, \@want, 'samp.locatedb');
  }

  # with 'regexp'
  {
    my $regexp = qr{^/usr/tmp};
    my $it = File::Locate::Iterator->new (database_file => $samp_locatedb,
                                          regexp => $regexp);
    my $noinfloop = no_inf_loop("$samp_locatedb with *.c");
    my @want = grep {/$regexp/} @samp_txt;
    my @got;
    while (defined (my $filename = $it->next)) {
      push @got, $filename;
      $noinfloop->();
    }
    is_deeply (\@got, \@want, 'samp.locatedb');
  }

  # with 'glob' and 'regexp'
  {
    my $regexp = qr{^/usr/tmp};
    my $it = File::Locate::Iterator->new (database_file => $samp_locatedb,
                                          regexp => $regexp,
                                          glob => '*.c');
    my $noinfloop = no_inf_loop("$samp_locatedb with *.c");
    my @want = grep {/$regexp|\.c$/} @samp_txt;
    my @got;
    while (defined (my $filename = $it->next)) {
      push @got, $filename;
      $noinfloop->();
    }
    is_deeply (\@got, \@want, 'samp.locatedb');
  }

  foreach my $use_mmap (0, 'if_sensible', 'if_possible') {
    my $it = File::Locate::Iterator->new (database_file => $samp_locatedb,
                                          use_mmap => $use_mmap);
    my $noinfloop = no_inf_loop("$samp_locatedb with use_mmap=$use_mmap it="
                                . explain $it);
    my @want = @samp_txt;
    my @got;
    while (my ($filename) = $it->next) {
      push @got, $filename;
      $noinfloop->();
    }
    is_deeply (\@got, \@want,
               "samp.locatedb  use_mmap=$use_mmap using_mmap=@{[$it->_using_mmap]}");
  }
  is ($/, $orig_RS, 'input record separator unchanged');
}

#-----------------------------------------------------------------------------
# bad files

{
  package MyFileRemover;
  # remove $filename when the "remover" object goes out of scope.
  sub new {
    my ($class, $filename) = @_;
    return bless { filename => $filename }, $class;
  }
  sub DESTROY {
    my ($self) = @_;
    unlink $self->{'filename'};
  }
}

{
  my $orig_RS = $/;

  my $filename = 'File-Locate-Iterator.tmp';
  my $remover = MyFileRemover->new ($filename);

  my $header = "\0LOCATE02\0";
  foreach my $elem (['empty',
                     'no LOCATE02 header',
                     '' ],
                    ['short header',
                     'no LOCATE02 header',
                     substr($header,0,-1) ],
                    ['count then eof',
                     'unexpected EOF',
                     $header . "\0" ],
                    ['no nul terminator',
                     'unexpected EOF',
                     $header . "\0foo" ],

                    ['long count marker then eof',
                     'unexpected EOF',
                     $header . "\200" ],
                    ['long count 1 byte then eof',
                     'unexpected EOF',
                     $header . "\200\0" ],
                    ['long count then eof',
                     'unexpected EOF',
                     $header . "\200\0\0" ],
                    ['long no nul terminator',
                     'unexpected EOF',
                     $header . "\200\0\0foo" ],

                    ['negative share -1',
                     'bad share length',
                     $header . "\377foo\0" ],
                    ['negative share -127',
                     'bad share length',
                     $header . "\201foo\0" ],
                    ['long negative share -1',
                     'bad share length',
                     $header . "\200\377\377foo\0" ],
                    ['long negative share -32768',
                     'bad share length',
                     $header . "\200\200\000foo\0" ],

                    ['overrun share 1',
                     'bad share length',
                     $header . "\1foo\0" ],
                    ['overrun share 127',
                     'bad share length',
                     $header . "\177foo\0" ],
                    ['long overrun share 1',
                     'bad share length',
                     $header . "\200\000\001foo\0" ],
                    ['long overrun share 32767',
                     'bad share length',
                     $header . "\200\177\377foo\0" ],

                   ) {
    my ($name, $want_err, $str) = @$elem;

    {
      do { my $fh;
           open $fh, '>', $filename
             and print $fh $str
               and close $fh }
        or die "Cannot write file $filename: $!";
    }

    foreach my $use_mmap (0, 'if_sensible', 'if_possible') {
      my $got_err;
      my $mmap_used = ($use_mmap ? 'no, failed' : 0);
      my $it;
      if (eval {
        $it = File::Locate::Iterator->new (database_file => $filename,
                                           use_mmap => $use_mmap);
        if (exists $it->{'mref'}) {
          $mmap_used = 'yes';
        }
        $it->next;
        1
      }) {
        $got_err = 'ok';
      } else {
        $got_err = $@;
      }
      like ($got_err, "/$want_err/", "$name, mmap_used=$mmap_used");
    }
  }
  is ($/, $orig_RS, 'input record separator unchanged');
}

#-----------------------------------------------------------------------------
# mmap caching

SKIP: {
  my $it1 = File::Locate::Iterator->new (database_file => $samp_locatedb,
                                         use_mmap => 'if_possible');
  my $it2 = File::Locate::Iterator->new (database_file => $samp_locatedb,
                                         use_mmap => 'if_possible');
  ($it1->_using_mmap && $it2->_using_mmap)
    or skip 'mmap "if_possible" not used', 2;

  is ($it1->{'fm'}, $it2->{'fm'}, "FileMap re-used");
  my $fm = $it1->{'fm'};
  Scalar::Util::weaken ($fm);
  undef $it1;
  undef $it2;
  is ($fm, undef, 'FileMap destroyed with iterators');
}

exit 0;
