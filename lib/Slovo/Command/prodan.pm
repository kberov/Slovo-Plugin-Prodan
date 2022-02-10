package Slovo::Command::prodan;

use Mojo::Base 'Mojolicious::Commands';

has hint => <<"EOF";

See '$0 prodan help ACTION' for more information on a specific command.
EOF
has message     => sub { shift->extract_usage . "\nActions:\n" };
has namespaces  => sub { [__PACKAGE__] };
has description => 'Sales related commands for a Slovo-based site.';

1;

=encoding utf8

=head1 NAME

Slovo::Command::prodan - A sales command

=head1 SYNOPSIS

    slovo prodan products create --from ./products.yaml
    slovo prodan products update --from ./products.yaml
    # same as above
    slovo prodan products replace --from ./products.yaml

=head1 DESCRIPTION

Slovo::Command::prodan is just a namespace for sales related commands.


=cut

