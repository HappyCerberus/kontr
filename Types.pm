#  Types.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Types;
use Moose;
use Moose::Util::TypeConstraints;

sub _config_helper {
	my $name = shift;
	return split ' ', Config::Tiny->new->read('config.ini')->{Submission}->{$name};
}

subtype 'SubmissionMode',
	as 'Str',
	where { my $m = $_; grep { $_ eq $m} _config_helper('modes') },
	message { 'Invalid submission mode' };

subtype 'SubmissionClass',
	as 'Str',
	where { my $c = $_; grep { $_ eq $c} _config_helper('classes') },
	message { 'Invalid submission class' };

subtype 'SubmissionModeStr',
	as 'Str',
	where { /^([^_]+_){2}[^_]+$/ },
	message { "$_ is not formated as SubmissionOpened" };

coerce 'SubmissionMode',
	from 'SubmissionModeStr',
	via { my @s = split /_/; $s[2]; };

subtype 'SubmissionModeArr',
	as 'ArrayRef[SubmissionMode]';

coerce 'SubmissionModeArr',
	from 'SubmissionMode',
	via { [ $_ ] };

no Moose;
__PACKAGE__->meta->make_immutable;
