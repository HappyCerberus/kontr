# Copyright (c) 2013 Tomas Brukner (xbrukner@fi.muni.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package NoSVN;


use strict;
use warnings;

use Moose;
use Session;
use SVN;
use File::Basename;

extends 'SVN';

sub _build_revision {
	my $self = shift;
	
	return '0';
}

sub _build_url {
	my $self = shift;
	
	return $self->path;
}


sub _fetch_dir {
	my $self = shift;
	my $dir = shift;
	
	return -d $dir;
}

sub _fetch_file {
	my $self = shift;
	my $file = shift;
	my $optional = shift;
	my $rev = $self->revision;
	
	my $prev = dirname($file);
	my $name = basename($file);
	
	if (! $self->_fetch_dir($prev)) {
		$self->result('missing_files');
		$self->missing_files($self->missing_files.basename($prev)."/\n");
		return 1; #Immediate stop
	}
	
	if (-f $file) { return 0; }
	else {
		if (!$optional) {
			$self->result('missing_files');
			$self->missing_files($self->missing_files.$name."\n");
		}
		return 2;
	}
}

sub _checkout {
	return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;
