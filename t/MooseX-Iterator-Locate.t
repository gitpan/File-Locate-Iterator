#!/usr/bin/perl -w

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
use Test::More;

BEGIN {
  eval { require MooseX::Iterator }
    or plan skip_all => "MooseX::Iterator not available -- $@";
}

use lib 't';
use MyTestHelpers;
BEGIN { MyTestHelpers::nowarnings() }

plan tests => 18;
require MooseX::Iterator::Locate;

my $want_version = 16;
is ($MooseX::Iterator::Locate::VERSION, $want_version, 'VERSION variable');
is (MooseX::Iterator::Locate->VERSION,  $want_version, 'VERSION class method');
{ ok (eval { MooseX::Iterator::Locate->VERSION($want_version); 1 },
      "VERSION class check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { MooseX::Iterator::Locate->VERSION($check_version); 1 },
      "VERSION class check $check_version");
}
# MooseX::Iterator::Locate->new object isn't an actual subclass, just a
# flavour of Iterator::Simple, so no object version number test


#-----------------------------------------------------------------------------
# samp.zeros / samp.locatedb

# read $filename and return a list of strings from it
# each strings in $filename is terminated by a NUL \0
# the \0s are not included in the return
sub slurp_zeros {
  my ($filename) = @_;
  open my $fh, '<', $filename or die "Cannot open $filename: $!";
  binmode($fh) or die "Cannot set binary mode";
  local $/ = "\0";
  my @ret = <$fh>;
  close $fh or die "Error reading $filename: $!";
  foreach (@ret) { chomp }
  return @ret;
}

require FindBin;
require File::Spec;
my $samp_zeros    = File::Spec->catfile ($FindBin::Bin, 'samp.zeros');
my $samp_locatedb = File::Spec->catfile ($FindBin::Bin, 'samp.locatedb');

{
  my $it = MooseX::Iterator::Locate->new (database_file => $samp_locatedb);
  my @want = slurp_zeros ($samp_zeros);
  {
    my @got;
    while ($it->has_next) {
      push @got, $it->next;
    }
    is_deeply (\@got, \@want, 'samp.locatedb');
  }
  $it->reset;
  {
    my @got;
    while (defined (my $filename = $it->next)) {
      push @got, $filename;
    }
    is_deeply (\@got, \@want, 'samp.locatedb after reset()');
  }
}

{
  my $it = MooseX::Iterator::Locate->new (database_file => $samp_locatedb);
  my @want = slurp_zeros ($samp_zeros);

  is ($it->peek, $want[0], 'peek');
  is ($it->peek, $want[0]);
  is ($it->next, $want[0]);
  is ($it->peek, $want[1]);
  is ($it->peek, $want[1]);
  is ($it->next, $want[1]);
  $it->reset;
  is ($it->peek, $want[0]);
  is ($it->peek, $want[0]);
  is ($it->next, $want[0]);
  is ($it->peek, $want[1]);
  is ($it->peek, $want[1]);
  is ($it->next, $want[1]);
}

exit 0;
