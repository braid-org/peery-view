######### Clientwise handlers ##########
bus = require('statebus').serve
    client: (client, socket) ->
        ###
        client("vote/*").to_save = (val, star, t) ->
            vote = bus.fetch "vote/#{star}"
            c = client.fetch "current_user"

            # Also need to check the shape of the data...
            if c.logged_in and c.user.key == vote.user
                t.done val
            else
                t.abort()

        client("post/*").to_save = (val, star, t) ->
            post = bus.fetch "post/#{star}"
            c = client.fetch "current_user"

            # Also need to check the shape of the data...
            if c.logged_in and c.user.key == post.user
                t.done val
            else
                t.abort()

        client("posts/*").to_save = (val, star, t) ->
            t.abort()
        ###

######### main bus handlers #########

# '/feed' = union over all /posts/*
# '/user_feed/*' = feed for a particular user = union of 
# '/posts/*' = posts made by user
# '/network/*' = complete network for a certain user
# '/votes_on/*'.to_fetch = all votes made on the specified thing: either a user or a post.
# '/votes_on_users/*'.to_fetch = all votes made on users by the specified user.
# '/votes_on_posts/*'.to_fetch = all votes made on posts by the specified user.

# Virtual keys cannot actually be edited.
virtual_keys = [
    'feed'
    'user_feed/*'
    'network/*'
    'weights/*'
    'votes_on/*'
    'votes_on_users/*'
    'votes_on_posts/*'
]
virtual_keys.forEach((key) ->
    bus(key).to_save = ((val, t) -> t.abort()))

# Network-spread weighting
MIN_WEIGHT = 0.05
NETWORK_ATT = 0.95
bus('weights/*').to_fetch = (star) ->
    weights = {}
    queue = [[star, 1.0]]
    while queue.length
        [uid, base_weight] = queue.shift()
        weights[uid] = base_weight
        if base_weight < MIN_WEIGHT
            continue
        for vote in (bus.fetch "votes_on_users#{uid}").all ? []
            unless vote.target of weights
                queue.push [vote.target, vote.weight * base_weight * NETWORK_ATT]
    {weights: weights}



###### Sending static content over HTTP ##############
send_file = (f) -> (r, res) -> res.sendFile(__dirname + f)

bus.http.get('/', send_file '/html/news.html')
# Coffee Compilation
coffee_cache = {}
bus.http.get('/coffee/*', (req, res) ->
  filename = req.path.substr('/coffee/'.length)
  if filename not of coffee_cache
    source = require('fs').readFileSync "coffee/#{filename}", 'utf-8'
    coffee_cache[filename] = {
      body: bus.compile_coffee source, filename
      etag: Math.random() + ''
    }

  res.setHeader 'Cache-Control', 'public'
  res.setHeader 'ETag', coffee_cache[filename].etag
  res.setHeader 'Access-Control-Allow-Origin', '*'
  res.setHeader 'Content-Type', 'application/javascript'
  res.send coffee_cache[filename].body
)

dirty_coffee = (event, path) -> coffee_cache = {}
require('chokidar').watch('./coffee').on('all', dirty_coffee)

