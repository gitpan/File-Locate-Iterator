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
use 5.006;
use strict;
use warnings;
use Carp;
use File::FnMatch;
    
sub _UNEXPECTED_EOF {
  my ($self) = @_;
  undef $self->{'entry'};
  croak 'Invalid database contents (unexpected EOF)';
}
sub _ERROR_READING {
  my ($self) = @_;
  undef $self->{'entry'};
  croak 'Error reading database: ',$!;
}
sub _BAD_SHARE {
  my ($self, $sharelen) = @_;
  undef $self->{'entry'};
  croak "Invalid database contents (bad share length $sharelen)";
}
sub next {
  my ($self) = @_;

  my $sharelen = $self->{'sharelen'};
  my $entry = $self->{'entry'};
  my $regexp = $self->{'regexp'};
  my $globs = $self->{'globs'};

  if (exists $self->{'mref'}) {
    my $mref = $self->{'mref'};
    my $pos = $self->{'pos'};
  MREF_LOOP: for (;;) {
      if (DEBUG >= 2) { printf "pos in map %#x\n", $pos; }
      if ($pos >= length ($$mref)) {
        undef $self->{'entry'};
        return; # end of file
      }

      my ($adjshare) = unpack 'c', substr ($$mref, $pos++, 1);
      if ($adjshare == -128) {
        if (DEBUG >= 2) { printf "  2byte pos %#X\n", $pos; }
        # print ord(substr ($$mref,$pos,1)),"\n";
        # print ord(substr ($$mref,$pos+1,1)),"\n";

        if ($pos+2 > length ($$mref)) { goto &_UNEXPECTED_EOF; }

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
        push @_, $sharelen; goto &_BAD_SHARE;
      }

      my $end = index ($$mref, "\0", $pos);
      # print "$pos to $end\n";
      if ($end < 0) { goto &_UNEXPECTED_EOF; }

      $entry = (substr($entry,0,$sharelen)
                . substr ($$mref, $pos, $end-$pos));
      $pos = $end + 1;

      if ($regexp) {
        last if $entry =~ $regexp;
      } elsif (! $globs) {
        last;
      }
      if ($globs) {
        foreach my $glob (@$globs) {
          last MREF_LOOP if File::FnMatch::fnmatch($glob,$entry)
        }
      }
    }
    $self->{'pos'} = $pos;

  } else {
    local $/ = "\0"; # readline() to \0

    my $fh = $self->{'fh'};
    if (DEBUG) { printf "pos tell(fh)=%#x\n",tell($fh); }
  IO_LOOP: for (;;) {
      my $adjshare;
      unless (my $got = read $fh, $adjshare, 1) {
        if (defined $got) {
          undef $self->{'entry'};
          return; # EOF
        }
        goto &_ERROR_READING;
      }

      ($adjshare) = unpack 'c', $adjshare;
      if ($adjshare == -128) {
        my $got = read $fh, $adjshare, 2;
        if (! defined $got) { goto &_ERROR_READING; }
        if ($got != 2) { goto &_UNEXPECTED_EOF; }

        # for perl 5.10 up could use 's>' for signed 16-bit big-endian
        # pack, instead of getting unsigned and stepping down
        ($adjshare) = unpack 'n', $adjshare;
        if ($adjshare >= 32768) { $adjshare -= 65536; }
      }
      if (DEBUG) { print "adjshare $adjshare\n"; }

      $sharelen += $adjshare;
      if (DEBUG) { print "share now $sharelen\n"; }
      if ($sharelen < 0 || $sharelen > length($entry)) {
        push @_, $sharelen; goto &_BAD_SHARE;
      }

      my $part;
      {
        # perlfunc.pod of 5.10.0 for readline() says you can clear $!
        # then check it afterwards for an error indication, but that's
        # wrong, $! ends up set to EBADF when filling the PerlIO buffer,
        # which means if the readline crosses a 1024 byte boundary
        # (something in attempting a fast gets then falling back ...)

        $part = readline $fh;
        if (! defined $part) { goto &_UNEXPECTED_EOF; }

        if (DEBUG) { print "part '$part'\n"; }
        chomp $part or goto &_UNEXPECTED_EOF;
      }

      $entry = substr($entry,0,$sharelen) . $part;

      if ($regexp) {
        last if $entry =~ $regexp;
      } elsif (! $globs) {
        last;
      }
      if ($globs) {
        foreach my $glob (@$globs) {
          last IO_LOOP if File::FnMatch::fnmatch($glob,$entry)
        }
      }
    }
  }

  $self->{'sharelen'} = $sharelen;
  return ($self->{'entry'} = $entry);
}

1;
