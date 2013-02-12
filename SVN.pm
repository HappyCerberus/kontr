# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package SVN;

use strict;
use warnings;

use Moose;
use Mailer;
use Config::Tiny;
use Exec;
use Session;
use Moose::Util::TypeConstraints;
use File::Basename;
use File::Slurp qw(read_file);

enum 'SVNResult', [ qw(success cant_update cant_download missing_files) ];
has 'result' => ( is => 'rw', isa => 'SVNResult', default => 'success' );
has 'url' => (is => 'rw', isa => 'Str', lazy_build => 1);
has 'revision' => (is => 'rw', isa => 'Str', lazy_build => 1);
has 'missing_files' => (is => 'rw', isa => 'Str', default => '');
has 'session' => (is => 'rw', isa => 'Session', required => 1);
has 'config' => (is => 'ro', isa => 'Config::Tiny', lazy_build => 1);

sub BUILDARGS
{
	my $class = shift;

	die "Wrong number of parameters for SVN" unless scalar @_ == 1;
	
	my $session = shift;
	return { 'session' => $session };
}

sub _build_revision {
	my $self = shift;
	my $url = $self->url;
	
	my $rev = `svn info $url | grep Revision | sed -e 's/[^0-9]*//'`;
	$rev =~ s/\s+$//;
	
	return $rev;
}

sub _build_url {
	my $self = shift;
	
	$self->url($self->config->{SVN}->{base_url}."/".$self->session->user->login."_".$self->session->class);
}

sub _build_config {
	Config::Tiny->new->read('config.ini');
}

sub _handle_error {
	my $self = shift;
	
	if ($self->result eq 'success') { return 0; }
	
	# report error by email
	my $mail = new Mailer(	to => $self->session->user->email, 
				reply => $self->config->{Global}->{admin}, 
				subject => $self->config->{SVN}->{$self->result.'_subj'},
				template => 'svn_'.$self->result);
	
	if ($self->result eq 'missing_files') {
		$mail->set_param(files => $self->missing_files);
	}
	else {
		$mail->set_param(repo => $self->url);
	}
	
	$mail->message()->send();
	return 1;
}

sub _fetch_dir {
	my $self = shift;
	my $dir = shift;
	my $rev = $self->revision;
	
	if (-d $dir) { return 1; } #End recursion when you find existing directory
	else {
		my $prev = dirname($dir);
		my $name = basename($dir);
		
		if (! $self->_fetch_dir($prev)) { return 0; }
		
		my $cmd = "cd $prev; svn update $name -r $rev --depth empty;";
		if (system($cmd) != 0) {
			$self->result('cant_update');
		}
	}
	
	return -d $dir;
}

sub _fetch_file {
	my $self = shift;
	my $file = shift;
	my $optional = shift;
	my $rev = $self->revision;
	
	my $prev = dirname($file);
	my $name = basename($file);
	
	if (! $self->_fetch_dir($prev)) {
		if ($self->result eq 'success') {
			$self->result('missing_files');
			$self->missing_files($self->missing_files.basename($prev)."/\n");
		}
		return 1; #Immediate stop
	}
	
	my $cmd = "cd $prev; svn update -r $rev $name";
	if (system("$cmd") != 0) {
		$self->result('cant_update');
		return 1; #Immediate stop
	}
	
	if (-f $file) { return 0; }
	else {
		if (!$optional) {
			$self->result('missing_files');
			$self->missing_files($self->missing_files.$name."\n");
		}
		return 2;
	}
}

sub _checkout {
	my $self = shift;
	my $path = shift;
	my $url = $self->url;
	
	if (system ("svn checkout $url $path --depth empty") != 0) {
		$self->result('cant_download');
		return 1;
	}
	return 0;
}
sub fetch
{
	my $self = shift;

	my $path = $self->config->{SVN}->{base_path}."/".$self->session->user->login."_".$self->session->class;

	if (! -d $path) { #If path exists, update will be done during download
		if ($self->_checkout($path)) { #cant_download
			$self->_handle_error();
			return;
		}
	}

	$self->session->repo_path($path);
	my $prefix = $path.'/'.$self->session->task.'/';
	my @files = read_file($self->config->{Tests}->{files_path}."/".$self->session->class."/".$self->session->task."/required_files");
	my @required = map { my $s = $prefix.$_; $s =~ s/\s+$//; $s; } (grep /^[^\?]/, @files);
	my @optional = map { my $s = $prefix.substr($_, 1); $s =~ s/\s+$//; $s; } (grep /^\?/, @files);

	for my $file (@required) {
		my $res = $self->_fetch_file($file);
		if ($res == 1) { #If you should stop immediately (cant_update)
			$self->_handle_error();
			return;
		}
		elsif ($res == 0) {
			$self->session->add_available_file(substr $file, length $prefix);
		}
	}
	for my $file (@optional) {
		my $res = $self->_fetch_file($file, 1);
		if ($res == 1) { #If you should stop immediately (cant_update)
			$self->_handle_error();
			return;
		}
		elsif ($res == 0) { #File available
			$self->session->add_available_file(substr $file, length $prefix);
		}
	}
	$self->_handle_error(); #If there are missing files, report them
}

no Moose;
__PACKAGE__->meta->make_immutable;
