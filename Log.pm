# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Log;

use warnings;
use strict;

use Moose;

has 'parent' => ( is => 'rw', isa => 'Log' );
has 'data' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'nocomit' => ( traits => ['Bool'], is => 'rw', isa => 'Bool', default => 0, handles => { set_nocomit => 'set', set_comit => 'unset' } );

sub add_line 
{
	my $self = shift;
	my $line = shift;

	$self->add_raw( ($line // "") ."\n");
}

sub add_raw 
{ 
	my $self = shift;
	my $line = shift;

	if ($self->nocomit)
	{
		$self->data($self->data.$line);
	}
	else
	{
		if (defined $self->parent)
		{ $self->parent->data($self->parent->data.$line); }
		else
		{ $self->data($self->data.$line); }
	}
}

sub comit
{
	my $self = shift;

	if ($self->nocomit && defined $self->parent)
	{
		$self->parent->add_raw($self->data);
		$self->purge();
	}
}

sub purge
{
	my $self = shift;

	if ($self->nocomit)
	{
		$self->data('');
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
