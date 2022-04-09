att_curve = (delta) ->
    xs = delta / (60*60*24*30)
    Math.max(1 / (xs*xs + 1), 0.1)

compute_score = (p) ->
    sqsc = (Math.sqrt Math.abs p.score) * (if p.score > 0 then 1 else -1)
    att = att_curve p.age
    sqsc + att + att * (sqsc + p.author)
    

sort_posts = (posts) ->
    c = fetch "/current_user"
    me = if c.logged_in then c.user.key else "/user/default"
    min_weight = (if c.logged_in then (fetch c.user)?.filter) ? -0.2
    weights = fetch "/weights#{me}"

    now = Date.now() / 1000
    
    scores = {}
    posts.forEach (p) ->
        # Subscribe to the post
        p = fetch p

        sum_votes = 0
        sum_weights = 0

        # Subscribe to the post's votes
        votes = (fetch "/votes_on#{p.key}").values ? []
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

    posts.sort (a, b) -> scores[b.key] - scores[a.key]
    posts.filter (v) ->
        scores[v.key] > min_weight or slash(v.user) == me

make_post = (title, url, userkey) ->
    get_id = () -> "/post/" + Math.random().toString(36).substr(2, 10)
    id = get_id()
    # Check for ID collision -- usually this won't happen
    while Object.keys(fetch id).length > 1
        # If we picked an ID that already exists, just forget it and make a new one
        forget id
        id = get_id()

    post =
        key: id
        user: userkey
        title: title
        url: url
        time: Math.floor (Date.now() / 1000)

    save post


delete_post = (key_or_post) ->
    key = key_or_post?.key ? key_or_post
    # Deletion is serverside, so no need to check perms here.
    save {key: key}
