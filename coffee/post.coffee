att_curve = (delta) ->
    xs = delta / (60*60*24*3)
    1 / (xs*xs + 1)

sort_posts = (posts) ->

    c = fetch "/current_user"
    me = if c.logged_in then c.user.key else "/user/default"
    weights = fetch "/weights#{me}"

    now = Date.now() / 1000
    
    scores = {}
    posts.forEach (p) ->
        # time-based attenuation
        att = att_curve (now - p.time)
        # author weight
        user_weight = weights[unslash p.user]?.weight ? 1.0 # PLACEHOLDER 1.0, maybe should be 0 instead?
        sum_votes = 0.1

        votes = (fetch "/votes_on#{p.key}").values ? []
        if votes.length
            # weighted sum of votes.
            # double check this part.
            sum_votes = votes
                .map (v) -> v.value * (weights[unslash v.user] ? 0)
                .reduce (a, b) -> a + b

        scores[p.key] = att * user_weight * sum_votes

    # Should we save scores and weights to the local state?

    posts.sort (a, b) -> scores[b.key] - scores[a.key]
    posts

MIN_WEIGHT = 0.05
NETWORK_ATT = 0.95


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

    all_posts = fetch "/posts"
    all_posts.all ?= []
    all_posts.all.push post
    save all_posts

    # Do we need to forget the things we fetched?
