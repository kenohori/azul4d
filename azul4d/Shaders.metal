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
};

struct VertexIn {
  float4 position;
  float3 colour;
};

struct VertexOut {
  float4 position [[position]];
  float4 colour;
};

vertex VertexOut vertexTransform(device VertexIn *vertices [[buffer(0)]],
                                 constant Constants &uniforms [[buffer(1)]],
                                 uint VertexId [[vertex_id]]) {
  VertexOut out;
  out.position = uniforms.modelViewProjectionMatrix * vertices[VertexId].position;
  out.colour = float4(vertices[VertexId].colour, 1.0);
  return out;
}

fragment half4 fragmentLit(VertexOut fragmentIn [[stage_in]]) {
  return half4(fragmentIn.colour);
}
