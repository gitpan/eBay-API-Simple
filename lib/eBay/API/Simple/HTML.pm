package eBay::API::Simple::HTML;

use strict;
use warnings;

use base 'eBay::API::SimpleBase';

use HTTP::Request;
use HTTP::Headers;
use XML::Simple;

our $DEBUG = 0;

=head1 NAME 

eBay::API::Simple::HTML

=head1 SYNPOSIS

  my $call = eBay::API::Simple::HTML->new();
  $call->execute( 'http://www.timkeefer.com/blog/view/portfolio' );

  if ( $call->has_error() ) {
     die "Call Failed:" . $call->errors_as_string();
  }

  # getters for the response DOM or Hash
  my $dom  = $call->response_dom();
  my $hash = $call->response_hash();

  # collect all h2 nodes
  my @h2 = $dom->getElementsByTagName('h2');

  foreach my $n ( @h2 ) {
    print $n->findvalue('text()') . "\n";
  }
  
=head1 new 

Constructor for the HTML API call

  my $call = ebay::API::Simple::HTML->new();
  $call->execute( 'http://www.timkeefer.com/blog/view/portfolio' );

=cut 

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return $self;    
}

=head1 execute( $url )
 
Calling this method will make build and execute the api request.
  
  $url = page to fetch
  $call->execute( 'http://www.timkeefer.com' );

=cut 

sub execute {
    my $self = shift;
    
    $self->{url} = shift;

    if ( ! defined $self->{url} ) {
        die "missing url";
    }
    
    $self->{response_content} = $self->_execute_http_request();

    # remove xmlns 
    $self->{response_content}  =~ s/xmlns=["'][^"']+"//;

    if ( $DEBUG ) {
        print STDERR $self->{response_content};
    }

}

=head1 response_hash

Custom response_hash method, uses the output from LibXML to generate the 
hash instead of the raw response body.

=cut

sub response_hash {
    my $self = shift;

    if ( ! defined $self->{response_hash} ) {
        $self->{response_hash} = XMLin( $self->response_dom->toString(),
            forcearray => [],
            keyattr    => []
        );
    }

    return $self->{response_hash};
}

=head1 response_dom 

Custom response_dom method, provides a more relaxed parsing to better handle HTML.

=cut

sub response_dom {
    my $self = shift;

    if ( ! defined $self->{response_dom} ) {
        require XML::LibXML;
        my $parser = XML::LibXML->new();
        $parser->recover(1);
        $parser->recover_silently(1);

        eval {
            $self->{response_dom} =
                $parser->parse_html_string( $self->response_content );
        };
        if ( $@ ) {
            $self->errors_append( { 'parsing_error' => $@ } );
        }
    }

    return $self->{response_dom};
}

=head1 _get_request_body

This methods supplies an empty request body for the HTML API call

=cut

sub _get_request_body {
    my $self = shift;
    return "";
}

=head1 _get_request_headers 

This methods supplies the headers for the HTML API call

=cut

sub _get_request_headers {
    my $self = shift;
   
    #my $obj = HTTP::Headers->new();
    #return $obj;
    return '';
}

=head1 _get_request_object 

This method creates the request object and returns to the parent class

=cut

sub _get_request_object {
    my $self = shift;

    my $request_obj = HTTP::Request->new(
        "GET",
        $self->{url},
    );

    return $request_obj;
}

1;

=head1 AUTHOR

Tim Keefer <tim@timkeefer.com>

=head1 COPYRIGHT

Tim Keefer 2009

=cut
