######### Clientwise handlers ##########
bus = require('statebus').serve
    client: (client, server) ->
        client("votes_on/*").to_fetch = (star, t) ->
            votes = (bus.fetch("votes").all ? [])
                .filter (v) -> v.target == star

            return
                poles: ["-1", "+1"]
                values: votes

        client("votes_on/*").to_save = (val, star, t) ->
            # Travis's slidergram is going to try to save to this endpoint.
            # Save an actual vote
            c = client.fetch 'current_user'
            if c.logged_in
                # Just change the vote for the user
                # Find the right vote in the list
                votes_from_us = val.values.filter (v) -> unprefix(v.user) is unprefix(c.user.key)
                # Pull out its value. 
                # If the value isn't there then the vote was probably deleted.
                value = votes_from_us[0]?.value ? 0
                if value == 0
                    console.log(val)

                # Where such a vote should be stored.
                vote_key =  "votes/_#{c.user.key}_#{star}_"
                new_vote = bus.fetch vote_key
                
                # ie, if the vote doesn't exist yet
                unless new_vote.user
                    # then we have to put it in the votes array
                    all_votes = bus.fetch("votes").all ? []
                    all_votes.push new_vote
                    bus.save
                        key: "votes"
                        all: all_votes
                    # at this point it's just a stub
                    # basically, a pointer to an unallocated location
                    # but that's fine because we're going to put something at that key now
                # Put properties on the vote
                Object.assign new_vote, {
                    user: c.user.key
                    target: star
                    value: value
                }
                # Save it
                bus.save new_vote
                # Save the vote to the list of votes
            # Allow the client to keep the "slidergram-computed" version of the votes
            t.done val

        client.shadows bus
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
                queue.push [vote.target, vote.value * base_weight * NETWORK_ATT]
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

unprefix = (t) -> if t.startsWith("/") then t.substr(1) else t
