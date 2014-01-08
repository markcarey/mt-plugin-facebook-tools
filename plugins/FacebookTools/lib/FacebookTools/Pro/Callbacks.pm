package FacebookTools::Pro::Callbacks;
use strict;

use MT::Util qw ( trim );

sub users_content_nav {
    my ($cb, $app, $param, $tmpl) = @_;

    return unless $app->param('id');

    my $menu_str = <<"EOF";
    <mt:if var="USER_VIEW">
        <li><a href="<mt:var name="SCRIPT_URL">?__mode=facebook_account&amp;id=<mt:var name="EDIT_AUTHOR_ID" escape="url">"><b><__trans phrase="Facebook Account"></b></a></li>
     </mt:if>
    <mt:if var="edit_author">
        <li<mt:if name="facebook_account"> class="active"</mt:if>><a href="<mt:var name="SCRIPT_URL">?__mode=facebook_account&amp;id=<mt:var name="id" escape="url">"><b><__trans phrase="Facebook Account"></b></a></li>
    </mt:if>
EOF

    require MT::Builder;
    my $builder = MT::Builder->new;
    my $ctx = $tmpl->context();
    my $menu_tokens = $builder->compile( $ctx, $menu_str )
        or return $cb->error($builder->errstr);

    if ( $param->{line_items} ) {
        push @{ $param->{line_items} }, bless $menu_tokens, 'MT::Template::Tokens';
    }
    else {
        $ctx->{__stash}{vars}{line_items} = [ bless $menu_tokens, 'MT::Template::Tokens' ];
        $param->{line_items} = [ bless $menu_tokens, 'MT::Template::Tokens' ];
    }
    if ( $app->mode eq 'facebook_account' ) {
        $param->{profile_inactive} = 1;
    }
    1;
}

sub auto_share_filters {
	my ($entry, $config) = @_;
#MT->log("start auto_share_filters");
	my $cat_list = $config->{filter_cats};
	my $tag_list = $config->{filter_tags};
	my $passed = 1;
	
	my $app = MT->app;
	
	if ($cat_list) {
		$passed = 0;
		my @add_cats = split /\s*,\s*/,
		  ( $app->param('category_ids') || '' );
		my @catnames = split(',',$cat_list);
		CATNAME: foreach my $cat_name (@catnames) {
			my $cat = MT->model('category')->load({ label => trim($cat_name), blog_id => $entry->blog_id });
			MT->log("Facebook Tools Error: category $cat_name not found") if (!$cat);
			# check for match in already-added catergories
			if ($cat && $entry->is_in_category($cat)) {
				$passed = 1;
#MT->log("found cat match so share it is 1 for " . $entry->title);
				last CATNAME;
			} elsif ($cat) {
				# check for match in about-to-be added categories, such as when creating a new entry and publishing it at the same time
				foreach my $cat_id (@add_cats) {
					if ($cat_id == $cat->id) {
						$passed = 1;
#MT->log("found cat_add match so share it is 1 for " . $entry->title);
						last CATNAME;
					}
				}
			}
		}
	}
	
	if ($tag_list) {
		$passed = 0;
		my @tagnames = split(',',$tag_list);
		TAGNAME: foreach my $tag_name (@tagnames) {
			# check for match in already-added tags
			if ($entry->has_tag(trim($tag_name))) {
				$passed = 1;
#MT->log("found tag match so share it is 1 for " . $entry->title);
				last TAGNAME;
			} else {
				# check for match in about-to-be added tags, such as when creating a new entry and publishing it at the same time
				my $tags = $app->param('tags');
			    if ( defined $tags ) {
			        my $blog = $app->blog;
			        my $fields = $blog->smart_replace_fields;
			        if ( $fields =~ m/tags/ig ) {
			            $tags = MT::App::CMS::_convert_word_chars( $app, $tags );
			        }
			        require MT::Tag;
			        my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
			        my @tags = MT::Tag->split( $tag_delim, $tags );
					foreach my $tag (@tags) {
						if ($tag eq trim($tag_name)) {
							$passed = 1;
#MT->log("found tag_add match so share it is 1 for " . $entry->title);
							last TAGNAME;
						}
					}
			    }
			}
		}
	}
	return $passed;
}

sub edit_entry {
    my ($eh, $app, $param, $tmpl) = @_;
    
    return unless UNIVERSAL::isa($tmpl, 'MT::Template');
    my $q = $app->param;
    my $entry_id = $q->param('id');
    return unless $entry_id;
    my $entry = MT->model('entry')->load($entry_id);
    return unless $entry;
    return if ($entry->status != 2);
    return if $entry->facebook_object_id;   # alreaded shared
    
	my $plugin = MT->component('FacebookTools');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{auto_share}; 
	return if !$enabled; #even though this is a manual share feature, auto-share must be enabled to turn on this feature for a blog
	my $innerHTML;

	my $pub_widget = $tmpl->getElementById('entry-publishing-widget')
	    or return $app->error('cannot get the entry-publishing-widget');
	$innerHTML = $pub_widget->innerHTML;
    $innerHTML .= <<MTML;
<mtapp:setting
    id="share-it">
    <input type="checkbox" name="share_it" id="share-it" value="1" class="cb" /> <label for="share_it"><__trans phrase="Post to Facebook"/></label>
</mtapp:setting>
MTML
	$pub_widget->innerHTML($innerHTML);
}

sub cms_pre_save_entry {
    my $eh = shift;
    my ($app, $entry) = @_;
    my $q = $app->param;
    if ( $q->param('share_it') && ($entry->status == 2) ) {
        # MT->log("Share it for " . $entry->title);
        $entry->{share_it} = 'manual';
        _shareme($entry->id);
    }
    1;
}

sub _shareme {
    my ($entry_id) = @_;
    my $key = 'fbme_' . $entry_id;
    my $session = MT->model('session')->load({ kind => 'FB', id => $key });
    next if ($session); #if the session exists that means we queued this already
    
    # now create session
    $session = MT->model('session')->new;
    $session->kind('FB');
    $session->id($key);
    $session->start(time);
    $session->save;
}

1;