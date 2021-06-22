package pf::provisioner::google_workspace_chromebook;

=head1 NAME

pf::provisioner::google_workspace_chromebook -

=head1 DESCRIPTION

pf::provisioner::google_workspace_chromebook

=cut

use strict;
use warnings;
use List::MoreUtils qw(any);
use Moo;
extends 'pf::provisioner::mobileconfig';
use fingerbank::Constant;

# Will always ignore the oses parameter provided and use [Windows]
has 'oses' => (is => 'ro', default => \&_set_to_chromebook , coerce => \&_set_to_chromebook );

sub _set_to_chromebook {
    [$fingerbank::Constant::PARENT_IDS{CHROMEBOOK}]
}

sub process_devices {
    my ($self, $devices);
    for my $device (@$devices) {
        $self->process_device($device);
    }
}

sub process_device {
    my ($self, $device) = @_;
    my $status = $device->{status};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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