# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Valgrind;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;
use File::Temp;

use Exec;
extends 'Exec';

has 'grind_errors' => ( traits => ['Bool'], is => 'rw', isa => 'Bool', default => 0 );
has 'grind_data' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'grind_user' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'grind_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

around 'exec' => sub
{
	my $orig = shift;
	my $self = shift;
	my $unit_test = shift;
	my $input = shift;

	if ($unit_test->session->got_value('run_timeout'))
	{ $self->limit_runtime($unit_test->session->get_value('run_timeout')); }

	my $tmp = File::Temp->new( TEMPLATE => 'grindXXXX', DIR => $unit_test->work_path, SUFFIX => '.out', UNLINK => 0);

	$self->work_path($unit_test->work_path);
	$self->cmd("valgrind",$unit_test->work_path."/".$unit_test->name);
	$self->stdin_path($input);
	$self->output_path($unit_test->work_path."/execution");	

	my $pid = $self->$orig("--leak-check=full","--track-fds=yes","--log-file=".$tmp->filename,$unit_test->work_path."/".$unit_test->name,@_);
	
	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');
	my $grind_bin = $Config->{Global}->{ext_bins}."/grind";
	my $grind_empty = $Config->{Global}->{ext_bins}."/grind_empty";
	my $grind_in = $tmp->filename;
	my $grind_stdout = $unit_test->work_path."/grind.".$pid.".stdout";
	my $grind_stderr = $unit_test->work_path."/grind.".$pid.".stderr";
	`$grind_bin $grind_in >$grind_stdout 2>$grind_stderr`;
	my $res = `diff $grind_stdout $grind_empty`;

	$self->grind_errors(length $res > 0);
	$self->grind_data($grind_stdout);
	$self->grind_user($grind_stderr);
	$self->grind_path($grind_in);
};

no Moose;
__PACKAGE__->meta->make_immutable;
