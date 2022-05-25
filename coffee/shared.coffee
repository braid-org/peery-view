window.unslash = (t) -> if t?.startsWith?("/") then t.substr(1) else t
window.slash = (t) -> if t?.startsWith?("/") then t else "/#{t}"
