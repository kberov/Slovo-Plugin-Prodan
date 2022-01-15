package Slovo::Controller::Poruchki;
use Mojo::Base 'Slovo::Controller', -signatures;

# POST /poruchki
# Create and store a new order.
# Invoked via OpenAPI by cart.js
sub store ($c) {

    my $orders = $c->poruchki;

    $c->openapi->valid_input or return;
    my $row = $c->validation->output->{Poruchka};
    $c->debug('Poruchka:' => $row);
    $row->{items} = Mojo::JSON::encode_json($row->{items});
    my $id = $orders->add($row);
    my $order = $orders->find($id);
    $order->{items} = Mojo::JSON::decode_json($order->{items});
    return $c->render(openapi => $order, status => 201);
}

# GET /poruchki_by_last/:id
# lists orders of a customer by last order id
sub list_by_last_order ($c) {


}
1;

