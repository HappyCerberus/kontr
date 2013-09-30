#  Action.pm
#  
#  Copyright 2013 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Action;

use Moose;
use Exec;
use File::Basename;

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'work_path' => (is => 'ro', isa => 'Str', required => 1);
has 'exec' => (is => 'rw', isa => 'Exec');
has 'created' => (is => 'rw', isa => 'ArrayRef[Str]', traits => ['Array'], handles => {add_created => 'push'}, default => sub { [] } );
has 'existing' => (is => 'rw', isa => 'HashRef', traits => ['Hash'], handles => { set_existing => 'set', was_existing => 'exists'} );
has 'metadata' => (is => 'rw', isa => 'HashRef', traits => ['Hash'], handles => { add_metadata => 'set' }, default => sub { {} });

sub _build_existing {
	my $self = shift;
	
	opendir(DIR, $self->work_path) or return;
	while (my $file = readdir(DIR)) {
		$self->add_existing($file);
	}
	closedir(DIR);
}

sub add_existing {
	my $self = shift;
	my $name = shift;
	
	$self->set_existing($name , 1);
}

sub BUILD {
	my $self = shift;
	
	$self->_build_existing();
}

sub finished {
	my $self = shift;
	my $exec = shift;
	
	$self->exec($exec);
	
	$self->_add_if_not_null($self->exec->stdin_path);
	$self->_add_if_not_null($self->exec->stdout_path);
	$self->_add_if_not_null($self->exec->stderr_path);
	
	$self->_build_created();
}

sub _build_created {
	my $self = shift;
	
	opendir(DIR, $self->work_path) or return;
	while (my $file = readdir(DIR)) {
		next if ($self->was_existing($file));
		$self->add_created($file);
	}
	closedir(DIR);
}

sub _add_if_not_null {
	my $self = shift;
	my $file = shift;
	
	if ($file ne '/dev/null' and dirname($file) eq $self->work_path ) {
		$self->add_existing(basename($file));
		return basename($file);
	}
	return $file;
}

sub _strip_dirname {
	my $self = shift;
	my $file = shift;
	
	if ($file ne '/dev/null' and dirname($file) eq $self->work_path) {
		return basename($file);
	}
	return $file;
	
}

sub get {
	my $self = shift;
	
	my %data = (
		'name' => $self->name,
		'command' => $self->exec->cmd,
		'args' => $self->exec->args,
		'stdin' => $self->_strip_dirname($self->exec->stdin_path),
		'stdout' => $self->_strip_dirname($self->exec->stdout_path),
		'stderr' => $self->_strip_dirname($self->exec->stderr_path),
		'exit_value' => $self->exec->exit_value,
		'exit_type' => $self->exec->exit_type,
		'created_files' => $self->created,
		'metadata' => $self->metadata,
		'run_time' => $self->exec->duration
	);
	
	return \%data;
}

sub add_metadata_file {
	my $self = shift; 
	my $name = shift;
	my $file = shift;
	
	if (dirname($file) eq $self->work_path) {
		$self->add_metadata($name, basename($file));
		$self->add_existing(basename($file));
	}
	else {
		$self->add_metadata($name, $file);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
