# TODO: These should be arguments for the relevant elements
# TODO: Should UI elements fetch global state or take arguments?
body_width = 800
margin_left = 40
post_width = 525
slider_width = body_width - 2*margin_left - post_width - 10

# The layout for a single post, including slidergram and such
dom.POST = ->
    post = @props.post
    # Subscribe to the post
    if post.key then fetch post
    unless post.user?
        # The post has actually just been deleted.
        return

    author = fetch post.user

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
    
    #time_string = ""
    #delta = Date.now() / 1000 - post.time
    #if delta > 60 * 60 * 24
    #    time_string = "#{Math.floor(delta / (60 * 60 * 24))} days"
    #else if delta > 60 * 60
    #    time_string = "#{Math.floor(delta / (60 * 60))} hours"
    #else if delta > 60
    #    time_string = "#{Math.floor(delta / 60)} minutes"
    #else
    #    time_string = "#{Math.floor(delta)} seconds"
    time_string = prettyDate(post.time * 1000)


    user_clickable = c.logged_in and (c.user.key != author.key)

    DIV
        key: "post-container-#{post.key}"
        marginTop: "10px"
        marginBottom: "10px"
        DIV
            key: "post-main"
            display: "grid"
            grid: "\"icon title slider more\" auto
                   \"icon domain_time slider more\" 16px
                    / #{margin_left}px #{post_width + 10}px 1fr #{margin_left}px"
            alignItems: "center"

            AVATAR_WITH_SLIDER
                key: "avatar"
                user: author
                clickable: user_clickable
                width: margin_left - 10
                height: margin_left - 10
                style:
                    gridArea: "icon"
                    zIndex: 5
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
           
            # TODO: Use the information in `view` to display a topical slidergram
            DIV
                key: "post-votes-slider"
                gridArea: "slider"
                alignSelf: "start"
                height: margin_left - 10
                if v.selected?.type == "tag"
                    SLIDERGRAM_WITH_TAG
                        post: post
                        tag: unslash v.selected._key
                        width: slider_width
                        height: margin_left - 5
                        max_avatar_radius: (margin_left - 5) / 2
                        read_only: !c.logged_in
                else
                    SLIDERGRAM
                        sldr: "/votes_on#{post.key}"
                        width: slider_width
                        height: margin_left - 5
                        max_avatar_radius: (margin_left - 5) / 2
                        read_only: !c.logged_in
                        vote_key: "user"
                        onsave: (vote) =>
                            vote.key = "/votes/_#{unslash c.user.key}_#{unslash post.key}_"
                            vote.target = post.key
                            save vote

            SPAN
                key: "more"
                color: "#999"
                className: "material-icons md-dark"
                fontSize: "24px"
                cursor: "pointer"
                textAlign: "end"
                gridArea: "more"
                onClick: () => 
                    @local.expanded = !@local.expanded
                    save @local
                if @local.expanded then "expand_less" else "expand_more"

        if @local.expanded
            POST_DETAILS
                post: post

dom.POST_DETAILS = ->
    post = fetch @props.post
    c = fetch "/current_user"
    # Cache this?
    potential_tags = (fetch "/feeds").all.filter (f) =>
        f.type == "tag" and (unslash f._key) not in (post.tags || [])
    max_suggestions = @props.max_suggestions ? 4
    # Setup default values in @local
    @local.selected_idx ?= -1
    @local.tagsearch ?= []
    @local.typed ?= ""
    @local.addtagvisible ?= false
    save @local
    DIV
        key: "post-dropdown"
        padding: "10px #{margin_left/2}px"
        margin: "0 #{margin_left/2}px"
        border: "2px solid #999"
        borderTop: "none"
        borderRadius: "0 0 10px 10px"
        display: "flex"
        flexDirection: "row"
        justifyContent: "space-between"
        alignContent: "stretch"

        ###
        if c.logged_in and c.user.key == author.key then SPAN
            key: "delete-btn"
            color: "#999"
            className: "material-icons md-dark"
            fontSize: "24px"
            cursor: "pointer"
            textAlign: "end"
            gridArea: "del"
            onClick: () =>
                delete_post(post)
            "delete"
        ###
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
                                        v.value = @local.tagsearch[@local.selected_idx].name
                            # Tab 
                            when 9
                                e.preventDefault()
                        save @local
                    # Handle actual text entry
                    onInput: (e) =>
                        v = @refs.addlabel.getDOMNode().value.toString().toLowerCase()
                        @local.typed = v
                        @local.tagsearch = potential_tags.filter((t) => t.name.startsWith v)
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
                        post.tags.push box.value.toString().toLowerCase()
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
                    key: "#{suggested._key}-res"
                    display: "contents"

                    SPAN key: "dummy1"

                    SPAN
                        key: "res"
                        cursor: "pointer"
                        className: "hover-select"
                        lineHeight: "24px"
                        color: "#444"
                        background: if selected then "#eee"
                        onClick: (e) =>
                            # Save text of the selected result in the widget state
                            @refs.addlabel.getDOMNode().value = suggested.name
                            @local.selected_idx = i
                            save @local

                        suggested.name

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
                        fontSize: 20
                        textTransform: "capitalize"
                        color: "#444"
                        "#{tag}:"

                    SLIDERGRAM_WITH_TAG
                        post: post
                        tag: tag
                        width: slider_width
                        height: margin_left - 5
                        max_avatar_radius: (margin_left - 5) / 2
                        read_only: !c.logged_in


#TODO: sometimes, The first time a vote on a slidergram is changed, it takes two clicks to show up


dom.HEADER = ->
    # view state contains information about whatever the current view is
    # In the future, we'll create a type of state that can be "viewed" (such as a project, user, or tag), and the HEADER will recieve that as a paremeter...
    v = fetch "view"
    c = fetch "/current_user"

    if v?.selected?.type == "user" and not v?.selected?.name
        v.selected.name = (fetch v.selected._key).name
        save v

    feed_name = switch
        when v?.selected?.type == "tag" then v.selected.name
        when v?.selected?.type == "user" then "#{v.selected.name}'s"
        when c.logged_in then "Your"
        else "PeeryView"
   
    DIV
        key: "header"
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

            SPAN
                key: "title"
                fontSize: 36
                flexGrow: 1
                "#{feed_name} feed"

            SPAN
                key: "home"
                margin: 10
                cursor: "pointer"
                onClick: () =>
                    load_path "/"
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
                when "post" then SUBMIT_POST(close: close)
                when "settings" then SETTINGS(close: close)
                when "login" then LOGIN(close: close)
                when "feeds" then FEEDS()



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
               "email email" 32px
               "register login" 24px
                / auto auto'
        gap: "6px"
        DIV
            gridArea: "error"
            display: "none" unless c.error
            fontSize: "12px"
            color: "red"
            c.error
        INPUT
            id: "login-name"
            ref: "login-name"
            placeholder: "Username"
            gridArea: "name"
        INPUT
            id: "login-pw"
            ref: "login-pw"
            placeholder: "Password"
            gridArea: "pw"
            type: "password"
        INPUT
            id: "login-email"
            ref: "login-email"
            placeholder: "Email"
            gridArea: "email"
            type: "email"

        BUTTON {
            gridArea: "register"
            button_style...

            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                em = @refs["login-email"].getDOMNode().value
                c.create_account =
                    name: name
                    pass: pw
                    email: em
                save c

                # I want to also log in here. But doing it naively will cause a race condition,
                # Maybe we can set a one-time to_save handler?
                #c.login_as =
                #    name: name
                #    pass: pw
                #save c

                @props.close?()
            },
            "Register"

        BUTTON {
            gridArea: "login"
            button_style...
            onClick: (e) =>
                name = @refs["login-name"].getDOMNode().value
                pw = @refs["login-pw"].getDOMNode().value
                c.login_as =
                    name: name
                    pass: pw
                save c

                @props.close?()

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
            gridArea: "nametag"
            color: "#333"
            fontSize: "12px"
            "Name"
        INPUT
            gridArea: "namefield"
            ref: "name"
            value: c.user.name
            id: "name-change"

        DIV
            gridArea: "emailtag"
            color: "#333"
            fontSize: "12px"
            "Email"
        INPUT
            gridArea: "emailfield"
            ref: "email"
            value: c.user.email
            id: "email-change"
            type: "email"

        DIV
            gridArea: "pictag"
            color: "#333"
            fontSize: "12px"
            "Avatar URL"
        INPUT
            gridArea: "picfield"
            ref: "pic"
            value: c.user.pic
            placeholder: "http://..."
            id: "pic-change"
        DIV
            gridArea: "filtertag"
            color: "#333"
            fontSize: "12px"
            "Min post score"
        INPUT
            gridArea: "filterfield"
            ref: "filter"
            value: c.user.filter
            placeholder: -0.2
            id: "filter-change"
            type: "number"
            step: 0.1


        BUTTON
            gridArea: "cancel"
            onClick: () => @props.close?()
            "Cancel"

        BUTTON
            gridrea: "logout"
            onClick: () =>
                @props.close?()
                c.logout = true
                save c
            "Logout"

        BUTTON
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
    feeds = (fetch "/feeds").all
    weights = fetch "/weights/#{unslash (c.user?.key ? 'user/default')}"
    # sort feeds to put the selected one first...
    feeds = feeds.sort((a, b) => 
        switch
            when a.type == "tag" and b.type == "tag" then 0
            when a.type == "tag" then -1
            when b.type == "tag" then 1
            else (weights[a._key] ? 0) - (weights[b._key] ? 0)
        ).filter (a) => a._key != c.user?.key
        #switch
        #    when a.key == v.selected then -10
        #    when b.key == v.selected then 10
        #    else (weights[a.key] ? 0) - (weights[b.key] ? 0)
    DIV
        key: "feeds-scroll-list"
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


        feeds.map (feed) =>
            selected = v.selected?._key == feed._key
            type = feed.type

            DIV
                key: "feed-#{type}-#{feed._key}"
                display: "contents"
                cursor: "pointer"
                color: if selected then "#179"
                onClick: () =>
                    v.selected = if selected then false else feed
                    # Update the url... todo: find a better way of doing this?
                    newpath = switch v?.selected?.type
                        when "user" then feed._key
                        when "tag" then "/tag#{feed._key}"
                        else "/"
                    change_path newpath
                    save v

                # TODO: How is an avatar rendered for something that isn't a user?
                if type == "user"
                    AVATAR
                        user: feed._key
                        key: "icon"
                        hide_tooltip: true
                        style:
                            width: 24
                            height: 24
                            borderRadius: "50%"
                else
                    DIV
                        key: "idk"
                        width: 24
                        textAlign: "center"
                        "#"

                SPAN
                    key: "type"
                    fontWeight: "bold"
                    textTransform: "capitalize"
                    "#{type}:"

                SPAN
                    key: "name"
                    textTransform: if type == "tag" then "capitalize"
                    feed.name
