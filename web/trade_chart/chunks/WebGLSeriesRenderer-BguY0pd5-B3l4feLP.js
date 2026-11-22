var bt=Object.defineProperty;var wt=(i,e,t)=>e in i?bt(i,e,{enumerable:!0,configurable:!0,writable:!0,value:t}):i[e]=t;var f=(i,e,t)=>wt(i,typeof e!="symbol"?e+"":e,t);import{a3 as kt,a4 as St,a5 as Rt,a6 as Ct,a7 as At,a8 as Mt,a9 as Et,aa as Bt}from"../chart.js";var q=(i,e)=>i.time===e.time&&i.open===e.open&&i.high===e.high&&i.low===e.low&&i.close===e.close&&i.volume===e.volume,K=class{constructor(){f(this,"buffer",new Float32Array);f(this,"count",0);f(this,"basePrice",0);f(this,"samples",[]);f(this,"last",null);f(this,"source",null);f(this,"revision")}get values(){return this.buffer}get length(){return this.count}get base(){return this.basePrice}sync(i,e){let t=i.length;if(t===0)return this.reset(),{full:!0,from:0,to:0};let r=this.count,o=i===this.source&&e===this.revision&&r>0&&t>=r&&this.samples.every(({index:a,bar:l})=>q(i[a],l));if(this.revision=e,!o)return this.basePrice=i[t-1].close,this.ensure(t),this.write(i,0,t),this.remember(i),{full:!0,from:0,to:t};let s=this.last!==null&&q(i[r-1],this.last)?r:r-1;return t>this.buffer.length/6?(this.ensure(t),this.write(i,0,t),this.remember(i),{full:!0,from:0,to:t}):(this.write(i,s,t),this.remember(i),{full:!1,from:s,to:t})}reset(){this.count=0,this.samples=[],this.last=null,this.source=null,this.revision=void 0}ensure(i){i*6<=this.buffer.length||(this.buffer=new Float32Array(Math.max(i+1024,Math.ceil(i*1.25))*6))}write(i,e,t){let r=this.buffer,o=this.basePrice;for(let s=e;s<t;s++){let a=i[s],l=s*6;r[l]=a.open-o,r[l+1]=a.high-o,r[l+2]=a.low-o,r[l+3]=a.close-o,r[l+4]=a.volume,r[l+5]=+(a.close>=a.open)}this.count=t}remember(i){let e=i.length,t=e-1,r=new Set;if(t>0)for(let o=0;o<16;o++)r.add(Math.min(t-1,Math.round(o*(t-1)/15)));this.samples=[...r].map(o=>({index:o,bar:{...i[o]}})),this.last={...i[e-1]},this.source=i}},D=new Map,C;function P(i,e){return i.endsWith("%")?parseFloat(i)/100:parseFloat(i)/e}function ht(i){let e=i.trim();if(e.toLowerCase()==="transparent")return[0,0,0,0];let t=/^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.exec(e);if(t){let o=t[1];o.length<=4&&(o=[...o].map(a=>a+a).join(""));let s=a=>parseInt(o.slice(a,a+2),16)/255;return[s(0),s(2),s(4),o.length===8?s(6):1]}let r=/^rgba?\(\s*([\d.]+%?)[\s,]+([\d.]+%?)[\s,]+([\d.]+%?)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/i.exec(e);return r?[P(r[1],255),P(r[2],255),P(r[3],255),r[4]===void 0?1:P(r[4],1)]:null}function Tt(){if(C!==void 0)return C;try{C=typeof OffscreenCanvas<"u"?new OffscreenCanvas(1,1).getContext("2d"):typeof document<"u"?document.createElement("canvas").getContext("2d"):null}catch{C=null}return C}function Ft(i){let e=Tt();if(!e)return null;e.fillStyle="#000",e.fillStyle=i;let t=String(e.fillStyle);if(e.fillStyle="#fff",e.fillStyle=i,String(e.fillStyle)!==t)return null;let r=ht(t);if(r)return r;e.clearRect(0,0,1,1),e.fillRect(0,0,1,1);let o=e.getImageData(0,0,1,1).data;return[o[0]/255,o[1]/255,o[2]/255,o[3]/255]}var I=new Set;function ct(i){let e=D.get(i);if(e)return e;if(I.has(i))return null;let t=ht(i)??Ft(i);return D.size>256&&D.clear(),I.size>256&&I.clear(),t?D.set(i,t):I.add(i),t}function x(i){return ct(i)??[0,0,0,0]}function w([i,e,t,r]){return[i*r,e*r,t*r,r]}function Dt(i,e){let{min:t,max:r}=i.priceRange,{y:o,height:s}=i.chartRect,a=+(i.invertScale===!0),l={log:0,invert:a,yA:o+s/2,yB:0,logOffset:0,min:1,logFloor:0,logK:0,top:o,bottom:o+s};if(i.logScale&&t>0&&r>0){let h=Math.log(r)-Math.log(t);return h===0?l:{...l,log:1,logOffset:e-t,min:t,logFloor:2**-52/t,logK:s/h}}let n=r-t;if(n===0)return l;let c=s/n;return a?{...l,yA:o+(e-t)*c,yB:c}:{...l,yA:o+(r-e)*c,yB:-c}}var Pt=class{constructor(i){this.gl=i}program(i,e,t){let r=this.gl,o=(h,u)=>{let p=r.createShader(h);if(!p)throw Error("WebGL: no shader");if(r.shaderSource(p,u),r.compileShader(p),!r.getShaderParameter(p,r.COMPILE_STATUS)){let d=r.getShaderInfoLog(p);throw r.deleteShader(p),Error(`WebGL shader: ${d}`)}return p},s=o(r.VERTEX_SHADER,i),a=o(r.FRAGMENT_SHADER,e),l=r.createProgram();if(!l)throw Error("WebGL: no program");if(r.attachShader(l,s),r.attachShader(l,a),r.linkProgram(l),r.deleteShader(s),r.deleteShader(a),!r.getProgramParameter(l,r.LINK_STATUS))throw Error(`WebGL program: ${r.getProgramInfoLog(l)}`);let n=r.createVertexArray();if(!n)throw Error("WebGL: no vertex array");let c=new Map;for(let h of t)c.set(h,r.getAttribLocation(l,h));return{program:l,vao:n,uniforms:new Map,attribs:c}}buffer(){let i=this.gl.createBuffer();if(!i)throw Error("WebGL: no buffer");return i}use(i){return this.gl.useProgram(i.program),this.gl.bindVertexArray(i.vao),i}attrib(i,e,t,r,o,s=1){let a=i.attribs.get(e);if(a===void 0||a<0)return;let l=this.gl;l.enableVertexAttribArray(a),l.vertexAttribPointer(a,t,l.FLOAT,!1,r,o),l.vertexAttribDivisor(a,s)}int(i,e,t){this.gl.uniform1i(this.loc(i,e),t)}float(i,e,t){this.gl.uniform1f(this.loc(i,e),t)}vec2(i,e,t,r){this.gl.uniform2f(this.loc(i,e),t,r)}vec4(i,e,t){this.gl.uniform4f(this.loc(i,e),t[0],t[1],t[2],t[3])}loc(i,e){return i.uniforms.has(e)||i.uniforms.set(e,this.gl.getUniformLocation(i.program,e)),i.uniforms.get(e)??null}deleteProgram(i){this.gl.deleteVertexArray(i.vao),this.gl.deleteProgram(i.program)}scissor(i,e,t,r,o,s){let a=Math.max(0,Math.floor(i)),l=Math.max(0,Math.floor(e)),n=Math.min(o,Math.ceil(t)),c=Math.min(s,Math.ceil(r));if(!(n>a&&c>l))return!1;let h=this.gl;return h.enable(h.SCISSOR_TEST),h.scissor(a,s-c,n-a,c-l),!0}};function It(i){let e=i.length/2;if(e<3)return[];let t=0,r=0;for(let a=1;a<e;a++)i[2*a]<i[2*t]&&(t=a),i[2*a]>i[2*r]&&(r=a);if(i[2*t]===i[2*r])return[];let o=J(i,t,r,1,e),s=J(i,t,r,-1,e);return!o||!s?null:Lt(o,s)}function X(i){let e=0,t=i.length/2;for(let r=0;r<t;r++){let o=(r+1)%t;e+=i[2*r]*i[2*o+1]-i[2*o]*i[2*r+1]}return e/2}function J(i,e,t,r,o){let s=[i[2*e],i[2*e+1]];for(let a=e;a!==t;){if(a=(a+r+o)%o,i[2*a]<s[s.length-2])return null;s.push(i[2*a],i[2*a+1])}return s}var Q=class{constructor(i){f(this,"i",0);this.c=i}at(i,e){let t=this.c;for(;this.i+5<t.length&&(t[this.i+2]<e||t[this.i+2]===t[this.i]);)this.i+=2;let r=t[this.i],o=t[this.i+1],s=t[this.i+2],a=t[this.i+3],l=n=>s===r?o:o+(a-o)*(n-r)/(s-r);return[l(i),l(e)]}};function Lt(i,e){let t=new Set;for(let n=0;n<i.length;n+=2)t.add(i[n]);for(let n=0;n<e.length;n+=2)t.add(e[n]);let r=[...t].sort((n,c)=>n-c),o=new Q(i),s=new Q(e),a=[],l=r.length-2;for(let n=0;n<=l;n++){let c=r[n],h=r[n+1],[u,p]=o.at(c,h),[d,v]=s.at(c,h);u===d&&p===v||a.push(c,h,u,p,d,v,+(n===0),+(n===l))}return a}var R=`#version 300 es
precision highp float;
uniform vec2 u_canvas;
uniform vec4 u_clip;

vec4 toClip(vec2 dev) {
  return vec4(dev.x / u_canvas.x * 2.0 - 1.0, 1.0 - dev.y / u_canvas.y * 2.0, 0.0, 1.0);
}
`,j=`
vec2 corner(int k) {
  if (k == 0) return vec2(0.0, 0.0);
  if (k == 1 || k == 4) return vec2(1.0, 0.0);
  if (k == 2 || k == 3) return vec2(0.0, 1.0);
  return vec2(1.0, 1.0);
}
const vec4 NOWHERE = vec4(-2.0, -2.0, 0.0, 1.0);
`,H=`
// This fragment's pixel centre in device pixels, y down.
vec2 pixelCentre() { return vec2(gl_FragCoord.x, u_canvas.y - gl_FragCoord.y); }

// The share of the pixel centred at p inside the clip.
float clipCoverage(vec2 p) {
  vec2 lo = p - 0.5;
  vec2 c = clamp(min(lo + 1.0, u_clip.zw) - max(lo, u_clip.xy), 0.0, 1.0);
  return c.x * c.y;
}
`,Nt=`${R}${j}
uniform float u_hw;
in vec4 a_p0;
in vec4 a_p1;
in vec4 a_p2;
in vec4 a_p3;
in vec4 a_p4;
in vec4 a_p5;
flat out vec4 v_p0;
flat out vec4 v_p1;
flat out vec4 v_p2;
flat out vec4 v_p3;
flat out vec4 v_p4;
flat out vec4 v_p5;

void main() {
  v_p0 = a_p0; v_p1 = a_p1; v_p2 = a_p2; v_p3 = a_p3; v_p4 = a_p4; v_p5 = a_p5;
  if (a_p2.z < 0.5 || a_p3.z < 0.5) { gl_Position = NOWHERE; return; }
  vec2 a = a_p2.xy;
  vec2 b = a_p3.xy;
  vec2 d = b - a;
  float len = length(d);
  vec2 dir = len > 0.0 ? d / len : vec2(1.0, 0.0);
  vec2 n = vec2(-dir.y, dir.x);
  float m = u_hw + 1.0;
  vec2 cr = corner(gl_VertexID % 6);
  vec2 pos = mix(a - dir * m, b + dir * m, cr.x) + n * mix(-m, m, cr.y);
  gl_Position = toClip(pos);
}
`,Ot=`${R}${H}
uniform vec4 u_color;
uniform float u_hw;
uniform int u_cap;
uniform vec4 u_dash;
flat in vec4 v_p0;
flat in vec4 v_p1;
flat in vec4 v_p2;
flat in vec4 v_p3;
flat in vec4 v_p4;
flat in vec4 v_p5;
out vec4 outColor;

float segDist(vec2 p, vec2 a, vec2 b) {
  vec2 ab = b - a;
  float l2 = dot(ab, ab);
  float t = l2 > 0.0 ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
  return length(p - a - t * ab);
}

bool joined(vec4 a, vec4 b) { return a.z > -0.5 && b.z > -0.5; }

// The share of a pixel at distance d from the centre line inside a line hw either side.
float across(float d) { return clamp(min(u_hw, d + 0.5) - max(-u_hw, d - 0.5), 0.0, 1.0); }

// The share of [s - 0.5, s + 0.5] inside [lo, hi].
float span(float s, float lo, float hi) { return clamp(min(s + 0.5, hi) - max(s - 0.5, lo), 0.0, 1.0); }

// The share of [s - 0.5, s + 0.5] on a dash.
float onDash(float s) {
  float period = u_dash.x + u_dash.y + u_dash.z + u_dash.w;
  float base = s - mod(s, period);
  float on = 0.0;
  for (int k = -1; k <= 1; k++) {
    float p0 = base + float(k) * period;
    on += span(s, p0, p0 + u_dash.x);
    on += span(s, p0 + u_dash.x + u_dash.y, p0 + u_dash.x + u_dash.y + u_dash.z);
  }
  return min(on, 1.0);
}

void main() {
  vec2 p = pixelCentre();
  float clipCov = clipCoverage(p);
  if (clipCov <= 0.0) discard;
  vec2 a = v_p2.xy;
  vec2 b = v_p3.xy;
  vec2 ab = b - a;
  float len = length(ab);
  vec2 dir = len > 0.0 ? ab / len : vec2(1.0, 0.0);
  float along = dot(p - a, dir);
  float perp = abs(dot(p - a, vec2(-dir.y, dir.x)));
  bool startEnd = v_p1.z < -0.5;
  bool finalEnd = v_p4.z < -0.5;

  float cov;
  if (u_dash.x + u_dash.y > 0.0) {
    cov = across(perp) * onDash(v_p2.w + along) * span(along, 0.0, len);
  } else {
    float self = segDist(p, a, b);
    float nearest = self;
    if (joined(v_p0, v_p1)) { float d = segDist(p, v_p0.xy, v_p1.xy); if (d <= self) discard; nearest = min(nearest, d); }
    if (joined(v_p1, v_p2)) { float d = segDist(p, v_p1.xy, v_p2.xy); if (d <= self) discard; nearest = min(nearest, d); }
    if (joined(v_p3, v_p4)) { float d = segDist(p, v_p3.xy, v_p4.xy); if (d < self) discard; nearest = min(nearest, d); }
    if (joined(v_p4, v_p5)) { float d = segDist(p, v_p4.xy, v_p5.xy); if (d < self) discard; nearest = min(nearest, d); }
    cov = across(nearest);
    // Past an end of the line: its cap, square-ended (butt or square) or round.
    float before = startEnd ? -along : -1e9;
    float after = finalEnd ? along - len : -1e9;
    if (u_cap != 1 && (before > -0.5 || after > -0.5)) {
      float reach = u_cap == 2 ? u_hw : 0.0;
      float lo = startEnd ? -reach : -1e9;
      float hi = finalEnd ? len + reach : 1e9;
      cov = across(perp) * span(along, lo, hi);
    }
  }
  if (cov <= 0.0) discard;
  outColor = u_color * (cov * clipCov);
}
`,Wt=`${R}${j}
in vec2 a_x;
in vec4 a_ab;
in vec2 a_ends;
flat out vec2 v_x;
flat out vec4 v_ab;
flat out vec2 v_ends;

void main() {
  v_x = a_x;
  v_ab = a_ab;
  v_ends = a_ends;
  float lo = min(min(a_ab.x, a_ab.y), min(a_ab.z, a_ab.w));
  float hi = max(max(a_ab.x, a_ab.y), max(a_ab.z, a_ab.w));
  vec2 cr = corner(gl_VertexID % 6);
  gl_Position = toClip(mix(vec2(floor(a_x.x), floor(lo) - 1.0), vec2(ceil(a_x.y), ceil(hi) + 1.0), cr));
}
`,zt=`${R}${H}
uniform int u_kind;
uniform vec4 u_color;
uniform vec4 u_line;
uniform vec4 u_offsets;
uniform int u_stops;
uniform vec4 u_stop0;
uniform vec4 u_stop1;
uniform vec4 u_stop2;
uniform vec4 u_stop3;
flat in vec2 v_x;
flat in vec4 v_ab;
flat in vec2 v_ends;
out vec4 outColor;

vec4 stopColor(int i) {
  if (i == 0) return u_stop0;
  if (i == 1) return u_stop1;
  if (i == 2) return u_stop2;
  return u_stop3;
}

vec4 gradient(vec2 p) {
  vec2 g = u_line.zw - u_line.xy;
  float l2 = dot(g, g);
  // A gradient of no length paints nothing.
  if (l2 <= 0.0) return vec4(0.0);
  float t = dot(p - u_line.xy, g) / l2;
  vec4 c = stopColor(0);
  for (int i = 1; i < 4; i++) {
    if (i >= u_stops) break;
    float o0 = u_offsets[i - 1];
    float o1 = u_offsets[i];
    if (t >= o1) c = stopColor(i);
    else if (t > o0) { c = mix(stopColor(i - 1), stopColor(i), (t - o0) / max(o1 - o0, 1e-6)); break; }
    else break;
  }
  return vec4(c.rgb * c.a, c.a);
}

void main() {
  vec2 p = pixelCentre();
  float x0 = v_x.x;
  float x1 = v_x.y;
  float left = v_ends.x > 0.5 ? clamp(p.x + 0.5 - x0, 0.0, 1.0) : (p.x >= x0 ? 1.0 : 0.0);
  float right = v_ends.y > 0.5 ? clamp(x1 - (p.x - 0.5), 0.0, 1.0) : (p.x < x1 ? 1.0 : 0.0);
  float along = v_ends.x > 0.5 && v_ends.y > 0.5
    ? clamp(min(p.x + 0.5, x1) - max(p.x - 0.5, x0), 0.0, 1.0)
    : min(left, right);
  float t = clamp((clamp(p.x, x0, x1) - x0) / max(x1 - x0, 1e-6), 0.0, 1.0);
  float ya = mix(v_ab.x, v_ab.y, t);
  float yb = mix(v_ab.z, v_ab.w, t);
  float across = clamp(min(p.y + 0.5, max(ya, yb)) - max(p.y - 0.5, min(ya, yb)), 0.0, 1.0);
  float cov = along * across * clipCoverage(p);
  if (cov <= 0.0) discard;
  vec4 color = u_kind == 1 ? gradient(p) : u_color;
  outColor = color * cov;
}
`,Ut=`${R}${j}
in vec3 a_disc;
in vec4 a_color;
flat out vec3 v_disc;
flat out vec4 v_color;
void main() {
  v_disc = a_disc;
  v_color = a_color;
  float m = a_disc.z + 1.0;
  gl_Position = toClip(mix(a_disc.xy - m, a_disc.xy + m, corner(gl_VertexID % 6)));
}
`,$t=`${R}${H}
flat in vec3 v_disc;
flat in vec4 v_color;
out vec4 outColor;
void main() {
  vec2 p = pixelCentre();
  float cov = clamp(v_disc.z + 0.5 - length(p - v_disc.xy), 0.0, 1.0) * clipCoverage(p);
  if (cov <= 0.0) discard;
  outColor = v_color * cov;
}
`,ut=4,Z=ut*4,z=32,ft=7,tt=ft*4,Yt=class{constructor(i){f(this,"stroke");f(this,"span");f(this,"disc");f(this,"buffer");this.kit=i,this.stroke=i.program(Nt,Ot,["a_p0","a_p1","a_p2","a_p3","a_p4","a_p5"]),this.span=i.program(Wt,zt,["a_x","a_ab","a_ends"]),this.disc=i.program(Ut,$t,["a_disc","a_color"]),this.buffer=i.buffer()}draw(i,e,t,r){let o=this.kit.gl;o.enable(o.BLEND);for(let s=0;s<i.length;s++){let a=i[s];if(o.blendFunc(o.ONE,o.ONE_MINUS_SRC_ALPHA),o.disable(o.SCISSOR_TEST),a.type==="rects"){let l=[a.values];for(;i[s+1]?.type==="rects";)l.push(i[++s].values);this.drawRects(l,r)}else a.type==="stroke"?this.drawStroke(a,e,t):a.type==="fill"?this.drawFill(a,e,t):this.drawDiscs(a.values,a.clip,e,t)}o.disable(o.SCISSOR_TEST)}destroy(){for(let i of[this.stroke,this.span,this.disc])this.kit.deleteProgram(i);this.kit.gl.deleteBuffer(this.buffer)}upload(i){let e=this.kit.gl;e.bindBuffer(e.ARRAY_BUFFER,this.buffer),e.bufferData(e.ARRAY_BUFFER,i,e.STREAM_DRAW)}common(i,e,t,r){let o=this.kit;return o.scissor(e.x0,e.y0,e.x1,e.y1,t,r)?(o.use(i),o.vec2(i,"u_canvas",t,r),o.vec4(i,"u_clip",[e.x0,e.y0,Math.min(e.x1,t),Math.min(e.y1,r)]),!0):!1}drawRects(i,e){let t=0;for(let s of i)t+=s.length/8;let r=new Float32Array(t*10),o=0;for(let s of i)for(let a=0;a<s.length;a+=8,o++)for(let l=0;l<8;l++)r[o*10+l]=s[a+l];e(r,t)}drawStroke(i,e,t){let r=this.stroke;if(!this.common(r,i.clip,e,t))return;let o=this.kit;o.vec4(r,"u_color",i.color),o.float(r,"u_hw",i.width/2),o.int(r,"u_cap",i.cap),o.vec4(r,"u_dash",i.dash??[0,0,0,0]),this.upload(new Float32Array(i.points));for(let a=0;a<6;a++)o.attrib(r,`a_p${a}`,4,Z,a*Z);let s=i.points.length/ut-5;s>0&&o.gl.drawArraysInstanced(o.gl.TRIANGLES,0,6,s)}drawFill(i,e,t){let r=this.kit,o=i.bounds;if(!r.scissor(o.x0,o.y0,o.x1,o.y1,e,t))return;let s=r.use(this.span);r.vec2(s,"u_canvas",e,t),r.vec4(s,"u_clip",[i.clip.x0,i.clip.y0,Math.min(i.clip.x1,e),Math.min(i.clip.y1,t)]),this.upload(new Float32Array(i.spans)),r.attrib(s,"a_x",2,z,0),r.attrib(s,"a_ab",4,z,8),r.attrib(s,"a_ends",2,z,24),this.paint(s,i.paint),r.gl.drawArraysInstanced(r.gl.TRIANGLES,0,6,i.spans.length/8)}paint(i,e){let t=this.kit;if(e.kind==="solid"){t.int(i,"u_kind",0),t.vec4(i,"u_color",e.color);return}t.int(i,"u_kind",1),t.vec4(i,"u_line",[e.x0,e.y0,e.x1,e.y1]);let r=[0,0,0,0];e.stops.forEach((o,s)=>{r[s]=o.offset}),t.vec4(i,"u_offsets",r),t.int(i,"u_stops",e.stops.length);for(let o=0;o<4;o++)t.vec4(i,`u_stop${o}`,(e.stops[o]??e.stops[e.stops.length-1]).color)}drawDiscs(i,e,t,r){let o=this.disc;this.common(o,e,t,r)&&(this.upload(new Float32Array(i)),this.kit.attrib(o,"a_disc",3,tt,0),this.kit.attrib(o,"a_color",4,tt,12),this.kit.gl.drawArraysInstanced(this.kit.gl.TRIANGLES,0,6,i.length/ft))}},et=(i,e)=>({x0:Math.max(i.x0,e.x0),y0:Math.max(i.y0,e.y0),x1:Math.min(i.x1,e.x1),y1:Math.min(i.y1,e.y1)}),pt=i=>!(i.x1>i.x0&&i.y1>i.y0);function U(i,e=0){let t=1/0,r=1/0,o=-1/0,s=-1/0;for(let a=0;a<i.length;a+=2){let l=i[a],n=i[a+1];l<t&&(t=l),l>o&&(o=l),n<r&&(r=n),n>s&&(s=n)}return{x0:t-e,y0:r-e,x1:o+e,y1:s+e}}function it(i){let e=[...i].sort((r,o)=>r.x0-o.x0),t=[];for(let r of e){for(let o=t.length-1;o>=0;o--)t[o].x1<=r.x0&&t.splice(o,1);for(let o of t)if(o.y0<r.y1&&r.y0<o.y1)return!0;t.push(r)}return!1}var $=class{constructor(i,e,t,r){f(this,"stops",[]);this.x0=i,this.y0=e,this.x1=t,this.y1=r}addColorStop(i,e){if(!(i>=0&&i<=1))throw RangeError("offset out of range");this.stops.push({offset:i,color:e})}},Y=typeof Path2D=="function"?Path2D:class{},dt=class V extends Y{constructor(t){super(t);f(this,"calls",[]);f(this,"unsupported",!1);t instanceof V?(this.calls.push(...t.calls),this.unsupported=t.unsupported):t!==void 0&&(this.unsupported=!0)}note(t,r,o=r){this.calls.push([t,r]),Y.prototype[t]?.apply(this,o)}unfollowed(t,r){this.unsupported=!0,this.note(t,[],r)}moveTo(t,r){this.note("moveTo",[t,r])}lineTo(t,r){this.note("lineTo",[t,r])}closePath(){this.note("closePath",[])}rect(t,r,o,s){this.note("rect",[t,r,o,s])}arc(t,r,o,s,a,l){this.note("arc",[t,r,o,s,a,+!!l])}quadraticCurveTo(t,r,o,s){this.note("quadraticCurveTo",[t,r,o,s])}bezierCurveTo(t,r,o,s,a,l){this.note("bezierCurveTo",[t,r,o,s,a,l])}arcTo(...t){this.unfollowed("arcTo",t)}ellipse(...t){this.unfollowed("ellipse",t)}roundRect(...t){this.unfollowed("roundRect",t)}addPath(t,r){!(t instanceof V)||r!==void 0?this.unsupported=!0:(this.calls.push(...t.calls),this.unsupported||(this.unsupported=t.unsupported)),Y.prototype.addPath?.call(this,t,r)}};function Gt(i){let e=globalThis,t=Object.prototype.hasOwnProperty.call(e,"Path2D"),r=e.Path2D;e.Path2D=dt;try{i()}finally{t?e.Path2D=r:delete e.Path2D}}var Vt=.25;function jt(i,e,t,r){if(t==="round")return!1;let o=i.points,s=o.length/2,a=+!i.closed,l=i.closed?s:s-1;for(let n=a;n<l;n++){let c=(n-1+s)%s,h=(n+1)%s,u=o[2*n]-o[2*c],p=o[2*n+1]-o[2*c+1],d=o[2*h]-o[2*n],v=o[2*h+1]-o[2*n+1],y=Math.hypot(u,p),k=Math.hypot(d,v);if(y===0||k===0)continue;let m=Math.max(-1,Math.min(1,(u*d+p*v)/(y*k))),b=Math.sqrt((1+m)/2);if((t==="miter"&&b>0&&1/b<=r?e*(1/b-1):e*(1-b))>Vt)return!0}return!1}function Ht(i,e){let t=i.points;for(let r=2;r<t.length;r+=2)if(Math.hypot(t[r]-t[r-2],t[r+1]-t[r-1])<e)return!0;return!1}function qt(i){let e=[],t=()=>e.push(0,0,-1,0);t(),t();for(let{points:r,closed:o}of i){let s=r.length/2,a=o&&s>=3;a&&e.push(r[2*(s-2)],r[2*(s-2)+1],0,0,r[2*(s-1)],r[2*(s-1)+1],0,0);let l=0;for(let n=0;n<s;n++)n>0&&(l+=Math.hypot(r[2*n]-r[2*n-2],r[2*n+1]-r[2*n-1])),e.push(r[2*n],r[2*n+1],1,l);a&&(l+=Math.hypot(r[0]-r[2*(s-1)],r[1]-r[2*(s-1)+1]),e.push(r[0],r[1],1,l),e.push(r[2],r[3],0,0,r[4],r[5],0,0)),t()}return t(),e}var g=Math.PI*2;function Kt(i,e){let t=2*Math.sqrt(Math.max(.2/Math.max(i,.1),1e-6));return Math.min(512,Math.max(4,Math.ceil(Math.abs(e)/Math.min(t,Math.PI/4))))}var rt=new Set(["fillStyle","strokeStyle","lineWidth","lineCap","lineJoin","miterLimit","globalAlpha","globalCompositeOperation","lineDashOffset","font","textAlign","textBaseline","direction","shadowBlur","shadowColor","shadowOffsetX","shadowOffsetY","filter"]),ot=new Set(["fontKerning","fontStretch","fontVariantCaps","letterSpacing","wordSpacing","textRendering"]),st=new Set(["imageSmoothingEnabled","imageSmoothingQuality"]),at=i=>!!(i.rect||i.circle)||i.points.length>=6,Xt=class{constructor(i,e){f(this,"commands",[]);f(this,"ctx");f(this,"texts",[]);f(this,"takesText",!0);f(this,"state");f(this,"stack",[]);f(this,"path",[]);f(this,"ok",!0);f(this,"stepStart",0);f(this,"solid",null);this.dpr=i,this.measure=e,this.reset({x0:0,y0:0,x1:1/0,y1:1/0}),this.ctx=this.proxy()}region(i,e){let t=this.dpr,r={x0:i.x*t,y0:i.y*t,x1:(i.x+i.width)*t,y1:(i.y+i.height)*t},o=[],s=e?.text!==!1;return{step:a=>{this.reset(r),this.texts=o,this.takesText=s;let l={commands:this.commands.length,texts:o.length};this.stepStart=l.commands,this.ok=!0;try{Gt(()=>a(this.ctx))}catch{this.ok=!1}return this.ok?!0:(this.commands.length=l.commands,o.length=l.texts,!1)},drawText:a=>Jt(a,o)}}reset(i){this.state={fillStyle:"#000000",strokeStyle:"#000000",lineWidth:1,lineCap:"butt",lineJoin:"miter",miterLimit:10,globalAlpha:1,globalCompositeOperation:"source-over",lineDash:[],lineDashOffset:0,font:"10px sans-serif",textAlign:"start",textBaseline:"alphabetic",direction:"inherit",shadowBlur:0,shadowColor:"rgba(0, 0, 0, 0)",shadowOffsetX:0,shadowOffsetY:0,filter:"none",textExtras:{},transform:[this.dpr,0,0,this.dpr,0,0],clip:i},this.stack=[],this.path=[]}unsupported(){this.ok=!1}copyState(){let i=this.state;return{...i,lineDash:[...i.lineDash],textExtras:{...i.textExtras}}}axisAligned(){let i=this.state.transform;return i[1]===0&&i[2]===0}uniform(){let i=this.state.transform;return this.axisAligned()&&Math.abs(i[0])===Math.abs(i[3])}setMatrix(i){i.every(Number.isFinite)&&(this.state.transform=i)}multiply(i,e,t,r,o,s){let[a,l,n,c,h,u]=this.state.transform;this.setMatrix([a*i+n*e,l*i+c*e,a*t+n*r,l*t+c*r,a*o+n*s+h,l*o+c*s+u])}current(){return this.path[this.path.length-1]}moveTo(i,e){if(!Number.isFinite(i)||!Number.isFinite(e))return;let t=this.state.transform;this.path.push({points:[t[0]*i+t[2]*e+t[4],t[1]*i+t[3]*e+t[5]],closed:!1})}lineTo(i,e){if(!Number.isFinite(i)||!Number.isFinite(e))return;let t=this.current();if(!t||t.closed)return this.moveTo(i,e);let r=this.state.transform;t.points.push(r[0]*i+r[2]*e+r[4],r[1]*i+r[3]*e+r[5]),t.rect=void 0,t.circle=void 0}closePath(){let i=this.current();!i||i.closed||(i.closed=!0,this.path.push({points:[i.points[0],i.points[1]],closed:!1}))}rect(i,e,t,r){if(![i,e,t,r].every(Number.isFinite))return;let o=this.state.transform,s=o[0]*i+o[2]*e+o[4],a=o[1]*i+o[3]*e+o[5],l=o[0]*(i+t)+o[2]*e+o[4],n=o[1]*(i+t)+o[3]*e+o[5],c=o[0]*(i+t)+o[2]*(e+r)+o[4],h=o[1]*(i+t)+o[3]*(e+r)+o[5],u={points:[s,a,l,n,c,h,o[0]*i+o[2]*(e+r)+o[4],o[1]*i+o[3]*(e+r)+o[5]],closed:!0};this.axisAligned()&&(u.rect={x0:Math.min(s,c),y0:Math.min(a,h),x1:Math.max(s,c),y1:Math.max(a,h)}),this.path.push(u),this.path.push({points:[s,a],closed:!1})}arc(i,e,t,r,o,s=!1){if(![i,e,t,r,o].every(Number.isFinite))return;if(t<0)throw new DOMException("negative radius","IndexSizeError");let a=o-r;a=!s&&a>=g?g:s&&-a>=g?-g:s?-(((r-o)%g+g)%g):(a%g+g)%g;let l=this.current(),n=this.state.transform,c=i+t*Math.cos(r),h=e+t*Math.sin(r),u=!l||l.closed||l.points.length===2&&Math.abs(l.points[0]-(n[0]*c+n[2]*h+n[4]))<1e-6&&Math.abs(l.points[1]-(n[1]*c+n[3]*h+n[5]))<1e-6,p=Kt(t*Math.abs(n[0]),a);for(let v=0;v<=p;v++){let y=r+a*v/p;this.lineTo(i+t*Math.cos(y),e+t*Math.sin(y))}let d=this.current();Math.abs(a)>=g-1e-9&&u&&this.uniform()&&d&&(d.circle={x:n[0]*i+n[4],y:n[3]*e+n[5],r:t*Math.abs(n[0])})}curve(i,e){(!this.current()||this.current().closed)&&this.moveTo(i[0],i[1]);let t=this.current(),r=this.state.transform;if(!t||!this.axisAligned()||r[0]===0||r[3]===0)return this.unsupported();let o=[(t.points[t.points.length-2]-r[4])/r[0],(t.points[t.points.length-1]-r[5])/r[3],...i,...e],s=0;for(let l=2;l<o.length;l+=2)s+=Math.hypot((o[l]-o[l-2])*r[0],(o[l+1]-o[l-1])*r[3]);let a=Math.max(4,Math.min(64,Math.ceil(s/3)));for(let l=1;l<=a;l++){let n=l/a,c=o.length===6?[(1-n)**2,2*n*(1-n),n*n]:[(1-n)**3,3*n*(1-n)**2,3*n*n*(1-n),n**3],h=0,u=0;c.forEach((p,d)=>{h+=p*o[2*d],u+=p*o[2*d+1]}),this.lineTo(h,u)}}withPath(i,e){let t=this.path;this.path=[],i(),e(),this.path=t}onPath(i,e){if(!(i instanceof dt)||i.unsupported)return this.unsupported();this.withPath(()=>{for(let[t,r]of i.calls)t==="moveTo"?this.moveTo(r[0],r[1]):t==="lineTo"?this.lineTo(r[0],r[1]):t==="closePath"?this.closePath():t==="rect"?this.rect(r[0],r[1],r[2],r[3]):t==="arc"?this.arc(r[0],r[1],r[2],r[3],r[4],!!r[5]):t==="quadraticCurveTo"?this.curve([r[0],r[1]],[r[2],r[3]]):t==="bezierCurveTo"&&this.curve([r[0],r[1],r[2],r[3]],[r[4],r[5]])},e)}baseColor(i){let e=this.solid;if(e&&e.style===i)return e.color;let t=w(x(i));return this.solid={style:i,color:t},t}alpha(){return Math.max(0,Math.min(1,this.state.globalAlpha))}solidColor(i){let e=this.baseColor(i),t=this.alpha();return[e[0]*t,e[1]*t,e[2]*t,e[3]*t]}paint(i){let e=this.alpha();if(typeof i=="string")return{kind:"solid",color:this.solidColor(i)};if(!(i instanceof $))return null;if(i.stops.length===0)return{kind:"solid",color:[0,0,0,0]};if(i.stops.length>4)return null;let t=this.state.transform,r=i.x0===i.x1||i.y0===i.y1;if(!this.axisAligned()||!this.uniform()&&!r)return null;let o=[...i.stops].sort((s,a)=>s.offset-a.offset).map(s=>{let a=x(s.color);return{offset:s.offset,color:[a[0],a[1],a[2],a[3]*e]}});return{kind:"linear",x0:t[0]*i.x0+t[4],y0:t[3]*i.y0+t[5],x1:t[0]*i.x1+t[4],y1:t[3]*i.y1+t[5],stops:o}}plain(){let i=this.state;return i.globalCompositeOperation!=="source-over"||i.filter!=="none"?!1:i.shadowBlur===0&&i.shadowOffsetX===0&&i.shadowOffsetY===0?!0:!(x(i.shadowColor)[3]>0)}fill(i="nonzero"){if(!this.plain())return this.unsupported();let e=this.paint(this.state.fillStyle);if(!e)return this.unsupported();let t=this.path.filter(at);if(t.length===0||e.kind==="solid"&&e.color[3]===0)return;if(t.length>1&&it(t.map(a=>U(a.points)))){let a=e.kind==="solid"&&e.color[3]>=1,l=Math.sign(X(t[0].points));if(!a||i!=="nonzero"||t.some(n=>Math.sign(X(n.points))!==l))return this.unsupported()}if(e.kind==="solid"&&t.every(a=>a.rect))return this.fillRects(t,e.color);if(e.kind==="solid"&&t.every(a=>a.circle)){let a=[];for(let l of t)a.push(l.circle.x,l.circle.y,l.circle.r,...e.color);this.commands.push({type:"circles",values:a,clip:this.state.clip});return}let r=[];for(let a of t){let l=It(a.points);if(!l)return this.unsupported();for(let n of l)r.push(n)}let o=U(t.flatMap(a=>a.points)),s=et({x0:Math.floor(o.x0),y0:Math.floor(o.y0),x1:Math.ceil(o.x1),y1:Math.ceil(o.y1)},this.state.clip);r.length>0&&!pt(s)&&this.commands.push({type:"fill",spans:r,bounds:s,paint:e,clip:this.state.clip})}fillRects(i,e){for(let t of i)this.pushRect(t.rect,e)}pushRect(i,e,t=1){let r=this.state.clip,o=Math.max(i.x0,r.x0),s=Math.max(i.y0,r.y0),a=Math.min(i.x1,r.x1),l=Math.min(i.y1,r.y1);if(!(a>o&&l>s))return;let n=this.commands[this.commands.length-1],c=n&&n.type==="rects"&&this.commands.length>this.stepStart?n.values:null,h=e[0]*t,u=e[1]*t,p=e[2]*t,d=e[3]*t;c?c.push(o,s,a,l,h,u,p,d):this.commands.push({type:"rects",values:[o,s,a,l,h,u,p,d]})}fillRect(i,e,t,r){let o=this.state.fillStyle;if(typeof o!="string"||!this.axisAligned()||!this.plain())return this.withPath(()=>this.rect(i,e,t,r),()=>this.fill());if(!(Number.isFinite(i)&&Number.isFinite(e)&&Number.isFinite(t)&&Number.isFinite(r)))return;let s=this.baseColor(o),a=this.alpha();if(s[3]*a===0)return;let l=this.state.transform,n=l[0]*i+l[4],c=l[0]*(i+t)+l[4],h=l[3]*e+l[5],u=l[3]*(e+r)+l[5];this.pushRect({x0:Math.min(n,c),y0:Math.min(h,u),x1:Math.max(n,c),y1:Math.max(h,u)},s,a)}stroke(){if(!this.plain())return this.unsupported();let i=this.paint(this.state.strokeStyle);if(!i||i.kind!=="solid"||!this.uniform())return this.unsupported();if(i.color[3]===0)return;let e=this.state,t=Math.abs(e.transform[0]),r=e.lineWidth*t,o=this.path.filter(l=>l.points.length>=4&&(e.lineCap!=="butt"||l.points.some((n,c)=>n!==l.points[c%2])));if(o.length===0)return;let s=this.dash(o,t);if(s===void 0||!this.drawsAlike(o,r,i.color[3]))return this.unsupported();let a=e.lineCap==="round"?1:e.lineCap==="square"?2:0;this.commands.push({type:"stroke",points:qt(o),color:i.color,width:r,cap:a,dash:s,clip:e.clip})}dash(i,e){let t=this.state;if(t.lineDash.length===0)return null;if(t.lineDash.length>4||t.lineDashOffset!==0||t.lineCap!=="butt"||i.some(o=>o.closed||o.points.length!==4))return;let r=t.lineDash.map(o=>o*e);for(;r.length<4;)r.push(...r.slice(0,4-r.length));return r}drawsAlike(i,e,t){let r=this.state,o=e/2;if(e>1&&i.some(a=>jt(a,o,r.lineJoin,r.miterLimit)))return!1;let s=o+(r.lineCap==="butt"?0:o);return!(i.length>1&&it(i.map(a=>U(a.points,s)))||t<1&&i.some(a=>Ht(a,e)))}clip(){let i=this.path.filter(at);if(i.length!==1||!i[0].rect)return this.unsupported();this.state.clip=et(this.state.clip,i[0].rect)}text(i,e,t,r,o){let s=i?this.state.strokeStyle:this.state.fillStyle;if(!this.takesText||typeof s!="string"||!this.plain())return this.unsupported();this.texts.push({stroke:i,text:String(e),x:t,y:r,maxWidth:o,state:this.copyState()})}measureText(i){let e=this.measure;if(!e)return{width:String(i).length*6};let t=e.font;e.font=this.state.font;let r=e.measureText(i);return e.font=t,r}methods(){let i=()=>this.state,e=Object.create(null);return Object.assign(e,{save:()=>{this.stack.push(this.copyState())},restore:()=>{let t=this.stack.pop();t&&(this.state=t)},beginPath:()=>{this.path=[]},moveTo:(t,r)=>this.moveTo(t,r),lineTo:(t,r)=>this.lineTo(t,r),closePath:()=>this.closePath(),rect:(t,r,o,s)=>this.rect(t,r,o,s),arc:(t,r,o,s,a,l)=>this.arc(t,r,o,s,a,l),quadraticCurveTo:(t,r,o,s)=>this.curve([t,r],[o,s]),bezierCurveTo:(t,r,o,s,a,l)=>this.curve([t,r,o,s],[a,l]),fill:(t,r)=>typeof t=="object"?this.onPath(t,()=>this.fill(r)):this.fill(t),stroke:t=>t?this.onPath(t,()=>this.stroke()):this.stroke(),clip:t=>typeof t=="object"?this.onPath(t,()=>this.clip()):this.clip(),fillRect:(t,r,o,s)=>this.fillRect(t,r,o,s),strokeRect:(t,r,o,s)=>this.withPath(()=>this.rect(t,r,o,s),()=>this.stroke()),fillText:(t,r,o,s)=>this.text(!1,t,r,o,s),strokeText:(t,r,o,s)=>this.text(!0,t,r,o,s),measureText:t=>this.measureText(t),setLineDash:t=>{t.every(r=>Number.isFinite(r)&&r>=0)&&(i().lineDash=t.length%2?[...t,...t]:[...t])},getLineDash:()=>[...i().lineDash],translate:(t,r)=>this.multiply(1,0,0,1,t,r),scale:(t,r)=>this.multiply(t,0,0,r,0,0),rotate:t=>this.multiply(Math.cos(t),Math.sin(t),-Math.sin(t),Math.cos(t),0,0),transform:(t,r,o,s,a,l)=>this.multiply(t,r,o,s,a,l),setTransform:(t,r,o,s,a,l)=>typeof t=="number"?this.setMatrix([t,r??0,o??0,s??1,a??0,l??0]):this.unsupported(),resetTransform:()=>this.setMatrix([1,0,0,1,0,0]),getTransform:()=>{let[t,r,o,s,a,l]=i().transform;return{a:t,b:r,c:o,d:s,e:a,f:l,m11:t,m12:r,m21:o,m22:s,m41:a,m42:l,is2D:!0,isIdentity:t===1&&r===0&&o===0&&s===1&&a===0&&l===0}},createLinearGradient:(t,r,o,s)=>new $(t,r,o,s)}),e}proxy(){let i=this.methods();return new Proxy({},{get:(e,t)=>{if(typeof t=="string"){if(t in i)return i[t];if(rt.has(t))return this.state[t];if(ot.has(t))return this.state.textExtras[t];if(t==="canvas")return this.measure?.canvas;if(!st.has(t))return this.unsupported(),()=>{}}},set:(e,t,r)=>(typeof t=="string"&&this.setProp(t,r),!0)})}setProp(i,e){let t=this.state;i==="lineWidth"||i==="miterLimit"?typeof e=="number"&&Number.isFinite(e)&&e>0&&(t[i]=e):i==="globalAlpha"?typeof e=="number"&&Number.isFinite(e)&&e>=0&&e<=1&&(t.globalAlpha=e):i==="fillStyle"||i==="strokeStyle"?e instanceof $?t[i]=e:typeof e=="string"?ct(e)&&(t[i]=e):this.unsupported():rt.has(i)?t[i]=e:ot.has(i)?this.state.textExtras[i]=e:st.has(i)||this.unsupported()}};function Jt(i,e){for(let t of e){let r=t.state;if(pt(r.clip))continue;i.save(),i.setTransform(1,0,0,1,0,0),Number.isFinite(r.clip.x1)&&Number.isFinite(r.clip.y1)&&(i.beginPath(),i.rect(r.clip.x0,r.clip.y0,r.clip.x1-r.clip.x0,r.clip.y1-r.clip.y0),i.clip());let[o,s,a,l,n,c]=r.transform;i.setTransform(o,s,a,l,n,c),i.font=r.font,i.textAlign=r.textAlign,i.textBaseline=r.textBaseline,i.direction=r.direction,i.globalAlpha=r.globalAlpha,Object.assign(i,r.textExtras),t.stroke?(i.strokeStyle=r.strokeStyle,i.lineWidth=r.lineWidth,i.strokeText(t.text,t.x,t.y,t.maxWidth)):(i.fillStyle=r.fillStyle,i.fillText(t.text,t.x,t.y,t.maxWidth)),i.restore()}}function Qt(i,e){return new Xt(i,e)}var T=`#version 300 es
precision highp float;
uniform vec2 u_canvas;
uniform float u_dpr;
uniform int u_log;
uniform int u_invert;
uniform float u_yA;
uniform float u_yB;
uniform float u_logOffset;
uniform float u_min;
uniform float u_logFloor;
uniform float u_logK;
uniform float u_top;
uniform float u_bottom;
out vec4 v_color;

// A price (relative to the base price) to a CSS-pixel y, as priceToYMapper
// does; mappedY in yMapping.ts is the same steps in TypeScript.
float cssY(float rel) {
  if (u_log == 1) {
    float v = log(max(1.0 + (rel + u_logOffset) / u_min, u_logFloor)) * u_logK;
    return u_invert == 1 ? u_top + v : u_bottom - v;
  }
  return u_yA + rel * u_yB;
}

float snap(float v) { return floor(v + ${Bt.toFixed(4)}); }

vec4 toClip(vec2 dev) {
  return vec4(dev.x / u_canvas.x * 2.0 - 1.0, 1.0 - dev.y / u_canvas.y * 2.0, 0.0, 1.0);
}

// The corners of a quad as two triangles.
vec2 corner(int k) {
  if (k == 0) return vec2(0.0, 0.0);
  if (k == 1 || k == 4) return vec2(1.0, 0.0);
  if (k == 2 || k == 3) return vec2(0.0, 1.0);
  return vec2(1.0, 1.0);
}

// Nothing to draw: every vertex at one point off the canvas.
const vec4 NOWHERE = vec4(-2.0, -2.0, 0.0, 1.0);
`,Zt=`${T}
in vec4 a_ohlc;
in vec2 a_vd;
uniform float u_x0;
uniform float u_unit;
uniform float u_wick;
uniform float u_body;
uniform vec4 u_upBody;
uniform vec4 u_downBody;
uniform vec4 u_upWick;
uniform vec4 u_downWick;

void main() {
  int vid = gl_VertexID % 12;
  vec2 cr = corner(vid % 6);
  bool up = a_vd.y > 0.5;
  float cx = (u_x0 + float(gl_InstanceID) * u_unit) * u_dpr;
  float wickLeft = snap(cx - u_wick * 0.5);
  float left;
  float width;
  float top;
  float height;
  if (vid < 6) {
    float h = snap(cssY(a_ohlc.y) * u_dpr);
    float l = snap(cssY(a_ohlc.z) * u_dpr);
    left = wickLeft;
    width = u_wick;
    top = min(h, l);
    height = max(abs(l - h), 1.0);
    v_color = up ? u_upWick : u_downWick;
  } else {
    float o = snap(cssY(a_ohlc.x) * u_dpr);
    float c = snap(cssY(a_ohlc.w) * u_dpr);
    left = wickLeft - (u_body - u_wick) * 0.5;
    width = u_body;
    top = min(o, c);
    height = max(abs(c - o), u_wick);
    v_color = up ? u_upBody : u_downBody;
  }
  gl_Position = toClip(vec2(left + cr.x * width, top + cr.y * height));
}
`,te=`${T}
in vec4 a_ohlc;
in vec2 a_vd;
uniform float u_x0;
uniform float u_unit;
uniform float u_wick;
uniform float u_body;
uniform float u_volBottom;
uniform float u_volScale;
uniform vec4 u_volUp;
uniform vec4 u_volDown;

void main() {
  vec2 cr = corner(gl_VertexID % 6);
  float cx = (u_x0 + float(gl_InstanceID) * u_unit) * u_dpr;
  float left = snap(cx - u_wick * 0.5) - (u_body - u_wick) * 0.5;
  float bottom = snap(u_volBottom * u_dpr);
  float top = snap((u_volBottom - a_vd.x * u_volScale) * u_dpr);
  if (bottom - top < 1.0) { gl_Position = NOWHERE; v_color = vec4(0.0); return; }
  v_color = a_vd.y > 0.5 ? u_volUp : u_volDown;
  gl_Position = toClip(vec2(left + cr.x * u_body, top + cr.y * (bottom - top)));
}
`,ee=`${T}
in vec4 a_col;
in float a_up;
uniform vec4 u_upBody;
uniform vec4 u_downBody;

void main() {
  vec2 cr = corner(gl_VertexID % 6);
  float left = snap(a_col.x * u_dpr);
  float width = max(1.0, snap((a_col.x + 1.0) * u_dpr) - left);
  float t = snap(cssY(a_col.y) * u_dpr);
  float b = snap(cssY(a_col.z) * u_dpr);
  v_color = a_up > 0.5 ? u_upBody : u_downBody;
  gl_Position = toClip(vec2(left + cr.x * width, min(t, b) + cr.y * max(abs(b - t), 1.0)));
}
`,ie=`${T}
in vec4 a_col;
in float a_up;
uniform float u_volBottom;
uniform float u_volScale;
uniform vec4 u_volUp;
uniform vec4 u_volDown;

void main() {
  vec2 cr = corner(gl_VertexID % 6);
  float left = snap(a_col.x * u_dpr);
  float width = max(1.0, snap((a_col.x + 1.0) * u_dpr) - left);
  float bottom = snap(u_volBottom * u_dpr);
  float top = snap((u_volBottom - a_col.w * u_volScale) * u_dpr);
  if (bottom - top < 1.0) { gl_Position = NOWHERE; v_color = vec4(0.0); return; }
  v_color = a_up > 0.5 ? u_volUp : u_volDown;
  gl_Position = toClip(vec2(left + cr.x * width, top + cr.y * (bottom - top)));
}
`,re=`${T}
in vec4 a_rect;
in vec4 a_color;
in vec2 a_dash;
flat out vec4 v_rect;
flat out vec2 v_dash;

void main() {
  vec2 cr = corner(gl_VertexID % 6);
  v_rect = a_rect * u_dpr;
  v_dash = a_dash * u_dpr;
  v_color = a_color;
  gl_Position = toClip(mix(floor(v_rect.xy), ceil(v_rect.zw), cr));
}
`,oe=`#version 300 es
precision highp float;
uniform vec2 u_canvas;
uniform int u_union;
in vec4 v_color;
flat in vec4 v_rect;
flat in vec2 v_dash;
out vec4 outColor;

// The share of rows [y, y + 1] inside the rectangle and, dashed, on a dash.
float rows(float y) {
  float lo = max(y, v_rect.y);
  float hi = min(y + 1.0, v_rect.w);
  if (hi <= lo) return 0.0;
  if (v_dash.x <= 0.0) return hi - lo;
  // A dash period is longer than a device pixel, so the row meets the dash
  // of the period it starts in and the next (a third to spare).
  float period = v_dash.x + v_dash.y;
  float first = v_rect.y + floor((lo - v_rect.y) / period) * period;
  float on = 0.0;
  for (int i = 0; i < 3; i++) {
    float start = first + float(i) * period;
    on += max(0.0, min(hi, start + v_dash.x) - max(lo, start));
  }
  return on;
}

void main() {
  // This pixel's top-left corner in device pixels, y down.
  vec2 p = vec2(floor(gl_FragCoord.x), u_canvas.y - floor(gl_FragCoord.y) - 1.0);
  float coverage = clamp(min(p.x + 1.0, v_rect.z) - max(p.x, v_rect.x), 0.0, 1.0) * rows(p.y);
  outColor = u_union == 1 ? vec4(v_color.rgb * coverage, coverage) : v_color * coverage;
}
`,L=`#version 300 es
precision highp float;
uniform vec2 u_canvas;
uniform vec4 u_clip;
in vec4 v_color;
out vec4 outColor;

void main() {
  vec2 p = vec2(floor(gl_FragCoord.x), u_canvas.y - floor(gl_FragCoord.y) - 1.0);
  vec2 c = clamp(min(p + 1.0, u_clip.zw) - max(p, u_clip.xy), 0.0, 1.0);
  outColor = v_color * (c.x * c.y);
}
`,A=24,B=5,lt=B*4,O=10,S=O*4,N=()=>{},M=["a_ohlc","a_vd","a_col","a_up","a_rect","a_color","a_dash"],ne=class vt{constructor(e,t){f(this,"label");f(this,"gl");f(this,"kit");f(this,"drawer");f(this,"candleBars");f(this,"volumeBars");f(this,"candleColumns");f(this,"volumeColumns");f(this,"rects");f(this,"seriesBuffer");f(this,"columnBuffer");f(this,"rectBuffer");f(this,"uploads",new K);f(this,"gpuFloats",0);f(this,"columns",new Float32Array(4096*B));f(this,"rectValues",new Float32Array(64*O));f(this,"clip",[0,0,0,0]);f(this,"lost",!1);f(this,"lostCallback",null);f(this,"restoredCallback",null);f(this,"release",N);f(this,"handleLost",e=>{e.preventDefault(),!this.lost&&(this.lost=!0,this.release(),this.release=N,this.lostCallback?.())});f(this,"handleRestored",()=>{if(!this.lost||this.gl.isContextLost())return;let e=St();if(!e){E(this.gl);return}try{this.build()}catch(t){e(),G(t),E(this.gl);return}this.release=e,this.lost=!1,this.restoredCallback?.()});this.canvas=e,this.gl=t,this.kit=new Pt(t),this.label=se(t),this.build(),e.addEventListener("webglcontextlost",this.handleLost),e.addEventListener("webglcontextrestored",this.handleRestored)}static create(e={}){if(typeof document>"u")return null;let t=document.createElement("canvas"),r=null;try{r=t.getContext("webgl2",{alpha:!0,premultipliedAlpha:!0,antialias:!1,depth:!1,stencil:!1,preserveDrawingBuffer:!1,failIfMajorPerformanceCaveat:e.failIfMajorPerformanceCaveat??!1})}catch(o){return G(o),null}if(!r)return null;try{let o=new vt(t,r);return o.release=e.release??N,o}catch(o){return G(o),E(r),null}}build(){let e=this.kit;Object.assign(this,{candleBars:e.program(Zt,L,M),volumeBars:e.program(te,L,M),candleColumns:e.program(ee,L,M),volumeColumns:e.program(ie,L,M),rects:e.program(re,oe,M),seriesBuffer:e.buffer(),columnBuffer:e.buffer(),rectBuffer:e.buffer(),drawer:new Yt(e),uploads:new K,gpuFloats:0})}onRestored(e){this.restoredCallback=e}onLost(e){this.lostCallback=e,(this.lost||this.gl.isContextLost())&&(this.lost=!0,queueMicrotask(()=>{this.lostCallback===e&&e()}))}recorder(e,t){return Qt(e,t)}render(e){let t=this.gl;if(this.lost||t.isContextLost())return{series:!1,volume:!1,background:!1,recorded:!1,under:!1};let r=nt(e.recorded)?e.recorded:null,o=nt(e.under)?e.under:null,s={series:e.candles,volume:e.volume!==null,background:e.background!==null,recorded:r!==null,under:o!==null};return t.viewport(0,0,this.canvas.width,this.canvas.height),t.disable(t.SCISSOR_TEST),t.clearColor(0,0,0,0),t.clear(t.COLOR_BUFFER_BIT),t.enable(t.BLEND),e.background&&this.drawBackground(e,e.background),o&&this.drawRecorded(e,o),this.drawSeries(e),r&&this.drawRecorded(e,r),s}drawSeries(e){let t=this.gl,{data:r,viewport:o,dpr:s}=e;if(r.length===0||!e.candles&&!e.volume)return;this.syncSeries(e);let a=Math.max(0,o.visibleRange.from),l=Math.min(o.visibleRange.to,r.length-1);if(l<a)return;let{chartRect:n}=o;this.clip=[n.x*s,n.y*s,(n.x+n.width)*s,(n.y+n.height)*s];let c=Math.floor(this.clip[0]),h=Math.floor(this.clip[1]),u=Math.ceil(this.clip[2])-c,p=Math.ceil(this.clip[3])-h;t.enable(t.SCISSOR_TEST),t.scissor(c,this.canvas.height-h-p,Math.max(0,u),Math.max(0,p)),t.blendFunc(t.ONE,t.ONE_MINUS_SRC_ALPHA);let d=kt(o),v=d?this.buildColumns(e,a,l):0;e.volume&&this.drawVolume(e,a,l,d,v);let{min:y,max:k}=o.priceRange;e.candles&&k-y!==0&&this.drawCandles(e,a,l,d,v),t.disable(t.SCISSOR_TEST)}drawRecorded(e,t){t.commands.length!==0&&this.drawer.draw(t.commands,this.canvas.width,this.canvas.height,(r,o)=>this.drawRecordedRects(e,r,o))}drawRecordedRects(e,t,r){let o=this.gl,s=this.use(this.rects,e);this.kit.float(s,"u_dpr",1),this.kit.int(s,"u_union",0),o.bindBuffer(o.ARRAY_BUFFER,this.rectBuffer),o.bufferData(o.ARRAY_BUFFER,t,o.STREAM_DRAW),this.bindRects(s,0),o.drawArraysInstanced(o.TRIANGLES,0,6,r)}destroy(){this.canvas.removeEventListener("webglcontextlost",this.handleLost),this.canvas.removeEventListener("webglcontextrestored",this.handleRestored),this.lostCallback=null,this.restoredCallback=null,this.release(),this.release=N;let e=this.gl;if(e.isContextLost())this.canvas.addEventListener("webglcontextrestored",()=>E(e),{once:!0});else{for(let t of[this.candleBars,this.volumeBars,this.candleColumns,this.volumeColumns,this.rects])this.kit.deleteProgram(t);this.drawer.destroy(),e.deleteBuffer(this.seriesBuffer),e.deleteBuffer(this.columnBuffer),e.deleteBuffer(this.rectBuffer),E(e)}this.canvas.remove()}syncSeries(e){let t=this.gl,r=this.uploads.sync(e.data,e.seriesRevision),o=this.uploads.values;t.bindBuffer(t.ARRAY_BUFFER,this.seriesBuffer),r.full||o.length!==this.gpuFloats?(t.bufferData(t.ARRAY_BUFFER,o,t.DYNAMIC_DRAW),this.gpuFloats=o.length):r.to>r.from&&t.bufferSubData(t.ARRAY_BUFFER,r.from*A,o,r.from*6,(r.to-r.from)*6)}buildColumns(e,t,r){let{viewport:o,data:s}=e,a=o.barWidth+o.barSpacing,l=-o.offset+o.chartRect.x+o.barWidth/2,n=this.uploads.base,c=0;Rt(s,t,r,u=>u*a+l,u=>{if((c+1)*B>this.columns.length){let d=new Float32Array(this.columns.length*2);d.set(this.columns),this.columns=d}let p=c*B;this.columns[p]=u.x,this.columns[p+1]=u.high-n,this.columns[p+2]=u.low-n,this.columns[p+3]=u.volume,this.columns[p+4]=+(u.close>=u.open),c++});let h=this.gl;return h.bindBuffer(h.ARRAY_BUFFER,this.columnBuffer),h.bufferData(h.ARRAY_BUFFER,this.columns.subarray(0,c*B),h.STREAM_DRAW),c}drawBackground(e,t){let{viewport:r,theme:o}=e,s=Ct(o),a=t.grid?At(r,t.marks):{horizontal:[],vertical:[]},l={horizontal:s.horizontal.visible?a.horizontal:[],vertical:s.vertical.visible?a.vertical:[]},n=l.horizontal.length+l.vertical.length,c=n+t.rects.length;if(c===0)return;this.rectValues.length<c*O&&(this.rectValues=new Float32Array(c*O*2));let h=this.rectValues,u=0,p=(_,mt,_t,gt,xt,yt,F)=>{h[u++]=_,h[u++]=mt,h[u++]=_t,h[u++]=gt;for(let W=0;W<4;W++)h[u++]=xt[W]*yt;h[u++]=F?F[0]:0,h[u++]=F?F[1]:0},d=w(x(s.horizontal.visible?s.horizontal.color:s.vertical.color)),{chartRect:v}=r;for(let _ of l.horizontal)p(v.x,_-.5,v.x+v.width,_+.5,d,1);for(let _ of l.vertical)p(_-.5,v.y,_+.5,v.y+v.height,d,1);let y="",k=d;for(let _ of t.rects)_.color!==y&&(y=_.color,k=w(x(_.color))),p(_.x,_.y,_.x+_.width,_.y+_.height,k,_.alpha,_.dash);let m=this.gl,b=this.use(this.rects,e);m.bindBuffer(m.ARRAY_BUFFER,this.rectBuffer),m.bufferData(m.ARRAY_BUFFER,h.subarray(0,u),m.STREAM_DRAW),n>0&&(m.uniform1i(this.loc(b,"u_union"),1),m.blendColor(0,0,0,d[3]),m.blendFuncSeparate(m.ONE,m.ONE_MINUS_SRC_ALPHA,m.CONSTANT_ALPHA,m.ONE_MINUS_SRC_ALPHA),this.bindRects(b,0),m.drawArraysInstanced(m.TRIANGLES,0,6,n)),t.rects.length>0&&(m.uniform1i(this.loc(b,"u_union"),0),m.blendFunc(m.ONE,m.ONE_MINUS_SRC_ALPHA),this.bindRects(b,n),m.drawArraysInstanced(m.TRIANGLES,0,6,t.rects.length))}drawCandles(e,t,r,o,s){let{theme:a,viewport:l,dpr:n}=e,c=w(x(a.candleUp)),h=w(x(a.candleDown));if(o){let p=this.use(this.candleColumns,e);this.vec4(p,"u_upBody",c),this.vec4(p,"u_downBody",h),this.bindColumns(p),this.gl.drawArraysInstanced(this.gl.TRIANGLES,0,6,s);return}let u=this.use(this.candleBars,e);this.barUniforms(u,l,t,n),this.vec4(u,"u_upBody",c),this.vec4(u,"u_downBody",h),this.vec4(u,"u_upWick",w(x(a.candleUpWick))),this.vec4(u,"u_downWick",w(x(a.candleDownWick))),this.bindBars(u,t),this.gl.drawArraysInstanced(this.gl.TRIANGLES,0,12,r-t+1)}drawVolume(e,t,r,o,s){let{data:a,viewport:l,theme:n,dpr:c}=e,h=0;for(let v=t;v<=r;v++)a[v].volume>h&&(h=a[v].volume);if(h===0)return;let{chartRect:u}=l,p=Mt(n),d=this.use(o?this.volumeColumns:this.volumeBars,e);if(this.float(d,"u_volBottom",u.y+u.height),this.float(d,"u_volScale",u.height*(e.volume?.heightRatio??.15)/h),this.vec4(d,"u_volUp",w(x(p.up))),this.vec4(d,"u_volDown",w(x(p.down))),o){this.bindColumns(d),this.gl.drawArraysInstanced(this.gl.TRIANGLES,0,6,s);return}this.barUniforms(d,l,t,c),this.bindBars(d,t),this.gl.drawArraysInstanced(this.gl.TRIANGLES,0,6,r-t+1)}barUniforms(e,t,r,o){let s=t.barWidth+t.barSpacing,a=-t.offset+t.chartRect.x+t.barWidth/2,{body:l,wick:n}=Et(t.barWidth,o);this.float(e,"u_x0",r*s+a),this.float(e,"u_unit",s),this.float(e,"u_wick",n),this.float(e,"u_body",l)}use(e,t){let r=this.gl;this.kit.use(e),r.uniform2f(this.loc(e,"u_canvas"),this.canvas.width,this.canvas.height),this.vec4(e,"u_clip",this.clip),this.float(e,"u_dpr",t.dpr);let o=Dt(t.viewport,this.uploads.base);return r.uniform1i(this.loc(e,"u_log"),o.log),r.uniform1i(this.loc(e,"u_invert"),o.invert),this.float(e,"u_yA",o.yA),this.float(e,"u_yB",o.yB),this.float(e,"u_logOffset",o.logOffset),this.float(e,"u_min",o.min),this.float(e,"u_logFloor",o.logFloor),this.float(e,"u_logK",o.logK),this.float(e,"u_top",o.top),this.float(e,"u_bottom",o.bottom),e}bindBars(e,t){let r=this.gl;r.bindBuffer(r.ARRAY_BUFFER,this.seriesBuffer),this.attrib(e,"a_ohlc",4,A,t*A),this.attrib(e,"a_vd",2,A,t*A+16)}bindRects(e,t){this.attrib(e,"a_rect",4,S,t*S),this.attrib(e,"a_color",4,S,t*S+16),this.attrib(e,"a_dash",2,S,t*S+32)}bindColumns(e){let t=this.gl;t.bindBuffer(t.ARRAY_BUFFER,this.columnBuffer),this.attrib(e,"a_col",4,lt,0),this.attrib(e,"a_up",1,lt,16)}attrib(e,t,r,o,s){this.kit.attrib(e,t,r,o,s)}float(e,t,r){this.kit.float(e,t,r)}vec4(e,t,r){this.kit.vec4(e,t,r)}loc(e,t){return this.kit.loc(e,t)}};function nt(i){return typeof i=="object"&&!!i&&Array.isArray(i.commands)}function se(i){let e=String(i.getParameter(i.RENDERER));if(e&&e!=="WebKit WebGL")return e;let t=i.getExtension("WEBGL_debug_renderer_info");return t?String(i.getParameter(t.UNMASKED_RENDERER_WEBGL)):e}function E(i){i.getExtension("WEBGL_lose_context")?.loseContext()}function G(i){console.warn("TradeCanvas: WebGL renderer unavailable, drawing with Canvas 2D.",i)}export{ne as WebGLSeriesRenderer};
