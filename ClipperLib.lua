
--[[
  /*******************************************************************************
  * Author    :  Angus Johnson                                                   *
  * Date      :  6 June 2025                                                     *
  * Website   :  https://www.angusj.com                                          *
  * Copyright :  Angus Johnson 2010-2025                                         *
  * Purpose   :  Lua wrapper for Clipper2 v1.5.4 DLL                             *
  * License   :  https://www.boost.org/LICENSE_1_0.txt                           *
  *******************************************************************************/
--]]

local ffi      = require "ffi"
local sys_arch = ffi.abi("64bit") and 64 or 32
local dll_name = ("Clipper2_%d"):format(sys_arch)
local instance = ffi.load(dll_name)

-------------------------------------------------------------------
--  Enums
-------------------------------------------------------------------

---@enum ClipType
local ClipType = { NoClip = 0, Intersection = 1, Union = 2, Difference = 3, Xor = 4 }

---@enum FillRule
local FillRule = { EvenOdd = 0, NonZero = 1, Positive = 2, Negative = 3 }

---@enum JoinType
local JoinType = { Square = 0, Bevel = 1, Round = 2, Miter = 3 }

---@enum EndType
local EndType  = { Polygon = 0, Joined = 1, Butt = 2, Square = 3, Round = 4 }

-------------------------------------------------------------------
--  FFI Declarations
-------------------------------------------------------------------

ffi.cdef[[
  typedef double* CPathD;
  typedef double* CPathsD;

  typedef struct {
    double left, top, right, bottom;
  } CRectD;

  const char* Version(void);
  void DisposeArrayD(double* p);

  int BooleanOpD(
    uint8_t cliptype,
    uint8_t fillrule,
    const double* subjects,
    const double* subjects_open,
    const double* clips,
    double** solution,
    double** solution_open,
    int precision,
    bool preserve_collinear,
    bool reverse_solution
  );

  double* InflatePathD(
    const double* path,
    double delta,
    uint8_t jointype,
    uint8_t endtype,
    int precision,
    double miter_limit,
    double arc_tolerance,
    bool reverse_solution
  );

  double* InflatePathsD(
    const double* paths,
    double delta,
    uint8_t jointype,
    uint8_t endtype,
    int precision,
    double miter_limit,
    double arc_tolerance,
    bool reverse_solution
  );

  double* RectClipD(
    const CRectD* rect,
    const double* paths,
    int precision
  );

  double* RectClipLinesD(
    const CRectD* rect,
    const double* paths,
    int precision
  );
]]

-------------------------------------------------------------------
--  Class Factory
-------------------------------------------------------------------

local Class = function(...)
  local cls = {}
  cls.__index = cls
  function cls:new(...)
    local instance = setmetatable({}, cls)
    if instance.init then instance:init(...) end
    return instance
  end
  cls.__call = function(_, ...) return cls:new(...) end
  return setmetatable(cls, {__call = cls.__call})
end

-------------------------------------------------------------------
--  Utility : grow‑on‑demand C buffer of doubles
-------------------------------------------------------------------

---Ensures a grow-on-demand buffer has room for *required* additional doubles.
---@param buf_ref  table   # `{cdata*, length}` pair (modified in-place)
---@param cap_ref  table   # `{capacity}` holder (modified in-place)
---@param required integer # number of extra `double` slots needed
local function update_cap(buf_ref, cap_ref, required)
  local length, capacity = buf_ref[2], cap_ref[1]
  if length + required > capacity then
    repeat capacity = capacity * 2 until length + required <= capacity
    local new_buffer = ffi.new("double[?]", capacity)
    ffi.copy(new_buffer, buf_ref[1], length * ffi.sizeof("double"))
    buf_ref[1], cap_ref[1] = new_buffer, capacity
  end
end

-------------------------------------------------------------------
--  Point : immutable 2D (x, y) coordinate
-------------------------------------------------------------------

---@class Point
---@field x number
---@field y number
local Point = Class()

---Instantiate a point
---@param x number
---@param y number
function Point:init(x, y)
  self.x, self.y = x, y
end

---Save point in a string.
---@return string
function Point:__tostring()
  return ("%g,%g"):format(self.x, self.y)
end

-------------------------------------------------------------------
--  Rect : structure {left, top, right, bottom}
-------------------------------------------------------------------

---@class Rect
---@field left number
---@field top number
---@field right number
---@field bottom number
local Rect = Class()

---Instantiate a rectangle
---@param left number
---@param top number
---@param right number
---@param bottom number
function Rect:init(left, top, right, bottom)
  self.left = left
  self.top = top
  self.right = right
  self.bottom = bottom
end

---Save rectangle in a string.
---@return string
function Rect:__tostring()
  return ("%g,%g,%g,%g"):format(self.left,
    self.top, self.right, self.bottom)
end

-------------------------------------------------------------------
--  Path : flat array [x0, y0, x1, y1, x2, y2, ..., xn, yn]
-------------------------------------------------------------------

---@class Path
---@field _buf_ref table # internal `{cdata*, length}`
---@field _cap_ref table # internal `{capacity}`
local Path = Class()

---Create an empty path with an optional initial capacity.
---@param initial_capacity? integer # pre-allocated point count
function Path:init(initial_capacity)
  local capacity = (initial_capacity or 16) * 2
  self._buf_ref = { ffi.new("double[?]", capacity), 0 }
  self._cap_ref = { capacity }
end

---Save path in a string.
---@return string
function Path:__tostring()
  local out = {}
  for index = 1, self:size() do
    local point = self:get(index)
    out[index] = tostring(point)
  end
  return table.concat(out, " ")
end

---Append a new point.
---@param point Point
function Path:add(point)
  update_cap(self._buf_ref, self._cap_ref, 2)
  local buffer = self._buf_ref[1]
  local length = self._buf_ref[2]
  buffer[length + 0] = point.x
  buffer[length + 1] = point.y
  self._buf_ref[2] = length + 2
end

---Replace the *index*-th point (1-based).
---@param index integer
---@param point Point
function Path:set(index, point)
  local buffer = self._buf_ref[1]
  local idx = (index - 1) * 2
  buffer[idx + 0] = point.x
  buffer[idx + 1] = point.y
end

---Return the *index*-th point.
---@param index integer
---@return Point
function Path:get(index)
  local buffer = self._buf_ref[1]
  local idx = (index - 1) * 2
  local px = buffer[idx + 0]
  local py = buffer[idx + 1]
  return Point(px, py)
end

---Remove every point.
function Path:clear()
  self._buf_ref[2] = 0
end

---Number of stored points.
---@return integer
function Path:size()
  return math.floor(self._buf_ref[2] / 2)
end

-------------------------------------------------------------------
--  Paths : packed structure [total, count, n0, 0, x0, y0, ...]
-------------------------------------------------------------------

---@class Paths
---@field _buf_ref table   # internal `{cdata*, length}`
---@field _cap_ref table   # internal `{capacity}`
---@field _list    Path[]  # Lua references for random access
---@field _count   integer # cached path count
local Paths = Class()

---Construct a `Paths` container.
---@param initial_paths?  integer # anticip. number of paths
---@param initial_points? integer # anticip. points per path
function Paths:init(initial_paths, initial_points)
  local num_paths = initial_paths or 4
  local per_path  = initial_points or 16
  local capacity  = num_paths * (2 + 2 * per_path) + 2
  local buffer    = ffi.new("double[?]", capacity)
  buffer[0], buffer[1] = 2, 0
  self._buf_ref = { buffer, 2 }
  self._cap_ref = { capacity }
  self._list    = {}
  self._count   = 0
end

---Save paths in a string.
---@return string
function Paths:__tostring()
  local out = {}
  for index = 1, self:size() do
    local path = self:get(index)
    out[index] = tostring(path)
  end
  return table.concat(out, "\n")
end

---Append a new path.
---@param path Path
function Paths:add(path)
  table.insert(self._list, path)
  self._count = self._count + 1
  local buffer = self._buf_ref[1]
  buffer[1] = self._count

  local num_pts = path:size()
  local need = 2 + 2 * num_pts
  update_cap(self._buf_ref, self._cap_ref, need)

  buffer = self._buf_ref[1]
  local cursor = self._buf_ref[2]
  buffer[cursor + 0] = num_pts
  buffer[cursor + 1] = 0

  local base = cursor + 2
  for j = 1, num_pts do
    local point = path:get(j)
    local idx = base + 2 * (j - 1)
    buffer[idx + 0] = point.x
    buffer[idx + 1] = point.y
  end

  self._buf_ref[2] = cursor + need
  buffer[0] = self._buf_ref[2]
end

---Path retrieval.
---@param index integer
---@return Path
function Paths:get(index)
  return self._list[index]
end

-- Remove every stored path.
function Paths:clear()
  self._list = nil
  self._list = {}
  self._count = 0
  self._buf_ref[2] = 2
  local buffer = self._buf_ref[1]
  buffer[0], buffer[1] = 2, 0
end

---Number of stored paths.
---@return integer
function Paths:size()
  return self._count
end

-------------------------------------------------------------------
--  Utility : Double-buffer -> Lua `Paths` converter
-------------------------------------------------------------------

---Convert a DLL-allocated `CPathsD` to a Lua-side `Paths` object.
---@param cpaths ffi.cdata*
---@return Paths
local function to_lua_paths(cpaths)
  local null = cpaths == ffi.NULL
  if null then return Paths() end
  local count = tonumber(cpaths[1])
  local result = Paths:new(count)
  local idx = 2
  for _ = 1, count do
    local npts = tonumber(cpaths[idx])
    local path = Path:new(npts)
    idx = idx + 2
    for _ = 1, npts do
      local px = cpaths[idx + 0]
      local py = cpaths[idx + 1]
      path:add(Point(px, py))
      idx = idx + 2
    end
    result:add(path)
  end
  instance.DisposeArrayD(cpaths)
  return result
end

-------------------------------------------------------------------
--  Clipper Module
-------------------------------------------------------------------

---@class Clipper
local Clipper = Class()

---Clipper constructor.
function Clipper:init() end

---Perform a boolean operation for paths.
---@param cliptype            ClipType  # boolean operation kind
---@param fillrule            FillRule  # winding rule for clipping
---@param subjects            Paths|nil # closed subject paths (may be null)
---@param subj_open           Paths|nil # open subject paths (may be null)
---@param clips               Paths|nil # closed clip paths (may be null)
---@param precision?          integer   # decimal precision (default = 2)
---@param preserve_collinear? boolean   # keep collinear edges (default = true)
---@param reverse_solution?   boolean   # reverse output winding (default = false)
---@return Paths, Paths                 # result closed and open paths
function Clipper:boolean(cliptype, fillrule, subjects, subj_open,
  clips, precision, preserve_collinear, reverse_solution)

  local precision = precision or 2
  local preserve_collinear = preserve_collinear ~= false
  local reverse_solution = reverse_solution == true

  local subj_buf = subjects and subjects._buf_ref[1] or ffi.cast("double*", 0)
  local open_buf = subj_open and subj_open._buf_ref[1] or ffi.cast("double*", 0)
  local clip_buf = clips and clips._buf_ref[1] or ffi.cast("double*", 0)

  local out_sol  = ffi.new("double*[1]")
  local out_open = ffi.new("double*[1]")

  local err = instance.BooleanOpD(cliptype, fillrule,
    subj_buf, open_buf, clip_buf, out_sol, out_open,
    precision, preserve_collinear, reverse_solution)
  if err ~= 0 then error("Clipper Error: " .. err) end

  local res_sol  = to_lua_paths(out_sol[0])
  local res_open = to_lua_paths(out_open[0])
  return res_sol, res_open
end

---Perform intersection operation for paths.
---@param subjects   Paths     # subject paths (not null)
---@param clips      Paths|nil # clipping paths (may be null)
---@param fillrule?  FillRule  # winding rule (default = `EvenOdd`)
---@param precision? integer   # decimal precision (default = 2)
---@return Paths, Paths        # result closed and open paths
function Clipper:intersect(subjects, clips, fillrule, precision)
  return self:boolean(ClipType.Intersection, fillrule or
    FillRule.EvenOdd, subjects, nil, clips, precision)
end

---Perform union operation for paths.
---@param subjects   Paths     # subject paths (not null)
---@param clips      Paths|nil # clipping paths (may be null)
---@param fillrule?  FillRule  # winding rule (default = `EvenOdd`)
---@param precision? integer   # decimal precision (default = 2)
---@return Paths, Paths        # result closed and open paths
function Clipper:union(subjects, clips, fillrule, precision)
  return self:boolean(ClipType.Union, fillrule or
    FillRule.EvenOdd, subjects, nil, clips, precision)
end

---Perform difference operation for paths.
---@param subjects   Paths     # subject paths (not null)
---@param clips      Paths|nil # clipping paths (may be null)
---@param fillrule?  FillRule  # winding rule (default = `EvenOdd`)
---@param precision? integer   # decimal precision (default = 2)
---@return Paths, Paths        # result closed and open paths
function Clipper:difference(subjects, clips, fillrule, precision)
  return self:boolean(ClipType.Difference, fillrule or
    FillRule.EvenOdd, subjects, nil, clips, precision)
end

---Perform exclusive-or operation for paths.
---@param subjects   Paths     # subject paths (not null)
---@param clips      Paths|nil # clipping paths (may be null)
---@param fillrule?  FillRule  # winding rule (default = `EvenOdd`)
---@param precision? integer   # decimal precision (default = 2)
---@return Paths, Paths        # result closed and open paths
function Clipper:xor(subjects, clips, fillrule, precision)
  return self:boolean(ClipType.Xor, fillrule or
    FillRule.EvenOdd, subjects, nil, clips, precision)
end

---Inflate (offset) one closed or open path.
---@param path              Path
---@param delta             number   # offset distance ( >0 = outward, <0 = inward )
---@param jointype?         JoinType # edge‑join style (default = `Miter`)
---@param endtype?          EndType  # end‑cap style (default = `Polygon`)
---@param precision?        integer  # decimal precision (default = 2)
---@param miter_limit?      number   # max ratio of miter length to offset (default = 2.0)
---@param arc_tolerance?    number   # max error when approximating arcs (default = 0.0)
---@param reverse_solution? boolean  # reverse output winding (default = false)
---@return Paths                     # result inflated paths
function Clipper:inflate_path(path, delta, jointype, endtype,
  precision, miter_limit, arc_tolerance, reverse_solution)

  local precision = precision or 2
  local miter_limit = miter_limit or 2.0
  local arc_tolerance = arc_tolerance or 0.0

  local jointype = jointype or JoinType.Miter
  local endtype = endtype or EndType.Polygon
  local reverse_solution = reverse_solution == true

  local path_buf = path._buf_ref[1]
  return to_lua_paths(instance.InflatePathD(
    path_buf, delta, jointype, endtype, precision,
    miter_limit, arc_tolerance, reverse_solution))
end

---Inflate (offset) all paths in a collection.
---@param paths             Paths
---@param delta             number   # offset distance ( >0 = outward, <0 = inward )
---@param jointype?         JoinType # edge‑join style (default = `Miter`)
---@param endtype?          EndType  # end‑cap style (default = `Polygon`)
---@param precision?        integer  # decimal precision (default = 2)
---@param miter_limit?      number   # max ratio of miter length to offset (default = 2.0)
---@param arc_tolerance?    number   # max error when approximating arcs (default = 0.0)
---@param reverse_solution? boolean  # reverse output winding (default = false)
---@return Paths                     # result inflated paths
function Clipper:inflate_paths(paths, delta, jointype, endtype,
  precision, miter_limit, arc_tolerance, reverse_solution)

  local precision = precision or 2
  local miter_limit = miter_limit or 2.0
  local arc_tolerance = arc_tolerance or 0.0

  local jointype = jointype or JoinType.Miter
  local endtype = endtype or EndType.Polygon
  local reverse_solution = reverse_solution == true

  local paths_buf = paths._buf_ref[1]
  return to_lua_paths(instance.InflatePathsD(
    paths_buf, delta, jointype, endtype, precision,
    miter_limit, arc_tolerance, reverse_solution))
end

---Clip polygons to a rectangle (removes area outside).
---@param rect       Rect    # rectangle {left, top, right, bottom}
---@param paths      Paths   # paths (closed polygons) to clip
---@param precision? integer # decimal precision (default = 2)
---@return Paths             # result clipped polygons
function Clipper:rect_clip(rect, paths, precision)
  local precision = precision or 2
  local crect = ffi.new("CRectD", rect.left, rect.top, rect.right, rect.bottom)
  return to_lua_paths(instance.RectClipD(crect, paths._buf_ref[1], precision))
end

---Clip lines in paths to a rectangle (removes segments outside).
---@param rect       Rect    # rectangle {left, top, right, bottom}
---@param paths      Paths   # paths (line segments) to clip 
---@param precision? integer # decimal precision (default = 2)
---@return Paths             # result clipped segments
function Clipper:rect_clip_lines(rect, paths, precision)
  local precision = precision or 2
  local crect = ffi.new("CRectD", rect.left, rect.top, rect.right, rect.bottom)
  return to_lua_paths(instance.RectClipLinesD(crect, paths._buf_ref[1], precision))
end

---Build a `Path` from a flat numeric table.
---@param coords number[] # {x1, y1, x2, y2, ...}
function Clipper:make_path(coords)
  local length = #coords
  local path = Path(length / 2)
  for index = 1, length, 2 do
    local px = coords[index + 0]
    local py = coords[index + 1]
    path:add(Point(px, py))
  end
  return path
end

---DLL version string.
---@return string
function Clipper:version()
  return ffi.string(instance.Version())
end

-------------------------------------------------------------------
--  Module export
-------------------------------------------------------------------

return
{
  Point = Point,
  Rect  = Rect,
  Path  = Path,
  Paths = Paths,
  Clipper  = Clipper,
  ClipType = ClipType,
  FillRule = FillRule,
  JoinType = JoinType,
  EndType  = EndType
}
