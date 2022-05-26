bus('usergram/*').to_fetch = (star) ->
    c = fetch "/current_user"
    username = slash star
    
    users = {}
    # Add users with direct votes
    Object.values(fetch "/votes_by#{username}")
        .filter (v) ->
            unless v.target?
                return false
            (unslash v.target).startsWith "user"
        .forEach (v) ->
            # Subscribe to each individual vote...
            fetch v
            # Now make a copy of it that isnt tied to the real state url
            t = Object.assign {}, v
            delete t.key
            users[slash t.target] = t

    # Users in network
    Object.entries(fetch "/weights#{username}")
        .filter ([k, v]) -> k != "key"
        .forEach ([k, v]) ->
            kk = slash k
            users[kk] ?= {
                user: username
                target: kk
                type: "network"
                # weights get computed between -1 and 1.
                # but the vote value should be between 0 and 1.
                value: (v + 1) / 2
            }

    # All other users
    # I should just make this a toggle or something??
    #if c.logged_in and c.user.key == username
    #    (fetch "/all_users").all
    #        .forEach (v) ->
    #            vv = slash v
    #            users[vv] ?= {
    #                user: username
    #                target: vv
    #                type: "remote"
    #                value: 0.5
    #            }

    # Don't put the user whose usergram this is in the display
    if users.hasOwnProperty username
        delete users[username]

    {
        values: Object.values users
    }


#bus('usergram/*').to_save = (val, star, key, t) ->
#    local = fetch shared_local_key key
#
#    # Only save the vote that was changed.
#    val.values.forEach (v) ->
#        if v.target == local.target
#            if v.type?
#                # This is a NEW vote that didn't exist before.
#                delete v.type
#
#            cop = Object.assign {}, v
#            cop.key = "/votes/_#{unslash star}_#{unslash v.target}_"
#            save cop
#                   
#    t.done val

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
                local_sldr.hover_target = target
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
            width: @props.width
            height: @props.height
            sldr: sldr
            read_only: @props.read_only
            max_avatar_radius: @props.max_avatar_radius
            onsave: @props.onsave

        SLIDER_BOTTOM
            sldr: sldr
            width: @props.width
            # Show the handle if we're dragging or hovering on an avatar
            feedback: !@props.no_feedback and !@props.read_only and (local_sldr.dragging or local_sldr.hover)
            linewidth: 3
            handleheight: Math.min((@props.height ? 100) / 4, 20)
            handleoffset: 3
            target_key: "target"
            target: if local_sldr.dragging then local_sldr.target else local_sldr.hover_target

        SLIDER_TOOLTIP
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
  sldr.values ||= []
  local_sldr = fetch shared_local_key sldr
  local_sldr.layout ?= {}
  
  # Put the height on so that start_slide can properly position the elements
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
            # To hopefully avoid react issues
            key: "histo-avatar-#{opinion.target}"
            # To tell the AVATAR whose pic/initials to display
            user: opinion.target
            # Hide the tooltip if we're dragging someone else
            hide_tooltip: true
            # To allow the multigram to check hovers properly
            "data-target": opinion.target
            style:
                # Size of the avatar
                width: size?.width or 50
                height: size?.width or 50
                # Where to position it
                transform: "translate(#{size?.left or 0}px, #{size?.top or 0}px)"
                # This is unnecessary unless we're using transform for size as well
                transformOrigin: "top left"
                # If there's a dragged avatar or we're an implicit vote, gray out
                opacity: if (dragging or opinion.type?) then 0.4
                filter: if (dragging or opinion.type?) then 'grayscale(80%)'
                # If this avatar is the "original position" of the current floating drag, put a dashed border
                boxSizing: "border-box"
                border: "2px dashed"
                borderColor: if (dragging and dragged) then "black" else "transparent"
                backgroundColor: if (dragging and dragged) then "transparent"
                color: if (dragging and dragged) then "black"
                # UX interactability
                cursor: "pointer" unless @props.read_only

        # This sets event listeners on the avatar
        unless @props.read_only
            props = implements_slide_draggable sldr, props, opinion.target, @props.width,
                onsave: @props.onsave

        # Actually generate the icon
        AVATAR props

    # floating dragged avatar
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
  # TODO: Replace current user with like, the name of the viewing user?
  dragging = local_sldr.dragging

  # We want to avoid running the expensive layout calculation unless things have changed
  hash = (v.value for v in sldr.values || []).join " "
  cache_key = md5([@props.width, @props.height, hash])

  if sldr.values?.length > 0 && (cache_key != @last_cache || local_sldr.dirty_opinions) && !@loading()
    local_sldr.dirty_opinions = false
    save local_sldr

    # Make a copy of the votes array that has weights on it.
    # The area of each avatar will be proportional to its weight.
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

    # calcRadius takes weight into account
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
