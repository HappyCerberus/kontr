#  TimeLock.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package TimeLock;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime;
use DateTime::Format::Strptime;

use Lock;
extends 'Lock';

sub pattern { '%Y%m%d%H%M%S' }

has 'duration' => (is => 'ro', isa => 'DateTime::Duration', required => 1);
has 'until' => (is => 'rw', isa => 'DateTime', predicate => 'has_until', clearer => '_no_lock');
has 'write' => (is => 'ro', isa => 'Bool', default => 0);
has '__override' => (is => 'rw', isa => 'Bool', default => 0); #Override has_lock functionality in order to make Lock->add_lock work

subtype 'TimeStr',
	as 'Str',
	where {
		return 0 unless /^[0-9]{14}\$/;
		DateTime::Format::Strptime->new( pattern => pattern() )->parse_datetime($_);
		};
		
subtype 'TimeStrFuture',
	as 'TimeStr',
	where { DateTime->compare(find_type_constraint("DateTime")->coerce($_), DateTime->now) == 1 };
	
coerce 'DateTime',
	from 'TimeStr',
	via {
		DateTime::Format::Strptime->new( pattern => pattern() )->parse_datetime($_);
	};

subtype 'TimeLockFile',
	as 'Str',
	where {
		return 0 unless -e;
		return 0 unless /^.*_[0-9]{14}\$/, basename($_);
		
		my $base = basename($_);
		my $time = substr $base, -14;
		my $name = substr $base, 0, -15;
		return 0 unless length $name;
		find_type_constraint('TimeStr')->check($time);	
	};

coerce 'TimeStr',
	from 'TimeLockFile',
	via { substr basename($_), -14; };

subtype 'TimeLockValidFile',
	as 'TimeLockFile',
	where {
		my $time = substr basename($_), -14;
		find_type_constraint('TimeStrFuture')->check($time);
	};

around 'has_lock' => sub
{
	my $self = shift;
	if ($self->__override) { return 0; }
	$self->cleanup();
	
	opendir(DIR, $self->directory) || die("Cannot open lock directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	my $name = $self->name;
	my @locks = grep { if (/^${name}_[0-9]{14}/) { return find_type_constraint('TimeLockValidFile')->check($_); } } @files;
	return 0 unless scalar @locks;
	$self->_max(@locks);
	return 1;	
};

around '_lock' => sub
{
	my $self = shift;
	if ($self->has_until) {
		return $self->directory.'/'.$self->name.'_'.$self->until->strftime(pattern());
	}
	else {
		my $t = DateTime->now->add_duration($self->duration);
		return $self->directory.'/'.$self->name.'_'.$t->strftime(pattern());
	}
};

around 'add_lock' => sub {
	my $self = shift;
	$self->__override = 1;
	my $res = $self->orig(@_);
	$self->__override = 0;
	if ($res) {
		$self->_cleanup();
	}
	return $res;
};

around 'remove_lock' => sub {
	my $self = shift;
	my $res = $self->orig(@_);
	if ($res) {
		$self->_no_lock;
	}
	return $res;
};

sub _max {
	my $self = shift;
	my $max = DateTime->from_epoch( epoch => 0 ); #Necessarily lowest value
	
	foreach (@_) {
		my $dt = find_type_constraint('DateTime')->coerce($_);
		if (DateTime->compare($max, $dt) == 1) {
			$max = $dt;
		}
	}
	
	$self->until($max);
};

sub _cleanup
{
	my $self = shift;
	return unless $self->write;
	
	opendir(DIR, $self->directory) || die("Cannot open lock directory");
	my @files = readdir(DIR);
	closedir(DIR);
	
	my @locks = grep { find_type_constraint('TimeLockFile')->check($_) } @files;
	return unless scalar @locks;
	my @valid;
	
	foreach (@locks) { #Old locks
		if (not find_type_constraint('TimeLockValidFile')->check($_)) {
			`rm -f $_`;
		}
		else { push @valid, ($_); } 
	}
	$self->_max(@valid);
	
	foreach (@valid) { #Only newest lock should remain
		if ( DateTime->compare($self->until, find_type_constraint('DateTime')->coerce($_)) ) {
			`rm -f $_`;
		}
	}
};
