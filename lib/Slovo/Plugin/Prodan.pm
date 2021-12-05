package Slovo::Plugin::Prodan;
use feature ':5.26';
use Mojo::Base 'Mojolicious::Plugin', -signatures;

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '0.01';

sub register ($self, $app, $conf) {

  # Prepend class
  unshift @{$app->renderer->classes}, __PACKAGE__;

  unshift @{$app->static->classes}, __PACKAGE__;

  return $self;
}


1;

#POD

=encoding utf8

=head1 NAME

Slovo::Plugin::Prodan – Manage sales in your Slovo-based site

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
aside#widgets {
    padding-top: 7rem;
    padding-bottom: 4rem;
    position: fixed;
    top: 0;
    right: 0;
    font-family: FreeSans, sans-serif;
    max-width: 50%;
}

#order_widget {
    padding: 0;
}

#order_widget>h2 {
    margin: 0;
}

#order_widget>button:nth-child(1) {
    float: right;
} 

#order_widget>table>tfoot th:nth-last-child(1),
#order_widget>table>tbody td:nth-last-child(1) {
    width: 13rem;
    white-space: nowrap;
    text-align: center;

}

#order_widget>table>thead th:nth-last-child(2),
#order_widget>table>tfoot th:nth-last-child(3),
#order_widget>table>tbody td:nth-last-child(2) {
    width: 5rem;
    white-space: nowrap;
    text-align: right;
}

#order_widget>table>thead th:nth-last-child(3),
#order_widget>table>tfoot th:nth-last-child(3),
#order_widget>table>tbody td:nth-last-child(3) {
    width: 7rem;
    white-space: nowrap;
    text-align: right;
}

#order_widget>table>tfoot th:nth-last-child(4) {
    min-width: 20rem;
    text-align: right;
}

button.product,.button.product,
#order_widget .button.cart, #order_widget button.cart {
	font-family: FreeSans, sans-serif;
	color: var(--color-success);
	font-weight: bolder;
	border-radius: 4px;
	font-size: small;
	padding: .5rem 1rem;
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

@media (max-width: 721px) {
    aside#widgets {
        padding-top: 10.5rem;
        padding-bottom: 4rem;
        max-width: 100%;
    }

} /* end @media (max-width: 721px) */

@@ js/cart.js
/* An unobtrusive shopping cart based on localStorage
 * Formatted with `astyle  -A2 lib/Slovo/resources/public/js/cart.js`
 */
jQuery(function($) {
    'use strict';
    let cart = localStorage.cart ? JSON.parse(localStorage.cart) : {};
    let order_widget_template =
`
<div id="order_widget" class="card text-center">
<button class="button primary outline icon cart" title="Показване/Скриване на поръчката"
    id="show_order"><img src="/img/cart.svg" width="24" /></button>
<h2 style="display:none">Поръчка</h2>
<table style="display:none">
<thead><tr><th>Продукт</th><th>Ед. цена</th><th>Бр.</th><th><!-- action --></th></tr></thead>
<tbody><!-- Here will be the order items --></tbody>
<tfoot>
<tr><th>
<button class="button primary outline icon cart pull-left"
title="Отказ от поръчката" id="cancel_order"><img src="/img/cart-off.svg" width="24" /></button>
Общо с ДДС(лв.)</th><th id="order_total"></th><th></th>
<th>
</th>
</tr>
</tfoot>
</table>
</div>
`;
    show_order();
    /* In a regular page we present a product(book, software package,
     * whatever). On the page there is one or more buttons(one per product)
     * (.add-to-cart) in which data- attributes are stored all the properties
     * of the product. Clicking on the button adds the product to the card.
     * */
    $('.add-to-cart').click(add_to_cart);
    $('#cancel_order').click(function() {
        delete localStorage.cart;
        $('#order_widget').remove();
    });
    function add_to_cart() {
        let product = $(this).data();
        let product_id = '_'+product.id;
        if(product_id in cart) {
            ++cart[product_id].quantity;
        } else {
            cart[product_id] = {id: product.id, title: product.title, quantity:1, price: product.price};
        }
        // Store the changed cart!!!
        localStorage.setItem('cart', JSON.stringify(cart));
        // display the cart in #order_widget
        show_order();
    }

    function show_order() {
        // there is nothing to show? return.
        if(!Object.keys(cart).length) return;

        let order_widget = $('#order_widget');
        //if not yet in dom, create it in #widgets
        if(!order_widget.length) {
            $('#widgets').prepend(order_widget_template);
            //populate the table>tbody with the contents of the cart
            $(Object.keys(cart)).each(populate_order_table);
            // make the cart button to toggle the visibility of the products table
            $('#show_order').click(toggle_order_table_visibility);
        }
        //else update it
        else {
            repopulate_order_table();
        }
        // calculate the sum of the order
        let sum = 0;
        Object.keys(cart).forEach( (curr) => sum += cart[curr].price * cart[curr].quantity );
        // VAT is included in the price
        $('#order_total').html(sum.toFixed(2));
    }// end function show_order()

    function populate_order_table() {
        // console.log(`this: `, this);
        $('#order_widget>table>tbody')
        .append(`
                  <tr id="${cart[this].id}">
                    <td title="${cart[this].title}">${cart[this].title}</td>
                    <td>${cart[this].price}</td>
                    <td>${cart[this].quantity} бр.</td>
                    <td>
                      <img class="outline minus" src="/img/cart-minus.svg" width="32" />
                      <img class="outline plus" src="/img/cart-plus.svg" width="32" />
                      <img class="outline remove" src="/img/cart-remove.svg" width="32" />
                    </td>
                  </tr>`
        );
    }

    function repopulate_order_table() {
        $('#order_widget>table>tbody').empty();
        $(Object.keys(cart)).each(populate_order_table);
    }

    function toggle_order_table_visibility() {
        let order_button_icon = $('#order_widget #show_order>img');
        if(order_button_icon.attr('src').match(/cart/))
            order_button_icon.attr('src', '/img/arrow-collapse-all.svg');
        else
            order_button_icon.attr('src', '/img/cart.svg');
        $('#order_widget>h2,#order_widget>table').toggle();
    }
});



@@ partials/_widgets.html.ep
    <aside id="widgets"></aside>
@@ img/arrow-collapse-all.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M19.5,3.09L20.91,4.5L16.41,9H20V11H13V4H15V7.59L19.5,3.09M20.91,19.5L19.5,20.91L15,16.41V20H13V13H20V15H16.41L20.91,19.5M4.5,3.09L9,7.59V4H11V11H4V9H7.59L3.09,4.5L4.5,3.09M3.09,19.5L7.59,15H4V13H11V20H9V16.41L4.5,20.91L3.09,19.5Z" /></svg>
@@ img/cart.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M17,18C15.89,18 15,18.89 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20C19,18.89 18.1,18 17,18M1,2V4H3L6.6,11.59L5.24,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42A0.25,0.25 0 0,1 7.17,14.75C7.17,14.7 7.18,14.66 7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.58 17.3,11.97L20.88,5.5C20.95,5.34 21,5.17 21,5A1,1 0 0,0 20,4H5.21L4.27,2M7,18C5.89,18 5,18.89 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20C9,18.89 8.1,18 7,18Z" /></svg>
@@ img/cart-off.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M22.73,22.73L1.27,1.27L0,2.54L4.39,6.93L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H14.46L15.84,18.38C15.34,18.74 15,19.33 15,20A2,2 0 0,0 17,22C17.67,22 18.26,21.67 18.62,21.16L21.46,24L22.73,22.73M7.42,15A0.25,0.25 0 0,1 7.17,14.75L7.2,14.63L8.1,13H10.46L12.46,15H7.42M15.55,13C16.3,13 16.96,12.59 17.3,11.97L20.88,5.5C20.96,5.34 21,5.17 21,5A1,1 0 0,0 20,4H6.54L15.55,13M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18Z" /></svg>
@@ img/cart-minus.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M16,6V4H8V6M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18M17,18A2,2 0 0,0 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20A2,2 0 0,0 17,18M7.17,14.75L7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.59 17.3,11.97L21.16,4.96L19.42,4H19.41L18.31,6L15.55,11H8.53L8.4,10.73L6.16,6L5.21,4L4.27,2H1V4H3L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42C7.29,15 7.17,14.89 7.17,14.75Z" /></svg>
@@ img/cart-plus.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M11,9H13V6H16V4H13V1H11V4H8V6H11M7,18A2,2 0 0,0 5,20A2,2 0 0,0 7,22A2,2 0 0,0 9,20A2,2 0 0,0 7,18M17,18A2,2 0 0,0 15,20A2,2 0 0,0 17,22A2,2 0 0,0 19,20A2,2 0 0,0 17,18M7.17,14.75L7.2,14.63L8.1,13H15.55C16.3,13 16.96,12.59 17.3,11.97L21.16,4.96L19.42,4H19.41L18.31,6L15.55,11H8.53L8.4,10.73L6.16,6L5.21,4L4.27,2H1V4H3L6.6,11.59L5.25,14.04C5.09,14.32 5,14.65 5,15A2,2 0 0,0 7,17H19V15H7.42C7.29,15 7.17,14.89 7.17,14.75Z" /></svg>
@@ img/cart-remove.svg
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="24" height="24" viewBox="0 0 24 24"><path d="M14.12,8.53L12,6.41L9.88,8.54L8.46,7.12L10.59,5L8.47,2.88L9.88,1.47L12,3.59L14.12,1.46L15.54,2.88L13.41,5L15.53,7.12L14.12,8.53M7,18A2,2 0 0,1 9,20A2,2 0 0,1 7,22A2,2 0 0,1 5,20A2,2 0 0,1 7,18M17,18A2,2 0 0,1 19,20A2,2 0 0,1 17,22A2,2 0 0,1 15,20A2,2 0 0,1 17,18M7.17,14.75A0.25,0.25 0 0,0 7.42,15H19V17H7A2,2 0 0,1 5,15C5,14.65 5.09,14.32 5.25,14.04L6.6,11.59L3,4H1V2H4.27L5.21,4L6.16,6L8.4,10.73L8.53,11H15.55L18.31,6L19.41,4H19.42L21.16,4.96L17.3,11.97C16.96,12.59 16.3,13 15.55,13H8.1L7.2,14.63L7.17,14.75Z" /></svg>

