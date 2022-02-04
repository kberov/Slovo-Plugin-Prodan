package Slovo::Controller::Poruchki;
use Mojo::Base 'Slovo::Controller', -signatures;
use Mojo::Util qw(dumper decode );

# POST /poruchki
# Create and store a new order.
# Invoked via OpenAPI by cart.js
sub store ($c) {

    state $shop = $c->config->{shop};
    state $app  = $c->app;
    my $orders = $c->poruchki;

    $c->debug('Request body' => Mojo::Util::decode('utf8' => $c->req->body));
    $c->openapi->valid_input or return;

    # Why ->{Poruchka}{Poruchka} ????
    my $o = $c->validation->output->{Poruchka}{Poruchka};

    # $c->debug('Poruchka:' => $o);

    # POST to Econt
    my $eco_res = $app->ua->request_timeout(5)->post(
        $shop->{update_order_endpoint} => {
            'Content-Type' => 'application/json',
            Authorization  => $shop->{private_key}
        },
        json => {

            #id => $o->{id},
            #orderNumber         => $o->{id},
            cod                 => 1,
            declaredValue       => $o->{sum},
            currency            => $o->{shipping_price_currency},
            shipmentDescription => (
                'книги: ' . join ';',
                map {"$_->{id}: $_->{quantity}бр."} @{$o->{items}}
            ),
            receiverShareAmount => $o->{shipping_price_cod},
            customerInfo        => {
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
            },
            items => [
                map {
                    {   name        => $_->{title},
                        SKU         => $_->{id},
                        count       => $_->{quantity},
                        hideCount   => 0,
                        totalPrice  => ($_->{quantity} * $_->{price}),
                        totalWeight => ($_->{quantity} * $_->{weight}),
                    }
                } @{$o->{items}}
            ]
        }
    )->res;

    if ($eco_res->is_success) {
        $o->{id} = $eco_res->json->{id};

        # Store in our database
        # TODO: Implement control panel for orders, invoices, products
        my $id = $orders->add(
            {   poruchka => Mojo::JSON::encode_json($o),
                map { $_ => $o->{$_} } qw(name email phone deliverer city_name)
            }
        );
        $o = $orders->find($id);
        return $c->render(data => $o->{poruchka}, status => 201);
    }

    $app->log->error('Error from Ekont: Status:'
          . $eco_res->code
          . $/
          . 'Response:'
          . decode(utf8 => $eco_res->body));

    return $c->render(
        openapi => {
            errors => [
                {   path    => $c->url_for,
                    message => 'Нещо не се разбрахме с доставчика.'
                      . $/
                      . 'Състояние: '
                      . $eco_res->code
                      . $/
                      . 'Опитваме се да се поправим. Извинете за неудобството.'
                }
            ]
        },
        status => 418
    );
}

# GET /poruchka/:id
# lists orders of a customer by last order id
sub show ($c) {


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

