#!/usr/bin/perl -w

# Copyright 2009, 2010 Kevin Ryde.
#
# This file is part of File-Locate-Iterator.
#
# File-Locate-Iterator is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# File-Locate-Iterator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with File-Locate-Iterator; see the file COPYING.  Failing that, go to
# <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use POSIX;
my $status = 256;

printf "status %#X\n", $status;
if (WIFEXITED($status)) {
  print "exit ",WEXITSTATUS($status),"\n";
} elsif (WIFSIGNALED($status)) {
  print "signal ",WTERMSIG($status),"\n";
} else {
  print "unknown\n";
}
exit 0;
