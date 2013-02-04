# Copyright (c) 2012, Tuomo Hartikainen. All rights reserved.
# Licensed under BSD 2-clause license. See LICENSE for details.

use DBI;
use Irssi;
use Irssi::Irc;
use LWP::Simple;

use strict;

# Settings
my $dbname = "";
my $username = "";
my $password = "";

# Set this to non-zero to enable fetching titles
my $fetch_title = 0;

my $link_regex = "((?:ftp|http)s?:\/\/[\-a-zA-Z0-9\.\?\$%&\/\)\(=_~#\.,:;\+]+)";

my $dbd = "DBI:Pg:dbname=" . $dbname;
use vars qw($VERSION %IRSSI);

$VERSION = "0.3";
%IRSSI = (
		authors		=> "Tuomo Hartikainen",
		contact		=> "hartitu\@gmail.com",
		name		=> "urllogpg",
		description	=> "logs URLs to postgreSQL database",
		license		=> "Simplified BSD licence",
		url			=> "http://harski.org/",
);

sub get_title {
	my ($url) = @_;
	my $content = get($url) or return undef;

	if($content =~ m/<title>(.*)<\/title>/i) {
		return $1;
	}
	return undef;
}

sub log_urls {
	my ($line, $nick, $channel) = @_;
	while ($line =~ m/$link_regex/g) {
		my $title;
		if ($fetch_title) {
			my $pid = fork();
			if ($pid) {
				exit(0);
			}
			$title = get_title($1);
		}
		insert($nick, $channel, $1, $title);
	}
	return 1;
}

sub chan_msg {
	my ($server, $line, $nick, $mask, $channel) = @_;
	return log_urls($line, $nick, $channel);
}

sub own_msg {
	my ($server, $line, $channel) = @_;
	return log_urls($line, $server->{nick}, $channel);
}

sub topic_msg {
	my ($server, $channel, $topic, $nick, $mask) = @_;
	return log_urls($topic, $nick, $channel);
}

sub insert {
	my ($nick, $channel, $url, $title)=@_;

	my $dbh = DBI->connect($dbd, $username, $password)
					or die("Cannot connect: " . $DBI::errstr);
	my $query = "INSERT INTO links VALUES (DEFAULT," .
				$dbh->quote($channel) . ", LOCALTIMESTAMP," .
				$dbh->quote($nick) . "," . $dbh->quote($url) . ", ";

	if(defined $title) {
		$query .= $dbh->quote($title) . ")";
	} else {
		$query .= "DEFAULT)";
	}

	my $sth = $dbh->do($query);
	$dbh->disconnect();
	return 1;
}


Irssi::signal_add_last('message public', 'chan_msg');
Irssi::signal_add_last('message own_public', 'own_msg');
Irssi::signal_add_last('message topic', 'topic_msg');

Irssi::print("Urllogpl loaded.");
