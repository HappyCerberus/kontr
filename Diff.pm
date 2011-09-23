# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Diff;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;

use Exec;
extends 'Exec';

around 'exec' => sub
{
	my $orig = shift;
	my $self = shift;
	my $unit_test = shift;
	my $mode = shift;
	my $f1 = shift;
	my $f2 = shift;

	$self->work_path($unit_test->work_path);
	$self->cmd('diff');
	$self->stdin_path('/dev/null');
	$self->output_path($unit_test->work_path."/difference");
	if ($mode eq 'case')
	{ return $self->$orig('-c','-i',$f1,$f2); }
	elsif ($mode eq 'space')
	{ return $self->$orig('-c','-b','-B','-w',$f1,$f2); }
	elsif ($mode eq 'normal')
	{ return $self->$orig('-c',$f1,$f2); }
	elsif ($mode eq 'casespace')
	{ return $self->$orig('-c','-b','-B','-w','-i',$f1,$f2); }
};

no Moose;
__PACKAGE__->meta->make_immutable;
