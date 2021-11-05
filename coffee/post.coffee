att_curve = (delta) ->
    xs = delta / (60*60*24*3)
    1 / (xs*xs + 1)

sort_posts = (posts, weights) ->
    # We have what each user has voted on each post, and what we rate each user.
    # And an exponential time decay
    now = Date.now() / 1000

    vote_ids = (fetch "/votes").all ? []
    votes = {}
    vote_ids
        .filter (t) ->
            t.key.startsWith("/post")
        .forEach (t) ->
            v = fetch "/votes#{t.key}"
            votes[v.target] ?= []
            votes[v.target].push v
    
    scores = {}
    posts.forEach (p) ->
        # time-based attenuation
        att = att_curve (now - p.time)
        # author weight
        user_weight = weights[p.user]?.weight ? 1.0 # PLACEHOLDER 1.0
        sum_votes = 0.1
        if p.key in votes
            # weighted sum of votes.
            # double check this part.
            sum_votes = votes[p.key]
                .map((v) -> v.value * weights[v.user]?.weight ? 0)
                .reduce((a, b) -> a + b)

        scores[p.key] = att * user_weight * sum_votes

    # Should we save scores and weights to the local state?

    posts.sort (a, b) -> scores[b.key] - scores[a.key]
    posts

MIN_WEIGHT = 0.05
NETWORK_ATT = 0.95

compute_weights = (user) ->
    weights = {}
    vote_ids = (fetch "/votes").all ? []
    votes = {}
    vote_ids
        .filter (t) ->
            t.key.startsWith("/user")
        .forEach (t) ->
            v = fetch "/votes#{t.key}"
            votes[v.user] ?= []
            votes[v.user].push v

    queue = [[user, 1.0, 0]]
    while queue.length
        [uid, base_weight, d] = queue.shift()
        weights[uid] = {weight: base_weight, distance: d}
        if base_weight < MIN_WEIGHT
            continue
        (votes[uid] ? []).forEach (vote) ->
            unless vote.target of weights
                queue.push [vote.target, vote.value * base_weight * NETWORK_ATT, d+1]
    weights

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
        time: Math.floor(Date.now() / 1000)

    save post

    all_posts = fetch "/posts"
    all_posts.all ?= []
    all_posts.all.push post
    save all_posts

    # Do we need to forget the things we fetched?
