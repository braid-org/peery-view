dom.MULTIGRAM = ->
    sldr = fetch @props.sldr
    local_sldr = fetch shared_local_key sldr

    DIV
        display: 'flex'
        flexDirection: 'column'
        marginBottom: 16

        onMouseOver: (e) =>
            # For some reason, trying to save the local_sldr while the element is loading throws errors in the console.
            # It doesn't cause any issues with the component as far as I can tell, but this check prevents that.
            if @loading()
                return
            # The AVATARS have data-target attributes set on them.
            # Doing it this way allows us to reuse one hover handler for all of the multigram avatars.
            if e.target.getAttribute?('data-target')?
                target = e.target.getAttribute('data-target')
                local_sldr.hover_target_key = target
                local_sldr.hover = true
            else
                local_sldr.hover = false
            save local_sldr

        onMouseOut: (e) =>
            if @loading()
                return
            local_sldr.hover = false
            save local_sldr


        MULTIHISTOGRAM
            key: "histogram"
            width: @props.width
            height: @props.height
            sldr: sldr
            read_only: @props.read_only
            max_avatar_radius: @props.max_avatar_radius
            onsave: @props.onsave

        SLIDER_BOTTOM
            key: "bottom"
            sldr: sldr
            width: @props.width
            # Show the handle if we're dragging or hovering on an avatar
            feedback: !@props.no_feedback and !@props.read_only and (local_sldr.dragging or local_sldr.hover)
            linewidth: 3
            handleheight: Math.min((@props.height ? 100) / 4, 20)
            handleoffset: 3
            vote_key: "target_key"
            target: if local_sldr.dragging then local_sldr.target_key else local_sldr.hover_target_key

        SLIDER_TOOLTIP
            key: "floating-tooltip"
            local: local_sldr
            width: @props.width
            height: @props.height
            follows_live: true
                
####
# Histogram
#
# Controls the display of the users arranged on a histogram. 
# 
# The user avatars are arranged imprecisely on the histogram
# based on the user's opinion, using a physics simulation. 

dom.MULTIHISTOGRAM = ->
  sldr = fetch @props.sldr
  sldr.arr ?= []
  local_sldr = fetch shared_local_key sldr
  local_sldr.layout ?= {}
  
  # Put the height on so that start_slide can properly position the elements
  local_sldr.height = @props.height
  save local_sldr

  @calcRadius = @props.calculateAvatarRadius or calculateAvatarRadius

  dragging = local_sldr.dragging

  DIV extend(@props,
    className: 'histogram'
    style:
      width: @props.width
      height: @props.height
      position: 'relative'
      userSelect: 'none'
    ),

    # Draw the avatars in the histogram. Placement will be determined later
    # by the physics sim
    for opinion in sldr.arr
        #continue if !opinion.user || (opinion_weights && opinion.user not of opinion_weights ) # && you != opinion.user)
        continue if opinion.depth == 0
        fetch opinion
        size = local_sldr.layout[opinion.target_key]
        continue unless opinion.value? and size?.left? and size?.width?
        
        dragged = local_sldr.target_key == opinion.target_key
        props = 
            key: "histo-avatar-#{opinion.target_key}"
            # To tell the AVATAR whose pic/initials to display
            user: opinion.target_key
            # Hide the tooltip if we're dragging someone else
            hide_tooltip: true
            # Put a border on white avatars
            add_border: !(dragging and dragged)
            # To allow the multigram to check hovers properly
            "data-target": opinion.target_key
            style: 
                # Size of the avatar
                width: size.width
                height: size.width
                # Where to position it
                transform: "translate(#{size.left}px, #{size.top}px)"
                # If there's a dragged avatar or we're an implicit vote, gray out
                opacity: if (dragging or opinion.depth != 1) then 0.4
                filter: if (dragging or opinion.depth != 1) then 'grayscale(80%)'
                # If this avatar is the "original position" of the current floating drag, put a dashed border
                boxSizing: "border-box"
                borderStyle: if (dragging and dragged) then "dashed" else "solid"
                borderWidth: "2px"
                borderColor: if (dragging and dragged) then "black" else "transparent"
                backgroundColor: if (dragging and dragged) then "transparent"
                color: if (dragging and dragged) then "black"
                # UX interactability
                cursor: unless @props.read_only then "pointer"

        # This sets event listeners on the avatar
        unless @props.read_only
            props = implements_slide_draggable sldr, props, opinion.target_key, @props.width,
                onsave: @props.onsave

        # Actually generate the icon
        AVATAR props

    # floating dragged avatar
    if dragging and local_sldr.live?
        val = local_sldr.live ? DEFAULT_SLIDER_VAL
        target = local_sldr.target_key
        
        # Get the "static" position of this avatar
        size = local_sldr.layout[target]
        r = (size?.width or 50) / 2
        props = 
            key: "histo-avatar-dragging"
            user: target
            hide_tooltip: true
            # This probably isn't necessary...
            "data-target": target
            style:
                left: within val * @props.width - r - 2, 0, @props.width - 2 * r
                top: size?.top ? 0 - 2
                width: r * 2
                height: r * 2
                zIndex: 3
                boxSizing: "border-box"
                filter: "drop-shadow(0 1px 1px rgba(0, 0, 0, 0.3))"
                border: "2px solid"
                borderColor: if val >= 0.5 then color_positive else color_negative

        AVATAR props


dom.MULTIHISTOGRAM.refresh = ->
  sldr = fetch @props.sldr
  local_sldr = fetch shared_local_key sldr
  dragging = local_sldr.dragging

  # We want to avoid running the expensive layout calculation unless things have changed
  hash = (v.value for v in sldr.arr || []).join " "
  cache_key = md5([@props.width, @props.height, hash, sldr.key])
  # A single multihistogram widget could get pointed at different state. Hence, the cache key should change when the state key changes

  if sldr.arr?.length > 0 and (cache_key != @last_cache || local_sldr.dirty_opinions) and !@loading()
    local_sldr.dirty_opinions = false
    save local_sldr

    # Make a copy of the votes array that has weights on it.
    # The area of each avatar will be proportional to its weight.
    vals_weight = sldr.arr
        .map (v) ->
            {
                v...
                weight: (Math.abs(v.value - 0.5) * 1.8 + 0.1) * (if v.depth == 1 then 1 else 0.5)
            }

    # calcRadius takes weight into account
    packing_radius = @calcRadius(@props.width, @props.height, vals_weight, @props.max_avatar_radius)

    radii = {}
    vals_weight
        .filter (vote) -> vote.target_key != vote.user_key
        .forEach (vote) ->
            radii[vote.target_key] = Math.sqrt(vote.weight) * packing_radius

    positionAvatars
      sldr: sldr
      width: @props.width
      height: @props.height
      default_radius: packing_radius
      radii: radii
      vote_key: "target_key"

    @last_cache = cache_key


    
# TODO refactor this
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
