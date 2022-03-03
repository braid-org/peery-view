######### Clientwise handlers ##########
bus = require('statebus').serve
    port: 1312
    client: (client, server) ->

        # Client cannot edit /votes_by/
        client('votes_by/*').to_save = (val, star, t) ->
            t.abort()

        client('votes/*').to_save = (val, star, t) ->
            c = client.fetch "current_user"
            split = star.split "_"
            # Check that key is correct
            unless split.length == 4
                return t.abort()
            voter = split[1]
            target = split[2]
            # Check that user has the right to change the key
            unless c.logged_in and c.user.key == voter
                return t.abort()
            # Check that the key matches the contents
            unless voter == val.user and target == val.target
                return t.abort()
            # Check that the vote has an associated value between 0 and 1
            unless 0 <= val.value and val.value <= 1
                return t.abort()
            # Alright, looks good.
            bus.save val
            t.done val


        # When the slidergram saves the list of votes, we want to add some fields to each vote in case they don't exist.
        # We add a (redundant here) 'target', which is just star.
        # But we also add a key (concatenation of the user and the target)
        # This means that each vote will actually get a url.
        # 
        # We will also add this vote (if it doesn't yet exist there) to the array votes_by.
        client('votes_on/*').to_save = (val, old, star, t) ->
            # since we're going to set properties directly on votes_by we have to prevent injection
            if star is "key"
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
            
            # Explicit fetching?
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

        # If an individual vote is saved, put it in the arrays if necessary.
        client('votes/*').to_save = (val, old, star, t) ->
            # Sanity check: make sure the star is of the form _user_target
            if star != "_#{unslash val.user}_#{unslash val.target}_"
                return t.abort()
            # Is this a new vote?
            unless old.value?
                # Put this vote into the necessary arrays.
                votes_by = bus.fetch "votes_by/#{unslash val.user}"
                votes_by[unslash val.target] ?= val
                bus.save votes_by

                votes_on = bus.fetch "votes_on/#{unslash val.target}"
                votes_on.values ?= []
                votes_on.values.push(val)
                bus.save votes_on

                # Is the simultaneous of this substate in two arrays going to cause issues? 
            
            bus.save val
            t.done val

        # Clients may also get a list of all users
        client('all_users').to_fetch = ->
            { all: for user in bus.fetch('users').all then user.key }

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
        if Math.abs(base_weight) < MIN_WEIGHT
            continue

        # queue.push ...stuff
        queue.push.apply(queue,
            Object.values(bus.fetch "votes_by/#{uid}")
                # Prioritize votes that express a stronger opinion.
                .sort (a, b) -> Math.abs(b.value - 0.5) - Math.abs(a.value - 0.5)
                .filter (v) ->
                    unless v.target?
                        return false
                    slashes_wtf = unslash v.target
                    (slashes_wtf.startsWith "user") and (slashes_wtf not of weights)
                .map (v) ->
                    # Causes a subscription on each individual vote
                    bus.fetch v
                    [(unslash v.target), (2 * v.value - 1) * base_weight * NETWORK_ATT]
            )
    weights

bus('weights/*').to_save = (star, t) ->
    t.abort()

###### Sending static content over HTTP ##############
send_file = (f) -> (r, res) -> res.sendFile(__dirname + f)

bus.http.use(free_the_cors)
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

unslash = (t) -> if t?.startsWith?("/") then t.substr(1) else t
slash = (t) -> if t?.startsWith?("/") then t else "/#{t}"


old_bodify = bus.to_http_body
bus.to_http_body = (o) ->
    if o.key == 'posts'
        JSON.stringify(o.all)
    else
        old_bodify(o)


`
// Free the CORS!
function free_the_cors (req, res, next) {
    console.log('free the cors!', req.method, req.url)

    // Hey... these headers aren't about CORS!  Let's move them into the braid
    // libraries:
    res.setHeader('Range-Request-Allow-Methods', 'PATCH, PUT')
    res.setHeader('Range-Request-Allow-Units', 'json')
    res.setHeader("Patches", "OK")
    // ^^ Actually, it looks like we're going to delete these soon.

    var free_the_cors = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "OPTIONS, HEAD, GET, PUT, UNSUBSCRIBE",
        "Access-Control-Allow-Headers": "subscribe, peer, version, parents, merge-type, content-type, patches, cache-control"
    }
    Object.entries(free_the_cors).forEach(x => res.setHeader(x[0], x[1]))
    if (req.method === 'OPTIONS') {
        res.writeHead(200)
        res.end()
    } else
        next()
}
`

restore_pass = (name, newpass) ->
  user = bus.fetch("user/#{name}")
  console.log('############# Restoring pass for ', name)
  user.pass = require('bcrypt-nodejs').hashSync(newpass)
  console.log('############# Now user is ', user)
  bus.save(user)
  console.log('############# Saved!!!!!!! ')

