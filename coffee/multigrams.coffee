DEFAULT_SLIDER_VAL = 0.5
SLIDER_COLOR = '#999'
feedback_orange = '#F19135'
considerit_salmon = '#F45F73'


get_target_slide = (sldr, target) ->
    sldr = fetch sldr
    target_slide = null
    for v in (sldr.values or [])
        if v?.target == target
            target_slide = v
            break
    target_slide


dom.MULTIGRAM = ->
    sldr = fetch @props.sldr
    local_sldr = fetch shared_local_key sldr

    DIV
        display: 'flex'
        flexDirection: 'column'
        marginBottom: 16

        onMouseOver: (e) =>
            if e.target.getAttribute?('data-target')
                target = e.target.getAttribute?('data-target')
                local_sldr.hover_target = target
                local_sldr.hover = true
            else
                local_sldr.hover = false
            save local_sldr

        onMouseOut: (e) =>
            local_sldr.hover = false
            save local_sldr


        MULTIHISTOGRAM
            width: @props.width
            height: @props.height
            sldr: sldr
            read_only: @props.read_only
            max_avatar_radius: @props.max_avatar_radius

        SLIDER_BOTTOM
            sldr: sldr
            width: @props.width
            linewidth: 3
            target: if local_sldr.dragging then local_sldr.target else local_sldr.hover_target
            feedback: !@props.no_feedback and (local_sldr.dragging or local_sldr.hover)
            handleheight: Math.min((@props.height ? 100) / 4, 20)
            handleoffset: 3
                

#########
# start_slide_target
#
# Initiates a user moving themself on a slider, either invoked 
# via mouse tracking or by dragging. 
#
# Supports movement by touch, mouse, and click events. 
start_slide_target = (sldr, slidergram_width, target, args) ->
    sldr = fetch(sldr)
    local = fetch shared_local_key(sldr)

    return if !your_key()

    targeted_slide = get_target_slide sldr, target
    val = if targeted_slide then targeted_slide.value else DEFAULT_SLIDER_VAL
    target_sldr = sldr

    local.dragging = true
    # We won't bother unsetting this, as it suffices to check local.dragging to see if something is targeted.
    local.target = target

    local.mouse_positions = [{x: mouseX, y: mouseY}]
    # adjust for starting location - offset
    local.x_adjustment = val * slidergram_width - local.mouse_positions[0].x

    save local
    key = md5([slidergram_width, local.height])

    # Do an initial save of the target_slider to get it to hover
    target_slide = get_target_slide target_sldr, target
    local.layout[target] =
        left: (val * slidergram_width) - 35
        top: (local.height - 70)/2
        width: 70

    save target_sldr

    # Mouse MOVE events
    mousemove = (e) ->
        e.preventDefault()
        x = mouseX
        y = mouseY
        local.mouse_positions.push {x, y}

        i = local.mouse_positions.length - 1

        dx = local.mouse_positions[i].x - local.mouse_positions[i-1].x

        if dx != 0 
            # Update position
            x = x + local.x_adjustment
            x = if x < 0
                    0
                else if x > slidergram_width
                    slidergram_width
                else
                    x
            target_slide = get_target_slide target_sldr, target
            if !target_slide
                target_slide =
                    target: target
                    explanation: ''
                    size: {}

                target_sldr.values.push target_slide

            # normalize position of handle into slider value
            target_slide.value = x / slidergram_width
            target_slide.value = Math.round(target_slide.value * 10000) / 10000
            target_slide.updated = (new Date()).getTime()

            local.layout[target]  =
                left: x - 35
                top: (local.height - 70)/2
                width: 70

            #if local.tracking_mouse != 'tracking'
            #    local.dirty_opinions = true

            save local
            save target_sldr
            saw_thing target_sldr

    register_window_event "slide-#{local.key}", 'mousemove', mousemove
    register_window_event "slide-#{local.key}", 'touchmove', mousemove

    # Mouse UP events
    mouseup = (e) ->
        saw_thing(sldr)
        stop_slider_dragging(sldr)

    register_window_event "slide-#{local.key}", 'mouseup', mouseup
    register_window_event "slide-#{local.key}", 'touchend', mouseup

    # Touch CANCEL events
    register_window_event "slide-#{local.key}", 'touchcancel', (e) ->
        e.preventDefault()
        stop_slider_dragging(sldr)

stop_slider_dragging = (sldr) ->
    local = fetch shared_local_key(sldr)
    unregister_window_event("slide-#{local.key}")
    local.x_adjustment = local.mouse_positions = local.dragging = null
    save local


# Extend a React component's props with implements_slide_target in order to make it 
# act like a slider handle
implements_slide_target = (sldr, target, width, props) ->
  extend props,
    onMouseDown: (e) -> e.preventDefault(); start_slide_target(sldr, width, target)
    onTouchStart: (e) -> e.preventDefault(); start_slide_target(sldr, width, target)
  props


####
# Histogram
#
# Controls the display of the users arranged on a histogram. 
# 
# The user avatars are arranged imprecisely on the histogram
# based on the user's opinion, using a physics simulation. 

dom.MULTIHISTOGRAM = ->
  sldr = fetch @props.sldr
  sldr.values ||= []
  local_sldr = fetch shared_local_key sldr
  local_sldr.layout ?= {}
  
  # Put the height on so that start_slide_target can properly position the elements
  local_sldr.height = @props.height
  save local_sldr

  @calcRadius = @props.calculateAvatarRadius or calculateAvatarRadius

  dragging = local_sldr.dragging

  DIV extend( props,
    key: 'histo'
    className: 'histogram'
    style:
      width: @props.width
      height: @props.height
      position: 'relative'
      userSelect: 'none'
    ),

    # Draw the avatars in the histogram. Placement will be determined later
    # by the physics sim
    for opinion in sldr.values
        #continue if !opinion.user || (opinion_weights && opinion.user not of opinion_weights ) # && you != opinion.user)
        continue if opinion.type == "me"

        size = local_sldr.layout[opinion.target]
        
        dragged = local_sldr.target == opinion.target
        props =
            key: "histo-avatar-#{opinion.target}"
            user: opinion.target
            className: "grab_cursor"
            vote_target: opinion.target
            hide_tooltip: dragging and !dragged
            "data-selected": dragging and dragged
            "data-target": opinion.target
            style:
                # cached width/height/left/top
                width: size?.width or 50
                height: size?.width or 50
                transform: "translate(#{size?.left or 0}px, #{size?.top or 0}px)"
                transformOrigin: "top left"
                transition: unless (dragging and dragged) then "transform 0.3s cubic-bezier(0.32, 0, 0.67, 0)"
                zIndex: if dragged then 5
                opacity: if (dragging or opinion.type?) and !dragged then 0.4
                filter: if (dragging or opinion.type?) and !dragged then 'grayscale(80%)'
                border: "2px solid"
                boxSizing: "border-box"
                borderColor: if (dragging and dragged) then "rgba(0, 80, 130, 0.2)" else "rgba(0, 0, 0, 0)"
                cursor: "pointer"

        props = implements_slide_target sldr, opinion.target, @props.width, props

        AVATAR props


dom.MULTIHISTOGRAM.refresh = ->

  sldr = fetch @props.sldr
  local_sldr = fetch(shared_local_key(sldr))
  c = fetch "/current_user"
  dragging = local_sldr.dragging

  cache_key = md5([@props.width, @props.height, sldr.values, sldr.dragging ? 0, sldr.target ? 0, c.user?.key ? 0])

  if sldr.values?.length > 0 && (cache_key != @last_cache || local_sldr.dirty_opinions) && !@loading()
    local_sldr.dirty_opinions = false
    save local_sldr

    vals_weight = sldr.values
        .map (v) ->
            vv = Object.assign({}, v)
            if vv.type == "remote"
                vv.weight = 0.1
            else
                factor = Math.abs(vv.value - 0.5) * 1.8 + 0.1
                if vv.type == "network"
                    factor /= 2
                vv.weight = factor
            vv
        .filter (v) -> !(dragging and v.target == local_sldr.target)

    packing_radius = @calcRadius(@props.width, @props.height, vals_weight, @props.max_avatar_radius)

    radii = {}
    vals_weight.forEach (vote) ->
        radii[vote.target] = Math.sqrt(vote.weight) * packing_radius

    # Tell positionavatars to ignore the currently-dragged avatar
    ignore = {}
    ignore[local_sldr.target ? ""] = true

    positionAvatars
      sldr: sldr
      width: @props.width
      height: @props.height
      default_radius: packing_radius
      radii: radii
      vote_key: "target"
      ignore: if dragging then ignore

    @last_cache = cache_key

    
style = document.createElement "style"
style.id = "multihistogram-styles"
style.innerHTML =   """
[data-widget='MULTIHISTOGRAM'] [data-widget='AVATAR'] {
    position: absolute;
    border-radius: 50%;
    background-color: #ccc;
}
[data-widget='MULTIHISTOGRAM'] span[data-widget='AVATAR'] {
    text-align: center;
    background-color: #aaa;
}
"""
document.head.appendChild style
