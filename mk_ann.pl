#!/usr/bin/env perl

# iterates over (unprocessed) images and uses ml-service api to extract annotations + embeddings
# to populate annotation table 

use strict;
use warnings;
use DBI;
use JSON;
use Data::Dumper;

my $size = $ARGV[0] || 10;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

my $dsn = "dbi:Pg:dbname=gbif_embeddings;host=localhost;port=5433";
my $user = "postgres";
my $password = $ENV{POSTGRES_PASSWORD};

my $dbh = DBI->connect($dsn, $user, $password, {
    RaiseError => 1,
    AutoCommit => 1,
}) or die $DBI::errstr;

warn "size=$size\n";

my $total_ct = 0;
my $q = $dbh->prepare("SELECT id, uri FROM image WHERE id NOT IN (SELECT image_id FROM annotation) ORDER BY id LIMIT $size;");
$q->execute;
while (my ($id, $uri) = $q->fetchrow_array) {
    $total_ct++;
    &mk_annot($id, $uri);
}


sub mk_annot {
    my ($id, $uri) = @_;
    return unless $uri;
    warn sprintf(" %4d/%d: pipelining annot(s) on %s...\n", $total_ct, $size, $uri);

    my $anns_data = &pipeline_annot($uri);

    # if we have no bbox, still make a kinda null-annot, so we dont try again
    if (!scalar(@{$anns_data->{pipeline_results}})) {
        warn "      - no bbox found\n";
        my $q = $dbh->prepare('INSERT INTO annotation (image_id, bbox) VALUES (?, ?);');
        $q->execute($id, '{}');
        return;
    }

    for (my $i = 0 ; $i < scalar(@{$anns_data->{pipeline_results}}) ; $i++) {
        my $bbox_data = {
            bbox => &int_bbox($anns_data->{pipeline_results}->[$i]->{bbox}),
            theta => $anns_data->{pipeline_results}->[$i]->{theta},
        };
        my $q = $dbh->prepare('INSERT INTO annotation (image_id, bbox, embedding) VALUES (?, ?, ?);');
        $q->execute($id, to_json($bbox_data), to_json($anns_data->{pipeline_results}->[$i]->{embedding}));
        warn "      - $i " . to_json($bbox_data->{bbox}) . "\n";
    }
}


sub int_bbox {
    my $bbox = shift;
    my $ints = [];
    foreach my $v (@$bbox) {
        push(@$ints, int($v + 0.5));
    }
    return $ints;
}

sub pipeline_annot {
    my $uri = shift;
    my $payload = {
        image_uri => $uri,
        predict_model_id => 'msv3',
        classify_model_id => 'zebra_v1',
        extract_model_id => 'miewid-msv4.1',
        bbox_score_threshold => 0.5,
        predict_model_params => { conf => 0.6 },
    };
    return &post('http://localhost:6050/pipeline/', $payload);
}


sub post {
    my ($uri, $data) = @_;
    my $req = HTTP::Request->new(POST => $uri);
    $req->content_type('application/json');
    $req->content(to_json($data));
    my $res = $ua->request($req);
    if ($res->is_success) {
        my $cont = $res->content;
        #warn $cont;
        return from_json($cont);
    } else {
        die $res->status_line;
    }
}

