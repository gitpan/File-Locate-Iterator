#!/usr/bin/perl -w

# Copyright 2010 Kevin Ryde

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

use strict;
use warnings;

# uncomment this to run the ### lines
use Smart::Comments;

{
  require MooseX::Iterator::Hash;
  my $it = MooseX::Iterator::Hash->new (collection => { a => 1, b=>2 });
  ### next: [ $it->next ]
  ### next: [ $it->next ]
  ### next: [ $it->next ]
  exit 0;
}

{
  require MooseX::Iterator::Array;
  # (fli => File::Locate::Iterator->new);
  my $it = MooseX::Iterator::Array->new (collection => [ 1, 2, 3]);
  print $it,"\n";
  print $it->next,"\n";
  ### peek: [ $it->peek ]
  ### next: [ $it->next ]
  ### next: [ $it->next ]
  ### next: [ $it->next ]
  exit 0;
}

{
  require MooseX::Iterator::Locate;
  # (fli => File::Locate::Iterator->new);
  my $it = MooseX::Iterator::Locate->new (glob => '*.c');
  print $it,"\n";
  print $it->next,"\n";
  print $it->peek,"\n";
  print $it->next,"\n";
  print $it->next,"\n";
  exit 0;
}
