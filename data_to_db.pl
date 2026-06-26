#!/usr/bin/env perl

# load gbif data (see grab.sh) into psql tables 

use strict;
use warnings;
use DBI;
use JSON;
use Data::Dumper;

my $dsn = "dbi:Pg:dbname=gbif_embeddings;host=localhost;port=5433";
my $user = "postgres";
my $password = $ENV{POSTGRES_PASSWORD};

my $dbh = DBI->connect($dsn, $user, $password, {
    RaiseError => 1,
    AutoCommit => 1,
}) or die $DBI::errstr;

my $data = from_json(join('', <STDIN>));
foreach my $occ_data (@{$data->{results}}) {
    my $id = $occ_data->{gbifID};
    my $sql = 'INSERT INTO gbif_reference (id) VALUES (?) ON CONFLICT (id) DO NOTHING;';
    my $q = $dbh->prepare($sql);
    $q->execute($id);
    my $ct = 0;
    foreach my $media (@{$occ_data->{media}}) {
        $sql = 'INSERT INTO image (uri, gbif_id) VALUES (?, ?) ON CONFLICT DO NOTHING;';
        $q = $dbh->prepare($sql);
        $q->execute($media->{identifier}, $id);
        $ct++;
    }
    warn "$id: $ct images\n";
}
