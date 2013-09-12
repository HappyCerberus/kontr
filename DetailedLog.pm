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
use LoggedFile;

has 'data' => (is => 'rw', isa => 'Str', default => '');
has 'master' => (is => 'rw', isa => 'Str');
has 'session' => (is => 'rw', isa => 'Session', required => 1);
has 'units' => (is => 'rw', isa => 'ArrayRef[Str]', traits => ['Array'], handles => { add_unit => 'push', clear_units => 'clear'}, default => sub { [] });
has 'student_log_size' => (is => 'rw', isa => 'Int');
has 'teacher_log_size' => (is => 'rw', isa => 'Int');
has 'student_log_files' => (is => 'rw', isa => 'ArrayRef[LoggedFile]', traits => ['Array'], handles => { add_student_log_file => 'push', clear_student_log_files => 'clear', list_student_log_files => 'elements', map_student_log_files => 'map'});
has 'teacher_log_files' => (is => 'rw', isa => 'ArrayRef[LoggedFile]', traits => ['Array'], handles => { add_teacher_log_file => 'push', clear_teacher_log_files => 'clear', list_teacher_log_files => 'elements', map_teacher_log_files => 'map' });
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
	return encode_json(\%ret);
}

sub new_unit {
	my $self = shift;
	
	$self->clear_subtests();
	$self->add_subtest( encode_json({ 'name' => '' }) );
	$self->clear_actions();
	$self->_set_log_size();
}

sub unit_data {
	my $self = shift;
	my $unit = shift;
	
	$self->_end_subtest($unit->report);
	my $subtests = _stringattr_json('subtests', $self->subtests);
	my $work_path = encode_json( {'work_path' => $unit->work_path} );
	$self->add_unit(_merge_json(data_master_unit($unit), _merge_json($subtests, $work_path)));
}

sub end_master {
	my $self = shift;
	
	return _merge_json($self->master, _arrayattr_json('units', @{ $self->units }) );
}

sub _set_log_size {
	my $self = shift;
	
	$self->student_log_size(length $self->session->user_log->data);
	$self->teacher_log_size(length $self->session->teacher_log->data);
	$self->clear_student_log_files();
	$self->clear_teacher_log_files();
}

sub _get_logs {
	my $self = shift;
	
	my $student_log = substr ($self->session->user_log->data, $self->student_log_size);
	my $student_offset = $self->student_log_size;
	my $teacher_log = substr ($self->session->teacher_log->data, $self->teacher_log_size);
	my $teacher_offset = $self->teacher_log_size;
	
	for my $student_file ($self->list_student_log_files) {
		($student_log, $student_offset) = $student_file->remove_from_log($student_log, $student_offset);
	}
	
	for my $teacher_file ($self->list_teacher_log_files) {
		($teacher_log, $teacher_offset) = $teacher_file->remove_from_log($teacher_log, $teacher_offset);
	}
	
	my %ret = (
		'student_log' => $student_log,
		'teacher_log' => $teacher_log,
		'student_log_files' => [ $self->map_student_log_files( sub { $_->get() })],
		'teacher_log_files' => [ $self->map_teacher_log_files( sub { $_->get() })],
	);
	
	return encode_json(\%ret);
}

sub add_report {
	my $self = shift;
	my $report = shift;
	
	my %data = (
		'tags' => [$report->allTags()],
		'points' => $report->points,
	);
	$self->add_subtest_data(encode_json(\%data));
	$self->add_subtest_data($self->_get_logs());
}

sub new_subtest {
	my $self = shift;
	my $report = shift;
	my $name = shift;
	
	$self->_end_subtest($report);
	$self->add_subtest( encode_json({ 'name' => $name }) );
	$self->_set_log_size();
}

sub _end_subtest {
	my $self = shift;
	my $report = shift;
	
	$self->add_report($report);
	$self->add_subtest_data( _stringattr_json('actions', [$self->map_actions( sub { encode_json($_->get()) })] ) );
	$self->clear_actions();
}

sub add_subtest_data {
	my $self = shift;
	my $data = shift;
	
	my $str = _merge_json($self->get_subtest(-1), $data);
	$self->splice_subtest(-1, 1, $str);
}

sub dump {
	my $session = shift;
	my $filename = shift;
	my $detailed;
	
	open $detailed, $filename;
	print $detailed '[';
	print $detailed join(',', @{ $session->detailed });
	print $detailed ']';
	close $detailed;
}

sub _merge_json {
	my $first = shift;
	my $second = shift;
	
	if (substr($first, 0, 1) eq substr($second, 0, 1) and (substr($first, 0, 1) eq '{' or substr($first, 0, 1) eq '[') ) {
		return substr($first, 0, -1).",".substr($second, 1);
	}
	die "Cannot merge ".$first." and ".$second;
}

sub _stringattr_json {
	my $name = shift;
	my $json = shift;
	
	if (ref($json) eq 'ARRAY') {
		$json = '['.join(',', @$json).']';
	}
	
	return '{'.JSON->new->allow_nonref->encode($name).':'.$json.'}';
}

sub _arrayattr_json {
	my $name = shift;
	
	return '{'.JSON->new->allow_nonref->encode($name).':['.join(',', @_).']}';
}


no Moose;
__PACKAGE__->meta->make_immutable;
