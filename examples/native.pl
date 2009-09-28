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


# Native use of File::Locate::Iterator.

use strict;
use warnings;
use File::Locate::Iterator;

my $it = File::Locate::Iterator->new;
my $count = 0;

while (defined (my $entry = $it->next)) {
  print $entry,"\n";

  if ($count++ > 10) {
    print "...\n";
    last;
  }
}
exit 0;
