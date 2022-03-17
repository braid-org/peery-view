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
  window.mouseX = e.pageX;
  return window.mouseY = e.pageY;
};

onTouchUpdate = function(e) {
  window.mouseX = e.touches[0].pageX;
  return window.mouseY = e.touches[0].pageY;
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
  if (key[0] === '/') {
    key = key.substring(1, key.length);
    return key + "/shared";
  } else {
    return key;
  }
};

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

dom.AUTOSIZEBOX = function() {
  var base, base1;
  (base = this.props).style || (base.style = {});
  this.props.style.resize = this.props.style.width || this.props.cols ? 'none' : 'horizontal';
  (base1 = this.props).rows || (base1.rows = 1);
  return TEXTAREA(this.props);
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

dom.AUTOSIZEBOX.up = function() {
  return resizebox(this.getDOMNode());
};

dom.AUTOSIZEBOX.refresh = function() {
  var el;
  resizebox(this.getDOMNode());
  if (!this.init) {
    this.init = true;
    el = this.getDOMNode();
    if ((this.props.autofocus || this.props.cursor) && el !== document.activeElement) {
      el.select();
    }
    if (this.props.cursor && el.setSelectionRange) {
      return el.setSelectionRange(this.props.cursor, this.props.cursor);
    }
  }
};

dom.GROWING_TEXTAREA = function() {
  var _onChange, _onClick, base, base1, base2, base3, base4, base5;
  (base = this.props).style || (base.style = {});
  (base1 = this.props.style).minHeight || (base1.minHeight = 60);
  this.props.style.height = this.local.height || this.props.initial_height || this.props.style.minHeight;
  (base2 = this.props.style).fontFamily || (base2.fontFamily = 'inherit');
  (base3 = this.props.style).lineHeight || (base3.lineHeight = '22px');
  (base4 = this.props.style).resize || (base4.resize = 'none');
  (base5 = this.props.style).outline || (base5.outline = 'none');
  _onChange = this.props.onChange;
  _onClick = this.props.onClick;
  this.props.onClick = function(ev) {
    if (typeof _onClick === "function") {
      _onClick(ev);
    }
    ev.preventDefault();
    return ev.stopPropagation();
  };
  this.props.onChange = (function(_this) {
    return function(ev) {
      if (typeof _onChange === "function") {
        _onChange(ev);
      }
      return _this.adjustHeight();
    };
  })(this);
  this.adjustHeight = (function(_this) {
    return function() {
      var h, max_height, min_height, ref, ref1, scroll_height, textarea;
      textarea = _this.getDOMNode();
      if (!textarea.value || textarea.value === '') {
        h = _this.props.initial_height || _this.props.style.minHeight;
        if (h !== _this.local.height) {
          _this.local.height = h;
          save(_this.local);
        }
      } else {
        min_height = _this.props.style.minHeight;
        max_height = _this.props.style.maxHeight;
        h = textarea.style.height;
        if (((ref = _this.last_value) != null ? ref.length : void 0) > textarea.value.length) {
          textarea.style.height = '';
        }
        scroll_height = textarea.scrollHeight;
        if (((ref1 = _this.last_value) != null ? ref1.length : void 0) > textarea.value.length) {
          textarea.style.height = h;
        }
        if (scroll_height !== textarea.clientHeight) {
          h = scroll_height + 5;
          if (max_height) {
            h = Math.min(scroll_height, max_height);
          }
          h = Math.max(min_height, h);
          if (h !== _this.local.height) {
            _this.local.height = h;
            save(_this.local);
          }
        }
      }
      return _this.last_value = textarea.value;
    };
  })(this);
  return TEXTAREA(this.props);
};

dom.GROWING_TEXTAREA.refresh = function() {
  return this.adjustHeight();
};

dom.WYSIWYG = function() {
  var base, mode, modes, my_data;
  my_data = fetch(this.props.obj);
  if ((base = this.local).mode == null) {
    base.mode = my_data.edit_mode || 'markdown';
  }
  if (!this.props.disable_html) {
    modes = [
      {
        label: 'markdown',
        id: 'markdown'
      }, {
        label: 'raw html',
        id: 'html'
      }
    ];
  } else {
    modes = [
      {
        label: 'markdown',
        id: 'markdown'
      }
    ];
  }
  return DIV({
    style: {
      position: 'relative'
    },
    onBlur: this.props.onBlur
  }, STYLE(".editor-toolbar .fa {\n    color:  #444444;\n}"), modes.length > 1 ? DIV({
    style: {
      position: 'absolute',
      top: -28,
      left: 0
    }
  }, (function() {
    var i, len, results;
    results = [];
    for (i = 0, len = modes.length; i < len; i++) {
      mode = modes[i];
      results.push((function(_this) {
        return function(mode) {
          return BUTTON({
            style: {
              background: 'transparent',
              border: 'none',
              textTransform: 'uppercase',
              color: _this.local.mode === mode.id ? '#555' : '#999',
              padding: '0px 8px 0 0',
              fontSize: 12,
              fontWeight: 700,
              cursor: _this.local.mode === mode.id ? 'auto' : void 0
            },
            onClick: function(e) {
              _this.local.mode = my_data.edit_mode = mode.id;
              save(_this.local);
              return save(my_data);
            }
          }, mode.label);
        };
      })(this)(mode));
    }
    return results;
  }).call(this)) : void 0, this.local.mode === 'html' ? AUTOSIZEBOX({
    style: {
      width: '100%',
      fontSize: 'inherit'
    },
    defaultValue: my_data[this.props.attr] || '\n',
    autofocus: true,
    autoFocus: true,
    onChange: (function(_this) {
      return function(e) {
        my_data[_this.props.attr] = e.target.value;
        return save(my_data);
      };
    })(this)
  }) : this.local.mode === 'markdown' ? EASYMARKDOWN(this.props) : void 0);
};

set_style("[data-widget=\"UncontrolledText\"] p:first-of-type {\n  margin-top: 0;\n}\n");

dom.EASYMARKDOWN = function() {
  var my_data;
  if (!this.local.initialized) {
    my_data = fetch(this.props.obj);
    this.local.initialized = true;
    this.local.id = this.local.key + "-easymarkdown-editor";
    save(this.local);
  }
  return DIV(null, TEXTAREA(extend({}, this.props, {
    style: this.props.style || {},
    id: this.local.id
  })));
};

dom.EASYMARKDOWN.refresh = function() {
  var actual_editor, cursor, editor, my_data;
  if (!this.init) {
    this.init = true;
    editor = document.getElementById(this.local.id);
    my_data = fetch(this.props.obj);
    this.editor = new EasyMDE({
      element: editor,
      initialValue: my_data[this.props.attr + "_src"] || my_data.src || my_data[this.props.attr] || '\n',
      autofocus: !!this.props.autofocus,
      insertTexts: {
        image: ['<img style="aspect-ratio:#width/#height" width="100%" src="', '#url#" />\n'],
        uploadedImage: ['<img width="100%" src="#url#" /> \n', ''],
        uploadedMovie: ["<video width=\"100%\" controls autoplay playsinline loop muted>\n <source src=\"#extentionless_url#.mp4\" type=\"video/mp4\">\n </video> ", '']
      },
      uploadImage: true,
      imageUploadFunction: function(f, onSuccess, onError) {
        var ref, subdirectory, xhr;
        if ((ref = f.type) !== "image/png" && ref !== "image/jpeg" && ref !== "video/quicktime" && ref !== "video/mp4" && ref !== "video/webm") {
          return;
        }
        subdirectory = my_data.key.split('/');
        subdirectory = subdirectory[subdirectory.length - 1];
        console.log('Sending file', f.name);
        xhr = new XMLHttpRequest();
        xhr.open('POST', '/upload', true);
        xhr.setRequestHeader('Content-Type', f.type);
        xhr.setRequestHeader('Content-Disposition', "attachment; filename=\"" + f.name + "\"");
        xhr.setRequestHeader('Content-Filename', f.name);
        xhr.setRequestHeader('Content-Directory', subdirectory);
        xhr.onreadystatechange = function() {
          var img_url, status;
          if (xhr.readyState === XMLHttpRequest.DONE) {
            status = xhr.status;
            if (status === 0 || (status >= 200 && status < 400)) {
              img_url = (document.body.getAttribute('data-static-prefix')) + "/media/" + subdirectory + "/" + f.name;
              console.log("DONE! " + f.name + " " + img_url, status);
              return onSuccess(img_url);
            } else {
              return onError('could not process file');
            }
          }
        };
        return xhr.send(f);
      }
    });
    actual_editor = editor.nextElementSibling.querySelector(".CodeMirror-code");
    if (this.props.autofocus) {
      this.editor.codemirror.focus();
      if (actual_editor != null) {
        actual_editor.focus();
      }
    }
    this.editor.codemirror.on("change", (function(_this) {
      return function() {
        my_data = fetch(_this.props.obj);
        if (my_data.src && !my_data[_this.props.attr + "_src"]) {
          my_data[_this.props.attr + "_src"] = my_data.src;
          delete my_data.src;
          save(my_data);
        }
        my_data[_this.props.attr + "_src"] = _this.editor.value();
        my_data[_this.props.attr] = typeof marked !== "undefined" && marked !== null ? typeof marked.marked === "function" ? marked.marked(my_data[_this.props.attr + "_src"]) : void 0 : void 0;
        if (!_this.dirty) {
          _this.dirty = true;
          return setTimeout(function() {
            if (_this.dirty) {
              save(my_data);
              return _this.dirty = false;
            }
          }, 1000);
        }
      };
    })(this));
    if (this.props.surrounding_text) {
      cursor = this.editor.codemirror.getSearchCursor(this.props.surrounding_text.trim());
      cursor.findNext();
      return this.editor.codemirror.setSelection(cursor.pos.from, cursor.pos.to);
    }
  }
};

dom.TRIX_WYSIWYG = function() {
  var my_data;
  if (!this.local.initialized) {
    my_data = fetch(this.props.obj);
    this.original_value = my_data[this.props.attr] || '\n';
    this.local.initialized = true;
    save(this.local);
  }
  return DIV(defaults({}, this.props, {
    style: this.props.style || {},
    dangerouslySetInnerHTML: {
      __html: "<input id=\"" + this.local.key + "-input\" value=\"" + (this.original_value.replace(/\"/g, '&quot;')) + "\" type=\"hidden\" name=\"content\">\n<trix-editor autofocus=" + (!!this.props.autofocus) + " class='trix-editor' input=\"" + this.local.key + "-input\" placeholder='" + (this.props.placeholder || 'Write something!') + "'></trix-editor>"
    }
  }));
};

dom.TRIX_WYSIWYG.refresh = function() {
  var editor;
  if (!this.init) {
    this.init = true;
    editor = this.getDOMNode().querySelector('.trix-editor');
    editor.addEventListener('trix-change', (function(_this) {
      return function(e) {
        var html, my_data;
        html = editor.innerHTML;
        my_data = fetch(_this.props.obj);
        my_data[_this.props.attr] = html;
        return save(my_data);
      };
    })(this));
    if (this.props.cursor) {
      return editor.editor.setSelectionRange(this.props.cursor, this.props.cursor);
    }
  }
};

dom.QUILL_WYSIWYG = function() {
  var my_data, ref;
  my_data = fetch(this.props.obj);
  this.supports_Quill = !!Quill;
  if (!this.local.initialized) {
    this.original_value = my_data[this.props.attr] || '';
    this.local.initialized = true;
    save(this.local);
  }
  this.show_placeholder = (!my_data[this.props.attr] || (((ref = this.editor) != null ? ref.getText().trim().length : void 0) === 0)) && !!this.props.placeholder;
  return DIV({
    style: {
      position: 'relative'
    }
  }, this.local.edit_code || !this.supports_Quill ? AutoGrowTextArea({
    style: {
      width: '100%',
      fontSize: 18
    },
    defaultValue: my_data[this.props.attr],
    onChange: (function(_this) {
      return function(e) {
        my_data[_this.props.attr] = e.target.value;
        return save(my_data);
      };
    })(this)
  }) : DIV({
    ref: 'editor',
    id: 'editor',
    dangerouslySetInnerHTML: {
      __html: this.original_value
    },
    style: this.props.style
  }));
};

dom.QUILL_WYSIWYG.refresh = function() {
  var getHTML, keyboard;
  if (!this.supports_Quill || !this.refs.editor || this.mounted) {
    return;
  }
  this.mounted = true;
  getHTML = (function(_this) {
    return function() {
      return _this.getDOMNode().querySelector(".ql-editor").innerHTML;
    };
  })(this);
  this.editor = new Quill(this.refs.editor.getDOMNode(), {
    styles: true,
    placeholder: this.show_placeholder ? this.props.placeholder : '',
    theme: 'snow'
  });
  keyboard = this.editor.getModule('keyboard');
  delete keyboard.bindings[9];
  return this.editor.on('text-change', (function(_this) {
    return function(delta, old_contents, source) {
      var my_data, node, removeStyles;
      if (source === 'user') {
        my_data = fetch(_this.props.obj);
        my_data[_this.props.attr] = getHTML();
        if (my_data[_this.props.attr].indexOf(' style') > -1) {
          removeStyles = function(el) {
            var child, i, len, ref, results;
            el.removeAttribute('style');
            if (el.childNodes.length > 0) {
              ref = el.childNodes;
              results = [];
              for (i = 0, len = ref.length; i < len; i++) {
                child = ref[i];
                if (child.nodeType === 1) {
                  results.push(removeStyles(child));
                } else {
                  results.push(void 0);
                }
              }
              return results;
            }
          };
          node = _this.editor.root;
          removeStyles(node);
          my_data[_this.props.attr] = getHTML();
        }
        return save(my_data);
      }
    };
  })(this));
};

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

//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiIiwic291cmNlUm9vdCI6IiIsInNvdXJjZXMiOlsiIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiJBQUFBLElBQUEsaUtBQUE7RUFBQTs7QUFBQSxNQUFNLENBQUMsaUJBQVAsR0FBMkI7O0FBSTNCLE1BQU0sQ0FBQyxTQUFQLEdBQW1CLFNBQUMsR0FBRCxFQUFNLEVBQU47QUFDakIsTUFBQTtFQUFBLEtBQUEsR0FBUSxRQUFRLENBQUMsYUFBVCxDQUF1QixPQUF2QjtFQUNSLElBQWlCLEVBQWpCO0lBQUEsS0FBSyxDQUFDLEVBQU4sR0FBVyxHQUFYOztFQUNBLEtBQUssQ0FBQyxTQUFOLEdBQWtCO1NBQ2xCLFFBQVEsQ0FBQyxJQUFJLENBQUMsV0FBZCxDQUEwQixLQUExQjtBQUppQjs7QUFVbkIsTUFBTSxDQUFDLE1BQVAsR0FBZ0IsTUFBTSxDQUFDLE1BQVAsR0FBZ0I7O0FBQ2hDLGFBQUEsR0FBZ0IsU0FBQyxDQUFEO0VBQ2QsTUFBTSxDQUFDLE1BQVAsR0FBZ0IsQ0FBQyxDQUFDO1NBQ2xCLE1BQU0sQ0FBQyxNQUFQLEdBQWdCLENBQUMsQ0FBQztBQUZKOztBQUdoQixhQUFBLEdBQWdCLFNBQUMsQ0FBRDtFQUNkLE1BQU0sQ0FBQyxNQUFQLEdBQWdCLENBQUMsQ0FBQyxPQUFRLENBQUEsQ0FBQSxDQUFFLENBQUM7U0FDN0IsTUFBTSxDQUFDLE1BQVAsR0FBZ0IsQ0FBQyxDQUFDLE9BQVEsQ0FBQSxDQUFBLENBQUUsQ0FBQztBQUZmOztBQUloQixRQUFRLENBQUMsZ0JBQVQsQ0FBMEIsV0FBMUIsRUFBdUMsYUFBdkMsRUFBc0QsS0FBdEQ7O0FBQ0EsUUFBUSxDQUFDLGdCQUFULENBQTBCLFlBQTFCLEVBQXdDLGFBQXhDLEVBQXVELEtBQXZEOztBQUVBLFFBQVEsQ0FBQyxnQkFBVCxDQUEwQixZQUExQixFQUF3QyxhQUF4QyxFQUF1RCxLQUF2RDs7QUFDQSxRQUFRLENBQUMsZ0JBQVQsQ0FBMEIsV0FBMUIsRUFBdUMsYUFBdkMsRUFBc0QsS0FBdEQ7O0FBU0Es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QU52QztJQU9BLFVBQUEsRUFBWSxJQVBaO0dBREYsQ0FmRixDQVBGLENBWkYsRUE2Q0UsR0FBQSxDQUNFO0lBQUEsS0FBQSxFQUNFO01BQUEsUUFBQSxFQUFVLEVBQVY7TUFDQSxTQUFBLEVBQVcsUUFEWDtLQURGO0dBREYsRUFLRSxLQUxGLEVBTUUsQ0FBQSxDQUNFO0lBQUEsSUFBQSxFQUFNLDJCQUFOO0lBQ0EsTUFBQSxFQUFRLFFBRFI7SUFFQSxLQUFBLEVBQ0U7TUFBQSxLQUFBLEVBQU8sU0FBUDtNQUNBLFVBQUEsRUFBWSxHQURaO0tBSEY7R0FERixFQU1FLG1CQU5GLENBTkYsRUFhRSxhQWJGLENBN0NGO0FBRGU7O0FBOERqQixHQUFHLENBQUMsaUJBQUosR0FBd0IsU0FBQTtTQUN0QixHQUFBLENBQ0U7SUFBQSxTQUFBLEVBQVcsaUJBQVg7SUFDQSx1QkFBQSxFQUF5QjtNQUFBLE1BQUEsRUFBUSx3TUFBUjtLQUR6QjtHQURGO0FBRHNCOztBQVl4QixNQUFNLENBQUMsY0FBUCxHQUF3QixTQUFDLENBQUQsRUFBRyxDQUFIO1NBQ3RCLElBQUksQ0FBQyxJQUFMLENBQVcsSUFBSSxDQUFDLEdBQUwsQ0FBUyxDQUFDLENBQUMsQ0FBRixHQUFNLENBQUMsQ0FBQyxDQUFqQixFQUFvQixDQUFwQixDQUFBLEdBQXlCLElBQUksQ0FBQyxHQUFMLENBQVMsQ0FBQyxDQUFDLENBQUYsR0FBTSxDQUFDLENBQUMsQ0FBakIsRUFBb0IsQ0FBcEIsQ0FBcEM7QUFEc0I7O0FBU3hCLFNBQUEsQ0FBVSwweUNBQVYsRUE2Q08sMEJBN0NQIiwic291cmNlc0NvbnRlbnQiOiJ3aW5kb3cuY29uc2lkZXJpdF9zYWxtb24gPSAnI0Y0NUY3MycgIyNmMzUzODknICMnI2RmNjI2NCcgI0UxNjE2MVxuXG5cblxud2luZG93LnNldF9zdHlsZSA9IChzdHksIGlkKSAtPlxuICBzdHlsZSA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQgXCJzdHlsZVwiXG4gIHN0eWxlLmlkID0gaWQgaWYgaWRcbiAgc3R5bGUuaW5uZXJIVE1MID0gc3R5XG4gIGRvY3VtZW50LmhlYWQuYXBwZW5kQ2hpbGQgc3R5bGVcblxuXG4jIFRyYWNraW5nIG1vdXNlIHBvc2l0aW9uc1xuIyBJdCBpcyBzb21ldGltZXMgbmljZSB0byBrbm93IHRoZSBtb3VzZSBwb3NpdGlvbi4gTGV0J3MganVzdCBtYWtlIGl0XG4jIGdsb2JhbGx5IGF2YWlsYWJsZS5cbndpbmRvdy5tb3VzZVggPSB3aW5kb3cubW91c2VZID0gbnVsbFxub25Nb3VzZVVwZGF0ZSA9IChlKSAtPiBcbiAgd2luZG93Lm1vdXNlWCA9IGUucGFnZVhcbiAgd2luZG93Lm1vdXNlWSA9IGUucGFnZVlcbm9uVG91Y2hVcGRhdGUgPSAoZSkgLT4gXG4gIHdpbmRvdy5tb3VzZVggPSBlLnRvdWNoZXNbMF0ucGFnZVhcbiAgd2luZG93Lm1vdXNlWSA9IGUudG91Y2hlc1swXS5wYWdlWVxuXG5kb2N1bWVudC5hZGRFdmVudExpc3RlbmVyKCdtb3VzZW1vdmUnLCBvbk1vdXNlVXBkYXRlLCBmYWxzZSlcbmRvY3VtZW50LmFkZEV2ZW50TGlzdGVuZXIoJ21vdXNlZW50ZXInLCBvbk1vdXNlVXBkYXRlLCBmYWxzZSlcblxuZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcigndG91Y2hzdGFydCcsIG9uVG91Y2hVcGRhdGUsIGZhbHNlKVxuZG9jdW1lbnQuYWRkRXZlbnRMaXN0ZW5lcigndG91Y2htb3ZlJywgb25Ub3VjaFVwZGF0ZSwgZmFsc2UpXG5cblxuXG5cblxuIyMjIyMjIyNcbiMgU3RhdGVidXMgaGVscGVyc1xuXG5zZXJ2ZXJfc2xhc2ggPSAoa2V5KSAtPiBcbiAgaWYga2V5WzBdICE9ICcvJ1xuICAgICcvJyArIGtleSBcbiAgZWxzZSBcbiAgICBrZXlcblxuXG53aW5kb3cubmV3X2tleSA9ICh0eXBlLCB0ZXh0KSAtPlxuICB0ZXh0IHx8PSAnJ1xuICAnLycgKyB0eXBlICsgJy8nICsgc2x1Z2lmeSh0ZXh0KSArIChpZiB0ZXh0Lmxlbmd0aCA+IDAgdGhlbiAnLScgZWxzZSAnJykgKyBNYXRoLnJhbmRvbSgpLnRvU3RyaW5nKDM2KS5zdWJzdHJpbmcoNylcblxuc2hhcmVkX2xvY2FsX2tleSA9IChrZXlfb3Jfb2JqZWN0KSAtPiBcbiAga2V5ID0ga2V5X29yX29iamVjdC5rZXkgfHwga2V5X29yX29iamVjdFxuICBpZiBrZXlbMF0gPT0gJy8nXG4gICAga2V5ID0ga2V5LnN1YnN0cmluZygxLCBrZXkubGVuZ3RoKVxuICAgIFwiI3trZXl9L3NoYXJlZFwiXG4gIGVsc2UgXG4gICAga2V5XG5cbndpbmRvdy55b3VyX2tleSA9IC0+XG4gIGN1cnJlbnRfdXNlciA9IGZldGNoKCcvY3VycmVudF91c2VyJylcbiAgY3VycmVudF91c2VyLnVzZXI/LmtleSBvciBjdXJyZW50X3VzZXIudXNlclxuXG53aW5kb3cud2FpdF9mb3JfYnVzID0gKGNiKSAtPiBcbiAgaWYgIWJ1cz9cbiAgICBzZXRUaW1lb3V0IC0+IFxuICAgICAgd2FpdF9mb3JfYnVzKGNiKVxuICAgICwgMTBcbiAgZWxzZSBcbiAgICBjYigpXG5cblxuIyMjIyMjIyMjIyMjIyNcbiMgTWFuaXB1bGF0aW5nIG9iamVjdHNcbndpbmRvdy5leHRlbmQgPSAob2JqKSAtPlxuICBvYmogfHw9IHt9XG4gIGZvciBhcmcsIGlkeCBpbiBhcmd1bWVudHMgXG4gICAgaWYgaWR4ID4gMCAgICAgIFxuICAgICAgZm9yIG93biBuYW1lLHMgb2YgYXJnXG4gICAgICAgIGlmICFvYmpbbmFtZV0/IHx8IG9ialtuYW1lXSAhPSBzXG4gICAgICAgICAgb2JqW25hbWVdID0gc1xuICBvYmpcblxud2luZG93LmRlZmF1bHRzID0gKG8pIC0+XG4gIG9iaiA9IHt9XG5cbiAgZm9yIGFyZywgaWR4IGluIGFyZ3VtZW50cyBieSAtMSAgICAgIFxuICAgIGZvciBvd24gbmFtZSxzIG9mIGFyZ1xuICAgICAgb2JqW25hbWVdID0gc1xuICBleHRlbmQgbywgb2JqXG5cblxuXG4jIGVuc3VyZXMgdGhhdCBtaW4gPD0gdmFsIDw9IG1heFxud2luZG93LndpdGhpbiA9ICh2YWwsIG1pbiwgbWF4KSAtPlxuICBNYXRoLm1pbihNYXRoLm1heCh2YWwsIG1pbiksIG1heClcblxud2luZG93LmNyb3NzYnJvd3NlcmZ5ID0gKHN0eWxlcywgcHJvcGVydHkpIC0+XG4gIHByZWZpeGVzID0gWydXZWJraXQnLCAnbXMnLCAnTW96J11cbiAgZm9yIHByZSBpbiBwcmVmaXhlc1xuICAgIHN0eWxlc1tcIiN7cHJlfSN7cHJvcGVydHkuY2hhckF0KDApLnRvVXBwZXJDYXNlKCl9I3twcm9wZXJ0eS5zdWJzdHIoMSl9XCJdXG4gIHN0eWxlc1xuXG5cbndpbmRvdy5nZXRfc2NyaXB0X2F0dHIgPSAoc2NyaXB0LCBhdHRyKSAtPlxuICBzYyA9IGRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoXCJzY3JpcHRbc3JjKj0nI3tzY3JpcHR9J11bc3JjJD0nLmNvZmZlZSddLCBzY3JpcHRbc3JjKj0nI3tzY3JpcHR9J11bc3JjJD0nLmpzJ11cIilcbiAgaWYgIXNjIFxuICAgIHJldHVybiBmYWxzZSBcblxuICB2YWwgPSBzYy5nZXRBdHRyaWJ1dGUoYXR0cilcblxuICBpZiB2YWwgPT0gJydcbiAgICB2YWwgPSB0cnVlIFxuICB2YWwgXG4gIFxuXG5zbHVnaWZ5ID0gKHRleHQpIC0+IFxuICB0ZXh0IHx8PSBcIlwiXG4gIHRleHQudG9TdHJpbmcoKS50b0xvd2VyQ2FzZSgpXG4gICAgLnJlcGxhY2UoL1xccysvZywgJy0nKSAgICAgICAgICAgIyBSZXBsYWNlIHNwYWNlcyB3aXRoIC1cbiAgICAucmVwbGFjZSgvW15cXHdcXC1dKy9nLCAnJykgICAgICAgIyBSZW1vdmUgYWxsIG5vbi13b3JkIGNoYXJzXG4gICAgLnJlcGxhY2UoL1xcLVxcLSsvZywgJy0nKSAgICAgICAgICMgUmVwbGFjZSBtdWx0aXBsZSAtIHdpdGggc2luZ2xlIC1cbiAgICAucmVwbGFjZSgvXi0rLywgJycpICAgICAgICAgICAgICMgVHJpbSAtIGZyb20gc3RhcnQgb2YgdGV4dFxuICAgIC5yZXBsYWNlKC8tKyQvLCAnJykgICAgICAgICAgICAgIyBUcmltIC0gZnJvbSBlbmQgb2YgdGV4dFxuICAgIC5zdWJzdHJpbmcoMCwgMzApXG5cbiMgQ2hlY2tzIHRoaXMgbm9kZSBhbmQgYW5jZXN0b3JzIHdoZXRoZXIgY2hlY2sgaG9sZHMgdHJ1ZVxud2luZG93LmNsb3Nlc3QgPSAobm9kZSwgY2hlY2spIC0+IFxuICBpZiAhbm9kZSB8fCBub2RlID09IGRvY3VtZW50XG4gICAgZmFsc2VcbiAgZWxzZSBcbiAgICBjaGVjayhub2RlKSB8fCBjbG9zZXN0KG5vZGUucGFyZW50Tm9kZSwgY2hlY2spXG5cblxuIyMjIyMjIyMjIyMjIyMjIyMjIyNcbiMjIyBUcmFja2luZyBcbiMjI1xuIyMjIyNcblxuIyBVc2VkIHRvIHRyYWNrIHdoaWNoIGl0ZW1zIGEgdXNlciBoYXMgaW50ZXJhY3RlZCB3aXRoLiBVc2VmdWwgZm9yIGUuZy4gbm90aWZpY2F0aW9ucy5cbndpbmRvdy5zYXdfdGhpbmcgPSAoa2V5c19vcl9vYmplY3RzKSAtPiBcbiAgc2VlbiA9IGZldGNoICdzZWVuX2luX3Nlc3Npb24nXG4gIHNlZW4uaXRlbXMgfHw9IHt9XG5cbiAgaWYgIShrZXlzX29yX29iamVjdHMgaW5zdGFuY2VvZiBBcnJheSlcbiAgICBrZXlzX29yX29iamVjdHMgPSBba2V5c19vcl9vYmplY3RzXVxuICBmb3Iga2V5X29yX29iamVjdCBpbiBrZXlzX29yX29iamVjdHNcbiAgICBrZXkgPSBrZXlfb3Jfb2JqZWN0LmtleSBvciBrZXlfb3Jfb2JqZWN0XG4gICAgc2Vlbi5pdGVtc1trZXldID0gZmFsc2UgXG5cbiAgc2F2ZSBzZWVuXG5cbiMgY2FsbCB0aGlzIG1ldGhvZCBpZiB5b3Ugd2FudCB5b3VyIGFwcGxpY2F0aW9uIHRvIHJlcG9ydCB0byB0aGUgc2VydmVyIHdoYXQgdXNlcnMgXG4jIHNlZSAodmlhIHNhd190aGluZylcbndpbmRvdy5yZXBvcnRfc2VlbiA9IChuYW1lc3BhY2UpIC0+XG4gIHdhaXRfZm9yX2J1cyAtPiBcbiAgICBuYW1lc3BhY2UgfHw9ICcnIFxuICAgIGRvIChuYW1lc3BhY2UpIC0+IFxuICAgICAgcmVwb3J0ZXIgPSBidXMucmVhY3RpdmUgLT4gXG4gICAgICAgIHNlZW4gPSBmZXRjaCAnc2Vlbl9pbl9zZXNzaW9uJ1xuICAgICAgICBzZWVuLml0ZW1zIHx8PSB7fVxuXG4gICAgICAgIHRvX3JlcG9ydCA9IFtdXG4gICAgICAgIGZvciBrLHYgb2Ygc2Vlbi5pdGVtcyB3aGVuIGsgIT0gJ2tleScgJiYgIXYgXG4gICAgICAgICAgdG9fcmVwb3J0LnB1c2ggayBcbiAgICAgICAgICBzZWVuLml0ZW1zW2tdID0gdHJ1ZVxuXG4gICAgICAgIGlmIHRvX3JlcG9ydC5sZW5ndGggPiAwIFxuICAgICAgICAgIHNhdmVcbiAgICAgICAgICAgIGtleTogXCIvc2Vlbi8je0pTT04uc3RyaW5naWZ5KHt1c2VyOnlvdXJfa2V5KCksIG5hbWVzcGFjZTogbmFtZXNwYWNlfSl9XCJcbiAgICAgICAgICAgIHNhdzogdG9fcmVwb3J0XG5cbiAgICAgICAgICBzYXZlIHNlZW4gXG5cbiAgICAgIHJlcG9ydGVyKClcblxuXG5cblxuXG5cblxuXG4jIyMjIyNcbiMgUmVnaXN0ZXJpbmcgd2luZG93IGV2ZW50cy5cbiMgU29tZXRpbWVzIHlvdSB3YW50IHRvIGhhdmUgZXZlbnRzIGF0dGFjaGVkIHRvIHRoZSB3aW5kb3cgdGhhdCByZXNwb25kIGJhY2sgXG4jIHRvIGEgcGFydGljdWxhciBpZGVudGlmaWVyLCBhbmQgZ2V0IGNsZWFuZWQgdXAgcHJvcGVybHkuIEFuZCB3aG9zZSBwcmlvcml0eVxuIyB5b3UgY2FuIGNvbnRyb2wuXG5cbndpbmRvdy5hdHRhY2hlZF9ldmVudHMgPSB7fVxuXG5yZWdpc3Rlcl93aW5kb3dfZXZlbnQgPSAoaWQsIGV2ZW50X3R5cGUsIGhhbmRsZXIsIHByaW9yaXR5KSAtPiBcbiAgaWQgPSBpZC5rZXkgb3IgaWRcbiAgcHJpb3JpdHkgPSBwcmlvcml0eSBvciAwXG5cbiAgYXR0YWNoZWRfZXZlbnRzW2V2ZW50X3R5cGVdIHx8PSBbXVxuXG4gICMgcmVtb3ZlIGFueSBwcmV2aW91cyBkdXBsaWNhdGVzXG4gIGZvciBlLGlkeCBpbiBhdHRhY2hlZF9ldmVudHNbZXZlbnRfdHlwZV0gXG4gICAgaWYgZS5pZCA9PSBpZFxuICAgICAgdW5yZWdpc3Rlcl93aW5kb3dfZXZlbnQoaWQsIGV2ZW50X3R5cGUpXG5cbiAgaWYgYXR0YWNoZWRfZXZlbnRzW2V2ZW50X3R5cGVdLmxlbmd0aCA9PSAwXG4gICAgd2luZG93LmFkZEV2ZW50TGlzdGVuZXIgZXZlbnRfdHlwZSwgaGFuZGxlX3dpbmRvd19ldmVudFxuXG4gIGF0dGFjaGVkX2V2ZW50c1tldmVudF90eXBlXS5wdXNoIHsgaWQsIGhhbmRsZXIsIHByaW9yaXR5IH1cblxuICBkdXBzID0gW11cbiAgZm9yIGUsaWR4IGluIGF0dGFjaGVkX2V2ZW50c1tldmVudF90eXBlXSBcbiAgICBpZiBlLmlkID09IGlkIFxuICAgICAgZHVwcy5wdXNoIGVcbiAgaWYgZHVwcy5sZW5ndGggPiAxXG4gICAgY29uc29sZS53YXJuIFwiRFVQTElDQVRFIEVWRU5UUyBGT1IgI3tpZH1cIiwgZXZlbnRfdHlwZVxuICAgIGZvciBlIGluIGR1cHNcbiAgICAgIGNvbnNvbGUud2FybiBlLmhhbmRsZXJcblxudW5yZWdpc3Rlcl93aW5kb3dfZXZlbnQgPSAoaWQsIGV2ZW50X3R5cGUpIC0+IFxuICBpZCA9IGlkLmtleSBvciBpZFxuXG4gIGZvciBldl90eXBlLCBldmVudHMgb2YgYXR0YWNoZWRfZXZlbnRzXG4gICAgY29udGludWUgaWYgZXZlbnRfdHlwZSAmJiBldmVudF90eXBlICE9IGV2X3R5cGVcblxuICAgIG5ld19ldmVudHMgPSBldmVudHMuc2xpY2UoKVxuXG4gICAgZm9yIGV2LGlkeCBpbiBldmVudHMgYnkgLTFcbiAgICAgIGlmIGV2LmlkID09IGlkIFxuICAgICAgICBuZXdfZXZlbnRzLnNwbGljZSBpZHgsIDFcblxuICAgIGF0dGFjaGVkX2V2ZW50c1tldl90eXBlXSA9IG5ld19ldmVudHNcbiAgICBpZiBuZXdfZXZlbnRzLmxlbmd0aCA9PSAwXG4gICAgICB3aW5kb3cucmVtb3ZlRXZlbnRMaXN0ZW5lciBldl90eXBlLCBoYW5kbGVfd2luZG93X2V2ZW50XG5cbmhhbmRsZV93aW5kb3dfZXZlbnQgPSAoZXYpIC0+XG4gICMgc29ydCBoYW5kbGVycyBieSBwcmlvcml0eVxuICBhdHRhY2hlZF9ldmVudHNbZXYudHlwZV0uc29ydCAoYSxiKSAtPiBiLnByaW9yaXR5IC0gYS5wcmlvcml0eVxuXG4gICMgc28gdGhhdCB3ZSBrbm93IGlmIGFuIGV2ZW50IGhhbmRsZXIgc3RvcHBlZCBwcm9wYWdhdGlvbi4uLlxuICBldi5fc3RvcFByb3BhZ2F0aW9uID0gZXYuc3RvcFByb3BhZ2F0aW9uXG4gIGV2LnN0b3BQcm9wYWdhdGlvbiA9IC0+XG4gICAgZXYucHJvcGFnYXRpb25fc3RvcHBlZCA9IHRydWVcbiAgICBldi5fc3RvcFByb3BhZ2F0aW9uKClcblxuICAjIHJ1biBoYW5kbGVycyBpbiBvcmRlciBvZiBwcmlvcml0eVxuICBmb3IgZSBpbiBhdHRhY2hlZF9ldmVudHNbZXYudHlwZV1cblxuICAgICNjb25zb2xlLmxvZyBcIlxcdCBFWEVDVVRJTkcgI3tldi50eXBlfSAje2UuaWR9XCIsIGUuaGFuZGxlclxuICAgIGUuaGFuZGxlcihldilcblxuICAgICMgZG9uJ3QgcnVuIGxvd2VyIHByaW9yaXR5IGV2ZW50cyB3aGVuIHRoZSBldmVudCBpcyBubyBcbiAgICAjIGxvbmdlciBzdXBwb3NlZCB0byBidWJibGVcbiAgICBpZiBldi5wcm9wYWdhdGlvbl9zdG9wcGVkICN8fCBldi5kZWZhdWx0UHJldmVudGVkXG4gICAgICBicmVhayBcblxuXG5cbiMgQ29tcHV0ZXMgdGhlIHdpZHRoL2hlaWdodCBvZiBzb21lIHRleHQgZ2l2ZW4gc29tZSBzdHlsZXNcbnNpemVfY2FjaGUgPSB7fVxud2luZG93LnNpemVXaGVuUmVuZGVyZWQgPSAoc3RyLCBzdHlsZSkgLT4gXG4gIG1haW4gPSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnbWFpbi1jb250ZW50Jykgb3IgZG9jdW1lbnQucXVlcnlTZWxlY3RvcignW2RhdGEtd2lkZ2V0PVwiYm9keVwiXScpXG5cbiAgcmV0dXJuIHt3aWR0aDogMCwgaGVpZ2h0OiAwfSBpZiAhbWFpblxuXG4gIHN0eWxlIHx8PSB7fVxuICAjIFRoaXMgRE9NIG1hbmlwdWxhdGlvbiBpcyByZWxhdGl2ZWx5IGV4cGVuc2l2ZSwgc28gY2FjaGUgcmVzdWx0c1xuICBzdHlsZS5zdHIgPSBzdHJcbiAga2V5ID0gSlNPTi5zdHJpbmdpZnkgc3R5bGVcbiAgZGVsZXRlIHN0eWxlLnN0clxuXG4gIGlmIGtleSBub3Qgb2Ygc2l6ZV9jYWNoZVxuICAgIHN0eWxlLmRpc3BsYXkgfHw9ICdpbmxpbmUtYmxvY2snXG5cbiAgICB0ZXN0ID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudChcInNwYW5cIilcbiAgICB0ZXN0LmlubmVySFRNTCA9IFwiPHNwYW4+I3tzdHJ9PC9zcGFuPlwiXG4gICAgZm9yIGssdiBvZiBzdHlsZVxuICAgICAgdGVzdC5zdHlsZVtrXSA9IHZcblxuICAgIG1haW4uYXBwZW5kQ2hpbGQgdGVzdCBcbiAgICBoID0gdGVzdC5vZmZzZXRIZWlnaHRcbiAgICB3ID0gdGVzdC5vZmZzZXRXaWR0aFxuICAgIG1haW4ucmVtb3ZlQ2hpbGQgdGVzdFxuXG4gICAgc2l6ZV9jYWNoZVtrZXldID0gXG4gICAgICB3aWR0aDogd1xuICAgICAgaGVpZ2h0OiBoXG5cbiAgc2l6ZV9jYWNoZVtrZXldXG5cbndpbmRvdy5nZXRDb29yZHMgPSAoZWwpIC0+XG4gIHJlY3QgPSBlbC5nZXRCb3VuZGluZ0NsaWVudFJlY3QoKVxuICBkb2NFbCA9IGRvY3VtZW50LmRvY3VtZW50RWxlbWVudFxuXG4gIG9mZnNldCA9IFxuICAgIHRvcDogcmVjdC50b3AgKyB3aW5kb3cucGFnZVlPZmZzZXQgLSBkb2NFbC5jbGllbnRUb3BcbiAgICBsZWZ0OiByZWN0LmxlZnQgKyB3aW5kb3cucGFnZVhPZmZzZXQgLSBkb2NFbC5jbGllbnRMZWZ0XG4gIGV4dGVuZCBvZmZzZXQsXG4gICAgY3g6IG9mZnNldC5sZWZ0ICsgcmVjdC53aWR0aCAvIDJcbiAgICBjeTogb2Zmc2V0LnRvcCArIHJlY3QuaGVpZ2h0IC8gMlxuICAgIHdpZHRoOiByZWN0LndpZHRoIFxuICAgIGhlaWdodDogcmVjdC5oZWlnaHRcblxuXG5cbiMgSEVBUlRCRUFUXG4jIEFueSBjb21wb25lbnQgdGhhdCByZW5kZXJzIGEgSEVBUlRCRUFUIHdpbGwgZ2V0IHJlcmVuZGVyZWQgb24gYW4gaW50ZXJ2YWwuXG4jIHByb3BzOiBcbiMgICBwdWJsaWNfa2V5OiB0aGUga2V5IHRvIHN0b3JlIHRoZSBoZWFydGJlYXQgYXRcbiMgICBpbnRlcnZhbDogbGVuZ3RoIGJldHdlZW4gcHVsc2VzLCBpbiBtcyAoZGVmYXVsdD0xMDAwKVxuZG9tLkhFQVJUQkVBVCA9IC0+ICAgXG4gIGJlYXQgPSBmZXRjaChAcHJvcHMucHVibGljX2tleSBvciAncHVsc2UnKVxuICBpZiAhYmVhdC5iZWF0P1xuICAgIHNldEludGVydmFsIC0+ICAgXG4gICAgICBiZWF0LmJlYXQgPSAoYmVhdC5iZWF0IG9yIDApICsgMVxuICAgICAgc2F2ZShiZWF0KVxuICAgICwgKEBwcm9wcy5pbnRlcnZhbCBvciAxMDAwKVxuXG4gIFNQQU4gbnVsbFxuXG5cblxuZG9tLkFVVE9TSVpFQk9YID0gLT5cbiAgQHByb3BzLnN0eWxlIHx8PSB7fVxuICBAcHJvcHMuc3R5bGUucmVzaXplID0gaWYgQHByb3BzLnN0eWxlLndpZHRoIG9yIEBwcm9wcy5jb2xzIHRoZW4gJ25vbmUnIGVsc2UgJ2hvcml6b250YWwnXG4gIEBwcm9wcy5yb3dzIHx8PSAxXG4gIFRFWFRBUkVBIEBwcm9wc1xuXG5yZXNpemVib3ggPSAodGFyZ2V0KSAtPlxuICB0YXJnZXQuc3R5bGUuaGVpZ2h0ID0gbnVsbFxuICB3aGlsZSAodGFyZ2V0LnJvd3MgPiAxICYmIHRhcmdldC5zY3JvbGxIZWlnaHQgPCB0YXJnZXQub2Zmc2V0SGVpZ2h0IClcbiAgICB0YXJnZXQucm93cy0tXG4gIHdoaWxlICh0YXJnZXQuc2Nyb2xsSGVpZ2h0ID4gdGFyZ2V0Lm9mZnNldEhlaWdodCAmJiB0YXJnZXQucm93cyA8IDk5OSlcbiAgICB0YXJnZXQucm93cysrXG5cbmRvbS5BVVRPU0laRUJPWC51cCAgICAgID0gLT4gcmVzaXplYm94IEBnZXRET01Ob2RlKClcblxuZG9tLkFVVE9TSVpFQk9YLnJlZnJlc2ggPSAtPiBcbiAgcmVzaXplYm94IEBnZXRET01Ob2RlKClcblxuICBpZiAhQGluaXQgXG4gICAgQGluaXQgPSB0cnVlIFxuICAgIGVsID0gQGdldERPTU5vZGUoKVxuXG4gICAgaWYgKEBwcm9wcy5hdXRvZm9jdXMgfHwgQHByb3BzLmN1cnNvcikgJiYgZWwgIT0gZG9jdW1lbnQuYWN0aXZlRWxlbWVudFxuICAgICAgIyBGb2N1cyB0aGUgdGV4dCBhcmVhIGlmIHdlIGp1c3QgY2xpY2tlZCBpbnRvIHRoZSBlZGl0b3IgICAgICBcbiAgICAgICMgdXNlIHNlbGVjdCgpLCBub3QgZm9jdXMoKSwgYmVjYXVzZSB0aGlzIGF2ZXJ0cyB0aGUgYnJvd3NlciBmcm9tIFxuICAgICAgIyBhdXRvbWF0aWNhbGx5IHNjcm9sbGluZyB0aGUgcGFnZSB0byB0aGUgdG9wIG9mIHRoZSB0ZXh0IGFyZWEsIFxuICAgICAgIyB3aGljaCBpbnRlcmZlcmVzIHdpdGggY2xpY2tpbmcgaW5zaWRlIGEgbG9uZyBwb3N0IHRvIHN0YXJ0IGVkaXRpbmdcbiAgICAgIGVsLnNlbGVjdCgpXG5cbiAgICBpZiBAcHJvcHMuY3Vyc29yICYmIGVsLnNldFNlbGVjdGlvblJhbmdlXG4gICAgICBlbC5zZXRTZWxlY3Rpb25SYW5nZShAcHJvcHMuY3Vyc29yLCBAcHJvcHMuY3Vyc29yKVxuXG5cblxuXG4jIEF1dG8gZ3Jvd2luZyB0ZXh0IGFyZWEuIFxuIyBUcmFuc2ZlcnMgcHJvcHMgdG8gYSBURVhUQVJFQS5cbmRvbS5HUk9XSU5HX1RFWFRBUkVBID0gLT5cbiAgQHByb3BzLnN0eWxlIHx8PSB7fVxuICBAcHJvcHMuc3R5bGUubWluSGVpZ2h0IHx8PSA2MFxuICBAcHJvcHMuc3R5bGUuaGVpZ2h0ID0gXFxcbiAgICAgIEBsb2NhbC5oZWlnaHQgfHwgQHByb3BzLmluaXRpYWxfaGVpZ2h0IHx8IEBwcm9wcy5zdHlsZS5taW5IZWlnaHRcbiAgQHByb3BzLnN0eWxlLmZvbnRGYW1pbHkgfHw9ICdpbmhlcml0J1xuICBAcHJvcHMuc3R5bGUubGluZUhlaWdodCB8fD0gJzIycHgnXG4gIEBwcm9wcy5zdHlsZS5yZXNpemUgfHw9ICdub25lJ1xuICBAcHJvcHMuc3R5bGUub3V0bGluZSB8fD0gJ25vbmUnXG5cbiAgIyBzYXZlIHRoZSBzdXBwbGllZCBvbkNoYW5nZSBmdW5jdGlvbiBpZiB0aGUgY2xpZW50IHN1cHBsaWVzIG9uZVxuICBfb25DaGFuZ2UgPSBAcHJvcHMub25DaGFuZ2UgICAgXG4gIF9vbkNsaWNrID0gQHByb3BzLm9uQ2xpY2tcblxuICBAcHJvcHMub25DbGljayA9IChldikgLT4gXG4gICAgX29uQ2xpY2s/KGV2KSAgXG4gICAgZXYucHJldmVudERlZmF1bHQoKTsgZXYuc3RvcFByb3BhZ2F0aW9uKClcblxuICBAcHJvcHMub25DaGFuZ2UgPSAoZXYpID0+IFxuICAgIF9vbkNoYW5nZT8oZXYpICBcbiAgICBAYWRqdXN0SGVpZ2h0KClcblxuICBAYWRqdXN0SGVpZ2h0ID0gPT4gXG4gICAgdGV4dGFyZWEgPSBAZ2V0RE9NTm9kZSgpXG5cbiAgICBpZiAhdGV4dGFyZWEudmFsdWUgfHwgdGV4dGFyZWEudmFsdWUgPT0gJydcbiAgICAgIGggPSBAcHJvcHMuaW5pdGlhbF9oZWlnaHQgfHwgQHByb3BzLnN0eWxlLm1pbkhlaWdodFxuXG4gICAgICBpZiBoICE9IEBsb2NhbC5oZWlnaHRcbiAgICAgICAgQGxvY2FsLmhlaWdodCA9IGhcbiAgICAgICAgc2F2ZSBAbG9jYWxcbiAgICBlbHNlIFxuICAgICAgbWluX2hlaWdodCA9IEBwcm9wcy5zdHlsZS5taW5IZWlnaHRcbiAgICAgIG1heF9oZWlnaHQgPSBAcHJvcHMuc3R5bGUubWF4SGVpZ2h0XG5cbiAgICAgICMgR2V0IHRoZSByZWFsIHNjcm9sbGhlaWdodCBvZiB0aGUgdGV4dGFyZWFcbiAgICAgIGggPSB0ZXh0YXJlYS5zdHlsZS5oZWlnaHRcbiAgICAgIHRleHRhcmVhLnN0eWxlLmhlaWdodCA9ICcnIGlmIEBsYXN0X3ZhbHVlPy5sZW5ndGggPiB0ZXh0YXJlYS52YWx1ZS5sZW5ndGhcbiAgICAgIHNjcm9sbF9oZWlnaHQgPSB0ZXh0YXJlYS5zY3JvbGxIZWlnaHRcbiAgICAgIHRleHRhcmVhLnN0eWxlLmhlaWdodCA9IGggIGlmIEBsYXN0X3ZhbHVlPy5sZW5ndGggPiB0ZXh0YXJlYS52YWx1ZS5sZW5ndGhcblxuICAgICAgaWYgc2Nyb2xsX2hlaWdodCAhPSB0ZXh0YXJlYS5jbGllbnRIZWlnaHRcbiAgICAgICAgaCA9IHNjcm9sbF9oZWlnaHQgKyA1XG4gICAgICAgIGlmIG1heF9oZWlnaHRcbiAgICAgICAgICBoID0gTWF0aC5taW4oc2Nyb2xsX2hlaWdodCwgbWF4X2hlaWdodClcbiAgICAgICAgaCA9IE1hdGgubWF4KG1pbl9oZWlnaHQsIGgpXG5cbiAgICAgICAgaWYgaCAhPSBAbG9jYWwuaGVpZ2h0XG4gICAgICAgICAgQGxvY2FsLmhlaWdodCA9IGhcbiAgICAgICAgICBzYXZlIEBsb2NhbFxuXG4gICAgQGxhc3RfdmFsdWUgPSB0ZXh0YXJlYS52YWx1ZVxuXG4gIFRFWFRBUkVBIEBwcm9wc1xuXG5cbmRvbS5HUk9XSU5HX1RFWFRBUkVBLnJlZnJlc2ggPSAtPiBcbiAgQGFkanVzdEhlaWdodCgpXG5cblxuXG5cblxuXG5cblxuXG5cblxuXG5kb20uV1lTSVdZRyA9IC0+IFxuICBteV9kYXRhID0gZmV0Y2ggQHByb3BzLm9ialxuXG4gIEBsb2NhbC5tb2RlID89IG15X2RhdGEuZWRpdF9tb2RlIG9yICdtYXJrZG93bidcblxuICBpZiAhQHByb3BzLmRpc2FibGVfaHRtbFxuICAgIG1vZGVzID0gW3tsYWJlbDogJ21hcmtkb3duJywgaWQ6ICdtYXJrZG93bid9LCB7bGFiZWw6ICdyYXcgaHRtbCcsIGlkOiAnaHRtbCd9XVxuICBlbHNlIFxuICAgIG1vZGVzID0gW3tsYWJlbDogJ21hcmtkb3duJywgaWQ6ICdtYXJrZG93bid9XSBcblxuICBESVYgXG4gICAgc3R5bGU6IFxuICAgICAgcG9zaXRpb246ICdyZWxhdGl2ZSdcbiAgICBvbkJsdXI6IEBwcm9wcy5vbkJsdXJcblxuICAgIFNUWUxFIFwiXCJcIlxuICAgICAgICAgIC5lZGl0b3ItdG9vbGJhciAuZmEge1xuICAgICAgICAgICAgICBjb2xvcjogICM0NDQ0NDQ7XG4gICAgICAgICAgfVxuICAgICAgICBcIlwiXCJcblxuICAgIGlmIG1vZGVzLmxlbmd0aCA+IDEgXG4gICAgICBESVYgXG4gICAgICAgIHN0eWxlOiBcbiAgICAgICAgICBwb3NpdGlvbjogJ2Fic29sdXRlJ1xuICAgICAgICAgIHRvcDogLTI4XG4gICAgICAgICAgbGVmdDogMFxuXG4gICAgICAgIGZvciBtb2RlIGluIG1vZGVzIFxuICAgICAgICAgIGRvIChtb2RlKSA9PlxuICAgICAgICAgICAgQlVUVE9OXG4gICAgICAgICAgICAgIHN0eWxlOiBcbiAgICAgICAgICAgICAgICBiYWNrZ3JvdW5kOiAndHJhbnNwYXJlbnQnXG4gICAgICAgICAgICAgICAgYm9yZGVyOiAnbm9uZSdcbiAgICAgICAgICAgICAgICB0ZXh0VHJhbnNmb3JtOiAndXBwZXJjYXNlJ1xuICAgICAgICAgICAgICAgIGNvbG9yOiBpZiBAbG9jYWwubW9kZSA9PSBtb2RlLmlkIHRoZW4gJyM1NTUnIGVsc2UgJyM5OTknXG4gICAgICAgICAgICAgICAgcGFkZGluZzogJzBweCA4cHggMCAwJ1xuICAgICAgICAgICAgICAgIGZvbnRTaXplOiAxMlxuICAgICAgICAgICAgICAgIGZvbnRXZWlnaHQ6IDcwMFxuICAgICAgICAgICAgICAgIGN1cnNvcjogaWYgQGxvY2FsLm1vZGUgPT0gbW9kZS5pZCB0aGVuICdhdXRvJ1xuXG4gICAgICAgICAgICAgIG9uQ2xpY2s6IChlKSA9PiBcbiAgICAgICAgICAgICAgICBAbG9jYWwubW9kZSA9IG15X2RhdGEuZWRpdF9tb2RlID0gbW9kZS5pZFxuICAgICAgICAgICAgICAgIHNhdmUgQGxvY2FsOyBzYXZlIG15X2RhdGFcblxuICAgICAgICAgICAgICBtb2RlLmxhYmVsXG5cbiAgICBpZiBAbG9jYWwubW9kZSA9PSAnaHRtbCdcbiAgICAgIEFVVE9TSVpFQk9YXG4gICAgICAgIHN0eWxlOiBcbiAgICAgICAgICB3aWR0aDogJzEwMCUnXG4gICAgICAgICAgZm9udFNpemU6ICdpbmhlcml0J1xuICAgICAgICBkZWZhdWx0VmFsdWU6IG15X2RhdGFbQHByb3BzLmF0dHJdIG9yICdcXG4nXG4gICAgICAgIGF1dG9mb2N1czogdHJ1ZVxuICAgICAgICBhdXRvRm9jdXM6IHRydWVcbiAgICAgICAgb25DaGFuZ2U6IChlKSA9PiBcbiAgICAgICAgICBteV9kYXRhW0Bwcm9wcy5hdHRyXSA9IGUudGFyZ2V0LnZhbHVlXG4gICAgICAgICAgc2F2ZSBteV9kYXRhXG5cbiAgICBlbHNlIGlmIEBsb2NhbC5tb2RlID09ICdtYXJrZG93bidcbiAgICAgIEVBU1lNQVJLRE9XTiBAcHJvcHNcbiAgICAjIGVsc2UgaWYgQGxvY2FsLm1vZGUgPT0gJ2h0bWwnXG4gICAgIyAgIFRSSVhfV1lTSVdZRyBAcHJvcHNcblxuXG5cblxuc2V0X3N0eWxlIFwiXCJcIlxuICBbZGF0YS13aWRnZXQ9XCJVbmNvbnRyb2xsZWRUZXh0XCJdIHA6Zmlyc3Qtb2YtdHlwZSB7XG4gICAgbWFyZ2luLXRvcDogMDtcbiAgfVxuXG5cIlwiXCJcblxuZG9tLkVBU1lNQVJLRE9XTiA9IC0+XG4gIGlmICFAbG9jYWwuaW5pdGlhbGl6ZWRcbiAgICAjIFdlIHN0b3JlIHRoZSBjdXJyZW50IHZhbHVlIG9mIHRoZSBIVE1MIGF0XG4gICAgIyB0aGlzIGNvbXBvbmVudCdzIGtleS4gVGhpcyBhbGxvd3MgdGhlICBcbiAgICAjIHBhcmVudCBjb21wb25lbnQgdG8gZmV0Y2ggdGhlIHZhbHVlIG91dHNpZGUgXG4gICAgIyBvZiB0aGlzIGdlbmVyaWMgd3lzaXd5ZyBjb21wb25lbnQuIFxuICAgICMgSG93ZXZlciwgd2UgXCJkYW5nZXJvdXNseVwiIHNldCB0aGUgaHRtbCBvZiB0aGUgXG4gICAgIyBlZGl0b3IgdG8gdGhlIG9yaWdpbmFsIEBwcm9wcy5odG1sLiBUaGlzIGlzIFxuICAgICMgYmVjYXVzZSB3ZSBkb24ndCB3YW50IHRvIGludGVyZmVyZSB3aXRoIHRoZSBcbiAgICAjIHd5c2l3eWcgZWRpdG9yJ3MgYWJpbGl0eSB0byBtYW5hZ2UgZS5nLiBcbiAgICAjIHRoZSBzZWxlY3Rpb24gbG9jYXRpb24uIFxuICAgIG15X2RhdGEgPSBmZXRjaCBAcHJvcHMub2JqXG4gICAgQGxvY2FsLmluaXRpYWxpemVkID0gdHJ1ZVxuICAgIEBsb2NhbC5pZCA9IFwiI3tAbG9jYWwua2V5fS1lYXN5bWFya2Rvd24tZWRpdG9yXCJcbiAgICBzYXZlIEBsb2NhbFxuIFxuXG4gIERJViBudWxsLCBcbiAgICBURVhUQVJFQSBleHRlbmQge30sIEBwcm9wcyxcbiAgICAgIHN0eWxlOiBAcHJvcHMuc3R5bGUgb3Ige31cbiAgICAgIGlkOiBAbG9jYWwuaWQgXG5cbmRvbS5FQVNZTUFSS0RPV04ucmVmcmVzaCA9IC0+IFxuICBpZiAhQGluaXQgXG4gICAgQGluaXQgPSB0cnVlXG4gICAgZWRpdG9yID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQgQGxvY2FsLmlkXG4gICAgbXlfZGF0YSA9IGZldGNoIEBwcm9wcy5vYmpcblxuICAgIEBlZGl0b3IgPSBuZXcgRWFzeU1ERVxuICAgICAgZWxlbWVudDogZWRpdG9yXG4gICAgICBpbml0aWFsVmFsdWU6IG15X2RhdGFbXCIje0Bwcm9wcy5hdHRyfV9zcmNcIl0gb3IgbXlfZGF0YS5zcmMgb3IgbXlfZGF0YVtAcHJvcHMuYXR0cl0gb3IgJ1xcbidcbiAgICAgIGF1dG9mb2N1czogISFAcHJvcHMuYXV0b2ZvY3VzXG4gICAgICBpbnNlcnRUZXh0czogXG4gICAgICAgIGltYWdlOiBbJzxpbWcgc3R5bGU9XCJhc3BlY3QtcmF0aW86I3dpZHRoLyNoZWlnaHRcIiB3aWR0aD1cIjEwMCVcIiBzcmM9XCInLCAnI3VybCNcIiAvPlxcbiddXG4gICAgICAgIHVwbG9hZGVkSW1hZ2U6IFsnPGltZyB3aWR0aD1cIjEwMCVcIiBzcmM9XCIjdXJsI1wiIC8+IFxcbicsICcnXVxuICAgICAgICB1cGxvYWRlZE1vdmllOiBbXCJcIlwiXG4gICAgICAgICAgICAgIDx2aWRlbyB3aWR0aD1cIjEwMCVcIiBjb250cm9scyBhdXRvcGxheSBwbGF5c2lubGluZSBsb29wIG11dGVkPlxcbiBcXFxuICAgICAgICAgICAgICAgIDxzb3VyY2Ugc3JjPVwiI2V4dGVudGlvbmxlc3NfdXJsIy5tcDRcIiB0eXBlPVwidmlkZW8vbXA0XCI+XFxuIFxcXG4gICAgICAgICAgICAgICA8L3ZpZGVvPiBcXFxuICAgICAgICAgICAgICBcIlwiXCIsICcnXVxuICAgICAgdXBsb2FkSW1hZ2U6IHRydWUgXG4gICAgICBpbWFnZVVwbG9hZEZ1bmN0aW9uOiAoZiwgb25TdWNjZXNzLCBvbkVycm9yKSAtPlxuICAgICAgICByZXR1cm4gaWYgZi50eXBlIG5vdCBpbiBbXCJpbWFnZS9wbmdcIiwgXCJpbWFnZS9qcGVnXCIsIFwidmlkZW8vcXVpY2t0aW1lXCIsIFwidmlkZW8vbXA0XCIsIFwidmlkZW8vd2VibVwiXVxuXG4gICAgICAgIHN1YmRpcmVjdG9yeSA9IG15X2RhdGEua2V5LnNwbGl0KCcvJylcbiAgICAgICAgc3ViZGlyZWN0b3J5ID0gc3ViZGlyZWN0b3J5W3N1YmRpcmVjdG9yeS5sZW5ndGggLSAxXVxuXG4gICAgICAgIGNvbnNvbGUubG9nICdTZW5kaW5nIGZpbGUnLCBmLm5hbWVcbiAgICAgICAgeGhyID0gbmV3IFhNTEh0dHBSZXF1ZXN0KClcbiAgICAgICAgeGhyLm9wZW4gJ1BPU1QnLCAnL3VwbG9hZCcsIHRydWVcbiAgICAgICAgeGhyLnNldFJlcXVlc3RIZWFkZXIgJ0NvbnRlbnQtVHlwZScsIGYudHlwZVxuICAgICAgICB4aHIuc2V0UmVxdWVzdEhlYWRlciAnQ29udGVudC1EaXNwb3NpdGlvbicsIFwiYXR0YWNobWVudDsgZmlsZW5hbWU9XFxcIiN7Zi5uYW1lfVxcXCJcIlxuICAgICAgICB4aHIuc2V0UmVxdWVzdEhlYWRlciAnQ29udGVudC1GaWxlbmFtZScsIGYubmFtZVxuICAgICAgICB4aHIuc2V0UmVxdWVzdEhlYWRlciAnQ29udGVudC1EaXJlY3RvcnknLCBzdWJkaXJlY3RvcnlcblxuICAgICAgICB4aHIub25yZWFkeXN0YXRlY2hhbmdlID0gLT5cbiAgICAgICAgICBpZiB4aHIucmVhZHlTdGF0ZSA9PSBYTUxIdHRwUmVxdWVzdC5ET05FXG4gICAgICAgICAgICBzdGF0dXMgPSB4aHIuc3RhdHVzXG4gICAgICAgICAgICBpZiBzdGF0dXMgPT0gMCB8fCAoc3RhdHVzID49IDIwMCAmJiBzdGF0dXMgPCA0MDApXG4gICAgICAgICAgICAgIGltZ191cmwgPSBcIiN7ZG9jdW1lbnQuYm9keS5nZXRBdHRyaWJ1dGUoJ2RhdGEtc3RhdGljLXByZWZpeCcpfS9tZWRpYS8je3N1YmRpcmVjdG9yeX0vI3tmLm5hbWV9XCJcbiAgICAgICAgICAgICAgY29uc29sZS5sb2cgXCJET05FISAje2YubmFtZX0gI3tpbWdfdXJsfVwiLCBzdGF0dXNcblxuICAgICAgICAgICAgICBvblN1Y2Nlc3MoaW1nX3VybClcbiAgICAgICAgICAgIGVsc2UgXG4gICAgICAgICAgICAgIG9uRXJyb3IgJ2NvdWxkIG5vdCBwcm9jZXNzIGZpbGUnXG5cbiAgICAgICAgeGhyLnNlbmQgZlxuXG5cblxuICAgIGFjdHVhbF9lZGl0b3IgPSBlZGl0b3IubmV4dEVsZW1lbnRTaWJsaW5nLnF1ZXJ5U2VsZWN0b3IoXCIuQ29kZU1pcnJvci1jb2RlXCIpXG4gXG4gICAgaWYgQHByb3BzLmF1dG9mb2N1c1xuICAgICAgQGVkaXRvci5jb2RlbWlycm9yLmZvY3VzKClcbiAgICAgIGFjdHVhbF9lZGl0b3I/LmZvY3VzKClcblxuICAgIEBlZGl0b3IuY29kZW1pcnJvci5vbiBcImNoYW5nZVwiLCA9PlxuICAgICAgbXlfZGF0YSA9IGZldGNoIEBwcm9wcy5vYmpcblxuICAgICAgIyBmb3IgYmFja3dhcmRzIGNvbXBhdGliaWxpdHlcbiAgICAgIGlmIG15X2RhdGEuc3JjICYmICFteV9kYXRhW1wiI3tAcHJvcHMuYXR0cn1fc3JjXCJdXG4gICAgICAgIG15X2RhdGFbXCIje0Bwcm9wcy5hdHRyfV9zcmNcIl0gPSBteV9kYXRhLnNyY1xuICAgICAgICBkZWxldGUgbXlfZGF0YS5zcmNcbiAgICAgICAgc2F2ZSBteV9kYXRhXG5cbiAgICAgIG15X2RhdGFbXCIje0Bwcm9wcy5hdHRyfV9zcmNcIl0gPSBAZWRpdG9yLnZhbHVlKClcbiAgICAgIG15X2RhdGFbQHByb3BzLmF0dHJdID0gbWFya2VkPy5tYXJrZWQ/IG15X2RhdGFbXCIje0Bwcm9wcy5hdHRyfV9zcmNcIl1cblxuICAgICAgaWYgIUBkaXJ0eVxuICAgICAgICBAZGlydHkgPSB0cnVlXG4gICAgICAgIHNldFRpbWVvdXQgPT5cbiAgICAgICAgICBpZiBAZGlydHlcbiAgICAgICAgICAgIHNhdmUgbXlfZGF0YVxuICAgICAgICAgICAgQGRpcnR5ID0gZmFsc2UgXG4gICAgICAgICwgMTAwMFxuXG4gICAgaWYgQHByb3BzLnN1cnJvdW5kaW5nX3RleHRcbiAgICAgIGN1cnNvciA9IEBlZGl0b3IuY29kZW1pcnJvci5nZXRTZWFyY2hDdXJzb3IgQHByb3BzLnN1cnJvdW5kaW5nX3RleHQudHJpbSgpXG4gICAgICBjdXJzb3IuZmluZE5leHQoKVxuICAgICAgQGVkaXRvci5jb2RlbWlycm9yLnNldFNlbGVjdGlvbiBjdXJzb3IucG9zLmZyb20sIGN1cnNvci5wb3MudG9cblxuXG5cbmRvbS5UUklYX1dZU0lXWUcgPSAtPlxuICBcbiAgaWYgIUBsb2NhbC5pbml0aWFsaXplZFxuICAgICMgV2Ugc3RvcmUgdGhlIGN1cnJlbnQgdmFsdWUgb2YgdGhlIEhUTUwgYXRcbiAgICAjIHRoaXMgY29tcG9uZW50J3Mga2V5LiBUaGlzIGFsbG93cyB0aGUgIFxuICAgICMgcGFyZW50IGNvbXBvbmVudCB0byBmZXRjaCB0aGUgdmFsdWUgb3V0c2lkZSBcbiAgICAjIG9mIHRoaXMgZ2VuZXJpYyB3eXNpd3lnIGNvbXBvbmVudC4gXG4gICAgIyBIb3dldmVyLCB3ZSBcImRhbmdlcm91c2x5XCIgc2V0IHRoZSBodG1sIG9mIHRoZSBcbiAgICAjIGVkaXRvciB0byB0aGUgb3JpZ2luYWwgQHByb3BzLmh0bWwuIFRoaXMgaXMgXG4gICAgIyBiZWNhdXNlIHdlIGRvbid0IHdhbnQgdG8gaW50ZXJmZXJlIHdpdGggdGhlIFxuICAgICMgd3lzaXd5ZyBlZGl0b3IncyBhYmlsaXR5IHRvIG1hbmFnZSBlLmcuIFxuICAgICMgdGhlIHNlbGVjdGlvbiBsb2NhdGlvbi4gXG4gICAgbXlfZGF0YSA9IGZldGNoIEBwcm9wcy5vYmpcbiAgICBAb3JpZ2luYWxfdmFsdWUgPSBteV9kYXRhW0Bwcm9wcy5hdHRyXSBvciAnXFxuJ1xuICAgIEBsb2NhbC5pbml0aWFsaXplZCA9IHRydWVcbiAgICBzYXZlIEBsb2NhbFxuIFxuICBESVYgZGVmYXVsdHMge30sIEBwcm9wcyxcbiAgICBzdHlsZTogQHByb3BzLnN0eWxlIG9yIHt9XG5cbiAgICBkYW5nZXJvdXNseVNldElubmVySFRNTDogX19odG1sOiBcIlwiXCJcbiAgICAgICAgPGlucHV0IGlkPVwiI3tAbG9jYWwua2V5fS1pbnB1dFwiIHZhbHVlPVwiI3tAb3JpZ2luYWxfdmFsdWUucmVwbGFjZSgvXFxcIi9nLCAnJnF1b3Q7Jyl9XCIgdHlwZT1cImhpZGRlblwiIG5hbWU9XCJjb250ZW50XCI+XG4gICAgICAgIDx0cml4LWVkaXRvciBhdXRvZm9jdXM9I3shIUBwcm9wcy5hdXRvZm9jdXN9IGNsYXNzPSd0cml4LWVkaXRvcicgaW5wdXQ9XCIje0Bsb2NhbC5rZXl9LWlucHV0XCIgcGxhY2Vob2xkZXI9JyN7QHByb3BzLnBsYWNlaG9sZGVyIG9yICdXcml0ZSBzb21ldGhpbmchJ30nPjwvdHJpeC1lZGl0b3I+XG4gICAgICBcIlwiXCJcblxuZG9tLlRSSVhfV1lTSVdZRy5yZWZyZXNoID0gLT4gXG4gIGlmICFAaW5pdCBcbiAgICBAaW5pdCA9IHRydWVcbiAgICBlZGl0b3IgPSBAZ2V0RE9NTm9kZSgpLnF1ZXJ5U2VsZWN0b3IoJy50cml4LWVkaXRvcicpXG5cbiAgICBlZGl0b3IuYWRkRXZlbnRMaXN0ZW5lciAndHJpeC1jaGFuZ2UnLCAoZSkgPT5cbiAgICAgIGh0bWwgPSBlZGl0b3IuaW5uZXJIVE1MXG4gICAgICBteV9kYXRhID0gZmV0Y2ggQHByb3BzLm9ialxuICAgICAgbXlfZGF0YVtAcHJvcHMuYXR0cl0gPSBodG1sXG4gICAgICBzYXZlIG15X2RhdGFcblxuICAgIGlmIEBwcm9wcy5jdXJzb3JcbiAgICAgIGVkaXRvci5lZGl0b3Iuc2V0U2VsZWN0aW9uUmFuZ2UgQHByb3BzLmN1cnNvciwgQHByb3BzLmN1cnNvclxuXG5cblxuXG5cbiMgSSBwcmVmZXIgdXNpbmcgVHJpeCBub3cuLi5cblxuZG9tLlFVSUxMX1dZU0lXWUcgPSAtPlxuXG4gIG15X2RhdGEgPSBmZXRjaCBAcHJvcHMub2JqXG5cbiAgQHN1cHBvcnRzX1F1aWxsID0gISFRdWlsbFxuXG4gIGlmICFAbG9jYWwuaW5pdGlhbGl6ZWRcbiAgICAjIFdlIHN0b3JlIHRoZSBjdXJyZW50IHZhbHVlIG9mIHRoZSBIVE1MIGF0XG4gICAgIyB0aGlzIGNvbXBvbmVudCdzIGtleS4gVGhpcyBhbGxvd3MgdGhlICBcbiAgICAjIHBhcmVudCBjb21wb25lbnQgdG8gZmV0Y2ggdGhlIHZhbHVlIG91dHNpZGUgXG4gICAgIyBvZiB0aGlzIGdlbmVyaWMgd3lzaXd5ZyBjb21wb25lbnQuIFxuICAgICMgSG93ZXZlciwgd2UgXCJkYW5nZXJvdXNseVwiIHNldCB0aGUgaHRtbCBvZiB0aGUgXG4gICAgIyBlZGl0b3IgdG8gdGhlIG9yaWdpbmFsIEBwcm9wcy5odG1sLiBUaGlzIGlzIFxuICAgICMgYmVjYXVzZSB3ZSBkb24ndCB3YW50IHRvIGludGVyZmVyZSB3aXRoIHRoZSBcbiAgICAjIHd5c2l3eWcgZWRpdG9yJ3MgYWJpbGl0eSB0byBtYW5hZ2UgZS5nLiBcbiAgICAjIHRoZSBzZWxlY3Rpb24gbG9jYXRpb24uIFxuICAgIEBvcmlnaW5hbF92YWx1ZSA9IG15X2RhdGFbQHByb3BzLmF0dHJdIG9yICcnXG4gICAgQGxvY2FsLmluaXRpYWxpemVkID0gdHJ1ZVxuICAgIHNhdmUgQGxvY2FsXG5cbiAgQHNob3dfcGxhY2Vob2xkZXIgPSAoIW15X2RhdGFbQHByb3BzLmF0dHJdIHx8IChAZWRpdG9yPy5nZXRUZXh0KCkudHJpbSgpLmxlbmd0aCA9PSAwKSkgJiYgISFAcHJvcHMucGxhY2Vob2xkZXJcblxuICBESVYgXG4gICAgc3R5bGU6IFxuICAgICAgcG9zaXRpb246ICdyZWxhdGl2ZSdcblxuXG4gICAgaWYgQGxvY2FsLmVkaXRfY29kZSB8fCAhQHN1cHBvcnRzX1F1aWxsXG4gICAgICBBdXRvR3Jvd1RleHRBcmVhXG4gICAgICAgIHN0eWxlOiBcbiAgICAgICAgICB3aWR0aDogJzEwMCUnXG4gICAgICAgICAgZm9udFNpemU6IDE4XG4gICAgICAgIGRlZmF1bHRWYWx1ZTogbXlfZGF0YVtAcHJvcHMuYXR0cl1cbiAgICAgICAgb25DaGFuZ2U6IChlKSA9PiBcbiAgICAgICAgICBteV9kYXRhW0Bwcm9wcy5hdHRyXSA9IGUudGFyZ2V0LnZhbHVlXG4gICAgICAgICAgc2F2ZSBteV9kYXRhXG5cbiAgICBlbHNlXG5cbiAgICAgIERJViBcbiAgICAgICAgcmVmOiAnZWRpdG9yJ1xuICAgICAgICBpZDogJ2VkaXRvcidcbiAgICAgICAgZGFuZ2Vyb3VzbHlTZXRJbm5lckhUTUw6e19faHRtbDogQG9yaWdpbmFsX3ZhbHVlfVxuICAgICAgICBzdHlsZTogQHByb3BzLnN0eWxlXG5cblxuZG9tLlFVSUxMX1dZU0lXWUcucmVmcmVzaCA9IC0+IFxuICByZXR1cm4gaWYgIUBzdXBwb3J0c19RdWlsbCB8fCAhQHJlZnMuZWRpdG9yIHx8IEBtb3VudGVkXG4gIEBtb3VudGVkID0gdHJ1ZSBcblxuICBnZXRIVE1MID0gPT4gQGdldERPTU5vZGUoKS5xdWVyeVNlbGVjdG9yKFwiLnFsLWVkaXRvclwiKS5pbm5lckhUTUxcblxuICAjIEF0dGFjaCB0aGUgUXVpbGwgd3lzaXd5ZyBlZGl0b3JcbiAgQGVkaXRvciA9IG5ldyBRdWlsbCBAcmVmcy5lZGl0b3IuZ2V0RE9NTm9kZSgpLFxuICAgIHN0eWxlczogdHJ1ZSAjaWYvd2hlbiB3ZSB3YW50IHRvIGRlZmluZSBhbGwgc3R5bGVzLCBzZXQgdG8gZmFsc2VcbiAgICBwbGFjZWhvbGRlcjogaWYgQHNob3dfcGxhY2Vob2xkZXIgdGhlbiBAcHJvcHMucGxhY2Vob2xkZXIgZWxzZSAnJ1xuICAgIHRoZW1lOiAnc25vdydcblxuICBrZXlib2FyZCA9IEBlZGl0b3IuZ2V0TW9kdWxlKCdrZXlib2FyZCcpXG4gIGRlbGV0ZSBrZXlib2FyZC5iaW5kaW5nc1s5XSAgICAjIDkgaXMgdGhlIGtleSBjb2RlIGZvciB0YWI7IHJlc3RvcmUgdGFiYmluZyBmb3IgYWNjZXNzaWJpbGl0eVxuXG4gIEBlZGl0b3Iub24gJ3RleHQtY2hhbmdlJywgKGRlbHRhLCBvbGRfY29udGVudHMsIHNvdXJjZSkgPT4gXG4gICAgaWYgc291cmNlID09ICd1c2VyJ1xuICAgICAgbXlfZGF0YSA9IGZldGNoIEBwcm9wcy5vYmpcbiAgICAgIG15X2RhdGFbQHByb3BzLmF0dHJdID0gZ2V0SFRNTCgpXG5cbiAgICAgIGlmIG15X2RhdGFbQHByb3BzLmF0dHJdLmluZGV4T2YoJyBzdHlsZScpID4gLTFcbiAgICAgICAgIyBzdHJpcCBvdXQgYW55IHN0eWxlIHRhZ3MgdGhlIHVzZXIgbWF5IGhhdmUgcGFzdGVkIGludG8gdGhlIGh0bWxcblxuICAgICAgICByZW1vdmVTdHlsZXMgPSAoZWwpIC0+XG4gICAgICAgICAgZWwucmVtb3ZlQXR0cmlidXRlICdzdHlsZSdcbiAgICAgICAgICBpZiBlbC5jaGlsZE5vZGVzLmxlbmd0aCA+IDBcbiAgICAgICAgICAgIGZvciBjaGlsZCBpbiBlbC5jaGlsZE5vZGVzXG4gICAgICAgICAgICAgIHJlbW92ZVN0eWxlcyBjaGlsZCBpZiBjaGlsZC5ub2RlVHlwZSA9PSAxXG5cbiAgICAgICAgbm9kZSA9IEBlZGl0b3Iucm9vdFxuICAgICAgICByZW1vdmVTdHlsZXMgbm9kZVxuICAgICAgICBteV9kYXRhW0Bwcm9wcy5hdHRyXSA9IGdldEhUTUwoKVxuXG4gICAgICBzYXZlIG15X2RhdGFcblxuXG5cblxuXG5cblxuXG5cbndpbmRvdy5pbnNlcnRfZ3JhYl9jdXJzb3Jfc3R5bGUgPSAtPiBcbiAgc2V0X3N0eWxlIFwiXCJcIlxuICAgICAgYSB7IFxuICAgICAgICBjdXJzb3I6IHBvaW50ZXI7IFxuICAgICAgICB0ZXh0LWRlY29yYXRpb246IHVuZGVybGluZTtcbiAgICAgIH1cbiAgICAgIC5ncmFiX2N1cnNvciB7XG4gICAgICAgIGN1cnNvcjogbW92ZTtcbiAgICAgICAgY3Vyc29yOiBncmFiO1xuICAgICAgICBjdXJzb3I6IGV3LXJlc2l6ZTtcbiAgICAgICAgY3Vyc29yOiAtd2Via2l0LWdyYWI7XG4gICAgICAgIGN1cnNvcjogLW1vei1ncmFiO1xuICAgICAgfSAuZ3JhYl9jdXJzb3I6YWN0aXZlIHtcbiAgICAgICAgY3Vyc29yOiBtb3ZlO1xuICAgICAgICBjdXJzb3I6IGdyYWJiaW5nO1xuICAgICAgICBjdXJzb3I6IGV3LXJlc2l6ZTtcbiAgICAgICAgY3Vyc29yOiAtd2Via2l0LWdyYWJiaW5nO1xuICAgICAgICBjdXJzb3I6IC1tb3otZ3JhYmJpbmc7XG4gICAgICB9XG5cblxuICAgIFwiXCJcIiwgJ2dyYWItY3Vyc29yJ1xuXG4jIFRha2VzIGFuIElTTyB0aW1lIGFuZCByZXR1cm5zIGEgc3RyaW5nIHJlcHJlc2VudGluZyBob3dcbiMgbG9uZyBhZ28gdGhlIGRhdGUgcmVwcmVzZW50cy5cbiMgZnJvbTogaHR0cDovL3N0YWNrb3ZlcmZsb3cuY29tL3F1ZXN0aW9ucy83NjQxNzkxXG53aW5kb3cucHJldHR5RGF0ZSA9ICh0aW1lKSAtPlxuICBkYXRlID0gbmV3IERhdGUodGltZSkgI25ldyBEYXRlKCh0aW1lIHx8IFwiXCIpLnJlcGxhY2UoLy0vZywgXCIvXCIpLnJlcGxhY2UoL1tUWl0vZywgXCIgXCIpKVxuICBkaWZmID0gKCgobmV3IERhdGUoKSkuZ2V0VGltZSgpIC0gZGF0ZS5nZXRUaW1lKCkpIC8gMTAwMClcbiAgZGF5X2RpZmYgPSBNYXRoLmZsb29yKGRpZmYgLyA4NjQwMClcblxuICByZXR1cm4gaWYgaXNOYU4oZGF5X2RpZmYpIHx8IGRheV9kaWZmIDwgMFxuXG4gICMgVE9ETzogcGx1cmFsaXplIHByb3Blcmx5IChlLmcuIDEgZGF5cyBhZ28sIDEgd2Vla3MgYWdvLi4uKVxuICByID0gZGF5X2RpZmYgPT0gMCAmJiAoXG4gICAgZGlmZiA8IDYwICYmIFwianVzdCBub3dcIiB8fCBcbiAgICBkaWZmIDwgMTIwICYmIFwiMSBtaW51dGUgYWdvXCIgfHwgXG4gICAgZGlmZiA8IDM2MDAgJiYgTWF0aC5mbG9vcihkaWZmIC8gNjApICsgXCIgbWludXRlcyBhZ29cIiB8fCBcbiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRpZmYgPCA3MjAwICYmIFwiMSBob3VyIGFnb1wiIHx8IFxuICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZGlmZiA8IDg2NDAwICYmIE1hdGguZmxvb3IoZGlmZiAvIDM2MDApICsgXCIgaG91cnMgYWdvXCIpIHx8IFxuICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZGF5X2RpZmYgPT0gMSAmJiBcIlllc3RlcmRheVwiIHx8IFxuICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZGF5X2RpZmYgPCA3ICYmIGRheV9kaWZmICsgXCIgZGF5cyBhZ29cIiB8fCBcbiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRheV9kaWZmIDwgMzEgJiYgTWF0aC5jZWlsKGRheV9kaWZmIC8gNykgKyBcIiB3ZWVrcyBhZ29cIiB8fFxuICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgXCIje2RhdGUuZ2V0TW9udGgoKSArIDF9LyN7ZGF0ZS5nZXREYXkoKSArIDF9LyN7ZGF0ZS5nZXRGdWxsWWVhcigpfVwiXG5cbiAgciA9IHIucmVwbGFjZSgnMSBkYXlzIGFnbycsICcxIGRheSBhZ28nKS5yZXBsYWNlKCcxIHdlZWtzIGFnbycsICcxIHdlZWsgYWdvJykucmVwbGFjZSgnMSB5ZWFycyBhZ28nLCAnMSB5ZWFyIGFnbycpXG4gIHJcblxuXG5cbndpbmRvdy5oc3YycmdiID0gKGgscyx2KSAtPiBcbiAgaF9pID0gTWF0aC5mbG9vcihoKjYpXG4gIGYgPSBoKjYgLSBoX2lcbiAgcCA9IHYgKiAoMSAtIHMpXG4gIHEgPSB2ICogKDEgLSBmKnMpXG4gIHQgPSB2ICogKDEgLSAoMSAtIGYpICogcylcbiAgW3IsIGcsIGJdID0gW3YsIHQsIHBdIGlmIGhfaT09MFxuICBbciwgZywgYl0gPSBbcSwgdiwgcF0gaWYgaF9pPT0xXG4gIFtyLCBnLCBiXSA9IFtwLCB2LCB0XSBpZiBoX2k9PTJcbiAgW3IsIGcsIGJdID0gW3AsIHEsIHZdIGlmIGhfaT09M1xuICBbciwgZywgYl0gPSBbdCwgcCwgdl0gaWYgaF9pPT00XG4gIFtyLCBnLCBiXSA9IFt2LCBwLCBxXSBpZiBoX2k9PTVcblxuICBcInJnYigje01hdGgucm91bmQocioyNTYpfSwgI3tNYXRoLnJvdW5kKGcqMjU2KX0sICN7TWF0aC5yb3VuZChiKjI1Nil9KVwiXG5cbiMgcmVuZGVycyBzdHlsZWQgSFRNTCwgVE9ETzogc3RyaXAgc2NyaXB0IHRhZ3MgZmlyc3RcbmRvbS5SRU5ERVJfSFRNTCA9IC0+IFxuICBESVYgXG4gICAgY2xhc3NOYW1lOiAnZW1iZWRkZWRfaHRtbCdcbiAgICBkYW5nZXJvdXNseVNldElubmVySFRNTDpcbiAgICAgIF9faHRtbDogQHByb3BzLmh0bWxcblxuXG5cblxuXG5kb20uTEFCX0ZPT1RFUiA9IC0+IFxuICBESVYgXG4gICAgc3R5bGU6IFxuICAgICAgbWFyZ2luVG9wOiA0MFxuICAgICAgcGFkZGluZzogJzIwcHggMCAyMHB4IDAnXG4gICAgICBmb250RmFtaWx5OiAnXCJCcmFuZG9uIEdyb3Rlc3F1ZVwiLCBNb250c2VycmF0LCBIZWx2ZXRpY2EsIGFyaWFsJ1xuICAgICAgYm9yZGVyVG9wOiAnMXB4IHNvbGlkICNENkQ3RDknXG4gICAgICBiYWNrZ3JvdW5kQ29sb3I6ICcjRjZGN0Y5J1xuICAgICAgY29sb3I6IFwiIzc3N1wiXG4gICAgICBmb250U2l6ZTogMzBcbiAgICAgIGZvbnRXZWlnaHQ6IDMwMFxuXG5cbiAgICBESVYgXG4gICAgICBzdHlsZTogXG4gICAgICAgIHRleHRBbGlnbjogJ2NlbnRlcicgICAgICAgIFxuICAgICAgICBtYXJnaW5Cb3R0b206IDZcblxuICAgICAgXCJNYWRlIGF0IFwiXG5cbiAgICAgIEEgXG4gICAgICAgIG9uTW91c2VFbnRlcjogPT4gXG4gICAgICAgICAgQGxvY2FsLmhvdmVyID0gdHJ1ZVxuICAgICAgICAgIHNhdmUgQGxvY2FsXG4gICAgICAgIG9uTW91c2VMZWF2ZTogPT4gXG4gICAgICAgICAgQGxvY2FsLmhvdmVyID0gZmFsc2VcbiAgICAgICAgICBzYXZlIEBsb2NhbFxuICAgICAgICBocmVmOiAnaHR0cDovL2NvbnNpZGVyLml0J1xuICAgICAgICB0YXJnZXQ6ICdfYmxhbmsnXG4gICAgICAgIHRpdGxlOiAnQ29uc2lkZXIuaXRcXCdzIGhvbWVwYWdlJ1xuICAgICAgICBzdHlsZTogXG4gICAgICAgICAgcG9zaXRpb246ICdyZWxhdGl2ZSdcbiAgICAgICAgICB0b3A6IDZcbiAgICAgICAgICBsZWZ0OiAzXG4gICAgICAgIFxuICAgICAgICBEUkFXX0xPR08gXG4gICAgICAgICAgaGVpZ2h0OiAzMVxuICAgICAgICAgIGNsaXA6IGZhbHNlXG4gICAgICAgICAgb190ZXh0X2NvbG9yOiBjb25zaWRlcml0X3NhbG1vblxuICAgICAgICAgIG1haW5fdGV4dF9jb2xvcjogY29uc2lkZXJpdF9zYWxtb24gICAgICAgIFxuICAgICAgICAgIGRyYXdfbGluZTogdHJ1ZSBcbiAgICAgICAgICBsaW5lX2NvbG9yOiAnI0Q2RDdEOSdcbiAgICAgICAgICBpX2RvdF94OiBpZiBAbG9jYWwuaG92ZXIgdGhlbiAxNDIgZWxzZSAyNTJcbiAgICAgICAgICB0cmFuc2l0aW9uOiB0cnVlXG5cblxuICAgIERJViBcbiAgICAgIHN0eWxlOiBcbiAgICAgICAgZm9udFNpemU6IDE2XG4gICAgICAgIHRleHRBbGlnbjogJ2NlbnRlcidcblxuICAgICAgXCJBbiBcIlxuICAgICAgQSBcbiAgICAgICAgaHJlZjogJ2h0dHBzOi8vaW52aXNpYmxlLmNvbGxlZ2UnXG4gICAgICAgIHRhcmdldDogJ19ibGFuaydcbiAgICAgICAgc3R5bGU6IFxuICAgICAgICAgIGNvbG9yOiAnaW5oZXJpdCdcbiAgICAgICAgICBmb250V2VpZ2h0OiA0MDBcbiAgICAgICAgXCJJbnZpc2libGUgQ29sbGVnZVwiXG4gICAgICBcIiBsYWJvcmF0b3J5XCJcblxuXG5kb20uTE9BRElOR19JTkRJQ0FUT1IgPSAtPiBcbiAgRElWXG4gICAgY2xhc3NOYW1lOiAnbG9hZGluZyBzay13YXZlJ1xuICAgIGRhbmdlcm91c2x5U2V0SW5uZXJIVE1MOiBfX2h0bWw6IFwiXCJcIlxuICAgICAgPGRpdiBjbGFzcz1cInNrLXJlY3Qgc2stcmVjdDFcIj48L2Rpdj5cbiAgICAgIDxkaXYgY2xhc3M9XCJzay1yZWN0IHNrLXJlY3QyXCI+PC9kaXY+XG4gICAgICA8ZGl2IGNsYXNzPVwic2stcmVjdCBzay1yZWN0M1wiPjwvZGl2PlxuICAgICAgPGRpdiBjbGFzcz1cInNrLXJlY3Qgc2stcmVjdDRcIj48L2Rpdj5cbiAgICAgIDxkaXYgY2xhc3M9XCJzay1yZWN0IHNrLXJlY3Q1XCI+PC9kaXY+XG4gICAgXCJcIlwiXG5cblxud2luZG93LnBvaW50X2Rpc3RhbmNlID0gKGEsYikgLT5cbiAgTWF0aC5zcXJ0KCBNYXRoLnBvdyhhLnggLSBiLngsIDIpICsgTWF0aC5wb3coYS55IC0gYi55LCAyKSApXG5cblxuXG5cbiMgbG9hZGluZyBpbmRpY2F0b3Igc3R5bGVzIGJlbG93IGFyZSBcbiMgQ29weXJpZ2h0IChjKSAyMDE1IFRvYmlhcyBBaGxpbiwgVGhlIE1JVCBMaWNlbnNlIChNSVQpXG4jIGh0dHBzOi8vZ2l0aHViLmNvbS90b2JpYXNhaGxpbi9TcGluS2l0XG5zZXRfc3R5bGUgXCJcIlwiXG4gIC5zay13YXZlIHtcbiAgICBtYXJnaW46IDQwcHggYXV0bztcbiAgICB3aWR0aDogNTBweDtcbiAgICBoZWlnaHQ6IDQwcHg7XG4gICAgdGV4dC1hbGlnbjogY2VudGVyO1xuICAgIGZvbnQtc2l6ZTogMTBweDsgfVxuICAgIC5zay13YXZlIC5zay1yZWN0IHtcbiAgICAgIGJhY2tncm91bmQtY29sb3I6IHJnYmEoMjIzLCA5OCwgMTAwLCAuNSk7XG4gICAgICBoZWlnaHQ6IDEwMCU7XG4gICAgICB3aWR0aDogNnB4O1xuICAgICAgZGlzcGxheTogaW5saW5lLWJsb2NrO1xuICAgICAgLXdlYmtpdC1hbmltYXRpb246IHNrLXdhdmVTdHJldGNoRGVsYXkgMS4ycyBpbmZpbml0ZSBlYXNlLWluLW91dDtcbiAgICAgICAgICAgICAgYW5pbWF0aW9uOiBzay13YXZlU3RyZXRjaERlbGF5IDEuMnMgaW5maW5pdGUgZWFzZS1pbi1vdXQ7IH1cbiAgICAuc2std2F2ZSAuc2stcmVjdDEge1xuICAgICAgLXdlYmtpdC1hbmltYXRpb24tZGVsYXk6IC0xLjJzO1xuICAgICAgICAgICAgICBhbmltYXRpb24tZGVsYXk6IC0xLjJzOyB9XG4gICAgLnNrLXdhdmUgLnNrLXJlY3QyIHtcbiAgICAgIC13ZWJraXQtYW5pbWF0aW9uLWRlbGF5OiAtMS4xcztcbiAgICAgICAgICAgICAgYW5pbWF0aW9uLWRlbGF5OiAtMS4xczsgfVxuICAgIC5zay13YXZlIC5zay1yZWN0MyB7XG4gICAgICAtd2Via2l0LWFuaW1hdGlvbi1kZWxheTogLTFzO1xuICAgICAgICAgICAgICBhbmltYXRpb24tZGVsYXk6IC0xczsgfVxuICAgIC5zay13YXZlIC5zay1yZWN0NCB7XG4gICAgICAtd2Via2l0LWFuaW1hdGlvbi1kZWxheTogLTAuOXM7XG4gICAgICAgICAgICAgIGFuaW1hdGlvbi1kZWxheTogLTAuOXM7IH1cbiAgICAuc2std2F2ZSAuc2stcmVjdDUge1xuICAgICAgLXdlYmtpdC1hbmltYXRpb24tZGVsYXk6IC0wLjhzO1xuICAgICAgICAgICAgICBhbmltYXRpb24tZGVsYXk6IC0wLjhzOyB9XG5cbiAgQC13ZWJraXQta2V5ZnJhbWVzIHNrLXdhdmVTdHJldGNoRGVsYXkge1xuICAgIDAlLCA0MCUsIDEwMCUge1xuICAgICAgLXdlYmtpdC10cmFuc2Zvcm06IHNjYWxlWSgwLjQpO1xuICAgICAgICAgICAgICB0cmFuc2Zvcm06IHNjYWxlWSgwLjQpOyB9XG4gICAgMjAlIHtcbiAgICAgIC13ZWJraXQtdHJhbnNmb3JtOiBzY2FsZVkoMSk7XG4gICAgICAgICAgICAgIHRyYW5zZm9ybTogc2NhbGVZKDEpOyB9IH1cblxuICBAa2V5ZnJhbWVzIHNrLXdhdmVTdHJldGNoRGVsYXkge1xuICAgIDAlLCA0MCUsIDEwMCUge1xuICAgICAgLXdlYmtpdC10cmFuc2Zvcm06IHNjYWxlWSgwLjQpO1xuICAgICAgICAgICAgICB0cmFuc2Zvcm06IHNjYWxlWSgwLjQpOyB9XG4gICAgMjAlIHtcbiAgICAgIC13ZWJraXQtdHJhbnNmb3JtOiBzY2FsZVkoMSk7XG4gICAgICAgICAgICAgIHRyYW5zZm9ybTogc2NhbGVZKDEpOyB9IH1cbiAgXCJcIlwiLCAnbG9hZGluZy1pbmRpY2F0b3Itc3R5bGVzJ1xuXG5cblxuIn0=
//# sourceURL=client/shared.coffee