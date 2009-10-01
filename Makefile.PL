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

use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use lib 'inc';
use MyMakeMakerExtras;

MyMakeMakerExtras::WriteMakefile
  (NAME         => 'File::Locate::Iterator',
   ABSTRACT     => 'Read "locate" database file with an iterator.',
   VERSION_FROM => 'lib/File/Locate/Iterator.pm',
   MIN_PERL_VERSION => '5.006',
   PREREQ_PM    => {
                    'Test::More' => 0,
                   },

   AUTHOR       => 'Kevin Ryde <user42@zip.com.au>',
   LICENSE      => 'gpl',
   SIGN         => 1,

   META_MERGE
   => { no_index => { directory => [ 'devel' ] },
        resources
        => { homepage
             => 'http://user42.tuxfamily.org/file-locate-iterator/index.html',
           },
        optional_features
        => { maximum_examples
             => { description => 'Be able to run all the examples programs.',
                  requires => { 'Iterator' => 0,
                                'Iterator::Simple' => 0,
                              },
                },
             maximum_interoperation
             => { description => 'Have maximum inter-operation with other modules (optional supported other stuff).',
                  requires => { 'Iterator' => 0,
                                'Iterator::Simple' => 0,
                              },
                },
             maximum_tests
             => { description => 'Have "make test" do as much as possible.',
                  requires => { 'Test::NoWarnings' => 0,
                              },
                },
             maximum_devel
             => { description => 'Stuff used variously for development.',
                  requires => { 'Devel::TimeThis' => 0,
                              },
                },
           },
      },
  );

#------------------------------------------------------------------------------

sub MY::postamble {
  my ($makemaker) = @_;
  return MyMakeMakerExtras::postamble ($makemaker) . <<'HERE';

t/samp.locatedb: t/samp.txt
	/usr/lib/locate/frcode <t/samp.txt >t/samp.locatedb
HERE
}
