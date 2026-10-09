-- value types used by gradient-based controls (color picker)
NumberSequence = { new = function(...) return { __rbx = "NumberSequence", ... } end }
ColorSequence = { new = function(v) return { __rbx = "ColorSequence", v } end }
ColorSequenceKeypoint = { new = function(t, c) return { __rbx = "ColorSequenceKeypoint", Time = t, Value = c } end }
