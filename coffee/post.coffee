att = (delta) ->
    xs = delta / (60*60*24*3)
    1 / (xs*xs + 1)

sort_posts = (posts, weights) ->
    # We have what each user has voted on each post, and what we rate each user.
    # And an exponential time decay
    now = Date.now() / 1000
    # Placeholder: just sort according to exponential decay (ie, time)
    posts.forEach (p) ->
        p.att = att now - p.time
        # get sum of weights
        votes = (fetch "/votes_on#{p.key}").all ? []
        p.total = p.att * votes.map((v) -> v.weight * weights[v.user])
            .reduce (a, b) -> a+b

    posts.sort (a, b) -> b.total - a.total
    posts

MIN_WEIGHT = 0.05
NETWORK_ATT = 0.95

compute_weights = (user, initial_weights) ->
    # Problems with this approach:
    # 1.   You have to make a bunch of fetches.
    #      That means that there should be a server call you can make to get this data.
    #      It's true that the server has to do the same thing, but there'll be less latency for the vote calls.
    # 2.   Only the first time a user is reached in the graph is counted.
    #      This means that the result is not necessarily the expected one.
    #      A way to improve the results is to have a priority queue by weight instead of a simple breadth-first search
    # 2.5. But there is no O(V+E) algorithm to compute the theoretical result (ie, sum-weight), since the best known matrix multiplication algorithsms are about O(V^2.4) (ie, O(V^2.4) > O(V^2) >= O(E)). Moreover, we actually have to iterate the matrix multiplication a bunch of times. 
    # 2.6. An amortized server-side algorithm might be a solution.
    extended_weights = {}
    queue = Object.entries initial_weights
    while queue.length
        [uid, base_weight] = queue.shift()
        extended_weights[uid] = base_weight
        if base_weight < MIN_WEIGHT
            continue
        for vote in (fetch "/votes_on_users#{uid}").all ? []
            unless vote.target of extended_weights or vote.target is user
                queue.push [vote.target, vote.weight * base_weight * NETWORK_ATT]
    extended_weights
    

dom.RENDER_POST = (post, user) ->
    DIV {},
        post.user
        post.title

