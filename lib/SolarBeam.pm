package SolarBeam;
use Mojo::Base -base;

use Mojo::UserAgent;
use Mojo::Parameters;
use Mojo::URL;
use SolarBeam::Response;
use SolarBeam::Query;

has url           => sub { Carp::Confess('url is required') };
has mojo_url      => sub { Mojo::URL->new(shift->url) };
has user_agent    => sub { Mojo::UserAgent->new };
has default_query => sub { {} };

my $escape_all   = quotemeta('+-&|!(){}[]^~:\\"*?');
my $escape_wilds = quotemeta('+-&|!(){}[]^~:\\');

sub search {
  my $callback = pop;
  my ($self, $query, %options) = @_;
  my $options = \%options;
  my $page    = $options->{page};
  $options->{-query} = $query;

  my $url = $self->build_url($options);

  my $q = $url->query;
  $url->query(Mojo::Parameters->new);

  $self->user_agent->post(
    $url,
    {'Content-Type' => 'application/x-www-form-urlencoded'} => $q,
    sub {
      my $res = SolarBeam::Response->new->parse(pop->res);

      if ($page && $res->ok) {
        $res->pager->current_page($page);
        $res->pager->entries_per_page($options->{rows});
      }

      if (!$res->ok) {
        warn "Solr failed: $url\n" . $res->error;
      }

      $callback->(shift, $res);
    }
  );
}

sub autocomplete {
  my $callback = pop;
  my ($self, $prefix, %options) = @_;
  my $postfix = delete $options{'-postfix'} || '\w+';

  $options{'regex.flag'} = 'case_insensitive';
  $options{'regex'}      = quotemeta($prefix) . $postfix;
  my $options = {terms => \%options, -endpoint => 'terms'};

  my $url = $self->build_url($options);

  $self->user_agent->get(
    $url,
    sub {
      my $res = SolarBeam::Response->new->parse(pop->res);
      $callback->(shift, $res);
    }
  );
}

sub build_url {
  my ($self, $options) = @_;

  my $endpoint = delete $options->{-endpoint};
  my $query    = delete $options->{-query};
  my $url      = $self->mojo_url->clone;

  $url->path($endpoint || 'select');
  $url->query(q => $self->build_query($query)) if $query;
  $url->query($self->default_query);
  $url->query({wt => 'json'});

  if ($options->{page}) {
    $self->handle_page($options->{page}, $options);
  }

  if ($options->{fq}) {
    $self->handle_fq($options->{fq}, $options);
  }

  if ($options->{facet}) {
    $self->handle_facet($options->{facet}, $options);
  }

  if ($options->{terms}) {
    $self->handle_nested_hash('terms', $options->{terms}, $options);
  }

  $url->query($options);

  return $url;
}

sub handle_page {
  my ($self, $page, $options) = @_;
  die "You must provide both page and rows" unless $options->{rows};
  $options->{start} = ($page - 1) * $options->{rows};
  return delete $options->{page};
}

sub handle_fq {
  my ($self, $fq, $options) = @_;

  if (ref($fq) eq 'ARRAY') {
    my @queries = map { $self->build_query($_) } @{$fq};
    $options->{fq} = \@queries;
  }
  else {
    $options->{fq} = $self->build_query($fq);
  }
  return;
}


sub handle_facet {
  my ($self, $facet, $options) = @_;
  $self->handle_nested_hash('facet', $facet, $options);
}


sub handle_nested_hash {
  my ($self, $prefix, $content, $options) = @_;
  my $type = ref $content;

  if ($type eq 'HASH') {
    $content->{-value} or $content->{-value} = 'true';

    for my $key (keys %{$content}) {
      my $name = $prefix;
      $name .= '.' . $key if $key ne '-value';
      $self->handle_nested_hash($name, $content->{$key}, $options);
    }
  }
  else {
    $options->{$prefix} = $content;
  }
}


sub build_query {
  my ($self, $query) = @_;

  my $type = ref($query);
  if ($type eq 'HASH') {
    $self->build_hash(%{$query});
  }
  elsif ($type eq 'ARRAY') {
    my ($raw, @params) = @$query;
    $raw =~ s|%@|$self->escape(shift @params)|ge;
    my %params = @params;
    $raw =~ s|%([a-z]+)|$self->escape($params{$1})|ge;
    $raw;
  }
  else {
    $query;
  }
}


sub build_hash {
  my ($self, %fields) = @_;
  my @query;

  for my $field (keys %fields) {
    my $val = $fields{$field};
    my @vals = ref($val) eq 'ARRAY' ? @{$val} : $val;
    push @query, join(' OR ', map { $field . ':(' . $self->escape($_) . ')' } @vals);
  }

  '(' . join(' AND ', @query) . ')';
}

sub escape {
  my $text = pop;
  my $chars;

  if (ref($text)) {
    $text  = ${$text};
    $chars = $escape_all;
  }
  else {
    $chars = $escape_wilds;
  }

  $text =~ s{([$chars])}{\\$1}g;
  return $text;
}

"It's super effective!";

1;

=encoding utf8

=head1 NAME

RG::Engine::Solr

=head1 DESCRIPTION

Interface to acquire Solr index engine connections.

=head1 EXAMPLE

use RG::Engine::Solr;

my $solr = RG::Engine::Solr->new( 'charter' );

=head1 ATTRIBUTES

L<SolarBeam> implements the the following attributes.

=head2 url

Solr endpoint as a string.

=head2 mojo_url

Solr endpoint as a Mojo::URL object. Defaults to inflating from the 'url' attribute.

=head2 user_agent

A Mojo::UserAgent compatible object.

=head2 default_query

A hashref with default parameters used for every query.

=head1 METHODS

=head2 search($query, [%options], $cb)

options:

    page
    rows

=head2 autocomplete($prefix, [%options], $cb)

options:

   -postfix   - defaults to \w+
   regex.flag -
   regex      -

=head2 build_url($options)

options:

    -endpoint - default 'select'
    -query    -
    fq        -
    facet     -
    terms     -

=head2 handle_page($page, $options)

=head2 handle_fq($fq, $options)

=head2 handle_facet($fact, $options)

=head2 handle_nested_hash($prefix, $content, $options)

=head2 build_query($query)

=head2 build_hash(%fields)

=head1 CLASS METHODS

=head2 escape($text);

=cut
