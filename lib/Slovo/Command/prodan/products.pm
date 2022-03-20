package Slovo::Command::prodan::products;
use Mojo::Base 'Slovo::Command', -signatures;
use Mojo::Util qw(encode decode getopt dumper);
use YAML::XS qw(Dump DumpFile LoadFile Load);
use Mojo::JSON qw(to_json);
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
    'o|ofset=i' => \(my $ofset = 0);
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
    $action = "_$action";
    $self->$action($where, $limit, $ofset);
  }
  return;
}

sub _create ($self, $file) {
  my $products = LoadFile $file;
  my $db       = $self->app->dbx->db;

  # INSERT
  for (@$products) {
    do {
      say encode utf8 => "Inserting $_->{alias}, $_->{sku}";
      $db->insert(
        'products' => {
          alias  => $_->{alias},
          sku    => $_->{sku},
          title  => $_->{title},
          p_type => $_->{p_type},

          # The data is NOT encoded to UTF8 by to_json
          properties => to_json($_->{properties})});
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
    say encode utf8 => "Updating $_->{alias}, $_->{sku}";
    $_->{properties} = to_json($_->{properties});
    $db->update('products', $_, {sku => $_->{sku}});
  }
  return;
}

sub _delete ($self, $where, $limit, $offset) {
  Carp::croak "Action delete - Not implemented";
}

sub _list ($self, $where, $limit, $offset) {
  $where = $where ? decode(UTF8 => "WHERE $where") : '';
  my $sql      = "SELECT * FROM products $where LIMIT $limit OFFSET $offset";
  my $products = eval { $self->app->dbx->db->query($sql)->hashes }
    || Carp::croak("Wrong SQL:\n$sql\n\n$@");

  printf("sku\t\ttitle\n---\nproperties\n\n");
  for my $p (@$products) {
    my $sku_title = encode UTF8 => sprintf("%s\t%s\n", $p->{sku}, $p->{title});
    STDOUT->say($sku_title, Dump Load encode UTF8 => $p->{properties});
  }
  return;
}

1;

=encoding utf8

=head1 NAME

Slovo::Command::prodan::products - manage products on the command line

=head1 SYNOPSIS

  Usage:
    slovo prodan products create --from ./products.yaml
    slovo prodan products update --from ./products.yaml
    slovo prodan products list   --where "alias like'%лечителката%'"
    slovo prodan products delete --where "alias like'%лечителката%'"

  Actions: create, update, list, delete

  Options:
    -h, --help  Show this summary of available options.
    -f, --from  File from which to get the properties of the products.
    -w, --where SQL clause for filtering products for deleting or listing.

=head1 DESCRIPTION

Slovo::Command::prodan::products is a command to easily create, list, update or
delete a bunch of products on the command line. For now only adding products
from (and dumping to) YAML files is supported. In the future CSV and XLS files
may be supported too.

The idea is that YAML is very human friendly and a user can edit such a file
and then feed it to this command to create or update the items in this file.
Example files with product items can be found in the test folder of this
distribution.

This command is still alfa quality and its functionality may change often.

=head1 SEE ALSO

L<Slovo::Command::prodan>,
L<Slovo::Plugin::Prodan>,
L<Slovo>


=cut

