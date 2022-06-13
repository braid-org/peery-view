att_curve = (delta) ->
    xs = delta / (60*60*24*30)
    Math.max(1 / (xs*xs + 1), 0.1)

compute_score = (p) ->
    sqsc = (Math.sqrt Math.abs p.score) * (if p.score > 0 then 1 else -1)
    att = att_curve p.age
    sqsc + att + att * (sqsc + p.author)
    

sort_posts = (posts, user, tag) ->
    c = fetch "/current_user"
    # The user whose perspective we should be sorting from
    me = slash (user ? c.user?.key ? "/user/default")
    min_weight = (if c.logged_in then (fetch c.user)?.filter) ? -0.2

    weights = fetch "weights/#{unslash me}#{stringify_kson {tag}}"
    ###
    # Add tagged votes, which aren't seen in the weights
    if tag
        tagged_votes = fetch "/votes_by#{me}/#{unslash tag}"
        (Object.entries tagged_votes).filter( ([k, v]) => (unslash k).startsWith "user")
                                     .forEach ([k, v]) =>
                                         fetch v
                                         weights[unslash k] = (2 * v.value) - 1
    ###
        
    if loading()
        return posts

    now = Date.now() / 1000

    kson = stringify_kson tag: tag, untagged: !tag
    
    scores = {}
    posts.forEach (p) ->
        # Subscribe to the post
        p = fetch p

        sum_votes = 0
        sum_weights = 0

        # Subscribe to the post's votes
        (fetch "/votes/#{unslash p.key}#{kson}")?.arr?.forEach (v) ->
            # first subscribe to the vote
            if v.key then fetch v
            voter = v.user_key
            # Keep track of the total weight of votes, and of the weighted sum of votes.
            sum_weights += Math.abs(weights[voter] ? 0)
            sum_votes   += (2 * v.value - 1) * (weights[voter] ? 0)

        # Our network-weight on the author
        author_weight = weights[p.user_key] ? 0

        scores[p.key] = compute_score
            age: now - p.time
            author: author_weight
            score: sum_votes
            volume: sum_weights

    # Should we save scores and weights to the local state? 
    # ^ past me, that probably wouldn't do anything!

    # Filter posts:              based on the minimum score       or we made this post
    posts.filter (v) -> (scores[v.key] > min_weight or v.user == me)
    # Filter before sorting!!
        .sort (a, b) -> scores[b.key] - scores[a.key]
    

make_post = (title, url, userkey) ->
    get_id = () -> "/post/" + Math.random().toString(36).substr(2)
    id = get_id()
    ###
    # Check for ID collision -- usually this won't happen
    while Object.keys(fetch id).length > 1
        # If we picked an ID that already exists, just forget it and make a new one
        forget id
        id = get_id()
    ###
    v = fetch "view"
    post =
        key: id
        user_key: userkey
        title: title
        url: url
        time: Math.floor (Date.now() / 1000)
        tags: if v.tag then [v.tag]

    save post


delete_post = (key_or_post) ->
    key = key_or_post?.key ? key_or_post
    # Deletion is serverside, so no need to check perms here.
    save {key: key}
