# TODO: These should be arguments for the relevant elements
# TODO: Should UI elements fetch global state or take arguments?
body_width = 800
margin_left = 40
post_width = 525
slider_width = body_width - 2*margin_left - post_width - 10

# The list of posts
dom.POSTS = ->
    c = fetch "/current_user"
    v = fetch "view"
    posts = (fetch "/posts#{stringify_kson tag: v.tag}").arr ? []

    username = v.user_key ? c?.user?.key ? "/user/default"
    min_weight = (if c.logged_in then (fetch c.user)?.filter) ? -0.2
    score_kson = stringify_kson tag: v.tag, user: username

    two_weeks_ago = (Date.now() / 1000) - 60 * 60 * 24 * 14
    # Recent posts with a positive score, sorted by time
    posts_recent = posts.filter (p) ->
            (p.time > two_weeks_ago) and 
            (fetch("score#{p.key}#{score_kson}").value ? 0) > 0.1 # TODO: Tune this
        .sort (a, b) -> b.time - a.time

    # Older posts, sorted by score
    posts_old = posts.filter (p) -> 
            (p.time <= two_weeks_ago) and 
            # Cut the list off at some point. TODO: Paging
            (fetch("score#{p.key}#{score_kson}").value ? 0) > min_weight
        .sort (a, b) -> (fetch("score#{b.key}#{score_kson}").value ? 0) - (fetch("score#{a.key}#{score_kson}").value ? 0)
    
    DIV
        key: "posts"
        posts_recent.map (post) ->
            POST
                post: post.key
                key: unslash post.key

        # If there were no recent posts, don't show the time separator
        if posts_recent.length
            DIV
                key: "sort-separator"
                display: "flex"
                flexDirection: "row"
                justifyContent: "stretch"
                alignItems: "center"

                DIV
                    key: "dummy1"
                    flexGrow: 1
                    height: 1.5
                    background: "#36a"
                    borderRadius: 1

                SPAN
                    key: "text"
                    color: "#36a"
                    margin: "0px 1ch"
                    "Two weeks ago"

                DIV
                    key: "dummy2"
                    flexGrow: 1
                    height: 1.5
                    background: "#36a"
                    borderRadius: 1

        posts_old.map (post) ->
            POST
                post: post.key
                key: unslash post.key

# The layout for a single post, including slidergram and such
dom.POST = ->
    post = @props.post
    # Subscribe to the post
    if post?.key or typeof post == "string" then post = fetch post
    unless post.user_key?
        # The post has actually just been deleted.
        return

    author = fetch post.user_key

    c = fetch '/current_user'
    v = fetch "view"

    # Compute the pretty version of the url
    url = if post.url.startsWith "javascript:" then "" else post.url

    pretty_url = url
    functional_url = url
    unless url.startsWith("https://") or url.startsWith("http://")
        functional_url = "https://" + functional_url
    try
        the_url = new URL functional_url
        the_url.protocol = "https://"
        functional_url = the_url.toString()
        pretty_url = the_url.host
    catch e 
        functional_url = ""
    
    time_string = prettyDate(post.time * 1000)
    user_clickable = c.logged_in and (c.user.key != author.key)

    DIV
        margin: "5px 0"
        padding: "5px 10px"
        boxShadow: if @local.expanded then "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"
        DIV
            key: "post-main"
            display: "grid"
            grid: "\"icon title slider more\" auto
                   \"icon domain_time slider more\" 16px
                    / #{margin_left}px #{post_width}px 1fr #{margin_left}px"
            alignItems: "center"

            AVATAR_WITH_SLIDER
                key: "avatar"
                user: author
                clickable: user_clickable
                width: margin_left - 10
                height: margin_left - 10
                style:
                    gridArea: "icon"
                    alignSelf: "center"

            A
                key: "title"
                className: "post-title"
                gridArea: "title"
                fontSize: "18px"
                paddingRight: "10px"
                lineHeight: "#{margin_left - 10}px"
                justifySelf: "stretch"
                textDecoration: "none"
                href: if functional_url.length then functional_url
                "#{post.title}"

            SPAN
                key: "url_time"
                gridArea: "domain_time"
                fontSize: "12px"
                color: "#999"
                whiteSpace: "nowrap"
                overflowX: "hidden"
                textOverflow: "ellipsis"
                "#{if @local.expanded then url else pretty_url} · #{time_string}"
           
            DIV
                key: "post-votes-slider"
                gridArea: "slider"
                alignSelf: "start"
                height: margin_left - 10
                if v.tag
                    SLIDERGRAM_WITH_TAG
                        key: "slidergram"
                        post: post
                        tag: unslash v.tag
                        width: slider_width
                        height: margin_left - 5
                        max_avatar_radius: (margin_left - 5) / 2
                        read_only: !c.logged_in
                else
                    SLIDERGRAM
                        key: "slidergram"
                        sldr: "/votes/#{unslash post.key}(untagged)"
                        width: slider_width
                        height: margin_left - 5
                        max_avatar_radius: (margin_left - 5) / 2
                        read_only: !c.logged_in
                        vote_key: "user_key"
                        onsave: (vote) =>
                            vote.key = "#{c.user.key}/vote/#{unslash post.key}"
                            vote.target_key = post.key
                            save vote

            SPAN
                key: "more"
                gridArea: "more"
                color: "#999"
                className: "material-icons md-dark"
                fontSize: "24px"
                cursor: "pointer"
                textAlign: "center"
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"

        if @local.expanded
            POST_DETAILS
                key: "details-dropdown"
                post: post

dom.POST_DETAILS = ->
    post = fetch @props.post
    c = fetch "/current_user"
    # Cache this?
    potential_tags = (fetch "/tags").arr.filter (f) -> f not in (post.tags || [])
    max_suggestions = @props.max_suggestions ? 4
    # Setup default values in @local
    @local.selected_idx ?= -1
    @local.tagsearch ?= []
    @local.typed ?= ""
    @local.addtagvisible ?= false
    save @local
    DIV
        padding: "10px #{margin_left/2}px"
        margin: "4px #{margin_left/2}px"
        display: "flex"
        flexDirection: "row"
        justifyContent: "space-between"
        alignContent: "stretch"

        
        if c?.user?.key == post?.user_key then SPAN
            key: "delete-btn"
            color: "#999"
            className: "material-icons md-dark"
            fontSize: "24px"
            cursor: "pointer"
            textAlign: "center"
            alignSelf: "center"
            onClick: () =>
                delete_post(post)
            "delete"
        
        DIV
            key: "add-tag"
            display: "grid"
            gridTemplateColumns: "1fr auto 1fr"
            gridAutoRows: "24px"
            width: "50%"
            alignSelf: "center"
            alignItems: "stretch"

            # Grid will look like this:
            # . SEARCHBOX  CONFIRM
            # . SUGGESTION .
            # . SUGGESTION .
            # .   ...      .
            SPAN key: "dummy"

            DIV
                key: "input-and-suggestions"
                INPUT
                    key: "textbox"
                    ref: "addlabel"
                    placeholder: "Relevant tag..."
                    display: unless @local.addtagvisible then "none"
                    width: slider_width
                    # Handle arrow keys, enter, etc
                    onKeyDown: (e) =>
                        switch e.keyCode
                            # Enter
                            when 13
                                e.preventDefault()
                            # Up/down
                            when 38, 40
                                e.preventDefault()
                                v = @refs.addlabel.getDOMNode()
                                # Up arrow is 38, down arrow is 40
                                di = e.keyCode - 39
                                # Increment or decrement the index
                                @local.selected_idx += di
                                switch @local.selected_idx
                                    # If we scrolled past the last one, or up from the 1st/0th, unselect
                                    when @local.tagsearch.length, -1, -2
                                        @local.selected_idx = -1
                                        v.value = @local.typed
                                    else
                                        # Otherwise, set the textbox value to the right name
                                        v.value = @local.tagsearch[@local.selected_idx]
                            # Tab 
                            when 9
                                e.preventDefault()
                        save @local
                    # Handle actual text entry
                    onInput: (e) =>
                        v = @refs.addlabel.getDOMNode().value.toString().toLowerCase()
                        @local.typed = v
                        @local.tagsearch = potential_tags.filter((t) => t.startsWith v)
                                                         .slice 0, max_suggestions
                        @local.selected_idx = -1
                        unless v.length then @local.tagsearch = []
                        save @local

                        
                SPAN
                    key: "textbox-replacement"
                    display: if @local.addtagvisible then "none"
                    color: "#999"
                    "Add Tag"

            SPAN
                key: "addbutton"
                color: "#999"
                className: "material-icons md-dark"
                fontSize: "24px"
                cursor: "pointer"
                marginLeft: 6
                onClick: () => 
                    box = @refs.addlabel.getDOMNode()
                    if @local.addtagvisible and box.value.length
                        post.tags ||= []
                        new_tag = box.value.toString().toLowerCase()
                        # Disable adding certain tags.
                        # In the future, we should make this check serverside so it can't be bypassed.
                        if new_tag.indexOf("/") == -1 and new_tag != "users"
                            post.tags.push new_tag
                        box.value = ""
                        save post
                    
                    @local.addtagvisible = !@local.addtagvisible
                    @local.tagsearch = []
                    save @local

                # Have an X instead when the field is empty?
                if @local.addtagvisible then "done" else "add_box"

            # Using map instead of for ... in prevents scoping issues, and allows access to the index
            @local.tagsearch.map (suggested, i) =>
                selected = i == @local.selected_idx
                DIV
                    key: "#{suggested}-res"
                    display: "contents"

                    SPAN key: "dummy1"

                    SPAN
                        key: "res"
                        cursor: "pointer"
                        className: "hover-select"
                        lineHeight: "24px"
                        color: "#444"
                        background: if selected then "#eee"
                        textTransform: "capitalize"
                        onClick: (e) =>
                            # Save text of the selected result in the widget state
                            @refs.addlabel.getDOMNode().value = suggested
                            @local.selected_idx = i
                            save @local

                        suggested

                    SPAN key: "dummy2"

        DIV
            key: "tags-grid"
            display: "grid"
            gridTemplateColumns: "minmax(5em, auto) #{slider_width}px"
            gridColumnGap: 10
            gridAutoRows: margin_left
            alignItems: "center"

            for tag in (post.tags || [])
                DIV
                    key: "tag-#{tag}"
                    display: "contents"
                    SPAN
                        key: "tag-text"
                        fontSize: 20
                        textTransform: "capitalize"
                        color: "#444"
                        "#{tag}:"

                    SLIDERGRAM_WITH_TAG
                        key: "tag-slidergram"
                        post: post
                        tag: tag
                        width: slider_width
                        height: margin_left - 5
                        max_avatar_radius: (margin_left - 5) / 2
                        read_only: !c.logged_in


#TODO: sometimes, The first time a vote on a slidergram is changed, it takes two clicks to show up


# The BEEG header
dom.HEADER = ->
    c = fetch "/current_user"
   
    DIV
        ref: "headercontainer"
        position: "relative"
        zIndex: 10
        DIV
            key: "actual-header"
            ref: "header"
            display: "flex"
            flexDirection: "row"
            alignItems: "center"
            background: "#def"
            padding: "10px 50px"
            color: "#444"
            zIndex: 5

            X_OF_Y
                key: "title-dropdown"
                flexGrow: 1

            SPAN
                key: "home"
                margin: 10
                cursor: "pointer"
                onClick: () -> load_path "/"
                "Home"

            SPAN
                key: "feeds"
                ref: "feeds"
                margin: 10
                cursor: "pointer"
                onClick: () => 
                    bbox_feeds = @refs.feeds.getDOMNode().getBoundingClientRect()
                    bbox_header = @refs.header.getDOMNode().getBoundingClientRect()
                    @local.offset = bbox_header.right - bbox_feeds.right
                    @local.modal = if @local.modal == "feeds" then false else "feeds"
                    save @local
                # "Preload" the list of feeds:
                # Otherwise the popup will be blank while waiting for the server...
                # Is there a better way to guess when to preload the feeds?
                onMouseEnter: () -> fetch "/feeds"
                "Feeds"
            SPAN
                key: "users"
                margin: 10
                cursor: "pointer"
                onClick: () -> load_path "/users"
                "Users"

            SPAN
                key: "post"
                margin: 10
                cursor: "pointer"
                onClick: () => 
                    @local.modal = if @local.modal == "post" then false else "post"
                    @local.offset = 0
                    save @local
                "Post"

            if c.logged_in
                SPAN
                    key: "user"
                    cursor: "pointer"
                    display: "contents"
                    onClick: () => 
                        @local.modal = if @local.modal == "settings" then false else "settings"
                        @local.offset = 0
                        save @local

                    SPAN
                        key: "name"
                        marginLeft: 14
                        marginRight: 4
                        c.user.name
                    AVATAR
                        key: "avatar"
                        user: c.user
                        hide_tooltip: true
                        style:
                            borderRadius: "50%"
                            width: 45
                            height: 45
            else
                SPAN
                    key: "user"
                    margin: 10
                    cursor: "pointer"
                    onClick: () => 
                        @local.modal = if @local.modal == "login" then false else "login"
                        @local.offset = 0
                        save @local
                    "Login"



        DIV
            key: "dropdown"
            display: "none" unless @local.modal 
            position: "absolute"
            zIndex: 6
            # Sometimes, we want the popup to be close to the button that opened it
            # So we can compute and specify a horizontal offset.
            right: @local.offset ? 0
            marginTop: 10
            padding: 10
            background: "white"
            boxShadow: "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"

            close = () =>
                @local.modal = false
                save @local

            # register_window_event prevents a new handler from being added when the element is re-rendered
            register_window_event "header-modal", "mousedown", (e) =>
                # should we preventdefault?
                unless @refs.headercontainer.getDOMNode().contains e.target
                    close()
            
            switch @local.modal
                when "post" then SUBMIT_POST
                    close: close
                    key: "submit-modal"
                when "settings" then SETTINGS
                    close: close
                    key: "settings-modal"
                when "login" then LOGIN
                    close: close
                    key: "login-modal"
                when "feeds" then FEEDS
                    key: "feeds-modal"

dom.X_OF_Y = ->

    DIV {
            display: "flex"
            flexDirection: "row"
            justifyContent: "left"
            alignItems: "flex-start"
            height: "1.3em"
            lineHeight: 1.2
            fontSize: 20
            @props...
        },
        PERS_DROPDOWN
            key: "pers-dropdown"

        SPAN
            key: "of-spacer"
            whiteSpace: "pre"
            " view of "

        SPAN
            key: "content-dropdown"
            color: "#c5b"
            "everything"


dom.PERS_DROPDOWN = ->
    c = fetch "/current_user"
    v = fetch "view"

    if @local.pers

        users = fetch("/users").all ? []
        tags = fetch("/tags").arr ? []

        n = 0
        scrollOffset = (props) -> SPAN {
                key: "dummy-scroll-offset-#{n++}"
                whiteSpace: "pre"
                pointerEvents: "none"
                style: scrollSnapAlign: "start"
                props...
            }, " "


        close_pers = () =>
            selected = users[@local.scroll_index ? 0] ? users[0]
            load_path selected.key

            @local.pers = false
            save @local

        # register_window_event prevents a new handler from being added when the element is re-rendered
        register_window_event "x-of-y-pers", "mousedown", (e) =>
            # should we preventdefault?
            unless @refs?.pers_dropdown?.getDOMNode?()?.contains e.target
                close_pers()
        DIV
            key: "pers-dropdown"
            ref: "pers_dropdown"
            className: "hide-scroll"
            display: "flex"
            flexDirection: "column"
            height: "6em"
            transform: "translateY(-2.4em)"
            lineHeight: 1.2
            overflowY: "auto"
            scrollBehavior: "smooth"
            style: scrollSnapType: "y mandatory"
            onScroll: () =>
                @local.scroll_index = Math.round @refs.pers_dropdown?.getDOMNode?()?.scrollTop / (20 * 1.2)
                @local.scroll_index -= 3
                save @local
                # TODO: Prefetch some relevant state (particularly the weights) for the selected user...
           
            SPAN
                key: "dummy-scroll-bounce-top-live"
                whiteSpace: "pre"
                lineHeight: 3.6
                pointerEvents: "none"
                " "

            scrollOffset()
            scrollOffset()
           
            n_users = 10
            users[..10].map (user, i) =>
                selected = (@local.scroll_index ? 0) == i
                DIV
                    key: unslash user.key
                    display: "flex"
                    flexDirection: "row"
                    justifyContent: "left"
                    style: if i < n_users - 1 then scrollSnapAlign: "start"

                    cursor: "pointer"
                    onClick: () =>
                        if selected
                            close_pers()
                        else
                            # 20px fontsize * 1.2 lineheight * (i + 3) elements
                            scrolltop = (i + 3) * 20 * 1.2
                            @refs.pers_dropdown?.getDOMNode?()?.scrollTo top: scrolltop

                    AVATAR
                        key: "avatar"
                        user: user
                        width: 20
                        height: 20
                        marginRight: 8
                        clickable: false
                        hide_tooltip: true
                        style:
                            alignSelf: "center"
                            borderRadius: "50%"
                        
                    SPAN
                        key: "name"
                        color: if selected then "#681"
                        textOverflow: "ellipsis"
                        overflow: "hidden"
                        maxWidth: "12ch"
                        whiteSpace: "nowrap"
                        user.name ? user.key[6..]

            SPAN
                key: "dummy-scroll-bounce-bot"
                whiteSpace: "pre"
                lineHeight: 4.5
                pointerEvents: "none"
                " "
    else
        SPAN
            key: "pers-text"
            color: "#681"
            cursor: "pointer"
            onClick: () =>
                @local.pers = !(@local.pers ? false)
                save @local
            if v.user_key?
                name = fetch(v.user_key)?.name
                if @loading()
                    name = "User"
                "#{name}'s"
            else
                "Your"

dom.PERS_DROPDOWN.refresh = ->
    el = @refs.pers_dropdown?.getDOMNode?()
    # Hmmm, now this can cause weird snapping if you scroll too far up with a trackpad. 
    # Add some local state to keep track of if the element was just rendered?
    if el? and el.scrollTop < 1
        v = fetch "view"
        users = fetch("/users").all ? []
        unless @loading()
            index = users.findIndex (u) -> v?.user_key == u.key
            el.scrollTo top: 20 * 1.2 * (3 + Math.max index, 0), behavior: "instant"


dom.SUBMIT_POST = ->

    @local.typed ?= false

    c = fetch "/current_user"
    unless c.logged_in
        return

    form_submit = =>
        title = @refs["post-title"].getDOMNode()
        link = @refs["post-url"].getDOMNode()
        if title.value.length > 1 and link.value.length > 1
            make_post title.value, link.value, c.user.key
            title.value = ""
            link.value = ""

        @props.close?()

    DIV
        key: "submit-container"
        display: "grid"
        grid: "\"icon title slider\" auto
               \"icon domain_time slider\" 16px
                / #{margin_left}px #{post_width + 10}px 1fr "
        alignItems: "center"

        AVATAR
            key: "avatar"
            user: c.user
            hide_tooltip: true
            gridArea: "icon"
            style:
                width: margin_left - 10
                height: margin_left - 10
                borderRadius: "50%"
                alignSelf: "center"
                opacity: 0.5

        INPUT
            key: "title"
            ref: "post-title"
            className: "post-title"
            gridArea: "title"
            fontSize: "18px"
            paddingRight: "10px"
            marginBottom: "2px"
            border: "none"
            lineHeight: "#{margin_left - 10}px"
            justifySelf: "stretch"
            placeholder: "Say something..."
            onKeyDown: (e) =>
                if e.keyCode == 13
                    form_submit()
                else if e.keyCode == 9
                    e.preventDefault()
                    @refs["post-url"].getDOMNode().focus()


        INPUT
            key: "url"
            ref: "post-url"
            gridArea: "domain_time"
            fontSize: "12px"
            color: "#999"
            whiteSpace: "nowrap"
            placeholder: "https://..."
            border: "none"
            onKeyDown: (e) =>
                if e.keyCode == 13
                    form_submit()
                else if e.keyCode == 9
                    e.preventDefault()
        
        SPAN
            key: "submit-btn"
            gridArea: "slider"
            alignSelf: "start"
            height: margin_left - 10
            textAlign: "center"
            alignSelf: "center"
            className: "material-icons md-dark"
            fontSize: "24px"
            onClick: form_submit
            cursor: "pointer"
            "post_add"



# Login Form
dom.LOGIN = ->
    c = fetch "/current_user"
    if c.logged_in and @local.login_attempted
        @local.login_attempted = false
        save @local
        @props.close?()
    button_style =
        justifySelf: "center"
        minWidth: "80%"
        paddingLeft: "5px"
        paddingRight: "5px"

    DIV
        width: 200
        paddingRight: "10px"
        display: "grid"
        # Maybe use flex instead here?
        grid: '"error error" auto
               "name name" 32px
               "pw pw" 32px
               "register login" 24px
                / auto auto'
        gap: "6px"
        DIV
            key: "error"
            gridArea: "error"
            display: "none" unless c.error
            fontSize: "12px"
            color: "red"
            c.error
        INPUT
            key: "login-name"
            id: "login-name"
            ref: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            key: "login-pw"
            id: "login-pw"
            ref: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
            type: "password"

        BUTTON {
            key: "register"
            gridArea: "register"
            button_style...

            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                c.create_account =
                    name: name
                    pass: pw
                save c
                delete c.create_account
                c.login_as =
                    name: name
                    pass: pw
                @local.login_attempted = true
                save c
                save @local
            },
            "Register"

        BUTTON {
            key: "login"
            gridArea: "login"
            button_style...
            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                c.login_as =
                    name: name
                    pass: pw
                @local.login_attempted = true
                save c
                save @local

            },
            "Login"

dom.SETTINGS = ->
    c = fetch "/current_user"
    unless c.logged_in
        return
    DIV
        width: "300"
        display: "grid"
        # Maybe use flex instead here?
        alignContent: "center"
        grid: '"nametag namefield namefield" 32px
               "emailtag emailfield emailfield" 32px
               "pictag picfield picfield" 32px
               "filtertag filterfield filterfield" 32px
               "logout cancel save" 24px
                / auto auto auto'
        gridGap: "5px"
        
        DIV
            key: "name"
            gridArea: "nametag"
            color: "#333"
            fontSize: "12px"
            "Name"
        INPUT
            key: "name-change"
            gridArea: "namefield"
            ref: "name"
            value: c.user.name
            id: "name-change"

        DIV
            key: "email"
            gridArea: "emailtag"
            color: "#333"
            fontSize: "12px"
            "Email"
        INPUT
            key: "email-change"
            gridArea: "emailfield"
            ref: "email"
            value: c.user.email
            id: "email-change"
            type: "email"

        DIV
            key: "pic"
            gridArea: "pictag"
            color: "#333"
            fontSize: "12px"
            "Avatar URL"
        INPUT
            key: "pic-change"
            gridArea: "picfield"
            ref: "pic"
            value: c.user.pic
            placeholder: "http://..."
            id: "pic-change"
        DIV
            key: "filter"
            gridArea: "filtertag"
            color: "#333"
            fontSize: "12px"
            "Min post score"
        INPUT
            key: "filter-change"
            gridArea: "filterfield"
            ref: "filter"
            value: c.user.filter
            placeholder: -0.2
            id: "filter-change"
            type: "number"
            step: 0.1


        BUTTON
            key: "cancel"
            gridArea: "cancel"
            onClick: () => @props.close?()
            "Cancel"

        BUTTON
            key: "logout"
            gridArea: "logout"
            onClick: () =>
                @props.close?()
                c.logout = true
                save c
            "Logout"

        BUTTON
            key: "save"
            gridArea: "save"
            onClick: () =>
                
                name = @refs.name.getDOMNode().value
                email = @refs.email.getDOMNode().value
                pic = @refs.pic.getDOMNode().value ? ""
                filter = @refs.filter.getDOMNode().value ? -0.2

                c.user.name = name
                c.user.email = email
                c.user.pic = pic
                c.user.filter = Number.parseFloat(filter)

                save c.user
                
                # Close the settings box
                @props.close?()
            "Save"

# TODO: Figure out how to "prefetch" things?
dom.FEEDS = ->
    c = fetch "/current_user"
    v = fetch "view"
    tags = (fetch "/tags").arr
    users = (fetch "/users").all
    weights = fetch "weights#{c.user?.key ? 'user/default'}"
    users = users
        .filter (a) -> a.key != c?.user?.key
        .sort (a, b) -> (weights[b.key] ? 0) - (weights[a.key] ? 0)

    DIV
        ref: "feeds"
        maxHeight: 200
        overflowY: "auto"
        paddingLeft: 5
        paddingRight: 20
        display: "grid"
        gridTemplateColumns: "24px auto 1fr"
        gridTemplateRows: "24px"
        gridAutoRows: "24px"
        gridGap: "10px 4px"
        alignItems: "center"


        tags.map (t) -> {type: 'tag', name: t, tag: t}
            .concat ( users.map (u) -> {type: 'user', name: u.name, user_key: u.key} )
            .map (feed) ->
                selected = switch feed.type
                    when 'tag' then v.tag == feed.tag
                    when 'user' then v.user_key == feed.user_key

                DIV
                    key: "feed-#{feed.type}-#{feed.user_key || feed.tag}"
                    display: "contents"
                    cursor: "pointer"
                    color: if selected then "#179"
                    onClick: () ->
                        if selected
                            v.tag = v.user_key = null
                        else
                            v.tag = feed.tag
                            v.user_key = feed.user_key
                        newpath = switch
                            when v.tag then "/#{v.tag}"
                            when v.user_key then v.user_key
                            else "/"
                        save v
                        change_path newpath

                    if feed.type == "user"
                        AVATAR
                            user: feed.user_key
                            key: "icon"
                            hide_tooltip: true
                            style:
                                width: 24
                                height: 24
                                borderRadius: "50%"
                    else
                        DIV
                            key: "tagvatar"
                            width: 24
                            textAlign: "center"
                            "#"

                    SPAN
                        key: "type"
                        fontWeight: "bold"
                        textTransform: "capitalize"
                        "#{feed.type}:"

                    SPAN
                        key: "name"
                        textTransform: if feed.type == "tag" then "capitalize"
                        feed.name


# The list of all users
dom.USERS = ->
    c = fetch "/current_user"
    # //TODO: allow viewing users with tags?

    # //Default to New sorting
    # // My IDE thinks i'm in JS, and sometimes @local breaks the syntax highlighting lmaoo
    this.local.sort ?= "top"
    save @local

    if @local.sort == "top"
        user = c?.user?.key ? "/user/default"
        weights = fetch "weights/#{unslash user}"

    sort_func = switch @local.sort
        when "new" then (a, b) -> (b.joined ? 0) - (a.joined ? 0)
        when "old" then (a, b) -> (a.joined ? 0) - (b.joined ? 0)
        when "top" then (a, b) -> (weights[b.key] ? 0) - (weights[a.key] ? 0)
        else (a, b) -> 0

    users = ((fetch "/users").all ? [])
        .filter (u) -> u.key != c?.user?.key
        .sort sort_func
    DIV
        key: "users"
        DIV
            key: "sort-select"
            display: "flex"
            flexDirection: "row"
            justifyContent: "space-evenly"

            ["top", "new", "old"].map (s) =>
                SPAN
                    key: s
                    textTransform: "capitalize"
                    fontSize: 20
                    color: if @local.sort == s then "black" else "#999"
                    cursor: "pointer" unless @local.sort == s
                    onClick: () =>
                        @local.sort = s
                        save @local
                    s

        DIV
            key: "user-list"
            users.map (user) =>
                USER
                    user: user.key
                    key: unslash user.key

# The layout for a user in a user feed
dom.USER = ->
    user = @props.user
    # Subscribe to the user
    if user?.key or typeof user == "string" then user = fetch user
    c = fetch "/current_user"

    joined_string = prettyDate(user.joined ? 0)

    DIV
        margin: "5px 0"
        padding: "5px 10px"
        #boxShadow: if @local.expanded then "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"
        DIV
            key: "user-main"
            display: "grid"
            grid: "\"icon name slider more\" auto
                   \"icon joined slider more\" 16px
                    / #{margin_left}px #{post_width}px 1fr #{margin_left}px"
            alignItems: "center"

            AVATAR
                key: "avatar"
                user: user
                width: margin_left - 10
                height: margin_left - 10
                style:
                    gridArea: "icon"
                    alignSelf: "center"
                    borderRadius: "50%"

            SPAN
                key: "name"
                gridArea: "name"
                fontSize: "18px"
                paddingRight: "10px"
                lineHeight: "#{margin_left - 10}px"
                justifySelf: "stretch"
                user.name ? user.key[6..]

            SPAN
                key: "joined"
                gridArea: "joined"
                fontSize: "12px"
                color: "#999"
                whiteSpace: "nowrap"
                overflowX: "hidden"
                "Joined #{joined_string}"
           
            DIV
                key: "user-votes-slider"
                gridArea: "slider"
                alignSelf: "start"
                height: margin_left - 10
                # TODO: Create a UI for viewing users wrt a tag
                SLIDERGRAM
                    key: "slidergram"
                    sldr: "/votes/#{unslash user.key}(untagged)"
                    width: slider_width
                    height: margin_left - 5
                    max_avatar_radius: (margin_left - 5) / 2
                    read_only: !c.logged_in
                    vote_key: "user_key"
                    onsave: (vote) =>
                        vote.key = "#{c.user.key}/vote/#{unslash user.key}"
                        vote.target_key = user.key
                        save vote

            SPAN
                key: "more"
                gridArea: "more"
                color: "#999"
                className: "material-icons md-dark"
                fontSize: "24px"
                cursor: "pointer"
                textAlign: "center"
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"

        if @local.expanded
            POST_DETAILS
                key: "details-dropdown"
                post: user
