package Slovo::Controller::Poruchki;
use Mojo::Base 'Slovo::Controller', -signatures;

# POST /poruchki
# Create and store a new order.
# Invoked via OpenAPI by cart.js
sub store ($c) {

    state $shop = $c->config->{shop};
    my $orders = $c->poruchki;

    # $c->debug('Request body' =>Mojo::Util::decode('utf8'=>$c->req->body));
    $c->openapi->valid_input or return;

    # Why ->{Poruchka}{Poruchka} ????
    my $o = $c->validation->output->{Poruchka}{Poruchka};

    #$c->debug('Poruchka:' => $o);

    # POST to Econt
    my $econt_res = $c->app->ua->request_timeout(5)->post(
        $shop->{update_order_endpoint} =>
          {'Content-Type' => 'application/json', Authorization => $shop->{private_key}},
        json => {
            #id                  => $o->{id},
            #orderNumber         => $o->{id},
            cod                 => 1,
            declaredValue       => $o->{sum},
            currency            => $o->{shipping_price_currency},
            shipmentDescription => (
                'книги: ' . join ';', map {"$_->{id}: $_->{quantity}"} @{$o->{items}}
            ),
            receiverShareAmount=>$o->{shipping_price_cod},
            customerInfo => {
                name        => $o->{name},
                face        => $o->{face},
                phone       => $o->{phone},
                email       => $o->{email},
                countryCode => $o->{id_country},
                cityName    => $o->{city_name},
                postCode    => $o->{post_code},
                officeCode  => $o->{office_code},
                address     => ($o->{office_code} && $o->{address}),
                quarter     => $o->{quarter},
                street      => $o->{street},
                num         => $o->{num},
                other       => $o->{other},
            }
        }
    );
    $c->debug('econt response:' => $econt_res->res->json, 'status' => $econt_res->res->code);

    # Store in our daatabase
    my $id = $orders->add(
        {   poruchka => Mojo::JSON::encode_json($o),
            map { $_ => $o->{$_} } qw(name email phone deliverer city_name)
        }
    );
    $o = $orders->find($id);
    return $c->render(data => $o->{poruchka}, status => 201);
}

# GET /poruchki_by_last/:id
# lists orders of a customer by last order id
sub list_by_last_order ($c) {


}

# GET /api/shop
# provides shipment data to the page on which the form for shipping the
# collected goods in the cart is called.
sub shop ($c) {

    # TODO: some logic to use the right shop. We may have multiple
    # shops(physical stores) from which we send the orders.  For example we may
    # choose the shop depending on the IP-location of the user. We want to use
    # the closest store to the user to minimise delivery expenses.

    # Copy data without private_key.
    state $shop = {
        map { $_ eq 'private_key' ? () : ($_ => $c->config->{shop}{$_}) }
          keys %{$c->config->{shop}}
    };
    return $c->render(openapi => $shop, status => 200);
}

1;

