# Copyright (c) 2012, Tuomo Hartikainen All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: 
# 
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation
# are those of the authors and should not be interpreted as representing
# official policies, either expressed or implied, of the FreeBSD
# Project.


# This is more or less what your table should look like. The title column is
# not used with this release directly, but it is a planned feature. Also note,
# that the id column is expected to be auto incremented by some sequence (here
# links_id_seq).
#
#                 Table "public.links"
# Column  |     Type   |                     Modifiers
#---------+------------+---------------------------------------------------
# id      | integer    | not null default nextval('links_id_seq'::regclass)
# channel | text       | not null
# time    | timestamp  |
# nick    | text       | not null
# link    | text       | not null
# title   | text       |

use DBI;
use Irssi;
use Irssi::Irc;
use LWP::Simple;

use strict;

# Settings
my $dbname = "";
my $username = "";
my $password = "";

my $fetch_title = 0;

my $dbd = "DBI:Pg:dbname=" . $dbname; 
use vars qw($VERSION %IRSSI);

$VERSION = "0.2";
%IRSSI = (
        authors     => "Tuomo Hartikainen",
        contact     => "hartitu\@gmail.com",
        name        => "urllogpg",
        description => "logs URLs to postgreSQL database",
        license     => "Simplified BSD licence",
        url         => "http://harski.org/",
    );


sub get_title {
    my ($url) = @_;
    my $content = get($url) or return "";

    if($content =~ m/<title>(.*)<\/title>/i) {
        return $1;
    }
    return "";
}


sub log_urls {
    my ($line, $nick, $channel) = @_;
    while ($line =~ m/((?:https?|ftp):\/\/\S+\.\S+)/ig) {
        my $title = "";
        if ($fetch_title) {
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

    my $dbh = DBI->connect($dbd, $username, $password) or die("Cannot connect: " . $DBI::errstr);
    my $query = "INSERT INTO links VALUES (DEFAULT,". $dbh->quote($channel) . ", LOCALTIMESTAMP," . $dbh->quote($nick) . "," . $dbh->quote($url) . ", ";

    if(length $title == 0) {
        $query .= "DEFAULT)";
    } else {
        $query .= $dbh->quote($title) . ")";
    }

    my $sth = $dbh->do($query);
    $dbh->disconnect();
    return 1;
}


Irssi::signal_add_last('message public', 'chan_msg');
Irssi::signal_add_last('message own_public', 'own_msg');
Irssi::signal_add_last('message topic', 'topic_msg');

Irssi::print("Urllogpl loaded.");
