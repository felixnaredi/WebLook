//
//  Shaders.metal
//  WebLook
//
//  Created by Felix Naredi on 2019-04-23.
//  Copyright © 2019 Felix Naredi. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "WEBLShaderTypes.h"

using namespace metal;


struct RasterizerData
{
  float4 position [[position]];
  float2 textureCoordinate;
  
  constexpr RasterizerData(WEBLVertex vtx)
  : position(float4(vtx.position, 0, 1))
  , textureCoordinate(vtx.textureCoordinate)
  {}
};


vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]], constant WEBLVertex *vertices [[ buffer(0) ]])
{ return RasterizerData(vertices[vertexID]); }


fragment float4
samplingsShader(RasterizerData in [[ stage_in ]], texture2d<half> colorTexture [[ texture(0) ]])
{
  return float4(
                colorTexture.sample(sampler(mag_filter::linear, min_filter::linear), in.textureCoordinate));
}
