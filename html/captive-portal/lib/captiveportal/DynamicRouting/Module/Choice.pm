package captiveportal::DynamicRouting::Module::Choice;

=head1 NAME

captiveportal::DynamicRouting::Module::Choice

=head1 DESCRIPTION

For giving a choice between multiple modules

=cut

use Moose;
extends 'captiveportal::DynamicRouting::ModuleManager';

use pf::util;
use pf::log;

has 'show_first_module_on_default' => (is => 'rw', isa => 'Str', default => sub{'disabled'});

has 'template' => (is => 'rw', isa => 'Str', default => sub {'content-with-choice.html'});

sub next {
    my ($self) = @_;
    $self->done();
}

before 'execute_child' => sub {
    my ($self) = @_;
    if($self->app->request->path =~ /^switchto\/(.+)/){
        $self->current_module($1) if($self->module_map->{$1});
    }
};

sub render {
    my ($self, @params) = @_;
    my $inner_content = $self->app->_render(@params);
    $self->render_choice($inner_content);
}

sub render_choice {
    my ($self, $inner_content) = @_;
    $self->SUPER::render($self->template, {content => $inner_content, modules => [grep {$_->display} $self->all_modules], current_module => $self->current_module});
}

sub default_behavior {
    my ($self) = @_;
    if(isenabled($self->show_first_module_on_default)){
        get_logger->debug("Default behavior is to show the first module");
        $self->default_module->execute();
    }
    else {
        get_logger->debug("Default behavior is to show only the choice");
        $self->render_choice(); 
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;

