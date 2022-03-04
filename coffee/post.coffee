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
        # Subscribe to the post
        fetch p
        # time-based attenuation
        att = att_curve (now - p.time)
        # author weight
        # Naively multiplying by the author weight causes problems:
        # Negative author weight times negative votes = ... positive score ???
        # Also, if a post by an unknown user is rated very highly in your network, you won't see it at all.
        
        # We consider the author to have an implicit vote on their own post.
        # We'll just add this one to the votes.
        author_vote = weights[unslash p.user]?.weight ? 0.0
        # As for the multiplicative factor, we compute it as follows
        author_weight = Math.sqrt((author_vote + 1) / 2)

        sum_votes = 0.05

        votes = (fetch "/votes_on#{p.key}").values ? []
        if votes.length
            # weighted sum of votes.
            # double check this part.
            sum_votes = votes
                .map (v) ->
                    # first subscribe to the vote
                    if v.key then fetch v
                    (2 * v.value - 1) * (weights[unslash v.user] ? 0)
                .reduce (a, b) -> a + b

        scores[p.key] = att * author_weight * (sum_votes + author_vote)

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


delete_post = (key_or_post) ->
    key = key_or_post?.key ? key_or_post
    # Deletion is serverside, so no need to check perms here.
    save {key: key}
