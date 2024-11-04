## what is this?
A simple 2D signed-distance function renderer for my apps and games (and maybe yours?)

i'm gonna make docs for it soon

## what can it do?
- [x] Transforms
- [x] Scissors
- Text:
	- [x] Unicode
	- [x] Layout baking
	- [x] Line wrapping
	- [x] Left/center/right justify
	- [x] Looks good at any size/rotation/scale
	- [ ] Internal msdf atlas generation
	- [ ] Outlines
- Shapes:
  - [x] Boxes with rounded corners
  - [x] Drop shadows for said boxes
  - [x] Circles
  - [x] Arcs
  - [x] Pie (yum)
  - [x] Quadratic and cubic beziers
  - [x] Arbitrary polygons
  - [x] Quad paths (has artifacts)
  - [x] Font glyphs (using multi-channel sdf fonts)
- Most shapes can be drawn as an outline
- Fill styles:
  - [x] Solid color
  - [x] Linear dithered gradient
  - [x] Radial dithered gradient
  - [x] A wierd simplex noise gradient that I like
  - [ ] User textures
  - [ ] Mesh gradients
