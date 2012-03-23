#  Lock.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Lock;

use Fcntl;
use Moose;
use Moose::Util::TypeConstraints;

use Types;

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'directory' => (is => 'ro', isa => 'Directory', required => 1);
	
sub _lock {
	my $self = shift;
	$self->directory.'/'.$self->name;
}

sub has_lock {
	my $self = shift;
	-f $self->_lock;
}

sub add_lock {
	my $self = shift;
	if ($self->has_lock) { return 0; }
	my $fh;
	if (not sysopen $fh, $self->_lock, O_WRONLY|O_EXCL|O_CREAT) {
		return 0;
	}
	close($fh);
	return 1;	
}

sub obtain_lock {
	my $self = shift;
	while (not $self->add_lock()) {
		sleep(int(rand(10)));
	}
}

sub remove_lock {
	my $self = shift;
	if (not $self->has_lock) { return 0; }
	my $lock = $self->_lock;
	`unlink $lock;`;
	not $self->has_lock;
}

no Moose;
__PACKAGE__->meta->make_immutable;
