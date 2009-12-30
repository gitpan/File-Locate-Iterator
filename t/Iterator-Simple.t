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
use Test::More;

eval { require Iterator::Simple }
  or plan skip_all => "Iterator::Simple not available -- $@";

plan tests => 6;

require Iterator::Simple::Locate;

SKIP: { eval 'use Test::NoWarnings; 1'
          or skip 'Test::NoWarnings not available', 1; }

my $want_version = 6;
cmp_ok ($Iterator::Simple::Locate::VERSION, '>=', $want_version,
        'VERSION variable');
cmp_ok (Iterator::Simple::Locate->VERSION,  '>=', $want_version,
        'VERSION class method');
{ ok (eval { Iterator::Simple::Locate->VERSION($want_version); 1 },
      "VERSION class check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { Iterator::Simple::Locate->VERSION($check_version); 1 },
      "VERSION class check $check_version");
}

#-----------------------------------------------------------------------------
# samp.txt / samp.locatedb

sub slurp_lines {
  my ($filename) = @_;
  open my $fh, '<', $filename or die "Cannot open $filename: $!";
  my @ret = <$fh>;
  close $fh or die;
  chomp foreach @ret;
  return @ret;
}
{
  require FindBin;
  require File::Spec;
  my $samp_txt      = File::Spec->catfile ($FindBin::Bin, 'samp.txt');
  my $samp_locatedb = File::Spec->catfile ($FindBin::Bin, 'samp.locatedb');
  my $it = Iterator::Simple::Locate->new (database_file => $samp_locatedb);
  my @want = slurp_lines ($samp_txt);
  my @got;
  while (defined (my $filename = $it->())) {
    push @got, $filename;
  }
  is_deeply (\@got, \@want, 'samp.locatedb');
}

exit 0;
