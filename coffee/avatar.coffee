dom.AVATAR = -> 
    return SPAN null if !@props.user

    @props.style ||= {}
    @props.hide_tooltip ||= false
    

    user = @props.user
    if (typeof @props.user == 'string') or @props.user.key
        user = fetch(@props.user)
    # else it is a connection possibly just with a name

    
    name = user.name ? user.invisible_name ? user.key.substr(1 + user.key.indexOf("/", 2)) ? 'Anonymous'
    extend @props,
        'data-user': name
        'data-showtooltip': !@props.hide_tooltip
        'data-color': @props.color
        'draggable': 'false'
    @props.style["--label"] = "\"#{name}\""
    @props.style.color ?= "white"

    if @props.add_border and user.border
        delete @props.style.border
        @props.style = {
            @props.style...
            boxSizing: "border-box"
            borderStyle: "solid"
            borderWidth: "2px"
            borderColor: "rgba(0, 0, 0, 0.08)"
        }


    name = name.trim().split(' ')
    if @props.hide_tooltip && !user.key == your_key()
        @props.title = name

    # check if the image loaded properly
    img_loaded = (fetch "profile_pic#{user.key}")?.loaded ? false
    # add initials if explicitly set or if user 
    add_initials = @props.add_initials ? !(user?.pic and img_loaded)
    if user.pic and img_loaded
        src = user.pic

        @props.style.backgroundImage = "url(\"#{src}\")"
        @props.style.backgroundColor = "white"
        @props.style.backgroundClip = "padding-box"
        @props.style.zIndex ?= 2
    else
        # Generate a pseudorandom background color
        # But dHow can I make sure the background image is fully loaded?eterministic with respect to the user
        hue = parseInt(md5(user?.key ? name).substr(0, 2), 16)
        @props.style.backgroundColor ?= "hsl(#{hue},45%,70%)"
        @props.style.zIndex ?= 1

    if add_initials
        if name == 'Anonymous'
            name = '?'
        if name.length == 2
            name = "#{name[0][0]}#{name[1][0]}"
        else
            name = "#{name[0][0]}"

    SPAN {
            display: "flex"
            justifyContent: "center"
            alignItems: "center"
            flexShrink: 0
            userSelect: "none"
            @props...
        },
    
        SPAN
            key: 'initials'
            className: 'initials'
            style:
                fontSize: (@props.style?.width ? @props.width ? 50) / 2
                lineHeight: "1em"
                display: "block"
                opacity: unless add_initials then 0
            name


dom.AVATAR_WITH_SLIDER = ->

    c = fetch "/current_user"
    view = @props.view ? fetch "view"

    if @props.clickable
        register_window_event "close-slider-#{@props.user.key}", "mousedown", (e) =>
            # should we preventdefault?
            if @refs.avatar?.getDOMNode().contains e.target
                @local.modal = !(@local.modal ? false)
            else unless @refs.modal?.getDOMNode().contains e.target
                @local.modal = false
            save @local

    sldr_params = stringify_kson tag: view.tag, untagged: !view.tag
    vote_params = stringify_kson tag: view.tag

    SPAN
        style: {
            @props.style...
            position: "relative"
            width: @props.width
            height: @props.height
            cursor: if @props.clickable then "pointer"
        }

        if @props.clickable
            # When clicked, we want to display the slider
            #onClick: (e) =>
            #    @local.modal = !(@local.modal ? false)
            #    save @local
            # When hovered, we want to show a slider icon
            onMouseOver: (e) =>
                @local.hover = true
                save @local
            onMouseLeave: (e) =>
                @local.hover = false
                save @local

        AVATAR
            key: "the-avatar"
            ref: "avatar"
            user: @props.user
            hide_tooltip: @local.modal
            style:
                width: @props.width
                height: @props.height
                borderRadius: "50%"

        if @local.modal
            DIV
                key: "modal"
                ref: "modal"

                #display: "none" unless @local.modal

                marginTop: 5
                position: "relative"
                width: "fit-content"
                transform: "translateX(calc(#{@props.width / 2}px - 50%))"

                zIndex: 5
                padding: "8px 15px"
                background: "white"
                boxShadow: "rgba(0, 0, 0, 0.15) 0px 1px 5px 1px"


                SLIDERGRAM
                    key: "slidergram"
                    sldr: "/votes#{@props.user.key}#{sldr_params}"
                    width: @props.slider_width ? 150
                    height: 24
                    max_avatar_radius: 12
                    read_only: !c.logged_in
                    vote_key: "user_key"
                    onsave: (vote) =>
                        vote.key = "#{c.user.key}/vote#{@props.user.key}#{vote_params}"
                        vote.target_key = @props.user.key
                        if view.tag?
                            vote.tag = view.tag
                        save vote

#        SPAN
#            key: "hover-icon"
#
#            className: "material-icons md-light"
#            color: "red"
#
#            fontSize: @props.width / 2
#            lineHeight: "2"
#            left: 0
#
#            position: "absolute"
#            zIndex: 2
#
#            pointerEvents: "none"
#            opacity: unless @local.hover then 0
#
#            "linear_scale"

style = document.createElement "style"
style.id = "avatar-styles"
style.innerHTML =   """
  [data-widget='AVATAR'] {
    width: 50px;
    height: 50px;
    object-fit: cover;
  }
  span[data-widget='AVATAR'] {
    background-color: #62B39D;
    text-align: center;
    display: inline-block;
    background-size: cover;
    background-position: center;
  }
  span[data-widget='AVATAR'] .initials {
    color: inherit;
    pointer-events: none;
    display: block;
    position: relative;
    font-family: monaco,Consolas,"Lucida Console",monospace;
  }
  [data-widget='AVATAR']::after {
    content: var(--label);
    font-size: var(--label-size);
    background-color: white;
    opacity: 0.8;
    color: #444;
    z-index: 10;
    display: none;
    text-align: center;
    position: absolute;
    left: 50%;
    top: 105%;
    transform: translateX(-50%);

    width: -moz-fit-content;
    width: -webkit-fit-content;
    width: fit-content;

    padding: 1px 4px;
  }

  [data-widget='AVATAR'][data-showtooltip='true']:hover,
  [data-widget='AVATAR'][data-selected='true'] {
    opacity: 1 !important;
  }
  [data-widget='AVATAR'][data-showtooltip='true']:hover::after,
  [data-widget='AVATAR'][data-selected='true']::after {
    display: block;
  }


"""

document.head.appendChild style

# attempt to load the user's profile picture.
# this allows us to tell if the profile picture was blocked, or 404s
bus("profile_pic/user/*").to_fetch = (key, star, t) ->
    userid = "/user/#{star}"
    user = fetch userid
    cached = bus.cache[key]
    # if we haven't yet tried to load, try to load
    if user.pic and !cached?.tried
        # if we haven't loaded ten seconds from now, give up.
        timeout = setTimeout 10000, () ->
            # is this necessary to stop a potentially hung load attempt?
            delete img
            save
                key: key
                loaded: false
                tried: false
        # create an image object to listen to onload
        img = new Image()
        img.addEventListener 'load', () ->
            clearTimeout timeout
            # if we successfully loaded the image, save that
            save
                key: key
                loaded: true
                tried: true
        # put the eventlisteners on before we set the source
        # to be sure not to miss anything
        img.src = user.pic

    cached ? {key, loaded: false, tried: false}

