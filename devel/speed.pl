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

use strict;
use warnings;
use Devel::TimeThis;
use File::Locate;
use File::Locate::Iterator;

my $database = '/var/cache/locate/locatedb';

{
  my $full_database = $database;
  $database = '/tmp/x.locatedb';
  system("locate --database=$full_database '*' | head -30000 | /usr/lib/locate/frcode >$database && ls -l $database") == 0
            or die;
}

{
  my $t = Devel::TimeThis->new('File-Locate all');
  File::Locate::locate ("*", $database, sub { });
}
{
  my $t = Devel::TimeThis->new('File-Locate no match');
  File::Locate::locate ('fdsjkfjsdk', $database, sub {});
}

foreach my $method ('fh', 'mmap') {
  my $use_mmap = ($method eq 'mmap');
  {
    my $t = Devel::TimeThis->new("Iterator all, $method");
    my $it = File::Locate::Iterator->new (database_file => $database,
                                          use_mmap => $use_mmap);
    while (defined ($it->next)) { }
  }
  {
    my $t = Devel::TimeThis->new("Iterator no match, $method");
    my $it = File::Locate::Iterator->new (database_file => $database,
                                          regexp => qr/^$/,
                                          use_mmap => $use_mmap);
    while (defined ($it->next)) { }
  }
}

exit 0;
