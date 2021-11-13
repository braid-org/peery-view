######### Clientwise handlers ##########
bus = require('statebus').serve
    client: (client, server) ->
        # Client cannot edit /votes_by/
        client('votes_by/*').to_save = (val, star, t) ->
            t.abort()

        # When the slidergram saves the list of votes, we want to add some fields to each vote in case they don't exist.
        # We add a (redundant here) 'target', which is just star.
        # But we also add a key (concatenation of the user and the target)
        # This means that each vote will actually get a url.
        # 
        # We will also add this vote (if it doesn't yet exist there) to the array votes_by.
        client('votes_on/*').to_save = (val, old, star, t) ->
            # since we're going to set properties directly on votes_by we have to prevent injection
            if star is "key" or star is "_dirty"
                return t.abort()

            c = client.fetch "current_user"
            userkey = c.user?.key
            our_vote = false
            
            val.values.forEach (v) ->
                v.target ?= star
                v.key ?= "votes/_#{unslash v.user}_#{star}_"

                if userkey is unslash v.user
                    our_vote = v
            
            bus.save val
            # now any new votes will have a url.
            
            # This thing doesn't really work:
            # the problem is that votes_by won't get dirtied if we changed just *the values* of votes.
            if userkey?
                # If there is a vote by the client, put it in votes_by if it isn't already there.
                votes_by = bus.fetch "votes_by/#{userkey}"

                need_to_save = false
                if our_vote
                    need_to_save = !votes_by[star]?
                    votes_by[star] ?= our_vote
                # Delete a vote if it's not there
                else
                    need_to_save = votes_by[star]?
                    delete votes_by[star]
                if need_to_save
                    bus.save votes_by
            # finally, tell the client that we accept their value
            t.done val

        client.shadows bus

######### main bus handlers #########

# Create user/default?

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

        # queue.push ...stuff
        queue.push.apply(queue,
            Object.values(bus.fetch "votes_by/#{uid}")
                .filter (v) ->
                    unless v.target?
                        return false
                    slashes_wtf = unslash v.target
                    (slashes_wtf.startsWith "user") and (slashes_wtf not of weights)
                .map (v) -> [(unslash v.target), v.value * base_weight * NETWORK_ATT]
            )
    weights

bus('weights/*').to_save = (star, t) ->
    t.abort()

bus('votes/*').to_save = (val, old, star, t) ->
    # Check if the vote is the same as the old one
    unless (JSON.stringify val) is (JSON.stringify old)
        # Dirty the pointers to it
        # Just calling bus.dirty doesn't work:
        # 1. These keys don't actually have custom to_fetch handlers on them
        # 2. The value of the array itself hasn't strictly changed at the right time.
        force_dirty "votes_on/#{unslash val.target}"
        force_dirty "votes_by/#{unslash val.user}"
    # Should we call t.done before or after we dirty the arrays?
    t.done val


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

unslash = (t) -> if t.startsWith("/") then t.substr(1) else t
force_dirty = (key) ->
    val = bus.fetch key
    val._dirty = !(val._dirty ? false)
    bus.save val
