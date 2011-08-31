# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package UserInfo;

use strict;
use warnings;
use Moose;

has 'login' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'email' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'uco'   => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'name'  => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

no Moose;
__PACKAGE__->meta->make_immutable;
