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

has 'name' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' ); 

has 'stage_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_file => 'push', staged_files => 'elements' } );

has 'compiled_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_file => 'push', staged_compiled_files => 'elements', compiled_files_string => 'join' } );

has 'stage_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_student_file => 'push', staged_student_files => 'elements' } );

has 'compiled_student_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { stage_compiled_student_file => 'push', staged_compiled_student_files => 'elements', compiled_student_files_string => 'join' } );

has 'master' => ( is => 'rw', isa => 'MasterTest' );
has 'session' => ( is => 'rw', isa => 'Session' );

has 'work_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'user_log' => ( is => 'rw', isa => 'Log' );
has 'teacher_log' => ( is => 'rw', isa => 'Log' );

has 'compilation' => ( is => 'rw', isa => 'Compiler' );
has 'extra_compiler_flags' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'execution' => ( is => 'rw', isa => 'Run' );
has 'analysis' => ( is => 'rw', isa => 'Analysis' );
has 'difference' => ( is => 'rw', isa => 'Diff' );

sub compile
{
	my $self = shift;
	my $stage = new Stage();
	$stage->prepare($self);

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	# compile
	$self->compilation(new Compiler());
	$self->compilation->compile($self); 

	# log result
	my $nocomit = $self->user_log->nocomit;
	$self->log_mode('comit');
	if ($self->compilation->result eq 'warnings')
	{
		$self->log($Config->{Compilation}->{warnings}."\n");
		my $path = $self->compilation->output_path;
		$self->log(`cat $path`."\n\n");
	}
	elsif ($self->compilation->result eq 'errors')
	{
		$self->log($Config->{Compilation}->{errors}."\n");
		my $path = $self->compilation->output_path;
		$self->log(`cat $path`."\n\n");
	}
	if ($nocomit) { $self->log_mode('nocomit'); }
}

sub run
{
	my $self = shift;
	my $input = shift;
	
	$self->execution(new Run());
	$self->execution->exec($self,$input,@_);
}

sub diff_stdout
{
	my $self = shift;
	my $mode = shift;
	my $file = shift;

	$self->diff_generic($mode,$self->execution->stdout_path,$file);
}

sub diff_stderr
{
	my $self = shift;
	my $mode = shift;
	my $file = shift;
	
	$self->diff_generic($mode,$self->execution->stderr_path,$file);	
}

sub diff_generic
{
	my $self = shift;
	my $mode = shift;
	my $file1 = shift;
	my $file2 = shift;

	$self->difference(new Diff());
	$self->difference->exec($self,$mode,$file1,$file2);
}

sub analyze_stdout
{
	my $self = shift;
	my $cmd = shift;

	$self->analysis(new Analysis());
	$self->analysis->exec($self,$cmd,$self->execution->stdout_path,@_);
}

sub analyze_stderr
{
	my $self = shift;
	my $cmd = shift;

	$self->analysis(new Analysis());
	$self->analysis->exec($self,$cmd,$self->execution->stderr_path,@_);	
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

no Moose;
__PACKAGE__->meta->make_immutable;
