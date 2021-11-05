dom.NETWORK = ->
    c = fetch '/current_user'
    unless c.logged_in
        return DIV "Log in to vote on users!"
    # We need an "initial weights" and an "extended weights"
    weights = compute_weights c.user.key
    DIV
        display: "flex"
        DIV "Slidergram goes here"
