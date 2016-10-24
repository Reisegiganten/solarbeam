package SolarBeam::Response;
use Mojo::Base -base;

use Data::Page;
use Mojo::JSON 'decode_json';
use Mojo::JSON::MaybeXS;
use Mojo::Util 'decamelize';

use constant DEBUG => $ENV{SOLARBEAM_DEBUG} || 0;

has docs => sub { +[] };
has error         => undef;
has facet_dates   => sub { +{} };
has facet_fields  => sub { +{} };
has facet_queries => sub { +{} };
has facet_ranges  => sub { +{} };
has num_found     => 0;
has pager         => sub { Data::Page->new };
has params        => sub { +{} };
has query_time    => 0;
has start         => 0;
has terms         => sub { +{} };

sub parse {
  my ($self, $tx) = @_;
  my $res = $tx->res;

  if ($tx->error) {
    $self->error($res->error);
    return $self;
  }

  my $data = decode_json($res->body);

  my $header   = $data->{responseHeader};
  my $response = $data->{response};
  my $facets   = $data->{facet_counts};
  my $terms    = $data->{terms};
  my $field;

  if (!$header) {
    my $dom = $res->dom;
    my $title = $dom->at('title') if $dom;

    if ($title) {
      $self->error({message => $title->text});
    }
    else {
      $self->error({code => $res->code, message => $res->body});
    }
    return $self;
  }

  for $field (keys %$header) {
    my $method = decamelize ucfirst $field;
    $self->$method($header->{$field}) if $self->can($method);
  }

  for $field (keys %$response) {
    my $method = decamelize ucfirst $field;
    $self->$method($response->{$field}) if $self->can($method);
  }

  for $field (keys %$facets) {
    $self->$field($facets->{$field}) if $self->can($field);
  }

  my $ff = $self->facet_fields;
  if ($ff) {
    for $field (keys %$ff) {
      $ff->{$field} = $self->build_count_list($ff->{$field});
    }
  }

  if ($self->facet_ranges) {
    for $field (keys %{$self->facet_ranges}) {
      my $range = $self->facet_ranges->{$field};
      $range->{counts} = $self->build_count_list($range->{counts});
    }
  }

  if ($terms) {
    my $sane_terms = {};
    for $field (keys %$terms) {
      $sane_terms->{$field} = $self->build_count_list($terms->{$field});
    }
    $self->terms($sane_terms);
  }

  if (!$self->error && $response) {
    $self->pager->total_entries($self->num_found);
  }

  $self;
}

sub build_count_list {
  my ($self, $list) = @_;
  my @result = ();
  for (my $i = 1; $i < @$list; $i += 2) {
    push @result, {value => $list->[$i - 1], count => $list->[$i]};
  }
  return \@result;
}

1;

=encoding utf8

=head1 NAME

SolarBeam::Response - TODO

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 ATTRIBUTES

=head1 METHODS

=head2 build_count_list

=head2 ok

=head2 parse

=head1 AUTHOR

Jan Henning Thorsen

=head1 COPYRIGHT AND LICENSE

TODO

=head1 SEE ALSO

TODO

=cut
