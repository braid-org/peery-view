# TOOD: put these somewhere better
color1 = "#681"
color2 = "#c5b"

### === POST FEED === ###
dom.POSTS = ->
    c = fetch "/current_user"
    v = fetch "view"

    # User who's viewing the posts
    username = v.user_key ? c?.user?.key ? "/user/default"
    kson = stringify_kson tag: v.tag, user: username, root_post: v.post_key
    layout = fetch "blocks_layout#{kson}"

    max_depth = @props.max_depth ? 5

    # We store this as a component property instead of local state
    # We need it to persist when blocks_layout changes (and the component rerenders)
    # But the changes that we make to it can be done while rendering
    # That is, we are able to check and bump each open reply *before* it gets rendered
    # So we need to be able to change its value without rerendering the function
    @block_replies ?= {}
    # On the other hand, when a reply button is clicked, we need to change block_replies AND rerender
    # Hence we have a dummy key that can be toggled in order to force refresh
    @local.refresh ?= false

    # Function to output a chat blocks layout, given a flattened array
    blocks = (arr, key) =>
        num_blocks = arr?.length
        # create the array once and then push all the created components into it
        posts_out = []
        arr
            ?.filter (block) -> block.level <= max_depth
            ?.forEach (block, i) =>
                # if the block level is 0 then it either has a detached parent
                # or no parent (in which case there's no context to show)
                # if the block has a skip count, then its parent was hidden for being bad.

                left = block.level * (post_height - 5) / 2

                num_posts = block.chain.length
                if block.context? and (block.level == 0 or block.skipped) and (block.context != v.post_key)
                    posts_out.push COLLAPSED_POST
                        key: "context-#{block.end}-#{block.context}"
                        post: block.context
                        style: marginLeft: left
                        width: 600 - left

                block.chain?.forEach (post, i) =>
                    is_last = i == num_posts - 1

                    # if there WAS an open block reply under this post, push it to the end of the block
                    if @block_replies[post] and not is_last
                        @block_replies[block.end] = @block_replies[post]
                        delete @block_replies[post]

                    # create the post and directly put it on the posts_out array
                    posts_out.push DIV
                        key: post
                        marginLeft: left
                        display: "flex"
                        flexDirection: "row"

                        POST
                            key: "post"
                            post: post
                            width: 600 - left
                            hide_reply: is_last and not block.children?.length

                        DIV
                            key: "tags-container"
                            height: post_height
                            marginLeft: padding_unit

                            TAGS
                                key: "tags"
                                post: post
                                style: background: "white"

                # every reply needs to have a key, even the ones that are not open
                # if our run through the posts didn't get us a reply key, generate one.
                @block_replies[block.end] ?= "block-end-#{Math.random().toString(36).substr(2)}"
                # spacing and reply
                posts_out.push DIV
                    key: @block_replies[block.end]
                    marginBottom: padding_unit if block.children?.length or not c.logged_in
                    marginLeft: left

                    unless block.children?.length
                        HOVER_REPLY
                            key: "reply-box"
                            parent: block.end
                            style: width: 600 - left

        DIV
            key: key
            marginLeft: 20
            posts_out
    DIV
        key: "posts"

        blocks layout.new, "new-posts"

        DIV
           key: "sort-separator"
           display: if layout.new.length then "flex" else "none"
           flexDirection: "row"
           justifyContent: "stretch"
           alignItems: "center"
           marginLeft: 10
           width: outer_width + post_height
 
           # Blue line on the left
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

           # Blue line on the right
           DIV
               key: "dummy2"
               flexGrow: 1
               height: 1.5
               background: "#36a"
               borderRadius: 1


        blocks layout.top, "top-posts", false

# The collapsed stub of a post.
# In some contexts, is expandable?
dom.COLLAPSED_POST = ->
    post = @props.post
    # Subscribe to the post
    if post?.key or typeof(post) == "string" then post = fetch post
    unless post.user_key?
        # The post has actually just been deleted.
        return

    author = fetch post.user_key
    ARTICLE
        position: "relative"
        display: "flex"
        flexDirection: "row"
        margin: "3px 0"
        opacity: 0.8
        width: @props.width
        style: @props.style

        AVATAR
            key: "avatar"
            user: author
            clickable: false
            hide_tooltip: true
            width: post_height/2
            height: post_height/2
            style:
                justifySelf: "center"
                alignSelf: "flex-start"
                flexShrink: 0
                flexGrow: 0
                marginRight: 5
                borderRadius: "50%"


        DIV
            key: "content"
            justifySelf: "stretch"
            alignSelf: "stretch"
            #flexGrow: 1
            overflowX: "hidden"
            textOverflow: "ellipsis"
            whiteSpace: "nowrap"
            fontSize: "0.9375rem" # 15px unless zoom
            lineHeight: 1.4
            color: "#444"
            marginRight: padding_unit

            post.title ? post.body

        DIV
            key: "gray-line"
            height: 1.5
            flexGrow: 1
            alignSelf: "center"
            background: "#999"


# The layout for a single post. Not including slidergram.
dom.POST = ->
    post = @props.post
    # Subscribe to the post
    if post?.key or typeof(post) == "string" then post = fetch post
    unless post.user_key?
        # The post has actually just been deleted.
        return

    ui = @local#fetch "post_state#{post.key}"

    author = fetch post.user_key

    c = fetch '/current_user'
    v = fetch "view"

    if post.url
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
    else
        pretty_url = ""
        functional_url = post.key
        
    time_string = prettyDate(post.time * 1000)
    user_clickable = c.logged_in and c.user.key != author.key
    is_author = c.logged_in and c.user.key == author.key

    controls_visible = (ui.hover or ui.editing) and not @props.no_controls
    pad = if ui.editing then 0 else padding_unit
    pad_controls = if ui.editing then padding_unit else 0

    # container for the post and the reply
    DIV
        width: @props.width
        
        # the actual post
        ARTICLE
            key: "post-content"
            position: "relative"
            display: "flex"
            flexDirection: "row"
            marginTop: 2

            AVATAR_WITH_SLIDER
                key: "avatar"
                user: author
                clickable: user_clickable
                width: post_height - 5
                height: post_height - 5
                style:
                    justifySelf: "center"
                    alignSelf: "flex-start"
                    flexShrink: 0
                    flexGrow: 0
                    marginRight: 5

            DIV
                key: "content"
                justifySelf: "stretch"
                alignSelf: "stretch"
                display: "flex"
                flexDirection: "column"
                flexGrow: 1
                background: "#eee"
                boxSizing: "border-box"
                # when we edit, the textarea assumes the padding
                # the controls line serves to pad the bottom
                padding: "#{pad}px #{pad}px 0 #{pad}px"
                onMouseEnter: () =>
                    ui.hover = true
                    save ui
                onMouseLeave: () =>
                    ui.hover = false
                    save ui

                if post.url then [
                    A
                        key: "title"
                        lineHeight: 1.3
                        justifySelf: "stretch"
                        textDecoration: "none"
                        href: if functional_url.length then functional_url
                        post.title

                    SPAN
                        key: "url"
                        fontSize: "12px"
                        color: "#999"
                        whiteSpace: "nowrap"
                        overflowX: "hidden"
                        textOverflow: "ellipsis"
                        pretty_url
                    ]

                else
                    if ui.editing
                        # A textbox with the text of the post body
                        AUTOSIZEBOX
                            key: "editbox"
                            ref: "editbox"
                            gridArea: "textbox"
                            padding: padding_unit

                            className: "stylish-input"
                            #minHeight: post_height
                            width: "100%"
                            boxSizing: "border-box"
                            fontSize: "0.9375rem" # 15px unless zoom
                            lineHeight: 1.4

                            resize: "none"

                            placeholder: "Edit your post..."
                            
                            value: ui.live_body
                            onChange: (e) =>
                                ui.live_body = e.target.value
                                save ui

                    else [
                            if post.title
                                SPAN
                                    key: "title"
                                    display: "block"
                                    fontSize: "1rem" # 16px unless zoom
                                    lineHeight: 1.5
                                    className: "post-title"
                                    fontWeight: "bold"
                                    post.title

                            SPAN
                                key: "body-intern"
                                whiteSpace: "pre-line"
                                textAlign: "justify"
                                fontSize: "0.9375rem" # 15px unless zoom
                                lineHeight: 1.4
                                post.body
                    ]


                # controls line
                DIV
                    key: "controls"
                    display: "flex"
                    flexDirection: "row"
                    justifyContent: "flex-start"
                    fontSize: "12px"
                    color: "#666"
                    opacity: if controls_visible then 1 else 0
                    # transition: "opacity 0.05s ease-in"
                    pointerEvents: if controls_visible then "auto" else "none"
                    padding: "0 #{pad_controls}px"
                    height: 14


                    SPAN
                        key: "time"
                        flexGrow: 1
                        marginRight: 8
                        time_string

                    BUTTON
                        key: "cancel-btn"
                        className: "unbutton"
                        display: unless ui.editing then "none"
                        marginLeft: 8
                        onClick: () =>
                            ui.editing = false
                            save ui
                        "Cancel"

                    BUTTON
                        key: "save-btn"
                        className: "unbutton"
                        marginLeft: 8
                        display: unless @local.editing then "none"
                        onClick: () =>
                            save {
                                post...
                                body: ui.live_body
                                edit_time: Math.floor (Date.now() / 1000)
                            }

                            ui.editing = false
                            save ui
                        "Save"

                    A
                        key: "permalink-btn"
                        className: "unbutton"
                        marginLeft: 8
                        display: if ui.editing or ui.replying then "none"
                        href: post.key
                        "data-load-intern": true
                        "Focus"

                    BUTTON
                        key: "delete-btn"
                        className: "unbutton"
                        display: if ui.editing or !is_author then "none"
                        marginLeft: 8
                        onClick: () -> del post.key
                        "Delete"

                    BUTTON
                        key: "edit-btn"
                        className: "unbutton"
                        marginLeft: 8
                        display: if post.url or ui.editing or !is_author then "none"
                        onClick: () =>
                            ui.replying = false
                            ui.editing = true
                            ui.live_body = post.body
                            save ui
                        "Edit"

                    BUTTON
                        key: "reply-btn"
                        className: "unbutton"
                        marginLeft: 8
                        display: if ui.editing or ui.replying or @props.hide_reply or not c.logged_in then "none"
                        onClick: () =>
                            ui.replying = true
                            ui.editing = false
                            save ui
                        "Reply"

        if ui.replying
            MINI_REPLY
                key: "reply"
                parent: post.key
                ui: "inline_reply#{post.key}"
                style:
                    marginLeft: (post_height - 5) / 2
                close: () =>
                    ui.replying = false
                    save ui

dom.TAGS = ->
    c = fetch "/current_user"
    v = fetch "view"
    post = fetch @props.post

    @local.expanded &= !@props.no_expand

    ASIDE
        display: "flex"
        flexDirection: "column"
        alignContent: "stretch"
        padding: "0 #{padding_unit}px"
        boxShadow: if @local.expanded then "rgba(0, 0, 0, 0.2) 0px 1px 5px 1px"
        # If expanded then we need to overlap other stuff
        position: "relative"
        zIndex: if @local.expanded then 2 else 1
        style: @props.style

        DIV
            key: "untagged-slider"
            display: "flex"

            SLIDERGRAM_WITH_TAG
                key: "slidergram"
                post: post
                width: slider_width
                height: slider_height
                max_avatar_radius: slider_height / 2.5
                read_only: !c.logged_in

            BUTTON
                key: "more"
                color: "#999"
                className: "material-icons-outlined md-dark unbutton"
                fontSize: "24px"
                textAlign: "center"
                display: if @props.no_expand then "none"
                marginLeft: padding_unit
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"

        # The tags that are actually on the post, plus their sliders
        if @local.expanded then [
            post.tags?.map (tag) =>
                DIV
                    key: "tag-#{tag}"
                    display: "flex"

                    SLIDERGRAM_WITH_TAG
                        key: "tag-slidergram"
                        post: post
                        tag: tag
                        width: slider_width
                        height: slider_height
                        max_avatar_radius: slider_height / 2.5
                        read_only: !c.logged_in

                    SPAN
                        key: "tag-text"
                        fontSize: 14
                        marginLeft: 15
                        textTransform: "capitalize"
                        color: "#666"
                        whiteSpace: "nowrap"
                        alignSelf: "center"

                        tag
            
            DIV
                key: "add-tag"
                display: if c.logged_in then "flex" else "none"
                alignItems: "flex-end"
                height: slider_height + 12

                SLIDER_BOTTOM
                    key: "empty-slider"
                    width: slider_width
                    linewidth: 1.75
                
                ADD_TAG
                    key: "textbox-and-dropdown"
                    post: post.key
                    style: marginLeft: 15, height: 20, alignSelf: "center"

            ]

dom.ADD_TAG = ->
    post = fetch @props.post

    potential_tags = (fetch "/tags").arr.filter (f) -> f not in (post.tags || [])
    max_suggestions = @props.max_suggestions ? 4
    # Setup default values in @local
    # These values are used for the tag search box
    @local.selected_idx ?= -1
    @local.tagsearch ?= []
    @local.typed ?= ""
    @local.addtagvisible ?= false
    save @local

    # Add-tag searchbox
    SPAN
        overflowY: "visible"
        style: @props.style

        confirm_add = () =>
            box = @refs.addlabel.getDOMNode()
            if box.value.length
                post.tags ||= []
                new_tag = box.value.toString().toLowerCase()
                # Disable adding certain tags.
                # In the future, we should make this check serverside so it can't be bypassed.
                if new_tag.indexOf("/") == -1 and ["users", "about"].indexOf(new_tag) ==  -1
                    post.tags.push new_tag
                box.value = ""
                save post
            
            @local.tagsearch = []
            save @local

        DIV
            key: "input-and-suggestions"
            display: "inline-flex"
            flexDirection: "row"
            alignItems: "center"

            INPUT
                key: "textbox"
                ref: "addlabel"
                placeholder: "New Tag..."
                fontSize: 15
                color: "#666"
                border: "none"
                maxWidth: "15ch"
                # Handle arrow keys, enter, etc
                onKeyDown: (e) =>
                    switch e.keyCode
                        # Enter
                        when 13
                            e.preventDefault()
                            confirm_add()
                        # Up/down, tab
                        when 38, 40, 9
                            if e.target.value
                                e.preventDefault()
                            v = @refs.addlabel.getDOMNode()
                            # Up arrow is 38, down arrow is 40, tab is 9
                            di = switch e.keyCode
                                when 38 then -1
                                when 40 then 1
                                when 9 then 1
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
                        # Escape
                        when 27
                            @local.tagsearch = []
                    save @local

                # Handle actual text entry
                onInput: (e) =>
                    v = @refs.addlabel.getDOMNode().value.toString().toLowerCase()
                    @local.typed = v
                    # Get the tags that start with the query
                    # In the future, could do a fuzzy search
                    @local.tagsearch = potential_tags.filter((t) => t.startsWith v)
                                                     .slice 0, max_suggestions
                    @local.selected_idx = -1
                    unless v.length then @local.tagsearch = []
                    save @local

        DIV
            key: "results-overflow"
            marginTop: 5
            overflowY: "visible"
            background: "white"
            boxShadow: "0 2px 3px rgba(0,0,0,0.2)"
            # match the input box width, with the symmetrical padding
            # Using map instead of for ... in prevents scoping issues, and allows access to the index
            @local.tagsearch.map (suggested, i) =>
                DIV
                    key: "#{suggested}-res"
                    cursor: "pointer"
                    className: "hover-select"
                    fontSize: 16
                    lineHeight: 1
                    color: "#444"
                    padding: 4
                    background: if i == @local.selected_idx then "#eee"
                    textTransform: "capitalize"
                    onClick: (e) =>
                        # Save text of the selected result in the widget state
                        @refs.addlabel.getDOMNode().value = suggested
                        @local.selected_idx = i
                        save @local

                    suggested


### === HEADER AND POPUPS === ###
# The BEEG header
dom.MAIN_HEADER = ->
    c = fetch "/current_user"
    v = fetch "view"

    static_titles = 
        post_details: ["Your", "view of a", "post"]
        users: ["Your", "view of", "all users"]
        search: ["Search", "for a", "post"]
   
    HEADER
        ref: "headercontainer"
        position: "relative"
        zIndex: 10
        maxWidth: outer_width + 100
        width: "100%"
        NAV
            key: "actual-header"
            ref: "header"
            display: "flex"
            flexDirection: "row"
            alignItems: "center"
            padding: "10px 45px"
            color: "#444"
            zIndex: 5

            # Dynamic rolodex title
            if v.page == "posts" then X_OF_Y
                key: "title-dropdown"
                flexGrow: 1
            else
                title = static_titles[v.page]
                # Static title with colors
                DIV
                    key: "title-text"
                    flexGrow: 1
                    height: "1.3em"
                    lineHeight: 1.2
                    fontSize: 20

                    SPAN
                        key: "word-1"
                        color: color1
                        title[0]
                    SPAN
                        key: "word-2"
                        whiteSpace: "pre"
                        "  #{title[1]}  "
                    SPAN
                        key: "word-3"
                        color: color2
                        title[2]

            A
                key: "home"
                className: "mobile-hide"
                margin: 10
                display: if v.page == "posts" then "none"
                color: "inherit"
                textDecoration: "none"
                href: "/"
                "data-load-intern": true
                "Home"

            A
                key: "about"
                className: "mobile-hide"
                margin: 10
                color: "inherit"
                textDecoration: "none"
                href: "/about"
                "About"

            A
                key: "users"
                className: "mobile-hide"
                margin: 10
                color: "inherit"
                textDecoration: "none"
                display: if v.page == "users" then "none"
                href: "/users"
                "data-load-intern": true
                "Users"

            A
                key: "search"
                className: "mobile-hide"
                margin: 10
                color: "inherit"
                textDecoration: "none"
                display: if v.page == "search" then "none"
                href: "/search"
                "data-load-intern": true
                "Search"

            if c.logged_in
                BUTTON
                    key: "user"
                    className: "unbutton"
                    display: "contents"
                    onClick: () => 
                        @local.modal = if @local.modal == "settings" then false else "settings"
                        save @local

                    SPAN
                        key: "name"
                        className: "mobile-hide"
                        marginLeft: 14
                        marginRight: 4
                        c.user.name
                    AVATAR
                        key: "avatar"
                        user: c.user
                        hide_tooltip: true
                        style:
                            borderRadius: "50%"
                            width: 40
                            height: 40
                            overflow: "hidden"
            else
                BUTTON
                    key: "user"
                    className: "unbutton"
                    margin: 10
                    onClick: () => 
                        @local.modal = if @local.modal == "login" then false else "login"
                        save @local
                    "Login"



        DIV
            key: "dropdown"
            display: "none" unless @local.modal 
            position: "absolute"
            right: 0
            zIndex: 6
            marginTop: 10
            padding: 10
            background: "white"
            boxShadow: "rgba(0, 0, 0, 0.2) 0px 1px 5px 1px"

            close = () =>
                @local.modal = false
                save @local

            # register_window_event prevents a new handler from being added when the element is re-rendered
            register_window_event "header-modal", "mousedown", (e) =>
                # should we preventdefault?
                unless @refs.headercontainer.getDOMNode().contains e.target
                    close()
           
            # Display one of various popups
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

# The view text, with rolodex view selectors
dom.X_OF_Y = ->

    v = fetch "view"
    c = fetch "/current_user"
    DIV {
            display: "flex"
            className: "x-of-y"
            flexDirection: "row"
            alignItems: "flex-start"
            justifyContent: "left"
            height: "1.3em"
            lineHeight: 1.2
            fontSize: 20
            @props...
        },

        if @local.pers
            viewing_user = c?.user?.key ? "/user/default"
            weights = fetch "weights/#{unslash viewing_user}"

            users = (fetch("/users").all ? [])
                .filter (u) -> u.key != viewing_user
                .sort (a, b) -> (weights[b.key] ? 0) - (weights[a.key] ? 0)
            users.unshift fetch viewing_user

            selected_user = if v.user_key then users.findIndex (u) -> u.key == v.user_key else 0
            ROLODEX
                key: "pers-rolo"
                # The array of data to be rendered
                arr: users
                # The index of the initially chosen element
                selected: selected_user
                # Callback for when an entry has been chosen
                close: (chosen) =>
                    if @local.pers
                        load_path if chosen then (users[chosen]?.key ? "/") else "/"
                    @local.pers = false
                    save @local
                # Function to render each element
                render: (user, selected, el_props) ->
                    DIV {
                            key: unslash user.key
                            display: "flex"
                            flexDirection: "row"
                            justifyContent: "left"
                            cursor: "pointer"
                            el_props...
                        },

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
                            color: if selected then color1
                            textOverflow: "ellipsis"
                            overflow: "hidden"
                            maxWidth: "12ch"
                            whiteSpace: "nowrap"
                            # Put "You" instead of your own username
                            switch user.key
                                when c?.user?.key then "You"
                                else user.name ? user.key[6..]

        else
            SPAN
                key: "pers-text"
                color: color1
                cursor: "pointer"
                onClick: () =>
                    @local.pers = true
                    save @local
                if v.user_key?
                    "#{fetch(v.user_key)?.name ? 'User'}'s"
                else
                    "Your"

        SPAN
            key: "of-spacer"
            whiteSpace: "pre"
            "  view of  "

        if @local.cont
            tags = ["Everything", (fetch("/tags").arr ? [])...]
            selected_tag = if v.tag then tags.indexOf v.tag else 0
            ROLODEX
                key: "cont-rolo"
                arr: tags
                selected: selected_tag
                close: (chosen) =>
                    if @local.cont
                        load_path if chosen then (tags[chosen] ? "/") else "/"
                    @local.cont = false
                    save @local
                # Function to render each element
                render: (tag, selected, el_props) ->
                    DIV {
                            key: tag
                            cursor: "pointer"
                            el_props...
                        },

                        SPAN
                            key: "the_tag"
                            color: if selected then color2
                            textOverflow: "ellipsis"
                            overflow: "hidden"
                            maxWidth: "12ch"
                            whiteSpace: "nowrap"
                            textTransform: "capitalize"
                            tag

        else
            SPAN
                key: "cont-text"
                color: color2
                cursor: "pointer"
                textTransform: "capitalize"
                onClick: () =>
                    @local.cont = true
                    save @local
                v.tag ? "everything"


dom.ROLODEX = ->
    n = 0
    scrollOffset = (props) -> SPAN {
            key: "dummy-scroll-offset-#{n++}"
            whiteSpace: "pre"
            pointerEvents: "none"
            props...
        }, " "

    close = () =>
        @props.close?(@local.scroll_index ? 0)

        @local.has_jumped_to_initial = false
        save @local

    # register_window_event prevents a new handler from being added when the element is re-rendered
    register_window_event "#{@props.key}-dropdown", "mousedown", (e) =>
        # should we preventdefault?
        unless @refs?.dropdown?.getDOMNode?()?.contains e.target
            close()
    DIV
        ref: "dropdown"
        className: "hide-scroll"
        display: "flex"
        flexDirection: "column"
        height: "6.65em"
        transform: "translateY(-2.4em)"
        lineHeight: 1.2
        overflowY: "auto"
        overflowX: "hidden"
        scrollBehavior: "smooth"
        style: scrollSnapType: "y mandatory"
        onScroll: () =>
            @local.scroll_index = Math.round @refs.dropdown?.getDOMNode?()?.scrollTop / (20 * 1.2)
            @local.scroll_index -= 3
            save @local
            # TODO: Prefetch some relevant state (particularly the weights) for the selected user...
      
        scrollOffset lineHeight: 3.6
        scrollOffset style: scrollSnapAlign: "start"
        scrollOffset style: scrollSnapAlign: "start"

        n_users = @props.arr.length
        @props.arr.map (data, i) =>
            selected = (@local.scroll_index ? 0) == i
            @props.render data, selected,
                onClick: () =>
                    if selected
                        close()
                    else
                        # 20px fontsize * 1.2 lineheight * (i + 3) elements
                        scrolltop = (i + 3) * 20 * 1.2
                        @refs.dropdown?.getDOMNode?()?.scrollTo top: scrolltop
                style: if i < n_users - 2 then scrollSnapAlign: "start"
                height: 24
                className: "rolodex-entry"


        scrollOffset lineHeight: 5

# We use refresh to set the dropdown's scroll position the first time it renders
dom.ROLODEX.refresh = ->
    el = @refs.dropdown?.getDOMNode?()
    # Hmmm, now this can cause weird snapping if you scroll too far up with a trackpad. 
    # Add some local state to keep track of if the element was just rendered?
    if el? and !@local.has_jumped_to_initial and @props.selected != -1
        top = 20 * 1.2 * (3 + @props.selected)
        el.scrollTo top: top, behavior: "instant"
        el.scrollTop = top
        @local.has_jumped_to_initial = true
        save @local


# The submit-post modal
dom.SUBMIT_POST = ->
    c = fetch "/current_user"
    unless c.logged_in
        return

    form_submit = =>
        body = @refs["post-main"].getDOMNode()
        title = @refs["post-title"].getDOMNode()
        body_val = body?.value.trim()
        title_val = title?.value.trim()

        if body_val and (title_val or !@local.show_title)
            make_post
                user: c.user.key
                title: title.value
                url: if @local.show_title then body_val
                body: unless @local.show_title then body_val
                parent: @props.parent

            # reset the form
            title.value = ""
            body.value = ""
            @local.typed = @local.show_title = false
            save @local

        @props.close?()

    DIV
        key: "submit-container"
        display: "grid"
        width: 600
        grid: "\" icon main  main   main \"  auto
               \" .    title title  title\"  auto
               \" .    .     cancel submit\" 18px
                / auto 1fr   auto    auto "
        gridColumnGap: 5
        gridRowGap: 2
        alignItems: "center"
        marginLeft: 20

        AVATAR
            key: "avatar"
            user: c.user
            hide_tooltip: true
            gridArea: "icon"
            style:
                width: post_height - 5
                height: post_height - 5
                borderRadius: "50%"
                alignSelf: "start"
                justifySelf: "start"
                opacity: 0.5

        TEXTAREA
            key: "main"
            ref: "post-main"
            className: "stylish-input"
            borderWidth: "1px"
            borderStyle: "solid"
            gridArea: "main"
            fontSize: "0.9375rem" # 15px but scales
            lineHeight: 1.2
            padding: padding_unit
            justifySelf: "stretch"
            resize: "vertical"
            minHeight: post_height
            boxSizing: "border-box"
            placeholder: "Say something..."
            style: height: "#{post_height}px"
            ###
            onKeyDown: (e) =>
                # enter
                if e.keyCode == 13
                    form_submit()
                # tab
                else if e.keyCode == 9
                    e.preventDefault()
                    @refs["post-url"].getDOMNode().focus()
            ###
            onInput: (e) =>
                # check if current value is a link
                val = e.target.value?.trim()
                try
                    the_url = new URL val
                    # must be an http or https url
                    @local.show_title = (the_url.protocol == "http:") or (the_url.protocol == "https:")
                catch
                    # value is not a url
                    @local.show_title = false
                finally
                    @local.typed = val?.length > 0
                    save @local
                # if an event handler returns false, some browsers will interpret as a call to e.preventDefault()
                return


        INPUT
            key: "title"
            ref: "post-title"
            gridArea: "title"
            className: "stylish-input"
            borderWidth: "2px"
            borderStyle: "solid"
            padding: padding_unit
            boxSizing: "border-box"
            placeholder: "Add a title..."
            fontSize: "0.9375rem"
            lineHeight: "#{post_height - 2 * padding_unit}px"
            whiteSpace: "nowrap"
            display: unless @local.show_title then "none"
            style: height: "#{post_height}px"
            ###
            onKeyDown: (e) =>
                if e.keyCode == 13
                    form_submit()
                else if e.keyCode == 9
                    e.preventDefault()
            ###
        
        BUTTON
            key: "cancel"
            className: "unbutton"
            gridArea: "cancel"
            fontSize: "14px"
            display: unless @props.cancel then "none"
            color: "#999"
            onClick: @props.close
            "Cancel"

        BUTTON
            key: "submit"
            className: "unbutton"
            gridArea: "submit"
            fontSize: "14px"
            color: "#999"
            onClick: form_submit
            display: unless @local.typed then "none"
            "Send"

dom.MINI_REPLY = ->
    c = fetch "/current_user"
    unless c.logged_in
        return

    ui = fetch (@props.ui ? @local)
    submit = () =>
        if ui.text?.length
            # reply
            make_post
                user: c.user.key
                body: ui.text
                parent: @props.parent

            ui.text = ""
            save ui
            @props?.close false

    DIV
        display: "grid"
        grid: "\" avatar        input  input\" auto
               \" .             cancel post  \" 16px
               / #{post_height}px 1fr auto"
        marginTop: 5
        marginBottom: 3
        style: @props.style

        AVATAR
            key: "avatar"
            user: c.user
            hide_tooltip: true
            style:
                gridArea: "avatar"
                width: post_height - 5
                height: post_height - 5
                borderRadius: "50%"
                alignSelf: "start"
                justifySelf: "start"
                opacity: 0.5

        AUTOSIZEBOX
            key: "content"
            ref: "content"
            gridArea: "input"
            className: "stylish-input"
            borderWidth: "1px"
            borderStyle: "solid"
            fontSize: "0.875rem" # 14px but scales
            lineHeight: 1.4
            padding: padding_unit - 1
            justifySelf: "stretch"
            resize: "none"
            minHeight: post_height
            boxSizing: "border-box"
            placeholder: "Say something..."
            height: post_height
            flexGrow: 1
            value: ui.text

            onChange: (e) =>
                ui.text = e.target.value
                save ui

            onKeyDown: (e) =>
                # escape
                if e.keyCode == 27
                    @props?.close true
                if e.keyCode ==  13 and !e.shiftKey
                    e.preventDefault()
                    submit()

        if @props?.close
            BUTTON
                key: "cancel"
                gridArea: "cancel"
                className: "unbutton"
                fontSize: 12
                color: "#999"
                justifySelf: "end"
                display: "none" if @props.no_controls
                onClick: () => @props?.close true
                    
                "Cancel"

        BUTTON
            key: "submit"
            gridArea: "post"
            className: "unbutton"
            fontSize: 12
            color: "#999"
            justifySelf: "end"
            marginLeft: 8
            onClick: submit
            display: "none" if @props.no_controls
                
            "Send"

dom.HOVER_REPLY = ->
    c = fetch "/current_user"
    unless c.logged_in
        return

    ui = fetch (@props.ui ? @local)
    active = ui.hover or ui.focus or ui.text?.length
    submit = () =>
        if ui.text?.length
            # reply
            make_post
                user: c.user.key
                body: ui.text
                parent: @props.parent

            ui.text = ""
            save ui

    DIV
        display: "grid"
        grid: "\" avatar input\" auto
               \" .      post \" auto
               / #{post_height}px 1fr"
        marginBottom: 2
        style: @props.style

        onMouseEnter: () =>
            ui.hover = true
            save ui
        onMouseLeave: () =>
            ui.hover = false
            save ui

        AVATAR
            key: "avatar"
            user: c.user
            hide_tooltip: true
            style:
                gridArea: "avatar"
                width: post_height - 5
                height: post_height - 5
                borderRadius: "50%"
                opacity: if ui.text?.length then 1.0 else 0
                # transition: "opacity 0.15s"

        AUTOSIZEBOX
            key: "content"
            ref: "content"
            gridArea: "input"
            # the stylish-input class removes some outlines,
            # and applies a partially opaque border to indicate hover and focus.
            className: "stylish-input"
            boxSizing: "border-box"
            borderWidth: "1px"
            borderStyle: "solid"
            # the stylish-input class includes some border colors 
            borderColor: "rgba(0, 0, 0, 0)" unless active
            # transition: "border-color 0.08s"
            fontSize: "0.875rem" # 14px but scales
            lineHeight: 1.4
            # since we have a 1px border, slightly reduce padding
            # this ensures correct alignment against real posts
            padding: padding_unit - 1
            marginTop: 0
            justifySelf: "stretch"
            # don't put resize handles; we autoresize
            resize: "none"
            # don't get smaller than the height of the avatar
            minHeight: post_height
            height: post_height
            placeholder: "Reply..."
            value: ui.text

            onChange: (e) =>
                ui.text = e.target.value
                save ui

            onKeyDown: (e) =>
                # escape
                if e.keyCode == 27
                    # what should we do on close??
                    @refs.content?.getDOMNode()?.blur()
                if e.keyCode ==  13 and !e.shiftKey
                    e.preventDefault()

            onFocus: () =>
                ui.focus = true
                save ui
            onBlur: () =>
                ui.focus = false
                save ui

        BUTTON
            key: "submit"
            gridArea: "post"
            className: "unbutton"
            fontSize: 12
            color: "#999"
            justifySelf: "end"
            marginLeft: 8
            onClick: submit
            display: "none" unless ui.text?.length
                
            "Send"

# The login/register modal
dom.LOGIN = ->
    c = fetch "/current_user"
    # We use this check to keep the modal open if login failed
    # More precisely, only close it if login succeeded.
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

# The modal for the logged-in user's settings
dom.SETTINGS = ->
    c = fetch "/current_user"
    unless c.logged_in
        return

    @local.name ?= c.user.name
    @local.email ?= c.user.email
    @local.pic ?= c.user.pic

    DIV
        width: "300"
        display: "grid"
        # Maybe use flex instead here?
        alignContent: "center"
        grid: '"nametag namefield namefield" 32px
               "emailtag emailfield emailfield" 32px
               "pictag picfield picfield" 32px
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
            value: @local.name
            onChange: (e) =>
                @local.name = e.target.value
                save @local
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
            value: @local.email
            onChange: (e) =>
                @local.email = e.target.value
                save @local
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
            value: @local.pic
            onChange: (e) =>
                @local.pic = e.target.value
                save @local
            placeholder: "http://..."
            id: "pic-change"

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
                
                c.user.name = @local.name
                c.user.email = @local.email
                c.user.pic = @local.pic

                save c.user

                # Close the settings box
                @props.close?()
            "Save"




### === ALL USER DISPLAY === ###
# The list of all users
dom.USERS = ->
    c = fetch "/current_user"
    # TODO: allow viewing users with tags?

    # Default to New sorting
    @local.sort ?= "top"
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
            width: outer_width

            ["top", "new", "old"].map (s) =>
                BUTTON
                    key: s
                    className: "unbutton"
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

    register_window_event "user-expand-#{user?.key ? user}", "mousedown", (e) =>
        # should we preventdefault?
        unless @refs?.container?.getDOMNode?()?.contains?(e.target)
            @local.expanded = false
            save @local

    DIV
        margin: "5px 0"
        padding: "5px 0"
        boxShadow: if @local.expanded then "rgba(0, 0, 0, 0.2) 0px 1px 5px 1px"
        ref: "container"
        DIV
            key: "user-main"
            display: "grid"
            className: "user-main-grid"
            width: "min(#{outer_width - 100}px, calc(100vw - 50px))"
            grid: "\"icon name slider more\" auto
                   \"icon joined slider more\" 16px
                    / 50px 1fr #{slider_width}px 50px"
            alignItems: "center"

            AVATAR
                key: "avatar"
                user: user
                width: post_height - 5
                height: post_height - 5
                style:
                    gridArea: "icon"
                    alignSelf: "center"
                    justifySelf: "center"
                    borderRadius: "50%"

            SPAN
                key: "name"
                gridArea: "name"
                className: "post-title"
                fontSize: "18px"
                paddingRight: "10px"
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
                className: "grid-slider"
                gridArea: "slider"
                alignSelf: "start"
                height: slider_height + 5
                # TODO: Create a UI for viewing users wrt a tag
                SLIDERGRAM
                    key: "slidergram"
                    sldr: "/votes/#{unslash user.key}(untagged)"
                    width: slider_width
                    height: slider_height
                    max_avatar_radius: slider_height / 2.5
                    read_only: !c.logged_in
                    vote_key: "user_key"
                    onsave: (vote) =>
                        vote.key = "#{c.user.key}/vote/#{unslash user.key}"
                        vote.target_key = user.key
                        save vote

            BUTTON
                key: "more"
                ref: "more"
                gridArea: "more"
                color: "#999"
                className: "material-icons-outlined md-dark unbutton"
                fontSize: "24px"
                textAlign: "center"
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"

        if @local.expanded
            DIV
                key: "details"
                margin: "5px 50px"
                display: "flex"
                flexDirection: "row"
                justifyContent: "flex-end"

                TAGS
                    key: "tags"
                    post: user

### === SEARCHING === ###

# A big searchbar widget
dom.SEARCH_BOX = ->
    v = fetch "view"

    search = () =>
        v.query = @local.query
        save v

    @local.query ?= v.query
    save @local

    DIV
        display: "flex"
        flexDirection: "row"
        justifyContent: "stretch"
        padding: 10
        width: inner_width

        INPUT
            key: "searchbox"
            ref: "searchbox"
            value: @local.query
            flexGrow: 1
            fontSize: 18
            lineHeight: 1.4
            padding: "2px 4px"
            onChange: (e) =>
                @local.query = e.target.value
                save @local
            onKeyDown: (e) -> if e.keyCode == 13 then search()

        BUTTON
            key: "submit"
            onClick: search
            marginLeft: 10
            fontSize: 16
            lineHeight: 1.4
            padding: "4px 8px"

            "Search"
        
    
# Search results
dom.POSTS_SEARCH = ->
    c = fetch "/current_user"
    v = fetch "view"


    username = v.user_key ? c?.user?.key ? "/user/default"
    score_kson = stringify_kson user: username

    min_weight = (fetch "filter").min ? -0.2
    # Should we even do filtering in search?
    posts = ((fetch "/posts").arr ? [])
        .filter (p) -> ((fetch("score#{p.key}#{score_kson}").value ? 0) > min_weight) and
                       (v.query.length) and
                       (p.title.toLowerCase().includes v.query.toLowerCase())
    
    DIV
        key: "posts"
        posts.map (post) ->
            POST
                post: post.key
                key: unslash post.key

# filter
dom.FILTER = ->
    
    filter = fetch "filter"
    @local.filter_val ?= (Math.sqrt Math.abs(filter.min ? 0)) * Math.sign(filter.min ? 0)
    if isNaN(@local.filter_val) then @local.filter_val = 0

    register_window_event "filter", "mouseup", (e) =>
        if @local.mouse_down
            @local.mouse_down = false
            save @local
            filter.min = Math.pow(@local.filter_val, 3)
            save filter

    DIV
        key: "container"
        style: @props.style
        display: "flex"
        maxWidth: 600
        marginLeft: 20
        marginBottom: 10
        color: "#666"

        # filter slider
        LABEL
            key: "filter-text"
            gridArea: "filter-label"
            marginRight: 5
            "Filter (min score): "

        INPUT
            key: "filter-range"
            gridArea: "filter-range"
            ref: "filter-range"
            type: "range"
            value: @local.filter_val
            min: -Math.sqrt 10
            max: Math.sqrt 10
            step: "any"
            flexGrow: 1

            onChange: (e) =>
                @local.filter_val = e.target.value
                save @local

            onMouseDown: () =>
                @local.mouse_down = true
                save @local

        SPAN
            key: "filter-val-precise"
            gridArea: "filter-text"
            marginLeft: 5
            Number(Math.pow(@local.filter_val, 2) * Math.sign @local.filter_val ).toFixed 2


dom.AUTOSIZEBOX = ->
    props = bus.clone @props
    props.ref = 'textbox'
    props.rows = 1
    delete props['data-widget']
    delete props['data-key']

    # We now disable the vertical scrollbar, because it takes up horizontal
    # space, which changes the width of the textarea, which affects line
    # wrapping of the content, which makes the element taller than necessary
    # until we make it big enough that the scrollbar can disappear, at which
    # point it'll remain too tall.
    props.overflowY = 'hidden'

    TEXTAREA props

dom.AUTOSIZEBOX.up = ->
    target = @refs.textbox.getDOMNode()
    document.fonts.ready.then () -> 
        target.style.height = target.scrollHeight + "px"

    target.addEventListener 'input', resizebox, false

dom.AUTOSIZEBOX.refresh = ->
    target = @refs.textbox.getDOMNode()
    resizebox target: target
  
resizebox = (e) ->
    document.fonts.ready.then () ->
        e.target.style.height = "auto"
        e.target.style.height = e.target.scrollHeight + "px"
