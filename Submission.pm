#  Submission.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Submission;

use Moose;
use Homework;
use Types;
use StudentInfo;
use Lock;
use Moose::Util::TypeConstraints;
use File::Basename;
use Try::Tiny;

has 'user' => ( is => 'ro', isa => 'StudentInfo', required => 1 );
has 'homework' => ( is => 'ro', isa => 'Homework', required => 1 );
has 'mode' => ( is => 'ro', isa => 'SubmissionMode', required => 1 );
has 'dir' => ( is => 'ro', isa => 'Directory', required => 1 );
has '_lock' => ( is => 'ro', isa => 'Lock', lazy_build => 1 );
has 'config' => ( is => 'ro', isa => 'Config::Tiny', lazy_build => 1 );

subtype 'SubmissionFilename',
	as 'Str',
	where {
		return 0 unless /^([^_ ]+_){3}[^_ ]+/;
		
		my @data = split ('_', basename($_));
			
		return 0 unless find_type_constraint('SubmissionClass')->check($data[0]);
		return 0 unless find_type_constraint('SubmissionMode')->check($data[1]);
		
		try {
			new StudentInfo(login => $data[2], class => $data[0]);
		}
		finally {
			return 1;
		}
		catch {
			return 0;
		}
	};

sub coerce_method {
	my $self = shift;
	my $input = shift;
	
	my $submission = 'Submission';
	my $studentInfo = 'StudentInfo';
	my $homework = 'Homework';
	
	if (@_) {
		$submission = shift;
		$studentInfo = shift;
		$homework = shift;
	}
	
	my @data = split ('_', basename($input));
	
	my $user = new $studentInfo(login => $data[2], class => $data[0]);
	my $hw = new $homework(name => $data[3], class => $data[0], dir => dirname($input));

	new $submission(user => $user, homework => $hw, mode => $data[1]);
}

coerce 'Submission',
	from 'SubmissionFilename',
	via { coerce_method($_); };

sub _build__lock {
	my $self = shift;
	
	new Lock( name => $self->_filename, directory => $self->dir);
}

sub _build_config {
	my $self = shift;
	
	my $r = Config::Tiny->new;
	if ($self->is_submitted) {
		return $r->read ($self->dir.'/'.$self->_filename);
	}
	return $r;
}

sub _filename {
	my $self = shift;

	$self->homework->class.'_'.$self->mode.'_'.$self->user->login.'_'.$self->homework->name;
}

sub is_submitted {
	my $self = shift;
	
	$self->_lock->has_lock;
}

sub can_submit {
	my $self = shift;
	
	if ( not $self->user->is_special and not $self->homework->is_opened($self->mode) ) {
		return 0;
	}
	
	return 1;
}

sub submit {
	my $self = shift;
	
	if (not $self->can_submit) { return 0; }
	$self->_lock->add_lock ($self->config->write_string);
}

sub remove {
	my $self = shift;
	
	$self->_lock->remove_lock;
}

sub validate {
	my $self = shift;
	
	$self->can_submit;
}

sub validate_remove {
	my $self = shift;
	
	if (not $self->is_submitted) { return 0; }
	if (not $self->validate) {
		$self->remove();
		return 1;
	}
	return 0;
}

sub get_all {
	if (@_ == 2) { shift; }
	my $prefix = shift;
	
	opendir(DIR, $prefix) || die("Cannot open submission directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	grep { find_type_constraint('SubmissionFilename')->check($_) } @files;
}

sub get_bad {
	if (@_ == 2) { shift; }
	my $prefix = shift;
	
	opendir(DIR, $prefix) || die("Cannot open submission directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	my @good = get_all($prefix);
	push(@good, ('.', '..'));
	
	grep { my $m = $_; not scalar grep { $_ eq $m} @good } @files;
}

sub cleanup {
	if (@_ == 2) { shift; }
	my $prefix = shift;
	
	foreach (get_bad($prefix)) {
		my $file = $prefix.'/'.$_;
		print "BAD_SUBMISSION: $_\n";
		system("rm -f '$file'");
	}
}

sub obtain_export {
	my $self = shift;
	my $dir = shift;
	
	if ($dir eq $self->dir and $self->is_submitted) {
		return $self->_lock->_lock;
	}
	
	my $lock = new Lock( name => $self->_filename, directory => $dir);
	$lock->obtain_lock($self->config->write_string);
	return $lock->_lock;
}

no Moose;
__PACKAGE__->meta->make_immutable;
