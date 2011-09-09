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

has 'stage_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_file => 'push' } );

has 'compiled_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_file => 'push' } );

has 'stage_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_student_file => 'push' } );

has 'stage_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_student_file => 'push' } );

has 'units' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { register_unit => 'push', units_count => 'count', get_unit => 'get' } );

sub run_tests
{
	my $master_test = shift;
	my $session = shift;

	my $script_path = $session->get_script_path;

	my $index;
	for ($index = 0; $index < $master_test->units_count; $index++)
	{
		my $unit_path = $script_path."/".$master_test->get_unit($index);
		die "Registered unit script \"".$unit_path."\" does not exist." unless -f $unit_path;	
	}

	for ($index = 0; $index < $master_test->units_count; $index++)
	{
		my $unit_test = new UnitTest();
		my $unit_path = $script_path."/".$master_test->get_unit($index);
		eval `cat $unit_path`;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
