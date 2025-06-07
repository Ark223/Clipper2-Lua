
local C = require "ClipperLib"

local FillRule = C.FillRule
local Clipper = C.Clipper
local Paths = C.Paths

local clipper = Clipper()

local subj, clip = Paths(), Paths()
subj:add(clipper:make_path{100,50, 10,79, 65,2,  65,98, 10,21})
clip:add(clipper:make_path{ 98,63,  4,68, 77,8, 52,100, 19,12})

local solution = clipper:intersect(subj, clip, FillRule.NonZero)
print(tostring(solution))
