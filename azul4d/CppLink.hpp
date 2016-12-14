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
  std::vector<CGAL::Point_d<Kernel>> points;
};

class CppLink {
public:
  std::list<Polygon_d> currentModel;
  std::list<Polygon_d>::const_iterator currentPolygon;
  std::vector<CGAL::Point_d<Kernel>>::const_iterator currentPoint;
  float currentPointCoordinates[4];
  
  Polygon_d refine(Polygon_d &polygon, double ratio, double size);
  Polygon_d triangulate(Polygon_d &polygon);
  
  void makeTesseract();
};

#endif /* CppLink_hpp */
