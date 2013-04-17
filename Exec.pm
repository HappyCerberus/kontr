# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Exec;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;
use BSD::Resource;

use Helpers;
use POSIX;
#use Cwd;
use File::stat;
use Time::HiRes qw(usleep nanosleep);

has 'cmd' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'output_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'stdin_path' => ( traits => ['String'],  is => 'rw', isa => 'Str', default => '/dev/null' );
has 'stdout_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '/dev/null' );
has 'stderr_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '/dev/null' );
has 'work_path' => ( is => 'rw', isa => 'directory', default => '/home/xtoth1' );

has 'limit_runtime' => ( traits => ['Number'], is => 'rw', isa => 'Int', default => 20 );
has 'limit_output' => ( traits => ['Number'], is => 'rw', isa => 'Int', default => 65536 );

enum 'ExitType', [ qw(normal error_signal error_system limit_time limit_size) ];

has 'success' => ( traits => ['Bool'], is => 'rw', isa => 'Bool', default => 1, handles => { failure => 'not' } );
has 'exit_type' => ( isa => 'ExitType', is => 'rw', default => 'normal' );
has 'exit_value' =>  (traits => ['Number'], is => 'rw', isa => 'Int', default => 0 );

has 'unit' => ( isa => 'UnitTest', is => 'rw' );

sub log_stdout
{
	my $self = shift;
	my $type = shift;

	my $path = $self->stdout_path;
	my $data = `cat $path`;
	$data = "" unless defined $data;
	$self->unit->log($data,$type);
}

sub log_stderr
{
	my $self = shift;
	my $type = shift;

	my $path = $self->stderr_path;
	my $data = `cat $path`;
	$data = "" unless defined $data;
	$self->unit->log($data,$type);
}

sub exec
{
	my $self = shift;
        my $origdir = getcwd();

        # fork the program
        my $pid = fork();
        if ($pid < 0) # system error, cannot fork
        {
		$self->success(0);
		$self->exit_type('error_system');
		$self->exit_value(0);
        }

	if ($pid == 0) # child
	{
		# change the working directory
		chdir $self->work_path;

		# redirect outputs
		if ($self->stdin_path ne '')
		{
			open STDIN,  "<".$self->stdin_path;
		}
		else
		{
			open STDIN, "</dev/null";
		}

		if ($self->output_path ne '')
		{
			open STDOUT, ">".$self->output_path.".$$.stdout";
			open STDERR, ">".$self->output_path.".$$.stderr";
		}
		else
		{
			open STDOUT, ">".$self->stdout_path;
			open STDERR, ">".$self->stderr_path;
		}
		
		# Use setrlimit to limit program output size
		setrlimit(RLIMIT_FSIZE, $self->limit_output, $self->limit_output);

		# execute the program
		unshift (@_,$self->cmd);
		{ exec @_; };

		die "This state shouldn't be reached. exec failed"; 
	}
	else # parent
	{
		my $starttime = time();
		my $deadpid = 0;
		my $result = 0;

		my $stdout;
		my $stderr;

		if ($self->output_path ne '')
		{
			$stdout = $self->output_path.".".$pid.".stdout";
			$stderr = $self->output_path.".".$pid.".stderr";
		}
		else
		{
			$stdout = $self->stdout_path;
			$stderr = $self->stderr_path;
		}

		$self->stdout_path($stdout);
		$self->stderr_path($stderr);

		my $end_type; 

		while($deadpid <= 0)
		{
			my $filesize = 0;

			# timeout - program running too long
			if (time() - $starttime > $self->limit_runtime)
			{
				$end_type = 'timeout';
				last;
			}

			if (-r $stdout) { $filesize += stat($stdout)->size; }
			if (-r $stderr) { $filesize += stat($stderr)->size; }

			# captured output to large
			if ($filesize > $self->limit_output)
			{
				$end_type = 'size';
				last;
			}
			
			$deadpid = waitpid($pid, WNOHANG);
			if ($deadpid > 0)
			{
				$result = $?;
				$end_type = 'exit';
				last;
			}

			usleep(50); # wait for a while
		}

		if ($end_type ne 'exit')
		{
			kill(9,$pid);
			wait();
			$result = $?;
		}

                if ($end_type eq 'timeout')
                {
			$self->success(0);
			$self->exit_type('limit_time');
			$self->exit_value(WTERMSIG($result));
                }
		elsif ($end_type eq 'size')
		{
			$self->success(0);
			$self->exit_type('limit_size');
			$self->exit_value(WTERMSIG($result));
		}
                elsif (WIFSIGNALED($result))
                {
			$self->success(0);
			$self->exit_type('error_signal');
			$self->exit_value(WTERMSIG($result));
                }
                elsif (WIFEXITED($result))
                {
			$self->success(1);
			$self->exit_type('normal');
			$self->exit_value(WEXITSTATUS($result));
                }

                return $pid;
        }
}

no Moose;
__PACKAGE__->meta->make_immutable;
