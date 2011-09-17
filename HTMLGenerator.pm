# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package HTMLGenerator;

use strict;
use warnings;

use Moose;
use POSIX;

has 'generated' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { add_file => 'push', files => 'elements' } );

sub generate
{
	my $self = shift;
	my $session = shift;

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	my $work_path = $Config->{Tests}->{stage_path};
	$work_path .= "/".$session->class;
	$work_path .= "/".$session->task;
	$work_path .= "/".$session->user->login."_".$session->timestamp;

	my $repo_path = $session->repo_path;

	my @files = split /\n/, `ls -1 $repo_path/*.c $repo_path/*.h $repo_path/*.cpp $repo_path/*.cc 2>/dev/null`;

	foreach (@files)
	{
		my $html = `basename $_`;
		chomp $html;
		$html = $work_path."/".$html.".html";	
		`vim -u ~/.vimrc_kontr -c ':TOhtml' -c ':x $html' -c ':qa!' $_ 2>/dev/null`;
		$self->add_file($html);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
