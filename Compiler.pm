# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Compiler;

use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints;

use Exec;

enum 'CompileResult', [ qw(clean warnings errors) ];
has 'result' => ( isa => 'CompileResult', is => 'rw', default => 'errors' );

has 'output_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' ); 

sub compile
{
	my $self = shift;
	my $test = shift;

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	my $has_warnings = 0;
	my $comp_bin = $Config->{$test->session->class}->{compiler};
	my $comp_flags = $Config->{$test->session->class}->{flags};

	my $f1 = $test->compiled_files_string(" ");
	my $f2 = $test->compiled_student_files_string(" ");
	my $f3 = $test->master->compiled_files_string(" ");
	my $f4 = $test->master->compiled_student_files_string(" ");
	my $f5 = $test->extra_compiler_flags;
	
	my $cmd = " ";
	if (defined $f1) { $cmd .= " ".$f1; }
	if (defined $f2) { $cmd .= " ".$f2; }
	if (defined $f3) { $cmd .= " ".$f3; }
	if (defined $f4) { $cmd .= " ".$f4; }
        if (defined $f5) { $cmd .= " ".$f5; }

	$cmd = $comp_flags." ".$cmd." -o ".$test->name;
	
	my $compile = new Exec(cmd => $comp_bin, work_path => $test->work_path, limit_runtime => '120');
	$compile->exec(split(' ',$cmd." -Werror"));
	if ($compile->failure || $compile->exit_value != 0)
	{
		$has_warnings = 1; # warnings or errors present
	}	
	
	$compile = new Exec(cmd => $comp_bin, work_path => $test->work_path, output_path => $test->work_path."/compilation", limit_runtime => 120);
	$compile->exec(split(' ',$cmd));
	if ($compile->failure || $compile->exit_value != 0)
	{
		$self->result('errors');
		$self->output_path($compile->stderr_path);
		return;
	}
	elsif ($has_warnings)
	{
		$self->result('warnings');
		$self->output_path($compile->stderr_path);
		return;
	}
	$self->result('clean');
	$self->output_path($compile->stderr_path);
}

no Moose;
__PACKAGE__->meta->make_immutable;
