dom.AVATAR = -> 
    return SPAN null if !@props.user

    @props.style ||= {}
    @props.hide_tooltip ||= false
    @props.key ||= "avatar-#{@props.user.key or @props.user}"
    

    user = @props.user
    if (typeof @props.user == 'string') or @props.user.key
        user = fetch(@props.user)
    # else it is a connection possibly just with a name
    
    add_initials = @props.add_initials ? !user?.pic
    name = user.name ? user.invisible_name ? user.key.substr(1 + user.key.indexOf("/", 2)) ? 'Anonymous'
    extend @props,
        'data-user': name
        'data-showtooltip': !@props.hide_tooltip
        'data-color': @props.color
        'draggable': 'false'
    @props.style["--label"] = "\"#{name}\""
    @props.style.color ?= "white"

    name = name.split(' ')
    if @props.hide_tooltip && !user.key == your_key()
        @props.title = name

    if user.pic
        src = user.pic

        if src.indexOf('/') == -1 && default_path
            src = "#{default_path}/#{src}"
        @props.style["backgroundImage"] = "url(\"#{src}\")"
        @props.style["backgroundColor"] = "white"

    if add_initials
        if name == 'Anonymous'
            name = '?'
        if name.length == 2
            name = "#{name[0][0]}#{name[1][0]}"
        else
            name = "#{name[0][0]}"

    SPAN @props,
    
        SPAN
            key: 'initials'
            className: 'initials'
            style:
                fontSize: (@props.style?.width ? 50) / 2
                lineHeight: 2
                display: "block"
                opacity: unless add_initials then 0
            name


dom.AVATAR_WITH_SLIDER = ->

    SPAN
        key: "container"
        style: {
            @props.style...,
            position: "relative",
            width: @props.width
            height: @props.height
            cursor: if @props.clickable then "pointer"
        }

        if @props.clickable
            # When clicked, we want to display the slider
            onClick: (e) =>
                @local.user_slide = !(@local.user_slide ? false)
                save @local
            # When hovered, we want to show a slider icon
            onMouseOver: (e) =>
                @local.hover = true
                save @local
            onMouseLeave: (e) =>
                @local.hover = false
                save @local

        AVATAR
            user: @props.user
            hide_tooltip: @local.user_slide
            style:
                width: @props.width
                height: @props.height
                borderRadius: "50%"

        if @local.user_slide
            # How do we put a slider here??? lmao
            DIV
                key: "individual-user-slider"
                position: "relative"
                zIndex: 3
                whiteSpace: "nowrap"
                "This should be a slider..."

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
default_path = window.avatar_default_path or get_script_attr('avatar', 'default-path')
