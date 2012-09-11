#  Submission.pm
#  
#  Copyright 2012 Tomáš Brukner <xbrukner@fi.muni.cz>
#  
# Licensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Report;

#use MasterTest;
#use UnitTest;
use Moose;
use Moose::Util::TypeConstraints;

#has 'master' => ( is => 'ro', isa => 'MasterTest', required => 1 );
#has 'unit' => ( is => 'ro', isa => 'UnitTest', required => 1 );
has 'master' => ( is => 'ro', isa => 'Str', required => 1 );
has 'unit' => ( is => 'ro', isa => 'Str', required => 1 );
has 'subtest' => ( is => 'rw', isa => 'Str', predicate => 'has_subtest' );
has 'tags' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { addTag => 'push', allTags => 'elements', hasTag => 'grep' } );
has 'points' => ( traits => ['Hash'], is => 'rw', isa => 'HashRef[Num]', default => sub { {} }, handles => { addPoints => 'set', allPoints => 'kv' } );

sub summary {
	my $self = shift;
	
	#$self->master->name.'/'.$self->unit->name.($self->has_subtest ? '/'.$self->subtest : '').': '.
	$self->master.'/'.$self->unit.($self->has_subtest ? '/'.$self->subtest : '').': '.
	join(' ', $self->allTags).'; '.join(' ', map { $_->[0].'='.$_->[1] } $self->allPoints );
}

sub sumPoints {
	my %res = ();
	my $data = shift;
		
	foreach my $report ( @$data ) {
		foreach ( $report->allPoints ) {
			if (exists $res{$_->[0]} ) { $res{$_->[0]} += $_->[1]; }
			else { $res{$_->[0]} += $_->[1]; }
		}
	}
	return %res;
}

sub sumTags {
	my $data = shift;
	
	use List::MoreUtils qw(uniq);
	uniq( map { $_->allTags } @$data );
}

no Moose;
__PACKAGE__->meta->make_immutable;
