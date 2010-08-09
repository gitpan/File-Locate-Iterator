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

use DynaLoader;
our @ISA = ('DynaLoader');

# uncomment this to run the ### lines
#use Smart::Comments;

our $VERSION = 11;

use constant default_use_mmap => 'if_sensible';
my $header = "\0LOCATE02\0";

if (eval { File::Locate::Iterator->bootstrap($VERSION) }) {
  ### FLI next() from XS
} else {
  ### FLI next() in perl, XS didn't load: $@
  require File::Locate::Iterator::PP;
}


# default path these days is /var/cache/locate/locatedb
#
# back in findutils 4.1 it was $(localstatedir)/locatedb, but there seems to
# have been no way to ask about the location
#
sub default_database_file {
  # my ($class) = @_;
  if (defined (my $env = $ENV{'LOCATE_PATH'})) {
    return $env;
  } else {
    return '/var/cache/locate/locatedb';
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

  ### regexp: $self->{'regexp'}
  ### globs : defined $self->{'globs'}

  if (defined (my $str = $options{'database_str'})) {
    $self->{'mref'} = \$str;

  } else {
    my $use_mmap = (defined $options{'use_mmap'}
                    ? $options{'use_mmap'}
                    : $class->default_use_mmap);
    ### $use_mmap
    if ($use_mmap) {
      if (! eval { require File::Locate::Iterator::FileMap }) {
        ### FileMap not possible: $@
        $use_mmap = 0;
      }
    }

    my $fh = $options{'database_fh'};
    if (defined $fh) {
      if ($use_mmap eq 'if_sensible'
          && File::Locate::Iterator::FileMap::_have_mmap_layer($fh)) {
        ### already have mmap layer, not sensible to mmap again
        $use_mmap = 0;
      }
    } else {
      my $file = (defined $options{'database_file'}
                  ? $options{'database_file'}
                  : $class->default_database_file);
      ### open database_file: $file

      # Crib note: '<:raw' means without :perlio buffering, whereas
      # binmode() preserves that buffering, assuming it's in the $ENV{'PERLIO'}
      # defaults.  Also :raw is not available in perl 5.6.
      open $fh, '<', $file
        or croak "Cannot open $file: $!";
      binmode($fh)
        or croak "Cannot set binary mode";
    }

    if ($use_mmap eq 'if_sensible') {
      $use_mmap = (File::Locate::Iterator::FileMap::_mmap_size_excessive($fh)
                   ? 0
                   : 'if_possible');
      ### if_sensible after size check becomes: $use_mmap
    }

    if ($use_mmap) {
      ### attempt mmap: $fh, (-s $fh)

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
        if (! -f $fh) {
          ### if_possible, not a plain file, consider not mmappable
        } else {
          if (! eval { $self->{'fm'}
                         = File::Locate::Iterator::FileMap->get($fh) }) {
            ### mmap failed: $@
          }
        }
      } else {
        $self->{'fm'} = File::Locate::Iterator::FileMap->get($fh);
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

# Not yet documented, likely worthwhile as long as it works properly.
# Return empty list for nothing yet?
#
# =item C<< $entry = $it->current >>
#
# Return the current entry from the database, meaning the same as the last
# call to C<next> returned.  At the start of the database (before the first
# C<next>) or at end of the database the return is an empty list.
#
#     while (defined $it->next) {
#         ...
#         print $it->current,"\n";
#     }
#
sub _current {
  my ($self) = @_;
  return $self->{'entry'};
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

Only "LOCATE02" format files are supported, per current versions of GNU
C<locate>, not the previous "slocate" format.

Iterators from this module are stand-alone, they don't need any of the
various iterator frameworks.  See L<Iterator::Locate> and
L<Iterator::Simple::Locate> to inter-operate with those frameworks.  The
frameworks have the advantage of convenient ways to grep, map or manipulate
iterated sequences.

=head1 FUNCTIONS

=head2 Constructor

=over 4

=item C<< $it = File::Locate::Iterator->new (key=>value,...) >>

Create and return a new locate database iterator object.  The following
optional key/value pairs are available.

=over 4

=item C<database_file> (string, default the system locate database)

=item C<database_fh> (handle ref)

The file to read, either as filename or file handle.  The default is the
C<default_database_file> below.

    $it = File::Locate::Iterator->new
            (database_file => '/foo/bar.db');

A filehandle is read with the usual C<PerlIO>, so it can come from various
sources but should generally be in binary mode.

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
except a fixed string (none of "*", "?" or "[") can match anywhere.

=item C<use_mmap> (string, default "if_sensible")

Whether to use C<mmap> to access the database.  This is fast and efficient
when it's possible.  To use mmap you must have the C<File::Map> module, the
file must fit in available address space, and for a C<database_fh> handle
there mustn't be any transforming C<PerlIO> layers.  The choices are

    undef           \
    "default"       | use mmap if sensible
    "if_sensible"   /
    "if_possible"   use mmap if possible, otherwise file I/O
    0               don't use mmap
    1               must use mmap, croak if cannot
    

Setting C<default>, C<undef> or omitted means C<if_sensible>.
C<if_sensible> uses mmap if available and the file size is reasonable, and
for C<database_fh> if it doesn't already have an C<:mmap> layer.
C<if_possible> lifts those restrictions and uses mmap whenever it can be
done.

    $it = File::Locate::Iterator->new
            (use_mmap => 'if_possible');

When multiple iterators access the same file they share the mmap.  The size
check for C<if_sensible> counts space in all C<File::Locate::Iterator>
mappings and won't go beyond 1/5 of available data space, which is assumed
to be (2**wordsize)/4 bytes.  On a 32-bit system this means 200Mb.
C<if_possible> and C<if_sensible> only map ordinary files because generally
the file size on char specials is not reliable.

=back

=back

=head2 Operations

=over 4

=item C<< $entry = $it->next >>

Return the next entry from the database, or no values at end of file.  An
empty return means C<undef> in scalar context or no values in array context
so you can loop with either

    while (defined (my $filename = $it->next)) ...

or

    while (my ($filename) = $it->next) ...

The return is a byte string since it's normally a filename and as of Perl
5.10 filenames are handled as byte strings.

=item C<< $filename = File::Locate::Iterator->default_database_file >>

Return the default database file used for C<new> above.  This is meant to be
the same as the C<locate> program uses and currently means
C<$ENV{'LOCATE_PATH'}> if set, otherwise F</var/cache/locate/locatedb>.  In
the future it might be possible to check how C<findutils> has been
installed.

=back

=head1 OTHER NOTES

On some systems C<mmap> may be a bit too "efficient", giving a process more
of the CPU than processes which make periodic system calls.  This is an OS
scheduling matter, but you might have to turn down the C<nice> or C<ionice>
if doing a lot of mmapped work.

=head1 ENVIRONMENT VARIABLES

=over 4

=item C<LOCATE_PATH>

Default locate database.

=back

=head1 FILES

=over 4

=item F</var/cache/locate/locatedb>

Default locate database, if C<LOCATE_PATH> environment variable not set.

=back

=head1 OTHER WAYS TO DO IT

C<File::Locate> reads a locate database with callbacks.  Whether you prefer
callbacks or an iterator is a matter of style.  Iterators let you write your
own loop and have multiple searches in progress simultaneously.

When C<File::Locate::Iterator> is built with its XSUB code (requires Perl
5.10.0 or higher currently) the speed of an iterator is about the same as
callbacks.

Iterators are good for cooperative coroutining like C<POE> or C<Gtk> where
state must be held in some sort of variable to be progressed by callbacks
from the main loop.  (C<next()> waits while reading from the database, so
the database generally should be a plain file rather than a socket or
something, so as not to hold up a main loop.)

If you have the recommended mmap (C<File::Map> module) then iterators share
an C<mmap> of the database file.  If not then currently each holds a
separate open handle to the database, which means a file descriptor and
PerlIO buffering per iterator.  Sharing a handle and making each seek to its
desired position would be possible, but a seek drops buffered data and so
would go slower.  Some PerlIO trickery might transparently share an fd and
have some multi-buffering.

=head1 SEE ALSO

L<File::Locate>, L<Iterator::Locate>, L<Iterator::Simple::Locate>,
C<locate(1)> and the GNU Findutils manual, L<File::FnMatch>, L<File::Map>

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
