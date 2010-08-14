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
use File::Locate::Iterator;
use Test::More;

use lib 't';
use MyTestHelpers;
use Test::Weaken::ExtraBits;
BEGIN { MyTestHelpers::nowarnings() }

BEGIN {
  # version 3.002 for "tracked_types"
  eval "use Test::Weaken 3.002; 1"
    or plan skip_all => "due to Test::Weaken 3.002 not available -- $@";

  plan tests => 3;
}
diag ("Test::Weaken version ", Test::Weaken->VERSION);


#-----------------------------------------------------------------------------

use FindBin;
use File::Spec;
my $samp_locatedb = File::Spec->catfile ($FindBin::Bin, 'samp.locatedb');

# database_file
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         File::Locate::Iterator->new (database_file => $samp_locatedb);
       },
       contents => \&Test::Weaken::ExtraBits::contents_glob_IO,
       tracked_types => [ 'GLOB', 'IO' ],
     });
  is ($leaks, undef, 'deep garbage collection');
  if ($leaks && defined &explain) {
    diag "Test-Weaken ", explain $leaks;
  }
}

# database_fh
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $filename = $samp_locatedb;
         open my $fh, '<', $filename
           or die "oops, cannot open $filename";
         return [ File::Locate::Iterator->new (database_fh => $fh),
                  $fh ];
       },
       contents => \&Test::Weaken::ExtraBits::contents_glob_IO,
       tracked_types => [ 'GLOB', 'IO' ],
     });
  is ($leaks, undef, 'deep garbage collection');
  if ($leaks && defined &explain) {
    diag "Test-Weaken ", explain $leaks;
  }
}

# database_fh, no mmap
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $filename = $samp_locatedb;
         open my $fh, '<', $filename
           or die "oops, cannot open $filename";
         return [ File::Locate::Iterator->new (database_fh => $fh,
                                               use_mmap => 0),
                  $fh ];
       },
       contents => \&Test::Weaken::ExtraBits::contents_glob_IO,
       tracked_types => [ 'GLOB', 'IO' ],
     });
  is ($leaks, undef, 'deep garbage collection');
  if ($leaks && defined &explain) {
    diag "Test-Weaken ", explain $leaks;
  }
}

exit 0;
