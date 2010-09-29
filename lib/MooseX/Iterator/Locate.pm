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

package MooseX::Iterator::Locate;
use 5.006;
use Carp;
use Moose;
use MooseX::Iterator::Meta::Iterable;

extends 'File::Locate::Iterator';
with 'MooseX::Iterator::Role';

our $VERSION = 16;

# uncomment this to run the ### lines
#use Smart::Comments;


# No peek() in the underlying File::Locate::Iterator as yet, so sit on a
# '_peek' lookahead.  What is next() supposed to do at end of collection?

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
  return defined($self->peek);
}

sub peek {
  my ($self) = @_;
  ### MooseX peek()
  if (exists $self->{'_peek'}) {
    return $self->{'_peek'};
  } else {
    return ($self->{'_peek'} = $self->SUPER::next);
  }
}

sub rewind {
  my ($self) = @_;
  delete $self->{'_peek'};
  $self->SUPER::rewind;
}
BEGIN {
  *reset = *rewind;
}

1;
__END__

#   has 'fli' => (is   => 'rw',
#                 isa  => 'File::Locate::Iterator',
#                 lazy => 1,
#                 default => sub {
#                   ### default
#                   return File::Locate::Iterator->new;
#                 }
#                );

=for stopwords seekable Ryde

=head1 NAME

MooseX::Iterator::Locate -- read "locate" database with MooseX::Iterator

=head1 SYNOPSIS

 use MooseX::Iterator::Locate;
 my $it = MooseX::Iterator::Locate->new;
 while ($it->has_next) {
   print $it->next, "\n";
 }

=head1 DESCRIPTION

C<MooseX::Iterator::Locate> reads a "locate" database file in iterator
style.  It's implemented as a front-end to C<File::Locate::Iterator>,
providing C<MooseX::Iterator> style methods.

=head1 FUNCTIONS

=over 4

=item C<< $it = MooseX::Iterator::Locate->new (key=>value,...) >>

Create and return a new C<MooseX::Iterator::Locate> object.  Optional key/value
pairs as passed to C<< File::Locate::Iterator->new >>.

=item C<< $entry = $it->next >>

Return the next entry from the database.

=item C<< $entry = $it->peek >>

Return the next entry from the database, but don't advance the iterator
position.  This lets you look at what C<$it-E<gt>next> would return.

=item C<< $bool = $it->has_next >>

Return true if there's a next entry available.

=item C<< $it->reset >>

Move C<$it> back to the start of the database again.

As discussed in C<File::Locate::Iterator> C<rewind()> this is only possible
when the underlying database file or handle is a plain file or something
else seekable.

=back

=head1 SEE ALSO

L<MooseX::Iterator>, L<File::Locate::Iterator>, L<Moose>

=head1 HOME PAGE

http://user42.tuxfamily.org/file-locate-iterator/index.html

=head1 COPYRIGHT

Copyright 2010 Kevin Ryde

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
