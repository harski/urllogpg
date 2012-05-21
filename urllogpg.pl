#                                    Table "public.links"
# Column  |            Type             |                     Modifiers
#---------+-----------------------------+---------------------------------------------------
# id      | integer                     | not null default nextval('links_id_seq'::regclass)
# channel | text                        | not null
# time    | timestamp without time zone |
# nick    | text                        | not null
# link    | text                        | not null
# title   | text                        |

use DBI;
use Irssi;
use Irssi::Irc;

use strict;

my $dbname = "";
my $username = "";
my $password = "";

my $dbd = "DBI:Pg:dbname=" . $dbname; 
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
        authors     => "Tuomo Hartikainen",
        contact     => "hartitu\@gmail.com",
        name        => "urllogpg",
        description => "logs URLs to postgreSQL database",
        license     => "BSD",
        url         => "http://harski.org/",
    );


sub log_urls {
    my ($server, $line, $nick, $channel) = @_;
    if ($line =~ m/((?:https?|ftp):\/\/\S+\.\S+)/i) {
        return insert($nick, $channel, $1, "");
    }
    return 0;
}


sub chan_msg {
    my ($server, $line, $nick, $mask, $channel) = @_;
    return log_urls($server, $line, $nick, $channel);
}


sub own_msg {
    my ($server, $line, $target) = @_;
    return log_urls($server, $line, $server->{nick}, $target);
}


sub insert {
    my ($nick, $channel, $url, $title)=@_;
    my $dbh = DBI->connect($dbd, $username, $password) or die("Cannot connect: " . $DBI::errstr);
    my $query = "INSERT INTO links VALUES (DEFAULT,". $dbh->quote($channel) . ", LOCALTIMESTAMP," . $dbh->quote($nick) . "," . $dbh->quote($url) . ", DEFAULT)";
    my $sth = $dbh->do($query);
    $dbh->disconnect();
    return 1;
}


Irssi::signal_add_last('message public', 'chan_msg');
Irssi::signal_add_last('message own_public', 'own_msg');
#Irssi::signal_add_last('message topic', 'topic_msg');

Irssi::print("Urllogpl loaded.");
