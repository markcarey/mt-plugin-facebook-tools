package FacebookTools::App::CMS;
use strict;

# use MT::Util qw( dirify );
use FacebookTools::Util qw( get_facebook_client fbtools_pro );

use Data::Dumper;

sub blog_config_template {
	my $app = MT->instance->app;
	my $q = $app->param();
	my $blog_id = $q->param('blog_id');
	my $plugin = MT->component('FacebookTools');
	my $scope = 'system';
	my $config = $plugin->get_config_hash($scope);
	my $blog_config = $plugin->get_config_hash('blog:'.$blog_id);
	my $authed = 1 if ($blog_config->{facebook_access_token} && $blog_config->{facebook_username});
	my $oauth_ready = 1 if ($blog_config->{facebook_application_id} || $config->{facebook_application_id} || MT->config('FacebookToolsApplicationID'));
	my $pro = fbtools_pro();
    my $tmpl = <<EOT;
	<mt:var name="blog_id" value="$blog_id">
	<mt:var name="authed" value="$authed">
	<mt:var name="oauth_ready" value="$oauth_ready">
	<mt:var name="pro" value="$pro">

<mt:If name="oauth_ready">	
	<mt:if name="authed">
		<mtapp:statusmsg
            id="authed"
            class="info">
            <p>Facebook user <strong><a href="http://facebook.com/<mt:var name="facebook_username">" target="_blank"><mt:var name="Facebook_username"></a></strong> has been authorized for this blog. New entries will be posted to this Facebook account.  To use a different Facebook account or to re-authorize, use the button below.</p>
        </mtapp:statusmsg>
		
		<input type="hidden" name="facebook_username" id="facebook_username" value="<mt:var name="facebook_username" escape="html">" />
		<input type="hidden" name="facebook_access_token" id="facebook_access_token" value="<mt:var name="facebook_access_token" escape="html">" />
	</mt:if>
	
	<mtapp:setting
	    id="facebook_aoauth"
	    label="<__trans phrase="Facebook Authorization">"
	    hint="Sign in with Facebook to authorize Facebook Tools to access your Facebook account."
		class="actions-bar"
	    show_hint="1">
	        <a href="<mt:CGIPath><mt:AdminScript>?__mode=facebooktools&amp;blog_id=$blog_id&amp;return_args=__mode%3Dcfg_plugins%26%26blog_id%3D$blog_id"><img src="<mt:StaticWebPath>plugins/FacebookTools/images/signin_with_facebook.gif" /></a>
	</mtapp:setting>
	
	<mtapp:setting
	    id="auto_share"
	    label="<__trans phrase="Auto-Share New Entries">"
	    hint="<__trans phrase="Automatically share on Facebook when a new entry is published.  Applies to Facebook accounts authorized for both this blog and for the entry author.">"
	    show_hint="1">
	    <input type="checkbox" name="auto_share" id="auto_share" value="1" <mt:If name="auto_share">checked</mt:If> />
	</mtapp:setting>
	
	<mtapp:setting
	    id="tweet_prefix"
	    label="<__trans phrase="Message Prefix">"
	    hint="<__trans phrase="Enter an (optional) prefix for your share messages.  For example: 'New post:' or 'New entry:'.">"
	    show_hint="1">
	    <input name="tweet_prefix" id="tweet_prefix" value="<mt:var name="tweet_prefix" escape="html">" size="40" />
	</mtapp:setting>

<mt:Ignore reason="no hastag support on Facebook yet">	
	<mtapp:setting
	    id="default_hashtags"
	    label="<__trans phrase="Hashtags">"
	    hint="<__trans phrase="Enter one or more hashtags to append to EVERY message.  For example: '#mthacks #Facebook'.">"
	    show_hint="1">
	    <input name="default_hashtags" id="default_hashtags" value="<mt:var name="default_hashtags" escape="html">" size="40" />
	</mtapp:setting>
	
	<mtapp:setting
	    id="entry_hashtags"
	    label="<__trans phrase="Use Entry Tags as Hashtags">"
	    hint="<__trans phrase="Append the Entry Tags to the message as #hashtags, if there is room left in the 420 character limit.">"
	    show_hint="1">
	    <input type="checkbox" name="entry_hashtags" id="entry_hashtags" value="1" <mt:If name="entry_hashtags">checked</mt:If> />
	</mtapp:setting>
</mt:Ignore>
	
<mt:If name="pro">	
	<mtapp:setting
	    id="tweet_field"
	    label="<__trans phrase="Staus Message Field">"
	    hint="<__trans phrase="Choose the Entry field to use for the status message text.  If you chose 'Custom Field', you need to create an Entry Custom Field called 'FBStatus' and use that for your desired message text. Note that if the chosen entry field is blank, the entry will not be posted to Facebook.">"
	    show_hint="1">
	    <select name="tweet_field">
			<option value="title" <mt:if name="tweet_field" eq="title"> selected="selected"</mt:if>>Title</option>
			<option value="text" <mt:if name="tweet_field" eq="text"> selected="selected"</mt:if>>Body</option>
			<option value="text_more" <mt:if name="tweet_field" eq="text_more"> selected="selected"</mt:if>>Extended</option>
			<option value="excerpt" <mt:if name="tweet_field" eq="excerpt"> selected="selected"</mt:if>>Excerpt</option>
			<option value="keywords" <mt:if name="tweet_field" eq="keywords"> selected="selected"</mt:if>>Keywords</option>
			<option value="custom" <mt:if name="tweet_field" eq="custom"> selected="selected"</mt:if>>Custom Field</option>
		</select>
	</mtapp:setting>
	
	<mtapp:setting
	    id="filter_cats"
	    label="<__trans phrase="Only Share with Categories">"
	    hint="<__trans phrase="Enter a comma seperated list of Categories (case-sensitive). **ONLY** entries in any of these Categories will be posted to Facebook. Leave blank to share entries from all Categories.">"
	    show_hint="1">
	    <input name="filter_cats" id="filter_cats" value="<mt:var name="filter_cats" escape="html">" size="40" />
	</mtapp:setting>
	
	<mtapp:setting
	    id="filter_tags"
	    label="<__trans phrase="Only Share with Tags">"
	    hint="<__trans phrase="Enter a comma seperated list of Tags (case-sensitive). **ONLY** entries with any of these Tags will be shared. Leave blank to share entries with any tag (or none).">"
	    show_hint="1">
	    <input name="filter_tags" id="filter_tags" value="<mt:var name="filter_tags" escape="html">" size="40" />
	</mtapp:setting>

<input type="hidden" name="never_shorten" id="never_shorten" value="1" />	
<mt:ignore reason="do people really want url shoetening with facebook">	
	<mtapp:setting
	    id="never_shorten"
	    label="<__trans phrase="Never Shorten URLs">"
	    hint="<__trans phrase="(Advanced) If this box is checked the plugin will never shorten entry URLs. Note that the Facebook API may still shorten URLs if tweets or URLs are very long.">"
	    show_hint="1">
	    <input type="checkbox" name="never_shorten" id="never_shorten" value="1" <mt:If name="never_shorten">checked</mt:If> />
	</mtapp:setting>
	
	<mtapp:setting
	    id="shortner_service"
	    label="<__trans phrase="URL Shortner Service">"
	    hint="<__trans phrase="The name of the URL shortner service (optional). Must be exactly one of: Bitly, TinyURL, Awesm, Moopz.">"
	    show_hint="1">
	    <input name="shortner_service" id="shortner_service" value="<mt:var name="shortner_service" escape="html">" size="40" />
	</mtapp:setting>

	<mtapp:setting
	    id="shortner_username"
	    label="<__trans phrase="URL Shortner Username">"
	    hint="<__trans phrase="The username of the URL shortner account (if applicable).">"
	    show_hint="1">
	    <input name="shortner_username" id="shortner_username" value="<mt:var name="shortner_username" escape="html">" size="40" />
	</mtapp:setting>

	<mtapp:setting
	    id="shortner_apikey"
	    label="<__trans phrase="URL Shortner API Key">"
	    hint="<__trans phrase="The API key or password of the URL shortner account (if applicable).">"
	    show_hint="1">
	    <input name="shortner_apikey" id="shortner_apikey" value="<mt:var name="shortner_apikey" escape="html">" size="40" />
	</mtapp:setting>
</mt:Ignore>
	
</mt:If>

<mt:Else>
    <p><strong>Step 1:</strong> <a href="http://www.facebook.com/developers/createapp.php" target="_blank">Create a Facebook Application</a> and enter the Application ID and Application Secret in the system-level plugin settings.<mt:If name="pro"> Or, you can enter them below to use the application for this blog only.</mt:If> After saving, return here for additonal setup and settings.</p>
</mt:If>
	
<mt:If name="pro">
	<mtapp:setting
        id="facebook_application_id"
        label="<__trans phrase="Facebook Application ID">"
        hint="<__trans phrase="The Facebook Application ID for the application associated with this blog. Optional if completed in system-level settings.">"
        show_hint="1">
        <input name="facebook_application_id" id="facebook_application_id" value="<mt:var name="facebook_application_id" escape="html">" size="40" />
    </mtapp:setting>
    
    <mtapp:setting
        id="facebook_application_secret"
        label="<__trans phrase="Facebook Application Secret">"
        hint="<__trans phrase="The application secret for the Facebook application associated with this blog. Optional if completed in system-level settings.">"
        show_hint="1">
        <input name="facebook_application_secret" id="facebook_application_secret" value="<mt:var name="facebook_application_secret" escape="html">" size="40" />
    </mtapp:setting>
</mt:If>    

EOT
}

sub facebook_oauth {
	my $app = shift;
    my $q = $app->param;
	my $return_to = $q->param('return_to') || $app->cookie_val('return_to');
	my $user;
	my $profile;
	my $access_token;
	
	if ($q->param('code')) {
		($profile, $access_token) = _do_oauth_login($app);
	} else {
		return _start_oauth_login($app,'facebooktools');
	}
	my $blog_id = $q->param('blog_id');
	if (!$blog_id && $return_to =~ m/blog_id=([0-9]+)/) {
		$blog_id = $1;
		$app->param('blog_id',$blog_id);
	}

	my $plugin = MT->component('FacebookTools');
	my $scope = 'blog:'.$blog_id;
	my $config = $plugin->get_config_hash($scope);

	$plugin->set_config_value('facebook_access_token', $access_token, $scope);
	$plugin->set_config_value('facebook_username', $profile->{name}, $scope);
	$plugin->set_config_value('facebook_id', $profile->{id}, $scope);
	
	
	# temp TODO need to fix this
	my $pages;
	my $pro = fbtools_pro();
	if ($pro) {
	    my $accounts;
	    my $client = get_facebook_client($app,$blog_id);
	    $client->access_token($access_token);
        eval {	$accounts = $client->fetch($profile->{id} . '/accounts') };
    	MT->log("FB me accounts die error:" . Dumper($@)) if $@;

    	$pages = $accounts->{data};
        foreach my $page (@$pages) {
    	    my $id = $page->{id};
    	    my $name = $page->{name};
    	    my $page_access_token = $page->{access_token};
#    	    MT->log("Page id is $id and name is $name and token is $page_access_token");
    	}
	}
	
	$app->build_page( $plugin->load_tmpl('oauth_success.tmpl'),
        { return_url => $return_to, facebook_username => $profile->{name}, facebook_screen_name => $profile->{name}, page_loop => $pages, pro => $pro } );
}

sub _start_oauth_login {
	my ($app, $mode, $args) = @_;
#MT->log("mode is $mode");
	my $q = $app->param;
	my $blog_id = $q->param('blog_id');
	my $client = get_facebook_client($app,$blog_id,$mode,$args);
    my $display = 'page';
    $display = 'popup' if ($q->param('popup'));

    my $url = $client->authorize
        ->extend_permissions(qw( manage_pages publish_stream offline_access ))
        ->set_display($display)
        ->uri_as_string;
#MT->log("FB Tools auth url is: $url");

    my $return_to = $app->return_uri;
	my %return_cookie = (
        -name    => 'return_to',
        -value   => $return_to,
        -path    => '/',
        -expires => "+300s"
    );
    $app->bake_cookie(%return_cookie);
    if ($q->param('popup')) {
        my %popup_cookie = (
            -name    => 'popup',
            -value   => 1,
            -path    => '/',
            -expires => "+300s"
        );
        $app->bake_cookie(%popup_cookie);
    }

	$app->redirect($url);
}

sub _do_oauth_login {
	my ($app,$mode,$args) = @_;
	my $q = $app->param;
	my $code = $q->param('code');

    my $return_to = $app->cookie_val('return_to');
    my $blog_id = $q->param('blog_id');
    if (!$blog_id && $return_to =~ m/blog_id=([0-9]+)/) {
		$blog_id = $1;
	}

	my $client = get_facebook_client($app,$blog_id,$mode,$args);
	
    my $response;

    eval { $response = $client->request_access_token($code) };
    if (my $error = $@) {
        MT->log("FB Tools error requesting access token: " . Dumper($error));
    }
    
    my $access_token = $client->access_token;
    $client->access_token($access_token);
    
#MT->log("FB Tools got access token: " . Dumper($access_token));

	my $profile = eval{ $client->fetch('me') };
	if ( my $error = $@ ) {
	    MT->log("Facebook Tools error during fetch me: " . Dumper($error));
	}
#MT->log("FB Tools profile is: " . Dumper($profile));
	return ($profile, $access_token) if $profile;
}



1;