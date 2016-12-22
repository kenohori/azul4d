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

#ifndef CppLink_hpp
#define CppLink_hpp

#include <list>
#include <fstream>

#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Cartesian_d.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Delaunay_mesher_2.h>
#include <CGAL/Delaunay_mesh_face_base_2.h>
#include <CGAL/Delaunay_mesh_size_criteria_2.h>
#include <CGAL/aff_transformation_tags.h>
#include <CGAL/predicates_d.h>
#include <CGAL/constructions_d.h>

typedef CGAL::Cartesian_d<double> Kernel;
typedef CGAL::Exact_predicates_inexact_constructions_kernel Triangulation_kernel;

typedef CGAL::Triangulation_vertex_base_2<Triangulation_kernel> Vertex_base;
typedef CGAL::Delaunay_mesh_face_base_2<Triangulation_kernel> Face_base;
typedef CGAL::Triangulation_data_structure_2<Vertex_base, Face_base> TDS;
typedef CGAL::Constrained_Delaunay_triangulation_2<Triangulation_kernel, TDS> CDT;

struct Polygon_d {
  std::vector<CGAL::Point_d<Kernel>> vertices;
};

struct Triangle_d {
  CGAL::Point_d<Kernel> vertices[3];
};

struct Mesh_d {
  std::vector<Triangle_d> triangles;
  float colour[4];
};

struct Edge_d {
  std::vector<CGAL::Point_d<Kernel>> vertices;
};

class CppLink {
public:
  std::vector<Mesh_d> faces;
  std::vector<Edge_d> edges;
  std::vector<CGAL::Point_d<Kernel>> vertices;
  std::vector<Mesh_d>::const_iterator currentFace;
  std::vector<Edge_d>::const_iterator currentEdge;
  std::vector<CGAL::Point_d<Kernel>>::const_iterator currentVertex;
  std::vector<Triangle_d>::const_iterator currentFaceTriangle;
//  std::vector<CGAL::Point_d<Kernel>>::const_iterator currentPoint;
  float currentPointCoordinates[4];
  
  Mesh_d refine(Polygon_d &polygon, double ratio, double size);
  Mesh_d triangulateUsingBarycentre(Polygon_d &polygon);
  Mesh_d triangulateQuad(Polygon_d &polygon);
  std::vector<Edge_d> generateEdges(std::vector<Polygon_d> &model);
  std::vector<CGAL::Point_d<Kernel>> generateVertices(std::vector<Polygon_d> &model);
  
  void makeTesseract();
  void makeHouse();
};

#endif /* CppLink_hpp */
