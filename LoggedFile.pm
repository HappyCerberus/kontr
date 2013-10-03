#  LoggedFile.pm
#  
#  Copyright 2013 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package LoggedFile;

use Moose;
use Data::Dumper;

has 'before_size' => (is => 'ro', isa => 'Int', required => 1);
has 'filename' => (is => 'ro', isa => 'Str', required => 1);
has 'filesize' => (is => 'ro', isa => 'Int', required => 1);
has 'offset' => (is => 'rw', isa => 'Int'); #Offset of starting position of file in log without files
has 'attached' => (is => 'ro', isa => 'Bool', default => 0);

sub remove_from_log {
	my $self = shift;
	my $log = shift;
	my $additional_offset = shift; #Read bytes not present in log
	
	$self->offset($self->before_size - $additional_offset);
	
	#If the file is attached, then it does not remove anything in the log
	my $result_log = ($self->attached ? $log : 
		substr($log, 0, $self->offset).substr($log, $self->filesize + $self->offset));

	#TODO - the file may not be commited
	my $result_offset = $additional_offset + ($self->attached ? 0 : $self->filesize);
	
	return ($result_log, $result_offset);
}

sub get { 
	my $self = shift;
	
	my %data = (
		'offset' => $self->offset,
		'filename' => $self->filename,
		'filesize' => $self->filesize,
		'attached' => $self->attached
	);
	
	return \%data;
}

no Moose;
__PACKAGE__->meta->make_immutable;
