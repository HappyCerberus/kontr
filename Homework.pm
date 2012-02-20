#  Homework.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Homework;

use Moose;
use Config::Tiny;
use Moose::Util::TypeConstraints;

use Types;

has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'class' => ( is => 'ro', isa => 'SubmissionClass', required => 1 );
has 'opened' => ( is => 'ro', isa => 'SubmissionModeArr', lazy_build => 1, coerce => 1, auto_deref => 1);

sub is_opened {
	my $self = shift;
	my $mode = shift;
	
	scalar grep { $_ eq $mode } $self->opened;
}

sub _build_dir {
	my $self = shift;
	my $name = shift;
	
	opendir(DIR, $name) || die("Cannot open '$name' directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	return @files;
}

sub _build_opened {
	my $self = shift;
	my $dir = Config::Tiny->new->read('config.ini')->{Submission}->{opened};
	my @data = $self->_build_dir($dir);
	my $subtype = 'SubmissionModeStr_'.$self->name.'_'.$self->class;
	
	subtype $subtype,
		as 'SubmissionModeStr',
		where {my $c = $self->class; my $n = $self->name; /^${c}_${n}_/ };
	
	[ map {find_type_constraint('SubmissionMode')->coerce($_) } 
		grep {find_type_constraint($subtype)->check($_) } @data ];
}

no Moose;
__PACKAGE__->meta->make_immutable;
