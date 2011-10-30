# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Stage;

use warnings;
use strict;
use Moose;
use Moose::Util::TypeConstraints;

has 'path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

enum 'StageResult', [ qw(success teacher_file_missing student_file_missing stage_file_duplicate) ];
has 'result' => ( is => 'rw', isa => 'StageResult', default => 'success' );
has 'result_error' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '');

sub stage
{
	my $self = shift;
	my $test = shift;

	my $src_path_teach = shift;
	my $src_path_student = shift;
	my $dst_path = shift;

	my $i;

	foreach $i ($test->staged_files)
	{
		my $file = $src_path_teach."/".$i;
		my $target = $dst_path."/".$i;
		unless (-r $file) { $self->result('teacher_file_missing'); $self->result_error($file); return; }
		if (-r $target) { $self->result('stage_file_duplicate'); $self->result_error($file); return; }

		`cp $file $target`;
	}

	foreach $i ($test->staged_compiled_files)
	{
		my $file = $src_path_teach."/".$i;
		my $target = $dst_path."/".$i;
		unless (-r $file) { $self->result('teacher_file_missing'); $self->result_error($file); return; }
		if (-r $target) { $self->result('stage_file_duplicate'); $self->result_error($file); return; }

		`cp $file $target`;
	}

	foreach $i ($test->staged_student_files)
	{
		my $file = $src_path_student."/".$i;
		my $target = $dst_path."/".$i;
		unless (-r $file) { $self->result('student_file_missing'); $self->result_error($file); return; }
		if (-r $target) { $self->result('stage_file_duplicate'); $self->result_error($file); return; }

		`cp $file $target`;
	}

	foreach $i ($test->staged_compiled_student_files)
	{
		my $file = $src_path_student."/".$i;
		my $target = $dst_path."/".$i;
		unless (-r $file) { $self->result('student_file_missing'); $self->result_error($file); return; }
		if (-r $target) { $self->result('stage_file_duplicate'); $self->result_error($file); return; }

		`cp $file $target`;
	}

}

sub prepare
{
	my $self = shift;
	my $unit_test = shift;
	my $master_test = $unit_test->master;
	my $session = $unit_test->session;

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');
	
	my $base_path = $Config->{Tests}->{stage_path};
	my $tmp_path = $base_path;
	
	# create directory
	# class/task/user_timestamp/master_test/unit_test
	
	$tmp_path .= "/".$session->class;
	mkdir $tmp_path unless -d $tmp_path; # /class

	$tmp_path .= "/".$session->task;
	mkdir $tmp_path unless -d $tmp_path; # /task

	$tmp_path .= "/".$session->user->login."_".$session->timestamp;
	mkdir $tmp_path unless -d $tmp_path; # /timestamp

	$tmp_path .= "/".$master_test->name;
	mkdir $tmp_path unless -d $tmp_path; # /master_test

	$tmp_path .= "/".$unit_test->name;
	mkdir $tmp_path unless -d $tmp_path; # /unit_test

	# directories are created, now copy all requested files
	my $student_src=$session->repo_path."/".$session->task;
	my $teacher_src=$Config->{Tests}->{files_path}."/".$session->class."/".$session->task;

	$self->result('success');

	# files from master test
	$self->stage($master_test,$teacher_src,$student_src,$tmp_path);
	return unless $self->result eq 'success';

	# files from unit test
	$self->stage($unit_test,$teacher_src,$student_src,$tmp_path);
	return unless $self->result eq 'success';

	$unit_test->work_path($tmp_path);
	$unit_test->file_path($teacher_src);
}

no Moose;
__PACKAGE__->meta->make_immutable;
