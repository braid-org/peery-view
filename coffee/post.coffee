compute_score = (t, p) ->
    # Computes an interpolated sorting key for posts
    # Inputs:
    #  p = {score, author, age, volume}

    #  t in [0, 1] is the interpolation parameter
    #  t = 0 means sort by new
    #  t = 1 means sort by top score
    #  t in between adjusts the relative importance of age and score
    theta = t * Math.PI / 2
    # We add a constant to the age to reduce the impact on very very new posts
    Math.sin(theta) * p.score - Math.cos(theta) * Math.log(1 + p.age / 3600)


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

# Set up the path parser for some local state
parser = PPPParser bus
# Weights calculation
parser("weights/user/<userid>").to_fetch = (key, t) ->
    {userid} = t._path
    {tag, untagged} = t._params
    blob = stringify_kson {computed: true, tag: tag, untagged}

    votes = fetch "/user/#{userid}/votes/people#{blob}"
    weights_ret = {key: key}
    (votes.arr ? []).forEach (v) ->
        fetch v
        weights_ret[v.target_key] = 2 * v.value - 1


    if tag
        ((fetch "/user/#{userid}/votes/people(computed,untagged)").arr ? []).forEach (v) ->
            unless weights_ret[v.target_key]?
                fetch v
                weights_ret[v.target_key] = 2 * v.value - 1

    weights_ret

# post score calculation
parser("score/post/<postid>").to_fetch = (key, t) ->
    {postid} = t._path
    {user, tag} = t._params

    user ?= "/user/default"

    weights = fetch "weights/#{unslash user}#{stringify_kson {tag}}"
        
    now = Date.now() / 1000

    kson = stringify_kson
        tag: tag
        untagged: !tag

    #// Subscribe to the post
    p = fetch "/post/#{postid}"

    sum_votes = 0
    sum_weights = 0

    #// Subscribe to the post's votes
    (fetch "/votes/#{unslash p.key}#{kson}")?.arr?.forEach (v) ->
        # first subscribe to the vote
        if v.key then fetch v
        voter = v.user_key
        # Keep track of the total weight of votes, and of the weighted sum of votes.
        sum_weights += Math.abs(weights[voter] ? 0)
        sum_votes   += (2 * v.value - 1) * (weights[voter] ? 0)

    #// Our network-weight on the author
    author_weight = weights[p.user_key] ? 0


    p =
        age: now - p.time
        author: author_weight
        score: sum_votes
        volume: sum_weights

    {
        key: key
        sort_top: compute_score 1, p
        sort_new: compute_score 0.2, p
        filter: sum_votes
    }


# chat block layout calculation
parser("post_layout").to_fetch = (key, t) ->
    kson = stringify_kson t._params
    {user, tag} = t._params

    posts = fetch "/posts"
    min_score = (fetch "filter")?.min ? -0.2

    # assemble posts into an array of trees
    # also mark which posts are good
    # and mark which are new
    children_of = root_top: [], root_new: []
    is_good = {}

    now = Date.now() / 1000
    two_weeks_ago = now - 60 * 60 * 24 * 14
    is_new = {}

    posts.arr?.forEach (post) ->
        parent = post.parent_key ? "root_top"
        (children_of[parent] ?= []).push post

        tag_filter = (!tag) or tag in (post.tags ? [])
        score_filter = (fetch "score#{post.key}#{kson}").filter > min_score
        is_good[post.key] = tag_filter and score_filter
        is_new[post.key] = post.time > two_weeks_ago

    # Now kidnap young children from their old parents >:)
    f_kidnap = (post) ->
        children_of[post.key] = children_of[post.key]?.filter (c) ->
            if is_new[c.key]
                children_of.root_new.push c
                return false
            else
                f_kidnap c
                true

    f_kidnap key: "root_top"

    # assemble trees of posts into trees of collapsed blocks, each of which is uniform in color
    blocks =
        root_top: {chain: null, context: null, end: 'root_top', children: []}
        root_new: {chain: null, context: null, end: 'root_new', children: []}
    f_chain = (post, block, parent) ->
        # we might have to start a new block
        block ?= chain: [], context: post.parent_key, children: [], good: is_good[post.key], skipped: 0
        block.chain.push post.key

        children = children_of[post.key] ? []
        # if we have exactly one child and its the same color, keep the block going
        if children.length == 1 and (is_good[children[0].key] == is_good[post.key])
            f_chain children[0], block, parent
        # otherwise, end the block and then tell all the children to start new blocks
        else
            # put the block in blocks, so that our children can find us
            block.end = post.key
            blocks[block.end] = block
            # children will need to start new blocks as children of the new parent
            # if any children have good descendents, or we are good, then so do we
            has_good_descendents = children
                    .map (c) -> f_chain c, null, block.end
                    .reduce ((a, b) -> a or b), block.good
            # trim completely bad branches by just not adding them
            if has_good_descendents
                # block.children should be populated with blocks that are good or have good descends
                # our entire subtree is maximally merged.
                # so now we need to merge/adopt children,
                # according to the following rules:
                # 1. if we have one child and its the same color, merge with it.
                if block.children.length == 1 and (is_good[block.children[0]] == block.good)
                    child = blocks[block.children[0]]
                    child.chain.unshift block.chain...
                    child.context = block.context
                    child.skipped = block.skipped # ?? not sure about this. probably always 0
                    delete blocks[block.end]
                    block = child
                    
                # 2. otherwise, if we have bad children, adopt their children and increment their skipped
                else
                    disown_bad_children block

                # 3. TODO: handle the "1 bad context" case?

                # done. attach to the parent
                blocks[parent].children.push block.end
        
            has_good_descendents

    # removes bad children and adopts any children of the disowned 
    disown_bad_children = (block) ->
        # avoid creating a new array here?
        new_children = []
        block.children
            .forEach (c) ->
                child = blocks[c]
                if child.good
                    new_children.push c
                else if child.children?.length
                    # add all children of the bad child to our children
                    # if all children have already called disown_bad_children,
                    # any grandchildren we find will be good.
                    new_children.push child.children...
                    child.children.forEach (gc) -> blocks[gc].skipped += child.chain.length
        block.children = new_children

    children_of.root_top.forEach (post) -> f_chain post, null, 'root_top'
    children_of.root_new.forEach (post) -> f_chain post, null, 'root_new'
    # root needs to adopt grandchildren
    disown_bad_children blocks.root_top
    disown_bad_children blocks.root_new

    block_scores = {}
    aggregate_score = (block, k) ->
        block_scores[block.end] ?= block.chain
            .map (c) -> (fetch "score#{c}#{kson}")[k]
            .reduce (a, b) -> Math.max a, b

    # flatten the blocks
    f_flatten = (block, level, out, k) ->
        block.level = level
        out.push block
        # sort the children to flatten in the right order
        block.children
            .map (c) -> blocks[c]
            .sort (a, b) -> (aggregate_score b, k) - aggregate_score a, k
            .forEach (c) -> f_flatten c, level + 1, out, k


    top_arr = []
    new_arr = []
    f_flatten blocks.root_top, -1, top_arr, "sort_top"
    f_flatten blocks.root_new, -1, new_arr, "sort_new"
    # the first element is root, which isn't real
    top_arr.shift()
    new_arr.shift()

    {
        key: key
        new: new_arr
        top: top_arr

    }

