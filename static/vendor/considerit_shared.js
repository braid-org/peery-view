window.ui = window.ui || {}
window.dom = window.dom || {}
var handle_window_event, onMouseUpdate, onTouchUpdate, register_window_event, resizebox, server_slash, shared_local_key, size_cache, slugify, unregister_window_event,
  hasProp = {}.hasOwnProperty;

window.considerit_salmon = '#F45F73';

window.set_style = function(sty, id) {
  var style;
  style = document.createElement("style");
  if (id) {
    style.id = id;
  }
  style.innerHTML = sty;
  return document.head.appendChild(style);
};

window.mouseX = window.mouseY = null;

onMouseUpdate = function(e) {
  window.mouseX = e.screenX;
  return window.mouseY = e.screenY;
};

onTouchUpdate = function(e) {
  window.mouseX = e.touches[0].screenX;
  return window.mouseY = e.touches[0].screenY;
};

document.addEventListener('mousemove', onMouseUpdate, false);

document.addEventListener('mouseenter', onMouseUpdate, false);

document.addEventListener('touchstart', onTouchUpdate, false);

document.addEventListener('touchmove', onTouchUpdate, false);

server_slash = function(key) {
  if (key[0] !== '/') {
    return '/' + key;
  } else {
    return key;
  }
};

window.new_key = function(type, text) {
  text || (text = '');
  return '/' + type + '/' + slugify(text) + (text.length > 0 ? '-' : '') + Math.random().toString(36).substring(7);
};

shared_local_key = function(key_or_object) {
  var key;
  key = key_or_object.key || key_or_object;
  if (key.startsWith("_shared")) {
    return key;
  }
  else {
    return "_shared" + server_slash(key);
  }
}

window.your_key = function() {
  var current_user, ref;
  current_user = fetch('/current_user');
  return ((ref = current_user.user) != null ? ref.key : void 0) || current_user.user;
};

window.wait_for_bus = function(cb) {
  if (typeof bus === "undefined" || bus === null) {
    return setTimeout(function() {
      return wait_for_bus(cb);
    }, 10);
  } else {
    return cb();
  }
};

window.extend = function(obj) {
  var arg, i, idx, len, name, s;
  obj || (obj = {});
  for (idx = i = 0, len = arguments.length; i < len; idx = ++i) {
    arg = arguments[idx];
    if (idx > 0) {
      for (name in arg) {
        if (!hasProp.call(arg, name)) continue;
        s = arg[name];
        if ((obj[name] == null) || obj[name] !== s) {
          obj[name] = s;
        }
      }
    }
  }
  return obj;
};

window.defaults = function(o) {
  var arg, i, idx, name, obj, s;
  obj = {};
  for (idx = i = arguments.length - 1; i >= 0; idx = i += -1) {
    arg = arguments[idx];
    for (name in arg) {
      if (!hasProp.call(arg, name)) continue;
      s = arg[name];
      obj[name] = s;
    }
  }
  return extend(o, obj);
};

window.within = function(val, min, max) {
  return Math.min(Math.max(val, min), max);
};

window.crossbrowserfy = function(styles, property) {
  var i, len, pre, prefixes;
  prefixes = ['Webkit', 'ms', 'Moz'];
  for (i = 0, len = prefixes.length; i < len; i++) {
    pre = prefixes[i];
    styles["" + pre + (property.charAt(0).toUpperCase()) + (property.substr(1))];
  }
  return styles;
};

window.get_script_attr = function(script, attr) {
  var sc, val;
  sc = document.querySelector("script[src*='" + script + "'][src$='.coffee'], script[src*='" + script + "'][src$='.js']");
  if (!sc) {
    return false;
  }
  val = sc.getAttribute(attr);
  if (val === '') {
    val = true;
  }
  return val;
};

slugify = function(text) {
  text || (text = "");
  return text.toString().toLowerCase().replace(/\s+/g, '-').replace(/[^\w\-]+/g, '').replace(/\-\-+/g, '-').replace(/^-+/, '').replace(/-+$/, '').substring(0, 30);
};

window.closest = function(node, check) {
  if (!node || node === document) {
    return false;
  } else {
    return check(node) || closest(node.parentNode, check);
  }
};


/* Tracking
 */

window.saw_thing = function(keys_or_objects) {
  var i, key, key_or_object, len, seen;
  seen = fetch('seen_in_session');
  seen.items || (seen.items = {});
  if (!(keys_or_objects instanceof Array)) {
    keys_or_objects = [keys_or_objects];
  }
  for (i = 0, len = keys_or_objects.length; i < len; i++) {
    key_or_object = keys_or_objects[i];
    key = key_or_object.key || key_or_object;
    seen.items[key] = false;
  }
  return save(seen);
};

window.report_seen = function(namespace) {
  return wait_for_bus(function() {
    namespace || (namespace = '');
    return (function(namespace) {
      var reporter;
      reporter = bus.reactive(function() {
        var k, ref, seen, to_report, v;
        seen = fetch('seen_in_session');
        seen.items || (seen.items = {});
        to_report = [];
        ref = seen.items;
        for (k in ref) {
          v = ref[k];
          if (!(k !== 'key' && !v)) {
            continue;
          }
          to_report.push(k);
          seen.items[k] = true;
        }
        if (to_report.length > 0) {
          save({
            key: "/seen/" + (JSON.stringify({
              user: your_key(),
              namespace: namespace
            })),
            saw: to_report
          });
          return save(seen);
        }
      });
      return reporter();
    })(namespace);
  });
};

window.attached_events = {};

register_window_event = function(id, event_type, handler, priority) {
  var dups, e, i, idx, j, l, len, len1, len2, ref, ref1, results;
  id = id.key || id;
  priority = priority || 0;
  attached_events[event_type] || (attached_events[event_type] = []);
  ref = attached_events[event_type];
  for (idx = i = 0, len = ref.length; i < len; idx = ++i) {
    e = ref[idx];
    if (e.id === id) {
      unregister_window_event(id, event_type);
    }
  }
  if (attached_events[event_type].length === 0) {
    window.addEventListener(event_type, handle_window_event);
  }
  attached_events[event_type].push({
    id: id,
    handler: handler,
    priority: priority
  });
  dups = [];
  ref1 = attached_events[event_type];
  for (idx = j = 0, len1 = ref1.length; j < len1; idx = ++j) {
    e = ref1[idx];
    if (e.id === id) {
      dups.push(e);
    }
  }
  if (dups.length > 1) {
    console.warn("DUPLICATE EVENTS FOR " + id, event_type);
    results = [];
    for (l = 0, len2 = dups.length; l < len2; l++) {
      e = dups[l];
      results.push(console.warn(e.handler));
    }
    return results;
  }
};

unregister_window_event = function(id, event_type) {
  var ev, ev_type, events, i, idx, new_events, results;
  id = id.key || id;
  results = [];
  for (ev_type in attached_events) {
    events = attached_events[ev_type];
    if (event_type && event_type !== ev_type) {
      continue;
    }
    new_events = events.slice();
    for (idx = i = events.length - 1; i >= 0; idx = i += -1) {
      ev = events[idx];
      if (ev.id === id) {
        new_events.splice(idx, 1);
      }
    }
    attached_events[ev_type] = new_events;
    if (new_events.length === 0) {
      results.push(window.removeEventListener(ev_type, handle_window_event));
    } else {
      results.push(void 0);
    }
  }
  return results;
};

handle_window_event = function(ev) {
  var e, i, len, ref, results;
  attached_events[ev.type].sort(function(a, b) {
    return b.priority - a.priority;
  });
  ev._stopPropagation = ev.stopPropagation;
  ev.stopPropagation = function() {
    ev.propagation_stopped = true;
    return ev._stopPropagation();
  };
  ref = attached_events[ev.type];
  results = [];
  for (i = 0, len = ref.length; i < len; i++) {
    e = ref[i];
    e.handler(ev);
    if (ev.propagation_stopped) {
      break;
    } else {
      results.push(void 0);
    }
  }
  return results;
};

size_cache = {};

window.sizeWhenRendered = function(str, style) {
  var h, k, key, main, test, v, w;
  main = document.getElementById('main-content') || document.querySelector('[data-widget="body"]');
  if (!main) {
    return {
      width: 0,
      height: 0
    };
  }
  style || (style = {});
  style.str = str;
  key = JSON.stringify(style);
  delete style.str;
  if (!(key in size_cache)) {
    style.display || (style.display = 'inline-block');
    test = document.createElement("span");
    test.innerHTML = "<span>" + str + "</span>";
    for (k in style) {
      v = style[k];
      test.style[k] = v;
    }
    main.appendChild(test);
    h = test.offsetHeight;
    w = test.offsetWidth;
    main.removeChild(test);
    size_cache[key] = {
      width: w,
      height: h
    };
  }
  return size_cache[key];
};

window.getCoords = function(el) {
  var docEl, offset, rect;
  rect = el.getBoundingClientRect();
  docEl = document.documentElement;
  offset = {
    top: rect.top + window.pageYOffset - docEl.clientTop,
    left: rect.left + window.pageXOffset - docEl.clientLeft
  };
  return extend(offset, {
    cx: offset.left + rect.width / 2,
    cy: offset.top + rect.height / 2,
    width: rect.width,
    height: rect.height
  });
};

dom.HEARTBEAT = function() {
  var beat;
  beat = fetch(this.props.public_key || 'pulse');
  if (beat.beat == null) {
    setInterval(function() {
      beat.beat = (beat.beat || 0) + 1;
      return save(beat);
    }, this.props.interval || 1000);
  }
  return SPAN(null);
};

resizebox = function(target) {
  var results;
  target.style.height = null;
  while (target.rows > 1 && target.scrollHeight < target.offsetHeight) {
    target.rows--;
  }
  results = [];
  while (target.scrollHeight > target.offsetHeight && target.rows < 999) {
    results.push(target.rows++);
  }
  return results;
};

set_style("[data-widget=\"UncontrolledText\"] p:first-of-type {\n  margin-top: 0;\n}\n");
window.insert_grab_cursor_style = function() {
  return set_style("a { \n  cursor: pointer; \n  text-decoration: underline;\n}\n.grab_cursor {\n  cursor: move;\n  cursor: grab;\n  cursor: ew-resize;\n  cursor: -webkit-grab;\n  cursor: -moz-grab;\n} .grab_cursor:active {\n  cursor: move;\n  cursor: grabbing;\n  cursor: ew-resize;\n  cursor: -webkit-grabbing;\n  cursor: -moz-grabbing;\n}\n\n", 'grab-cursor');
};

window.prettyDate = function(time) {
  var date, day_diff, diff, r;
  date = new Date(time);
  diff = ((new Date()).getTime() - date.getTime()) / 1000;
  day_diff = Math.floor(diff / 86400);
  if (isNaN(day_diff) || day_diff < 0) {
    return;
  }
  r = day_diff === 0 && (diff < 60 && "just now" || diff < 120 && "1 minute ago" || diff < 3600 && Math.floor(diff / 60) + " minutes ago" || diff < 7200 && "1 hour ago" || diff < 86400 && Math.floor(diff / 3600) + " hours ago") || day_diff === 1 && "Yesterday" || day_diff < 7 && day_diff + " days ago" || day_diff < 31 && Math.ceil(day_diff / 7) + " weeks ago" || ((date.getMonth() + 1) + "/" + (date.getDay() + 1) + "/" + (date.getFullYear()));
  r = r.replace('1 days ago', '1 day ago').replace('1 weeks ago', '1 week ago').replace('1 years ago', '1 year ago');
  return r;
};

window.hsv2rgb = function(h, s, v) {
  var b, f, g, h_i, p, q, r, ref, ref1, ref2, ref3, ref4, ref5, t;
  h_i = Math.floor(h * 6);
  f = h * 6 - h_i;
  p = v * (1 - s);
  q = v * (1 - f * s);
  t = v * (1 - (1 - f) * s);
  if (h_i === 0) {
    ref = [v, t, p], r = ref[0], g = ref[1], b = ref[2];
  }
  if (h_i === 1) {
    ref1 = [q, v, p], r = ref1[0], g = ref1[1], b = ref1[2];
  }
  if (h_i === 2) {
    ref2 = [p, v, t], r = ref2[0], g = ref2[1], b = ref2[2];
  }
  if (h_i === 3) {
    ref3 = [p, q, v], r = ref3[0], g = ref3[1], b = ref3[2];
  }
  if (h_i === 4) {
    ref4 = [t, p, v], r = ref4[0], g = ref4[1], b = ref4[2];
  }
  if (h_i === 5) {
    ref5 = [v, p, q], r = ref5[0], g = ref5[1], b = ref5[2];
  }
  return "rgb(" + (Math.round(r * 256)) + ", " + (Math.round(g * 256)) + ", " + (Math.round(b * 256)) + ")";
};

dom.RENDER_HTML = function() {
  return DIV({
    className: 'embedded_html',
    dangerouslySetInnerHTML: {
      __html: this.props.html
    }
  });
};

dom.LAB_FOOTER = function() {
  return DIV({
    style: {
      marginTop: 40,
      padding: '20px 0 20px 0',
      fontFamily: '"Brandon Grotesque", Montserrat, Helvetica, arial',
      borderTop: '1px solid #D6D7D9',
      backgroundColor: '#F6F7F9',
      color: "#777",
      fontSize: 30,
      fontWeight: 300
    }
  }, DIV({
    style: {
      textAlign: 'center',
      marginBottom: 6
    }
  }, "Made at ", A({
    onMouseEnter: (function(_this) {
      return function() {
        _this.local.hover = true;
        return save(_this.local);
      };
    })(this),
    onMouseLeave: (function(_this) {
      return function() {
        _this.local.hover = false;
        return save(_this.local);
      };
    })(this),
    href: 'http://consider.it',
    target: '_blank',
    title: 'Consider.it\'s homepage',
    style: {
      position: 'relative',
      top: 6,
      left: 3
    }
  }, DRAW_LOGO({
    height: 31,
    clip: false,
    o_text_color: considerit_salmon,
    main_text_color: considerit_salmon,
    draw_line: true,
    line_color: '#D6D7D9',
    i_dot_x: this.local.hover ? 142 : 252,
    transition: true
  }))), DIV({
    style: {
      fontSize: 16,
      textAlign: 'center'
    }
  }, "An ", A({
    href: 'https://invisible.college',
    target: '_blank',
    style: {
      color: 'inherit',
      fontWeight: 400
    }
  }, "Invisible College"), " laboratory"));
};

dom.LOADING_INDICATOR = function() {
  return DIV({
    className: 'loading sk-wave',
    dangerouslySetInnerHTML: {
      __html: "<div class=\"sk-rect sk-rect1\"></div>\n<div class=\"sk-rect sk-rect2\"></div>\n<div class=\"sk-rect sk-rect3\"></div>\n<div class=\"sk-rect sk-rect4\"></div>\n<div class=\"sk-rect sk-rect5\"></div>"
    }
  });
};

window.point_distance = function(a, b) {
  return Math.sqrt(Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2));
};

set_style(".sk-wave {\n  margin: 40px auto;\n  width: 50px;\n  height: 40px;\n  text-align: center;\n  font-size: 10px; }\n  .sk-wave .sk-rect {\n    background-color: rgba(223, 98, 100, .5);\n    height: 100%;\n    width: 6px;\n    display: inline-block;\n    -webkit-animation: sk-waveStretchDelay 1.2s infinite ease-in-out;\n            animation: sk-waveStretchDelay 1.2s infinite ease-in-out; }\n  .sk-wave .sk-rect1 {\n    -webkit-animation-delay: -1.2s;\n            animation-delay: -1.2s; }\n  .sk-wave .sk-rect2 {\n    -webkit-animation-delay: -1.1s;\n            animation-delay: -1.1s; }\n  .sk-wave .sk-rect3 {\n    -webkit-animation-delay: -1s;\n            animation-delay: -1s; }\n  .sk-wave .sk-rect4 {\n    -webkit-animation-delay: -0.9s;\n            animation-delay: -0.9s; }\n  .sk-wave .sk-rect5 {\n    -webkit-animation-delay: -0.8s;\n            animation-delay: -0.8s; }\n\n@-webkit-keyframes sk-waveStretchDelay {\n  0%, 40%, 100% {\n    -webkit-transform: scaleY(0.4);\n            transform: scaleY(0.4); }\n  20% {\n    -webkit-transform: scaleY(1);\n            transform: scaleY(1); } }\n\n@keyframes sk-waveStretchDelay {\n  0%, 40%, 100% {\n    -webkit-transform: scaleY(0.4);\n            transform: scaleY(0.4); }\n  20% {\n    -webkit-transform: scaleY(1);\n            transform: scaleY(1); } }", 'loading-indicator-styles');
