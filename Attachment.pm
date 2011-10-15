# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Attachment;

use strict;
use warnings;
use Config::Tiny;

use Moose;

has 'filename' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'name'     => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'mime'     => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

sub BUILD
{
	my $self = shift;
	my $args = shift;

	my $conf = Config::Tiny->new;
	$conf = Config::Tiny->read('config.ini');

	unless (exists $args->{'mime'})
	{
		my $script = $conf->{Global}->{ext_bins}."/getmime.sh";
		my $path = $self->filename;
		my $type = `$script $path`;
		chomp $type;
		$self->mime($type);
	} 
	
	unless (exists $args->{'name'})
	{
		my $path = $self->filename;
		my $short = `basename $path`;
		chomp $short;
		$self->name($short);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
