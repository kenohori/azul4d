//
//  CppLink.hpp
//  azul4d
//
//  Created by Ken Arroyo Ohori on 05/12/16.
//  Copyright © 2016 Ken Arroyo Ohori. All rights reserved.
//

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

class CppLink {
public:
  std::vector<Mesh_d> currentModelFaces, currentModelEdges, currentModelVertices, currentModelPart;
  std::vector<Mesh_d>::const_iterator currentMesh;
  std::vector<Triangle_d>::const_iterator currentTriangle;
  std::vector<CGAL::Point_d<Kernel>>::const_iterator currentPoint;
  float currentPointCoordinates[4];
  
  Mesh_d refine(Polygon_d &polygon, double ratio, double size);
  Mesh_d triangulateUsingBarycentre(Polygon_d &polygon);
  Mesh_d triangulateQuad(Polygon_d &polygon);
  std::vector<Mesh_d> generate_edges(std::vector<Polygon_d> &model, double size, double radius, unsigned int circle_segments);
  std::vector<Mesh_d> generate_vertices(std::vector<Polygon_d> &model, double radius, unsigned int icosphere_refinements);
  
  void makeTesseract();
  void makeHouse();
};

#endif /* CppLink_hpp */
