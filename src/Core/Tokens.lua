-- Tokens: the design scales every component draws from. No component hardcodes a spacing,
-- radius, text size or duration: it picks a step from here, which is what keeps the whole
-- library visually consistent (and lets a single edit re-skin everything).
local Tokens = {}

-- Spacing scale (pixels). Pick by relationship, not by eye:
--   Xs  icon <-> text          Sm  items inside one control      Md  sibling controls
--   Lg  card padding           Xl  between cards                 Xxl between page areas
Tokens.Space = { Xs = 2, Sm = 4, Md = 8, Lg = 12, Xl = 16, Xxl = 24 }

Tokens.Radius = { Sm = 6, Md = 8, Lg = 12, Pill = 999 }

-- Typography hierarchy. Primary: page titles, key values. Secondary: section titles, labels,
-- control names. Supporting: descriptions, status, metadata. Caption: overlines, badges.
Tokens.Type = {
	Display = { Size = 24, Font = "Bold" },
	Primary = { Size = 17, Font = "Bold" },
	Secondary = { Size = 14, Font = "Medium" },
	Supporting = { Size = 12, Font = "Regular" },
	Caption = { Size = 11, Font = "Bold" },
}

-- Motion (seconds). Fast: hover/press feedback. Base: state changes. Slow: layout (expand, collapse).
Tokens.Motion = { Fast = 0.12, Base = 0.18, Slow = 0.28 }

-- Control heights: [touch] doubles as the minimum hit area.
Tokens.Height = {
	Compact = { Desktop = 26, Touch = 34 },
	Control = { Desktop = 34, Touch = 44 },
	Nav = { Desktop = 36, Touch = 44 },
}

return Tokens
