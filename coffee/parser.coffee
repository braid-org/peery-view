# I think all these things have to be defined before 
unslash = (t) -> if t?.startsWith?("/") then t.substr(1) else t
slash = (t) -> if t?.startsWith?("/") then t else "/#{t}"
split_once = (str, char) ->
    i = str.indexOf char
    if i == -1
        [str, ""]
    else
        [str[...i], str[i+1..]]

# KSON = Kinda Simple Object Notation
# but it rhymes with JSON
parse_kson = (str) ->
    # assert str.startsWith "(" and str.endsWith ")"

    # Coffeescript doesn't have object comprehensions :(
    ret = {}
    # Pull out the parentheses
    str[1...-1]
    # Split by commas. TODO: Allow spaces after commas?
    .split ","
    # Delete empty parts (this ensures that empty strings will properly result in empty KSON, and allows trailing commas)
    .filter (part) -> part.length
    .forEach (part) ->
        # If the part has a comma, its a key:value, otherwise it's just a singleton
        [k, v] = split_once part, ":"

        ret[k] = switch
            when v.length == 0 then true
            # If the value is itself a KSON object, parse it recursively
            when v.startsWith "(" then parse_kson v
            else v
    ret

stringify_kson = (obj) ->
    entries = Object.entries obj
    # Allowed values in KSON are: object, string, true
    # Arrays are in fact objects, and we don't need to treat them differently.
    # Their order won't change!
    inner = entries
        .filter ([k, v]) -> v
        .sort()
        .map ([k, v]) ->
            switch typeof v
                when "boolean" then k
                when "string" then "#{k}:#{v}"
                when "object" then "#{k}:#{stringify_kson v}"
                else ""
        .join ","
    if inner.length then "(#{inner})" else ""

# Pattern: looks something like `const/<args1>/...`
# Star: looks something like `a/b/c/d(params:etc)`
match_pattern = (pattern, star) ->
    # First separate out the params, as raw KSON
    [star, params_raw] = split_once star, "("
    
    # Now we need to determine if star matches the pattern
    star_parts = star.split "/"
    pattern_parts = pattern.split "/"
    # Quick length check
    unless star_parts.length == pattern_parts.length
        return false

    # Once again... no object comprehension, or zip()
    path = {}
    for ppart, i in pattern_parts
        spart = star_parts[i]
        # we either match an argument (if ppart is of the form <keyN>) or we verify that the constants are equal
        if ppart.startsWith "<"
            path[ppart[1...-1]] = spart
        else if ppart != spart
            return false

    # split_once will take off the parenthese if it exists, let's put it back on
    params = if params_raw.length then parse_kson "(#{params_raw}" else {}
    {path, params}

autodetect_args = (handler) ->
    if handler.args then return

    # Get an array of the handler's params
    comments = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
    params = /([^\s,]+)/g
    s = handler.toString().replace comments, ''

    params = s[s.indexOf('(') + 1 ... s.indexOf(')')].match(params) || []

    handler.args = {}
    params.forEach (p, i) ->
        switch p
            when "key", "k" then handler.args.key = i
            when "json", "vars" then handler.args.vars = i
            when "star", "rest" then handler.args.res= i
            when "t", "transaction" then handler.args.t = i
            when "o", "obj", "val", "new", "New" then handler.args.obj = i
            when "old" then handler.args.old = i

# Pattern-Path-Params Parser
PPPParser = (bus) ->
    # Create arrays to store the fetch and save handlers
    handlers = 
        to_fetch: []
        to_save: []
        on_save: []
        on_set_sync: []
        on_delete: []
        to_delete: []
        to_forget: []

    og_route = bus.route
    bus.route = (key, method, arg, t) ->
        for route in (handlers[method] || [])
            {pattern, handler} = route
            if {path, params} = match_pattern pattern, key
                # For the time being, we are able to sneak in arguments on the transaction
                # If we run into issues with that, the solution is simply to have the handler access `key` and reparse it
                # Since it knows its own pattern!
                t ||= {}
                t._path = path
                t._params = params
                bus.run_handler handler, method, arg, {t: t, binding: pattern}
                return 1
        return og_route(key, method, arg, t)
    
    (pattern) ->
        ret = {}
        Object.entries handlers
            .forEach ([method, arr]) ->
                Object.defineProperty ret, method,
                    set: (handler) ->
                        autodetect_args handler
                        (handler.defined ?= []).push
                            as: 'handler'
                            bus: bus
                            method: method
                            key: pattern
                        arr.push {pattern, handler}
                    # Could add a getter here that allows deleting patterns.
                    # get: -> ...
        ret



exports = {slash, unslash, split_once, parse_kson, stringify_kson, match_pattern, PPPParser}
if window?
    for k, v of exports
        window[k] = v
else
    # Nodejs
    module.exports = exports
