# Copyright (c) 2013 Tomas Brukner <xbrukner@fi.muni.cz>
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Plagiarism;

use strict;
use warnings;

use Moose;
use POSIX;

has 'used_whole' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { add_whole => 'push' } );
has 'used_diffed' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { add_diffed => 'push' } );

sub generate
{
	my $self = shift;
	my $session = shift;
	my $filepath = shift;

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	my $output_file = "$filepath/plagiarism";
	my $log_file = "$filepath/plagiarism_log";
	my $repo_path = $session->repo_path."/".$session->task;
	my $files_prefix = $Config->{Tests}->{files_path}.'/'.$session->class.'/'.$session->task.'/plagiarism_';
	
	system("touch $log_file");
	system("touch $output_file");

	for my $file ($session->all_available_files)
	{
		if ( -f $files_prefix.$file) {
			system("echo '$file: diffed' >> $log_file");
			system("diff -iw ${files_prefix}${file} $repo_path/$file | grep '^>' | sed 's/^> //' >> $output_file");
			$self->add_diffed($file);
		}
		else {
			system("echo '$file: whole' >> $log_file");
			system("cat $repo_path/$file >> $output_file");
			$self->add_whole($file);
		}
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
