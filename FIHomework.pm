#  FIHomework.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package FIHomework;

use Moose;
use Moose::Util::TypeConstraints;

use Homework;
extends 'Homework';

has 'prepared' => ( is => 'ro', isa => 'Homework', lazy_build => 1 );

around BUILDARGS => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->$orig(@_, dir => Config::Tiny->new->read('config.ini')->{Submission}->{opened});
};

sub _build_prepared {
	my $self = shift;
	
	new Homework(name => $self->name, class => $self->class, dir => Config::Tiny->new->read('config.ini')->{Submission}->{prepared});
}

around is_opened => sub {
	my $orig = shift;
	my $self = shift;
	my $type = shift;
	
	$self->$orig($type) and $self->prepared->is_opened($type);
};

no Moose;
__PACKAGE__->meta->make_immutable;
