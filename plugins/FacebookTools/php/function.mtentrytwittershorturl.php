<?php
function smarty_function_mtentrytwittershorturl($args, &$ctx) {
	$blog_id = $ctx->stash('blog_id');
	$entry = $ctx->stash('entry');
	$url = '';
	if ($entry) {
		$obj_type = 'entry';
		$obj_id = $entry['entry_id'];
		$meta = $ctx->mt->db->get_meta($obj_type, $obj_id);
        $url = $meta['twitter_short_url'];
	} else {
		return 'no entry';
	}
	return $url;
}
?>