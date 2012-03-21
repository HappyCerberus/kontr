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
#has '__override' => (is => 'rw', isa => 'Bool', default => 0, predicate => '__is_override', clearer => '__no_override');
#Override has_lock functionality in order to make Lock->add_lock work

subtype 'TimeStr',
	as 'Str',
	where {
		return 0 unless /[0-9]{14}\Z/;
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

subtype 'TimeLockFilename',
	as 'Str',
	where {
		return 0 unless /^.*_[0-9]{14}$/;
				
		my $time = substr $_, -14;
		my $name = substr $_, 0, -15;
		return 0 unless length $name;
		find_type_constraint('TimeStr')->check($time);	
	};

coerce 'TimeStr',
	from 'TimeLockFilename',
	via { substr basename($_), -14; };

subtype 'TimeLockValidFilename',
	as 'TimeLockFilename',
	where {
		my $time = substr $_, -14;
		find_type_constraint('TimeStrFuture')->check($time);
	};

around 'has_lock' => sub
{
	my $orig = shift;
	my $self = shift;
	$self->_cleanup();
	
	my @locks = $self->_valid_files;
	return 0 unless scalar @locks;
	$self->_max(@locks);
	return 1;	
};

around '_lock' => sub
{
	my $orig = shift;
	my $self = shift;
	if ($self->has_lock) {
		return $self->directory.'/'.$self->name.'_'.$self->until->strftime(pattern());
	}
	else {
		my $t = DateTime->now->add_duration($self->duration);
		return $self->directory.'/'.$self->name.'_'.$t->strftime(pattern());
	}
};

around 'add_lock' => sub {
	my $orig = shift;
	my $self = shift;
	if ($self->has_lock) { $self->remove_lock; }

	my $res = $self->$orig(@_);
	if ($res) {
		$self->_cleanup(1); #Count max
	}
	return $res;
};

around 'remove_lock' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $res = $self->$orig(@_);
	if ($res) { $self->_no_lock; }
	return $res;
};

sub _files {
	my $self = shift;
	
	opendir(DIR, $self->directory) || die("Cannot open lock directory");
	my @files = readdir(DIR);
	closedir(DIR);
	@files;
}

sub _filter_files {
	my $self = shift;
	my $type = shift;
	if (not @_) { @_ = $self->_files; }

	my $name = $self->name;
	grep { /^${name}_[0-9]{14}$/ and find_type_constraint($type)->check($_); } @_;
}

sub _valid_files {
	my $self = shift;
	$self->_filter_files('TimeLockValidFilename', @_);
}

sub _lock_files {
	my $self = shift;
	$self->_filter_files('TimeLockFilename', @_);
}

sub _max {
	my $self = shift;
	my $max = DateTime->from_epoch( epoch => 0 ); #Necessarily lowest value
	
	if (not @_) { @_ = $self->_valid_files; }
	
	foreach (@_) {
		my $dt = find_type_constraint('DateTime')->coerce($_);
		if (DateTime->compare($max, $dt) == -1) {
			$max = $dt;
		}
	}
	if (@_) { $self->until($max); }
	else { $self->_no_lock; }
};

sub _cleanup
{
	my $self = shift;
	unless ($self->write) {
		$self->_max if scalar @_; #If force count of maximum
		return;
	}

	my @locks = $self->_lock_files; #Only this name
	return unless scalar @locks;
	
	my @valid;
	foreach (@locks) { #Old locks
		if (not find_type_constraint('TimeLockValidFilename')->check($_)) {
			my $p = $self->directory.'/'.$_;
			`rm -f $p`;
		}
		else { push @valid, ($_); } 
	}
	$self->_max(@valid);
	
	foreach (@valid) { #Only newest lock should remain
		if ( DateTime->compare($self->until, find_type_constraint('DateTime')->coerce($_)) ) {
			my $p = $self->directory.'/'.$_;
			`rm -f $p`; 
		}
	}
};

no Moose;
__PACKAGE__->meta->make_immutable;
