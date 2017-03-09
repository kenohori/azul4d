// azul4d
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

struct RenderingConstants {
  float4x4 modelViewProjectionMatrix;
};

struct ProjectionParameters {
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

kernel void stereographicProjection(const device VertexIn *verticesIn [[buffer(0)]],
                                    device VertexIn *verticesOut [[buffer(1)]],
                                    constant ProjectionParameters &projectionParameters [[buffer(2)]],
                                    uint id [[thread_position_in_grid]]) {
  
  // Apply 4D transformation
  float4 transformedVertex = projectionParameters.transformationMatrix * verticesIn[id].position;

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
  
  // Output
  verticesOut[id].position = float4(point_r3, 1.0);
  verticesOut[id].colour = verticesIn[id].colour;
}

vertex VertexOut vertexLit(device VertexIn *vertices [[buffer(0)]],
                           constant RenderingConstants &uniforms [[buffer(1)]],
                           uint VertexId [[vertex_id]]) {
  VertexOut out;
  out.position = uniforms.modelViewProjectionMatrix * vertices[VertexId].position;
  out.colour = vertices[VertexId].colour;
  return out;
}

float4 normalise4(float4 v) {
  float norm = v.x*v.x+v.y*v.y+v.z*v.z+v.w*v.w;
  float4 vnormalised = float4(v.x/norm, v.y/norm, v.z/norm, v.w/norm);
  return vnormalised;
}

float determinant2(float a, float b, float c, float d) {
  return a*d - b*c;
}

float determinant3(float a, float b, float c, float d, float e, float f, float g, float h, float i) {
  return a*determinant2(e, f, h, i) - b*determinant2(d, f, g, i) + c*determinant2(d, e, g, h);
}

float4 crossProduct4(float4 u, float4 v, float4 w) {
  return float4(determinant3(u.y, u.z, u.w, v.y, v.z, v.w, w.y, w.z, w.w),
                -determinant3(u.x, u.z, u.w, v.x, v.z, v.w, w.x, w.z, w.w),
                determinant3(u.x, u.y, u.w, v.x, v.y, v.w, w.x, w.y, w.w),
                -determinant3(u.x, u.y, u.z, v.x, v.y, v.z, w.x, w.y, w.z));
}

kernel void orthographicProjection(const device VertexIn *verticesIn [[buffer(0)]],
                                   device VertexIn *verticesOut [[buffer(1)]],
                                   constant ProjectionParameters &projectionParameters [[buffer(2)]],
                                   uint id [[thread_position_in_grid]]) {
  
  // Apply 4D transformation
  float4 transformedVertex = projectionParameters.transformationMatrix * verticesIn[id].position;
  
  float4 from = float4(0.0, 1.0, 0.0, 0.0);
  float4 to = float4(0.0, 0.0, 0.0, 0.0);
  float4 up = float4(0.0, 0.0, 1.0, 0.0);
  float4 over = float4(0.0, 0.0, 0.0, 1.0);
  
  float4 d = normalise4(float4(to.x-from.x, to.y-from.y, to.z-from.z, to.w-from.w));  // Along y
  float4 a = normalise4(crossProduct4(up, over, d));  // Along x
  float4 b = normalise4(crossProduct4(over, d, a));   // Along z
  float4 c = crossProduct4(d, a, b)*2.0;  // Along w
  
  float4x4 m(a, b, c, d);
  float4 eye = (transformedVertex-from) * m;
  
  // Output
  verticesOut[id].position = float4(eye.x, eye.y, eye.z, 1.0);
  verticesOut[id].colour = verticesIn[id].colour;
}

kernel void longAxisProjection(const device VertexIn *verticesIn [[buffer(0)]],
                                   device VertexIn *verticesOut [[buffer(1)]],
                                   constant ProjectionParameters &projectionParameters [[buffer(2)]],
                                   uint id [[thread_position_in_grid]]) {
  
  // Apply 4D transformation
  float4 transformedVertex = projectionParameters.transformationMatrix * verticesIn[id].position;
  float3 longAxis = float3(2.0*transformedVertex.w, 0.0*transformedVertex.w, 0.0*transformedVertex.w);
  
  // Output
  verticesOut[id].position = float4(transformedVertex.x+longAxis.x, transformedVertex.z+longAxis.z, transformedVertex.y+longAxis.y, 1.0);
  verticesOut[id].colour = verticesIn[id].colour;
}

fragment half4 fragmentLit(VertexOut fragmentIn [[stage_in]]) {
  return half4(fragmentIn.colour);
}
