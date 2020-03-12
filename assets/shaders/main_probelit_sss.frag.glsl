#version 310 es
#extension GL_EXT_texture_buffer : enable
#extension GL_OES_texture_buffer : enable
#extension GL_EXT_texture_cube_map_array : enable
//#extension GL_EXT_control_flow_attributes : enable

$ModifyWarning

#ifdef GL_ES
    precision mediump float;
    precision mediump sampler2DShadow;
#endif

#include "common_fs.glsl"

#define LIGHT_ATTEN_CUTOFF 0.004

layout(binding = REN_MAT_TEX0_SLOT) uniform sampler2D diffuse_texture;
layout(binding = REN_MAT_TEX1_SLOT) uniform sampler2D normals_texture;
layout(binding = REN_MAT_TEX2_SLOT) uniform sampler2D specular_texture;
layout(binding = REN_MAT_TEX3_SLOT) uniform sampler2D sss_texture;
layout(binding = REN_SHAD_TEX_SLOT) uniform sampler2DShadow shadow_texture;
layout(binding = REN_DECAL_TEX_SLOT) uniform sampler2D decals_texture;
layout(binding = REN_SSAO_TEX_SLOT) uniform sampler2D ao_texture;
layout(binding = REN_LIGHT_BUF_SLOT) uniform mediump samplerBuffer lights_buffer;
layout(binding = REN_DECAL_BUF_SLOT) uniform mediump samplerBuffer decals_buffer;
layout(binding = REN_CELLS_BUF_SLOT) uniform highp usamplerBuffer cells_buffer;
layout(binding = REN_ITEMS_BUF_SLOT) uniform highp usamplerBuffer items_buffer;

#if defined(VULKAN) || defined(GL_SPIRV)
layout (binding = 0, std140)
#else
layout (std140)
#endif
uniform SharedDataBlock {
    SharedData shrd_data;
};

#if defined(VULKAN) || defined(GL_SPIRV)
layout(location = 0) in highp vec3 aVertexPos_;
layout(location = 1) in mediump vec3 aVertexUVAndCurvature_;
layout(location = 2) in mediump vec3 aVertexNormal_;
layout(location = 3) in mediump vec3 aVertexTangent_;
layout(location = 4) in highp vec3 aVertexShUVs_[4];
#else
in highp vec3 aVertexPos_;
in mediump vec3 aVertexUVAndCurvature_;
in mediump vec3 aVertexNormal_;
in mediump vec3 aVertexTangent_;
in highp vec3 aVertexShUVs_[4];
#endif

layout(location = REN_OUT_COLOR_INDEX) out vec4 outColor;
layout(location = REN_OUT_NORM_INDEX) out vec4 outNormal;
layout(location = REN_OUT_SPEC_INDEX) out vec4 outSpecular;

#include "common.glsl"

// Taken from https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/SG.h

struct SphGauss {
	vec3 amplitude;
	float sharpness;
	vec3 axis;
	float _unused;
};

vec3 SphGaussEvaluate(SphGauss sg, vec3 dir) {
	return sg.amplitude * exp(sg.sharpness * (dot(dir, sg.axis) - 1.0));
}

vec3 SphGaussInnerProduct(SphGauss sg1, SphGauss sg2) {
	float um_len = length(sg1.sharpness * sg1.axis + sg2.sharpness * sg2.axis);
	vec3 expo = exp(um_len - sg1.sharpness - sg2.sharpness) * sg1.amplitude * sg2.amplitude;
	float other = 1.0 - exp(-2.0 * um_len);
	return (2.0 * M_PI * expo * other) / um_len;
}

vec3 SphGaussIntegral(SphGauss sg) {
	float exp_term = 1.0 - exp(-2.0 * sg.sharpness);
	return 2.0 * M_PI * (sg.amplitude / sg.sharpness) * exp_term;
}

vec3 SphGaussIntegralApprox(SphGauss sg) {
	return 2.0 * M_PI * (sg.amplitude / sg.sharpness);
}

SphGauss SphGaussCosine(vec3 dir) {
	SphGauss sg;
	sg.axis = dir;
	sg.sharpness = 2.133;
	sg.amplitude = vec3(1.17);
	
	return sg;
}

vec3 SphGaussIrradianceApprox(SphGauss light_lobe, vec3 normal) {
	SphGauss cosine_lobe = SphGaussCosine(normal);
	return SphGaussInnerProduct(light_lobe, cosine_lobe);
}

vec3 SphGaussIrradianceFitted(SphGauss light_lobe, vec3 normal) {
	const float mu_dot_N = dot(light_lobe.axis, normal);
    const float lambda = light_lobe.sharpness;

    const float c0 = 0.36;
    const float c1 = 1.0 / (4.0 * c0);

    float eml  = exp(-lambda);
    float em2l = eml * eml;
    float rl   = 1.0 / lambda;

    float scale = 1.0 + 2.0 * em2l - rl;
    float bias  = (eml - em2l) * rl - em2l;

    float x  = sqrt(1.0 - scale);
    float x0 = c0 * mu_dot_N;
    float x1 = c1 * x;

    float n = x0 + x1;

    float y = (abs(x0) <= x1) ? n * n / x : clamp(mu_dot_N, 0.0, 1.0);

    float normalized_irradiance = scale * y + bias;

    return normalized_irradiance * SphGaussIntegralApprox(light_lobe);
}

SphGauss SphGaussNormalized(vec3 axis, float sharpness) {
	SphGauss sg;
	sg.axis = axis;
	sg.sharpness = sharpness;
	sg.amplitude = vec3(1.0);
	sg.amplitude = vec3(1.0) / SphGaussIntegralApprox(sg);
	
	return sg;
}

void main(void) {
    highp float lin_depth = shrd_data.uClipInfo[0] / (gl_FragCoord.z * (shrd_data.uClipInfo[1] - shrd_data.uClipInfo[2]) + shrd_data.uClipInfo[2]);
    highp float k = log2(lin_depth / shrd_data.uClipInfo[1]) / shrd_data.uClipInfo[3];
    int slice = int(floor(k * float(REN_GRID_RES_Z)));
    
    int ix = int(gl_FragCoord.x), iy = int(gl_FragCoord.y);
    int cell_index = slice * REN_GRID_RES_X * REN_GRID_RES_Y + (iy * REN_GRID_RES_Y / int(shrd_data.uResAndFRes.y)) * REN_GRID_RES_X + ix * REN_GRID_RES_X / int(shrd_data.uResAndFRes.x);
    
    highp uvec2 cell_data = texelFetch(cells_buffer, cell_index).xy;
    highp uvec2 offset_and_lcount = uvec2(bitfieldExtract(cell_data.x, 0, 24), bitfieldExtract(cell_data.x, 24, 8));
    highp uvec2 dcount_and_pcount = uvec2(bitfieldExtract(cell_data.y, 0, 8), bitfieldExtract(cell_data.y, 8, 8));
    
    vec3 albedo_color = texture(diffuse_texture, aVertexUVAndCurvature_.xy).rgb;
    
    vec2 duv_dx = dFdx(aVertexUVAndCurvature_.xy), duv_dy = dFdy(aVertexUVAndCurvature_.xy);
    vec3 normal_color = texture(normals_texture, aVertexUVAndCurvature_.xy).wyz;
    vec4 specular_color = texture(specular_texture, aVertexUVAndCurvature_.xy);
    
    vec3 dp_dx = dFdx(aVertexPos_);
    vec3 dp_dy = dFdy(aVertexPos_);

    for (uint i = offset_and_lcount.x; i < offset_and_lcount.x + dcount_and_pcount.x; i++) {
        highp uint item_data = texelFetch(items_buffer, int(i)).x;
        int di = int(bitfieldExtract(item_data, 12, 12));
        
        mat4 de_proj;
        de_proj[0] = texelFetch(decals_buffer, di * 6 + 0);
        de_proj[1] = texelFetch(decals_buffer, di * 6 + 1);
        de_proj[2] = texelFetch(decals_buffer, di * 6 + 2);
        de_proj[3] = vec4(0.0, 0.0, 0.0, 1.0);
        de_proj = transpose(de_proj);
        
        vec4 pp = de_proj * vec4(aVertexPos_, 1.0);
        pp /= pp[3];
        
        vec3 app = abs(pp.xyz);
        vec2 uvs = pp.xy * 0.5 + 0.5;
        
        vec2 duv_dx = 0.5 * (de_proj * vec4(dp_dx, 0.0)).xy;
        vec2 duv_dy = 0.5 * (de_proj * vec4(dp_dy, 0.0)).xy;
        
        if (app.x < 1.0 && app.y < 1.0 && app.z < 1.0) {
            vec4 diff_uvs_tr = texelFetch(decals_buffer, di * 6 + 3);
            float decal_influence = 0.0;
            
            if (diff_uvs_tr.z > 0.0) {
                vec2 diff_uvs = diff_uvs_tr.xy + diff_uvs_tr.zw * uvs;
                
                vec2 _duv_dx = diff_uvs_tr.zw * duv_dx;
                vec2 _duv_dy = diff_uvs_tr.zw * duv_dy;
            
                vec4 decal_diff = textureGrad(decals_texture, diff_uvs, _duv_dx, _duv_dy);
                decal_influence = decal_diff.a;
                albedo_color = mix(albedo_color, decal_diff.rgb, decal_influence);
            }
            
            vec4 norm_uvs_tr = texelFetch(decals_buffer, di * 6 + 4);
            
            if (norm_uvs_tr.z > 0.0) {
                vec2 norm_uvs = norm_uvs_tr.xy + norm_uvs_tr.zw * uvs;
                
                vec2 _duv_dx = 2.0 * norm_uvs_tr.zw * duv_dx;
                vec2 _duv_dy = 2.0 * norm_uvs_tr.zw * duv_dy;
            
                vec3 decal_norm = textureGrad(decals_texture, norm_uvs, _duv_dx, _duv_dy).wyz;
                normal_color = mix(normal_color, decal_norm, decal_influence);
            }
            
            vec4 spec_uvs_tr = texelFetch(decals_buffer, di * 6 + 5);
            
            if (spec_uvs_tr.z > 0.0) {
                vec2 spec_uvs = spec_uvs_tr.xy + spec_uvs_tr.zw * uvs;
                
                vec2 _duv_dx = spec_uvs_tr.zw * duv_dx;
                vec2 _duv_dy = spec_uvs_tr.zw * duv_dy;
            
                vec4 decal_spec = textureGrad(decals_texture, spec_uvs, _duv_dx, _duv_dy);
                specular_color = mix(specular_color, decal_spec, decal_influence);
            }
        }
    }

    vec3 normal = normal_color * 2.0 - 1.0;
    normal = normalize(mat3(aVertexTangent_, cross(aVertexNormal_, aVertexTangent_), aVertexNormal_) * normal);
    
    vec3 additional_light = vec3(0.0, 0.0, 0.0);
    
    for (uint i = offset_and_lcount.x; i < offset_and_lcount.x + offset_and_lcount.y; i++) {
        highp uint item_data = texelFetch(items_buffer, int(i)).x;
        int li = int(bitfieldExtract(item_data, 0, 12));

        vec4 pos_and_radius = texelFetch(lights_buffer, li * 3 + 0);
        highp vec4 col_and_index = texelFetch(lights_buffer, li * 3 + 1);
        vec4 dir_and_spot = texelFetch(lights_buffer, li * 3 + 2);
        
        vec3 L = pos_and_radius.xyz - aVertexPos_;
        float dist = length(L);
        float d = max(dist - pos_and_radius.w, 0.0);
        L /= dist;
        
        highp float denom = d / pos_and_radius.w + 1.0;
        highp float atten = 1.0 / (denom * denom);
        
        highp float brightness = max(col_and_index.x, max(col_and_index.y, col_and_index.z));
        
        highp float factor = LIGHT_ATTEN_CUTOFF / brightness;
        atten = (atten - factor) / (1.0 - LIGHT_ATTEN_CUTOFF);
        atten = max(atten, 0.0);
        
        float _dot1 = max(dot(L, normal), 0.0);
        float _dot2 = dot(L, dir_and_spot.xyz);
        
        atten = _dot1 * atten;
        if (_dot2 > dir_and_spot.w && (brightness * atten) > FLT_EPS) {
            int shadowreg_index = floatBitsToInt(col_and_index.w);
            if (shadowreg_index != -1) {
                vec4 reg_tr = shrd_data.uShadowMapRegions[shadowreg_index].transform;
                
                highp vec4 pp = shrd_data.uShadowMapRegions[shadowreg_index].clip_from_world * vec4(aVertexPos_, 1.0);
                pp /= pp.w;
                pp.xyz = pp.xyz * 0.5 + vec3(0.5);
                pp.xy = reg_tr.xy + pp.xy * reg_tr.zw;
                
                atten *= SampleShadowPCF5x5(shadow_texture, pp.xyz);
            }
            
            additional_light += col_and_index.xyz * atten * smoothstep(dir_and_spot.w, dir_and_spot.w + 0.2, _dot2);
        }
    }
    
    vec3 indirect_col = vec3(0.0);
    float total_fade = 0.0;
    
    for (uint i = offset_and_lcount.x; i < offset_and_lcount.x + dcount_and_pcount.y; i++) {
        highp uint item_data = texelFetch(items_buffer, int(i)).x;
        int pi = int(bitfieldExtract(item_data, 24, 8));
        
        const float SH_A0 = 0.886226952; // PI / sqrt(4.0f * Pi)
        const float SH_A1 = 1.02332675;  // sqrt(PI / 3.0f)
        
        float dist = distance(shrd_data.uProbes[pi].pos_and_radius.xyz, aVertexPos_);
        float fade = 1.0 - smoothstep(0.9, 1.0, dist / shrd_data.uProbes[pi].pos_and_radius.w);
        vec4 vv = fade * vec4(SH_A0, SH_A1 * normal.yzx);

        indirect_col.r += dot(shrd_data.uProbes[pi].sh_coeffs[0], vv);
        indirect_col.g += dot(shrd_data.uProbes[pi].sh_coeffs[1], vv);
        indirect_col.b += dot(shrd_data.uProbes[pi].sh_coeffs[2], vv);
        total_fade += fade;
    }
    
    indirect_col /= max(total_fade, 1.0);
    indirect_col = max(4.0 * indirect_col, vec3(0.0));
    

	float N_dot_L = dot(normal, shrd_data.uSunDir.xyz);
    float lambert = clamp(N_dot_L, 0.0, 1.0);

    float visibility = 0.0;
    if (lambert > 0.00001) {
        visibility = GetSunVisibility(lin_depth, shadow_texture, aVertexShUVs_);
    }
    
	vec3 sun_diffuse;
	
	{
		visibility = 1.0;
		
		float curvature = clamp(aVertexUVAndCurvature_.z, 0.0, 1.0);
		
		/*vec3 scatter_amt = 0.01 * max(curvature, 0.0) * vec3(1.0, 0.15, 0.1);
		
		SphGauss r_kernel = SphGaussNormalized(shrd_data.uSunDir.xyz, 1.0 / scatter_amt.r);
		SphGauss g_kernel = SphGaussNormalized(shrd_data.uSunDir.xyz, 1.0 / scatter_amt.g);
		SphGauss b_kernel = SphGaussNormalized(shrd_data.uSunDir.xyz, 1.0 / scatter_amt.b);
		
		sun_diffuse = vec3(
			SphGaussIrradianceFitted(r_kernel, normal).x,
			SphGaussIrradianceFitted(g_kernel, normal).x,
			SphGaussIrradianceFitted(b_kernel, normal).x
		);*/
		
		sun_diffuse = texture(sss_texture, vec2(N_dot_L * 0.5 + 0.5, curvature)).rgb;
	}
	
    vec2 ao_uvs = vec2(ix, iy) / shrd_data.uResAndFRes.zw;
    float ambient_occlusion = textureLod(ao_texture, ao_uvs, 0.0).r;
    vec3 diffuse_color = albedo_color * (shrd_data.uSunCol.xyz * sun_diffuse * visibility + ambient_occlusion * indirect_col + additional_light);
    
    vec3 view_ray_ws = normalize(shrd_data.uCamPosAndGamma.xyz - aVertexPos_);
    float N_dot_V = clamp(dot(normal, view_ray_ws), 0.0, 1.0);
    
    vec3 kD = 1.0 - FresnelSchlickRoughness(N_dot_V, specular_color.xyz, specular_color.a);
    
    outColor = vec4(diffuse_color * kD, 1.0);
    outNormal = vec4(normal * 0.5 + 0.5, 0.0);
    outSpecular = specular_color;
	
	/*{
		outColor.rgb *= 0.00001;
		
		outColor.rgb += vec3(aVertexUVAndCurvature_.z);
	}*/
}
