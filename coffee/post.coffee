compute_score = (p) ->
    # Computes an interpolated sorting key for posts
    # Inputs:
    #  p = {score, author, age, volume, t}
    #  t in [0, 1] is the interpolation parameter
    #  t = 0 means sort by new
    #  t = 1 means sort by top score
    #  t in between adjusts the relative importance of age and score
    t = p.t
    switch
        when t < 0.02 then 1 / Math.log(p.age)
        when t > 0.98 then p.score
        else
            # Interpolate between new and top score
            decay_score = t
            decay_age = Math.pow(1 - t, 2)
            (1 + p.score * decay_score) / (1 + Math.log(p.age) * decay_age)



make_post = (props) ->
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
        user_key: props.user_key ? props.user
        title: props.title
        url: props.url
        body: props.body
        parent_key: props.parent_key ? props.parent
        time: Math.floor (Date.now() / 1000)
        tags: if v.tag then [v.tag]

    save post


delete_post = (key_or_post) ->
    key = key_or_post?.key ? key_or_post
    # Deletion is serverside, so no need to check perms here.
    save {key: key}
