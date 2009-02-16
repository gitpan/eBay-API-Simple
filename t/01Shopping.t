use Test::More;
use strict; no warnings;
#use LWP::Debug qw(+);
use Data::Dumper;
use lib qw/lib/;

BEGIN {
    my @skip_msg;

    eval {
        use eBay::API::Simple::Shopping;
    };
    
    if ( $@ ) {
        push @skip_msg, 'missing module eBay::API::Simple::Shopping, skipping test';
    }
    if ( scalar( @skip_msg ) ) {
        plan skip_all => join( ' ', @skip_msg );
    }
    else {
        plan qw(no_plan);
    }    
}

my $call = eBay::API::Simple::Shopping->new();

#$call->api_init( { 
#    site_id => 0,
#    uri     => $arg_uri,
#    domain  => $arg_domain,
#    app_id  => $arg_appid,
#    version => $arg_version,
#} );

eval {    
    $call->execute( 'FindItems', 
        { QueryKeywords => 'black shoes', MaxEntries => 10 } 
    );
};

SKIP: {
    skip $@, 1 if $@;

    #diag $call->request_object->as_string();
    #diag $call->response_object->as_string();

    if ( $call->has_error() ) {
        fail( 'api call failed: ' . $call->errors_as_string() );
    }
    else {
        is( ref $call->response_dom(), 'XML::LibXML::Document', 'response dom' );
        is( ref $call->response_hash(), 'HASH', 'response hash' );

        like( $call->nodeContent('Timestamp'), 
            qr/^\d{4}-\d{2}-\d{2}/, 
            'response timestamp' 
        );
    
        ok( $call->nodeContent('TotalItems') > 10, 'response total items' );
    #    diag( 'total items: ' . $call->nodeContent('TotalItems') );
    #    diag( Dumper( $call->response_hash() ) );
    }

    $call->execute( 'BadCall', { QueryKeywords => 'shoe' } );

    is( $call->has_error(), 1, 'look for error flag' );
    ok( $call->errors_as_string() ne '', 'check for error message' );
    ok( $call->response_content() ne '', 'check for response content' );

    $call->execute( 'FindItemsAdvanced', { QueryKeywords => 'shoe' } );

    is( $call->has_error(), 0, 'error check' );
    is( $call->errors_as_string(), '', 'error string check' );
    ok( $call->nodeContent('TotalItems') > 10, 'response total items' );

    #diag( Dumper( $call->response_content() ) );

    my @nodes = $call->response_dom->findnodes(
        '/FindItemsAdvancedResponse/SearchResult/ItemArray/Item'
    );

    foreach my $n ( @nodes ) {
        # diag( $n->findvalue('Title/text()') );
        ok( $n->findvalue('Title/text()') ne '', 'title check' );
    }


    my $call2 = eBay::API::Simple::Shopping->new( { response_encoding => 'XML' } );
    $call2->execute( 'FindPopularSearches', { QueryKeywords => 'shoe' } );

    #diag( $call2->response_content() );
}

