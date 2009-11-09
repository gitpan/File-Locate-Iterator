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

eval { require Iterator }
  or plan skip_all => "Iterator.pm not available -- $@";

plan tests => 9;

require Iterator::Locate;

SKIP: { eval 'use Test::NoWarnings; 1'
          or skip 'Test::NoWarnings not available', 1; }

my $want_version = 3;
cmp_ok ($Iterator::Locate::VERSION, '>=', $want_version,
        'VERSION variable');
cmp_ok (Iterator::Locate->VERSION,  '>=', $want_version,
        'VERSION class method');
{ ok (eval { Iterator::Locate->VERSION($want_version); 1 },
      "VERSION class check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { Iterator::Locate->VERSION($check_version); 1 },
      "VERSION class check $check_version");
}
{ my $tdl = Iterator::Locate->new;
  cmp_ok ($tdl->VERSION, '>=', $want_version, 'VERSION object method');
  ok (eval { $tdl->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { $tdl->VERSION($check_version); 1 },
      "VERSION object check $check_version");
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
  my $it = Iterator::Locate->new (database_file => $samp_locatedb);
  my @want = slurp_lines ($samp_txt);
  my @got;
  until ($it->is_exhausted) {
    push @got, $it->value;
  }
  is_deeply (\@got, \@want, 'samp.locatedb');
}

exit 0;
