package pf::Switch::Extreme::Extreme_Controller;

=head1 NAME

pf::Switch::Extreme::Extreme_Controller

=head1 SYNOPSIS

Module to manage Extreme APs managed by an Extreme Cloud IQ (cloud)

=head1 STATUS

Developed and tested on AeroHIVE AP305C running IQ Engine 10.4r6.

=over

=back 

=cut
use strict;
use warnings;

use pf::config qw(
    $WIRELESS_MAC_AUTH
    $WEBAUTH_WIRELESS
);
use pf::constants;
use pf::locationlog;
use pf::node;
use pf::util;
use pf::security_event;
use pf::constants::role qw($REJECT_ROLE);
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $WEBAUTH_WIRED
    $WEBAUTH_WIRELESS
);
use pf::Switch::constants;

use base ('pf::Switch');
use pf::SwitchSupports qw(
    ExternalPortal
    RoleBasedEnforcement
    WirelessDot1x
    WirelessMacAuth
);


sub description { 'Extreme Controller' }


=head1 METHODS

=over

=cut

=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    %params = (
        switch_id               => $req->param('RADIUS-NAS-IP'),
        client_mac              => clean_mac($req->param('Calling-Station-Id')),
        client_ip               => $req->param('STA-IP'),
        ssid                    => $req->param('ssid'),
        redirect_url            => defined($req->param('destination_url')),
        grant_url               => $req->param('url'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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

