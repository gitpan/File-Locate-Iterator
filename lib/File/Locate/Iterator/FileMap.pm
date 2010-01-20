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

package File::Locate::Iterator::FileMap;
use 5.006;
use strict;
use warnings;
use Scalar::Util;

our $VERSION = 8;

use constant DEBUG => 0;

our %cache;

sub _key {
  my ($fh) = @_;
  my ($dev, $ino, undef, undef, undef, undef, undef, $size) = stat ($fh);
  return "$dev,$ino,$size";
}
sub find {
  my ($class, $fh) = @_;
  return $cache{_key($fh)};
}

# return a FileMap object which is $fh mmapped
sub get {
  my ($class, $fh) = @_;

  my $key = _key($fh);
  if (DEBUG) { print "cache get $fh, key=$key, size ",-s $fh,"\n"; }
  return ($cache{$key} || do {
    require File::Map;
    File::Map->VERSION('0.20'); # for empty file as empty string
    my $self = bless { key => $key }, $class;

    # explicit \$foo since no prototype when only "require File::Map", and
    # "&" calls to defeat if File::Map is in fact already loaded :-(
    &File::Map::map_handle (\$self->{'mmap'}, $fh, '<');
    &File::Map::advise (\$self->{'mmap'}, 'sequential');

    Scalar::Util::weaken ($cache{$key} = $self);
    $self;
  });
}
# return a scalar ref to the mmapped string
sub mmap_ref {
  my ($self) = @_;
  return \($self->{'mmap'});
}
sub DESTROY {
  my ($self) = @_;
  delete $cache{$self->{'key'}};
}

use constant::defer _PAGESIZE => sub {
  require POSIX;
  my $pagesize = eval { POSIX::sysconf (POSIX::_SC_PAGESIZE()) } || -1;
  return ($pagesize > 0 ? $pagesize : 1024);
};

# return the total bytes used by mmaps here plus prospective further $space
sub _total_space {
  my ($space) = @_;
  if (DEBUG) { print "total space of $space + ",values %cache,"\n"; }
  $space = _round_up_pagesize($space);
  foreach my $self (values %cache) {
    $space += _round_up_pagesize (length (${$self->mmap_ref}));
  }
  return $space;
}
sub _round_up_pagesize {
  my ($n) = @_;

  my $pagesize = _PAGESIZE();
  return $pagesize * int (($n + $pagesize - 1) / $pagesize);
}

#-----------------------------------------------------------------------------

# return true if $fh has an ":mmap" layer
sub _have_mmap_layer {
  my ($fh) = @_;
  my $ret;
  eval {
    require PerlIO; # new in perl 5.8
    foreach my $layer (PerlIO::get_layers ($fh)) {
      if ($layer eq 'mmap') { $ret = 1; last; }
    }
  };
  return $ret;
}

# return the name of a layer bad for mmap, or undef if all ok
my %acceptable_layers = (unix => 1, perlio => 1, mmap => 1);
sub _bad_layer {
  my ($fh) = @_;
  my $bad_layer;
  eval {
    require PerlIO; # new in perl 5.8
    foreach my $layer (PerlIO::get_layers ($fh)) {
      if (! $acceptable_layers{$layer}) {
        if (DEBUG) { print STDERR "layer '$layer' no good for mmap\n"; }
        $bad_layer = $layer;
        last;
      }
    }
  };
  return $bad_layer;
}

# return true if mmapping $fh would be an excessive cumulative size
sub _mmap_size_excessive {
  my ($fh) = @_;
  if (File::Locate::Iterator::FileMap->find($fh)) {
    # if already mapped then not excessive
    return 0;
  }

  # in 32-bits this is 4G*(1/4)*(1/5) which is 200Mb
  require Config;
  my $limit
    = (2 ** (8 * $Config::Config{'ptrsize'}))  # eg. 2^32 bytes addr space
      * 0.25   # perhaps only 1/2 or 1/4 of it usable for data
        * 0.2; # then don't go past 1/5 of that usable space

  my $prosp = File::Locate::Iterator::FileMap::_total_space (-s $fh);
  if (DEBUG) {
    print "mmap size limit $limit\n";
    print "  file size ",(-s $fh)," for new total $prosp\n";
  }
  if (DEBUG) { if ($prosp > $limit) { print "  too big\n"; } }
  return ($prosp > $limit);
}

1;
__END__

=head1 NAME

File::Locate::Iterator::FileMap -- shared mmaps for File::Locate::Iterator

=head1 DESCRIPTION

This is an internal part of C<File::Locate::Iterator>.  A FileMap object
holds a file mmapped by C<File::Map> and will re-use it rather than mapping
the same file a second time.

=head1 SEE ALSO

L<File::Locate::Iterator>, L<File::Map>

=head1 HOME PAGE

http://user42.tuxfamily.org/file-locate-iterator/index.html

=head1 COPYRIGHT

Copyright 2009, 2010 Kevin Ryde

File-Locate-Iterator is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option) any
later version.

File-Locate-Iterator is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along with
File-Locate-Iterator.  If not, see http://www.gnu.org/licenses/

=cut
