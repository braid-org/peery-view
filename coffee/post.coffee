att_curve = (delta) ->
    xs = delta / (60*60*24*30)
    Math.max(1 / (xs*xs + 1), 0.1)

compute_score = (p) ->
    # compute the hot score
    sqsc = (Math.sqrt Math.abs p.score) * (if p.score > 0 then 1 else -1)
    att = att_curve p.age
    {
        hot: sqsc + att + att * (sqsc + p.author)
        score: p.score + p.author
    }

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
