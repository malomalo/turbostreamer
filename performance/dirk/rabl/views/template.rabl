object false

node(:generated_at) { $now }
node(:request_id)   { $next_request_id.call }

node(:cached) { partial("cached", object: false) }

node(:item_count) { 101 }
