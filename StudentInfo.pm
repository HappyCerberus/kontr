# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package StudentInfo;

use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints;
use UserInfo;
use File::Slurp qw(read_file);
use Config::Tiny;

extends 'UserInfo';
has 'teacher' => ( isa => 'UserInfo', is => 'rw' );
has 'is_special' => ( traits => ['Bool'], is => 'rw', isa => 'Bool', default => 0 );

subtype 'filename'
	=> as 'Str'
	=> where { -r $_ }
	=> message { "$_ is not a readable file" };

has 'students_file' => ( is => 'rw', isa => 'filename', default => sub { my $Config = Config::Tiny->new; $Config = Config::Tiny->read('config.ini'); return $Config->{StudentInfo}->{students}; } );
has 'teachers_file' => ( is => 'rw', isa => 'filename', default => sub { my $Config = Config::Tiny->new; $Config = Config::Tiny->read('config.ini'); return $Config->{StudentInfo}->{teachers}; } );


sub BUILD
{
	my $self = shift;
	my $args = shift;

	$self->read_info($args->{login}, $args->{class});
}

sub read_info
{ 
	my $self = shift;
	my $login = shift;
	my $class = shift;

	my @lines = grep {/^$login/} map {read_file($_)} glob($self->teachers_file);
	die "Multiple entries for user \"$login\" in teacher mapping file" unless scalar @lines <= 1;
	if (scalar @lines == 1) # teacher match
	{
		my @values = split(',',$lines[0]);
		die "Wrong format of teacher mapping file for user \"$login\"" unless scalar @values == 4;
		my $name = $values[3];
		#remove trailing whitespace
		$name =~ s/\s+$//;
		$self->login($values[0]);
		$self->uco($values[1]);
		$self->email($values[2]);
		$self->name($name);
		$self->is_special(1);
	}
	else
	{
		@lines = grep {/^$login/ && /$class/} map {read_file($_)} glob($self->students_file);
		die "User \"$login\" not present in students mapping file\"".$self->students_file."\"" unless scalar @lines >= 1;
		die "Multiple entries for user \"$login\" in students mapping file" unless scalar @lines <= 1;

		my @values = split(',',$lines[0]);
		die "Wrong format of students mapping file for user \"$login\"" unless scalar @values == 6;
		
		my $teacher  = $values[5];
		# remove trailing whitespace
		$teacher =~ s/\s+$//;
		$self->login($values[0]);
		$self->uco($values[2]);
		$self->email($values[3]);
		$self->name($values[4]);

		# read the teacher info now
		@lines = grep {/^$teacher/} map {read_file($_)} glob($self->teachers_file);
		die "User \"$teacher\" not present in teacher mapping file" unless scalar @lines >= 1;
		die "Multiple entries for user \"$teacher\" in teacher mapping file" unless scalar @lines <= 1;
		
		@values = split(',',$lines[0]);
		die "Wrong format of teacher mapping file for user \"$teacher\"" unless scalar @values == 4;

		# remove trailing white space from name
		my $teacher_name = $values[3];
		$teacher_name =~ s/\s+$//;

		$self->teacher(new UserInfo(login => $values[0], uco => $values[1], email => $values[2], name => $teacher_name));
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
