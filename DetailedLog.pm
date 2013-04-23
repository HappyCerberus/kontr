#  DetailedLog.pm
#  
#  Copyright 2013 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package DetailedLog;

use Moose;
use JSON;
use Session;
use Action;
use Data::Dumper;

has 'data' => (is => 'rw', isa => 'Str', default => '');
has 'master' => (is => 'rw');
has 'session' => (is => 'rw', isa => 'Session', required => 1);
has 'units' => (is => 'rw', isa => 'ArrayRef', traits => ['Array'], handles => { add_unit => 'push', get_unit => 'get', splice_unit => 'splice', clear_units => 'clear'}, default => sub { [] });
has 'student_log_size' => (is => 'rw', isa => 'Int');
has 'teacher_log_size' => (is => 'rw', isa => 'Int');
has 'subtests' => (is => 'rw', isa => 'ArrayRef', traits => ['Array'], handles => { add_subtest => 'push', clear_subtests => 'clear', get_subtest => 'get', splice_subtest => 'splice'}, default => sub { [] } );
has 'actions' => (is => 'rw', isa => 'ArrayRef', traits => ['Array'], handles => { add_action => 'push', clear_actions => 'clear', map_actions => 'map' }, default => sub { [] } );

sub add_master {
	my $self = shift;
	my $master = shift;
	
	$self->master(data_master_unit($master));
	$self->clear_units();
}

sub data_master_unit {
	my $master = shift;
	
	my %ret = (
		'name' => $master->name,
		'staged_files' => ($master->staged_files ? [$master->staged_files] : []),
		'compiled_files' => ($master->staged_compiled_files ? [$master->staged_compiled_files] : []),
		'staged_student_files' => ($master->staged_student_files ? [$master->staged_student_files] : []),
		'compiled_student_files' => ($master->staged_compiled_student_files ? [$master->staged_compiled_student_files] : [])
	);
	return \%ret;
}

sub new_unit {
	my $self = shift;
	
	#$self->add_unit();
	$self->clear_subtests();
	$self->add_subtest( { 'name' => '' });
	$self->clear_actions();
	$self->_set_log_size();
}

sub unit_data {
	my $self = shift;
	my $unit = shift;
	
	$self->_end_subtest($unit->report);
	my %subtests = ('subtests' => $self->subtests);
	my %work_path = ('work_path' => $unit->work_path);
	my %data = (%{data_master_unit($unit)}, %work_path, %subtests);
	#$self->add_unit_data(\%data);
	$self->add_unit(\%data);
}

sub end_master {
	my $self = shift;
	
	my %master = %{$self->master};
	$master{'units'} = $self->units;
	
	return \%master;
}

sub _set_log_size {
	my $self = shift;
	
	$self->student_log_size(length $self->session->user_log->data);
	$self->teacher_log_size(length $self->session->teacher_log->data);
}

sub _get_logs {
	my $self = shift;
	
	my %ret = (
		'student_log' => substr ($self->session->user_log->data, $self->student_log_size),
		'teacher_log' => substr ($self->session->teacher_log->data, $self->teacher_log_size),
	);
	
	return \%ret;
}

sub add_report {
	my $self = shift;
	my $report = shift;
	
	my %data = (
		'tags' => [$report->allTags()],
		'points' => $report->points,
	);
	$self->add_subtest_data(\%data);
	$self->add_subtest_data($self->_get_logs());
}

sub new_subtest {
	my $self = shift;
	my $report = shift;
	my $name = shift;
	
	$self->_end_subtest($report);
	$self->add_subtest( { 'name' => $name });
	$self->_set_log_size();
}

sub _end_subtest {
	my $self = shift;
	my $report = shift;
	
	$self->add_report($report);
	$self->add_subtest_data( { 'actions' => [$self->map_actions( sub { $_->get() })] } );
	$self->clear_actions();
}

sub add_unit_data {
	my $self = shift;
	my $data = shift;
	
	my %newdata = (%{$self->get_unit(-1)}, %{$data});
	$self->splice_unit(-1, 1, \%newdata);
}

sub add_subtest_data {
	my $self = shift;
	my $data = shift;
	
	my %newdata = (%{$self->get_subtest(-1)}, %{$data});
	$self->splice_subtest(-1, 1, \%newdata);
}

sub dump {
	my $session = shift;
	my $filename = shift;
	my $detailed;
	
	open $detailed, $filename;
	print $detailed encode_json($session->detailed);
	close $detailed;
}


no Moose;
__PACKAGE__->meta->make_immutable;
