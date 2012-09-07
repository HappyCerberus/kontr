#  FISubmissionUndernal.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package FISubmissionInternal;

use Moose;
use Submission;
use FIHomework;
use Moose::Util::TypeConstraints;

extends 'Submission';

coerce 'FISubmissionInternal',
	from 'SubmissionFilename',
	via { Submission->coerce_method($_, 'FISubmissionInternal', 'StudentInfo', 'FIHomework'); };


sub get_dir {
	Config::Tiny->new->read('config.ini')->{Submission}->{submitted_internal};
};

around BUILDARGS => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->$orig(@_, dir => $self->get_dir());
};

around get_all => sub {
	my $orig = shift;
	my $self = shift;
	my $dir = $self->get_dir();
	
	map { $dir.'/'.$_ } $self->$orig($dir);
};

sub runType {
	my $self = shift;
	
	return ($self->mode eq 'nanecisto' ? 'student' : 'teacher');
}

no Moose;
__PACKAGE__->meta->make_immutable;

