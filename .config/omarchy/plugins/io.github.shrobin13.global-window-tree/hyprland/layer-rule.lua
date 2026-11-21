hl.layer_rule({
  name = "global-window-tree-blur",
  match = { namespace = "^global-window-tree$" },
  blur = true,
  ignore_alpha = 0.5,
  no_anim = true,
})
