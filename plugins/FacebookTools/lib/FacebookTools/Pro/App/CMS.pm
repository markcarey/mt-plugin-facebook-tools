package FacebookTools::Pro::App::CMS;
use strict;

use FacebookTools::Util qw( get_facebook_client );

use FacebookTools::App::CMS;

use Data::Dumper;

sub facebook_account {
	my $app = shift;
	my $q = $app->param;
	my $plugin = MT->component('FacebookTools');
    my $author_id = $app->param('id')
        or return $app->error('Author id is required');
    my $user = MT->model('author')->load($author_id)
        or return $app->error('Author id is invalid');
    return $app->error('Not permitted to view')
        if $app->user->id != $author_id && !$app->user->is_superuser();
	my $profile;
	my $access_token;
	my $facebook_username;
	my $authed = 0;
	my $args = {};
	$args->{id} = $user->id;
	if ($q->param('code')) {
		($profile, $access_token) = FacebookTools::App::CMS::_do_oauth_login($app,'facebook_account',$args);
		if ($profile) {
			$user->facebook_username($profile->{name});
			$user->facebook_id($profile->{id});
			$user->facebook_access_token($access_token);
			$user->save;
		}
	} elsif ($q->param('start_oauth')) {
		return FacebookTools::App::CMS::_start_oauth_login($app,'facebook_account', $args);
	}
	if ($user->facebook_username && $user->facebook_access_token) {
		$facebook_username = $user->facebook_username;
		$authed = 1;
	}

	$app->build_page( $plugin->load_tmpl('facebook_account.tmpl'),
        {   return_url => $app->return_uri, 
	        id             => $user->id,
	        username       => $user->name,
	        edit_author_id => $user->id,
			authed		   => $authed,
			facebook_username => $facebook_username,
	  	} );
}

sub facebook_page_auth {
	my $app = shift;
    my $q = $app->param;
	my $page_id = $q->param('page_id');
	my $return_to = $q->param('return_to') || $app->cookie_val('return_to');
		
	my $blog_id = $q->param('blog_id');
	if (!$blog_id && $return_to =~ m/blog_id=([0-9]+)/) {
		$blog_id = $1;
		$app->param('blog_id',$blog_id);
	}

	my $plugin = MT->component('FacebookTools');
	my $scope = 'blog:'.$blog_id;
	my $config = $plugin->get_config_hash($scope);
	
	my $accounts;
    my $client = get_facebook_client($app,$blog_id);
    $client->access_token($config->{facebook_access_token});
    eval {	$accounts = $client->fetch('me/accounts') };
	MT->log("FB accounts die error:" . Dumper($@)) if $@;

	my $pages = $accounts->{data};
	my $page_name;
	my $access_token;
    foreach my $page (@$pages) {
	    my $id = $page->{id};
	    my $name = $page->{name};
	    my $page_access_token = $page->{access_token};
#	    MT->log("page_auth Page id is $id and name is $name and token is $page_access_token");
	    if ($id == $page_id) {
	        $access_token = $page_access_token;
	        $page_name = $name;
	    }
	}
	
	$plugin->set_config_value('facebook_access_token', $access_token, $scope);
	$plugin->set_config_value('facebook_username', $page_name, $scope);
	$plugin->set_config_value('facebook_id', $page_id, $scope);
	
	$app->build_page( $plugin->load_tmpl('oauth_success.tmpl'),
        { return_url => $return_to, facebook_username => $page_name, facebook_screen_name => $page_name, page_auth => 1 } );
}


1;