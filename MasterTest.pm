# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package MasterTest;

use UnitTest;

use strict;
use warnings;
use Moose;

has 'name' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'stage_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_file => 'push', staged_files => 'elements' } );

has 'compiled_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_file => 'push', staged_compiled_files => 'elements', compiled_files_string => 'join' } );

has 'stage_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_student_file => 'push', staged_student_files => 'elements' } );

has 'compiled_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_student_file => 'push', staged_compiled_student_files => 'elements', compiled_student_files_string => 'join' } );

has 'units' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { register_unit => 'push', units_count => 'count', get_unit => 'get' } );

has 'detailed_log' => (is => 'rw', isa => 'HashRef');

sub run_tests
{
	my $master_test = shift;
	my $session = shift;
	my $detailed_log = shift;

	my $script_path = $session->get_script_path;

	my $index;
	for ($index = 0; $index < $master_test->units_count; $index++)
	{
		my $unit_path = $script_path."/".$master_test->get_unit($index);
		die "Registered unit script \"".$unit_path."\" does not exist." unless -f $unit_path;	
	}
	
	$detailed_log->add_master($master_test);
	
	for ($index = 0; $index < $master_test->units_count; $index++)
	{
		my $user_log = new Log(parent => $session->user_log, nocomit => 0 );
		my $teacher_log = new Log(parent => $session->teacher_log, nocomit => 0 );

		$detailed_log->new_unit();
		my $unit_test = new UnitTest( master => $master_test, session => $session, user_log => $user_log, teacher_log => $teacher_log, detailed_log => $detailed_log );
		my $unit_path = $script_path."/".$master_test->get_unit($index);
		eval `cat $unit_path`;
		print $@ if $@;
		$detailed_log->unit_data($unit_test);
	}
	$master_test->detailed_log($detailed_log->end_master());
}

no Moose;
__PACKAGE__->meta->make_immutable;
