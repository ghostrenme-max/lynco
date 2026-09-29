// Analytic, texture-free flame. A three-second cycle makes deterministic capture possible.
uniform float flame_time = 0.0;
uniform vec4 outer_color : source_color = vec4(1.0, 0.36, 0.055, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.53, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.10;
uniform float wiggle_strength : hint_range(0.0, 2.0) = 1.0;
uniform float core_size : hint_range(0.3, 0.9) = 0.72;

float centerline(float h, float a) {
	// Layered wiggle: slow body sway, faster tip flutter. All phases loop exactly.
	float wiggle = 0.022*sin(5.0*a-h*8.0)+0.012*sin(9.0*a+h*11.0+1.7);
	return 0.13 * sin(a - h * 5.8) * h + 0.075 * sin(2.0 * a + h * 3.4) * h * h + wiggle*wiggle_strength*h;
}

float body_field(vec2 p, float a) {
	float top = 0.78 + 0.055 * sin(a) + 0.026 * sin(2.0*a) + 0.014*sin(a*7.0)*wiggle_strength;
	float bottom = 0.055;
	float h = (p.y-bottom)/(top-bottom);
	float belly = 0.225*(1.0+0.045*sin(2.0*a));
	float width;
	if (h < 0.32) {
		float q = (h-0.32)/0.32;
		width = belly*sqrt(max(0.0,1.0-q*q));
	} else {
		width = belly*pow(max(0.0,(1.0-h)/0.68),0.78);
	}
	width *= 1.0+0.06*sin(a*2.0-h*7.0)*smoothstep(0.25,0.6,h);
	width *= 1.0+0.035*sin(a*6.0-h*12.0)*wiggle_strength*smoothstep(0.25,0.6,h);
	float cx = centerline(h,a);
	// Rounded closed lower bulb, broad belly, and curling upper tip.
	cx += 0.09 * sin(a + 1.3) * smoothstep(0.68,1.0,h);
	float d = max(abs(p.x-cx)-width, p.y-top);
	d = max(d, bottom-p.y);
	// Hollow scallops climb both edges and create long hooked flame tongues.
	for (int i=0; i<3; i++) {
		float fi = float(i);
		float life = fract(a/6.28318530718 + fi/3.0);
		float y = 0.31 + life*0.62;
		float side = i==1 ? 1.0 : -1.0;
		float hh = (y-bottom)/(top-bottom);
		float x = centerline(hh,a) + side*(0.245-0.14*hh);
		float grow = sin(life*3.14159265);
		vec2 q = p-vec2(x,y);
		q.x += side*q.y*0.45;
		float cut = (length(q/vec2(0.085+0.04*grow,0.105+0.07*grow))-1.0)*0.095;
		float active = smoothstep(0.0,0.12,life)*(1.0-smoothstep(0.85,1.0,life));
		float lower_protection = 1.0-smoothstep(0.25,0.40,p.y);
		d = max(d, -cut-(1.0-active)*0.3-lower_protection*0.4);
	}
	return d;
}

// Stable pseudo-random values: no gameplay RNG and reproducible seek/capture.
float ember_hash(float seed) {
    return fract(sin(seed*127.1+311.7)*43758.5453);
}

vec4 render_flame(vec2 uv) {
	float a = flame_time * 2.09439510239;
	vec2 p = vec2(uv.x-0.5, 0.9375-uv.y);
	float d = body_field(p,a);
	float aa = max(fwidth(d),0.001);
	float body = 1.0-smoothstep(-aa,aa,d);
	vec2 cp = vec2((p.x+0.012)/core_size, (p.y-0.079)/0.86+0.055);
	float cd = body_field(cp,a+0.10);
	float core = (1.0-smoothstep(-0.005,0.005,cd))*body;
	vec3 edge = mix(outer_color.rgb*vec3(1.0,0.82,0.8),outer_color.rgb+vec3(0.0,0.10,0.035),clamp(1.0-p.y,0.0,1.0));
	float warmth = exp(-max(-d,0.0)*35.0);
	edge = mix(edge,outer_color.rgb*vec3(1.0,0.83,0.75),warmth*0.5);
	vec3 color = mix(edge,core_color.rgb,core);
	float alpha = body;
	// Uneven births, individual trajectories and filled flame fragments.
	// Each lane changes its seed every birth; the full sequence repeats after 27 shader seconds.
	float ember_glow = 0.0;
	for (int i=0;i<10;i++) {
		float lane=float(i);
		float offset=ember_hash(lane+4.0)*9.0;
		float clock=(flame_time+offset)/9.0;
		float generation=floor(clock);
		float seed=lane*19.0+mod(generation,3.0)*73.0+5.0;
		float r1=ember_hash(seed+1.0);
		float age=fract(clock)*9.0;
		float lifetime=mix(1.6,3.8,r1);
		// Uniform across the quad: skip dead lanes before shape, noise, glow and derivatives.
		if (age >= lifetime) { continue; }
		float r0=ember_hash(seed);
		float r2=ember_hash(seed+2.0);
		float r3=ember_hash(seed+3.0);
		float life=clamp(age/lifetime,0.0,1.0);
		float fade=smoothstep(0.0,0.09,life)*(1.0-smoothstep(0.66,1.0,life));
		float side=r0<0.5 ? -1.0 : 1.0;
		float start_y=mix(0.36,0.60,r2);
		float birth_time=flame_time-age;
		float start_x=centerline(start_y/0.8,birth_time*2.09439510239)+side*mix(0.08,0.16,r3);
		float rise=mix(0.19,0.30,ember_hash(seed+4.0));
		float flutter=sin(life*mix(6.0,13.0,r3)+r1*6.28)-sin(r1*6.28);
		vec2 pos=vec2(start_x+side*life*mix(0.055,0.16,r1)+flutter*0.016*life,
			start_y+rise*(life*0.7+life*life*0.3));
		float size=mix(0.009,0.031,r3*r3)*(1.0-0.78*life);
		float angle=side*mix(0.15,0.7,r2)+0.35*sin(life*8.0+r3*6.28)*life;
		vec2 q=p-pos;
		q=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
		float stretch=mix(1.15,2.6,r2)*(1.0+0.18*sin(age*6.0+r0*6.28));
		vec2 shape=q/vec2(size,size*stretch);
		shape.x+=0.17*sin(shape.y*2.0+age*4.0)*clamp(shape.y,0.0,1.0);
		float taper=clamp(0.75-0.40*shape.y,0.24,1.12);
		float sd=(length(vec2(shape.x/taper,shape.y))-1.0)*size;
		// Some broad pieces have a small edge bite; most are filled tapered shards.
		if (r0>0.70) {
			float bite=(length((shape-vec2(0.74,0.48))/vec2(0.56,0.65))-1.0)*size;
			sd=max(sd,-bite);
		}
		float spark_aa=max(fwidth(sd),0.0008);
		float spark=(1.0-smoothstep(-spark_aa,spark_aa,sd))*fade*(1.0-body);
		float hot=(1.0-smoothstep(0.15,0.60,length(shape-vec2(0.0,-0.18))))*(1.0-life);
		vec3 ember_color=mix(outer_color.rgb,core_color.rgb,hot*0.85);
		color=mix(color,ember_color,spark);
		alpha=max(alpha,spark);
		ember_glow=max(ember_glow,exp(-max(sd,0.0)*190.0)*0.22*fade*(1.0-body));
	}
	float glow_pulse=0.93+0.045*sin(a*5.0)+0.025*sin(a*9.0+0.8);
	float halo=(exp(-max(d,0.0)*23.0)*0.72+exp(-max(d,0.0)*10.0)*0.25)*glow_strength*glow_pulse;
	halo*=smoothstep(-0.055,-0.015,p.y);
	float pool=exp(-pow(p.x/0.25,2.0)-pow((p.y+0.002)/0.026,2.0))*glow_strength*0.68;
	float ga=clamp(max(max(halo,pool),ember_glow*glow_strength),0.0,0.98);
	vec3 final_color=mix(outer_color.rgb,color,alpha);
	float final_alpha=max(alpha,ga);
	// Fade transparent margins so the quad never shows a rectangular edge.
	final_alpha*=smoothstep(0.0,0.035,uv.x)*smoothstep(0.0,0.035,1.0-uv.x);
	final_alpha*=smoothstep(0.0,0.025,uv.y)*smoothstep(0.0,0.025,1.0-uv.y);
	return vec4(final_color,final_alpha);
}
