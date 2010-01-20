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


## no critic (ProhibitCallsToUndeclaredSubs)

use strict;
use warnings;
use Test::More;

eval 'use Test::Synopsis; 1'
  or plan skip_all => "due to Test::Synopsis not available -- $@";

plan tests => 1;
synopsis_ok('lib/File/Locate/Iterator.pm');

exit 0;
