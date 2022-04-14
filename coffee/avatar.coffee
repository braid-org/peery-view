
default_path = window.avatar_default_path or get_script_attr('avatar', 'default-path')


dom.AVATAR = -> 
  return SPAN null if !@props.user

  @props.style ||= {}
  @props.hide_tooltip ||= false
  @props.key ||= "avatar-#{@props.user.key or @props.user}"

  add_initials = if !@props.add_initials? then true else @props.add_initials

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

  name = name.split(' ')
  if @props.hide_tooltip && !user.key == your_key()
    @props.title = name

  if user.pic
    src = user.pic

    if src.indexOf('/') == -1 && default_path
      src = "#{default_path}/#{src}"
    @props.style["backgroundImage"] = "url(\"#{src}\")"

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
        fontSize: (@props.style?.width or 50) / 2
        lineHeight: 2
        display: "block"
        opacity: if user.pic then 0
      name

    if @props.prompt_avatar && fetch('/current_user').user?.key == user.key
      DIV
        style:
          position: 'absolute'
          left: 0
          bottom: -30

        BUTTON
          style:
            textDecoration: 'underline'
            color: considerit_salmon
            fontSize: 13
            backgroundColor: 'transparent'
          onClick: =>
            auth = fetch 'auth'
            auth.form = 'upload_avatar'
            save auth
          'set your pic'


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
    color: white;
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
    position: relative;
    left: 50%;
    top: 1px;
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

