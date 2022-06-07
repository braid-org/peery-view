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

    weights = fetch "/weights#{me}"
    # Add tagged votes, which aren't seen in the weights
    if tag
        tagged_votes = fetch "/votes_by#{me}/#{unslash tag}"
        (Object.entries tagged_votes).filter( ([k, v]) => (unslash k).startsWith "user")
                                     .forEach ([k, v]) =>
                                         fetch v
                                         weights[unslash k] = (2 * v.value) - 1

    if loading()
        return posts

    now = Date.now() / 1000
    
    scores = {}
    was_tagged = {}
    posts.forEach (p) ->
        if tag?.length
            if (unslash tag) in (p.tags || [])
                was_tagged[p.key] = true
            else
                return
        # Subscribe to the post
        p = fetch p

        sum_votes = 0
        sum_weights = 0

        # Subscribe to the post's votes
        votes = (fetch "/votes_on#{p.key}#{tag || ''}").values ? []
        votes.forEach (v) ->
            # first subscribe to the vote
            if v.key then fetch v
            voter = unslash v.user
            # Keep track of the total weight of votes, and of the weighted sum of votes.
            sum_weights += Math.abs(weights[voter] ? 0)
            sum_votes   += (2 * v.value - 1) * (weights[voter] ? 0)

        # Our network-weight on the author
        author_weight = weights[unslash p.user] ? 0

        scores[p.key] = compute_score
            age: now - p.time
            author: author_weight
            score: sum_votes
            volume: sum_weights

    # Should we save scores and weights to the local state?

    # Filter posts:              based on the minimum score       or we made this posts           only show posts with the selected tag
    posts = posts.filter (v) -> (scores[v.key] > min_weight or slash(v.user) == me) and (!tag?.length or was_tagged[v.key])
    # Filter before sorting!!
    posts.sort (a, b) -> scores[b.key] - scores[a.key]
    posts
    

make_post = (title, url, userkey) ->
    get_id = () -> "/post/" + Math.random().toString(36)
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
        user: userkey
        title: title
        url: url
        time: Math.floor (Date.now() / 1000)
        tags: if v?.selected?.type == "tag" then [unslash v.selected._key]

    save post


delete_post = (key_or_post) ->
    key = key_or_post?.key ? key_or_post
    # Deletion is serverside, so no need to check perms here.
    save {key: key}
