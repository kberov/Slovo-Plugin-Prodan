package Slovo::Command::prodan::products;

BEGIN {
  binmode STDOUT => ':utf8';
  binmode STDERR => ':utf8';
}
use Mojo::Base 'Slovo::Command', -signatures;
use Mojo::File qw(path);
use Mojo::Loader qw(data_section file_is_binary);
use Mojo::Util qw(encode decode getopt dumper);
use YAML::XS qw(Dump Load DumpFile LoadFile);
has description => 'Manage products on the command line';

has usage   => sub { shift->extract_usage };
has actions => sub { [qw(create update dump delete list)] };

sub run ($self, @args) {
  my $action    = shift @args || 'list';
  my $a_pattern = '^(?:' . join('|', @{$self->actions}) . ')$';
  $action =~ $a_pattern
    || STDERR->say('Only '
      . join(',', @{$self->actions})
      . ' actions are supported.'
      . $/
      . $/
      . $self->usage)
    && return;
  getopt \@args,
    'f|file=s'  => \(my $file  = ''),
    'w|where=s' => \(my $where = ''),
    'l|limit=i' => \(my $limit = 100),
    'o|ofset=s' => \(my $ofset = 0);
  my $file_actions  = join('|', @{$self->actions}[0 .. 2]);
  my $where_actions = join('|', @{$self->actions}[3 .. 4]);
  if ($action =~ /$file_actions/) {
    $file
      || STDERR->say(
      'Please profide a YAML file to read data from' . $/ . $/ . $self->usage)
      && return;
    $file =~ /\.(ya?ml|json)$/
      || STDERR->say(
      'Only YAML and json files are supported right now.' . $/ . $/ . $self->usage)
      && return;
    $action = "_$action";
    $self->$action($file);
  }
  elsif ($action =~ /$where_actions/) {
    $action eq 'delete'
      && STDERR->say('Please provide a WHERE clause for DELETE!')
      && return;
  }
}

sub _create ($self, $file) {
  my $products = LoadFile $file;
  my $db       = $self->app->dbx->db;

  # INSERT
  for (@$products) {
    do {
      say "Inserting $_->{alias}, $_->{sku}";
      $db->insert(
        'products' => {
          alias      => $_->{alias},
          sku        => $_->{sku},
          title      => $_->{title},
          p_type     => $_->{p_type},
          properties => Dump($_->{properties})});
    } unless $db->select('products', ['id'], {alias => $_->{alias}, sku => $_->{sku},})
      ->hash;
  }
  return;
}

sub _update ($self, $file) {
  my $products = LoadFile $file;
  my $db       = $self->app->dbx->db;

  # UPDATE all the products found in the file
  for (@$products) {
    say "Updating $_->{alias}, $_->{sku}";
    $_->{properties} = Dump($_->{properties});
    $db->update('products', $_, {alias => $_->{alias}, sku => $_->{sku}});
  }
  return;
}

sub _delete ($self, $where, $limit, $offset) {
  die "Not implemented";
}

sub _list ($self, $where, $limit, $offset) {
  die "Not implemented";
}
1;

=encoding utf8

=head1 NAME

Slovo::Command::prodan::products - manage products on the command line

=head1 SYNOPSIS

    slovo prodan products create --from ./products.yaml
    slovo prodan products update --from ./products.yaml
    slovo prodan products list   --where "alias like'%лечителката%'"
    slovo prodan products delete --where "alias like'%лечителката%'"

=head1 DESCRIPTION

Slovo::Command::prodan::products is a command to easily create, list, update or
delete a bunch of products on the command line. For now only adding products
from (and dumping to) YAML files is supported. In the future CSV and XLS files
may be supported too.


=cut

