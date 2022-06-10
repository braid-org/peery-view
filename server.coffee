require 'coffeescript/register'
parse = require('./coffee/parser.coffee')

######### Clientwise handlers ##########
# on the to_fetch and to_save handlers:
bus = require('statebus').serve
    port: 1312
    client: (client, server) ->
        parser = parse.PPPParser client

        parser('post/<postid>').to_save = (key, val, old, t) ->
            c = client.fetch "current_user"
            all_posts = bus.fetch "posts"
            # So there's a few cases here. 
            # 1. A client is making a new post
            # 2. A client is deleting an existing post.
            # 3. A client is editing an existing post: this is not allowed!
            # 4. A client is adding a tag to an existing post

            # New post
            unless old.user_key?
                # Is the user logged in and making a post under their own name?
                unless c.logged_in and (c.user.key == val.user_key)
                    return t.abort()
                # Does the post contain all the required fields?
                unless val.user_key and val.title and val.url and val.time \
                    and typeof(val.title) == "string" and typeof(val.url) == "string" and typeof(val.time) == "number"
                    return t.abort()
                
                # Ok, put it into the posts list
                (all_posts.arr ?= []).push val
                bus.save all_posts
                return t.done val
           
            # Deleting post
            unless val.user_key?
                # TODO
                return t.abort()
                
                unless c.logged_in and (c.user.key == old.user_key)
                    return t.abort()
                # Everything looks good. So we need to do four things.
                # 1. Remove the post from `posts`
                # 2. Delete `votes_on/post/<id>`
                # 3. Delete every vote on the post
                #   a. Remove the vote from votes_by
                #   b. Delete the vote itself
                # 4. Delete the actual post.
                
                # TODO: Also delete the tagged votes
                
                # Fetch the votes and make a static copy
                votes = JSON.parse(JSON.stringify(bus.fetch "votes_on/post/#{star}")).values ? []

                # Remove the post from `posts`
                all_posts.all = all_posts.all.filter (p) -> p.key != val.key
                bus.save all_posts

                # Delete `votes_on`
                bus.save {key: "votes_on/post/#{star}"}
                
                # Remove from `votes_by/` and delete the vote key itself
                votes.forEach (v) ->
                    votes_by = bus.fetch "votes_by/#{v.user_key}"
                    delete votes_by[val.key]
                    bus.save votes_by
                    bus.save {key: v.key}
                                
                # Finally delete the actual post
                val = {key: val.key}
                bus.save val
                return t.done val

            # Adding a tag: 
            if val?.tags?.length
                all_tags = bus.fetch "tags"
                all_tags.arr ?= []
                old.tags ?= []
                val.tags.forEach (t) ->
                    unless t in old.tags then old.tags.push t
                    unless t in all_tags.arr then all_tags.arr.push t
                bus.save all_tags
                bus.save old
                return t.done old

            t.abort()

        # If an individual vote is saved, put it in the arrays if necessary.
        parser('user/<userid>/vote/<type>/<targetid>').to_save = (key, val, old, t) ->
            {userid, type, targetid} = t._path
            {tag} = t._params
            user = "user/#{userid}"
            target = "#{type}/#{targetid}"

            # Permission and integrity checking
            c = client.fetch "current_user"
            unless type == "user" or type == "post"
                console.log "Bad type '#{type}'"
                return t.abort()
            # Check that user has the right to change the key
            unless c.logged_in and c.user.key == user == val.user_key
                console.log "User #{c.user.key}, #{user} in url, #{val.user_key} in state"
                return t.abort()
            # Check that the key matches the contents
            unless target == val.target_key
                console.log "Bad target ('#{target}' in url, '#{val.target_key}' in state)"
                return t.abort()
            # Check that the vote has an associated value between 0 and 1
            unless 0 <= val.value <= 1
                return t.abort()
            # Check that the tag is right
            if tag != val.tag
                console.log "Bad tag ('#{tag}' in url, '#{val.tag}' in state)"
                return t.abort()
            # Alright, looks good.
            
            # Is this a new vote?
            unless old.value?
                # Put this vote into the necessary arrays.
                # We only put it into the untagged arrays -- the tagged (ie, filtered) views of these arrays are computed automatically
                ["#{user}/votes", "votes/#{target}"].forEach (k) ->
                    s = bus.fetch k
                    (s.arr ?= []).push val
                    bus.save s

            # Add the tag-type if necessary
            if tag
                target_obj = bus.fetch target
                unless tag in (target_obj.tags ?= [])
                    target_obj.tags.push tag
                bus.save target_obj

                all_tags = bus.fetch "tags"
                unless tag in (all_tags.arr ?= [])
                    all_tags.arr.push tag
                bus.save all_tags
            
            bus.save val
            t.done val

        client('users').to_fetch = (t) ->
            bus.fetch 'users'

        client.shadows bus
        
########## main bus handlers #########
bus_parser = parse.PPPParser bus

# safety check for state that should return an array
default_arr = (key) -> {arr: [], (bus.cache[key] ?= {key: key})...}


# Network-spread weighting
MIN_WEIGHT = 0.05
MAX_DEPTH = 5
bus_parser('user/<username>/votes/<type>').to_fetch = (key, t) ->
    {username, type} = t._path
    {computed, tag} = t._params
    userkey = "user/#{username}"
    
    # Compute weights through the network
    if computed and type == "people"
        # This function implements the following computation:
        # w(x, y) :=
        #    let l = min(minimum length of all paths x -> y, 5) 
        #    let P = { p : path x -> y | length(p) = l and |Product_{j=1}^(l-1) p_j| >= 0.05}
        #    return Sum_{i=1}^{|P|} Product_{j=1}^l (P_i)_j
        # Then W(x) = { (y, w(x, y)) }
        # Note that *votes* have their values scaled from 0 to 1, while this choice of algorithm scales votes from -1 to 1
        # Just a choice.
        votes = {}
        depth = 0
        queue_cur = {}
        queue_cur[userkey] = [1.0]
        queue_next = {}
        while Object.keys(queue_cur).length
            for target, paths of queue_cur

                vote_computed = depth != 1
                vote_key =  "#{userkey}/vote/#{target}#{parse.stringify_kson {computed: vote_computed, tag: tag}}"

                unless vote_computed
                    votes[target] = bus.fetch vote_key
                    w = 2 * votes[target].value - 1
                else
                    w = (paths.reduce (a, b) -> a+b) / paths.length

                    votes[target] = 
                        key: vote_key
                        user_key: userkey
                        target_key: target
                        value: (w + 1) / 2
                        depth: depth

                if Math.abs(w) <= MIN_WEIGHT
                    continue

                bus.fetch "#{target}/votes/people#{parse.stringify_kson {tag: tag}}"
                    ?.arr
                    ?.filter (v) -> (v.target_key not of votes) and (v.target_key not of queue_cur)
                    ?.forEach (v) ->
                        t = v.target_key
                        # Put a subscription on the individual vote
                        unless t of queue_next
                            queue_next[t] = []
                            bus.fetch v
                        # If a user has a negative weight we record that weight but then we end the chain.
                        queue_next[t].push (2 * v.value - 1) * Math.max w, 0

            # We've processed all nodes at depth n. Now we'll swap our buffers and process the next depth.
            if ++depth <= 5
                queue_cur = queue_next
                queue_next = {}
            # We want to fallback a vote on the default user at depth 2, so that it'll be considered computed.
            # So the "naive" way would be to queue it at depth 2 if the conditions are right. But we might not make it to depth 2!
            # So at depth 1, if the queue is empty, we'll jump to depth 2.
            if (depth == 1) and Object.keys(queue_cur).length == 0
                depth++
            # Now if we're at depth 2 and we don't have a depth=1 vote on default
            if (depth == 2) and "user/default" not of votes
                queue_cur["user/default"] = [1.0]
                
        # Votes is a hash so that we can quickly check membership,
        # but we need to return an array of votes.
        {
            key: key
            arr: Object.values votes
        }
    else
        prefix = if type == "people" then "user" else "post"
        all_votes = bus.fetch "#{userkey}/votes"
        {
            key: key
            arr: all_votes.arr.filter (v) ->

                if c = (!tag or tag == v.tag) and v.target_key.startsWith prefix then bus.fetch v
                c
        }
# Here's a bunch of boring filtering code...    
bus_parser('votes/<type>/<targetid>').to_fetch = (key, t) ->
    {type, targetid} = t._path
    {computed, tag} = t._params
    if tag
        # Fetching here instead of accessing cache makes us reactive
        all_votes = bus.fetch "votes/#{type}/#{targetid}"
        {
            key: key
            arr: all_votes.arr.filter (v) ->
                if c = tag == v.tag then bus.fetch v
                c

        }
    else
        default_arr key

bus_parser('user/<username>/votes').to_fetch = (key, t) ->
    {username} = t._path
    {computed, tag} = t._params
    if tag
        # Fetching here instead of accessing cache makes us reactive
        all_votes = bus.fetch "user/#{username}/votes"
        {
            key: key
            arr: all_votes.arr.filter (v) ->
                if c = tag == v.tag then bus.fetch v
                c
        }
    else
        default_arr key

bus_parser('user/<username>/vote/user/<target>').to_fetch = (key, t) ->
    {username, target} = t._path
    {computed, tag} = t._params

    if computed
        raw = bus.fetch "user/#{username}/vote/user/#{target}#{parse.stringify_kson {tag}}"
        # If the raw vote actually exists
        # This is kind of an arbitrary way to check for a vote existing
        if raw.user_key
            raw.key = key
            raw
        else
            # Call into the weights computation
            # The weights computation outputs an array that contains (ie, modifies) the state we're currently to_fetch'ing...
            # Is there weird statebus magic we have to do?
            wot = bus.fetch "user/#{username}/votes/people#{parse.stringify_kson t._params}"
            for vote of wot.arr
                if vote.key == key
                    return vote

    else
        bus.cache[key] ?= {key: key}


bus_parser('user/<username>/posts').to_fetch = (key, t) ->
    {username} = t._path
    {computed, tag} = t._params
    all_posts = bus.fetch "posts"
    userkey = "user/#{username}"
    {
        key: key
        arr: all_posts.arr.filter (p) ->
            if c = !tag or tag in p.tags and userkey == p.user_key then bus.fetch p
            c
    }

bus_parser('posts').to_fetch = (key, t) ->
    {computed, tag} = t._params
    if tag
        all_posts = bus.fetch "posts"
        {
            key: key
            arr: all_posts.arr.filter (p) ->
                if c = tag in p.tags then bus.fetch p
                c
        }
    else
        default_arr key

bus('tags').to_fetch = (key) -> default_arr key



###### Sending static content over HTTP ##############
express = require 'express'
send_file = (f) -> (r, res) -> res.sendFile(__dirname + f)
bus.http.use('/*', (req, res, next) ->
  if req.headers.accept.includes('html')
    res.sendFile(__dirname + '/static/news.html')
  else
    next()
)
bus.http.use free_the_cors
bus.http.get '/', send_file '/static/news.html'
bus.http.use '/static', express.static('static')


# Coffee Compilation
fs = require 'fs'
minify = (require 'terser').minify
coffee_cache = {}
bus.http.get('/coffee/*', (req, res) ->
  filename = req.path.substr('/coffee/'.length)
  if filename not of coffee_cache
    source = fs.readFileSync "coffee/#{filename}", 'utf-8'
    big = bus.compile_coffee source, filename
    small = (await minify big, {mangle: false}).code
    coffee_cache[filename] = {
      body: small
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

# Pack clientjs
clientjs = ""
bus.http.get '/client.js', (req, res) ->
    # If the clientjs hasn't been assembled yet
    unless clientjs.length
        files =
            ['extras/coffee.js', 'extras/sockjs.js', 'extras/react.js', 'statebus.js', 'client.js']
                .map( (f) => fs.readFileSync('node_modules/statebus/' + f) )
        if bus.options.braid_mode
            files.unshift fs.readFileSync 'node_modules/braidify/braidify-client.js' 
        clientjs = files.join ';\n'
        clientjs = (await minify clientjs, {mangle: false}).code


    # Since we're using raw send, should set content-type
    res.setHeader 'Content-Type', 'application/javascript'
    res.send clientjs



old_bodify = bus.to_http_body
bus.to_http_body = (o) ->
    if o.key == 'posts'
        JSON.stringify o.all
    else
        old_bodify o 


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

