# Clipper2-Lua

### A Polygon <a href="https://en.wikipedia.org/wiki/Clipping_(computer_graphics)">Clipping</a> and <a href="https://en.wikipedia.org/wiki/Parallel_curve">Offsetting</a> library for LuaJIT (FFI binding to the Clipper2 DLL)<br>

[![Version](https://img.shields.io/badge/Version-1.5.4-purple.svg)](https://github.com/AngusJohnson/Clipper2/releases)
[![License](https://img.shields.io/badge/License-Boost_1.0-lightblue.svg)](https://www.boost.org/LICENSE_1_0.txt)
[![documentation](https://user-images.githubusercontent.com/5280692/187832279-b2a43890-da80-4888-95fe-793f092be372.svg)](https://www.angusj.com/clipper2/Docs/Overview.htm)

## Introduction

The <b>Clipper2</b> library performs **intersection**, **union**, **difference** and **XOR** boolean operations on both simple and complex polygons. It also performs customizable polygon offsetting (inflating or shrinking polygons). This is a major update of the original <a href="https://sourceforge.net/projects/polyclipping/"><b>Clipper</b></a> library (now "Clipper1"), and while Clipper1 still works very well, Clipper2 is [better](https://www.angusj.com/clipper2/Docs/Changes.htm) in just about every way.

**Clipper2-Lua** provides a **high-level LuaJIT wrapper** for the official Clipper2 DLL, enabling fast and robust polygon clipping and offsetting in the LuaJIT environment. Key features include an **efficient conversion** between Lua tables and Clipper paths, a **simple, object-oriented API** for working with geometric objects, and **close mirroring** of the Clipper2 C++ interface for intuitive usage.

## LuaJIT

[LuaJIT](https://luajit.org/) is a high-performance **Just-In-Time Compiler for Lua**, widely used for demanding scripting tasks. This wrapper is implemented as a pure LuaJIT module using the **FFI (Foreign Function Interface)**, which allows direct loading and usage of the **Clipper2 DLL** through user-friendly Lua interface.

You can use this library on any platform where both **LuaJIT** and **Clipper2 DLL** are available (Windows, Linux, or Mac), as long as DLL is compiled for your target environment. The DLL file provided in this repository is built for Windows OS and supports both **32-bit** and **64-bit** architectures.

## DLL

Download prebuilt DLLs from the official [Clipper2 GitHub releases](https://github.com/AngusJohnson/Clipper2/releases).  
Or build DLL file yourself from [Clipper2 C++ source code](https://github.com/AngusJohnson/Clipper2).

## Documentation

See the **[Clipper2 HTML documentation](https://www.angusj.com/clipper2/Docs/Overview.htm)** for in-depth algorithm explanations and options.  
This LuaJIT binding exposes the most-used functions via Lua classes, closely mirroring the C++/C# API.

## API Reference

### Main Classes

#### 🟪 Clipper

The main interface for performing polygon operations.

- **Constructor**
  - `Clipper:new()`

- **Boolean Operations**
  - `Clipper:boolean(cliptype, fillrule, subject[, subj_open, `  
      `clip, precision, preserve_collinear, reverse_solution])`  
  - `Clipper:intersect(subject[, clip, fillrule, precision])`  
  - `Clipper:union(subject[, clip, fillrule, precision])`  
  - `Clipper:difference(subject[, clip, fillrule, precision])`  
  - `Clipper:xor(subject[, clip, fillrule, precision])`

- **Path Offsetting**
  - `Clipper:inflate_path(path, delta[, jointype, endtype, `  
    `precision, miter_limit, arc_tolerance, reverse_solution])`  
  - `Clipper:inflate_paths(paths, delta[, jointype, endtype, `  
    `precision, miter_limit, arc_tolerance, reverse_solution])`

- **Rectangle Clipping**
  - `Clipper:rect_clip(rect, paths[, precision])`  
  - `Clipper:rect_clip_lines(rect, paths[, precision])`

- **Helpers**
  - `Clipper:make_path{ x1, y1, x2, y2, ..., xn, yn }`  
  - `Clipper:version()` – Get DLL version string.

#### 🟦 Paths

A collection of polygon paths.

- `Paths:new()` - Initialize a new `Paths` container.
- `Paths:add(path)` – Add a `Path` to the collection.
- `Paths:get(index)` – Get the (1-based) `Path` at `index`.
- `Paths:clear()` – Remove all paths from the container.
- `Paths:size()` – Number of paths in the collection.
- `tostring(Paths)` – String representation.

#### 🟩 Path

A sequence of points (a single polygon or contour).

- `Path:new()` - Initialize a new `Path` container.
- `Path:add(point)` – Add a `Point` to the path.
- `Path:get(index)` – Get the (1-based) `Point` at `index`.
- `Path:set(index, point)` – Replace a point at position.
- `Path:clear()` – Remove all points from the container.
- `Path:size()` – Number of points in a collection.
- `tostring(Path)` – String representation.

#### 🟨 Rect

A rectangle structure for use with rectangle clipping.

- `Rect:new(left, top, right, bottom)` – Construct a new `Rect`.
- `tostring(Rect)` – String representation.

#### 🟧 Point

A 2D coordinate used to define vertices of paths.

- `Point:new(x, y)` - Initialize a new `Point`.
- `tostring(Point)` – String representation.

### Enums

Use these constants to control behavior in operations.

| Name         | Values                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `ClipType`   | `NoClip`, `Intersection`, `Union`, `Difference`, `Xor`                                          |
| `FillRule`   | `EvenOdd`, `NonZero`, `Positive`, `Negative`                                                    |
| `JoinType`   | `Square`, `Bevel`, `Round`, `Miter`                                                             |
| `EndType`    | `Polygon`, `Joined`, `Butt`, `Square`, `Round`  

## Example

```lua
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

--[[
65,38.7188 68.3516,39.7969 67.4141,43.2578 85.2266,54.7578 65,61.2734
65,64.75 61.5234,64.9375 55.9688,85.3594 43.6719,68.1406 40.4453,69.1875
39.2891,66.1172 18.3984,67.2266 30.7109,50 28.9297,47.5 31.5156,45.375
24.0703,25.5313 43.6719,31.8516 45.5938,29.1641 48.7578,31.2109 65,17.8594
--]]