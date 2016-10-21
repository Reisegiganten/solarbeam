use strict;
use warnings;

use Mojo::UserAgent;
use Test::More 'no_plan';
use_ok 'SolarBeam';

my $sb = SolarBeam->new(url => 'http://localhost/');
my $mock = UserAgentMock->new;
$sb->ua($mock);

$mock->expect("/select", wt => 'json', q => 'hello');
$sb->search("hello", sub { });


$mock->expect(
  "/terms",
  wt                 => 'json',
  terms              => 'true',
  'terms.fl'         => 'artifact.name',
  'terms.regex'      => 'ost\w+',
  'terms.regex.flag' => 'case_insensitive'
);

$sb->autocomplete('ost', fl => 'artifact.name', sub { });

$mock->expect(
  "/terms",
  wt                 => 'json',
  terms              => 'true',
  'terms.fl'         => 'artifact.name',
  'terms.regex'      => 'ost.*',
  'terms.regex.flag' => 'case_insensitive'
);

$sb->autocomplete('ost', -postfix => '.*', fl => 'artifact.name', sub { });

ok(!$sb->ua->{expect});

package UserAgentMock;
use Test::More;

sub new {
  bless {}, 'UserAgentMock';
}

sub expect {
  my $self = shift;
  $self->{expect} = \@_;
}

sub get {
  my ($self, $url) = @_;
  my $expect = delete $self->{expect};
  ok($expect);
  my ($path, %query) = @{$expect};
  is($url->path, $path);
  is_deeply($url->query->to_hash, \%query);
}

sub post {
  my $self = shift;

  # Re-implement post from Mojo::UserAgent without callback support though
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $tx = Mojo::UserAgent->new->build_tx('POST', @_);
  my $expect = delete $self->{expect};

  ok($expect);
  my ($path, %query) = @{$expect};

  is($tx->req->url->path, $path);
  is_deeply($tx->req->params->to_hash, \%query);
}
