=head1 NAME

engine pf test

=cut

=head1 DESCRIPTION

engine pf test script

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use Test::More tests => 4;

BEGIN {
    use_ok("pf::engine");
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use PfFilePaths;
}


#This test will running last
use Test::NoWarnings;
use pf::filter;
use pf::condition::false;
use pf::condition::true;

{

    my $engine = pf::engine->new(
        {   filters => [
                pf::filter->new(
                    {   answer    => 'falses',
                        condition => pf::condition::false->new,
                    }
                ),
                pf::filter->new(
                    {   answer    => 'true1',
                        condition => pf::condition::true->new,
                    }
                ),
                pf::filter->new(
                    {   answer    => 'true2',
                        condition => pf::condition::true->new,
                    }
                ),
            ],
        }
    );

    #This is the first test
    is($engine->match_first({}), 'true1', "Match first");

    #This is the second test
    is_deeply([$engine->match_all({})], ['true1', 'true2'], "Match all");

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;


