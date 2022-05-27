######### Clientwise handlers ##########
bus = require('statebus').serve
    port: 1312
    client: (client, server) ->

        client('posts').to_save = (val, t) ->
            t.abort()

        client('post/*').to_save = (val, old, star, t) ->
            c = client.fetch "current_user"
            all_posts = bus.fetch "posts"
            # So there's a few cases here. 
            # 1. A client is making a new post
            # 2. A client is deleting an existing post.
            # 3. A client is editing an existing post: this is not allowed!

            # New post
            unless old.user?
                # Is the user logged in and making a post under their own name?
                unless c.logged_in and (c.user.key == unslash val.user)
                    return t.abort()
                # Does the post contain all the required fields?
                unless val.user and val.title and val.url and val.time \
                    and typeof(val.title) == "string" and typeof(val.url) == "string" and typeof(val.time) == "number"
                    return t.abort()
                
                # Ok, put it into the posts list
                all_posts.all ?= []
                all_posts.all.push val
                bus.save all_posts
                return t.done val
           
            # Deleting post
            unless val.user?
                unless c.logged_in and (c.user.key == unslash old.user)
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
                    votes_by = bus.fetch "votes_by/#{unslash v.user}"
                    delete votes_by[unslash val.key]
                    bus.save votes_by
                    bus.save {key: v.key}
                                
                # Finally delete the actual post
                val = {key: val.key}
                bus.save val
                return t.done val
            # Adding a tag: TODO: FIND A BETTER PLACE TO STORE A TAG
            if val?.tags?.length
                all_tags = bus.fetch "tags"
                all_tags.tags ||= []
                old.tags ||= []
                val.tags.forEach (t) => 
                    unless t in old.tags then old.tags.push t
                    unless t in all_tags.tags then all_tags.tags.push t
                bus.save old
                return t.done old
            

            t.abort()


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

            # The slidergram no longer directly saves this array. So it's not clear what the 

            console.warn("votes_on saved!!")
            return t.abort()


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
            # Permission and integrity checking
            c = client.fetch "current_user"
            split = star.split "_"
            # Check that key is correct
            unless split.length == 4 or split.length == 5
                console.log("Got a bad key")
                return t.abort()
            voter = split[1]
            target = split[2]
            tag = split[3]
            # Check that user has the right to change the key
            unless c.logged_in and c.user.key == voter
                return t.abort()
            # Check that the key matches the contents
            unless voter == (unslash val.user) and target == (unslash val.target)
                return t.abort()
            # Check that the vote has an associated value between 0 and 1
            unless 0 <= val.value and val.value <= 1
                return t.abort()
            # Check that the tag is right
            if split.length == 5 and (tag != val.tag or tag.length == 0)
                console.log tag
                console.log val.tag
                return t.abort()
            # Alright, looks good.
            
            # Is this a new vote?
            unless old.value?
                tag_path = if split.length == 5 then "/#{tag}" else ""
                # Put this vote into the necessary arrays.
                votes_by = bus.fetch "votes_by/#{unslash val.user}#{tag_path}"
                votes_by[unslash val.target] ?= val
                bus.save votes_by

                votes_on = bus.fetch "votes_on/#{unslash val.target}#{tag_path}"
                votes_on.values ?= []
                votes_on.values.push val
                bus.save votes_on

            # Add the tag-type if necessary
            if split.length == 5
                target_obj = bus.fetch target
                target_obj.tags ||= []
                unless tag in target_obj.tags
                    target_obj.tags.push tag
                bus.save target_obj

                all_tags = bus.fetch "tags"
                unless tag in all_tags.tags
                    all_tags.tags.push tag
                bus.save all_tags

            
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
    # This functions implements the following computation:
    # w(x, y) :=
    #    let l = minimum length of all paths x -> y
    #    let P = { p : path x -> y | length(p) = l }
    #    return (0.95^l / |P|) * Sum_{i=1}^{|P|} Product_{j=1}^l (P_i)_j
    # Then W(x) = { (y, w(x, y)) | w(x, y) > 0.05 }
    weights = {}
    queue_cur = {}
    queue_cur[star] = [1.0]
    queue_next = {}
    while Object.keys(queue_cur).length
        # Do something here?
        for y, P of queue_cur
            w = (P.reduce (a, b) -> a+b) / P.length
            weights[y] = w
            if Math.abs(w) <= MIN_WEIGHT
                continue

            Object.values(bus.fetch "votes_by/#{y}")
                .forEach (v) ->
                    unless v.target?
                        return false
                    t = unslash v.target
                    unless (t.startsWith "user") and (t not of weights) and (t not of queue_cur)
                        return false
                    # Put a subscription on the individual vote
                    if t not of queue_next
                        queue_next[t] = []
                        bus.fetch v
                    queue_next[t].push (2 * v.value - 1) * w * NETWORK_ATT
        # We've processed all nodes at depth n. Now we'll swap our buffers and process the next depth.
        queue_cur = queue_next
        queue_next = {}
    weights

bus('votes_by/*').to_fetch = (star, t) ->
    key = "votes_by/#{star}"
    cur = bus.cache[key]
    if cur?
        return cur
    # Put a vote on the default user
    cur = {
        key: key
        "user/default": {
            key: "votes/_#{star}_user/default_"
            updated: 0
            user: "/#{star}"
            target: "/user/default"
            value: 1.0
        }
    }
    bus.save.sync cur
    return cur

bus('weights/*').to_save = (star, t) ->
    t.abort()

# TODO: People should be able to create feeds
bus('feeds').to_fetch = () ->
    users = bus.fetch('users').all
    tags = (bus.fetch("tags").tags || [])

    feeds = users.map((u) => {_key: u.key, name: u.name, type: "user"})
                 .concat tags.map (t) => {_key: t, name: t, type: "tag"}
    return
        key: "feeds"
        all: feeds

###### Sending static content over HTTP ##############
express = require 'express'
send_file = (f) -> (r, res) -> res.sendFile(__dirname + f)
bus.http.use('/*', (req, res, next) ->
  if /.*html.*/.test(req.headers.accept)
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

