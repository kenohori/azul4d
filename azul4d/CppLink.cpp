//
//  CppLink.cpp
//  azul4d
//
//  Created by Ken Arroyo Ohori on 05/12/16.
//  Copyright © 2016 Ken Arroyo Ohori. All rights reserved.
//

#include "CppLink.hpp"

Mesh_d CppLink::refine(Polygon_d &polygon, double ratio, double size) {
  Mesh_d polygon_refined;
    
  // Plane passing through points 0-2 is defined by the space of vector_01 and vector_02
  CGAL::Point_d<Kernel> origin = polygon.vertices[0];
  CGAL::Vector_d<Kernel> vector_01 = polygon.vertices[1]-origin;
  vector_01 /= sqrt(vector_01.squared_length());
  
  CGAL::Hyperplane_d<Kernel> orthogonal_to_vector_01(origin, vector_01.direction());
  double k = (orthogonal_to_vector_01.coefficient(0)*polygon.vertices[2][0]+orthogonal_to_vector_01.coefficient(1)*polygon.vertices[2][1]+orthogonal_to_vector_01.coefficient(2)*polygon.vertices[2][2]+orthogonal_to_vector_01.coefficient(3)*polygon.vertices[2][3]+orthogonal_to_vector_01.coefficient(4))/(orthogonal_to_vector_01.coefficient(0)*orthogonal_to_vector_01.coefficient(0)+orthogonal_to_vector_01.coefficient(1)*orthogonal_to_vector_01.coefficient(1)+orthogonal_to_vector_01.coefficient(2)*orthogonal_to_vector_01.coefficient(2)+orthogonal_to_vector_01.coefficient(3)*orthogonal_to_vector_01.coefficient(3));
  double point_2_projected_to_plane_coordinates[4] = {polygon.vertices[2][0]-k*orthogonal_to_vector_01.coefficient(0),
    polygon.vertices[2][1]-k*orthogonal_to_vector_01.coefficient(1),
    polygon.vertices[2][2]-k*orthogonal_to_vector_01.coefficient(2),
    polygon.vertices[2][3]-k*orthogonal_to_vector_01.coefficient(3)};
  CGAL::Point_d<Kernel> point_2_projected_to_plane(4, point_2_projected_to_plane_coordinates, point_2_projected_to_plane_coordinates+4);
  CGAL::Vector_d<Kernel> vector_02 = point_2_projected_to_plane-origin;
  vector_02 /= sqrt(vector_02.squared_length());
  
  // Project a polygon to the plane
  Polygon_d polygon_2d;
  for (auto point : polygon.vertices) {
    CGAL::Vector_d<Kernel> point_vector = point-origin;
    double coordinates_2d[2] = {point_vector*vector_01, point_vector*vector_02};
    polygon_2d.vertices.push_back(CGAL::Point_d<Kernel>(2, coordinates_2d, coordinates_2d+2));
  }
  
  // Refine it
  CDT triangulation;
  for (unsigned int index = 0; index < polygon_2d.vertices.size()-1; ++index) {
    CDT::Vertex_handle current_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices[index][0], polygon_2d.vertices[index][1]));
    CDT::Vertex_handle next_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices[index+1][0], polygon_2d.vertices[index+1][1]));
    triangulation.insert_constraint(current_vertex, next_vertex);
  } CDT::Vertex_handle last_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices.back()[0], polygon_2d.vertices.back()[1]));
  CDT::Vertex_handle first_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices.front()[0], polygon_2d.vertices.front()[1]));
  triangulation.insert_constraint(last_vertex, first_vertex);
  //    std::cout << "Before: " << triangulation.number_of_vertices();
  CGAL::refine_Delaunay_mesh_2(triangulation, CGAL::Delaunay_mesh_size_criteria_2<CDT>(ratio, size));
  //    std::cout << " After: " << triangulation.number_of_vertices() << std::endl;
  
  // Project the refined mesh back
  for (auto current_face = triangulation.finite_faces_begin(); current_face != triangulation.finite_faces_end(); ++current_face) {
    polygon_refined.triangles.push_back(Triangle_d());
    polygon_refined.triangles.back().vertices[0] = origin+current_face->vertex(0)->point()[0]*vector_01+current_face->vertex(0)->point()[1]*vector_02;
    polygon_refined.triangles.back().vertices[1] = origin+current_face->vertex(1)->point()[0]*vector_01+current_face->vertex(1)->point()[1]*vector_02;
    polygon_refined.triangles.back().vertices[2] = origin+current_face->vertex(2)->point()[0]*vector_01+current_face->vertex(2)->point()[1]*vector_02;
  }
    
  return polygon_refined;
}

Mesh_d CppLink::triangulate(Polygon_d &polygon) {
  
  Mesh_d polygon_triangulated;
  
  // Compute the centroid
  double centroid[4] = {0.0, 0.0, 0.0, 0.0};
  for (auto const &point : polygon.vertices) {
    for (unsigned int currentCoordinate = 0; currentCoordinate < 4; ++currentCoordinate) {
      centroid[currentCoordinate] += point.cartesian(currentCoordinate);
    }
  } for (unsigned int currentCoordinate = 0; currentCoordinate < 4; ++currentCoordinate) {
    centroid[currentCoordinate] /= polygon.vertices.size();
  } CGAL::Point_d<Kernel> centroidPoint(4, centroid, centroid+4);
  
  // Barycentric triangulation
  std::vector<CGAL::Point_d<Kernel>>::const_iterator previousPoint = polygon.vertices.begin();
  std::vector<CGAL::Point_d<Kernel>>::const_iterator currentPoint = previousPoint;
  ++currentPoint;
  while (currentPoint != polygon.vertices.end()) {
    polygon_triangulated.triangles.push_back(Triangle_d());
    polygon_triangulated.triangles.back().vertices[0] = centroidPoint;
    polygon_triangulated.triangles.back().vertices[1] = *previousPoint;
    polygon_triangulated.triangles.back().vertices[2] = *currentPoint;
    ++previousPoint;
    ++currentPoint;
  } polygon_triangulated.triangles.push_back(Triangle_d());
  polygon_triangulated.triangles.back().vertices[0] = centroidPoint;
  polygon_triangulated.triangles.back().vertices[1] = polygon.vertices.back();
  polygon_triangulated.triangles.back().vertices[2] = polygon.vertices.front();
  
  return polygon_triangulated;
}

void CppLink::makeTesseract() {
  std::vector<Polygon_d> tesseract;
  
  double coordinates_0000[4] = {-1, -1, -1, -1};
  double coordinates_0001[4] = {-1, -1, -1, +1};
  double coordinates_0010[4] = {-1, -1, +1, -1};
  double coordinates_0011[4] = {-1, -1, +1, +1};
  double coordinates_0100[4] = {-1, +1, -1, -1};
  double coordinates_0101[4] = {-1, +1, -1, +1};
  double coordinates_0110[4] = {-1, +1, +1, -1};
  double coordinates_0111[4] = {-1, +1, +1, +1};
  double coordinates_1000[4] = {+1, -1, -1, -1};
  double coordinates_1001[4] = {+1, -1, -1, +1};
  double coordinates_1010[4] = {+1, -1, +1, -1};
  double coordinates_1011[4] = {+1, -1, +1, +1};
  double coordinates_1100[4] = {+1, +1, -1, -1};
  double coordinates_1101[4] = {+1, +1, -1, +1};
  double coordinates_1110[4] = {+1, +1, +1, -1};
  double coordinates_1111[4] = {+1, +1, +1, +1};
  
  
  
  CGAL::Point_d<Kernel> point_0000(4, coordinates_0000, coordinates_0000+4);
  CGAL::Point_d<Kernel> point_0001(4, coordinates_0001, coordinates_0001+4);
  CGAL::Point_d<Kernel> point_0010(4, coordinates_0010, coordinates_0010+4);
  CGAL::Point_d<Kernel> point_0011(4, coordinates_0011, coordinates_0011+4);
  CGAL::Point_d<Kernel> point_0100(4, coordinates_0100, coordinates_0100+4);
  CGAL::Point_d<Kernel> point_0101(4, coordinates_0101, coordinates_0101+4);
  CGAL::Point_d<Kernel> point_0110(4, coordinates_0110, coordinates_0110+4);
  CGAL::Point_d<Kernel> point_0111(4, coordinates_0111, coordinates_0111+4);
  CGAL::Point_d<Kernel> point_1000(4, coordinates_1000, coordinates_1000+4);
  CGAL::Point_d<Kernel> point_1001(4, coordinates_1001, coordinates_1001+4);
  CGAL::Point_d<Kernel> point_1010(4, coordinates_1010, coordinates_1010+4);
  CGAL::Point_d<Kernel> point_1011(4, coordinates_1011, coordinates_1011+4);
  CGAL::Point_d<Kernel> point_1100(4, coordinates_1100, coordinates_1100+4);
  CGAL::Point_d<Kernel> point_1101(4, coordinates_1101, coordinates_1101+4);
  CGAL::Point_d<Kernel> point_1110(4, coordinates_1110, coordinates_1110+4);
  CGAL::Point_d<Kernel> point_1111(4, coordinates_1111, coordinates_1111+4);
  
  // ffvv
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_0110);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1000);
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1100);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1110);
  
  // fvfv
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_0100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_0110);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1000);
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1010);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1110);
  
  // fvvf
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_0100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_0101);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1000);
  tesseract.back().vertices.push_back(point_1010);
  tesseract.back().vertices.push_back(point_1110);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1101);
  
  // vffv
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1000);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1110);
  
  // vfvf
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_1010);
  tesseract.back().vertices.push_back(point_1000);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1001);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_1110);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1101);
  
  // vvff
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_1100);
  tesseract.back().vertices.push_back(point_1000);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1001);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_1110);
  tesseract.back().vertices.push_back(point_1010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1011);
  
  std::vector<Mesh_d> tesseract_refined;
  for (auto &polygon : tesseract) {
    tesseract_refined.push_back(refine(polygon, 0.125, 0.1));
    tesseract_refined.back().colour[0] = 0.0;
    tesseract_refined.back().colour[1] = 0.0;
    tesseract_refined.back().colour[2] = 1.0;
    tesseract_refined.back().colour[3] = 0.2;
//    tesseract_refined.push_back(triangulate(polygon));
  }
  
  currentModel = tesseract_refined;
}
