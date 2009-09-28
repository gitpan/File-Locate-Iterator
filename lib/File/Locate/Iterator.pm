# Copyright 2009 Kevin Ryde.
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

$VERSION = 1;

use constant DEBUG => 0;

use constant default_database_file => '/var/cache/locate/locatedb';
use constant default_use_mmap      => 0;

use constant _HEADER => "\0LOCATE02\0";

sub new {
  my ($class, %options) = @_;

  my @regexps = (defined $options{'regexp'} ? ($options{'regexp'}) : (),
                 @{$options{'regexps'} || []});
  foreach my $suffix (defined $options{'suffix'} ? $options{'suffix'} : (),
                      @{$options{'suffixes'}}) {
    push @regexps, quotemeta($suffix) . '$';
  }
  foreach my $glob (defined $options{'glob'} ? $options{'glob'} : (),
                    @{$options{'globs'}}) {
    push @regexps, _glob_to_regex_string($glob);
  }
  my $re = join ('|', @regexps);
  $re = qr/$re/;

  my $self = bless { regexp   => $re,
                     entry    => '',
                     sharelen => 0,
                   }, $class;

  if (defined (my $str = $options{'database_str'})) {
    $self->{'mref'} = \$str;

  } else {
    my $fh = $options{'database_fh'};
    if (! defined $fh) {
      my $file = (defined $options{'database_file'}
                  ? $options{'database_file'}
                  : $class->default_database_file);

      open $fh, '<', $file
        or die "Cannot open $file: $!";
    }
    my $use_mmap = $options{'use_mmap'} || 0;
    if ($use_mmap eq 'if_sensible') {
      require Config;
      my $address_percent = 1.0 / 4;
      my $limit = (256 ** $Config::Config{'ptrsize'}) * $address_percent / 100;
      if (DEBUG) { print "mmap size limit $limit\n"; }
      if (-s $fh > $limit) {
        if (DEBUG) { print "file size ",-s $fh," too big\n"; }
        $use_mmap = 0;
      } else {
        $use_mmap = 'if_possible';
      }
    }
    if ($use_mmap) {
      if (DEBUG) { print "attempt mmap $fh size ",-s $fh,"\n"; }

      # There's many ways an mmap can fail.  Even an ordinary readable file
      # can fail on linux kernel post 2.6.12 (or some such) if it's empty,
      # since it's not possible to mmap length==0 there.
      if ($use_mmap eq 'if_possible') {
        if (! eval { $self->{'fm'}
                       = File::Locate::Iterator::FileMap->get($fh) }) {
          if (DEBUG) { print "mmap failed: $@\n"; }
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
    my $header = _HEADER;
    unless ($$mref =~ /\Q$header/) {
    BAD_HEADER:
      undef $self->{'entry'};
      croak "Invalid database contents (no LOCATE02 header)";
    }
    $self->{'pos'} = length(_HEADER);
  } else {
    my $header = '';
    read $self->{'fh'}, $header, length(_HEADER);
    if ($header ne _HEADER) { goto BAD_HEADER; }
  }

  return $self;
}

# return true if mmap is in use
# (an actual mmap, not the slightly similar 'database_str' option)
sub _using_mmap {
  my ($self) = @_;
  return defined $self->{'fm'};
}

BEGIN {
  @ISA = ('DynaLoader');
  require DynaLoader;
  if (eval { bootstrap File::Locate::Iterator $VERSION }) {
    if (DEBUG) { print "FLI next() from xs\n"; }

  } else {
    if (DEBUG) { print "FLI next() in perl (XS didn't load -- $@)\n"; }

    *next = sub {
      my ($self) = @_;

      my $sharelen = $self->{'sharelen'};
      my $entry = $self->{'entry'};

      if (exists $self->{'mref'}) {
        my $mref = $self->{'mref'};
        my $pos = $self->{'pos'};
        for (;;) {
          if (DEBUG >= 2) { printf "pos %#X\n", $pos; }
          if ($pos >= length ($$mref)) {
            undef $self->{'entry'};
            return; # end of file
          }

          my ($adjshare) = unpack 'c', substr ($$mref, $pos++, 1);
          if ($adjshare == -128) {
            if (DEBUG >= 2) { printf "  2byte pos %#X\n", $pos; }
            # print ord(substr ($$mref,$pos,1)),"\n";
            # print ord(substr ($$mref,$pos+1,1)),"\n";

            if ($pos+2 > length ($$mref)) {
            UNEXPECTED_EOF:
              undef $self->{'entry'};
              croak 'Invalid database contents (unexpected EOF)';
            }

            # for perl 5.10 up could use 's>' for signed 16-bit big-endian pack,
            # instead of getting unsigned and stepping down
            ($adjshare) = unpack 'n', substr ($$mref, $pos, 2);
            if ($adjshare >= 32768) { $adjshare -= 65536; }

            $pos += 2;
          }
          if (DEBUG >= 2) { print "adjshare $adjshare\n"; }
          $sharelen += $adjshare;
          # print "share now $sharelen\n";
          if ($sharelen < 0 || $sharelen > length($entry)) {
          BAD_SHARE:
            undef $self->{'entry'};
            croak "Invalid database contents (bad share length $sharelen)";
          }

          my $end = index ($$mref, "\0", $pos);
          # print "$pos to $end\n";
          if ($end < 0) { goto UNEXPECTED_EOF; }

          my $part = substr ($$mref, $pos, $end-$pos);
          # print "part '$part'\n";
          $entry = (substr($entry,0,$sharelen)
                    . substr ($$mref, $pos, $end-$pos));
          $pos = $end + 1;

          last if $entry =~ $self->{'regexp'};
        }
        $self->{'pos'} = $pos;

      } else {
        local $/ = "\0"; # readline() to \0

        my $fh = $self->{'fh'};
        if (DEBUG) { printf "pos %#x\n",tell($fh); }
        for (;;) {
          my $adjshare;
          unless (my $got = read $fh, $adjshare, 1) {
            if (defined $got) {
              undef $self->{'entry'};
              return; # EOF
            }
          ERROR_READING:
            undef $self->{'entry'};
            croak "Error reading database: $!";
          }

          ($adjshare) = unpack 'c', $adjshare;
          if ($adjshare == -128) {
            my $got = read $fh, $adjshare, 2;
            if (! defined $got) { goto ERROR_READING; }
            if ($got != 2) { goto UNEXPECTED_EOF; }

            # for perl 5.10 up could use 's>' for signed 16-bit big-endian pack,
            # instead of getting unsigned and stepping down
            ($adjshare) = unpack 'n', $adjshare;
            if ($adjshare >= 32768) { $adjshare -= 65536; }
          }
          if (DEBUG) { print "adjshare $adjshare\n"; }

          $sharelen += $adjshare;
          if (DEBUG) { print "share now $sharelen\n"; }
          if ($sharelen < 0 || $sharelen > length($entry)) {
            goto BAD_SHARE;
          }

          my $part;
          {
            # the perlfunc docs for readline() say you can clear $! then check
            # it afterwards for an error indication, but in perl 5.10.0 $! seems
            # to be set to EBADF when there's a read into the buffer on $fh,
            # which is when the readline crosses into a new 1024 byte block.
            #
            # undef $!;
            # if ($!) { goto ERROR_READING; }

            $part = readline $fh;
            if (! defined $part) { goto UNEXPECTED_EOF; }

            if (DEBUG) { print "part '$part'\n"; }
            chomp $part or goto UNEXPECTED_EOF;
          }

          $entry = substr($entry,0,$sharelen) . $part;

          last if $entry =~ $self->{'regexp'};
        }
      }

      $self->{'sharelen'} = $sharelen;
      return ($self->{'entry'} = $entry);
    }
  }
}

# Maybe ...
#
# =item C<< $entry = $it->current >>
#
# Return the current entry from the database, meaning the same as the last
# call to C<next> returned.  At the start of the database (before any C<next>)
# or at end of file the return is C<undef>.
sub _current {
  my ($self) = @_;
  return $self->{'entry'};
}

# Per info node "(find)Shell Pattern Matching", not the same as Text::Glob.
#     *             -- 0 or more chars, including /
#     ?             -- 1 char, including /
#     [abc]         -- char class
#     [^abc],[!abc] -- negated char class
#     \             -- remove special meaning, incl in char class
#
sub _glob_to_regex_string {
  my ($str) = @_;
  my $saw_wild;

  $str =~ s{(\[(?:\\.|[^\\\]])*\])  # $1 char class
            |\\(.)                  # $2 backslashed
            |(\W)}{                 # $3 other non-plain
    (defined $1   ? ($saw_wild = _glob_char_class_to_regex($1))
     : defined $2 ? do { print "backslash $2\n"; quotemeta($2) }
     : $3 eq '?'  ? ($saw_wild = '.')
     : $3 eq '*'  ? ($saw_wild = '.*')
     : quotemeta($3))
      }xsge;

  # any wildcard in the pattern means anchor to start and end
  if (defined $saw_wild) {
    $str = '^'.$str.'$';
  }
  # but can optimize away leading "^.*" or trailing ".*$" anything at start/end
  $str =~ s/^\^(\.\*)+//;
  $str =~ s/(\.\*)+\$$//;

  return $str;
}
sub _glob_char_class_to_regex {
  my ($str) = @_;
  $str =~ s/^\[!/[^/;    # [! negation -> [^
  $str =~ s/\\(\w)/$1/g; # \ backslashed word char -> unbackslashed literal
  return $str;
}


package File::Locate::Iterator::FileMap;
use File::Map;
use Scalar::Util;
use constant DEBUG => 0;
our %cache;

sub get {
  my ($class, $fh) = @_;

  my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size) = stat ($fh);
  my $key = "$dev,$ino,$size";
  if (DEBUG) { print "FileMap get $fh, key=$key, size ",-s $fh,"\n"; }
  return ($cache{$key} || do {
    my $self = bless { key => $key }, $class;
    File::Map::map_handle ($self->{'mmap'}, $fh);
    Scalar::Util::weaken ($cache{$key} = $self);
    $self;
  });
}
sub mmap_ref {
  my ($self) = @_;
  return \$self->{'mmap'};
}
sub DESTROY {
  my ($self) = @_;
  delete $cache{$self->{'key'}};
}

sub _total_space_used {
  require List::Util;
  my $page_size = _page_size();
  return List::Util::sum (map {my $size = (split ',')[2];
                               int ($size + $page_size - 1 / $page_size) }
                          keys %cache);
}
{
  my $page_size;
  sub _page_size {
    if (! defined $page_size) {
      require POSIX;
      $page_size = eval { POSIX::sysconf (POSIX::_SC_PAGESIZE()) } || -1;
      if ($page_size <= 0) { $page_size = 1024; }
    }
    return $page_size;
  }
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

Locate databases normally hold filenames, as a way of finding files faster
than churning through all directories.  Optional glob, suffix and regexp
options on the iterator let you restrict the entries returned.

Only "LOCATE02" files are supported, per current versions of GNU C<locate>,
not the "slocate" format.

The iterators from this module are stand-alone, they don't need any of the
various iterator module frameworks.  See L<Iterator::Locate> or
L<Iterator::Simple::Locate> to inter-operate with those frameworks.  They
have the advantage of various convenient ways to grep, map or manipulate the
iterated sequence.

=head1 FUNCTIONS

=over 4

=item C<< $it = File::Locate::Iterator->new (key=>value,...) >>

Create and return a new locate iterator object.  The following following
optional key/value pairs are available,

=over 4

=item C<database_file> (default the system locate database)

=item C<database_fh>

The file to read, either by filename or file handle.  The default is per
C<default_database_file> below, usually F</var/cache/locate/locatedb>.

    $it = File::Locate::Iterator->new
            (database_file => '/foo/bar.db');

=item C<suffix> (string)

=item C<suffixes> (arrayref of strings)

=item C<glob> (string)

=item C<globs> (arrayref of strings)

=item C<regexp> (string or regexp object)

=item C<regexps> (arrayref of string)

Restrict the entries returned to those of given suffix(es) or matching the
given glob(s) or regexp(s).  For example,

    # C code files on the system
    $it = File::Locate::Iterator->new
            (suffixes => ['.c','.h']);

Globs are in the style of the C<locate> program, which means "*" for zero or
more chars (including slashes), "?" for one char, "[abc]" char classes and
"[^abc]" or "[!abc]" negated classes.  Backslash "\" escapes any char.  A
pattern without wildcards matches anywhere, but with any wildcard it's
anchored to start and end (use leading or trailing "*" to avoid that).

=back

=item C<< $entry = $it->next >>

Return the next entry from the database, or an empty list at end of file.
Recall that an empty list return means C<undef> in scalar context or no
values in array context.  So you can loop with either

    while (defined (my $filename = $it->next)) ...

or

    while (my ($filename) = $it->next) ...

=item C<< $filename = File::Locate::Iterator->default_database_file >>

Return the default database file used in C<new> above.  Currently this is
always F</var/cache/locate/locatedb>, though the intention is to make it the
system default, if that can be found easily.

=back

=head1 FILES

=over 4

=item F</var/cache/locate/locatedb>

Default locate database.

=back

=head1 OTHER WAYS

The plain C<File::Locate> reads a locate database with callbacks.  Whether
you prefer callbacks or an iterator is a matter of style.  Iterators let you
write your own loop, and you can have a few of searches on the go
simultaneously.

Iterators are also good for cooperative coroutining like C<POE> or C<Gtk>
where you must hold state in some sort of variable, to be progressed by
callbacks from the main loop.  (Note that C<next> will block reading from
the database, so the database generally should be a plain file rather than a
socket or something, so as not to hold up a main loop.)

=head1 SEE ALSO

L<File::Locate>, L<Iterator::Locate>, L<Iterator::Simple::Locate>,
C<locate(1)> and the GNU Findutils manual

=head1 FUTURE

The current implementation is pure-Perl and for that reason isn't very fast.
Some XS (in progress) should make it as fast as C<File::Locate> in the
future.

Currently each C<File::Locate::Iterator> holds a separate open handle on the
database, which means a file descriptor and buffering per iterator.  In the
future hopefully some sharing between iterators can reduce resource
requirements.

Sharing an open handle between iterators with each seeking to its desired
position would be possible, but a seek drops buffered data and so would go
slower than ever.  There's some secret undocumented mmap code in progress
which should be both small and fast, when an mmap is possible, and isn't so
huge as to eat up all your address space.

Glob patterns are converted to Perl regexps for matching.  It might be worth
making that public or splitting it out.  It's slightly different from what
C<Text::Glob> does.  (If you want shell globs then convert with
C<Text::Glob> and pass as regexps to C<new> above.)

=head1 HOME PAGE

http://user42.tuxfamily.org/file-locate-iterator/index.html

=head1 COPYRIGHT

Copyright 2009 Kevin Ryde

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
