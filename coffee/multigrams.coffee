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
  local_sldr = fetch(shared_local_key(sldr))

  you = your_key()

  read_only = @props.read_only

  slidergram_width = @props.width
  svg_sides = slidergram_width / 2

  sldr.poles ||= ['-1','+1']

  # console.log 'RENDERING value', get_your_slide(sldr)?.value
    
  DIV
    style:
      #width: slidergram_width
      position: 'relative'
      #width: 9999 # so slider label doesn't wrap
      zIndex: if local_sldr.editing_label then 2 else 1
                # Set at least 1 so that when you hover over a slidergram that 
                # is below this post, the other post doesn't prevent mouseovers
                # on this slidergram. The 2 is for putting a slidergram being
                # edited above the other ones, so that the drop down label
                # selection works. 
      display: 'flex'
      flexDirection: 'row'
      alignItems: 'flex-end'
      paddingBottom: 32/2

    # on option-click, delete self (or slidergram as whole if already empty)
    onMouseEnter: (e) =>
      @local.hover = true
      save @local
    onMouseLeave: (e) =>
      @local.hover = false
      save @local

    if !@props.no_label && !@props.one_sided

      LABEL_TAG = @props.draw_label or (if @props.edit_label then BASIC_SLIDER_LABEL else STATIC_SLIDER_LABEL)
      DIV
        style:

          marginRight: 12
          marginBottom: -12

        LABEL_TAG
          style:
            fontSize: 14
            fontWeight: 400
            color:  @props.slider_color or SLIDER_COLOR

          key: sldr.key
          sldr: sldr
          height: @props.height
          text: sldr.poles[0]
          pole_idx: 0
          onInput: (e) =>
            sldr.poles[0] = e.target.innerHTML
            # save sldr


    DIV
      key: 'opinion_area'
      ref: 'opinion_area'
      style:
        flex: 2

      MULTIHISTOGRAM
        width: slidergram_width
        height: @props.height
        sldr: sldr
        read_only: read_only
        max_avatar_radius: @props.max_avatar_radius

      DIV # slider base
        style :
          width: slidergram_width
          position: 'relative'
          borderTop: "1.5px solid #{@props.slider_color or SLIDER_COLOR}"
          textAlign: 'left' # prevent inherited centering from happening


        # arrowtip
        SVG
          style:
            position: 'absolute'
            left: 0
            bottom: 0
          width: slidergram_width
          height: 5
          viewBox: "-#{svg_sides} 0 #{slidergram_width} 3"

          G
            fill: @props.slider_color or SLIDER_COLOR
            
            POLYGON
              points: "#{-svg_sides},0 #{-svg_sides},5 #{8 - svg_sides},5"

            POLYGON
              points: "#{svg_sides},0 #{svg_sides},5 #{svg_sides - 8},5"

            POLYGON
              points: "-4,5 0,0 4,5"


        if !@props.no_feedback
          SLIDER_FEEDBACK
            show_handle: @local.hover_opinion_area
            sldr: sldr
            color: considerit_salmon
            width: @props.width
            style:
              display: if !(@local.hover_opinion_area || \
                          local_sldr.dragging || local_sldr.tracking_mouse == 'activated') \
                        then 'none'

    if !@props.no_label

      LABEL_TAG = @props.draw_label or (if @props.edit_label then BASIC_SLIDER_LABEL else STATIC_SLIDER_LABEL)
      DIV
        style:
          marginLeft: 12
          marginBottom: -12

        LABEL_TAG
          style:
            fontSize: 14
            fontWeight: 400
            color:  @props.slider_color or SLIDER_COLOR
          key: sldr.key
          sldr: sldr
          height: @props.height
          pole_idx: 1
          text: sldr.poles[1]
          onInput: (e) =>
            sldr.poles[1] = e.target.innerHTML
            # save sldr

#########
# start_slide
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
    # How do I not do this part?
    target_sldr = sldr # save changes immediately to server  
    #target_sldr = local
    # extend local,
        #values: [{
        #  target: target
        #  value: val
        #}]

    local.dragging = true

    local.mouse_positions = [{x: mouseX, y: mouseY}]
    # adjust for starting location - offset
    local.x_adjustment = val * slidergram_width - local.mouse_positions[0].x

    save local

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

                target_sldr.values.push target_slide

            # normalize position of handle into slider value
            target_slide.value = x / slidergram_width
            target_slide.value = Math.round(target_slide.value * 10000) / 10000
            target_slide.updated = (new Date()).getTime()

            # console.log('DRAGGED TO ', your_slide.value)
            if local.tracking_mouse != 'tracking'
                local.dirty_opinions = true

            save target_sldr
            save local
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


##
# SliderHandle
#
# A little feedback on the slider that shows where you're dragging
dom.SLIDER_FEEDBACK = ->
  handle_height = @props.handle_height or 2
  handle_width = @props.handle_width or 1

  local_sldr = fetch shared_local_key(@props.sldr)

  val = if local_sldr.tracking_mouse
          local_sldr.values[0].value
        else #if local_sldr.dragging
          get_your_slide(@props.sldr)?.value or 0

  return SPAN null if val < 0 || val > 1.0

  DIV
    style: defaults @props.style,
      width: handle_width
      height: handle_height
      top: -2
      position: 'absolute'
      #marginLeft: -handle_width / 2
      zIndex: 1
      left: 0
      width: @props.width * val
      backgroundColor: @props.color or feedback_orange #focus_blue #'#666'


    if @props.show_handle
      @props.draw_handle?() or SVG defaults (@props.handle_attrs or {}),
        style:
          position: 'relative'
          left: @props.width * val - 14 / 2
        className: 'grab_cursor'
        width: 14
        height: 15
        viewBox: "0 0 14 15"
        dangerouslySetInnerHTML: __html: """
          <defs>
            <path d="M986,1295 L1000,1295 L1000,1303 L986,1303 L986,1295 Z M993,1309 L986,1303 L1000,1303 L993,1309 Z" id="path-1"></path>
            <filter x="-3.6%" y="-10.7%" width="107.1%" height="114.3%" filterUnits="objectBoundingBox" id="filter-2">
                <feOffset dx="0" dy="-1" in="SourceAlpha" result="shadowOffsetOuter1"></feOffset>
                <feColorMatrix values="0 0 0 0 0.641528486   0 0 0 0 0.236649693   0 0 0 0 0.29099584  0 0 0 1 0" type="matrix" in="shadowOffsetOuter1"></feColorMatrix>
            </filter>
          </defs>
          <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
              <g id="Desktop-HD-Copy-23" transform="translate(-986.000000, -1295.000000)">
                  <g id="Rectangle-7" transform="translate(993.000000, 1302.000000) scale(1, -1) translate(-993.000000, -1302.000000) ">
                      <use fill="black" fill-opacity="1" filter="url(#filter-2)" xlink:href="#path-1"></use>
                      <use fill="#F45F73" fill-rule="evenodd" xlink:href="#path-1"></use>
                  </g>
              </g>
          </g>
        """


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

  opinion_weights = fetch('opinion').weights

  @calcRadius = @props.calculateAvatarRadius or calculateAvatarRadius

  focus_on_dragging = local_sldr.dragging || local_sldr.tracking_mouse == 'activated'

  DIV extend( props,
    ref: 'histo'
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

        key = md5([@props.width, @props.height, opinion_weights])
        size = opinion.size?[key]

        props =
            key: "histo-avatar-#{opinion.target}"
            user: opinion.target
            className: "grab_cursor"
            vote_target: opinion.target
            hide_tooltip: focus_on_dragging
            style:
                # cached width/height/left/top
                width: size?.width or 50
                height: size?.width or 50
                left: size?.left or 0
                top: size?.top or 0

        props = implements_slide_target sldr, opinion.target, @props.width, props
        AVATAR props


dom.MULTIHISTOGRAM.refresh = ->

  sldr = fetch @props.sldr
  local_sldr = fetch(shared_local_key(sldr))

  opinion_weights = fetch('opinion').weights

  key = md5([@props.width, @props.height, opinion_weights])
  cache_key = ( Math.round(o.value * 100) / 100 for o in (sldr.values or []) ).join(' ')
  cache_key += key

  if sldr.values?.length > 0 && (cache_key != @last_cache || local_sldr.dirty_opinions) && !@loading()
    local_sldr.dirty_opinions = false
    save local_sldr

    
    if opinion_weights
      radii = {}
      avatars = (o for o in sldr.values when o.user of opinion_weights)
      avatar_radius = @calcRadius(@props.width, @props.height, avatars, @props.max_avatar_radius)
      for u, weight of opinion_weights
        radii[u] = weight * avatar_radius
    else
      radii = null
      avatar_radius = @calcRadius(@props.width, @props.height, sldr.values, @props.max_avatar_radius)


    positionAvatars
      positions: sldr
      width: @props.width
      height: @props.height
      default_radius: avatar_radius
      key: key
      radii: radii
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
