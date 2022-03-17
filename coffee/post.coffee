att_curve = (delta) ->
    xs = delta / (60*60*24*3)
    Math.max(1 / (xs*xs + 1), 0.1)

compute_score = (p) ->
    att = if p.score > 0 then att_curve p.age else 1
    (p.score * att) + ((p.me ? 0) + p.author) * Math.sqrt(att)
    

sort_posts = (posts) ->

    c = fetch "/current_user"
    me = if c.logged_in then c.user.key else "/user/default"
    min_weight = fetch( c?.user )?.filter ? -0.2
    weights = fetch "/weights#{me}"

    now = Date.now() / 1000
    
    scores = {}
    posts.forEach (p) ->
        # Subscribe to the post
        fetch p
        # Subscribe to the post's votes
        votes = (fetch "/votes_on#{p.key}").values ? []
        authorname = unslash p.user

        my_vote = null
        sum_votes = 0

        if votes.length
            # weighted sum of votes.
            sum_votes = votes
                .map (v) ->
                    # first subscribe to the vote
                    if v.key then fetch v

                    # The following might seem to not handle the case where we made this post. 
                    # But choosing to consider such a vote as "our vote" instead of "the author's vote" allows the user some control over the order they see their own posts in.

                    # Exclude our own vote on the post.
                    # The scoring function has separate access to this.
                    voter = unslash v.user
                    if voter == unslash me
                        my_vote = 2 * v.value - 1
                        0
                    # Completely ignore the author's vote on their own post
                    else if voter == authorname
                        0
                    else
                        (2 * v.value - 1) * (weights[voter] ? 0)
                .reduce (a, b) -> a + b

        # Our network-weight on the author
        author_weight = weights[authorname]?.weight ? 0

        scores[p.key] = compute_score
            age: now - p.time
            author: author_weight
            score: sum_votes
            # Maybe we should have sum_weights instead??
            votes: votes.length
            me: my_vote

    # Should we save scores and weights to the local state?

    posts.sort (a, b) -> scores[b.key] - scores[a.key]
    posts.filter (v) ->
        scores[v.key] > min_weight

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
