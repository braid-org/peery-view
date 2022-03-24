DEFAULT_SLIDER_VAL = 0.5
SLIDER_COLOR = '#999'
feedback_orange = '#F19135'
considerit_salmon = '#F45F73'
color_positive = '#5fb4f4'
color_negative = '#f46444'

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


  DIV
    key: 'opinion_area'
    ref: 'opinion_area'
    style:
      flex: 2

    onMouseEnter: if !read_only then (e) =>
      @local.hover_opinion_area = true
      @local.hover = true
      save @local
      if !has_opined && !local_sldr.tracking_mouse
        x_entry = mouseX - @refs.opinion_area.getDOMNode().getBoundingClientRect().left
        start_slide sldr, @props.width, 'tracking',
          initial_val: x_entry / slidergram_width
          slidergram_width: slidergram_width


    onMouseLeave: if !read_only then (e) =>
      @local.hover_opinion_area = false
      @local.hover = false
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
          sldr: sldr
          width: @props.width
          style:
            display: 'none' unless local_sldr.tracking_mouse or @props.force_ghosting or has_opined


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

  you = your_key()
  return if !you

  val = args?.initial_val

  if slide_type == 'dragging'
    your_slide = get_your_slide(sldr)
    val = if your_slide then your_slide.value else DEFAULT_SLIDER_VAL
    local.dragging = true

  else if slide_type == 'tracking'
    val = args.initial_val ? DEFAULT_SLIDER_VAL
    local.tracking_mouse = 'tracking'
  
  local.live_pos = val
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

      # normalize position of handle into slider value
      value = x / slidergram_width
      local.live_pos = Math.round(value * 10000) / 10000

      # console.log 'SAVING slide', your_slide.value
      save local

  register_window_event "slide-#{local.key}", 'mousemove', mousemove
  register_window_event "slide-#{local.key}", 'touchmove', mousemove

  # Mouse UP events
  mouseup = (e) ->
    if slide_type == 'dragging'
      local.dragging = false
      saw_thing(sldr)
      stop_slider_dragging(sldr)
    else if slide_type == 'tracking'
      saw_thing(sldr)
      stop_slider_mouse_tracking(sldr)

    # Update the value in the server
    your_vote = get_your_slide(sldr)
    if !your_vote
        your_vote = 
            user: you
        sldr.values.push your_vote
    your_vote.updated = (new Date()).getTime()
    your_vote.value = local.live_pos

    save sldr
    local.dirty_opinions = true
    save local

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
  local_sldr = fetch(shared_local_key(sldr))
  unregister_window_event "slide-#{local_sldr.key}"
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

  val = if local_sldr.tracking_mouse or local_sldr.dragging and local_sldr.live_pos?
          local_sldr.live_pos
        else if @props.target?
          get_target_slide(@props.sldr, @props.target)?.value or 0
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
      left: @props.width * Math.min val, 0.5
      width: @props.width * Math.abs(val - 0.5)
      backgroundColor: @props.color ? (if val >= 0.5 then color_positive else color_negative)


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
      continue if !opinion.user or (opinion_weights and opinion.user not of opinion_weights ) or opinion.user == you

      key = md5([@props.width, @props.height, opinion_weights])
      size = opinion.size?[key]

      props =
        key: "histo-avatar-#{opinion.user}"
        user: opinion.user
        hide_tooltip: focus_on_dragging
        style:
          # cached width/height/left/top
          width: size?.width or 50
          height: size?.width or 50
          top: size?.top or 0
          left: size?.left or 0
          opacity: if focus_on_dragging then .4
          filter: if  focus_on_dragging then 'grayscale(80%)'

      AVATAR props


    your_vote = get_your_slide(sldr)
    if @props.show_ghosted_user or your_vote

      r = @calcRadius(@props.width, @props.height, sldr.values, @props.max_avatar_radius)
      val = if local_sldr.live_pos?
              local_sldr.live_pos
            else if your_vote?.value
                your_vote.value
            else
              DEFAULT_SLIDER_VAL
      opaque = local_sldr.tracking_mouse == 'activated'

      props =
          key: "histo-avatar-me"
          user: you
          hide_tooltip: true
          className: 'grab_cursor you'
          style:
              left: within val * @props.width - r, 0, @props.width - 2 * r
              top: @props.height - r
              width: r*2
              height: r*2
              zIndex: 3
              opacity: 0.6 if (@props.show_ghosted_user and !opaque)
              filter: "drop-shadow(0 1px 1px rgba(0, 0, 0, 0.3))" if focus_on_dragging

      if your_vote
        props = implements_slide_draggable sldr, @props.width, props

      AVATAR props


dom.HISTOGRAM.refresh = ->

  sldr = fetch @props.sldr
  local_sldr = fetch(shared_local_key(sldr))
  you = your_key?()

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


    # Ignore the user's own vote
    ignore = {}
    ignore[you] = true

    positionAvatars
      positions: sldr
      width: @props.width
      height: @props.height
      default_radius: avatar_radius
      key: key
      radii: radii
      vote_key: "user"
      ignore: ignore

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
    cursor: pointer;
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
  vote_key = args.vote_key
  live = args.live ? false
  ignore = args.ignore ? {}

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
      o.x += alpha * x_force_mult * (o.x_target - o.x)

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
    p1_jealousy = (p1.x - p1.x_target) ** 2 - \
                  (p2.x - p1.x_target) ** 2
    p2_jealousy = (p2.x - p2.x_target) ** 2 - \
                  (p1.x - p2.x_target) ** 2
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
    avatars = (o for o in avatars when o[vote_key] of radii)
  avatars = avatars.filter (o) -> !ignore[o[vote_key]]

  n = avatars.length

  #init = calculateInitialLayout width, height, r, avatars, vote_key

  nodes = avatars.map (o, i) ->

    rad = radii?[o[vote_key]] or o.r or r

    x_target = o.value * width
    # If there's already someone else trying to go there...
    if targets[x_target]
        # Generate a random number in (-1, 1) seeded by the vote key.
        pseudorand = parseInt(md5(o[vote_key]).substr(0, 10), 16) / Math.pow(16, 10)
        offset = (pseudorand * 2) - 1
      
        # If we're near one of the edges, move towards the center
        if o.value > .98
            offset = -Math.abs(offset)
        else if o.value < .02
            offset = Math.abs(offset)
        # Move up to 50% of avatar width.
        x_target += offset * rad

    targets[x_target] = 1

    # Travis: I'm finding that different initial conditions work 
    # better at different scales.
    #   - Give large numbers of avatars some good initial spacing
    #   - Small numbers of avatars can be more precisely placed for quick 
    #     convergence with little churn  
    # x = if n > 10 
    #       rad + (width - 2 * rad) * (i / n) 
    #     else 
    #       x_target
    x = o.size?[key]?.left + rad
    y = o.size?[key]?.top + rad
    if isNaN(x) or isNaN(y)
        x = x_target
        y = height - rad

    return {
      index: i
      radius: rad
      x: x
      y: y
      x_target: x_target
    }

  ###########
  # run the simulation

  stable = false
  alpha = 1
  decay = 0.9
  min_alpha = 1e-3
  x_force_mult = 1
  y_force_mult = 5 * (width / height)

  while not stable
    stable = tick alpha
    alpha *= decay

    stable ||= alpha <= min_alpha
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

calculateInitialLayout = (w, h, r, avatars, key) ->
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
    assignments[o[key]] = least_crowded_cell * r

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
        w = opinions[o].weight ? 1
        cnt += w*w

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
        w = o.weight ? 1
        cnt += w * w
    if cnt > max_opinions
      max_opinions = cnt
      max_region = region

  # Third, calculate the avatar radius we'll use. It is based on 
  # trying to fill ratio_filled of the densest area of the histogram
  ratio_filled = .75
  if max_opinions > 1
    effective_width = width * Math.abs(max_region[0] - max_region[1]) / 2
    area_per_avatar = ratio_filled * effective_width * height / max_opinions
    r = Math.sqrt(area_per_avatar / Math.PI)
  else
    r = Math.sqrt(ratio_filled * width * height / (opinions.length * Math.PI))

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




