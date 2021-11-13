DEFAULT_SLIDER_VAL = 0.5
SLIDER_COLOR = '#999'
feedback_orange = '#F19135'
considerit_salmon = '#F45F73'

# Remove current user from this slider, if they're on it
window.remove_self_from_slider = (sldr) -> 
  sldr = fetch sldr
  return if !(sldr.selection or sldr.anchor)

  you = your_key()
  for o, idx in sldr.values
    if o.user == you 
      sldr.values.splice(idx, 1)
      save sldr
      break

# Delete slider + selection if no one has made a slider drag
# BUG: if someone else has slid the slider, but that slide 
#      hasn't been synchronized to this client yet, the slider
#      might be erroneously deleted
window.delete_slider_if_no_activity = (sldr) -> 
  sldr = fetch sldr
  return if !(sldr.selection or sldr.anchor or sldr.point)

  anchor = fetch(sldr.selection or sldr.anchor or sldr.point)

  if !sldr.values || sldr.values.length == 0
    idx = anchor.sliders.indexOf sldr.key 
    if idx > -1 
      anchor.sliders.splice(idx, 1)
      save anchor

    del sldr 





dom.SLIDERGRAM = -> 
  sldr = fetch @props.sldr
  local_sldr = fetch(shared_local_key(sldr))

  you = your_key()
  has_opined = you in (o.user for o in (sldr.values or []))

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
    onClick: (e) => 
      if e.altKey
        if sldr.values.length == 0
          delete_slider_if_no_activity(sldr)
        else 
          remove_self_from_slider(sldr)
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

      onMouseEnter: if !read_only then (e) => 
        @local.hover_opinion_area = true 
        save @local 
        if !has_opined && !local_sldr.tracking_mouse 
          x_entry = mouseX - @refs.opinion_area.getDOMNode().getBoundingClientRect().left
          start_slide sldr, @props.width, 'tracking', 
            initial_val: x_entry / slidergram_width
            slidergram_width: slidergram_width


      onMouseLeave: if !read_only then (e) => 
        @local.hover_opinion_area = false 
        save @local 

        # only remove if we haven't added ourselves
        if local_sldr.tracking_mouse == 'tracking'
          e.preventDefault()
          stop_slider_mouse_tracking(sldr)
      


      HISTOGRAM
        width: slidergram_width
        height: @props.height
        sldr: sldr
        show_ghosted_user: !has_opined && (local_sldr.tracking_mouse || @props.force_ghosting)
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




    if @local.hover && fetch('/permissions')[you] == 'admin'
      BUTTON
        style: 
          backgroundColor: 'transparent'
          color: '#ddd'
          fontSize: 10
          position: 'absolute'
          left: '100%'
          paddingLeft: 100 
          fontWeight: 'normal'
        onClick: => 
          if window.confirm('Are you sure?') 
            del sldr
        'Delete'


split_label = (label) ->
  first_part = ""
  second_part = ""

  idx = 0 
  while true 
    img = label.substring(idx).match(/^<img[^>]*(.*?)>(<\/img>)?/)?[0]
    if img 
      first_part += img 
      idx += img.length 
    else if label[idx] == ' '
      second_part = label.substring(idx + 1)
      break
    else 
      first_part += label[idx]
      idx += 1

    break if idx >= label.length 

  [first_part, second_part]

  



set_style """
  [data-widget='BASIC_SLIDER_LABEL'] .emojione {
    width: 32px; height: 32px;
    vertical-align: middle;
  }
"""
dom.BASIC_SLIDER_LABEL = ->

  sldr = fetch @props.sldr
  pole_idx = @props.pole_idx
  pole_idx ?= 1

  if !@local.text? or @props.text != @local.text
    @local.text = @props.text or sldr.poles?[pole_idx] or '+'

  if @local.text == 'undefined'
    @local.text = ''

  # The contenteditable label
  DIV
    key: 'content_editable_label' 
    ref: 'editor'
    spellCheck: false
    contentEditable: true
    style: defaults {}, (@props.style or {}),
      border: '1px solid'
      outline: 'none'
      #width: if @local.focused then 300 else 'auto'
      minHeight: 24 # firefox made short boxes when empty
      minWidth: 32
      whiteSpace: 'nowrap'
      borderColor: if @local.hovering
                     '#ddd'
                   else 
                     'transparent'

    onInput: @props.onInput or ((e) =>
      sldr.poles ||= ['','']
      old_text = sldr.poles[pole_idx]
      new_text = @refs.editor.getDOMNode().innerHTML
      sldr.poles[pole_idx] = new_text
      save sldr)

    onMouseEnter: =>
      @local.hovering = true
      save @local

    onMouseLeave: (e) => 
      @local.hovering = false
      save @local

    onFocus: (e) => 
      @local.focused = true 
      save @local 

    onBlur: (e) => 
      @local.focused = false
      @local.text = sldr.poles?[pole_idx] or @props.text or '+'
      save @local 
      save sldr

    dangerouslySetInnerHTML: if @local.text?.length > 0 then {__html: (if emojione? then emojione.unicodeToImage(@local.text) else @local.text)}



dom.STATIC_SLIDER_LABEL = ->

  sldr = fetch @props.sldr
  pole_idx = @props.pole_idx
  pole_idx ?= 1

  if !@local.text? or @props.text != @local.text
    @local.text = @props.text or sldr.poles?[pole_idx] or '+'

  if @local.text == 'undefined'
    @local.text = ''

  # noneditable
  DIV
    style: defaults {}, (@props.style or {}),
      #width: if @local.focused then 300 else 'auto'
      minHeight: 24 # firefox made short boxes when empty
      minWidth: "2ch"
      whiteSpace: 'nowrap'

    dangerouslySetInnerHTML: if @local.text?.length > 0 then {__html: (if emojione? then emojione.unicodeToImage(@local.text) else @local.text)}
      


#######
# Creates a slidergram
# args:
#    anchor: the thing against which this slidergram is reacting
#    poles: the endpoints
window.create_slidergram = (args) -> 
  anchor = args.anchor 
  if anchor && !anchor.key
    anchor = fetch anchor

  slidergram =  
    key: new_key('slider')
    anchor: if anchor then anchor.key
    poles: args.poles or ['', '']
    values: []

  save slidergram

  if anchor
    anchor.sliders ?= []
    anchor.sliders.push slidergram.key 
    save anchor
  slidergram





#########
# start_slide
#
# Initiates a user moving themself on a slider, either invoked 
# via mouse tracking or by dragging. 
#
# Supports movement by touch, mouse, and click events. 
start_slide = (sldr, slidergram_width, slide_type, args) -> 
  sldr = fetch(sldr)
  local = fetch shared_local_key(sldr)

  return if !your_key()

  if slide_type == 'dragging'
    your_slide = get_your_slide(sldr)
    val = if your_slide then your_slide.value else DEFAULT_SLIDER_VAL
    # How do I not do this part?
    target_sldr = sldr # save changes immediately to server  
    #target_sldr = local
    extend local,
      values: [{
        user: your_key(),
        value: val
      }]

    local.dragging = true

  else if slide_type == 'tracking'
    val = args.initial_val
    extend local,
      tracking_mouse: 'tracking'
      values: [{
        user: your_key(),
        value: val
      }]
    target_sldr = local  # don't propagate to server immediately

  local.mouse_positions = [{x: mouseX, y: mouseY}]
  # adjust for starting location - offset
  local.x_adjustment = val * slidergram_width - local.mouse_positions[0].x
  save local

  # Mouse DOWN events (only for tracking)
  if slide_type == 'tracking'
    mousedown = (e) ->
      e.preventDefault()
      local.tracking_mouse = 'activated'
      save local

    register_window_event "slide-#{local.key}", 'mousedown', mousedown
    register_window_event "slide-#{local.key}", 'touchstart', mousedown

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

      your_slide = get_your_slide(target_sldr)
      if !your_slide
        your_slide =
          user: your_key()
          explanation: ''

        target_sldr.values.push your_slide

      # normalize position of handle into slider value
      your_slide.value = x / slidergram_width
      your_slide.value = Math.round(your_slide.value * 10000) / 10000
      your_slide.updated = (new Date()).getTime()

      # console.log('DRAGGED TO ', your_slide.value)
      if local.tracking_mouse != 'tracking'
        local.dirty_opinions = true

      # console.log 'SAVING slide', your_slide.value
      save target_sldr
      save local
      saw_thing target_sldr

  register_window_event "slide-#{local.key}", 'mousemove', mousemove
  register_window_event "slide-#{local.key}", 'touchmove', mousemove

  # Mouse UP events
  mouseup = (e) -> 
    if slide_type == 'dragging'
      saw_thing(sldr)
      stop_slider_dragging(sldr)
    else if slide_type == 'tracking'
      # automatically start editing label if no one else is on the slider
      if local.is_new && sldr.poles?[1] == ''
        local.editing_label = true 
        save local      
      saw_thing(sldr)
      stop_slider_mouse_tracking(sldr)

  register_window_event "slide-#{local.key}", 'mouseup', mouseup
  register_window_event "slide-#{local.key}", 'touchend', mouseup

  # Touch CANCEL events
  if slide_type == 'dragging'
    register_window_event "slide-#{local.key}", 'touchcancel', (e) -> 
      e.preventDefault()
      stop_slider_dragging(sldr)
  else if slide_type == 'tracking'
    register_window_event "slide-#{local.key}", 'touchcancel', (e) -> 
        e.preventDefault()
        stop_slider_mouse_tracking(sldr, true)

stop_slider_dragging = (sldr) ->
  local = fetch shared_local_key(sldr)
  unregister_window_event("slide-#{local.key}")
  local.x_adjustment = local.mouse_positions = local.dragging = null 
  save local

stop_slider_mouse_tracking = (sldr, skip_save) -> 
  sldr = fetch(sldr)
  local_sldr = fetch(shared_local_key(sldr))
  unregister_window_event "slide-#{local_sldr.key}"
  return if !local_sldr.tracking_mouse

  # Well, the user has added themself to the slidergram!
  # Need to transfer from local_sldr to sldr 
  if !skip_save && local_sldr.tracking_mouse == 'activated'
    sldr.values.push local_sldr.values[0]
    save sldr 
    local_sldr.dirty_opinions = true 

  local_sldr.tracking_mouse = null
  save local_sldr


# Extend a React component's props with implements_slide_draggable in order to make it 
# act like a slider handle
implements_slide_draggable = (sldr, width, props) -> 
  extend props, 
    onMouseDown: (e) -> e.preventDefault(); start_slide(sldr, width, 'dragging')
    onTouchStart: (e) -> e.preventDefault(); start_slide(sldr, width, 'dragging')
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

dom.HISTOGRAM = -> 
  sldr = fetch @props.sldr 
  sldr.values ||= []
  local_sldr = fetch(shared_local_key(sldr))

  you = your_key?()
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
      continue if !opinion.user || (opinion_weights && opinion.user not of opinion_weights ) # && you != opinion.user)

      key = md5([@props.width, @props.height, opinion_weights])
      size = opinion.size?[key]
      is_you = opinion.user == you

      props = 
        key: "histo-avatar-#{opinion.user}"
        user: opinion.user
        hide_tooltip: focus_on_dragging        
        style: 
          # cached width/height/left/top
          width: size?.width or 50
          height: size?.width or 50
          left: size?.left or 0
          top: size?.top or 0
          opacity: if focus_on_dragging && !is_you then .2
          WebkitFilter: if focus_on_dragging && !is_you then 'grayscale(100%)'
          filter: if  focus_on_dragging && !is_you then 'grayscale(100%)'  


      if is_you && !@props.read_only
        # console.log "  RE-RENDERING @ #{opinion.value}"
        extend props, 
          className: 'you grab_cursor'
          hide_tooltip: true

        props = implements_slide_draggable sldr, @props.width, props


      AVATAR props


    if @props.show_ghosted_user

      r = @calcRadius(@props.width, @props.height, sldr.values, @props.max_avatar_radius)
      val = if local_sldr.values?[0]?
              local_sldr.values[0].value
            else 
              DEFAULT_SLIDER_VAL
      opaque = local_sldr.tracking_mouse == 'activated'

      left = within val * @props.width - r, 0, @props.width - 2 * r
      style = 
        position: 'absolute'
        left: left
        top: @props.height - r * 2
        width: r * 2
        height: r * 2
        backgroundColor: '#f1f1f1'
        borderRadius: '50%'
        zIndex: if !opaque then -1            
        opacity: .5 if !opaque 
        cursor: if !opaque then 'pointer'
        className: if opaque then 'grab_cursor'

      AVATAR
        className: 'you'
        user: you
        style: style
        hide_tooltip: true


dom.HISTOGRAM.refresh = ->

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
style.id = "histogram-styles"
style.innerHTML =   """
  [data-widget='HISTOGRAM'] [data-widget='AVATAR'] {
    position: absolute;
    border-radius: 50%;
    background-color: #ccc;
  } [data-widget='HISTOGRAM'] .you[data-widget='AVATAR'] {
    transition: none;
  } [data-widget='HISTOGRAM'] span[data-widget='AVATAR'] {
    text-align: center; 
    background-color: #aaa;
  }
"""
document.head.appendChild style


######
# Uses a physics simulation to calculate a reasonable layout
# of avatars within a given area.
#
# positions is a keyed-object: 
#    - positions.values has each of the avatars with their targeted x location
#    - client positions are saved on each avatar at .size

positionAvatars = (args) -> 
  positions = args.positions
  width = args.width
  height = args.height
  r = args.default_radius
  key = args.key
  radii = args.radii

  # One iteration of the simulation
  tick = (alpha) ->
    stable = true

    ####
    # Repel colliding nodes
    # A quadtree helps efficiently detect collisions
    q = quadtree(nodes)

    for n in nodes 
      q.visit collide(n, alpha)

    ####
    # apply forces
    for o, i in nodes
      o.px = o.x
      o.py = o.y

      # Push node toward its desired x-position
      o.x += alpha * (x_force_mult * width  * .001) * (o.x_target - o.x)

      # Push node downwards
      #o.y += alpha * y_force_mult * ( Math.max(1, 4 * o.radius * 2 / height + .5 ))
      o.y += alpha * y_force_mult

      # Ensure node is still within the bounding box
      if o.x < o.radius
        o.x = o.radius
      else if o.x > width - o.radius
        o.x = width - o.radius

      if o.y < o.radius
        o.y = o.radius
      else if o.y > height - o.radius
        o.y = height - o.radius

      dx = Math.abs(o.px - o.x)
      dy = Math.abs(o.py - o.y)

      if stable && Math.sqrt(dx * dx + dy * dy) > 1
        stable = false

    # Complete the simulation if we've reached a steady state
    stable

  collide = (p1, alpha) ->

    return (quad, x1, y1, x2, y2) ->
      p2 = quad.point
      if quad.leaf && p2 && p2 != p1
        dx = Math.abs (p1.x - p2.x)
        dy = Math.abs (p1.y - p2.y)
        dist = Math.sqrt(dx * dx + dy * dy)
        combined_r = p1.radius + p2.radius

        # Transpose two points in the same neighborhood if it would reduce 
        # energy of system
        if energy_reduced_by_swap(p1, p2) > 0
          swap_position(p1, p2)          

        # repel both points equally in opposite directions if they overlap
        if dist < combined_r
          separate_by = if dist == 0 then 1 else ( combined_r - dist ) / combined_r
          offset_x = (combined_r - dx) * separate_by
          offset_y = (combined_r - dy) * separate_by

          if p1.x < p2.x 
            p1.x -= offset_x / 2
            p2.x += offset_x / 2
          else 
            p2.x -= offset_x / 2
            p1.x += offset_x / 2

          if p1.y < p2.y           
            p1.y -= offset_y / 2
            p2.y += offset_y / 2
          else 
            p2.y -= offset_y / 2
            p1.y += offset_y / 2

      # Visit subregions if we could possibly have a collision there
      neighborhood_radius = p1.radius
      nx1 = p1.x - neighborhood_radius
      nx2 = p1.x + neighborhood_radius
      ny1 = p1.y - neighborhood_radius
      ny2 = p1.y + neighborhood_radius

      return x1 > nx2 || 
              x2 < nx1 ||
              y1 > ny2 ||
              y2 < ny1

  # Check if system energy would be reduced if two nodes' positions would 
  # be swapped. We square the difference in order to favor large differences 
  # for one vs small differences for the pair.
  energy_reduced_by_swap = (p1, p2) ->
    # how much does each point covet the other's location, over their own?
    p1_jealousy = (p1.x - p1.x_target) * (p1.x - p1.x_target) - \
                  (p2.x - p1.x_target) * (p2.x - p1.x_target)
    p2_jealousy = (p2.x - p2.x_target) * (p2.x - p2.x_target) - \
                  (p1.x - p2.x_target) * (p1.x - p2.x_target) 
    p1_jealousy + p2_jealousy

  # Swaps the positions of two avatars
  swap_position = (p1, p2) ->
    swap_x = p1.x; swap_y = p1.y
    p1.x = p2.x; p1.y = p2.y
    p2.x = swap_x; p2.y = swap_y 



  ##############
  # Initialize positions of each node
  targets = {}
  avatars = positions.values or positions.opinions
  if radii 
    avatars = (o for o in avatars when o.user of radii)

  n = avatars.length

  init = calculateInitialLayout width, height, r, avatars  

  nodes = avatars.map (o, i) ->
    x_target = o.value * width

    # if targets[x_target]
    #   if x_target > .99
    #     x_target -= .01 * Math.random() 
    #   else 
    #     x_target += .01 * Math.random() 

    if targets[x_target]
      if x_target > .98
        x_target -= .1 * Math.random() 
      else if x_target < .02
        x_target += .1 * Math.random() 

    targets[x_target] = 1

    rad = radii?[o.user] or o.r or r
    # Travis: I'm finding that different initial conditions work 
    # better at different scales.
    #   - Give large numbers of avatars some good initial spacing
    #   - Small numbers of avatars can be more precisely placed for quick 
    #     convergence with little churn  
    # x = if n > 10 
    #       rad + (width - 2 * rad) * (i / n) 
    #     else 
    #       x_target
    x = x_target
    y = height - init[o.user] - rad #rad

    return {
      index: i
      radius: rad
      x: x
      y: y
      x_target: x_target
    }

  ###########
  # run the simulation
  # stable = false
  # alpha = .25
  # x_force_mult = 2
  # y_force_mult = 10

  stable = false
  alpha = .8
  decay = .8
  min_alpha = 0.0000001
  x_force_mult = 2
  y_force_mult = 6

  total_ticks = 0
  ticks_per_timeout = 20

  next = -> 
    setTimeout -> 
      ticks = 0
      while ticks % ticks_per_timeout != ticks_per_timeout - 1

        num_unstable = 0
        stable = tick alpha
        alpha *= decay

        ticks += 1
        total_ticks += 1

        stable ||= alpha <= min_alpha
        break if stable 

      if stable
        done()
      else 
        next()

    , 1

  # while alpha > 0 && !stable
  #   stable = tick(alpha)
  #   alpha -= .001

  done = -> 
    ##############
    # cache the final locations on positions
    for avatar,i in avatars
      rad = nodes[i].radius

      avatar.size ||= {}

      avatar.size[key] = 
        left: nodes[i].x - rad
        top: nodes[i].y - rad
        width: 2 * rad

    save positions 

  next()



calculateInitialLayout = (w, h, r, avatars) -> 
  assignments = {}
  grid = {}

  r = 2 * r
  rows = Math.floor h / r

  for o in avatars 

    col = Math.floor o.value * w / r
    if !grid[col]?
      grid[col] = (0 for row in [0..rows])

    least_crowded_cell = null 
    least_crowded_cnt = Infinity
    for num,row in grid[col]
      if num == 0 
        # assign immediately
        least_crowded_cell = row
        break 
      else if num < least_crowded_cnt
        least_crowded_cnt = num 
        least_crowded_cell = row 

    grid[col][least_crowded_cell] += 1
    assignments[o.user] = least_crowded_cell * r

  assignments



#####
# Calculate node radius based on the largest density of avatars in an 
# area (based on a moving average of # of opinions, mapped across the
# width and height)

calculateAvatarRadius = (width, height, opinions, max_avatar_radius) -> 
  max_avatar_radius ?= Infinity

  opinions.sort (a,b) -> a.value - b.value

  # first, calculate a moving average of the number of opinions
  # across around all possible stances
  window_size = .1
  avg_inc = .01
  moving_avg = []
  idx = 0
  stance = 0
  sum = 0

  while stance <= 1.0

    o = idx
    cnt = 0
    while o < opinions.length

      if opinions[o].value < stance - window_size
        idx = o
      else if opinions[o].value > stance + window_size
        break
      else 
        cnt += 1

      o += 1

    moving_avg.push cnt
    stance += avg_inc
    sum += cnt

  # second, calculate the densest area of opinions, operationalized
  # as the region with the most opinions amongst all regions of 
  # opinion space that have contiguous above average opinions. 
  dense_regions = []
  avg_of_moving_avg = sum / moving_avg.length


  current_region = []
  for avg, idx in moving_avg
    reset = idx == moving_avg.length - 1
    if avg >= avg_of_moving_avg
      current_region.push idx
    else
      reset = true

    if reset && current_region.length > 0
      dense_regions.push [current_region[0] * avg_inc - window_size , \
                    idx * avg_inc + window_size ]      
      current_region = []

  max_region = null
  max_opinions = 0
  for region in dense_regions
    cnt = 0
    for o in opinions
      if o.value >= region[0] && \
         o.value <= region[1] 
        cnt += 1
    if cnt > max_opinions
      max_opinions = cnt
      max_region = region

  # Third, calculate the avatar radius we'll use. It is based on 
  # trying to fill ratio_filled of the densest area of the histogram
  ratio_filled = .75
  if max_opinions > 1
    effective_width = width * Math.abs(max_region[0] - max_region[1]) / 2
    area_per_avatar = ratio_filled * effective_width * height / max_opinions
    r = Math.sqrt(area_per_avatar) / 2
  else 
    r = Math.sqrt(width * height / opinions.length * ratio_filled) / 2

  r = Math.min(r, width / 2, height / 2, max_avatar_radius)

  r



window.get_your_slide = (sldr) =>
  sldr = fetch(sldr)

  you = your_key()
  your_slide = null
  for v in (sldr.values or [])
    if v?.user == you
      your_slide = v
      break
  your_slide

# returns average score of the opinions on this slider,
# weighted by current opinion weights
window.get_average_value = (sldr) =>
  weights = fetch('opinion').weights

  sldr = fetch sldr 
  return 0 if !sldr.values?

  w = 0 # total opinion weight 
  v = 0 # total opinion value
  n = 0 # total users contributing to score

  for slide in sldr.values 
    if weights 
      continue if slide.user not of weights 
      w += weights[slide.user]
      v += weights[slide.user] * slide.value
    else 
      w += 1 
      v += slide.value 

    n += 1

  if n == 0 || w == 0 
    -1 
  else 
    v / w



slidergramify = (node) ->
  for lst in node.querySelectorAll('ol[data-slidergram], ul[data-slidergram]')
    is_ol = lst.tagName.toLowerCase() == 'ol'
    items = lst.querySelectorAll('li')

    wrapper = document.createElement 'div'
    wrapper.setAttribute 'data-slidergram-wrapper', true 
    replaced = lst.parentNode.replaceChild wrapper, lst 

    React.render SLIDERGRAM_OL({items, is_ol}), wrapper

dom.SLIDERGRAM_OL = -> 
  SLIST = if @props.is_ol then OL else UL

  SLIST null,
    for item in @props.items
      SLIDERGRAM_LI 
        html: item.innerHTML

dom.SLIDERGRAM_LI = ->
  sldr = fetch "/slider/#{@props.html}"

  return LI null if @loading()

  if !sldr.values?
    anchor = 
      key: "/anchor/#{@props.html}"
      sliders: []
    save anchor 

    sldr = create_slidergram
      anchor: anchor


  LI 
    style: 
      minHeight: 50
      position: 'relative'

    SPAN 
      dangerouslySetInnerHTML: __html: @props.html

    DIV 
      style: 
        position: 'absolute'
        right: -250
        top: -25

      SLIDERGRAM 
        sldr: sldr 
        width: 200
        height: 40




