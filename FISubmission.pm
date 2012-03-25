#  Submission.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package FISubmission;

use Moose;
use Submission;
use FIHomework;
use Moose::Util::TypeConstraints;
use File::Basename;
use TimeLock;

extends 'Submission';

has '_corrected' => ( is => 'ro', isa => 'TimeLock', lazy_build => 1 );

coerce 'FISubmission',
	from 'SubmissionFilename',
	via {
		my @data = split ('_', basename($_));
		
		new FISubmission(user => new StudentInfo(login => $data[2], class => $data[0]),
			homework => new FIHomework(name => $data[3], class => $data[0]),
			mode => $data[1]);	
	};

sub get_dir {
	Config::Tiny->new->read('config.ini')->{Submission}->{submitted};
}

sub corrected_dir {
	Config::Tiny->new->read('config.ini')->{Submission}->{corrected};
}

sub _build__corrected {
	my $self = shift;
	
	new TimeLock(name => $self->_filename,
		directory => corrected_dir(),
		duration => DateTime::Duration->new( minutes => 15 ),
		write => 1);
}

around BUILDARGS => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->$orig(@_, dir => get_dir());
};

around can_submit => sub {
	my $orig = shift;
	my $self = shift;
	
	if ($self->_corrected->has_lock) { return 0; }
	$self->$orig;
};

around validate => sub {
	my $orig = shift;
	my $self = shift;
	
	return 0 unless getpwuid((stat($self->_lock->_lock))[4]) eq $self->user->login; #Check login
	$self->$orig;
};

around get_all => sub {
	my $orig = shift;
	my $self = shift;
	my $dir = get_dir();
	
	map { $dir.'/'.$_ } $self->$orig($dir);
};

around get_bad => sub {
	my $orig = shift;
	my $self = shift;
	my $dir = get_dir();
	
	map { $dir.'/'.$_ } $self->$orig($dir);
};

around cleanup => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->$orig(get_dir());
	TimeLock->cleanup(corrected_dir());
};

sub corrected {
	my $self = shift;
	
	$self->_corrected->add_lock() unless $self->user->is_special;
	$self->remove();
}

sub is_corrected {
	my $self = shift;
	
	$self->_corrected->has_lock;
}

sub until {
	my $self = shift;
	
	$self->_corrected->until;
}

no Moose;
__PACKAGE__->meta->make_immutable;

