package Slovo::Controller::Poruchki;
use Mojo::Base 'Slovo::Controller', -signatures;
use Mojo::Util qw(dumper decode );

use Mojo::JSON qw(true false decode_json encode_json);
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
            # TODO: implement product types as started in table products column type.
            shipmentDescription => (
                'книги ISBN: ' . join ';',
                map {"$_->{sku}: $_->{quantity}бр."} @{$o->{items}}
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
                        SKU         => $_->{sku},
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
        $o->{deliverer_id} = $eco_res->json->{id}+0;

        # Store in our database
        # TODO: Implement control panel for orders, invoices, products
        my $id = $orders->add(
            {   poruchka => encode_json($o),
                map { $_ => $o->{$_} } qw(deliverer_id deliverer name email phone city_name)
            }
        );
        $o = $orders->find($id);
        return $c->render(data => $o->{poruchka}, status => 201);
    }

    $app->log->error('Error from Econt: Status:'
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

# GET /poruchka/:deliverer/:id
# show an order by given :deliverer and :id with that deliverer.
# Invoked via OpenAPI by cart.js
sub show ($c) {
    $c->openapi->valid_input or return;
    my $deliverer = $c->param('deliverer');
    my $id = $c->param('id');
$c->debug("$deliverer|$id");
    my $order = $c->poruchki->find_where({deliverer => $deliverer, deliverer_id => $c->param('id')});

    return $c->render(
        openapi => {errors => [{path => $c->url_for.'', message => 'Not Found'}]},
        status  => 404
    ) unless $order;

    return $c->render(openapi => decode_json($order->{poruchka}));

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

