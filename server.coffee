require 'coffeescript/register'
parse = require('./coffee/parser.coffee')

######### Clientwise handlers ##########
# on the to_fetch and to_save handlers:
bus = require('statebus').serve
    port: 1312
    client: (client, server) ->
        parser = parse.PPPParser client

        parser('post/<postid>').to_save = (key, val, old, t) ->
            {postid} = t._path
            c = client.fetch "current_user"
            # So there's a few cases here. 
            # 1. A client is making a new post
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

                bus.save.sync val                
                # Ok, put it into the posts list
                all_posts = bus.fetch "posts"
                (all_posts.arr ?= []).push val
                bus.save all_posts
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

        parser('post/<postid>').to_delete = (key, old, t) ->
            {postid} = t._path
            c = client.fetch "current_user"
            all_posts = bus.fetch "posts"

            unless c.logged_in and c.user.key == old.user_key
                return t.abort()
            # We need to do six things.
            # 1. Remove the post from `posts`.
            # 2. Delete `votes/post/<id>`.
            # 3. Remove the post from `user/<uid>/votes` for everyone who's voted on it.
            # 4. Delete the votes themselves.
            # 5. Delete all the comments.
            # 6. Delete the actual post.
            
            
            # Fetch the votes and make a static copy
            votes = JSON.parse(JSON.stringify(bus.fetch "votes/post/#{postid}")).arr ? []
            voters = votes.map (o) -> o.user_key
            voters = voters.filter (u, i) -> i == voters.indexOf u

            # Remove the post from `posts`
            all_posts.arr = all_posts.arr.filter (p) -> p.key != key
            bus.save all_posts

            # Delete `votes/...`
            bus.delete "votes/post/#{postid}"
            
            # Remove from `<user>/votes`
            voters.forEach (u) ->
                votes_by = bus.fetch "#{u}/votes"
                votes_by.arr = votes_by.arr?.filter (v) -> v.target_key != key
                bus.save votes_by

            # Delete all the individual votes
            votes.forEach (v) -> bus.delete v.key

            # Delete the comments
            comments = JSON.parse(JSON.stringify(bus.fetch "post/#{postid}/comments")).arr ? []
            bus.delete "post/#{postid}/comments"
            comments.forEach (c) -> bus.delete c.key
                            
            # Finally delete the actual post
            bus.delete key

        parser('post/<postid>/comment/<commentid>').to_delete = (key, old, t) ->
            {postid, commentid} = t._path
            c = client.fetch "current_user"
            # Make sure that the user has the right to delete
            unless c.logged_in and c.user.key == old.user_key
                return t.abort()
            # Remove the comment from the relevant array
            comments = bus.fetch "post/#{postid}/comments"
            comments.arr = (comments.arr ? []).filter (c) -> c.key != key
            bus.save.sync comments

            # Now delete the key on the main bus
            bus.delete key

            # Hmm, what about if the comment has replies?


        parser('post/<postid>/comment/<commentid>').to_save = (key, val, old, t) ->
            {postid, _} = t._path
            post_key = "post/#{postid}"
            post = bus.fetch post_key

            c = client.fetch "current_user"
            # Check that user has the right to change the key
            unless c.logged_in and c.user.key == val.user_key
                return t.abort()
            # Check that the key matches the contents
            unless post_key == val.post_key
                return t.abort()
            # Check that the comment has a non-empty body
            unless val?.body?.length
                return t.abort()
            # Check that the comment has a submission time
            unless val.time
                return t.abort()
            # Alright, looks good.

            # Is this an old comment being edited?
            if old?.user_key
                # Make sure the user isn't like, stealing someone else's comment
                unless val.user_key == old.user_key
                    return t.abort()
                # Make sure the user hasn't changed the chaining
                unless val.parent_key == old.parent_key
                    return t.abort()
                # Make sure the user hasn't changed the submission time
                unless val.time == old.time
                    return t.abort()
                # Alright, the edit was fine.
                bus.save val
            # Ok, this a new comment
            else
                bus.save.sync val
                # Put it in the relevant array.
                post_comments = bus.fetch "post/#{postid}/comments"
                (post_comments.arr ?= []).push val
                bus.save post_comments

            t.done val


        parser('post/<postid>/comments').to_save = (t) ->
            t.abort()

        parser('user/<userid>/votes').to_save = (t) ->
            t.abort()

        parser('user/<userid>/votes/<type>').to_save = (t) ->
            t.abort()

        parser('votes/<type>/<target>').to_save = (t) ->
            t.abort()

        # If an individual vote is saved, put it in the arrays if necessary.
        parser('user/<userid>/vote/<type>/<targetid>').to_save = (key, val, old, t) ->
            {userid, type, targetid} = t._path
            {computed, tag} = t._params
            user = "user/#{userid}"
            target = "#{type}/#{targetid}"

            # Permission and integrity checking
            c = client.fetch "current_user"
            unless type == "user" or type == "post"
                return t.abort()
            # Check that user has the right to change the key
            unless c.logged_in and c.user.key == user == val.user_key
                return t.abort()
            # Check that the key matches the contents
            unless target == val.target_key
                return t.abort()
            # Check that the vote has an associated value between 0 and 1
            unless 0 <= val.value <= 1
                return t.abort()
            # Check that the tag is right
            if tag != val.tag
                return t.abort()
            # Don't bother trying to save a computed vote
            if computed == true
                return t.abort()
            # Alright, looks good.
           
            # User votes should be given depth 1
            if type == "user"
                val.depth = 1
            bus.save.sync val

            # Is this a new vote?
            unless old.user_key?
                # Put this vote into the necessary arrays.
                # We only put it into the untagged arrays -- the tagged (ie, filtered) views of these arrays are computed automatically
                ["#{user}/votes", "votes/#{target}"].forEach (k) ->
                    s = bus.fetch k
                    (s.arr ?= []).push val
                    bus.save.sync s

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
            
            t.done val

        parser('user/<userid>').to_save = (key, val, old, t) ->
            # The client can't change their join date
            unless old.joined == val.joined
                return t.abort()
            unless old.border == val.border
                return t.abort()
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
    {computed, tag, untagged} = t._params
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
        votes = {}
        depth = 0
        queue_cur = {}
        queue_cur[userkey] = [1.0]
        queue_next = {}
        while Object.keys(queue_cur).length and depth < 5
            for target, paths of queue_cur

                vote_computed = depth != 1
                vote_key =  "#{userkey}/vote/#{target}#{parse.stringify_kson {computed: vote_computed, tag}}"

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
                        tag: tag

                if Math.abs(w) <= MIN_WEIGHT
                    continue

                bus.fetch "#{target}/votes/people#{parse.stringify_kson {tag, untagged}}"
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
            queue_cur = queue_next
            queue_next = {}
            if ++depth >= 5
                break
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
                unless v.target_key.startsWith prefix
                    return false
                bus.fetch v

                (tag and tag == v.tag) or (untagged and not v.tag) or not (untagged or tag)
        }
# Here's a bunch of boring filtering code...    
bus_parser('votes/<type>/<targetid>').to_fetch = (key, t) ->
    {type, targetid} = t._path
    {computed, tag, untagged} = t._params
    if tag or untagged
        # Fetching here instead of accessing cache makes us reactive
        all_votes = (bus.fetch "votes/#{type}/#{targetid}").arr ? []
        {
            key: key
            arr: all_votes.filter (v) ->
                bus.fetch v
                (tag and tag == v.tag) or (untagged and not v.tag?)
        }
    else
        default_arr key

bus_parser('user/<username>/votes').to_fetch = (key, t) ->
    {username} = t._path
    {computed, tag, untagged} = t._params
    if tag or untagged
        # Fetching here instead of accessing cache makes us reactive
        all_votes = bus.fetch "user/#{username}/votes"
        {
            key: key
            arr: all_votes.arr.filter (v) =>
                bus.fetch v
                (tag and tag == v.tag) or (untagged and not v.tag?)
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
            {
                raw...
                key: key
            }
        else
            # Call into the weights computation
            # The weights computation outputs an array that contains (ie, modifies) the state we're currently to_fetch'ing...
            # Is there weird statebus magic we have to do?
            wot = bus.fetch "user/#{username}/votes/people#{parse.stringify_kson t._params}"
            for vote in wot.arr
                if vote.key == key
                    return vote
            return { key: key }

    else
        bus.cache[key] ?= {key: key}


bus_parser('user/<username>/posts').to_fetch = (key, t) ->
    {username} = t._path
    {computed, tag, untagged} = t._params
    all_posts = bus.fetch "posts"
    userkey = "user/#{username}"
    {
        key: key
        arr: all_posts.arr.filter (p) ->
            unless userkey == p.user_key
                return false
            bus.fetch p
            (tag and tag in p.tags) or (untagged and not p.tags.length) or not (untagged or tag)
                
    }

bus_parser('posts').to_fetch = (key, t) ->
    {computed, tag, untagged} = t._params
    if tag or untagged
        all_posts = bus.fetch "posts"
        {
            key: key
            arr: all_posts.arr.filter (p) ->
                bus.fetch p
                (tag and tag in (p.tags ? [])) or (untagged and not p?.tags?.length)
        }
    else
        default_arr key

bus('tags').to_fetch = (key) -> default_arr key

fs = require 'fs'
https = require 'https'
sharp = require 'sharp'

validate_pic = (key, url, cb) ->
    # Function to call if we run into an error trying to fetch the image
    error = (e) -> 
        if (e)
            console.error e
        cb exists: no, white: no
    # First grab the image
    try 
        fs.mkdirSync ".cache", recursive: true
        req = https.get url, (res) ->
            {statusCode} = res
            contentType = res.headers['content-type']?.toLowerCase?()
            unless (statusCode == 200) and contentType?.startsWith?("image/")
                res.resume()
                # 404 or image isn't an image
                error()
                return
            
            fp = ".cache/#{key.replaceAll '/', '_'}"
            res.pipe fs.createWriteStream fp
                .on 'error', error
                .once 'close', () -> 
                    # Use sharp to process the image
                    buf = await sharp fp
                        .flatten background: 'white'
                        .toColorspace 'b-w'
                        .resize 32, 32
                        .raw()
                        .toBuffer()
                    # data is a flattened 32,32 buffer giving the bw lightness
                    # We want to determine the average brightness along the largest inscribed circle
                    # Since the image has already been shrunk, we can just sample a set of single pixels.
                    total_brightness = 0
                    [0...32].forEach (i) ->
                        rad = 2 * Math.PI * i / 32
                        x = Math.floor(15.5 + 15 * Math.cos rad)
                        y = Math.floor(15.5 + 15 * Math.sin rad)
                        
                        ind = y * 32 + x
                        total_brightness += buf[ind]
                    total_brightness /= 32
                    is_white = total_brightness >= 230
                    cb exists: yes, white: is_white

        # Typically if url is a valid URL but there's no server there
        req.on 'error', error

    catch e
        # Invalid url
        error(e)
        


bus_parser('user/<userid>').to_save = (key, val, old, t) ->
    unless old.joined
        val.joined = Date.now()

    # Check to see if the profile picture is white around the edges, or 404s
    if val.pic and val.pic != old.pic
        validate_pic key, val.pic, (pic_results) =>
            unless pic_results.exists
                delete val.pic
            val.border = pic_results.white

            bus.save.fire val
            t.done val
    else
        bus.save.fire val
        t.done val


migrate = (state) ->
    m = state.fetch "migrations"
    unless m.june13
        console.log "MIGRATION J13: June 13th New Standard"
        console.log "MIGRATION J13: Consider making a manual backup of the database..."

        # in `posts` and `tags`: the array should be key.arr instead of key.all or key.tags
        console.log "MIGRATION J13: Storing arrays on `key.arr`."
        state.save.sync 
            key: "tags"
            arr: (state.fetch "tags").tags ? []
        state.save.sync
            key: "posts"
            arr: (state.fetch "posts").all ? []

        # each post need to have user replaced by user_key.
        console.log "MIGRATION J13: Changing `user` field to `user_key` on all posts."
        Object.keys state.cache
            .filter (k) -> k.startsWith "post"
            .forEach (k) ->
                p = state.fetch k
                p.user_key = parse.unslash p.user
                delete p.user
                state.save.sync p

        # Delete all votes_on keys
        console.log "MIGRATION J13: Deleting `votes_on` arrays."
        Object.keys state.cache
            .filter (k) -> k.startsWith "votes_on"
            .forEach (k) -> state.delete k
        
        # Now find all keys that match votes_by/user/<userid>/<tag> and votes_by/user/<userid>
        # These things are objects with key value pairs representing (key, vote).
        # Each of these votes should be moved to a new key, should have user_key replaced by target_key, should have depth=1 added
        # NOTE: a vote on the default user with value 1 should just be deleted.
        console.log "MIGRATION J13: Reformatting votes."
        Object.keys state.cache
            .filter (k) -> k.startsWith "votes_by/user/"
            .forEach (k) ->
                userid = k.substr 14
                kson_blob = ""

                slash_ind = userid.indexOf "/"
                # Figure out if these are tagged or untagged votes
                if slash_ind != -1
                    tag = userid[1 + slash_ind..]
                    userid = userid[...slash_ind]
                    kson_blob = "(tag:#{tag})"

                # The new key where the votes will be stored
                votes_new = state.fetch "user/#{userid}/votes"
                votes_new.arr ?= []
                # Fetch the current list of votes and iterate over it
                votes_old = state.fetch k
                Object.values votes_old
                    .filter (v) -> v.key? and v.user? and v.target?
                    .forEach (v) ->
                        new_vote = 
                            key: "user/#{userid}/vote/#{parse.unslash v.target}#{kson_blob}"
                            user_key: "user/#{userid}"
                            target_key: parse.unslash v.target
                            value: v.value
                            updated: v.updated
                            depth: 1
                            tag: tag
                        state.save.sync new_vote
                        # Delete the original vote
                        state.delete v

                        # Put it in the array for the target
                        target_votes = state.fetch "votes/#{new_vote.target_key}"
                        (target_votes.arr ?= []).push new_vote
                        state.save.sync target_votes 

                        # Put it in the array for the user
                        votes_new.arr.push new_vote

                state.save.sync votes_new
                state.delete votes_old

        # Trim the DB by cleaning up cached weights objects.
        console.log "MIGRATION J13: Cleaning up cached WoT."
        Object.keys state.cache
            .filter (k) -> k.startsWith "weights"
            .forEach (k) -> state.delete k

        console.log "MIGRATION J13: Migration complete."
        m.june13 = true
        state.save m

    unless m.joindate
        console.log "MIGRATION UJD: User Join Date."
        console.log "MIGRATION UJD: Inferring user join order from their position in user array."
        users = state.fetch "users"
        users.all.forEach (v, i) ->
            unless v.joined
                v.joined = i * 5000 + 1500000000000
                state.save.fire v
        console.log "MIGRATION UJD: Migration complete."
        m.joindate = true
        state.save m

    unless m.picborder
        console.log "MIGRATION WPP: White Profile Pictures."
        console.log "MIGRATION WPP: Analyzing all current profile pictures."
        users = state.fetch "users"
        users.all.forEach (v, i) ->
            if v.pic
                validate_pic v.key, v.pic, (pic_results) =>
                    unless pic_results.exists
                        delete v.pic
                    v.border = pic_results.white

                    state.save.fire v
        console.log "MIGRATION WPP: Migration complete."
        m.picborder = true
        state.save m


migrate bus


###### Sending static content over HTTP ##############
express = require 'express'
send_file = (f) -> (r, res) -> res.sendFile(__dirname + f)
bus.http.use '/about', send_file '/static/about.html'
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
        JSON.stringify o.arr
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

