package UnitTest;

use strict;
use warnings;
use Moose;

has 'name' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' ); 

no Moose;
__PACKAGE__->meta->make_immutable;
