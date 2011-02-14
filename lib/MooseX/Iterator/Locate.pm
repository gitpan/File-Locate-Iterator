# Copyright 2010, 2011 Kevin Ryde

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

package MooseX::Iterator::Locate;
use 5.006;
use Carp;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Iterator::Meta::Iterable;

extends
  'File::Locate::Iterator',
  'Moose::Object'; # does() and stuff
with 'MooseX::Iterator::Role';

our $VERSION = 19;

# uncomment this to run the ### lines
#use Smart::Comments;

# meta new_object() per Moose::Cookbook::Basics::Recipe11
sub new {
  my $class = shift;
  my $self = $class->SUPER::new (@_);
  return $class->meta->new_object (__INSTANCE__ => $self, @_);
}

has 'database_file'
  => (is      => 'bare',
      isa     => 'Maybe[Str]',
      # default as subr returning value,
      # default_database_file() is dynamic from $ENV{'LOCATE_PATH'}
      default => File::Locate::Iterator->can('default_database_file'),
      documentation => 'Database file name',
     );
has 'database_fh'  => (is      => 'bare',
                       isa     => 'Maybe[FileHandle]',
                       default => undef,
                       documentation => 'Database file handle',
                      );
has 'database_str' => (is      => 'bare',
                       isa     => 'Maybe[Str]',
                       default => undef,,
                       documentation => 'Database contents in a string',
                      );
has 'suffix'
  => (is      => 'bare',
      isa     => 'Maybe[Str]',
      default => undef,
      documentation => 'A suffix to match, like ".c"',
     );
has 'suffixes'
  => (is      => 'bare',
      isa     => 'Maybe[ArrayRef[Str]]',
      default => undef,
      documentation => 'An array of suffixes, any of which to match',
     );

has 'glob'
  => (is      => 'bare',
      isa     => 'Maybe[Str]',
      default => undef,
      documentation => 'A glob pattern to match, like "*.pl"',
     );
has 'globs'
  => (is      => 'bare',
      isa     => 'Maybe[ArrayRef[Str]]',
      default => undef,
      documentation => 'An array of glob patterns, any of which to match',
     );

has 'regexp'
  => (is      => 'bare',
      isa     => 'Maybe[Str|RegexpRef]',
      default => undef,
      documentation => 'A regexp to match, like qr/ban(an)*a/',
     );
has 'regexps'
  => (is      => 'bare',
      isa     => 'Maybe[ArrayRef[Str|RegexpRef]]',
      default => undef,
      documentation => 'An array of regexps, any of which to match',
     );

# this enum not documented, is this sort of name about right?
# enum is string choices, so Maybe[] to allow undef
enum 'File::Locate::Iterator::UseMMAP'
  => qw(default if_sensible if_possible 0 1);
has 'use_mmap'
  => (is      => 'bare',
      isa     => 'Maybe[File::Locate::Iterator::UseMMAP]',
      default => 'default',
      documentation => 'Whether to use mmap() for the database (with File::Map)',
     );

# No peek() in the underlying File::Locate::Iterator as yet, so
# peek()/next() cooperate to sit on a lookahead in $self->{'_peek'}.
# What is next() supposed to do at end of collection?

sub next {
  my ($self) = @_;
  ### MooseX next()
  if (exists $self->{'_peek'}) {
    return delete $self->{'_peek'};
  } else {
    return $self->SUPER::next;
  }
}

sub has_next {
  my ($self) = @_;
  ### MooseX has_next()
  return defined($self->peek);
}

sub peek {
  my ($self) = @_;
  ### MooseX peek(): $self
  if (exists $self->{'_peek'}) {
    return $self->{'_peek'};
  } else {
    ### fill from super
    return ($self->{'_peek'} = $self->SUPER::next);
  }
}

sub rewind {
  my ($self) = @_;
  ### MooseX rewind()
  delete $self->{'_peek'};
  $self->SUPER::rewind;
}
BEGIN {
  *reset = *rewind;
}

1;
__END__

=for stopwords seekable Ryde getters coderef

=head1 NAME

MooseX::Iterator::Locate -- read "locate" database with MooseX::Iterator

=head1 SYNOPSIS

 use MooseX::Iterator::Locate;
 my $it = MooseX::Iterator::Locate->new;
 while ($it->has_next) {
   print $it->next, "\n";
 }

=head1 CLASS HIERARCHY

C<MooseX::Iterator::Locate> is a subclass of C<Moose::Object> and
C<File::Iterator::Locate>,

    Moose::Object
    File::Iterator::Locate
      MooseX::Iterator::Locate

and does

    MooseX::Iterator::Role

=head1 DESCRIPTION

C<MooseX::Iterator::Locate> reads a "locate" database file in iterator
style.  It offers C<MooseX::Iterator> style methods as a front-end to
C<File::Locate::Iterator>.

=head1 FUNCTIONS

=over 4

=item C<< $it = MooseX::Iterator::Locate->new (key=>value,...) >>

Create and return a new C<MooseX::Iterator::Locate> object.  Optional
key/value pairs are passed to C<< File::Locate::Iterator->new >>.

=item C<< $entry = $it->next >>

Return the next entry from the database.  The first call is the first entry.

=item C<< $entry = $it->peek >>

Return the next entry from the database, but don't advance the iterator
position.  This is what C<$it-E<gt>next> would return.

(This is not the same as C<peek> in the base MooseX::Iterator version 0.11,
it gives the second next item.  Believe that's a mistake there, though the
intention will be to follow what the base does when resolved.)

=item C<< $bool = $it->has_next >>

Return true if there's a next entry available.

=item C<< $it->reset >>

Move C<$it> back to the start of the database again.  The next call to
C<$it-E<gt>next> gives the first entry again.

As discussed in C<File::Locate::Iterator> under C<rewind()>, this reset is
only possible when the underlying database file or handle is a plain file or
something seekable.

=back

=head1 ATTRIBUTES

The various parameters accepted by C<new> are attributes.  They're all
"bare" create-only, no getters or setters.

    database_file     Str
    database_fh       FileHandle
    database_str      Str
    suffix            Str
    suffixes          ArrayRef[Str]
    glob              Str
    globs             ArrayRef[Str]
    regexp            Str | RegexpRef
    regexps           ArrayRef[Str|RegexpRef]
    use_mmap          enum default, if_sensible, if_possible, 0, 1

The default in the C<database_file> attribute is per
C<< File::Locate::Iterator->default_database_file >>.  (It's a coderef type
since C<default_database_file> looks at C<%ENV>.)

=head1 SEE ALSO

L<MooseX::Iterator>, L<File::Locate::Iterator>, L<Moose>, L<Moose::Object>

=head1 HOME PAGE

http://user42.tuxfamily.org/file-locate-iterator/index.html

=head1 COPYRIGHT

Copyright 2010, 2011 Kevin Ryde

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
