object false

node(:generated_at) { $now }
node(:request_id)   { $next_request_id.call }

node(:article) { partial("article", object: false) }

node(:total_comments) { $arr.size }
