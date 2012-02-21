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
use Moose::Util::TypeConstraints;
use File::Basename;
use Try::Tiny;

has 'user' => ( is => 'ro', isa => 'StudentInfo', required => 1 );
has 'homework' => ( is => 'ro', isa => 'Homework', required => 1 );
has 'mode' => ( is => 'ro', isa => 'SubmissionMode', required => 1);
has 'file' => ( is => 'ro', isa => 'Bool', writer => '_set_file', lazy_build => 1 );

subtype 'SubmissionFile',
	as 'Str',
	where {
		my $prefix = prefix();
		return 0 unless -e;
		return 0 unless /^${prefix}([^_]+_){3}[^_]+/;
		
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

coerce 'Submission',
	from 'SubmissionFile',
	via {
		my @data = split ('_', basename($_));
		
		new Submission(user => new StudentInfo(login => $data[2], class => $data[0]),
			homework => new Homework(name => $data[3], class => $data[0]),
			mode => $data[1]);	
	};

sub prefix {
	return Config::Tiny->new->read('config.ini')->{Submission}->{submitted}.'/';
}

sub _filename {
	my $self = shift;
	my $prefix = '';
	if (scalar @_) {
		$prefix = prefix();
	}
	
	return $prefix.$self->homework->class.'_'.$self->mode.'_'.$self->user->login.'_'.$self->homework->name;
}

sub _build_file {
	my $self = shift;
	
	return -e $self->_filename(1);
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
	
	if (not $self->can_submit) { return 1; }
	if ($self->file) { return 1; }
	
	my $filename = $self->_filename(1);
	`touch $filename;`;
	
	$self->_set_file(1);
	return 0;
}

sub remove {
	my $self = shift;
	
	if (not $self->file) { return 1; }
	
	my $filename = $self->_filename(1);
	`rm $filename;`;
	
	$self->_set_file(0);
	return 0;
}

sub validate_remove {
	my $self = shift;
	
	if (not $self->file) { return 0; }
	if (not $self->can_submit) {
		$self->remove();
		return 1;
	}
	return 0;
}

sub get_all {
	my $prefix = prefix();
	
	opendir(DIR, $prefix) || die("Cannot open submission directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	grep { find_type_constraint('SubmissionFile')->check($prefix.$_) } @files;
}

sub get_bad {
	my $prefix = prefix();
	
	opendir(DIR, $prefix) || die("Cannot open submission directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	my @good = get_all();
	push(@good, ('.', '..'));
	
	grep { my $m = $_; not scalar grep { $_ eq $m} @good } @files;
}

no Moose;
__PACKAGE__->meta->make_immutable;
