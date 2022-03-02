
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

  name = user.name or user.invisible_name or 'Anonymous'
  extend @props,
    'data-user': name
    'data-showtooltip': !@props.hide_tooltip
    'data-color': @props.color
    'draggable': 'false'

  name = name.split(' ')
  if @props.hide_tooltip && !user.key == your_key()
    @props.title = name

  if user.pic
    @props.src ||= user.pic

    if @props.src.indexOf('/') == -1 && default_path
      @props.src = "#{default_path}/#{@props.src}"

    IMG @props
  else

    if add_initials
      if name == 'Anonymous'
        name = '?'
      if name.length == 2
        name = "#{name[0][0]}#{name[1][0]}"
      else
        name = "#{name[0][0]}"

    SPAN @props,

      if add_initials
        SPAN
          key: 'initials'
          className: 'initials'
          style:
            fontSize: (@props.style?.width or 50) / 2
            lineHeight: 2
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
  } span[data-widget='AVATAR'] {
    background-color: #62B39D;
    text-align: center;
    display: inline-block;
  } span[data-widget='AVATAR'] .initials {
    color: white;
    pointer-events: none;
    display: block;
    position: relative;
    font-family: monaco,Consolas,"Lucida Console",monospace;
  }
"""

document.head.appendChild style


##########
# Performance hack.
# Was seeing major slowdown on pages with lots of avatars simply because we
# were attaching a mouseover and mouseout event on each and every Avatar for
# the purpose of showing a tooltip name. So we use event delegation instead. 
document.addEventListener "mouseover", (e) ->
  return if !create_tooltip?
  if e.target.getAttribute?('data-user') && e.target.getAttribute?('data-showtooltip') == 'true'
    name = e.target.getAttribute('data-user')
    create_tooltip name, e.target, 
      backgroundColor: "white"
      color: '#444'
      opacity: 0.9
      fontSize: 14
      padding: '2px 4px'
      maxWidth: 200
      whiteSpace: 'nowrap'

document.addEventListener "mouseout", (e) ->
  return if !clear_tooltip?
  if e.target.getAttribute?('data-user') && e.target.getAttribute('data-showtooltip') == 'true'
    clear_tooltip()

create_tooltip = (text, target, style) ->

    tooltip = fetch "tooltip"

    tooltip.hidden = false
    tooltip.style = style ? {}
    tooltip.text = text

    # Compute the position of the tooltip
    bbox = target.getBoundingClientRect()
    tooltip.x = bbox.x + bbox.width/2 + window.scrollX
    tooltip.y = bbox.bottom + window.scrollY

    save tooltip

clear_tooltip = ->
    tooltip = fetch "tooltip"
    tooltip.hidden = true
    save tooltip

