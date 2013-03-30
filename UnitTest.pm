# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package UnitTest;

use strict;
use warnings;
use Moose;

use Stage;
use MasterTest;
use Session;
use Log;
use Compiler;
use Run;
use Analysis;
use Diff;
use Valgrind;
use Report;

has 'name' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' ); 

has 'stage_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_file => 'push', staged_files => 'elements' } );

has 'compiled_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_file => 'push', staged_compiled_files => 'elements', compiled_files_string => 'join' } );

has 'stage_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_student_file => 'push', staged_student_files => 'elements' } );

has 'compiled_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_student_file => 'push', staged_compiled_student_files => 'elements', compiled_student_files_string => 'join' } );

has 'report' => ( is => 'rw', isa => 'Report', lazy_build => 1, handles => { add_tag => 'addTag', add_points => 'addPoints' } );

has 'master' => ( is => 'rw', isa => 'MasterTest' );
has 'session' => ( is => 'rw', isa => 'Session' );

has 'work_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'file_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'user_log' => ( is => 'rw', isa => 'Log' );
has 'teacher_log' => ( is => 'rw', isa => 'Log' );

has 'compilation' => ( is => 'rw', isa => 'Compiler' );
has 'extra_compiler_flags' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'compilation_log_errors' => ( is => 'rw', isa => 'Bool', default => 1);

has 'execution' => ( is => 'rw', isa => 'Exec' );
has 'analysis' => ( is => 'rw', isa => 'Analysis' );
has 'difference' => ( is => 'rw', isa => 'Diff' );
has 'valgrind' => ( is => 'rw', isa => 'Valgrind' );

sub compile
{
	my $self = shift;
	my $stage = new Stage();
	$stage->prepare($self);
	if ($stage->result ne 'success') { die "Couldn't stage ".$stage->result." (file ".$stage->result_error.")\n"; }

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	# compile
	$self->compilation(new Compiler());
	$self->compilation->compile($self);
	
	if ($self->compilation->result eq 'failure') {
		$self->log($Config->{Compilation}->{failure}."\n", 'both');
		$self->session->add_summary($Config->{Compilation}->{failure}."\n");
		$self->add_tag('compilation_failure');
		return;
	}

	my $log_to = 'both';
	if (not $self->compilation_log_errors)
	{
		$log_to = 'teacher';
	}
	
	# log result
	my $nocomit = $self->user_log->nocomit;
	$self->log_mode('comit');
	if ($self->compilation->result eq 'warnings')
	{
		$self->log($Config->{Compilation}->{warnings}."\n", $log_to);
		my $path = $self->compilation->output_path;
		$self->log(`cat $path`."\n\n", $log_to);
		$self->add_tag('compilation_warnings');
	}
	elsif ($self->compilation->result eq 'errors')
	{
		$self->log($Config->{Compilation}->{errors}."\n", $log_to);
		my $path = $self->compilation->output_path;
		$self->log(`cat $path`."\n\n", $log_to);
		$self->add_tag('compilation_errors');
	}
	if ($nocomit) { $self->log_mode('nocomit'); }
}

sub run
{
	my $self = shift;
	my $input = shift;
	
	$self->execution(new Run(unit => $self));
	$self->execution->exec($self,$input,@_);
}

sub run_grind
{
	my $self = shift;
	my $input = shift;
	$self->valgrind(new Valgrind(unit => $self));
	$self->valgrind->exec($self,$input,@_);
	$self->execution($self->valgrind);
}

sub diff_stdout
{
	my $self = shift;
	my $mode = shift;
	my $file = shift;

	$self->diff_generic($mode,$self->execution->stdout_path,$self->file_path."/".$file);
}

sub diff_stderr
{
	my $self = shift;
	my $mode = shift;
	my $file = shift;
	
	$self->diff_generic($mode,$self->execution->stderr_path,$self->file_path."/".$file);	
}

sub diff_generic
{
	my $self = shift;
	my $mode = shift;
	my $file1 = shift;
	my $file2 = shift;

	$self->difference(new Diff(unit => $self));
	$self->difference->exec($self,$mode,$file1,$file2);
}

sub analyze_stdout
{
	my $self = shift;
	my $cmd = shift;

	$self->analysis(new Analysis(unit => $self));
	$self->analysis->exec($self,$cmd,$self->execution->stdout_path,@_);
}

sub analyze_stderr
{
	my $self = shift;
	my $cmd = shift;

	$self->analysis(new Analysis(unit => $self));
	$self->analysis->exec($self,$cmd,$self->execution->stderr_path,@_);	
}

sub add_attachment
{
	my $self = shift;
	my $data = shift;
	my $type = shift;

	$type = 'both' unless defined $type;

	if ($type eq 'both' || $type eq 'teacher')
	{
		my $attach = new Attachment(filename => $self->work_path."/".$data);
		$self->session->add_teacher_attach($attach);
	}

	if ($type eq 'both' || $type eq 'student')
	{
		my $attach = new Attachment(filename => $self->work_path."/".$data);
		$self->session->add_student_attach($attach);
	}
}

sub log
{
	my $self = shift;
	my $data = shift;
	my $type = shift;

	$type = 'both' unless defined $type;

	if ($type eq 'both' || $type eq 'teacher')
	{
		$self->teacher_log->add_line($data);
	}

	if ($type eq 'both' || $type eq 'student')
	{
		$self->user_log->add_line($data);
	}
}

sub log_comit 
{ 
	my $self = shift;
	
	$self->user_log->comit();
	$self->teacher_log->comit();
}

sub log_purge 
{ 
	my $self = shift;

	$self->user_log->purge();
	$self->teacher_log->purge();
}

sub log_mode
{
	my $self = shift;
	my $comit = shift;

	if ($comit eq 'comit')
	{
		$self->user_log->set_comit();
		$self->teacher_log->set_comit();
	}

	if ($comit eq 'nocomit')
	{
		$self->user_log->set_nocomit();
		$self->teacher_log->set_nocomit();
	}
}

sub log_run_fail
{
	my $self = shift;
	my $prefix = shift;

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	if ($self->execution->exit_type eq 'error_system')
	{
		$self->log($prefix.$Config->{Run}->{fail_system}."\n");
	}
	elsif ($self->execution->exit_type eq 'limit_time')
	{
		$self->log($prefix.$Config->{Run}->{fail_time}."\n");
	}
	elsif ($self->execution->exit_type eq 'limit_size')
	{
		$self->log($prefix.$Config->{Run}->{fail_size}."\n");
	}
	elsif ($self->execution->exit_type eq 'error_signal')
	{
		$self->log($prefix.$Config->{Run}->{fail_signal});

		if ($self->execution->exit_value == 4)
		{ $self->log($prefix.$Config->{Run}->{fail_signal_ill}."\n"); }
		elsif ($self->execution->exit_value == 6)
		{ $self->log($prefix.$Config->{Run}->{fail_signal_abrt}."\n"); }
		elsif ($self->execution->exit_value == 8)
		{ $self->log($prefix.$Config->{Run}->{fail_signal_fpe}."\n"); }
		elsif ($self->execution->exit_value == 9)
		{ $self->log($prefix.$Config->{Run}->{fail_signal_kill}."\n"); }
		elsif ($self->execution->exit_value == 11)
		{ $self->log($prefix.$Config->{Run}->{fail_signal_segv}."\n"); }
		elsif ($self->execution->exit_value == 15)
		{ $self->log($prefix.$Config->{Run}->{fail_signal_term}."\n"); }
		elsif ($self->execution->exit_value == 25)
		{ $self->log($prefix.$Config->{Run}->{fail_size}."\n"); }
		else
		{ $self->log($prefix.$Config->{Run}->{fail_signal_gen}."\n"); } 
	}
	else { return; }
}

sub _build_report {
	my $self = shift;
	
	my $res = new Report(master => $self->master->name, unit => $self->name);
	$self->session->new_report($res);
	return $res;
}

sub log_tag {
	my $self = shift;
	my $tag = shift;
	
	$self->add_tag($tag);
	$self->log(@_);
}

sub subtest {
	my $self = shift;
	my $name = shift;
	
	my $res = new Report(master => $self->master->name, unit => $self->name, subtest => $name);
	$self->session->new_report($res);
	$self->report($res);
}

no Moose;
__PACKAGE__->meta->make_immutable;
