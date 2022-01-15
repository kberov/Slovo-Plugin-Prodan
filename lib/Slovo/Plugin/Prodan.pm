package Slovo::Plugin::Prodan;
use feature ':5.26';
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::JSON qw(true false);

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '0.01';

sub register ($self, $app, $conf) {

    # Prepend class
    unshift @{$app->renderer->classes}, __PACKAGE__;

    unshift @{$app->static->classes}, __PACKAGE__;
    $app->stylesheets('/css/cart.css');
    $app->javascripts('/js/cart.js');
    local $Data::Dumper::Maxdepth = 5;

    # $app->log->debug(join $/, sort keys %INC);
    # $app->debug('Prodan $config', $conf);
    # Set this flag, when we have changes to the tables to be applied.
    $self->_migrate($app, $conf) if ($conf->{migrate});
    require Storable;
    my $spec = $app->openapi_spec;
    %{$spec->{definitions}} = (%{$spec->{definitions}}, $self->_definitions);
    %{$spec->{paths}}       = (%{$spec->{paths}},       $self->_paths);
    $app->plugin(OpenAPI => {spec => $spec});

    # $app->debug($spec);
    # Generate helpers for instantiating Slovo::Model classes just like
    # Slovo::PLugin::MojoDBx
    for my $t ('poruchki',) {
        my $T     = Mojo::Util::camelize($t);
        my $class = "Slovo::Model::$T";
        $app->load_class($class);
        $app->helper(
            $t => sub ($c) {
                my $m = $class->new(dbx => $c->dbx, c => $c);
                Scalar::Util::weaken $m->{c};
                return $m;
            }
        );
    }
    return $self;
}

sub _paths {
    return (
        '/poruchki' => {
            post => {
                description => 'Create a new order',
                'x-mojo-to' => 'poruchki#store',
                parameters  => [
                    { 
                        required => true,
                        in       => 'body',
                        name     => 'Poruchka',
                        schema   => {'$ref' => '#/definitions/Poruchka'}
                    },
                ],
                responses => {
                    201 => {
                        description => 'Order created successfully!',
                        schema      => {'$ref' => '#/definitions/Poruchka'}

                    },
                    default => {'$ref' => '#/definitions/ErrorResponse'}
                }
            }
        },

        '/poruchki_by_last_order/:id' => {
            get => {
                description => 'List orders for a customer starting with the given last :id. '
                . 'Gets the email from the order and lists all orders for the same email.',
                'x-mojo-to' => 'poruchki#list_by_last_order',
                parameters  => [
                    {
                       '$ref' => '#/parameters/id'
                    },
                ],
                responses => {
                    200 => {
                        description => 'List all orders, made by the same email like this order id',
                        schema      => {'$ref' => '#/definitions/ListOfPoruchki'}

                    },
                    default => {'$ref' => '#/definitions/ErrorResponse'}
                }
            }
        }
    );
}

# Returns description as a perl structure of objects defined for the json API
# to be added to the /definitions of our OpenAPI
sub _definitions {
    return (
        ListOfPoruchki => {
            description => 'An array of Poruchka items.',
            items => {
                '$ref' => '#/definitions/Poruchka',
                type   => 'array',
            }
        },
        Poruchka => {
            properties => {
                id => {
                    description =>
                      ' Id of the new order, returend with the response to the user-agent(browser)',
                    type => 'integer',
                },
                recipient_names => {
                    maxLength => 100,
                    type      => 'string'
                },
                phone => {
                    maxLength => 20,
                    type      => 'string'
                },
                deliverer => {
                    maxLength => 100,
                    type      => 'string'
                },
                address => {
                    maxLength => 155,
                    type      => 'string'
                },
                notes => {
                    maxLength => 255,
                    type      => 'string'
                },
                items => {
                    '$ref'   => '#/definitions/OrderProducts',
                    type     => 'array'
                },
                way_bill_id => {
                    description =>
                      'Id at the deliverer site, returned by their system after we created the way-bill at their site.',
                    maxLength => 40,
                    type => 'string'
                }
            },
        },
        OrderProducts => {
            description => 'An array of OrderProduct items in an order.',
            items => {
                '$ref' => '#/definitions/OrderProduct',
                type   => 'array',

            }
        },
        OrderProduct => {
            description => 'An item in an order (cart): id, title, quantity, price',
            properties  => {
                id => {
                    maxLength => 40,
                    type      => 'string'
                },
                quantity => {
                    type     => 'integer'
                },
                price => {
                    type     => 'number'
                },
            }
        },
    );
}
# Create tables in the database on the very first run if they do not exist.
sub _migrate ($self, $app, $conf) {
      $app->dbx->migrations->name('prodan')
        ->from_data(__PACKAGE__, 'resources/data/prodan_migrations.sql')
            ->migrate();
  return $self;
}

1;

#POD

=encoding utf8

=head1 NAME

Slovo::Plugin::Prodan – Make and manage sales in your Mojo-based site

=head1 DESCRIPTION

The word про̀дан (прода̀жба) in Bulgarian means sale. Roots are found in Old
Common Slavic (Old Bulgarian) I<<проданьѥ>>. Here is an exerpt from Codex
Suprasliensis(331.27): I<<сꙑнъ божии. вол҄еѭ на сьпасьнѫѭ страсть съ вами
придетъ. и на B<<продании>> станетъ. искѹпѹѭштааго животворьноѭ кръвьѭ. своеѭ
миръ.>>

L<<Slovo::Plugin::Prodan>> is a L<<Mojolicious::Plugin>>. I just used the
namespace of the application in which I use it. It should not depend directly on
it. It may depend on features found in L<<Slovo>>. If so, I will mention it
explicitly and provide explanations and examples to implement the needed
feature.

=head1 FEATURES

In its first edition of L<<Slovo::Plugin::Prodan>> we implemented the following features:

=over 1

=item A jQuery and localStorage based shopping cart. Two static files contain
the implementation and they can be inflated as usual. The files are 
C</css/cart.css> and C</js/cart.js>. These files will be inflated into your
public forlder, for example C<lib/Slovo/resources/public>. Even not inflated
these can be referred from any page or set of pages where you need their
functionality. You need to have the following in your html (usually a
template)

  <head>
    <!-- your other stuff -->
    <script src="/mojo/jquery/jquery.js" ></script>
    <link rel="stylesheet" href="/css/cart.css" />
    <script src="/js/cart.js" ></script>
  </head>

To display the cart on the page, an C<aside> element C<aside#widgets> is required.
In future versions this can be made configurable.
To add a product to your cart, you need a button, containing the product
data. For example:

    <button class="add-to-cart"
        data-id="978-619-91690-0-2"
        data-title="Житие на света Петка Българска от свети патриарх Евтимий"
        data-isbn="978-619-91690-0-2"
        data-price="5.00">Add to cart</button>

The only required properties are C<id>, C<title> and C<price>.

=item A "Pay on delivery" integration with Bulgarian currier L<<Econt (in
Bulgarian)|https://www.econt.com/developers/43-kakvo-e-dostavi-s-ekont.html>>.

=back

=head2 TODO

=over 1

=item Products - a products SQL table with Open API to populate your pages

=item Invoices - generate an invoice in PDF via headless LibreOffice instance
on your server.

=item Merchants - a merchants SQL table with Open API to manage and
automatically populate invoices.

=item Other "Pay on Delivery" providers. Feel free to contibute yours. 
=item Other types of Payments and/or online Payment Providers like online POS Terminals etc.

=back

=head1 METHODS

The usual method is implemented.

=head2 register

Prepends the class to renderer and static classes.

=head1 EMBEDDED FILES

    @@ css/cart.css
    @@ js/cart.js

=head1 SEE ALSO

L<Mojolicious::Guides::Tutorial/Stash and templates>,
L<Mojolicious/renderer>,
L<Mojolicious::Renderer>,
L<Mojolicious::Guides::Rendering/Bundling assets with plugins>,
L<Slovo::Command::Author::inflate>

=head1 AUTHOR

    Красимир Беров
    CPAN ID: BEROV
    berov на cpan точка org
    http://i-can.eu

=head1 CONTRIBUTORS

Ordered by time of first commit.

=over

=item * Your Name

=item * Someone Else

=item * Another Contributor

=back

=head1 COPYRIGHT

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

The full text of the license can be found in the
LICENSE file included with this module.

This distribution contains icons from L<https://materialdesignicons.com/> and
may contain other free software which belongs to their respective authors.


=cut

__DATA__

@@ css/cart.css
@charset "utf-8";

#show_order {
    background-color: var(--bg-color);
}

#order_widget {
    padding: 0;
    z-index: 2;
    background-color: var(--bg-color);
    color: black;
    /* 'position' cannot be fixed, because it must be slidable in case there
     * are more * products and the bottom of the table is not visible on the
     * screen. */
    position: absolute;
    top: 8rem;
    left: 0;
}

#order_widget>h3 {
    margin: 0;
}

#order_widget>button:nth-child(1) {
    float: right;
}

#order_widget>table {
    position: relative;
}
#order_widget>table>tfoot th:nth-last-child(1),
#order_widget>table>tbody td:nth-last-child(1) {
    max-width: 13rem;
   /* white-space: nowrap; */
    text-align: center;
}

#order_widget>table>thead th:nth-last-child(2),
#order_widget>table>tfoot th:nth-last-child(3),
#order_widget>table>tbody td:nth-last-child(2) {
    max-width: 5rem;
    white-space: nowrap;
    text-align: right;
}

#order_widget>table>thead th:nth-last-child(3),
#order_widget>table>tfoot th:nth-last-child(3),
#order_widget>table>tbody td:nth-last-child(3) {
    max-width: 7rem;
    white-space: nowrap;
    text-align: right;
}

#order_widget>table>tfoot th:nth-last-child(4),
#order_widget>table>tbody td:nth-last-child(4) {
    max-width: 40rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

#order_widget>table>tfoot th:nth-last-child(4){
    text-align: right;
}

button.product,.button.product, .button.cart, button.cart {
	font-family: FreeSans, sans-serif;
	color: var(--color-success);
	font-weight: bolder;
	border-radius: 4px;
	font-size: small;
	padding: .2rem .2em;
}

#order_widget tr:nth-child(even) td {
    background-color: var(--color-lightGrey);
}

#order_widget tr:nth-child(odd) td {
    background-color: white;
}

img.outline {
    color:  var(--color-primary);
    border: 1px solid var(--color-primary);
    border-radius: 4px;
    cursor: pointer;
}

#email_order_layer, #last_order_layer {
    position: absolute;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0;
    z-index: 3;
    background-color: rgba(250, 250, 250, 0.80);
}

#last_order_items td, 
#last_order_table td {
    font-family: sans-serif;
}
/*
*/
#order_help h5, #order_help h6 {
    margin: 0.35rem 0 0 0;
}
#email_order_form input:invalid {
  border: red solid 2px;
}
#order_help p {
    font-family: Veleka, serif;
}
#order_help {
    z-index:4;
    position: absolute;
    top: 0;
    left: 30%;
    right: 30%;
}

@media (max-width: 700px) {
    /* .plus, .minus,.remove images as buttons */
    #order_widget img.outline {
        width: 32px;
    }
    #order_widget>table>tfoot th:nth-last-child(1),
    #order_widget>table>tbody td:nth-last-child(1) {
        max-width: 5rem;
    }
    #order_widget>table>tfoot th:nth-last-child(4),
    #order_widget>table>tbody td:nth-last-child(4) {
       max-width: 10rem; 
    }
    .remove {
        display: none;
    }
    #order_help {
        top: 0;
        left: 0;
        right: 0;
    }
} /* end @media (max-width: 700px) */

@@ js/cart.js
/* An unobtrusive shopping cart based on localStorage
 * Formatted with `js-beautify -j -r -f lib/Slovo/resources/public/js/cart.js`
 */
jQuery(function ($) {
    'use strict';
    // cart will go finally to order.items
    let cart = localStorage.cart ? JSON.parse(localStorage.cart) : {};
    let order = localStorage.order ? JSON.parse(localStorage.order) : {};
    let last_order = localStorage.last_order ? JSON.parse(localStorage.last_order) : {};
    const order_widget_template = `
<div id="order_widget" class="card text-center">
<button class="button primary outline icon cart" title="Показване/Скриване на поръчката"
    id="show_order"><span class="order_total"></span><img src="/img/cart.svg" width="32" height="32" /></button>
<h3 style="display:none">Поръчка</h3>
<table style="display:none">
<thead><tr><th>Изделие</th><th>Ед. цена</th><th>Бр.</th><th><!-- action --></th></tr></thead>
<tbody><!-- Here will be the order items --></tbody>
<tfoot>
<tr><th>
Общо (лв.)</th><th class="order_total"></th>
<th>
    <button class="button primary outline icon cart pull-left"
        title="Отказ от поръчката" id="cancel_order"><img 
            src="/img/cart-off.svg" width="32" /></button>
</th>
<th>
<button class="button primary icon cart"
title="Купувам" id="email_order"><img src="/img/cart-check.svg" width="32" /></button>
</th>
</tr>
</tfoot>
</table>
</div>
`;
    const email_order_template = `
<div id="email_order_layer" style="display:none">
<form id="email_order_form" method="POST" action="/api/poruchki" class="container">
<fieldset class="card">
<legend data-description="Повечето от полетата, които попълвате тук, съдържат лични данни. Нужно е да ги предоставите, за да поръчате."
    >Поръчка</legend>
<button class="button outline icon cart pull-right" title="Скриване на формуляра"
    id="hide_email_order"><span class="order_total"></span><img src="/img/arrow-collapse-all.svg" width="32" /></button>
<button class="button outline icon cart pull-right" title="Пояснения"
    id="help_email_order"><img src="/css/malka/help-circle-outline.svg" width="32" /></button>

<label for="recipient_names">Получател</label>
<input type="text" name="recipient_names" placeholder="Иванка Петканова" required="required" maxlength="100"
title="Собствено и родово име или име на фирма, получател."/>
<label for="email">E-поща</label>
<input type="email" name="email" placeholder="ivanka@primer.com" required="required" maxlength="100"
title="Адрес, на който ще получите уведомление, когато предадем пратката на доставчика. При закупуване на невеществени изделия (електронни книги, софтуер…) на този адрес ще получите връзка за изтегляне на файла."/>
<label for="phone">Телефон</label>
<input type="tel" name="phone" placeholder="0891234567" required="required" maxlength="20"
title="Телефонен номер, на който ще бъдете известени от доставчика, когато пратката ви пристигне."/>
<label for="deliverer">Предпочитан доставчик</label>
<select name="deliverer" title="Изберете кой от доставчиците, с които работим, предпочитате. При закупуване на невеществени изделия, ще изпратим връзка за изтегляне и банкова сметка, на която да преведете сумата по поръчката.">
    <option value="email">Е-поща (за електронни издания и софтуер)</option>
    <option value="econt">Еконт</option>
    <option value="speedy">Спиди</option>
</select>
<label for="address">Адрес за получаване</label>
<input type="text" name="address" placeholder="п.к. 3210 с. Горно Нанадолнище, ул. „Цветуша“ №123" maxlength="155"
title="Вашият точен адрес за получаване на пратката или адрес на офис на избрания доставчик. При закупуване на невеществени изделия и услуги това поле не е задължително." />
<label for="notes">Допълнителни бележки</label>
<textarea name="notes" rows="2" maxlength="255"
title="Ако желаете да добавите някакви подробности и уточнения, въведете ги в това поле."></textarea>
<input type="hidden" name="items" value="{}"/>
<footer class="is-right" style="margin-top:1rem">
    <button type="reset" class="secondary outline button icon-only"
        class="reset_order_form" title="изчистване"><img src="/css/malka/card-bulleted-off-outline.svg" width="32" /></button>
    &nbsp;&nbsp;<button class="primary button icon-only" type="submit"
        title="Поръчвам"><img src="/img/cart-check.svg" width="32" /></button>
</footer>
</fieldset>
</form>
</div>
`;
    const last_order_template = `
<div id="last_order_layer" style="display:none">
    <div class="container card">
        <button class="button outline icon cart pull-right hide_last_order"
        title="Скриване"><span class="order_total"></span><img src="/img/arrow-collapse-all.svg" width="32" /></button>
    <p>Вашата поръчка е приета. На електронната ви поща ще изпратим номера на
    товарителницата, с който можете да проследите пратката. Също така ще бъдете
    уведомени своевременно от превозвача, когато вашата пратка пристигне.</p>
        <table id="last_order_table">
            <tr><th>Поръчка:</th><td id="id"></td></tr>
            <tr><th>Товарителница:</th><td id="way_bill_id"></td></tr>
            <tr><th>Получател:</th><td id="recipient_names"></td></tr>
            <tr><th>E-поща:</th><td id="email"></td></tr>
            <tr><th>Телефон:</th><td id="phone"></td></tr>
            <tr><th>Предпочетен доставчик:</th><td id="deliverer"></td></tr>
            <tr><th>Адрес за получаване:</th><td id="address"></td></tr>
            <tr><th>Допълнителни бележки:</th><td id="notes"></td></tr>
        </table>
        <table id="last_order_items">
            <cation class="text-center">Изделия</caption>

        </table>
  <footer class="is-center">
    <button class="button primary hide_last_order">Добре</button>
  </footer>
    </div>
</div>
    `;
    show_order();
    /* In a regular page we present a product(book, software package,
     * whatever). On the page there is one or more buttons(one per product)
     * (.add-to-cart) in which data-attributes are stored all the properties
     * of the product. Clicking on the button adds the product to the card.
     * */
    $('.add-to-cart').click(add_to_cart);

    function add_to_cart() {
        let product = $(this).data();
        let product_id = '_' + product.id;
        if (product_id in cart) {
            ++cart[product_id].quantity;
        } else {
            cart[product_id] = {
                id: product.id,
                title: product.title,
                quantity: 1,
                price: product.price
            };
        }
        // display the cart in #order_widget
        show_order();
        //Scroll to the top to show the cart because it is positioned absolutely.
        $('html').animate({
            scrollTop: 0
        }, 300)
    }

    function cancel_order() {
        console.log('#cancel_order');
        localStorage.removeItem('cart');
        cart = {};
        $('#order_widget').remove();
    }

    function show_order() {
        // there is nothing to show? return.
        if (!Object.keys(cart).length) return;

        // Store the changed cart!!!
        localStorage.setItem('cart', JSON.stringify(cart));
        let order_widget = $('#order_widget');
        //if not yet in dom, create it
        if (!order_widget.length) {
            $('body').append(order_widget_template);
            //populate the table>tbody with the contents of the cart
            $(Object.keys(cart)).each(populate_order_table);
            // make the cart button to toggle the visibility of the products table
            $('#show_order').click(toggle_order_table_visibility);
            // append the email_order_form
            if (!$('#email_order_layer').length)
                $('body').append(email_order_template);

        }
        //else update it
        else {
            repopulate_order_table();
        }
        // calculate the sum of the items in the cart
        let sum = 0;
        Object.keys(cart).forEach((curr) => sum += cart[curr].price * cart[curr].quantity);
        // VAT is included in the price
        $('.order_total').html(sum.toFixed(2));
        $('#cancel_order').click(cancel_order);

        $('#email_order').click(show_email_order);
    } // end function show_order()

    function populate_order_table() {
        console.log(`this: `, this);
        let this_id = this;
        let ow_jq = '#order_widget>table>tbody';
        $(ow_jq).append(`
                  <tr id="${this_id}">
                    <td title="${cart[this_id].title}">${cart[this].title}</td>
                    <td>${cart[this_id].price}</td>
                    <td>${cart[this_id].quantity} бр.</td>
                    <td>
                      <img class="outline minus" title="Премахване на един брой" src="/img/cart-minus.svg" width="32" />
                      <img class="outline plus" title="Добавяне на един брой" src="/img/cart-plus.svg" width="32" />
                      <img class="outline remove" title="Без това изделие" src="/img/cart-remove.svg" width="32" />
                    </td>
                  </tr>`);
        //Add functionality to plus,minus and remove
        $(`${ow_jq} tr#${this_id} .minus`).click(function () {
            if (cart[this_id].quantity == 1) {
                remove_item();
                return;
            }
            --cart[this_id].quantity;
            localStorage.removeItem('cart');
            show_order();
        });
        $(`${ow_jq} tr#${this_id} .plus`).click(function () {
            ++cart[this_id].quantity;
            localStorage.removeItem('cart');
            show_order();
        });
        $(`${ow_jq} tr#${this_id} .remove`).click(remove_item);

        function remove_item() {
            if (Object.keys(cart).length == 1) {
                $('#cancel_order').trigger('click');
                return;
            }
            delete cart[this_id];
            localStorage.removeItem('cart');
            show_order();
        }

    } // end function populate_order_table() 

    function repopulate_order_table() {
        $('#order_widget>table>tbody').empty();
        $(Object.keys(cart)).each(populate_order_table);
    }

    function toggle_order_table_visibility() {
        let order_button_icon = $('#order_widget #show_order>img');
        if (order_button_icon.attr('src').match(/cart/))
            order_button_icon.attr('src', '/img/arrow-collapse-all.svg');
        else
            order_button_icon.attr('src', '/img/cart.svg');
        $('#order_widget>h3,#order_widget>table').toggle();
    }

    function show_email_order() {
        $('#email_order_layer').show();
        let hide = $('#hide_email_order');
        hide.off('click');
        hide.click(function (e) {
            $('#email_order_layer').hide();
            e.preventDefault();
        });

        let help = $('#help_email_order');
        help.off('click');
        //Display help text for each field in the form.
        let fo = '#email_order_form';
        help.click(function (e) {
            e.preventDefault();
            let legend = $(`${fo} legend`);
            let titles = `
<button class="button outline icon cart pull-right" title="Скриване на поясненията"
    id="hide_order_help"><img src="/img/arrow-collapse-all.svg" width="32" /></button>
                <h4>${legend.text()}</h4><p>${legend.data('description')}</p>`;
            // take the help from label titles
            $(`${fo} label`).each(function () {
                let self = $(this);
                let field_title = $(`${fo} [name=${self.prop('for')}]`).prop('title');
                titles += `<h5>${self.html()}</h5><p>${field_title}</p>`;
            });
            // display the help
            $('#email_order_layer').append(`<section id="order_help" class="card">${titles}</section>`);
            // remove the help from the DOM
            $('#hide_order_help').click(() => $('#order_help').remove());
        });
        let fields = $(`${fo} :input`);
        // Populate each field (excluding order items) with previous data if there is such.
        fields.each(function () {
            if (order[$(this).prop('name')])
                $(this).val(order[$(this).prop('name')]);
        });
        // Add events to each field to save the state (value) of the field so
        // the next time the user will have the info ready and prefilled. 
        fields.change(function () {
            order[$(this).prop('name')] = $(this).val();
            localStorage.setItem('order', JSON.stringify(order));
        });
        $(fo).off('submit');
        $(fo).submit(submit_order);
    } // end function show_email_order()

    /**
     * Delete the just made by the user order.
     */
    function delete_cart() {
        console.log('#delete_made_order');
        localStorage.removeItem('cart');
        cart = {};
        $('#order_widget').remove();
    }

    function submit_order(ev) {
        let fo = '#email_order_form';
        let fields = $(`${fo} :input`);
        // make sure all fields data goes to order
        fields.each(function () {
            if ($(this).prop('name') !== '')
                order[$(this).prop('name')] = $(this).val();
        });
        order.items = [];
        Object.keys(cart).forEach((curr) => order.items.push(cart[curr]));
        $.post($(fo).prop('action'), JSON.stringify(order), function (data, status) {
            if (status === 'success') {
                // store the order for showing later too
                localStorage.setItem('last_order', JSON.stringify(data));
                delete_cart();
                $('#email_order_layer').hide();
                display_last_order(data);
            } else {
                let response = JSON.stringify(data);
                alert(`
Нещо се обърка на сървъра.
Опитайте да изпратите поръчката си на poruchki@studio-berov.eu.
Следва отговорът от сървъра. Молим изпратете, снимка на екрана си, за да ни
улесните в отстраняването на грешката.
${response}
`);
            }
        }, 'json');
        ev.preventDefault();
    } // end function submit_order

    /**
     * Displays the just made or last order to the user 
     */
    function display_last_order(order_data) {
        //alert(order_data);
        // display last order
        $('body').append(last_order_template);
        for (const k in order_data) {
            if (k !== 'items')
                $(`#last_order_table #${k}`).html(order_data[k]);
        }
        let order_sum = 0;
        let items = order_data.items;
        for (const it of items) {
            let item_sum = it.price * it.quantity;
            order_sum += item_sum;
            $('#last_order_items').append(`
                  <tr>
                    <th title="${it.title}">${it.title}</th>
                    <td>${it.price}</td><td>${it.quantity} бр.</td><td>${item_sum}</td>
                  </tr>
            `);

        }
        $('#last_order_items').append(`<tr><th colspan="3">Общо</th><td>${order_sum}</td></tr>`);
        $('.hide_last_order').click(() => $('#last_order_layer').hide());
        $('#last_order_layer').show();
    } // end function display_last_order

});
@@ img/arrow-collapse-all.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M19.5,3.09L20.91,4.5L16.41,9H20V11H13V4H15V7.59L19.5,3.09M20.91,19.5L19.5,20.91L15,16.41V20H13V13H20V15H16.41L20.91,19.5M4.5,3.09L9,7.59V4H11V11H4V9H7.59L3.09,4.5L4.5,3.09M3.09,19.5L7.59,15H4V13H11V20H9V16.41L4.5,20.91L3.09,19.5Z" /></svg>
@@ img/cart.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M17,18C15.89,18 15,18.89 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20C19,18.89 18.1,18 17,18M1,2V4H3L6.6,11.59L5.24,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42A0.25,0.25 0 0,1 7.17,14.75C7.17,14.7 7.18,14.66 7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.58 17.3,11.97L20.88,5.5C20.95,5.34 21,5.17 21,5A1,1 0 0,0 20,4H5.21L4.27,2M7,18C5.89,18 5,18.89 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20C9,18.89 8.1,18 7,18Z" /></svg>
@@ img/cart-check.svg
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1"  width="24" height="24" viewBox="0 0 24 24"><path fill="#fff" d="M9 20C9 21.11 8.11 22 7 22S5 21.11 5 20 5.9 18 7 18 9 18.9 9 20M17 18C15.9 18 15 18.9 15 20S15.9 22 17 22 19 21.11 19 20 18.11 18 17 18M7.17 14.75L7.2 14.63L8.1 13H15.55C16.3 13 16.96 12.59 17.3 11.97L21.16 4.96L19.42 4H19.41L18.31 6L15.55 11H8.53L8.4 10.73L6.16 6L5.21 4L4.27 2H1V4H3L6.6 11.59L5.25 14.04C5.09 14.32 5 14.65 5 15C5 16.11 5.9 17 7 17H19V15H7.42C7.29 15 7.17 14.89 7.17 14.75M18 2.76L16.59 1.34L11.75 6.18L9.16 3.59L7.75 5L11.75 9L18 2.76Z" />
</svg>
@@ img/cart-off.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M22.73,22.73L1.27,1.27L0,2.54L4.39,6.93L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H14.46L15.84,18.38C15.34,18.74 15,19.33 15,20A2,2 0 0,0 17,22C17.67,22 18.26,21.67 18.62,21.16L21.46,24L22.73,22.73M7.42,15A0.25,0.25 0 0,1 7.17,14.75L7.2,14.63L8.1,13H10.46L12.46,15H7.42M15.55,13C16.3,13 16.96,12.59 17.3,11.97L20.88,5.5C20.96,5.34 21,5.17 21,5A1,1 0 0,0 20,4H6.54L15.55,13M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18Z" /></svg>
@@ img/cart-minus.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M16,6V4H8V6M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18M17,18A2,2 0 0,0 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20A2,2 0 0,0 17,18M7.17,14.75L7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.59 17.3,11.97L21.16,4.96L19.42,4H19.41L18.31,6L15.55,11H8.53L8.4,10.73L6.16,6L5.21,4L4.27,2H1V4H3L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42C7.29,15 7.17,14.89 7.17,14.75Z" /></svg>
@@ img/cart-plus-white.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path fill="white" d="M11,9H13V6H16V4H13V1H11V4H8V6H11M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18M17,18A2,2 0 0,0 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20A2,2 0 0,0 17,18M7.17,14.75L7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.59 17.3,11.97L21.16,4.96L19.42,4H19.41L18.31,6L15.55,11H8.53L8.4,10.73L6.16,6L5.21,4L4.27,2H1V4H3L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42C7.29,15 7.17,14.89 7.17,14.75Z" /></svg>
@@ img/cart-plus.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M11,9H13V6H16V4H13V1H11V4H8V6H11M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18M17,18A2,2 0 0,0 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20A2,2 0 0,0 17,18M7.17,14.75L7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.59 17.3,11.97L21.16,4.96L19.42,4H19.41L18.31,6L15.55,11H8.53L8.4,10.73L6.16,6L5.21,4L4.27,2H1V4H3L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42C7.29,15 7.17,14.89 7.17,14.75Z" /></svg>
@@ img/cart-remove.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M14.12,8.53L12,6.41L9.88,8.54L8.46,7.12L10.59,5L8.47,2.88L9.88,1.47L12,3.59L14.12,1.46L15.54,2.88L13.41,5L15.53,7.12L14.12,8.53M7,18A2,2 0 0,1 9,20A2,2 0 0,1 7,22A2,2 0 0,1 5,20A2,2 0 0,1 7,18M17,18A2,2 0 0,1 19,20A2,2 0 0,1 17,22A2,2 0 0,1 15,20A2,2 0 0,1 17,18M7.17,14.75A0.25,0.25 0 0,0 7.42,15H19V17H7A2,2 0 0,1 5,15C5,14.65 5.09,14.32 5.25,14.04L6.6,11.59L3,4H1V2H4.27L5.21,4L6.16,6L8.4,10.73L8.53,11H15.55L18.31,6L19.41,4H19.42L21.16,4.96L17.3,11.97C16.96,12.59 16.3,13 15.55,13H8.1L7.2,14.63L7.17,14.75Z" /></svg>
@@ img/econt.svg
<svg version="1.1" width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg"><path style="opacity:1;fill:#234182;fill-opacity:1;stroke-width:1.24709" d="M 6.1289062 -0.001953125 C 4.6048195 -0.017998455 3.2956311 1.2947208 3.125 3.0820312 L 1.5019531 20.080078 C 1.4422923 20.705007 1.5321941 21.30588 1.734375 21.841797 C 2.0990696 23.087443 3.2446653 23.992188 4.6113281 23.992188 L 17.267578 23.992188 C 18.929578 23.992188 20.267578 22.654187 20.267578 20.992188 C 20.267578 19.330188 18.929578 17.992188 17.267578 17.992188 L 7.7382812 17.992188 L 8.8828125 6 L 19.546875 6 C 21.208875 6 22.546875 4.662 22.546875 3 C 22.546875 1.338 21.208875 0 19.546875 0 L 6.484375 0 C 6.4201955 0 6.3580767 0.0058336146 6.2949219 0.009765625 C 6.2393916 0.0056858294 6.1839178 -0.001373973 6.1289062 -0.001953125 z M 15.328125 8.0390625 A 4 4 0 0 0 11.328125 12.039062 A 4 4 0 0 0 15.328125 16.039062 A 4 4 0 0 0 19.328125 12.039062 A 4 4 0 0 0 15.328125 8.0390625 z " /></svg>

@@ resources/data/prodan_migrations.sql

-- 202112310000 up

-- A list of products and services being sold
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- Lowercased and trimmed of \W characters unique identifier
  alias VARCHAR(100) UNIQUE NOT NULL,
  description VARCHAR(2000) NOT NULL DEFAULT '',
  -- the properties which are put in the data-* attributes
  -- of an "Add to cart" button such as data-isbn, data-price,
  -- data-vat, data-vat_included, data-title, data-description, etc.
  properties JSON NOT NULL DEFAULT '{}'

);

-- A list of orders for bying product by customers
CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- recipient names - own and family name
  recipient_names VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  deliverer VARCHAR(100) NOT NULL,
  address VARCHAR(155) NOT NULL,
  notes VARCHAR(255) NOT NULL,
  -- Product items. Each item has the properties of a product.
  items JSON NOT NULL,
  -- When this content was inserted
  created_at INTEGER NOT NULL DEFAULT 0,
  -- Last time the record was touched
  tstamp INTEGER DEFAULT 0,
  -- Id at the deliverer site, returned by their system after we created the
  -- way-bill at their site.
  way_bill_id VARCHAR(40) DEFAULT '',
  executed INT(1) DEFAULT 0

);

-- A list of invoices for services and products, produced by different users
-- of this system.
CREATE TABLE IF NOT EXISTS invoices (
  -- Internal ID for this invoice. For the visible id each user will have its
  -- own incrementing counter, implemented outside the database
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- The visible and printable invoice ID - unique per user
  user_invoice_id INTEGER NOT NULL,
  -- User who created the invoice (owner).
  user_id INTEGER NOT NULL,
  -- Which order is this invoice for? NOTE: Items for the invoice are taken from the order.
  order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id),
  -- Who modified this record the last time?
  changed_by INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS users_invoices_last_id (
  --  ID of the user which created this invoice
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  -- Internal invoice ID of the last invoice, generated by this user
  invoice_id INTEGER REFERENCES invoices(id) ON DELETE CASCADE,
  PRIMARY KEY(user_id, invoice_id)
);

-- 202112310000 down

DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users_invoices_last_id;

