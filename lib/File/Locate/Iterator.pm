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


package File::Locate::Iterator;
use 5.006;  # for qr//, and open anon handles
use strict;
use warnings;
use Carp;
use vars ('$VERSION', '@ISA');

BEGIN {
  $VERSION = 7;
}

use constant DEBUG => 0;

use constant default_database_file => '/var/cache/locate/locatedb';
use constant default_use_mmap      => 0;

my $header = "\0LOCATE02\0";

BEGIN {
  require DynaLoader;
  @ISA = ('DynaLoader');
  if (eval { bootstrap File::Locate::Iterator $VERSION }) {
    if (DEBUG) { print "FLI next() from xs\n"; }
  } else {
    if (DEBUG) { print "FLI next() in perl (XS didn't load -- $@)\n"; }
    require File::Locate::Iterator::PP;
  }
}

sub new {
  my ($class, %options) = @_;

  my @regexps = (defined $options{'regexp'} ? ($options{'regexp'}) : (),
                 @{$options{'regexps'} || []});
  foreach my $suffix (defined $options{'suffix'} ? $options{'suffix'} : (),
                      @{$options{'suffixes'}}) {
    push @regexps, quotemeta($suffix) . '$';
  }

  # as per findutils locate.c locate() function, pattern with * ? or [ is a
  # glob, anything else is a literal match
  #
  my @globs = (defined $options{'glob'} ? $options{'glob'} : (),
               @{$options{'globs'} || []});
  @globs = grep { ($_ =~ /[[*?]/
                   || do { push @regexps, quotemeta($_); 0 })
                } @globs;

  my $self = bless { entry    => '',
                     sharelen => 0,
                   }, $class;

  if (@regexps) {
    my $regexp = join ('|', @regexps);
    $self->{'regexp'} = qr/$regexp/s;
  }
  if (@globs) {
    $self->{'globs'} = \@globs;
  }

  if (DEBUG) { print "regexp ",
                 (defined $self->{'regexp'} ? $self->{'regexp'} : 'undef'),
                   " globs ",
                     (defined $self->{'globs'} ? @{$self->{globs}} : 'undef'),
                       "\n"; }

  if (defined (my $str = $options{'database_str'})) {
    $self->{'mref'} = \$str;

  } else {
    my $use_mmap = (defined $options{'use_mmap'}
                    ? $options{'use_mmap'}
                    : default_use_mmap);
    if (DEBUG) { print "use_mmap=$use_mmap\n"; }

    my $fh = $options{'database_fh'};
    if (defined $fh) {
      if ($use_mmap) {
        if (defined (my $layer = _bad_layer($fh))) {
          if ($use_mmap eq '1') {
            croak "database_fh layer '$layer' no good for mmap";
          }
          $use_mmap = 0;
        } elsif ($use_mmap eq 'if_sensible' && _have_mmap_layer($fh)) {
          # if already a :mmap perlio layer don't mmap again
          $use_mmap = 0;
        }
      }
    } else {
      my $file = (defined $options{'database_file'}
                  ? $options{'database_file'}
                  : $class->default_database_file);
      if (DEBUG) { print "open database_file $file\n"; }
      open $fh, '<', $file
        or die "Cannot open $file: $!";
    }

    if ($use_mmap eq 'if_sensible') {
      $use_mmap = (_mmap_size_excessive($fh)
                   ? 0
                   : 'if_possible');
    }

    if ($use_mmap) {
      if (DEBUG) { print "attempt mmap $fh size ",(-s $fh),"\n"; }

      # There's many ways an mmap can fail, just chuck an eval on FileMap /
      # File::Map it to catch them all.
      # - An ordinary readable file of length zero may fail per POSIX, and
      #   that's how it is in linux kernel post 2.6.12.  However File::Map
      #   0.20 takes care of returning an empty string for that.
      # - A char special usually gives 0 for its length, even for instance
      #   linux kernel special files like /proc/meminfo.  Char specials can
      #   often be mapped perfectly well, but without a length don't know
      #   how much to look at.  For that reason if_possible restricts to
      #   ordinary files, though forced use_mmap=>1 just goes ahead anyway.
      #
      if ($use_mmap eq 'if_possible') {
        if (-f $fh) {
          if (! eval { $self->{'fm'}
                         = File::Locate::Iterator::FileMap->get($fh) }) {
            if (DEBUG) { print "mmap failed: $@\n"; }
          }
        } else {
          $self->{'fm'} = File::Locate::Iterator::FileMap->get($fh);
        }
      }
    }
    if ($self->{'fm'}) {
      $self->{'mref'} = $self->{'fm'}->mmap_ref;
    } else {
      $self->{'fh'} = $fh;
    }
  }


  if (exists $self->{'mref'}) {
    my $mref = $self->{'mref'};
    unless ($$mref =~ /^\Q$header/o) { goto &_ERROR_BAD_HEADER }
    $self->{'pos'} = length($header);
  } else {
    my $got = '';
    read $self->{'fh'}, $got, length($header);
    if ($got ne $header) { goto &_ERROR_BAD_HEADER }
  }

  return $self;
}
sub _ERROR_BAD_HEADER {
  croak 'Invalid database contents (no LOCATE02 header)';
}


# return true if mmap is in use
# (an actual mmap, not the slightly similar 'database_str' option)
# this is meant for internal use as a diagnostic ...
sub _using_mmap {
  my ($self) = @_;
  return defined $self->{'fm'};
}

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

  # - Pointer size times 8 bits, then 2**N for total pointer address space,
  #   eg. 2**32 for a 32-bit system.
  # - Then often only 1/2 or 1/4 of that available for data, so * 0.25,
  #   eg. 1Gbyte on a 32-bit system
  # - Then cap ourselves at 1/5 of that likely space, eg. 200Mbyte on a
  #   32-bit system.
  # 
  require Config;
  my $limit = (2 ** (8 * $Config::Config{'ptrsize'})) * 0.25 * 0.2;

  my $prosp = File::Locate::Iterator::FileMap::_total_space (-s $fh);
  if (DEBUG) {
    print "mmap size limit $limit\n";
    print "  file size ",(-s $fh)," for new total $prosp\n";
  }
  if (DEBUG) { if ($prosp > $limit) { print "  too big\n"; } }
  return ($prosp > $limit);
}

# Not yet documented, likely worthwhile as long as it works properly ...
#
# =item C<< $entry = $it->current >>
#
# Return the current entry from the database, meaning the same as the last
# call to C<next> returned.  At the start of the database (before any C<next>)
# or at end of file the return is C<undef>.
#
sub _current {
  my ($self) = @_;
  return $self->{'entry'};
}


#------------------------------------------------------------------------------

package File::Locate::Iterator::FileMap;
use strict;
use warnings;
use Scalar::Util;
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
    File::Map->VERSION('0.20'); # for 
    my $self = bless { key => $key }, $class;

    # explicit \$foo since no prototype when only "require File::Map"
    File::Map::map_handle (\$self->{'mmap'}, $fh, '<');
    File::Map::advise (\$self->{'mmap'}, 'sequential');

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
  return int ($n + _PAGESIZE() - 1 / _PAGESIZE());
}

1;
__END__

=head1 NAME

File::Locate::Iterator -- read "locate" database with an iterator

=head1 SYNOPSIS

 use File::Locate::Iterator;
 my $it = File::Locate::Iterator->new;
 while (defined (my $entry = $it->next)) {
   print $entry,"\n";
 }

=head1 DESCRIPTION

C<File::Locate::Iterator> reads a "locate" database file in iterator style.
Each C<next()> call on the iterator returns the next entry from the
database.

Locate databases normally hold filenames as a way of finding files faster
than churning through directories on the filesystem.  Optional glob, suffix
and regexp options on the iterator let you restrict the entries returned.

Only "LOCATE02" format files are supported per current versions of GNU
C<locate>, not the "slocate" format.

Iterators from this module are stand-alone, they don't need any of the
various iterator frameworks.  See L<Iterator::Locate> and
L<Iterator::Simple::Locate> for inter-operating with those frameworks.  The
frameworks have the advantage of convenient ways to grep, map or manipulate
the iterated sequence.

=head1 FUNCTIONS

=over 4

=item C<< $it = File::Locate::Iterator->new (key=>value,...) >>

Create and return a new locate database iterator object.  The following
optional key/value pairs are available,

=over 4

=item C<database_file> (default the system locate database)

=item C<database_fh>

The file to read, either as filename or file handle.  The default is the
C<default_database_file> below.

    $it = File::Locate::Iterator->new
            (database_file => '/foo/bar.db');

A filehandle is read with the usual C<PerlIO>, so it can come from various
sources, but should generally be in binary mode.

=item C<suffix> (string)

=item C<suffixes> (arrayref of strings)

=item C<glob> (string)

=item C<globs> (arrayref of strings)

=item C<regexp> (string or regexp object)

=item C<regexps> (arrayref of strings or regexp objects)

Restrict the entries returned to those with given suffix(es) or matching the
given glob(s) or regexp(s).  For example,

    # C code files on the system, .c and .h
    $it = File::Locate::Iterator->new
            (suffixes => ['.c','.h']);

If multiple patterns or suffixes are given then matches of any are returned.

Globs are in the style of the C<locate> program, which means C<fnmatch> with
no options (see L<File::FnMatch>) and the pattern must match the full entry,
except that a fixed string (none of "*", "?" or "[") can match anywhere.

=back

=item C<< $entry = $it->next >>

Return the next entry from the database, or no values at end of file.
Recall that an empty return means C<undef> in scalar context or no values in
array context so you can loop with either

    while (defined (my $filename = $it->next)) ...

or

    while (my ($filename) = $it->next) ...

The return is a byte string since it's normally a filename (and as of Perl
5.10 filenames are handled as byte strings).

=item C<< $filename = File::Locate::Iterator->default_database_file >>

Return the default database file used in C<new> above.  This is meant to be
the same as the C<locate> program uses and currently means
F</var/cache/locate/locatedb>, but in the future it may be possible to check
how C<findutils> has been installed, or maybe even follow C<LOCATE_PATH>.

=back

=head1 FILES

=over 4

=item F</var/cache/locate/locatedb>

Default locate database.

=back

=head1 OTHER WAYS TO DO IT

C<File::Locate> reads a locate database with callbacks.  Whether you prefer
callbacks or an iterator is a matter of style.  Iterators let you write your
own loop and can have multiple searches in progress simultaneously.

Iterators are good for cooperative coroutining like C<POE> or C<Gtk> where
you must hold state in some sort of variable to be progressed by callbacks
from the main loop.  (Note that C<next()> waits while reading from the
database, so the database generally should be a plain file rather than a
socket or something, so as not to hold up a main loop.)

When C<File::Locate> is built with its XSUB code (requires Perl 5.10.0 or
higher currently) the speed of an iterator is about the same as callbacks.

Currently each C<File::Locate::Iterator> holds a separate open handle on the
database, which means a file descriptor and PerlIO buffering per iterator.
In the future hopefully some sharing among iterators can reduce resource
requirements.

Sharing an open handle between iterators with each seeking to its desired
position would be possible, but a seek drops buffered data and so would go
slower than ever.  There's some secret undocumented C<mmap> code which
should be both small and fast when an C<mmap> is possible and isn't so huge
as to eat up all your address space.

=head1 SEE ALSO

L<File::Locate>, L<Iterator::Locate>, L<Iterator::Simple::Locate>,
C<locate(1)> and the GNU Findutils manual, L<File::FnMatch>

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
