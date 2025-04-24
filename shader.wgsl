struct Uniforms {
  size: vec2<f32>,
  time: f32,
  gamma: f32,
  text_unit_range: f32,
  text_in_bias: f32,
  text_out_bias: f32,
};

@group(0)
@binding(0)
var<uniform> uniforms: Uniforms;

struct Shape {
	kind: u32,
	next: u32,
	quad_min: vec2<f32>,
	quad_max: vec2<f32>,
	tex_min: vec2<f32>,
	tex_max: vec2<f32>,
	cv0: vec2<f32>,
	cv1: vec2<f32>,
	cv2: vec2<f32>,
	radius: vec4<f32>,
	width: f32,
	start: u32,
	count: u32,
	stroke: u32,
	xform: u32,
	paint: u32,
	mode: u32,
};

struct Shapes {
	shapes: array<Shape>,
};

@group(2)
@binding(0)
var<storage> shapes: Shapes;

struct Paint {
	kind: u32,
	noise: f32,
	cv0: vec2<f32>,
	cv1: vec2<f32>,
	cv2: vec2<f32>,
	cv3: vec2<f32>,
	col0: vec4<f32>,
	col1: vec4<f32>,
	col2: vec4<f32>,
};

struct Paints {
	paints: array<Paint>,
};

@group(2)
@binding(1)
var<storage> paints: Paints;

struct CVS {
	cvs: array<vec2<f32>>,
};

@group(2)
@binding(2)
var<storage> cvs: CVS;

struct XForms {
	xforms: array<mat4x4<f32>>,
};

@group(2)
@binding(3)
var<storage> xforms: XForms;

struct VertexOutput {
  @builtin(position) pos: vec4<f32>,
	@location(0) shape: u32,
	@location(1) p: vec2<f32>,
	@location(2) uv: vec2<f32>,
};

@group(1)
@binding(0)
var atlas_samp: sampler;

@group(1)
@binding(1)
var atlas_tex: texture_2d<f32>;

@group(1)
@binding(2)
var user_samp: sampler;

@group(1)
@binding(3)
var user_tex: texture_2d<f32>;

// Signed-distance functions
fn sd_subtract(d1: f32, d2: f32) -> f32 {
	return max(-d1, d2);
}
fn sd_circle(p: vec2<f32>, r: f32) -> f32 {
	return length(p) - r + 0.5;
}
fn sd_pie(p: vec2<f32>, sca: vec2<f32>, scb: vec2<f32>, r: f32) -> f32 {
	var pp = p * mat2x2<f32>(sca,vec2<f32>(-sca.y,sca.x));
	pp.x = abs(pp.x);
	let l = length(pp) - r;
	let m = length(pp - scb * clamp(dot(pp, scb), 0.0, r));
	return max(l, m * sign(scb.y * pp.x - scb.x * pp.y)) + 0.5;
}
fn sd_pie2(p: vec2<f32>, n: vec2<f32>) -> f32 {
	return abs(p).x * n.y + p.y * n.x;
}
fn sd_arc_square(p: vec2<f32>, sca: vec2<f32>, scb: vec2<f32>, radius: f32, width: f32) -> f32 {
  let pp = p * mat2x2<f32>(sca,vec2<f32>(-sca.y,sca.x));
  return sd_subtract(sd_pie2(pp, vec2<f32>(scb.x, -scb.y)), abs(sd_circle(pp, radius)) - width) + 1;
}
fn sd_arc(p: vec2<f32>, sca: vec2<f32>, scb: vec2<f32>, ra: f32, rb: f32) -> f32 {
	var pp = p * mat2x2<f32>(vec2<f32>(sca.x, sca.y), vec2<f32>(-sca.y, sca.x));
  pp.x = abs(pp.x);
  var k = 0.0;
  if (scb.y * pp.x > scb.x * pp.y) {
    k = dot(pp, scb);
  } else {
    k = length(pp);
  }
  return sqrt(dot(pp, pp) + ra * ra - 2.0 * ra * k) - rb + 1;
}
fn sd_box(p: vec2<f32>, b: vec2<f32>, rr: vec4<f32>) -> f32 {
	var r: vec2<f32>;
	if (p.x > 0.0) {
		r = rr.yw;
	} else {
		r = rr.xz;
	}
	if (p.y > 0.0) {
		r.x = r.y;
	}
  let q = abs(p) - b + r.x;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2<f32>(0.0, 0.0))) - r.x + 0.5;
}
fn sd_bezier_approx(p: vec2<f32>, A: vec2<f32>, B: vec2<f32>, C: vec2<f32>) -> f32 {
  let v0 = normalize(B - A); let v1 = normalize(C - A);
  let det = v0.x * v1.y - v1.x * v0.y;
  if(abs(det) < 0.01) {
    return sd_bezier(p, A, B, C);
  }
  return length(get_distance_vector(A-p, B-p, C-p));
}
fn sd_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
	let pa = p - a;
	let ba = b - a;
	let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) + 0.5;
}
fn cro(a: vec2<f32>, b: vec2<f32>) -> f32 {
	return a.x * b.y - a.y * b.x;
}
fn sd_bezier(pos: vec2<f32>, A: vec2<f32>, B: vec2<f32>, C: vec2<f32>) -> f32 {
  let a = B - A;
  let b = A - 2.0 * B + C;
  let c = a * 2.0;
  let d = A - pos;
  let kk = 1.0 / dot(b, b);
  let kx = kk * dot(a, b);
  let ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
  let kz = kk * dot(d, a);
  var res = 0.0;
  let p = ky - kx * kx;
  let p3 = p * p * p;
  let q = kx * (2.0 * kx * kx + -3.0 * ky) + kz;
  var h = q * q + 4.0 * p3;
  if (h > 0.0) {
    h = sqrt(h);
    let x = (vec2<f32>(h, -h) - q) / 2.0;
    let uv = sign(x) * pow(abs(x), vec2<f32>(1.0 / 3.0));
    let t = clamp( uv.x + uv.y - kx, 0.0, 1.0 );
    res = dot2(d + (c + b * t) * t);
  } else {
    let z = sqrt(-p);
    let v = acos(q / (p * z * 2.0)) / 3.0;
    let m = cos(v);
    let n = sin(v) * 1.732050808;
    let t = clamp(vec3<f32>( m + m, -n - m, n - m) * z - kx, vec3<f32>(0.0), vec3<f32>(1.0));
    res = min(dot2(d + (c + b * t.x) * t.x), dot2(d + (c + b * t.y) * t.y));
    // the third root cannot be the closest
    // res = min(res,dot2(d+(c+b*t.z)*t.z));
  }
  return sqrt(res);
}
fn cos_acos_3(X: f32) -> f32 {
	var x = sqrt(0.5 + 0.5 * X);
	return x * (x * (x * ((x * -0.008972) + 0.039071) - 0.107074) + 0.576975) + 0.5;
}
fn sd_signed_bezier(pos: vec2<f32>, A: vec2<f32>, B: vec2<f32>, C: vec2<f32>) -> f32 {
	let a = B - A;
	let b = A - 2.0 * B + C;
	let c = a * 2.0;
	let d = A - pos;
	let kk = 1.0 / dot(b, b);
	let kx = kk * dot(a, b);
	let ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
	let kz = kk * dot(d, a);
	var res = 0.0;
	var sgn = 0.0;
	let p = ky - kx * kx;
	let p3 = p * p * p;
	let q = kx * (2.0 * kx * kx + -3.0 * ky) + kz;
	var h = q * q + 4.0 * p3;
	if (h >= 0.0) {
		h = sqrt(h);
		var x = (vec2<f32>(h, -h) - q) / 2.0;
		// if (abs(p) < 0.001) {
		// 	let k = p3 / q;
		// 	x = vec2<f32>(k, -k - q);
		// }
		let uv = sign(x) * pow(abs(x), vec2(1.0 / 3.0));
		var t = uv.x + uv.y;
		t -= (t * (t * t + 3.0 * p) + q) / (3.0 * t * t + 3.0 * p);
		t = clamp(t - kx, 0.0, 1.0);
		let w = d + (c + b * t) * t;
		res = dot2(w);
		sgn = cro(c + 2.0 * b * t, w);
	} else {
		let z = sqrt(-p);
		let m = cos_acos_3(q / (p * z * 2.0));
		var n = sqrt(1.0 - m * m);
		n *= sqrt(3.0);
		let t = clamp(vec3<f32>(m + m, -n - m, n - m) * z - kx, vec3<f32>(0.0), vec3<f32>(1.0));
		let qx = d + (c + b * t.x) * t.x;
		let dx = dot2(qx);
		let qy = d + (c + b + t.y) * t.y;
		let dy = dot2(qy);
		if (dx < dy) {
			res = dx;
			sgn = cro(a + b * t.x, qx);
		} else {
			res = dy;
			sgn = cro(a + b * t.y, qy);
		}
	}
	return sqrt(res) * sign(sgn);
}
fn sd_line_test(p: vec2<f32>, A: vec2<f32>, B: vec2<f32>) -> f32 {
	let dir = normalize(B - A);
	var det = 1.0 / ((dir.x * dir.x) - (-dir.y * dir.y));
	let xform = mat2x2<f32>(
		det * dir.x, det * -dir.y,
		det * dir.y, det * dir.x,
	);
	return (xform * (p - A)).y / 4.0;
}
fn sd_triangle(p: vec2<f32>, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
	let e0 = p1 - p0;
	let e1 = p2 - p1;
	let e2 = p0 - p2;
	let v0 = p - p0;
	let v1 = p - p1;
	let v2 = p - p2;
	let pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	let pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	let pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	let s = sign(e0.x * e2.y - e0.y * e2.x);
	let d = min(min(vec2<f32>(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                  vec2<f32>(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                  vec2<f32>(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
  return -sqrt(d.x) * sign(d.y);
}

// Blur function for drop shadows
fn rounded_box_shadow_x(x: f32, y: f32, sigma: f32, corner: f32, half_size: vec2<f32>) -> f32 {
	let delta = min(half_size.y - corner - abs(y), 0.0);
	let curved = half_size.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
  let integral = 0.5 + 0.5 * erf((x + vec2(-curved, curved)) * (sqrt(0.5) / sigma));
  return integral.y - integral.x;
}

// Math helpers
fn gaussian(x: f32, sigma: f32) -> f32 {
	let pi: f32 = 3.141592653589793;
  return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * pi) * sigma);
}
fn dot2(v: vec2<f32>) -> f32 {
    return dot(v, v);
}
fn get_distance_vector(b0: vec2<f32>, b1: vec2<f32>, b2: vec2<f32>) -> vec2<f32> {
    let a = det(b0, b2);
    let b = 2.0 * det(b1, b0);
    let d = 2.0 * det(b2, b1);

    let f = b * d - a * a;
    let d21 = b2 - b1; let d10 = b1 - b0; let d20 = b2 - b0;
    var gf = 2.0 * (b * d21 + d * d10 + a * d20);
    gf = vec2<f32>(gf.y, -gf.x);
    let pp = -f * gf / dot(gf, gf);
    let d0p = b0 - pp;
    let ap = det(d0p, d20); let bp = 2.0 * det(d10, d0p);
    // (note that 2*ap+bp+dp=2*a+b+d=4*area(b0,b1,b2))
    let t = clamp((ap + bp) / (2.0 * a + b + d), 0.0, 1.0);
    return mix(mix(b0, b1, t), mix(b1, b2, t), t);
}
fn det(a: vec2<f32>, b: vec2<f32>) -> f32 { return a.x * b.y - b.x * a.y; }
fn erf(x: vec2<f32>) -> vec2<f32> {
    let s = sign(x);
    let a = abs(x);
    var y = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    y *= y;
    return s - s / (y * y);
}

// Boolean shape tests
fn lineTest(p: vec2<f32>, A: vec2<f32>, B: vec2<f32>) -> bool {
  let cs = i32(A.y < p.y) * 2 + i32(B.y < p.y);
  if(cs == 0 || cs == 3) { return false; } // trivial reject
  let v = B - A;
  // Intersect line with x axis.
  let t = (p.y - A.y) / v.y;
  return (A.x + t * v.x) > p.x;
}
fn bezierTest(p: vec2<f32>, A: vec2<f32>, B: vec2<f32>, C: vec2<f32>) -> bool {
  // Compute barycentric coordinates of p.
  // p = s * A + t * B + (1-s-t) * C
  let v0 = B - A;
  let v1 = C - A;
  let v2 = p - A;
  let det = v0.x * v1.y - v1.x * v0.y;
  let s = (v2.x * v1.y - v1.x * v2.y) / det;
  let t = (v0.x * v2.y - v2.x * v0.y) / det;
  if(s < 0.0 || t < 0.0 || (1.0 - s - t) < 0.0) {
    return false; // outside triangle
  }
  // Transform to canonical coordinte space.
  let u = s / 2 + t;
  let v = t;
  return u * u < v;
}

// Functions for msdf text rendering
fn median(r: f32, g: f32, b: f32) -> f32 {
	return max(min(r, g), min(max(r, g), b));
}
fn screen_px_range(texcoord: vec2<f32>) -> f32 {
	let screen_tex_size = vec2<f32>(1.0) / fwidth(texcoord);
	return max(0.5 * dot(vec2<f32>(uniforms.text_unit_range), screen_tex_size), 2.0);
}
fn contour(dist: f32, bias: f32, texcoord: vec2<f32>) -> f32 {
	let width = screen_px_range(texcoord);
	let e = width * (dist - 0.5 + uniforms.text_in_bias) + 0.5 + (uniforms.text_out_bias + bias);
	return smoothstep(0.0, 1.0, e);
}
fn sample_msdf(uv: vec2<f32>, bias: f32) -> f32 {
	let msd = textureSample(atlas_tex, atlas_samp, uv).rgb;
	let dist = median(msd.r, msd.g, msd.b);
	return contour(dist, bias, uv);
}
fn sample_sdf(uv: vec2<f32>, bias: f32) -> f32 {
	let dist = textureSample(atlas_tex, atlas_samp, uv).a;
	return contour(dist, bias, uv);
}

// Returns the signed sistance to a given shape
fn sd_shape(shape: Shape, p: vec2<f32>) -> f32 {
	var d = 1e10;
	switch (shape.kind) {
		// No shape
		case 0u: {}
		// Circle
		case 1u: {
			d = sd_circle(p - shape.cv0, shape.radius[0]);
		}
		// Box
		case 2u: {
			let center = 0.5 * (shape.cv0 + shape.cv1);
			d = sd_box(p - center, (shape.cv1 - shape.cv0) * 0.5, shape.radius);
		}
		// Rounded box shadow
		case 3u: {
			let blur_radius = shape.cv2.x;
			let center = 0.5*(shape.cv1 + shape.cv0);
			let half_size = 0.5*(shape.cv1 - shape.cv0);
      let point = p - center;

      let low = point.y - half_size.y;
      let high = point.y + half_size.y;
      let start = clamp(-3.0 * blur_radius, low, high);
      let end = clamp(3.0 * blur_radius, low, high);

      let step = (end - start) / 4.0;
      var y = start + step * 0.5;
      var value = 0.0;
      for (var i: i32 = 0; i < 4; i++) {
          value += rounded_box_shadow_x(point.x, point.y - y, blur_radius, shape.radius[0], half_size) * gaussian(y, blur_radius) * step;
          y += step;
      }
      d = 1.0 - value;
		}
		// Arc
		case 4u: {
			if (shape.start > 0u) {
				d = sd_arc_square(p - shape.cv0, shape.cv1, shape.cv2, shape.radius[0], shape.radius[1]);
			} else {
				d = sd_arc(p - shape.cv0, shape.cv1, shape.cv2, shape.radius[0], shape.radius[1]);
			}
		}
		// Bezier
		case 5u: {
			d = sd_bezier(p, shape.cv0, shape.cv1, shape.cv2) + 1.0 - shape.width;
		}
		// Pie
		case 6u: {
			d = sd_pie(p - shape.cv0, shape.cv1, shape.cv2, shape.radius[0]);
		}
		// Quad Path
		case 7u: {
			var s = 1.0;
			let filterWidth = 1.0;
      for (var i = 0; i < i32(shape.count); i = i + 1) {
      	let j = i32(shape.start) + 3 * i;
        let a = cvs.cvs[j];
        let b = cvs.cvs[j + 1];
        let c = cvs.cvs[j + 2];
        var skip = false;
        let xmax = p.x + filterWidth;
        let xmin = p.x - filterWidth;
        // If the hull is far enough away, don't bother with
        // an sdf.
        if (a.x > xmax && b.x > xmax && c.x > xmax) {
          skip = true;
        } else if (a.x < xmin && b.x < xmin && c.x < xmin) {
          skip = true;
        }
        if (!skip) {
        	d = min(d, sd_bezier(p, a, b, c));
        }
        if (lineTest(p, a, c)) {
        	s = -s;
        }
        // Flip if inside area between curve and line.
        if (!skip) {
          if (bezierTest(p, a, b, c)) {
            s = -s;
          }
        }
      }
      d = d * s;
    }
    // Arbitrary Polygon
    case 8u: {
   		var d = dot(p - cvs.cvs[0], p - cvs.cvs[0]);
     	var s = 1.0;
      for(var i: u32 = 0; i < shape.count; i += 1u) {
      	let j = (i + 1) % shape.count;
      	let ii = i + shape.start;
       	let jj = j + shape.start;
        let e = cvs.cvs[jj] - cvs.cvs[ii];
        let w = p - cvs.cvs[ii];
        let b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
        d = min(d, dot(b, b));
        let c = vec3<bool>(p.y >= cvs.cvs[ii].y, p.y < cvs.cvs[jj].y, e.x * w.y > e.y * w.x);
        if(all(c) || all(not(c))) {
        	 s *= -1.0;
        }
      }
      return s * sqrt(d) + 0.5;
    }
    // Glyph
    case 9u: {
    	// Supersampling parameters
    	let dscale = 0.352;
     	let uv = shape.cv0;
      let bias = shape.radius[0];
      let duv = dscale * (dpdxFine(uv) + dpdyFine(uv));
      let box = vec4<f32>(uv - duv, uv + duv);
      // Supersample the sdf texture
      let asum = sample_msdf(box.xy, bias) + sample_msdf(box.zw, bias) + sample_msdf(box.xw, bias) + sample_msdf(box.zy, bias);
      // Determine opacity
      var alpha = (sample_msdf(uv, bias) + 0.5 * asum) / 3.0;
      // Reflect opacity with distance result
      d = smoothstep(1.0, 0.0, alpha);
    }
    // Line segment
    case 10u: {
    	d = sd_line(p, shape.cv0, shape.cv1) - shape.width;
    }
    // Signed bezier
    case 11u: {
    	d = sd_signed_bezier(p, shape.cv0, shape.cv1, shape.cv2) * shape.radius.x;
    }
		default: {}
	}

	switch (shape.stroke) {
		case 1u: {
			let r = shape.width * 0.5;
			d = abs(d + r - 0.5) - r + 0.5;
		}
		case 2u: {
			d = abs(d) - shape.width / 2 + 0.5;
		}
		case 3u: {
			let r = shape.width * 0.5;
			d = abs(d - r + 0.5) - r + 0.5;
		}
		case 4u: {
			d = smoothstep(0.0, 1.0, d / shape.width);
		}
		default: {}
	}
	return d;
}

fn not(v: vec3<bool>) -> vec3<bool> {
	return vec3<bool>(!v.x, !v.y, !v.z);
}
fn hash(p: vec2<f32>) -> vec2<f32> {
	var pp = vec2<f32>( dot(p,vec2<f32>(127.1,311.7)), dot(p,vec2<f32>(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(pp)*43758.5453123);
}
fn random(coords: vec2<f32>) -> f32 {
	return fract(sin(dot(coords.xy, vec2<f32>(12.9898, 78.233))) * 43758.5453);
}
fn noise(p: vec2<f32>) -> f32 {
  let K1: f32 = 0.366025404; // (sqrt(3)-1)/2;
  let K2: f32 = 0.211324865; // (3-sqrt(3))/6;

	let i: vec2<f32> = floor(p + (p.x + p.y) * K1);
  let a: vec2<f32> = p - i + (i.x + i.y) * K2;
  let m: f32 = step(a.y, a.x);
  let o: vec2<f32> = vec2(m, 1.0 - m);
  let b: vec2<f32> = a - o + K2;
	let c: vec2<f32> = a - 1.0 + 2.0 * K2;
  let h: vec3<f32> = max(vec3<f32>(0.5) - vec3<f32>(dot2(a), dot2(b), dot2(c)), vec3<f32>(0.0));
	let n: vec3<f32> = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i+o)), dot(c, hash(i + 1.0)));
  return dot(n, vec3<f32>(70.0));
}
fn hue_to_rgb(p: f32, q: f32, tt: f32) -> f32 {
	var t = tt;
	if (t < 0.0) {
		t += 1.0;
	}
	if (t > 1.0) {
		t -= 1.0;
	}
	if (t < 1.0 / 6.0) {
		return p + (q - p) * 6.0 * t;
	}
	if (t < 1.0 / 2.0) {
		return q;
	}
	if (t < 2.0 / 3.0) {
		return p + (q - p) * 6.0 * (2.0 / 3.0 - t);
	}
	return p;
}
fn hsl_to_rgb(h: f32, s: f32, l: f32) -> vec3<f32> {
	var r = 0.0;
	var g = 0.0;
	var b = 0.0;
	if (s == 0.0) {
		r = l;
		g = l;
		b = l;
	} else {
		var q = 0.0;
		if (l < 0.5) {
			q = l * (1.0 + s);
		} else {
			q = l + s - l * s;
		}
		let p = 2.0 * l - q;
		r = hue_to_rgb(p, q, h + 1.0 / 3.0);
		g = hue_to_rgb(p, q, h);
		b = hue_to_rgb(p, q, h - 1.0 / 3.0);
	}
	return vec3<f32>(r, g, b);
}

@vertex
fn vs_main(@builtin(vertex_index) vertex: u32, @builtin(instance_index) instance: u32) -> VertexOutput {
	let shape = shapes.shapes[instance];
  var out: VertexOutput;

	switch (vertex) {
	case 0u: {
		out.p = shape.quad_min;
		out.uv = shape.tex_min;
	}
	case 1u: {
		out.p = vec2<f32>(shape.quad_min.x, shape.quad_max.y);
		out.uv = vec2<f32>(shape.tex_min.x, shape.tex_max.y);
	}
	case 2u: {
		out.p = vec2<f32>(shape.quad_max.x, shape.quad_min.y);
		out.uv = vec2<f32>(shape.tex_max.x, shape.tex_min.y);
	}
	case 3u: {
		out.p = shape.quad_max;
		out.uv = shape.tex_max;
	}
	default: {}
	}

	let xform = xforms.xforms[shape.xform];
  var pos = (xform * vec4<f32>(out.p, 0.0, 1.0)).xy;
  pos = vec2<f32>(2.0, -2.0) * pos / uniforms.size + vec2<f32>(-1.0, 1.0);
  out.pos = vec4<f32>(pos, 0.0, 1.0);
  out.shape = instance;
  return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
	var out: vec4<f32>;
	var d = 0.0;

	var shape = shapes.shapes[in.shape];

	if (shape.paint == 0u) {
		return out;
	}

	let paint = paints.paints[shape.paint];

	if (shape.kind > 0u) {
		if (shape.kind == 9u) {
			shape.cv0 = in.uv;
		}
		d = sd_shape(shape, in.p);
	}

	while (shape.next > 0u) {
		shape = shapes.shapes[shape.next];
		if (shape.kind > 0u) {
			if (shape.kind == 9u) {
				shape.cv0 = in.uv;
			}
			switch (shape.mode) {
				// Union
				case 0u: {
					d = min(d, sd_shape(shape, in.p));
				}
				// Subtraction
				case 1u: {
					d = max(-d, sd_shape(shape, in.p));
				}
				// Intersection
				case 2u: {
					d = max(d, sd_shape(shape, in.p));
				}
				// Xor
				case 3u: {
					let d1 = sd_shape(shape, in.p);
					d = max(min(d, d1), -max(d, d1));
				}
				default: {}
			}
		}
	}

	let opacity = clamp(1.0 - d, 0.0, 1.0);

	// Get pixel color
	if (opacity > 0.0) {
		switch (paint.kind) {
			// Solid color
			case 1u: {
				out = paint.col0;
			}
			// Atlas sampler
			case 2u: {
				out = textureSample(atlas_tex, atlas_samp, paint.cv0 + ((in.pos.xy - paint.cv2) / paint.cv3) * paint.cv1) * paint.col0;
			}
			// User texture sampler
			case 3u: {
				out = textureSampleBias(user_tex, user_samp, in.uv, -0.5) * paint.col0;
			}
			// Simplex noise gradient
			case 4u: {
				var uv = in.p;
				var f = 0.5 * noise(uv * 0.0025 + uniforms.time * 0.2);
				uv = mat2x2<f32>(1.6, 1.2, -1.2, 1.6) * uv;
				f += noise(uv * 0.005 - uniforms.time * 0.2);
				out = mix(paint.col0, paint.col1, clamp(f, 0.0, 1.0));
			}
			// Linear Gradient
			case 5u: {
				let dir = paint.cv1 - paint.cv0;
				var det = 1.0 / ((dir.x * dir.x) - (-dir.y * dir.y));
				let xform = mat2x2<f32>(
					det * dir.x, det * -dir.y,
					det * dir.y, det * dir.x,
				);
		    var t = clamp((xform * (in.p - paint.cv0)).x, 0.0, 1.0);
				// Mix color output
		    out = mix(paint.col0, paint.col1, t + mix(-paint.noise, paint.noise, random(in.p)));
			}
			// Radial gradient
			case 6u: {
				let r = paint.cv1.x;
				var t = clamp(length(in.p - paint.cv0) / r, 0.0, 1.0);
		  	out = mix(paint.col0, paint.col1, t + mix(-paint.noise, paint.noise, random(in.p)));
			}
			// Distance field
			case 7u: {
				if (d > 0) {
					out = vec4<f32>(d / 10, 0.0, 0.0, 1.0);
				} else {
					out = vec4<f32>(0.0, 0.0, -d / 10, 1.0);
				}
				out = vec4<f32>(out.xyz * 0.8 + 0.2 * cos(0.5 * (d + uniforms.time * 5)), 1.0);
				out = mix(out, vec4<f32>(1.0), 1.0 - smoothstep(0.0, 0.25, -(d / 5.0)));
			}
			// Wheel gradient
			case 8u: {
				let diff = in.p - paint.cv0;
				let hue = atan2(diff.y, diff.x) * 0.159154;
				out = vec4<f32>(hsl_to_rgb(hue, 1.0, 0.5), 1.0);
			}
			// Tri-gradient
			case 9u: {
				let v0 = paint.cv1 - paint.cv0;
				let v1 = paint.cv2 - paint.cv0;
				let v2 = in.p - paint.cv0;
				let denom = v0.x * v1.y - v1.x * v0.y;
				let v = (v2.x * v1.y - v1.x * v2.y) / denom;
				let w = (v0.x * v2.y - v2.x * v0.y) / denom;
				let u = 1 - v - w;
				out = paint.col0 * u + paint.col1 * v + paint.col2 * w;
			}
			// Default case
			default: {}
		}
	}

	out = vec4<f32>(pow(out.rgb, vec3<f32>(uniforms.gamma)), out.a * opacity);

	return out;
}
