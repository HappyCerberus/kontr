# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Helpers;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;

subtype 'filename'
	=> as 'Str'
	=> where { -r $_ }
	=> message { "$_ is not a readable file" };

subtype 'directory'
	=> as 'Str'
	=> where { -d $_ }
	=> message { "$_ is not an existing directory" };

no Moose;
__PACKAGE__->meta->make_immutable;
