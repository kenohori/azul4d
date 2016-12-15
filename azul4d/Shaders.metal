// azul
// Copyright © 2016 Ken Arroyo Ohori
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <metal_stdlib>
using namespace metal;

struct Constants {
  float4x4 modelViewProjectionMatrix;
  float4x4 transformationMatrix;
};

struct VertexIn {
  float4 position;
  float4 colour;
};

struct VertexOut {
  float4 position [[position]];
  float4 colour;
};

vertex VertexOut vertexFacesStereo(device VertexIn *vertices [[buffer(0)]],
                                   constant Constants &uniforms [[buffer(1)]],
                                   uint VertexId [[vertex_id]]) {
  
  // Apply 4D transformation
  float4 transformedVertex = uniforms.transformationMatrix * vertices[VertexId].position;
  
  // Project from R4 to S3
  float r = sqrt(transformedVertex.x*transformedVertex.x+
                 transformedVertex.y*transformedVertex.y+
                 transformedVertex.z*transformedVertex.z+
                 transformedVertex.w*transformedVertex.w);
  float3 point_s3;
  
  if (r != 0) {
    point_s3.x = acos(transformedVertex.x/r);
  } else {
    if (transformedVertex.x >= 0) {
      point_s3.x = 0;
    } else {
      point_s3.x = 3.141592653589793;
    }
  }
  
  if (transformedVertex.y*transformedVertex.y+
      transformedVertex.z*transformedVertex.z+
      transformedVertex.w*transformedVertex.w != 0) {
    point_s3.y = acos(transformedVertex.y/sqrt(transformedVertex.y*transformedVertex.y+
                                                         transformedVertex.z*transformedVertex.z+
                                                         transformedVertex.w*transformedVertex.w));
  } else {
    if (transformedVertex.y >= 0) {
      point_s3.y = 0;
    } else {
      point_s3.y = 3.141592653589793;
    }
  }
  
  if (transformedVertex.z*transformedVertex.z+
      transformedVertex.w*transformedVertex.w != 0) {
    if (transformedVertex.w >= 0) {
      point_s3.z = acos(transformedVertex.z/sqrt(transformedVertex.z*transformedVertex.z+
                                                           transformedVertex.w*transformedVertex.w));
    } else {
      point_s3.z = -acos(transformedVertex.z/sqrt(transformedVertex.z*transformedVertex.z+
                                                            transformedVertex.w*transformedVertex.w));
    }
  } else {
    if (transformedVertex.w >= 0) {
      point_s3.z = 0;
    } else {
      point_s3.z = 3.141592653589793;
    }
  }
  
  // Project from S3 to R4
  float4 point_r4;
  point_r4.x = cos(point_s3.x);
  point_r4.y = sin(point_s3.x)*cos(point_s3.y);
  point_r4.z = sin(point_s3.x)*sin(point_s3.y)*cos(point_s3.z);
  point_r4.w = sin(point_s3.x)*sin(point_s3.y)*sin(point_s3.z);
  
  // Project from R4 to R3
  float3 point_r3;
  point_r3.x = point_r4.x/(point_r4.w-1);
  point_r3.y = point_r4.y/(point_r4.w-1);
  point_r3.z = point_r4.z/(point_r4.w-1);
  
  VertexOut out;
  out.position = uniforms.modelViewProjectionMatrix * float4(point_r3, 1.0);
  out.colour = vertices[VertexId].colour;
  return out;
}

fragment half4 fragmentLit(VertexOut fragmentIn [[stage_in]]) {
  return half4(fragmentIn.colour);
}
