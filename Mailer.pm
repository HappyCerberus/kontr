# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Mailer;

use strict;
use warnings;
use MIME::Lite::TT; 
use Config::Tiny;

use Moose;

has 'to'	=> ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'reply'	=> ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'subject'	=> ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'template'	=> ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'params'	=> ( traits => ['Hash'], is => 'rw', isa => 'HashRef[Str]', default => sub { {} }, handles => { set_param => 'set', }, );

has 'templates' => ( traits => ['String'], is => 'rw', isa => 'Str', default => sub { my $Config = Config::Tiny->new; $Config = Config::Tiny->read('config.ini'); return $Config->{Email}->{templates}; } );

sub send 
{
	my $self = shift;
	my %options;
	my $msg;

	open FILE, "<".$self->templates.'/'.$self->template.'.tt';
	my $template = do { local $/; <FILE> };

	$msg = MIME::Lite::TT->new(
		From		=> $self->reply,
		To		=> $self->to,
		Subject		=> $self->subject,
		Template        => \$template,
		TmplOptions	=> \%options,
		TmplParams	=> $self->params,
	);


	my $attachment;
	while ($attachment = shift)
	{
		my $name = shift;
		my $mime = shift;
		
		$msg->attach(	Type => $mime,
				Path => $attachment,
				Filename => $name,
				Disposition => "attachment"
				);
	}

	$msg->send;
}

no Moose;
__PACKAGE__->meta->make_immutable;
