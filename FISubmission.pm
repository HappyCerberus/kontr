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
	via { Submission->coerce_method($_, 'FISubmission', 'StudentInfo', 'FIHomework' ); };

sub get_dir {
	Config::Tiny->new->read('config.ini')->{Submission}->{submitted};
}

sub corrected_dir {
	Config::Tiny->new->read('config.ini')->{Submission}->{corrected};
}

sub _build__corrected {
	my $self = shift;
	my $user = `whoami`;
	$user =~ s/\s+$//;
	
	new TimeLock(name => $self->_filename,
		directory => corrected_dir(),
		duration => DateTime::Duration->new( minutes => 15 ),
		write => (Config::Tiny->new->read('config.ini')->{Global}->{superuser} eq $user) );
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
	
	return 0 if $self->_corrected->has_lock;
	return 0 unless getpwuid((stat($self->_lock->_lock))[4]) eq $self->user->login; #Check login
	if (not $self->user->is_special) {
		return 0 unless $self->config->write_string eq '';
	}
	$self->$orig;
};

around get_all => sub {
	my $orig = shift;
	my $self = shift;
	my $dir = get_dir();
	
	map { $dir.'/'.$_ } grep { find_type_constraint('FISubmission')->coerce($_)->validate() } $self->$orig($dir);
};

around get_bad => sub {
	my $orig = shift;
	my $self = shift;
	my $dir = get_dir();
	
	opendir(DIR, $dir) || die("Cannot open submission directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	my @good = get_all();
	push(@good, ('.', '..'));
	
	my @res = grep { my $m = $_; not scalar grep { basename($_) eq $m} @good } @files;
	
	push(@res, $self->$orig($dir));
	map { $dir.'/'.$_ } @res;
};

around cleanup => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->$orig(get_dir());
	TimeLock->cleanup(corrected_dir());
	
	foreach (get_bad()) {
		print "BAD_SUBMISSION: $_\n";
		`rm -f "$_"`;
	}
};

sub toBeCorrected {
	my $self = shift;
	
	$self->_corrected->add_lock() unless $self->user->is_special;
}

sub corrected {
	my $self = shift;
	
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

