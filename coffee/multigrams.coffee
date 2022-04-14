dom.MULTIGRAM = ->
    sldr = fetch @props.sldr
    local_sldr = fetch shared_local_key sldr

    DIV
        display: 'flex'
        flexDirection: 'column'
        marginBottom: 16

        onMouseOver: (e) =>
            if e.target.getAttribute?('data-target')?
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
            target_key: "target"
                
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
            "data-target": opinion.target
            style:
                # cached width/height/left/top
                width: size?.width or 50
                height: size?.width or 50
                transform: "translate(#{size?.left or 0}px, #{size?.top or 0}px)"
                transformOrigin: "top left"
                opacity: if (dragging or opinion.type?) then 0.4
                filter: if (dragging or opinion.type?) then 'grayscale(80%)'
                boxSizing: "border-box"
                borderWidth: "2px"
                borderStyle: if (dragging and dragged) then "dashed" else "solid"
                borderColor: if (dragging and dragged) then "black" else "transparent"
                backgroundColor: if (dragging and dragged) then "transparent"
                color: if (dragging and dragged) then "black"
                cursor: "pointer"

        props = implements_slide_draggable sldr, props, "target", opinion.target, @props.width

        AVATAR props

    # Dragged avatar
    if dragging and local_sldr.live?
        val = local_sldr.live ? DEFAULT_SLIDER_VAL
        target = local_sldr.target
        
        # Get the "static" position of this avatar
        size = local_sldr.layout[target]
        r = (size?.width or 50) / 2
        props = 
            key: "histo-avatar-dragging"
            user: target
            hide_tooltip: true
            vote_target: target
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
  local_sldr = fetch(shared_local_key(sldr))
  c = fetch "/current_user"
  dragging = local_sldr.dragging

  cache_key = md5([@props.width, @props.height, sldr.values, dragging ? 0, c.user?.key ? 0])

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

    packing_radius = @calcRadius(@props.width, @props.height, vals_weight, @props.max_avatar_radius)

    radii = {}
    vals_weight.forEach (vote) ->
        radii[vote.target] = Math.sqrt(vote.weight) * packing_radius

    positionAvatars
      sldr: sldr
      width: @props.width
      height: @props.height
      default_radius: packing_radius
      radii: radii
      vote_key: "target"

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
